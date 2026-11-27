import AppKit
import CharlCore
import QuartzCore
import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var model: ClipboardModuleModel
    let actions: ClipboardActions
    var ropeOpacity: Double = 1
    @FocusState private var searchFocused: Bool
    @State private var confirmingClear = false
    @State private var compactCards: Bool

    init(model: ClipboardModuleModel, actions: ClipboardActions, compactCards: Bool = true, ropeOpacity: Double = 1) {
        self.model = model
        self.actions = actions
        self.ropeOpacity = ropeOpacity
        _compactCards = State(initialValue: compactCards)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Color.clear)
        .confirmationDialog(loc("清空所有未收藏的历史？", "Clear all unpinned history?"), isPresented: $confirmingClear, titleVisibility: .visible) {
            Button(loc("清空", "Clear"), role: .destructive) { model.clearUnpinned() }
            Button(loc("取消", "Cancel"), role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                IconTile(symbol: "doc.on.clipboard", tint: Theme.accent, size: 24)
                Text(loc("剪贴板", "Clipboard"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.label)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 18)
                    TextField(loc("搜索 \(model.items.count) 条记录", model.items.count == 1 ? "Search 1 item" : "Search \(model.items.count) items"), text: $model.filter)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($searchFocused)
                    if !model.filter.isEmpty {
                        ToolButton(symbol: "xmark.circle.fill", help: loc("清除搜索", "Clear Search"), size: 19) { model.filter = "" }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(Theme.panel))
                .frame(width: 320)

                Menu {
                    ForEach(ClipboardGroup.allCases) { group in
                        Button("\(group.title)  \(model.count(in: group))") {
                            model.group = group
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        if model.group == .pinned {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                        }
                        Text(model.group.title)
                            .font(.system(size: 11, weight: .medium))
                        Text("\(model.count(in: model.group))")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Theme.tertiary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.panel))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Spacer(minLength: 12)

            HStack(spacing: 4) {
                ToolButton(symbol: compactCards ? "rectangle" : "rectangle.grid.2x2", help: compactCards ? loc("使用标准卡片", "Use Standard Cards") : loc("使用紧凑卡片", "Use Compact Cards"), size: 26) {
                    compactCards.toggle()
                }
                Menu {
                    Button(loc("清空未收藏", "Clear Unpinned"), role: .destructive) { confirmingClear = true }
                        .disabled(model.items.allSatisfy(\.isPinned))
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(loc("更多操作", "More Actions"))
                ToolButton(symbol: "gearshape", help: loc("剪贴板设置", "Clipboard Settings"), size: 26, action: actions.settings)
                ToolButton(symbol: "xmark", help: loc("关闭 (Esc)", "Close (Esc)"), size: 26, action: actions.close)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if model.visibleItems.isEmpty {
            EmptyState(
                symbol: model.filter.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
                title: emptyTitle,
                message: emptyMessage
            )
            .overlay(alignment: .bottom) {
                if !model.filter.isEmpty {
                    Button(loc("清除搜索", "Clear Search")) { model.filter = "" }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.bottom, 36)
                }
            }
        } else {
            ClipboardCardScroller(model: model, actions: actions, compact: compactCards, ropeOpacity: ropeOpacity) {
                searchFocused = false
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyTitle: String {
        if !model.filter.isEmpty { return loc("没有匹配的记录", "No Matching Items") }
        if model.group == .pinned { return loc("还没有收藏内容", "Nothing Pinned Yet") }
        return model.group == .all ? loc("剪贴板还是空的", "Clipboard Is Empty") : loc("此分组还没有内容", "Nothing in This Group")
    }

    private var emptyMessage: String {
        if !model.filter.isEmpty { return loc("换个关键词，或清除搜索查看全部记录", "Try another keyword, or clear the search to see everything") }
        if model.group == .pinned { return loc("点击卡片上的星标，收藏常用内容", "Tap the star on a card to pin what you use often") }
        return loc(
            "复制文本、链接或图片后会自动记录\n敏感与临时内容不会被保存",
            "Copied text, links and images are recorded automatically\nSensitive and temporary content is never saved"
        )
    }

}

struct ClipboardActions {
    var activate: (ClipboardItem) -> Void
    var preview: (ClipboardItem) -> Void
    var copyOnly: (ClipboardItem) -> Void
    var pinImage: (ClipboardItem) -> Void
    var settings: () -> Void
    var close: () -> Void
}

/// 卡片悬停只由光标位置推导（鼠标移动 / 布局落定 / 滚动时重算）。
/// 不监听 .onHover：reloadData 回收视图时 AppKit 会补发 mouseExited，
/// 会把静止光标下的悬停错误清掉，按钮随之消失、点击落空。
final class ClipboardCardHover: ObservableObject {
    @Published private(set) var id: UUID?

    func reset(to id: UUID?) {
        if self.id != id { self.id = id }
    }
}

private struct ClipboardCardScroller: NSViewRepresentable {
    let model: ClipboardModuleModel
    let actions: ClipboardActions
    let compact: Bool
    var ropeOpacity: Double = 1
    let resignSearch: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model, actions: actions, compact: compact, ropeOpacity: ropeOpacity, resignSearch: resignSearch)
    }

    func makeNSView(context: Context) -> ClipboardHorizontalScrollView {
        let scrollView = ClipboardHorizontalScrollView()
        let collectionView = ClipboardCollectionView()
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = NSSize(width: compact ? 190 : 250, height: (compact ? 170 : 200) + ClipboardCardMetrics.attachmentHeight)
        layout.minimumLineSpacing = ClipboardCardMetrics.spacing
        layout.minimumInteritemSpacing = ClipboardCardMetrics.spacing
        layout.sectionInset = NSEdgeInsets(top: 0, left: 18, bottom: 12, right: 18)
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColors = [.clear]
        collectionView.backgroundView = ClipboardRopeView()
        collectionView.isSelectable = false
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.onLayout = { [weak coordinator = context.coordinator] in coordinator?.refreshHoverUnderPointer() }
        collectionView.onPointerMove = { [weak coordinator = context.coordinator] in coordinator?.refreshHoverUnderPointer() }
        collectionView.onPointerExit = { [weak coordinator = context.coordinator] in coordinator?.hover.reset(to: nil) }
        collectionView.register(ClipboardCardCollectionItem.self, forItemWithIdentifier: ClipboardCardCollectionItem.identifier)

        scrollView.documentView = collectionView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.scrollerStyle = .legacy
        let scroller = ClipboardScroller()
        scroller.controlSize = .small
        scrollView.horizontalScroller = scroller
        scrollView.autohidesScrollers = false
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        context.coordinator.collectionView = collectionView
        context.coordinator.attachScrollObserver(scrollView.contentView)
        scrollView.onWindowChange = { [weak coordinator = context.coordinator] visible in
            visible ? coordinator?.startMotion() : coordinator?.stopMotion()
        }
        return scrollView
    }

    func updateNSView(_ scrollView: ClipboardHorizontalScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.actions = actions
        coordinator.resignSearch = resignSearch
        coordinator.ropeOpacity = ropeOpacity
        let sizeChanged = coordinator.compact != compact
        coordinator.compact = compact
        if sizeChanged, let layout = coordinator.collectionView?.collectionViewLayout as? NSCollectionViewFlowLayout {
            layout.itemSize = NSSize(width: compact ? 190 : 250, height: (compact ? 170 : 200) + ClipboardCardMetrics.attachmentHeight)
            layout.invalidateLayout()
        }
        let items = model.visibleItems
        let identifiers = items.map(\.id)
        let contentChanged = identifiers != coordinator.identifiers
        let oldIdentifiers = coordinator.identifiers
        let oldSelection = coordinator.selection
        let selectionChanged = oldSelection != model.selection
        coordinator.items = items
        coordinator.identifiers = identifiers
        coordinator.selection = model.selection
        if contentChanged { coordinator.noteBirths(identifiers) }
        let metricsDirty = contentChanged || sizeChanged
        if metricsDirty { coordinator.recomputeMetrics() }

        guard let collectionView = coordinator.collectionView else { return }
        let previousOffset = scrollView.contentView.bounds.origin
        if sizeChanged || oldIdentifiers.isEmpty || identifiers.isEmpty {
            collectionView.reloadData()
        } else if contentChanged {
            // 差量更新：已有 hosting 只移动不重建。reloadData 重建后 SwiftUI 内容
            // 可能来不及/不再重绘，静止光标下的点击会落在没画出来的卡片上。
            let oldIndex = Dictionary(uniqueKeysWithValues: oldIdentifiers.enumerated().map { ($0.element, $0.offset) })
            let newIndex = Dictionary(uniqueKeysWithValues: identifiers.enumerated().map { ($0.element, $0.offset) })
            let deletes = oldIdentifiers.enumerated().filter { newIndex[$0.element] == nil }.map { IndexPath(item: $0.offset, section: 0) }
            let inserts = identifiers.enumerated().filter { oldIndex[$0.element] == nil }.map { IndexPath(item: $0.offset, section: 0) }
            let moves = oldIdentifiers.enumerated().compactMap { entry -> (from: IndexPath, to: IndexPath)? in
                guard let to = newIndex[entry.element], to != entry.offset else { return nil }
                return (IndexPath(item: entry.offset, section: 0), IndexPath(item: to, section: 0))
            }
            collectionView.performBatchUpdates {
                if !deletes.isEmpty { collectionView.deleteItems(at: Set(deletes)) }
                if !inserts.isEmpty { collectionView.insertItems(at: Set(inserts)) }
                for move in moves { collectionView.moveItem(at: move.from, to: move.to) }
            } completionHandler: { [weak coordinator] _ in
                coordinator?.refreshHoverUnderPointer()
            }
        } else if selectionChanged {
            var changed: [IndexPath] = []
            if items.indices.contains(oldSelection) { changed.append(IndexPath(item: oldSelection, section: 0)) }
            if items.indices.contains(model.selection) { changed.append(IndexPath(item: model.selection, section: 0)) }
            if !changed.isEmpty { collectionView.reloadItems(at: Set(changed)) }
        }
        let contentWidth = coordinator.contentWidth
        if metricsDirty {
            collectionView.backgroundView?.frame = NSRect(x: 0, y: 0, width: contentWidth, height: 40)
            if let rope = collectionView.backgroundView as? ClipboardRopeView {
                rope.attachments = coordinator.attachments
            }
            collectionView.backgroundView?.needsDisplay = true
            collectionView.setFrameSize(NSSize(width: contentWidth, height: collectionView.frame.height))
        }
        if let rope = collectionView.backgroundView as? ClipboardRopeView, rope.opacity != CGFloat(ropeOpacity) {
            rope.opacity = CGFloat(ropeOpacity)
            rope.needsDisplay = true
        }
        scrollView.reflectScrolledClipView(scrollView.contentView)
        let hasOverflow = contentWidth > scrollView.contentSize.width + 1
        scrollView.hasHorizontalScroller = hasOverflow
        scrollView.horizontalScroller?.isEnabled = hasOverflow

        if contentChanged {
            scrollView.contentView.setBoundsOrigin(.zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        if items.indices.contains(model.selection), contentChanged || selectionChanged {
            collectionView.scrollToItems(
                at: [IndexPath(item: model.selection, section: 0)],
                scrollPosition: .centeredHorizontally
            )
        } else {
            scrollView.contentView.setBoundsOrigin(previousOffset)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        scrollView.requiredContentWidth = contentWidth
        if metricsDirty { scrollView.needsLayout = true }
        // 仅当倍率真的变化（跨屏）时才递归同步，避免每次更新的 O(图层) 开销，
        // 同时保证外接 1x / 内建 2x 都按原生倍率渲染。
        if let backing = scrollView.window?.backingScaleFactor {
            if scrollView.layer?.contentsScale != backing {
                DisplayScaling.apply(to: scrollView, scale: backing)
            }
        }
        if scrollView.window == nil { coordinator.stopMotion() }
        if contentChanged || sizeChanged || selectionChanged {
            // 等这一轮布局与滚动落定，再按光标位置重算悬停
            DispatchQueue.main.async { [weak coordinator] in coordinator?.refreshHoverUnderPointer() }
        }
    }

    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
        var model: ClipboardModuleModel
        var actions: ClipboardActions
        var compact: Bool
        var resignSearch: () -> Void
        var items: [ClipboardItem] = []
        var identifiers: [UUID] = []
        var selection = 0
        var ropeOpacity: Double = 1
        var ropeYs: [CGFloat] = []
        var attachments: [(x: CGFloat, y: CGFloat)] = []
        var contentWidth: CGFloat = 0
        let hover = ClipboardCardHover()
        weak var collectionView: NSCollectionView?

        init(model: ClipboardModuleModel, actions: ClipboardActions, compact: Bool, ropeOpacity: Double = 1, resignSearch: @escaping () -> Void) {
            self.model = model
            self.actions = actions
            self.compact = compact
            self.ropeOpacity = ropeOpacity
            self.resignSearch = resignSearch
        }

        func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            items.count
        }

        /// 一次 O(n) 预计算所有挂点/绳高/总宽，避免每个 item 再 O(n) 累加（原先 O(n²)）。
        func recomputeMetrics() {
            let total = ClipboardCardMetrics.contentWidth(for: items, compact: compact)
            contentWidth = total
            ropeYs.removeAll(keepingCapacity: true)
            attachments.removeAll(keepingCapacity: true)
            var center: CGFloat = 18
            for item in items {
                let width = ClipboardCardMetrics.width(for: item, compact: compact)
                let x = center + width / 2
                let progress = min(max((x - 18) / max(total - 36, 1), 0), 1)
                // 1x 外接屏按整像素对齐卡片纵向位置，避免亚像素渲染发虚
                let y = (6 + 16 * sin(.pi * progress)).rounded()
                ropeYs.append(y)
                attachments.append((x: x, y: y))
                center += width + ClipboardCardMetrics.spacing
            }
        }

        func ropeY(at index: Int) -> CGFloat {
            ropeYs.indices.contains(index) ? ropeYs[index] : 6
        }

        func attachmentPoints() -> [(x: CGFloat, y: CGFloat)] { attachments }

        /// 按当前光标位置重算悬停卡片：内容或滚动变化后，光标下的卡片可能已经换了一张。
        func refreshHoverUnderPointer() {
            guard let cv = collectionView, let window = cv.window else { hover.reset(to: nil); return }
            let point = cv.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            guard cv.visibleRect.contains(point),
                  let indexPath = cv.indexPathForItem(at: point),
                  items.indices.contains(indexPath.item),
                  let frame = cv.layoutAttributesForItem(at: indexPath)?.frame else { hover.reset(to: nil); return }
            let item = items[indexPath.item]
            let cardHeight = ClipboardCardMetrics.height(for: item, compact: compact)
            let card = ClipboardCardMetrics.cardFrame(in: frame, height: cardHeight, flipped: cv.isFlipped)
            hover.reset(to: card.contains(point) ? item.id : nil)
        }

        // 挂绳“微风”动效：单个 30fps 定时器驱动绳身呼吸 + 卡片绕挂点轻摆。
        // 只改 layer transform 与绳身重绘，不触发 SwiftUI 重渲染/UICollectionView reload。
        private var motionTimer: Timer?
        private var motionStart = Date.timeIntervalSinceReferenceDate
        private var scrollImpulse: CGFloat = 0
        private var birth: [UUID: TimeInterval] = [:]
        private var boundsObserver: NSObjectProtocol?
        private var lastOriginX: CGFloat = 0
        private var ropeFrame = 0

        deinit {
            motionTimer?.invalidate()
            if let observer = boundsObserver { NotificationCenter.default.removeObserver(observer) }
        }

        func startMotion() {
            guard motionTimer == nil, !Theme.reduceMotion, !CommandLine.arguments.contains("--no-motion") else { return }
            motionStart = Date.timeIntervalSinceReferenceDate
            let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tickMotion() }
            RunLoop.main.add(timer, forMode: .common)
            motionTimer = timer
        }

        func stopMotion() {
            motionTimer?.invalidate()
            motionTimer = nil
            resetTransforms()
        }

        func addScrollImpulse(_ dx: CGFloat) {
            scrollImpulse = max(-60, min(60, scrollImpulse + dx))
            startMotion()
        }

        func noteBirths(_ ids: [UUID]) {
            let now = Date.timeIntervalSinceReferenceDate
            var added = false
            for id in ids where birth[id] == nil { birth[id] = now; added = true }
            birth = birth.filter { ids.contains($0.key) }
            if added { startMotion() }
        }

        func attachScrollObserver(_ contentView: NSClipView) {
            contentView.postsBoundsChangedNotifications = true
            lastOriginX = contentView.bounds.origin.x
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification, object: contentView, queue: .main
            ) { [weak self, weak contentView] _ in
                guard let self, let contentView else { return }
                let x = contentView.bounds.origin.x
                let dx = x - self.lastOriginX
                self.lastOriginX = x
                if abs(dx) > 0.5 { self.addScrollImpulse(dx * 0.6) }
                self.refreshHoverUnderPointer()
            }
        }

        private func resetTransforms() {
            guard let cv = collectionView else { return }
            for item in cv.visibleItems() { item.view.layer?.transform = CATransform3DIdentity }
            if let rope = cv.backgroundView as? ClipboardRopeView {
                rope.sway = 0
                rope.needsDisplay = true
            }
        }

        private func tickMotion() {
            guard let cv = collectionView, let window = cv.window, window.isVisible else { stopMotion(); return }
            let t = Date.timeIntervalSinceReferenceDate
            let gust = max(0, 1 - (t - motionStart) / 1.0)
            scrollImpulse *= 0.86
            var anyDrop = false
            for item in cv.visibleItems() {
                let idx = cv.indexPath(for: item)?.item ?? 0
                let id = items.indices.contains(idx) ? items[idx].id : UUID()
                if t - (birth[id] ?? motionStart) < 0.5 { anyDrop = true; break }
            }
            // 硬上限：任何一次触发最多动画 1.5s，之后必然归位停表
            if t - motionStart > 1.5 {
                settle()
                stopMotion()
                return
            }
            // 事件驱动：无能量时归位并停表，静止态零 CPU
            guard gust > 0.01 || abs(scrollImpulse) > 0.3 || anyDrop else {
                settle()
                stopMotion()
                return
            }
            let sway = scrollImpulse * 0.06 + gust * CGFloat(sin(t * 6)) * 1.2
            ropeFrame += 1
            // 卡片 30fps、绳身 15fps（整绳重绘不断开），降低滚动期光栅化开销
            if ropeFrame % 2 == 0, let rope = cv.backgroundView as? ClipboardRopeView, abs(sway - rope.sway) > 0.12 {
                rope.sway = sway
                // 整绳重绘，避免滚动/拖动时局部重绘造成缎带断开
                rope.needsDisplay = true
            }
            for item in cv.visibleItems() {
                guard let layer = item.view.layer else { continue }
                let idx = cv.indexPath(for: item)?.item ?? 0
                let id = items.indices.contains(idx) ? items[idx].id : UUID()
                let shape = ropeYs.indices.contains(idx) ? (ropeYs[idx] - 6) / 16 : 1
                let drop = max(0, 1 - (t - (birth[id] ?? motionStart)) / 0.5)
                let dropY = -18 * drop * drop
                let dropRot = 0.035 * drop * (idx.isMultiple(of: 2) ? 1 : -1)
                let gustRot = gust * sin(Double(idx) * 1.3) * 1.5
                let scrollRot = scrollImpulse * 0.035
                let angle = CGFloat(gustRot + scrollRot) * .pi / 180 + CGFloat(dropRot)
                let ride = sway * shape + CGFloat(dropY)
                let h = layer.bounds.height
                var tr = CATransform3DIdentity
                tr = CATransform3DTranslate(tr, 0, -ride, 0)
                tr = CATransform3DTranslate(tr, 0, h / 2, 0)
                tr = CATransform3DRotate(tr, angle, 0, 0, 1)
                tr = CATransform3DTranslate(tr, 0, -h / 2, 0)
                layer.transform = tr
            }
        }

        private func settle() {
            guard let cv = collectionView else { return }
            for item in cv.visibleItems() { item.view.layer?.transform = CATransform3DIdentity }
            if let rope = cv.backgroundView as? ClipboardRopeView {
                rope.sway = 0
                rope.needsDisplay = true
            }
        }

        func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
            let item = items[indexPath.item]
            return NSSize(
                width: ClipboardCardMetrics.width(for: item, compact: compact),
                height: ClipboardCardMetrics.height(for: item, compact: compact) + ropeY(at: indexPath.item) + 6
            )
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let view = collectionView.makeItem(withIdentifier: ClipboardCardCollectionItem.identifier, for: indexPath) as! ClipboardCardCollectionItem
            let index = indexPath.item
            let item = items[index]
            view.configure(
                item: item,
                thumbnail: model.thumbnail(for: item),
                compact: compact,
                ropeY: ropeY(at: index),
                ropeOpacity: ropeOpacity,
                index: index,
                isSelected: selection == index,
                hover: hover,
                onSelect: { [weak self] in
                    self?.model.selection = index
                    self?.resignSearch()
                },
                onActivate: { [weak self] in self?.actions.activate(item) },
                onPreview: { [weak self] in self?.actions.preview(item) },
                onCopy: { [weak self] in self?.actions.copyOnly(item) },
                onPinImage: { [weak self] in self?.actions.pinImage(item) },
                onTogglePin: { [weak self] in self?.model.togglePin(item) },
                onDelete: { [weak self] in self?.model.delete(item) }
            )
            if let backing = collectionView.window?.backingScaleFactor {
                DisplayScaling.apply(to: view.view, scale: backing)
            }
            return view
        }
    }
}

private enum ClipboardKindStyle {
    static let headerText = Color.black.opacity(0.78)

    static func tint(for item: ClipboardItem) -> Color {
        if item.kind == .image { return Color(red: 0.96, green: 0.78, blue: 0.28) }
        if item.isLink { return Color(red: 0.36, green: 0.68, blue: 0.96) }
        return Color(red: 0.36, green: 0.78, blue: 0.42)
    }
}

enum ClipboardCardMetrics {
    static let spacing: CGFloat = 14
    static let attachmentHeight: CGFloat = 14

    /// 卡片本体位于 item  frame 中挂绳的下方，按视图是否翻转取对应一端。
    static func cardFrame(in itemFrame: NSRect, height: CGFloat, flipped: Bool) -> NSRect {
        NSRect(x: itemFrame.minX, y: flipped ? itemFrame.maxY - height : itemFrame.minY, width: itemFrame.width, height: height)
    }

    // 统一宽度：删除一张后，下一张的按钮要落在光标原来的位置，宽度随类型变化会对不齐
    static func width(for item: ClipboardItem, compact: Bool) -> CGFloat {
        compact ? 190 : 250
    }

    static func height(for item: ClipboardItem, compact: Bool) -> CGFloat {
        if item.isLink { return compact ? 170 : 190 }
        if item.kind == .image { return compact ? 190 : 220 }
        return compact ? 170 : 200
    }

    static func contentWidth(for items: [ClipboardItem], compact: Bool) -> CGFloat {
        guard !items.isEmpty else { return 0 }
        let nodes = items.reduce(CGFloat(0)) { $0 + width(for: $1, compact: compact) }
        return 36 + nodes + CGFloat(items.count - 1) * spacing
    }
}

private final class ClipboardRopeView: NSView {
    var attachments: [(x: CGFloat, y: CGFloat)] = []
    var opacity: CGFloat = 1
    var sway: CGFloat = 0
    override var isFlipped: Bool { true }

    private var isDark: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    override func draw(_ dirtyRect: NSRect) {
        let width = bounds.width
        guard width > 36 else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(opacity)
        defer { NSGraphicsContext.restoreGraphicsState() }
        let left: CGFloat = 18, right = width - 18, top: CGFloat = 6
        let sag: CGFloat = 26 + sway
        let c1x = width * 0.30, c2x = width * 0.70
        let coral = NSColor(srgbRed: 1.00, green: 0.43, blue: 0.38, alpha: 1)
        let violet = NSColor(srgbRed: 0.53, green: 0.32, blue: 0.91, alpha: 1)
        let teal = NSColor(srgbRed: 0.10, green: 0.76, blue: 0.72, alpha: 1)

        func curve(_ dy: CGFloat) -> NSBezierPath {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: left, y: top + dy))
            path.curve(to: NSPoint(x: right, y: top + dy), controlPoint1: NSPoint(x: c1x, y: sag + dy), controlPoint2: NSPoint(x: c2x, y: sag + dy))
            path.lineCapStyle = .round
            return path
        }

        // 柔光晕
        let halo = curve(0)
        halo.lineWidth = 9
        violet.withAlphaComponent(isDark ? 0.20 : 0.13).setStroke()
        halo.stroke()
        let halo2 = curve(0)
        halo2.lineWidth = 5
        violet.withAlphaComponent(isDark ? 0.28 : 0.18).setStroke()
        halo2.stroke()

        // 缎带：品牌珊瑚→紫→青渐变
        let half: CGFloat = 1.7
        let band = NSBezierPath()
        band.move(to: NSPoint(x: left, y: top - half))
        band.curve(to: NSPoint(x: right, y: top - half), controlPoint1: NSPoint(x: c1x, y: sag - half), controlPoint2: NSPoint(x: c2x, y: sag - half))
        band.line(to: NSPoint(x: right, y: top + half))
        band.curve(to: NSPoint(x: left, y: top + half), controlPoint1: NSPoint(x: c2x, y: sag + half), controlPoint2: NSPoint(x: c1x, y: sag + half))
        band.close()
        NSGradient(colors: [coral, violet, teal])?.draw(in: band, angle: 0)

        // 缎面高光
        let highlight = curve(-1.0)
        highlight.lineWidth = 0.7
        NSColor.white.withAlphaComponent(isDark ? 0.30 : 0.45).setStroke()
        highlight.stroke()

        // 两端光泽吊珠
        for x in [left, right] {
            let bead = NSBezierPath(ovalIn: NSRect(x: x - 4.5, y: top - 4.5, width: 9, height: 9))
            NSGradient(starting: NSColor(white: 0.96, alpha: 1), ending: violet)?.draw(in: bead, angle: -90)
            let spec = NSBezierPath(ovalIn: NSRect(x: x - 2.4, y: top - 2.8, width: 2.6, height: 2.6))
            NSColor.white.withAlphaComponent(0.85).setFill()
            spec.fill()
        }

        // 挂点金属环
        let metal = isDark ? NSColor(srgbRed: 0.82, green: 0.84, blue: 0.88, alpha: 1) : NSColor(srgbRed: 0.52, green: 0.55, blue: 0.62, alpha: 1)
        for point in attachments {
            let ky = point.y + sway * ((point.y - 6) / 16)
            let ring = NSBezierPath(ovalIn: NSRect(x: point.x - 3.0, y: ky - 3.0, width: 6, height: 6))
            ring.lineWidth = 1.5
            metal.setStroke()
            ring.stroke()
        }
    }
}

private final class ClipboardScroller: NSScroller {
    var visibleProportion: CGFloat = 1
    override var isOpaque: Bool { false }

    private var visibleKnobRect: NSRect {
        let trackWidth = max(0, bounds.width - 36)
        let knobWidth = min(trackWidth, max(42, trackWidth * visibleProportion))
        let travel = max(0, trackWidth - knobWidth)
        let knobHeight = min(6, max(3, bounds.height - 5))
        return NSRect(x: 18 + travel * doubleValue, y: (bounds.height - knobHeight) / 2, width: knobWidth, height: knobHeight)
    }

    override func rect(for part: NSScroller.Part) -> NSRect {
        part == .knob ? visibleKnobRect : super.rect(for: part)
    }

    override func draw(_ dirtyRect: NSRect) {
        drawKnobSlot(in: bounds, highlight: false)
        drawKnob()
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        let track = NSRect(x: 18, y: slotRect.midY - 1, width: max(0, slotRect.width - 36), height: 2)
        NSColor.separatorColor.withAlphaComponent(0.28).setFill()
        NSBezierPath(roundedRect: track, xRadius: 1, yRadius: 1).fill()
    }

    override func drawKnob() {
        let rect = visibleKnobRect
        guard rect.width > 0, rect.height > 0 else { return }
        let color = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.58, alpha: 0.82)
                : NSColor(white: 0.25, alpha: 0.82)
        }
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
    }
}

/// 布局落定后重算光标下的悬停卡片：reloadData 的布局不是同步完成的，
/// 只靠一次异步重算会扑空，悬停被清掉后按钮就再也不出现。
private final class ClipboardCollectionView: NSCollectionView {
    var onLayout: (() -> Void)?
    var onPointerMove: (() -> Void)?
    var onPointerExit: (() -> Void)?
    private var pointerTracking: NSTrackingArea?

    override func layout() {
        super.layout()
        onLayout?()
    }

    override func updateTrackingAreas() {
        if let pointerTracking { removeTrackingArea(pointerTracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        pointerTracking = area
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        onPointerMove?()
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        onPointerExit?()
        super.mouseExited(with: event)
    }
}

private final class ClipboardHorizontalScrollView: NSScrollView {
    var requiredContentWidth: CGFloat = 0
    var onWindowChange: ((Bool) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        syncScale()
        onWindowChange?(window != nil)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        syncScale()
    }

    private func syncScale() {
        guard let scale = window?.backingScaleFactor else { return }
        DisplayScaling.apply(to: self, scale: scale)
    }

    override func layout() {
        super.layout()
        let viewport = contentSize.width
        let hasOverflow = viewport > 0 && requiredContentWidth > viewport + 1
        if hasHorizontalScroller != hasOverflow { hasHorizontalScroller = hasOverflow }
        let proportion = hasOverflow ? viewport / requiredContentWidth : 1
        horizontalScroller?.isEnabled = hasOverflow
        horizontalScroller?.knobProportion = proportion
        (horizontalScroller as? ClipboardScroller)?.visibleProportion = proportion
        horizontalScroller?.needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        window?.makeKey()
        if abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY) {
            super.scrollWheel(with: event)
            return
        }
        guard let documentView else { return }
        let maximum = max(0, documentView.bounds.width - contentView.bounds.width)
        guard maximum > 0 else { return }
        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 18
        let current = contentView.bounds.origin.x
        let next = min(max(0, current - event.scrollingDeltaY * multiplier), maximum)
        contentView.setBoundsOrigin(NSPoint(x: next, y: 0))
        reflectScrolledClipView(contentView)
    }
}

private final class ClipboardCardCollectionItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("ClipboardCard")
    private var hosting: ScaledHostingView<ClipboardHangingCard>?

    override func loadView() {
        view = NSView()
    }

    func configure(
        item: ClipboardItem,
        thumbnail: NSImage?,
        compact: Bool,
        ropeY: CGFloat,
        ropeOpacity: Double,
        index: Int,
        isSelected: Bool,
        hover: ClipboardCardHover,
        onSelect: @escaping () -> Void,
        onActivate: @escaping () -> Void,
        onPreview: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onPinImage: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        let card = ClipboardCard(
            item: item,
            thumbnail: thumbnail,
            compact: compact,
            index: index,
            isSelected: isSelected,
            hover: hover,
            onSelect: onSelect,
            onActivate: onActivate,
            onPreview: onPreview,
            onCopy: onCopy,
            onPinImage: onPinImage,
            onTogglePin: onTogglePin,
            onDelete: onDelete
        )
        let hanging = ClipboardHangingCard(card: card, tint: ClipboardKindStyle.tint(for: item), ropeY: ropeY, opacity: ropeOpacity)
        if let hosting {
            hosting.rootView = hanging
            return
        }
        let hosting = ScaledHostingView(rootView: hanging)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        self.hosting = hosting
    }
}

private struct ClipboardHangingCard: View {
    let card: ClipboardCard
    let tint: Color
    let ropeY: CGFloat
    var opacity: Double = 1

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.primary.opacity(0.38))
                    .frame(width: 1.2, height: ropeY + 4)
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(tint)
                    .frame(width: 12, height: 13)
                    .overlay(RoundedRectangle(cornerRadius: 2.5).strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5))
                    .overlay(Circle().fill(Color.white.opacity(0.55)).frame(width: 2.2, height: 2.2).offset(y: -2))
                    .offset(y: ropeY - 3)
            }
            .frame(height: ropeY + 6)
            .opacity(opacity)
            card
        }
    }
}

struct ClipboardCard: View {
    let item: ClipboardItem
    let thumbnail: NSImage?
    let compact: Bool
    let index: Int
    let isSelected: Bool
    @ObservedObject var hover: ClipboardCardHover
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onPreview: () -> Void
    let onCopy: () -> Void
    let onPinImage: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    private var hovering: Bool { hover.id == item.id }
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            content
            cardFooter
        }
        .frame(width: ClipboardCardMetrics.width(for: item, compact: compact), height: ClipboardCardMetrics.height(for: item, compact: compact))
        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.elevatedCard))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(
                    isSelected ? ClipboardKindStyle.tint(for: item) : (hovering ? ClipboardKindStyle.tint(for: item).opacity(0.55) : Color.primary.opacity(0.12)),
                    lineWidth: isSelected ? 1.5 : 0.7
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Theme.elevatedCard)
                .shadow(color: isSelected ? ClipboardKindStyle.tint(for: item).opacity(0.28) : Color.black.opacity(scheme == .dark ? 0.18 : 0.10), radius: isSelected ? 8 : 6, y: isSelected ? 5 : 3)
        )
        .modifier(HangingTransform(hovering: hovering, isSelected: isSelected, index: index))
        .animation(Theme.motion(.spring(response: 0.28, dampingFraction: 0.6)), value: hovering)
        .animation(Theme.motion(.spring(response: 0.22, dampingFraction: 0.8)), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onActivate)
        .onTapGesture(count: 1, perform: onSelect)
        .contextMenu {
            Button(loc("粘贴 / 复制", "Paste / Copy"), action: onActivate)
            Button(loc("预览", "Preview"), action: onPreview)
            Button(loc("仅复制", "Copy Only"), action: onCopy)
            Button(item.isPinned ? loc("取消收藏", "Unpin") : loc("收藏", "Pin"), action: onTogglePin)
            if item.kind == .image { Button(loc("贴图到屏幕", "Pin to Screen"), action: onPinImage) }
            Divider()
            Button(loc("删除", "Delete"), role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(loc("\(index + 1) \(item.preview) \(item.sourceApp ?? "剪贴板")", "\(index + 1). \(item.preview) from \(item.sourceApp ?? "Clipboard")"))
        .accessibilityAction { onSelect() }
        .accessibilityAction(named: loc("粘贴 / 复制", "Paste / Copy"), onActivate)
        .accessibilityAction(named: loc("预览", "Preview"), onPreview)
        .accessibilityAction(named: item.isPinned ? loc("取消收藏", "Unpin") : loc("收藏", "Pin"), onTogglePin)
    }

    private var kindTitle: String {
        if item.kind == .image { return loc("图片", "Image") }
        return item.isLink ? loc("链接", "Link") : loc("文本", "Text")
    }

    private var contentHeight: CGFloat {
        ClipboardCardMetrics.height(for: item, compact: compact) - (compact ? 52 : 56) - (compact ? 42 : 48)
    }

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(kindTitle)
                    .font(.system(size: 12, weight: .semibold))
                Text(RelativeTime.string(for: item.createdAt))
                    .font(.system(size: 10))
                    .opacity(0.78)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                AppIconView(bundleID: item.sourceBundleID, name: item.sourceApp ?? loc("剪贴板", "Clipboard"), size: 22)
                Text(item.sourceApp ?? loc("剪贴板", "Clipboard"))
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(ClipboardKindStyle.headerText)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(height: compact ? 52 : 56)
        .frame(maxWidth: .infinity)
        .background(ClipboardKindStyle.tint(for: item))
    }

    @ViewBuilder
    private var content: some View {
        if item.kind == .image {
            ZStack {
                Checkerboard()
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Theme.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: contentHeight)
            .clipped()
        } else if item.isLink {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    IconTile(symbol: "link", tint: Theme.accent, size: 30)
                    Text(item.linkHost ?? loc("链接", "Link"))
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .foregroundStyle(Theme.label)
                        .lineLimit(2)
                }
                Text(item.text ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(4)
                    .textSelection(.disabled)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .frame(height: contentHeight, alignment: .topLeading)
        } else {
            Text(item.text ?? "")
                .font(.system(size: compact ? 12 : 13))
                .foregroundStyle(Theme.label)
                .lineSpacing(compact ? 3 : 4)
                .lineLimit(compact ? 6 : 7)
                .textSelection(.disabled)
                .padding(14)
                .frame(maxWidth: .infinity)
                .frame(height: contentHeight, alignment: .topLeading)
        }
    }

    private var cardFooter: some View {
        HStack(spacing: 4) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.secondary)
                .frame(width: 16, alignment: .leading)
            Text(footerMeta)
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            // 操作按钮常驻：若只在悬停时插入视图树，静止光标下的点击会落在按钮出现/消失的间隙里
            HStack(spacing: 4) {
                ToolButton(symbol: "eye", help: loc("预览 (Space)", "Preview (Space)"), size: 23, action: onPreview)
                ToolButton(symbol: "doc.on.doc", help: loc("仅复制", "Copy Only"), size: 23, action: onCopy)
                ToolButton(symbol: "trash", help: loc("删除", "Delete"), size: 23, action: onDelete)
            }
            .opacity(hovering || isSelected ? 1 : 0.45)
            ToolButton(symbol: item.isPinned ? "star.fill" : "star", help: item.isPinned ? loc("取消收藏", "Unpin") : loc("收藏", "Pin"), tint: item.isPinned ? Theme.workday : Theme.tertiary, size: 23, action: onTogglePin)
                .opacity(hovering || item.isPinned || isSelected ? 1 : 0.45)
        }
        .padding(.horizontal, 12)
        .frame(height: compact ? 42 : 48)
        .animation(Theme.motion(.easeOut(duration: 0.1)), value: hovering)
    }

    private var footerMeta: String {
        if item.kind == .image { return "\(item.imageWidth ?? 0) × \(item.imageHeight ?? 0)" }
        return loc("\(item.characterCount) 字符", item.characterCount == 1 ? "1 char" : "\(item.characterCount) chars")
    }
}

struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 8
            for y in stride(from: CGFloat(0), to: size.height, by: step) {
                for x in stride(from: CGFloat(0), to: size.width, by: step) {
                    let alternate = (Int(x / step) + Int(y / step)) % 2 == 0
                    context.fill(Path(CGRect(x: x, y: y, width: step, height: step)), with: .color(Color.primary.opacity(alternate ? 0.04 : 0.02)))
                }
            }
        }
    }
}

/// 仅在悬停/选中时应用变换，静止态不创建变换层，避免 1x 屏上文字被光栅化发虚。
private struct HangingTransform: ViewModifier {
    let hovering: Bool
    let isSelected: Bool
    let index: Int

    func body(content: Content) -> some View {
        if hovering || isSelected {
            content
                .scaleEffect(isSelected ? 1.025 : 1)
                .rotationEffect(.degrees(hovering && !isSelected ? (index.isMultiple(of: 2) ? 1.4 : -1.4) : 0), anchor: .top)
        } else {
            content
        }
    }
}
