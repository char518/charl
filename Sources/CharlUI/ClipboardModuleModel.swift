import AppKit
import CharlCore
import CharlPlatform
import Combine
import Foundation
import os

private let clipboardLog = Logger(subsystem: "com.charl.charl", category: "clipboard")

/// 剪贴板模块视图模型。历史 JSON 在面板首次打开时才加载；缩略图按需读盘并缓存。
public final class ClipboardModuleModel: ObservableObject {
    @Published public private(set) var items: [ClipboardItem] = [] {
        didSet { refreshVisible() }
    }

    @Published public var filter = "" {
        didSet { selection = 0; refreshVisible() }
    }
    @Published public var group: ClipboardGroup = .all {
        didSet { selection = 0; refreshVisible() }
    }
    @Published public var selection = 0

    private var cachedVisible: [ClipboardItem] = []

    public var visibleItems: [ClipboardItem] { cachedVisible }

    private func refreshVisible() {
        cachedVisible = ClipboardQuery.filter(items, group: group, keyword: filter)
    }

    public func count(in group: ClipboardGroup) -> Int {
        items.filter { group.contains($0) }.count
    }

    public func onOpen() {
        loadIfNeeded()
        group = .all
        filter = ""
        selection = 0
    }

    public var selectedItem: ClipboardItem? {
        let visible = visibleItems
        guard visible.indices.contains(selection) else { return nil }
        return visible[selection]
    }

    public func moveSelection(_ delta: Int) {
        let count = visibleItems.count
        guard count > 0 else { return }
        selection = min(max(0, selection + delta), count - 1)
    }

    /// 容量上限由设置驱动（AppModel.applySettings 同步）。
    public var maxTextItems = AppConfig.maxTextItems
    public var maxImageItems = AppConfig.maxImageItems

    private var history = ClipboardHistory()
    private let service: ClipboardService
    private let storage: StorageService
    private var loaded = false
    private var saveWork: DispatchWorkItem?
    private var thumbnailCache: [UUID: NSImage] = [:]
    private let persistQueue = DispatchQueue(label: "com.charl.charl.clipboard.persist", qos: .utility)

    private static let historyPath = "clipboard/history.json"

    public init(service: ClipboardService, storage: StorageService, monitoring: Bool = true) {
        self.service = service
        self.storage = storage
        if monitoring {
            service.startMonitoring { [weak self] item in self?.ingest(item) }
        }
    }

    public func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? storage.read(Self.historyPath),
              let decoded = try? JSONDecoder().decode(ClipboardHistory.self, from: data) else { return }
        history = decoded
        items = decoded.items
    }

    public func copy(_ item: ClipboardItem) {
        service.copy(item)
    }

    public func togglePin(_ item: ClipboardItem) {
        history.togglePin(id: item.id)
        publish()
    }

    public func delete(_ item: ClipboardItem) {
        guard let removed = history.remove(id: item.id) else { return }
        service.deleteImageFiles(for: removed)
        thumbnailCache.removeValue(forKey: item.id)
        publish()
    }

    public func clearUnpinned() {
        let removed = history.clearUnpinned()
        removed.forEach { service.deleteImageFiles(for: $0) }
        thumbnailCache.removeAll()
        publish()
    }

    public func thumbnail(for item: ClipboardItem) -> NSImage? {
        if let cached = thumbnailCache[item.id] { return cached }
        guard let data = service.thumbnailData(for: item), let image = NSImage(data: data) else { return nil }
        thumbnailCache[item.id] = image
        return image
    }

    public func fullImage(for item: ClipboardItem) -> NSImage? {
        guard let data = service.imageData(for: item) else { return nil }
        return NSImage(data: data)
    }

    /// 面板关闭时释放缩略图缓存，压低常驻内存。
    public func releaseCaches() {
        thumbnailCache.removeAll()
    }

    public func flushSave() {
        saveWork?.cancel()
        saveWork = nil
        // 退出/测试等需要立即可见的场景：同步落盘（debounce 的 persist 走后台队列）
        guard loaded, let data = try? JSONEncoder().encode(history) else { return }
        do {
            try storage.write(data, to: Self.historyPath)
        } catch {
            clipboardLog.error("clipboard history save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func ingest(_ item: ClipboardItem) {
        // 监听早于面板打开：先合并磁盘历史，避免只存新增条目
        loadIfNeeded()
        let removed = history.insert(item, maxText: maxTextItems, maxImage: maxImageItems)
        removed.forEach { service.deleteImageFiles(for: $0) }
        publish()
    }

    private func publish() {
        items = history.items
        selection = min(selection, max(0, visibleItems.count - 1))
        scheduleSave()
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.persist() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func persist() {
        // 未加载过磁盘历史的短生命周期进程不得落盘，否则会清空既有历史
        guard loaded else { return }
        let snapshot = history
        // 编码与写盘放后台，避免连续复制时主线程卡顿
        persistQueue.async { [weak self] in
            guard let self else { return }
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            do {
                try self.storage.write(data, to: Self.historyPath)
            } catch {
                clipboardLog.error("clipboard history save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}