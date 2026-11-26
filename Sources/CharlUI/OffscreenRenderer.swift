import AppKit
import CharlCore
import SwiftUI

public enum OffscreenRenderer {
    public static func render(model: AppModel, name: String, query: String = "", to url: URL) throws {
        let dark = CommandLine.arguments.contains("--dark")
        switch name {
        case "calendar":
            if let day = SearchEngine.parseDate(query, today: Day.today()) { model.calendar.select(day) }
            let palette = CommandLine.arguments.first(where: { $0.hasPrefix("--palette=") }).flatMap { CalendarPalette(rawValue: String($0.dropFirst(10))) } ?? .mist
            try bitmap(CalendarPopoverView(model: model.calendar, palette: palette, customAccent: Color(hex: model.settingsModel.settings.calendarAccentHex), fontSize: Double(model.settingsModel.settings.calendarFontSize), expanded: query == "detail"), size: NSSize(width: 320, height: 520), dark: dark, fitHeight: true, to: url)
        case "clipboard":
            model.clipboard.loadIfNeeded()
            model.clipboard.filter = query == "standard" ? "" : query
            try bitmap(ClipboardPanelView(model: model.clipboard, actions: model.clipboardActions, compactCards: query != "standard", ropeOpacity: Double(model.settingsModel.settings.clipboardRopeOpacity) / 100.0), size: NSSize(width: 1408, height: 340), dark: dark, to: url)
        case "settings":
            let tab = SettingsTab(rawValue: query) ?? .general
            try bitmap(SettingsView(model: model, initialTab: tab), size: NSSize(width: 740, height: 540), dark: dark, to: url)
        case "capture":
            let frame = testFrame()
            let state = CaptureState()
            let canvas = ScreenshotCanvas(frame: frame, state: state, windows: [], magnifier: false)
            canvas.setSelection(CGRect(x: 100, y: 80, width: 320, height: 220))
            let container = NSView(frame: canvas.bounds)
            container.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            container.addSubview(canvas)
            let toolbar = CaptureToolbarView(state: state, undo: {}, cancel: {}, pin: {}, save: {}, copy: {})
            toolbar.frame = CGRect(x: 40, y: 100, width: 680, height: 52)
            container.addSubview(toolbar)
            guard let rep = renderView(container, size: container.bounds.size, scale: renderScale) else { throw RenderError.failed }
            guard let data = rep.representation(using: .png, properties: [:]) else { throw RenderError.failed }
            try data.write(to: url)
            guard let image = canvas.result(), let result = image.cgImage(forProposedRect: nil, context: nil, hints: nil), result.width == 320, result.height == 220 else { throw RenderError.failed }
        default: throw RenderError.failed
        }
    }

    private static func bitmap<V: View>(_ view: V, size: NSSize, dark: Bool, fitHeight: Bool = false, to url: URL) throws {
        let hosting = NSHostingView(rootView: view.background(Theme.windowBackground))
        hosting.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        let fit = hosting.fittingSize
        let outputSize = fitHeight ? NSSize(width: max(fit.width, 1), height: max(fit.height, 1)) : size
        hosting.frame = NSRect(origin: .zero, size: outputSize)
        hosting.layoutSubtreeIfNeeded()
        guard let rep = renderView(hosting, size: outputSize, scale: renderScale) else { throw RenderError.failed }
        guard let data = rep.representation(using: .png, properties: [:]) else { throw RenderError.failed }
        try data.write(to: url)
    }

    private static var renderScale: CGFloat {
        CommandLine.arguments.first(where: { $0.hasPrefix("--scale=") }).flatMap { Int($0.dropFirst(8)) }.map { CGFloat($0) } ?? 2
    }

    private static func renderView(_ view: NSView, size: NSSize, scale: CGFloat) -> NSBitmapImageRep? {
        DisplayScaling.apply(to: view, scale: scale)
        view.layoutSubtreeIfNeeded()
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    private static func testFrame() -> ScreenFrame {
        let width = 760, height = 460
        var bytes = Data(count: width * height * 4)
        bytes.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * 4
                    raw[offset] = UInt8(180 + x % 50)
                    raw[offset + 1] = UInt8(100 + y % 100)
                    raw[offset + 2] = UInt8(70 + x % 100)
                    raw[offset + 3] = 255
                }
            }
        }
        return ScreenFrame(pixelWidth: width, pixelHeight: height, bytesPerRow: width * 4, scale: 1, pixels: bytes)
    }
    private enum RenderError: Error { case failed }
}
