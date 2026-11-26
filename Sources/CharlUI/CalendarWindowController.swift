import AppKit
import CharlCore
import QuartzCore
import SwiftUI

/// 日历锚定菜单栏，背景采用原生毛玻璃（可切更透明/纯色）；
/// 强调色只作用于今天、选中与按钮等高亮。
final class CalendarWindowController: NSObject, NSWindowDelegate {
    private var panel: UtilityPanel?
    private var blur: NSVisualEffectView?
    private var solid: NSView?
    private var borderLayer: CAShapeLayer?
    private var hosting: NSHostingView<CalendarPopoverView>?
    private var escMonitor: Any?
    private weak var model: AppModel?
    var keepsOpenOnResign = false
    private var anchorRect: NSRect?
    private var anchorVisible: NSRect?

    var isShown: Bool { panel?.isVisible ?? false }

    func show(anchor: NSView, model: AppModel, selecting day: Day?, screen preferredScreen: NSScreen? = nil) {
        self.model = model
        if panel == nil { build(model: model) }
        guard let panel, let hosting else { return }

        model.calendar.onOpen()
        let fontSize = Double(model.settingsModel.settings.calendarFontSize)
        let width = 320 * CGFloat(fontSize) / 13.0
        hosting.rootView = CalendarPopoverView(
            model: model.calendar,
            palette: model.settingsModel.settings.calendarPalette,
            customAccent: Color(hex: model.settingsModel.settings.calendarAccentHex),
            onContentChange: { [weak self] in self?.fitToContent() },
            fontSize: fontSize
        )
        if let day { model.calendar.select(day) }

        // 先按原生倍率测量，避免上一次超采样(2x)的 contentsScale 影响 fittingSize，
        // 导致外接 1x 屏重复打开时尺寸/字体越变越小。
        hosting.wantsLayer = true
        hosting.layer?.contentsScale = panel.backingScaleFactor
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: 10)
        hosting.layoutSubtreeIfNeeded()
        let fit = hosting.fittingSize
        let size = NSSize(width: width, height: max(fit.height, 10))
        panel.setContentSize(size)
        let bounds = NSRect(origin: .zero, size: size)
        blur?.frame = bounds
        solid?.frame = bounds
        hosting.frame = bounds
        applyBackground(model.settingsModel.settings.calendarBackground, bounds: bounds)

        // 锚定到状态项下方：状态按钮的 window 可能尚未就绪，就绪后再定位，避免落到屏幕左下角。
        positionPanel(anchor: anchor, size: size, preferredScreen: preferredScreen, retries: 8)
        applyNativeScale()

        NSApp.activate(ignoringOtherApps: true)
        panel.alphaValue = Theme.reduceMotion ? 1 : 0
        panel.makeKeyAndOrderFront(nil)
        if !Theme.reduceMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.16
                panel.animator().alphaValue = 1
            }
        }
        installEsc()
    }

    private func positionPanel(anchor: NSView, size: NSSize, preferredScreen: NSScreen?, retries: Int) {
        if let resolved = resolveAnchor(anchor: anchor, preferredScreen: preferredScreen) {
            anchorRect = resolved.rect
            anchorVisible = resolved.visible
            place(size: size)
            // 菜单栏布局完成后再次贴合真实图标位置
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak anchor] in
                guard let self, let anchor, self.panel?.isVisible == true else { return }
                if let again = self.resolveAnchor(anchor: anchor, preferredScreen: preferredScreen) {
                    self.anchorRect = again.rect
                    self.anchorVisible = again.visible
                    self.place(size: self.panel?.frame.size ?? size)
                }
            }
            return
        }
        guard retries > 0 else { return }
        DispatchQueue.main.async { [weak self, weak anchor] in
            guard let self, let anchor else { return }
            self.positionPanel(anchor: anchor, size: size, preferredScreen: preferredScreen, retries: retries - 1)
        }
    }

    /// 状态项 window 在启动早期可能尚未定位（frame 在原点），依次回退：
    /// 有效的状态窗口 frame → 鼠标位于菜单栏（点击图标场景）→ 屏幕右上兜底。
    private func resolveAnchor(anchor: NSView, preferredScreen: NSScreen?) -> (rect: NSRect, visible: NSRect)? {
        let thickness = NSStatusBar.system.thickness
        if let preferred = preferredScreen {
            if let window = anchor.window, window.screen == preferred,
               window.frame.width > 1, window.frame.height > 1,
               abs(window.frame.maxY - preferred.frame.maxY) < thickness + 2 {
                return (window.frame, preferred.visibleFrame)
            }
            let rect = NSRect(x: preferred.visibleFrame.maxX - 44, y: preferred.frame.maxY - thickness, width: 44, height: thickness)
            return (rect, preferred.visibleFrame)
        }
        if let window = anchor.window {
            let frame = window.frame
            if frame.width > 1, frame.height > 1,
               let screen = window.screen ?? NSScreen.main,
               abs(frame.maxY - screen.frame.maxY) < thickness + 2 {
                return (frame, screen.visibleFrame)
            }
        }
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }),
           mouse.y >= screen.frame.maxY - thickness - 2 {
            let rect = NSRect(x: mouse.x - 20, y: screen.frame.maxY - thickness, width: 40, height: thickness)
            return (rect, screen.visibleFrame)
        }
        if let screen = preferredScreen ?? NSScreen.main {
            let rect = NSRect(x: screen.visibleFrame.maxX - 44, y: screen.frame.maxY - thickness, width: 44, height: thickness)
            return (rect, screen.visibleFrame)
        }
        return nil
    }

    /// 日历始终按屏幕原生倍率渲染（不做超采样），保证跨屏/重复打开字体尺寸稳定。
    private func applyNativeScale() {
        guard let panel, let content = panel.contentView else { return }
        DisplayScaling.apply(to: content, scale: panel.backingScaleFactor)
    }

    private func place(size: NSSize) {
        guard let panel, let origin = origin(for: size) else { return }
        panel.setFrameOrigin(origin)
    }

    private func origin(for size: NSSize) -> NSPoint? {
        guard let anchorRect else { return nil }
        let visible = anchorVisible ?? .zero
        // 水平居中对齐图标正下方，纵向锚在菜单栏下；夹在屏幕可见区内。
        var x = anchorRect.midX - size.width / 2
        var y = anchorRect.minY - size.height - 6
        x = min(max(visible.minX + 8, x), visible.maxX - size.width - 8)
        y = min(max(visible.minY + 8, y), visible.maxY - size.height - 8)
        return NSPoint(x: x, y: y)
    }

    /// 详情展开/收起、换月或字体变化后平滑贴合内容，避免窗口突然跳动。
    private func fitToContent() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel, let hosting = self.hosting else { return }
            let width = 320 * CGFloat(self.model?.settingsModel.settings.calendarFontSize ?? 13) / 13.0
            hosting.wantsLayer = true
            hosting.layer?.contentsScale = panel.backingScaleFactor
            hosting.layoutSubtreeIfNeeded()
            let fit = hosting.fittingSize
            let size = NSSize(width: width, height: max(fit.height, 10))
            let background = self.model?.settingsModel.settings.calendarBackground ?? .native
            self.applyBackground(background, bounds: NSRect(origin: .zero, size: size))
            applyNativeScale()
            guard abs(panel.frame.height - size.height) > 0.5 || abs(panel.frame.width - size.width) > 0.5 else { return }
            let frame = NSRect(origin: self.origin(for: size) ?? panel.frame.origin, size: size)
            if Theme.reduceMotion {
                panel.setFrame(frame, display: true)
            } else {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.18
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(frame, display: true)
                }
            }
        }
    }

    private func applyBackground(_ background: CalendarBackground, bounds: NSRect) {
        blur?.isHidden = false
        solid?.isHidden = background != .solid
        switch background {
        case .native, .solid:
            blur?.material = .popover
            blur?.alphaValue = 1
        case .clear:
            blur?.material = .underWindowBackground
            blur?.alphaValue = 0.55
        }
        if let borderLayer {
            if background == .clear {
                borderLayer.isHidden = true
            } else {
                borderLayer.isHidden = false
                borderLayer.frame = bounds
                let inset: CGFloat = 0.25
                borderLayer.path = CGPath(
                    roundedRect: bounds.insetBy(dx: inset, dy: inset),
                    cornerWidth: 18 - inset,
                    cornerHeight: 18 - inset,
                    transform: nil
                )
            }
        }
    }

    func close() {
        removeEsc()
        panel?.orderOut(nil)
    }

    private func build(model: AppModel) {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.masksToBounds = true

        let blur = NSVisualEffectView()
        blur.material = .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.alphaValue = 1
        blur.frame = container.bounds
        blur.autoresizingMask = [.width, .height]
        container.addSubview(blur)

        let solid = SolidBackgroundView()
        solid.isHidden = true
        solid.frame = container.bounds
        solid.autoresizingMask = [.width, .height]
        container.addSubview(solid)

        let hosting = ScaledHostingView(rootView: CalendarPopoverView(model: model.calendar))
        hosting.minimumScale = 1
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)

        let borderLayer = CAShapeLayer()
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.strokeColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        borderLayer.lineWidth = 0.5
        container.layer?.addSublayer(borderLayer)

        let panel = UtilityPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 10), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = container
        panel.delegate = self

        self.panel = panel
        self.blur = blur
        self.solid = solid
        self.borderLayer = borderLayer
        self.hosting = hosting
    }

    private func installEsc() {
        guard escMonitor == nil else { return }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53, self.panel?.isKeyWindow == true else { return event }
            self.close()
            return nil
        }
    }

    private func removeEsc() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor); self.escMonitor = nil }
    }

    func windowDidChangeScreen(_ notification: Notification) {
        applyNativeScale()
    }

    func windowDidChangeBackingProperties(_ notification: Notification) {
        applyNativeScale()
    }

    func windowDidResignKey(_ notification: Notification) {
        if keepsOpenOnResign { return }
        // 焦点转到 charl 自己的窗口（如截图遮罩）时保持打开；点到其它 App 才关闭
        if NSApp.keyWindow != nil { return }
        close()
    }
}

/// 纯色叠加层：在原生玻璃上加一层很薄的亮/暗罩，让「纯色」比毛玻璃更实一点，
/// 观感接近系统控制中心模块（浅色近白玻璃），并随明暗模式更新。
private final class SolidBackgroundView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateColor()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColor()
    }

    private func updateColor() {
        wantsLayer = true
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.backgroundColor = (dark
            ? NSColor(white: 0, alpha: 0.16).cgColor
            : NSColor(white: 1, alpha: 0.14).cgColor)
    }
}
