import AppKit
import CharlCore
import SwiftUI

public final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private weak var model: AppModel?

    public init(model: AppModel) { self.model = model; super.init() }

    public func show() {
        guard let model else { return }
        if window == nil {
            let value = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 540), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            value.contentView = NSHostingView(rootView: SettingsView(model: model))
            value.isReleasedWhenClosed = false
            value.delegate = self
            value.center()
            window = value
        }
        window?.title = loc("charl 设置", "charl Settings")
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if let window { DisplayScaling.apply(to: window) }
    }

    public func windowDidChangeScreen(_ notification: Notification) {
        if let window { DisplayScaling.apply(to: window) }
    }

    public func windowDidChangeBackingProperties(_ notification: Notification) {
        if let window { DisplayScaling.apply(to: window) }
    }

    public func windowWillClose(_ notification: Notification) { model?.cancelRecording() }
    public func windowDidResignKey(_ notification: Notification) { model?.cancelRecording() }
}
