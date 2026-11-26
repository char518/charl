import AppKit
import Foundation
import SwiftUI
import os

private let panelLog = Logger(subsystem: "com.charl.charl", category: "panel")

enum PanelPlacement {
    case center, bottom, top
}

final class UtilityPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelController: NSObject, NSWindowDelegate {
    private let panel: UtilityPanel
    private let resizable: Bool
    private var preferredSize: NSSize?
    private var monitor: Any?
    private var mouseInside = false
    private var rekeyTimer: Timer?
    var onKey: ((NSEvent) -> Bool)?
    var onClose: (() -> Void)?
    var keepsOpenOnResign = false

    init<V: View>(title: String, content: V, size: NSSize, resizable: Bool = false) {
        self.resizable = resizable
        // 不用 .nonactivatingPanel：真实滚轮按“激活 App”路由，非激活面板会让
        // 滚轮落到背后激活的窗口上。改为激活式面板，打开即激活 charl 并保持。
        var style: NSWindow.StyleMask = [.borderless]
        if resizable { style.insert(.resizable) }
        panel = UtilityPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: style, backing: .buffered, defer: false)
        super.init()
        panel.title = title
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = !resizable
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        if resizable {
            panel.minSize = NSSize(width: min(720, size.width), height: 240)
        }
        let hosting = ScaledHostingView(rootView: content.overlay(alignment: .bottomTrailing) {
            if resizable {
                Image(systemName: "line.3.diagonal")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.tertiary)
                    .padding(5)
                    .allowsHitTesting(false)
            }
        })
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = Theme.panelRadius
        hosting.layer?.masksToBounds = true
        hosting.layer?.borderWidth = resizable ? 0 : 0.5
        hosting.layer?.borderColor = NSColor.separatorColor.cgColor
        panel.contentView = hosting
        hosting.addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
        DisplayScaling.apply(to: panel)
    }

    // 滚轮事件只发给 key window；指针在面板内期间持续保持持焦（不激活 App），
    // 否则滚轮会落到背后处于激活态的窗口上（卡片间隙 likewise）。
    func mouseEntered(with event: NSEvent) {
        mouseInside = true
        rekey()
        if rekeyTimer == nil {
            rekeyTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                self?.rekey()
            }
        }
    }

    func mouseMoved(with event: NSEvent) {
        rekey()
    }

    func mouseExited(with event: NSEvent) {
        mouseInside = false
        rekeyTimer?.invalidate()
        rekeyTimer = nil
    }

    private func rekey() {
        guard mouseInside, panel.isVisible else { return }
        // 真实滚轮按“激活 App”路由；仅 makeKey 不够，悬停时需激活 charl。
        if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
        if !panel.isKeyWindow { panel.makeKeyAndOrderFront(nil) }
    }

    var isVisible: Bool { panel.isVisible }
    func focus() { if panel.isVisible { panel.makeKeyAndOrderFront(nil) } }

    func resetPreferredSize() {
        preferredSize = nil
    }

    func show(on screen: NSScreen, size: NSSize, placement: PanelPlacement) {
        let visible = screen.visibleFrame
        var requested = preferredSize ?? size
        requested.width = min(max(requested.width, panel.minSize.width), visible.width - 32)
        requested.height = min(max(requested.height, panel.minSize.height), visible.height - 48)
        preferredSize = requested
        let y: CGFloat
        switch placement {
        case .bottom: y = visible.minY
        case .top: y = visible.maxY - requested.height - 16
        case .center: y = visible.midY - requested.height / 2 + 64
        }
        let frame = NSRect(x: visible.midX - requested.width / 2, y: y, width: requested.width, height: requested.height)
        panel.setFrame(frame, display: true)
        DisplayScaling.apply(to: panel)
        panelLog.notice("show screen=\(screen.frame.debugDescription, privacy: .public) mouse=\(NSStringFromPoint(NSEvent.mouseLocation), privacy: .public) backing=\(self.panel.backingScaleFactor) contentScale=\(self.panel.contentView?.layer?.contentsScale ?? -1)")
        NSApp.activate(ignoringOtherApps: true)
        panel.alphaValue = Theme.reduceMotion ? 1 : 0
        panel.makeKeyAndOrderFront(nil)
        if !Theme.reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                panel.animator().alphaValue = 1
            }
        }
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, event.window === self.panel else { return event }
                return self.onKey?(event) == true ? nil : event
            }
        }
    }

    func close() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        mouseInside = false
        rekeyTimer?.invalidate()
        rekeyTimer = nil
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        onClose?()
    }

    func windowDidResize(_ notification: Notification) {
        if resizable && panel.isVisible { preferredSize = panel.frame.size }
    }

    func windowDidChangeScreen(_ notification: Notification) {
        DisplayScaling.apply(to: panel)
    }

    func windowDidChangeBackingProperties(_ notification: Notification) {
        DisplayScaling.apply(to: panel)
    }

    func windowDidResignKey(_ notification: Notification) {
        if keepsOpenOnResign { return }
        // 焦点转到 charl 自己的窗口（如截图遮罩）时保持打开；点到其它 App 才关闭
        if NSApp.keyWindow != nil { return }
        close()
    }
}
