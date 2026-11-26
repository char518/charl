import Foundation

/// 剪贴板历史的纯业务逻辑：去重、置顶、容量上限。不依赖任何平台 API。
public struct ClipboardHistory: Codable, Sendable {
    public private(set) var items: [ClipboardItem]

    public init(items: [ClipboardItem] = []) {
        self.items = items
    }

    /// 插入新条目，返回因容量上限被淘汰的旧条目（调用方负责清理其附件文件）。
    @discardableResult
    public mutating func insert(_ item: ClipboardItem, maxText: Int = AppConfig.maxTextItems, maxImage: Int = AppConfig.maxImageItems) -> [ClipboardItem] {
        if item.kind == .text, let index = items.firstIndex(where: { $0.kind == .text && $0.text == item.text }) {
            if items[index].isPinned {
                return []
            }
            items.remove(at: index)
        }
        items.insert(item, at: 0)

        var removed: [ClipboardItem] = []
        removed += prune(kind: .text, limit: maxText)
        removed += prune(kind: .image, limit: maxImage)
        return removed
    }

    private mutating func prune(kind: ClipboardItem.Kind, limit: Int) -> [ClipboardItem] {
        var removed: [ClipboardItem] = []
        var count = items.filter { $0.kind == kind }.count
        var index = items.count - 1
        while count > limit && index >= 0 {
            if items[index].kind == kind && !items[index].isPinned {
                removed.append(items.remove(at: index))
                count -= 1
            }
            index -= 1
        }
        return removed
    }

    public mutating func togglePin(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
    }

    @discardableResult
    public mutating func remove(id: UUID) -> ClipboardItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return items.remove(at: index)
    }

    @discardableResult
    public mutating func clearUnpinned() -> [ClipboardItem] {
        let removed = items.filter { !$0.isPinned }
        items.removeAll { !$0.isPinned }
        return removed
    }
}