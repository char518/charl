import AppKit
import CharlCore

private final class PinnedPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PinWindowController: NSObject, NSWindowDelegate {
    private var windows: [NSWindow] = []

    func show(image: NSImage) {
        let window = PinnedPanel(contentRect: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height), styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        window.title = "charl Pin"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentAspectRatio = image.size
        window.delegate = self
        let view = PinnedImageView(image: image)
        window.contentView = view
        let scale = min(1, 800 / max(image.size.width, image.size.height))
        window.setContentSize(NSSize(width: image.size.width * scale, height: image.size.height * scale))
        window.center()
        windows.append(window)
        window.alphaValue = Theme.reduceMotion ? 1 : 0
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        DisplayScaling.apply(to: window)
        if !Theme.reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                window.animator().alphaValue = 1
            }
        }
    }

    func closeAll() {
        let values = windows
        values.forEach { $0.close() }
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow { windows.removeAll { $0 === window } }
    }
}

private final class PinnedImageView: NSView {
    let image: NSImage
    init(image: NSImage) { self.image = image; super.init(frame: NSRect(origin: .zero, size: image.size)) }
    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds)
        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()
    }
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { window?.close() } else { window?.performDrag(with: event) }
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { window?.close() }
        else if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" { copyImage() }
        else { super.keyDown(with: event) }
    }
    override func scrollWheel(with event: NSEvent) {
        guard let window else { return }
        if event.modifierFlags.contains(.option) {
            window.alphaValue = min(1, max(0.15, window.alphaValue + Double(event.scrollingDeltaY) * 0.01))
        } else {
            let ratio = max(0.9, min(1.1, 1 + event.scrollingDeltaY * 0.012))
            let current = window.frame.size
            let width = min(1800, max(40, current.width * ratio))
            let height = width * image.size.height / image.size.width
            let frame = NSRect(x: window.frame.midX - width / 2, y: window.frame.midY - height / 2, width: width, height: height)
            window.setFrame(frame, display: true)
        }
    }
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem(title: loc("复制图片", "Copy Image")) { [weak self] in self?.copyImage() })
        menu.addItem(ClosureMenuItem(title: loc("保存图片…", "Save Image…")) { [weak self] in self?.saveImage() })
        menu.addItem(ClosureMenuItem(title: loc("恢复原始大小", "Actual Size")) { [weak self] in
            guard let self else { return }; self.window?.setContentSize(self.image.size)
        })
        menu.addItem(ClosureMenuItem(title: loc("不透明", "Opaque")) { [weak self] in self?.window?.alphaValue = 1 })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: loc("关闭贴图", "Close Pin")) { [weak self] in self?.window?.close() })
        return menu
    }
    private func copyImage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
    private func saveImage() {
        guard let data = image.tiffRepresentation, let rep = NSBitmapImageRep(data: data), let png = rep.representation(using: .png, properties: [:]) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "charl-pin.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try png.write(to: url) } catch { NSAlert(error: error).runModal() }
    }
}
