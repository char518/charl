import AppKit
import Combine
import CharlCore
import CharlPlatform
import QuartzCore
import SwiftUI
import os

private let captureLog = Logger(subsystem: "com.charl.charl", category: "screenshot")

private enum CaptureDestination { case copy, save, pin }

private final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

public final class ScreenshotController {
    private let service: ScreenshotService
    private let toast: Toast
    private let settings: () -> AppSettings
    private let onPin: (NSImage) -> Void
    private var panel: CapturePanel?
    private var canvas: ScreenshotCanvas?
    private var isCapturing = false
    private var keyMonitor: Any?
    var onCaptureEnd: (() -> Void)?

    init(service: ScreenshotService, toast: Toast, settings: @escaping () -> AppSettings, onPin: @escaping (NSImage) -> Void) {
        self.service = service
        self.toast = toast
        self.settings = settings
        self.onPin = onPin
    }

    private var mouseScreen: NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    public func captureRegion() {
        guard !isCapturing, panel == nil, let screen = mouseScreen else { return }
        let allowed = service.hasPermission()
        captureLog.notice("region requested permission=\(allowed)")
        guard allowed else {
            let granted = service.requestPermission()
            captureLog.notice("permission request result=\(granted)")
            toast.show(loc("请在系统设置 → 屏幕录制中允许 charl，再重试", "Allow charl in System Settings → Privacy & Security → Screen Recording, then try again"), symbol: "exclamationmark.triangle")
            return
        }
        isCapturing = true
        captureLog.notice("capture screen=\(screen.frame.debugDescription) scale=\(screen.backingScaleFactor) mouse=\(NSStringFromPoint(NSEvent.mouseLocation))")
        guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { return }
        Task { @MainActor in
            defer { self.isCapturing = false }
            do {
                let frame = try await self.service.captureFrame(displayID: id)
                captureLog.notice("frame captured \(frame.pixelWidth)x\(frame.pixelHeight)")
                let windows = self.service.visibleWindows(displayID: id, excludingProcess: Int32(ProcessInfo.processInfo.processIdentifier))
                self.present(frame: frame, screen: screen, windows: windows)
            } catch {
                captureLog.error("capture failed: \(error.localizedDescription, privacy: .public)")
                self.toast.show(error.localizedDescription, symbol: "exclamationmark.triangle")
            }
        }
    }

    public func captureFullScreen() {
        guard !isCapturing, let screen = mouseScreen else { return }
        guard service.hasPermission() else { _ = service.requestPermission(); toast.show(loc("请授权屏幕录制后重试", "Grant Screen Recording permission, then try again"), symbol: "exclamationmark.triangle"); return }
        isCapturing = true
        guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { return }
        Task { @MainActor in
            defer { self.isCapturing = false }
            do {
                let data = try await self.service.capture(displayID: id, region: nil)
                if let image = NSImage(data: data) { self.deliver(image: image, destination: .copy) }
            } catch { self.toast.show(error.localizedDescription, symbol: "exclamationmark.triangle") }
        }
    }

    func present(frame: ScreenFrame, screen: NSScreen, windows: [DetectedWindow]) {
        let state = CaptureState()
        let view = ScreenshotCanvas(frame: frame, state: state, windows: windows, magnifier: settings().showMagnifier)
        view.wantsLayer = true
        view.layer?.contentsScale = screen.backingScaleFactor
        let panel = CapturePanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "charl Capture"
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.alphaValue = 1
        panel.contentView = view
        panel.acceptsMouseMovedEvents = true
        view.setPointerFromScreen(NSEvent.mouseLocation)
        view.onCancel = { [weak self] in self?.dismiss() }
        view.onConfirm = { [weak self] in self?.finish(.copy) }
        view.onColorCopy = { [weak self] hex in self?.toast.show(loc("已复制色值 \(hex)", "Color copied: \(hex)"), symbol: "paintpalette") }
        let toolbar = CaptureToolbarView(state: state, undo: { [weak view] in view?.undo() }, cancel: { [weak self] in self?.dismiss() }, pin: { [weak self] in self?.finish(.pin) }, save: { [weak self] in self?.finish(.save) }, copy: { [weak self] in self?.finish(.copy) })
        toolbar.frame = CGRect(x: 0, y: 0, width: 680, height: 52)
        toolbar.isHidden = true
        view.addSubview(toolbar)
        view.onSelection = { [weak toolbar, weak view] rect in
            guard let toolbar, let view else { return }
            let x = min(max(8, rect.maxX - toolbar.frame.width), max(8, view.bounds.width - toolbar.frame.width - 8))
            let y = rect.maxY + toolbar.frame.height + 10 < view.bounds.height ? rect.maxY + 8 : max(8, rect.minY - toolbar.frame.height - 8)
            toolbar.setFrameOrigin(CGPoint(x: x, y: y))
            toolbar.isHidden = false
        }
        self.panel = panel
        self.canvas = view
        DisplayScaling.apply(to: panel)
        NSApp.activate(ignoringOtherApps: true)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(view)
        CATransaction.commit()
        DispatchQueue.main.async { [weak panel, weak view] in
            guard let panel, let view else { return }
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(view)
            DisplayScaling.apply(to: panel)
            captureLog.notice("selection panel visible=\(panel.isVisible) key=\(panel.isKeyWindow)")
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel, weak view] event in
            guard let self, event.window === panel else { return event }
            if event.keyCode == 53 { self.dismiss(); return nil }
            if event.keyCode == 36 || (event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" && view?.selection != nil) { self.finish(.copy); return nil }
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "z" { view?.undo(); return nil }
            return event
        }
    }

    private func dismiss() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        panel?.orderOut(nil)
        panel = nil
        canvas = nil
        onCaptureEnd?()
    }

    private func finish(_ destination: CaptureDestination) {
        guard let image = canvas?.result() else { return }
        dismiss()
        deliver(image: image, destination: destination)
    }

    private func deliver(image: NSImage, destination: CaptureDestination) {
        if destination == .pin { onPin(image); return }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
            toast.show(loc("图片编码失败", "Failed to encode the image"), symbol: "exclamationmark.triangle"); return
        }
        if destination == .save {
            let save = NSSavePanel()
            save.nameFieldStringValue = filename()
            guard save.runModal() == .OK, let url = save.url else { return }
            do { try png.write(to: url); toast.show(loc("已保存图片", "Image saved")) }
            catch { NSAlert(error: error).runModal() }
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        guard settings().saveScreenshotsToDisk else { toast.show(loc("已复制截图", "Screenshot copied")); return }
        do {
            let directory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0].appendingPathComponent(AppConfig.screenshotDirectoryName)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: directory.appendingPathComponent(filename()))
            toast.show(loc("已复制，并保存到 图片/charl", "Copied and saved to Pictures/charl"))
        } catch { toast.show(loc("已复制，但保存失败：\(error.localizedDescription)", "Copied, but saving failed: \(error.localizedDescription)"), symbol: "exclamationmark.triangle") }
    }

    private func filename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        return "charl_" + formatter.string(from: Date()) + ".png"
    }
}

final class CaptureToolbarView: NSView {
    private let hosting: ScaledHostingView<CaptureToolbarContent>

    init(state: CaptureState, undo: @escaping () -> Void, cancel: @escaping () -> Void, pin: @escaping () -> Void, save: @escaping () -> Void, copy: @escaping () -> Void) {
        hosting = ScaledHostingView(rootView: CaptureToolbarContent(state: state, undo: undo, cancel: cancel, pin: pin, save: save, copy: copy))
        super.init(frame: NSRect(x: 0, y: 0, width: 680, height: 52))
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize { NSSize(width: 680, height: 52) }
}

private struct CaptureToolbarContent: View {
    @ObservedObject var state: CaptureState
    let undo: () -> Void
    let cancel: () -> Void
    let pin: () -> Void
    let save: () -> Void
    let copy: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(CaptureTool.allCases.enumerated()), id: \.offset) { _, tool in
                ToolbarIconButton(symbol: tool.symbol, help: tool.title, isActive: state.tool == tool) { state.tool = tool }
            }
            ToolbarIconButton(symbol: "arrow.uturn.backward", help: loc("撤销 (⌘Z)", "Undo (⌘Z)"), isDisabled: state.undoCount == 0, action: undo)
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 1, height: 20)
                .padding(.horizontal, 3)
            ForEach(Array(CaptureState.colors.enumerated()), id: \.offset) { index, color in
                Button {
                    state.colorIndex = index
                } label: {
                    Circle()
                        .fill(Color(nsColor: color))
                        .frame(width: 15, height: 15)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
                        .overlay(
                            Circle().strokeBorder(state.colorIndex == index ? Theme.accent : Color.clear, lineWidth: 2).padding(-3.5)
                        )
                        .frame(width: 22, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(loc("标注颜色 \(index + 1)", "Annotation color \(index + 1)"))
            }
            Slider(value: Binding(get: { state.lineWidth }, set: { state.lineWidth = $0.rounded() }), in: 1...8)
                .tint(.white)
                .frame(width: 70)
                .accessibilityLabel(loc("线条宽度", "Line width"))
            Text("\(Int(state.lineWidth)) px")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: 32, alignment: .leading)
            Spacer(minLength: 4)
            ToolbarIconButton(symbol: "xmark", help: loc("取消 (Esc)", "Cancel (Esc)"), action: cancel)
            ToolbarIconButton(symbol: "pin", help: loc("贴图到屏幕", "Pin to Screen"), action: pin)
            ToolbarIconButton(symbol: "square.and.arrow.down", help: loc("保存…", "Save…"), action: save)
            Button(action: copy) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(loc("复制 (↩)", "Copy (↩)"))
            .accessibilityLabel(loc("确认并复制截图", "Confirm and copy screenshot"))
        }
        .padding(.horizontal, 6)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(MaterialBackground(material: .hudWindow))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
    }
}

private struct ToolbarIconButton: View {
    let symbol: String
    let help: String
    var isActive = false
    var isDisabled = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isActive ? Theme.accent : Color.white.opacity(isDisabled ? 0.3 : 0.92))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Theme.accent.opacity(0.22) : (hovering ? Color.white.opacity(0.12) : Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering = $0 }
    }
}
