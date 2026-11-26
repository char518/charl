import AppKit
import CharlCore
import Combine

public enum CaptureTool: String, CaseIterable, Identifiable {
    case select, rectangle, ellipse, arrow, pen, mosaic, text
    public var id: String { rawValue }
    var title: String {
        switch self {
        case .select: return loc("调整选区", "Adjust Selection")
        case .rectangle: return loc("矩形", "Rectangle")
        case .ellipse: return loc("椭圆", "Ellipse")
        case .arrow: return loc("箭头", "Arrow")
        case .pen: return loc("画笔", "Pen")
        case .mosaic: return loc("马赛克", "Mosaic")
        case .text: return loc("文字", "Text")
        }
    }
    var symbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .arrow: return "arrow.up.right"
        case .pen: return "pencil.tip"
        case .mosaic: return "square.grid.3x3.fill"
        case .text: return "textformat"
        }
    }
}

final class CaptureState: ObservableObject {
    @Published var tool: CaptureTool = .select
    @Published var colorIndex = 0
    @Published var lineWidth: Double = 3
    @Published var undoCount = 0
    static let colors: [NSColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .white, .black]
}

private struct Annotation {
    var tool: CaptureTool
    var points: [CGPoint]
    var color: NSColor
    var width: CGFloat
    var text: String = ""
    var rect: CGRect {
        guard let start = points.first, let end = points.last else { return .zero }
        return CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
    }
}

extension ScreenFrame {
    var cgImage: CGImage? {
        guard let provider = CGDataProvider(data: pixels as CFData) else { return nil }
        return CGImage(width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

final class ScreenshotCanvas: NSView {
    private static let placeholder: CGImage = {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        return context?.makeImage() ?? CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: CGDataProvider(data: Data([0, 0, 0, 255]) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }()

    private let screenFrame: ScreenFrame
    private let image: CGImage
    private let displayImage: NSImage
    private let state: CaptureState
    private let windows: [DetectedWindow]
    private let magnifier: Bool
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?
    var onColorCopy: ((String) -> Void)?
    private(set) var selection: CGRect?
    private var hovered: CGRect?
    private var magnifierCache: (rect: CGRect, image: CGImage)?
    private var lastMagnifierRect: CGRect?
    private var textEditor: NSTextField?
    private var textPoint: CGPoint = .zero
    private var pointer = CGPoint.zero
    private var annotations: [Annotation] = []
    private var draft: Annotation?
    private var tracking: NSTrackingArea?
    private var origin: CGPoint?
    private var originalSelection: CGRect?
    private var dragMode: DragMode?
    private enum DragMode { case newSelection, move, resize(Int), annotate }

    init(frame: ScreenFrame, state: CaptureState, windows: [DetectedWindow], magnifier: Bool) {
        screenFrame = frame
        image = frame.cgImage ?? Self.placeholder
        self.state = state
        self.windows = windows
        self.magnifier = magnifier
        let pointSize = NSSize(width: Double(frame.pixelWidth) / frame.scale, height: Double(frame.pixelHeight) / frame.scale)
        displayImage = NSImage(cgImage: image, size: pointSize)
        super.init(frame: NSRect(origin: .zero, size: pointSize))
    }
    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self)
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    /// 依据指针位置切换光标：手柄/边缘=对应缩放箭头，选区内=移动手型，其余=十字。
    private func updateCursor(at point: CGPoint) {
        guard let selection else { NSCursor.crosshair.set(); return }
        let handles = self.handles(selection)
        if let index = handles.firstIndex(where: { hypot($0.x - point.x, $0.y - point.y) < 9 }) {
            switch index {
            case 0, 7: diagonalCursor(nwse: true).set()
            case 2, 5: diagonalCursor(nwse: false).set()
            case 1, 6: NSCursor.resizeUpDown.set()
            default: NSCursor.resizeLeftRight.set()
            }
            return
        }
        let edge = selection.insetBy(dx: -6, dy: -6)
        if edge.contains(point) && !selection.insetBy(dx: 6, dy: 6).contains(point) {
            let nearLeft = abs(point.x - selection.minX) <= 6
            let nearRight = abs(point.x - selection.maxX) <= 6
            let nearTop = abs(point.y - selection.minY) <= 6
            let nearBottom = abs(point.y - selection.maxY) <= 6
            if (nearLeft && nearTop) || (nearRight && nearBottom) { diagonalCursor(nwse: true).set() }
            else if (nearRight && nearTop) || (nearLeft && nearBottom) { diagonalCursor(nwse: false).set() }
            else if nearLeft || nearRight { NSCursor.resizeLeftRight.set() }
            else if nearTop || nearBottom { NSCursor.resizeUpDown.set() }
            else { NSCursor.openHand.set() }
            return
        }
        if selection.contains(point) { NSCursor.openHand.set() } else { NSCursor.crosshair.set() }
    }

    private func diagonalCursor(nwse: Bool) -> NSCursor {
        let selector = Selector(nwse ? "_windowResizeNorthWestSouthEastCursor" : "_windowResizeNorthEastSouthWestCursor")
        if NSCursor.responds(to: selector),
           let cursor = NSCursor.perform(selector)?.takeUnretainedValue() as? NSCursor {
            return cursor
        }
        return nwse ? NSCursor.resizeUpDown : NSCursor.resizeLeftRight
    }

    func setPointerFromScreen(_ location: NSPoint) {
        guard let window else { return }
        pointer = clamp(convert(window.convertPoint(fromScreen: location), from: nil))
        updateHover()
        lastMagnifierRect = magnifier ? magnifierRect() : nil
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        let oldHover = hovered
        pointer = convert(event.locationInWindow, from: nil)
        updateHover()
        updateCursor(at: pointer)
        if hovered != oldHover {
            // 悬停窗口变化才整屏重绘
            lastMagnifierRect = nil
            needsDisplay = true
        } else if magnifier && selection == nil {
            // 仅放大镜移动：只重绘放大镜旧/新区域，避免每帧整屏光栅化
            let rect = magnifierRect()
            if let old = lastMagnifierRect { setNeedsDisplay(old) }
            setNeedsDisplay(rect)
            lastMagnifierRect = rect
        }
        // 已有选区且无放大镜时，移动鼠标不改变画面，跳过重绘
    }

    private func magnifierRect() -> CGRect {
        let size: CGFloat = 124
        let x = min(max(8, pointer.x + 22), bounds.width - size - 8)
        let y = min(max(8, pointer.y + 22), bounds.height - size - 54)
        return CGRect(x: x - 2, y: y - 2, width: size + 184, height: size + 34)
    }

    private func updateHover() {
        guard selection == nil else { hovered = nil; return }
        hovered = windows.first { window in
            CGRect(x: window.frame.x, y: window.frame.y, width: window.frame.width, height: window.frame.height).contains(pointer)
        }.map { CGRect(x: $0.frame.x, y: $0.frame.y, width: $0.frame.width, height: $0.frame.height) }
    }

    override func draw(_ dirtyRect: NSRect) {
        displayImage.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        let region = selection ?? hovered
        let shade = NSBezierPath(rect: bounds)
        if let region { shade.appendRect(region); shade.windingRule = .evenOdd }
        NSColor.black.withAlphaComponent(0.35).setFill()
        shade.fill()
        if let region {
            NSGraphicsContext.saveGraphicsState()
            let clipping = NSBezierPath(rect: region)
            clipping.addClip()
            if let context = NSGraphicsContext.current?.cgContext {
                for annotation in annotations { render(annotation, in: context) }
                if let draft { render(draft, in: context) }
            }
            NSGraphicsContext.restoreGraphicsState()
            Theme.accentNS.setStroke()
            let border = NSBezierPath(rect: region)
            border.lineWidth = 1.5
            border.stroke()
            if selection != nil {
                for point in handles(region) {
                    NSColor.white.setFill()
                    let box = NSBezierPath(rect: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
                    box.fill(); Theme.accentNS.setStroke(); box.stroke()
                }
            }
            let text = "\(Int(region.width * screenFrame.scale)) × \(Int(region.height * screenFrame.scale)) px"
            label(text, at: CGPoint(x: region.minX, y: max(8, region.minY - 28)))
        }
        if magnifier && selection == nil { drawMagnifier() }
        if selection == nil {
            label(loc("拖拽框选 / 双击选窗口 · C 色值 · Esc 取消", "Drag to select · double-click a window · C color · Esc cancel"), at: CGPoint(x: max(8, bounds.midX - 205), y: max(8, bounds.height - 45)))
        }
    }

    private func label(_ text: String, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white]
        let string = text as NSString
        let size = string.size(withAttributes: attributes)
        NSColor.black.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: CGRect(x: point.x, y: point.y, width: size.width + 16, height: size.height + 10), xRadius: 5, yRadius: 5).fill()
        string.draw(at: CGPoint(x: point.x + 8, y: point.y + 5), withAttributes: attributes)
    }

    private func drawMagnifier() {
        let px = Int(pointer.x * screenFrame.scale)
        let py = Int(pointer.y * screenFrame.scale)
        guard let color = screenFrame.color(atPixelX: px, y: py) else { return }
        let size: CGFloat = 124
        let x = min(max(8, pointer.x + 22), bounds.width - size - 8)
        let y = min(max(8, pointer.y + 22), bounds.height - size - 54)
        let box = CGRect(x: x, y: y, width: size, height: size)
        let source = CGRect(x: max(0, px - 8), y: max(0, py - 8), width: 17, height: 17).intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let crop: CGImage?
        if let cached = magnifierCache, cached.rect == source {
            crop = cached.image
        } else {
            crop = image.cropping(to: source)
            if let crop { magnifierCache = (source, crop) }
        }
        if let crop {
            NSGraphicsContext.current?.imageInterpolation = .none
            NSImage(cgImage: crop, size: box.size).draw(in: box, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        NSColor.white.setStroke()
        let cross = NSBezierPath()
        cross.move(to: CGPoint(x: box.minX, y: box.midY)); cross.line(to: CGPoint(x: box.maxX, y: box.midY))
        cross.move(to: CGPoint(x: box.midX, y: box.minY)); cross.line(to: CGPoint(x: box.midX, y: box.maxY)); cross.lineWidth = 0.5; cross.stroke()
        label("\(ScreenFrame.hex(color))  \(px),\(py)", at: CGPoint(x: x, y: y + size + 3))
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastMagnifierRect = nil
        let point = clamp(convert(event.locationInWindow, from: nil))
        if event.clickCount == 2, state.tool == .select {
            let target = windows.first { window in
                CGRect(x: window.frame.x, y: window.frame.y, width: window.frame.width, height: window.frame.height).contains(point)
            }.map { CGRect(x: $0.frame.x, y: $0.frame.y, width: $0.frame.width, height: $0.frame.height) }
            if let target {
                selection = target
                onSelection?(target)
                needsDisplay = true
                return
            }
        }
        pointer = point
        origin = point
        originalSelection = selection
        if state.tool != .select, let selection, selection.contains(point) {
            if state.tool == .text { addText(at: point); return }
            draft = Annotation(tool: state.tool, points: [point, point], color: CaptureState.colors[state.colorIndex], width: state.lineWidth)
            dragMode = .annotate
        } else if let selection, let index = handles(selection).firstIndex(where: { hypot($0.x - point.x, $0.y - point.y) < 9 }) {
            dragMode = .resize(index)
        } else if let selection, selection.contains(point) {
            dragMode = .move
        } else {
            hovered = windows.first { window in
                CGRect(x: window.frame.x, y: window.frame.y, width: window.frame.width, height: window.frame.height).contains(point)
            }.map { CGRect(x: $0.frame.x, y: $0.frame.y, width: $0.frame.width, height: $0.frame.height) }
            selection = nil
            annotations.removeAll()
            state.undoCount = 0
            dragMode = .newSelection
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin, let dragMode else { return }
        lastMagnifierRect = nil
        let point = clamp(convert(event.locationInWindow, from: nil))
        pointer = point
        switch dragMode {
        case .newSelection: selection = normalized(origin, point)
        case .move:
            guard let originalSelection else { return }
            var rect = originalSelection.offsetBy(dx: point.x - origin.x, dy: point.y - origin.y)
            rect.origin.x = min(max(0, rect.origin.x), bounds.width - rect.width)
            rect.origin.y = min(max(0, rect.origin.y), bounds.height - rect.height)
            selection = rect
        case .resize(let index):
            guard let originalSelection else { return }
            var lo = originalSelection.origin
            var hi = CGPoint(x: originalSelection.maxX, y: originalSelection.maxY)
            if [0, 3, 5].contains(index) { lo.x = point.x }
            if [2, 4, 7].contains(index) { hi.x = point.x }
            if [0, 1, 2].contains(index) { lo.y = point.y }
            if [5, 6, 7].contains(index) { hi.y = point.y }
            selection = normalized(lo, hi)
        case .annotate:
            if draft?.tool == .pen { draft?.points.append(point) }
            else { draft?.points = [origin, point] }
        }
        if case .move = dragMode { NSCursor.closedHand.set() } else { updateCursor(at: point) }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        lastMagnifierRect = nil
        if case .newSelection = dragMode, let origin, hypot(pointer.x - origin.x, pointer.y - origin.y) < 5 {
            selection = nil
        }
        if let draft { annotations.append(draft); self.draft = nil; state.undoCount = annotations.count }
        if case .move = dragMode, let originalSelection, let selection {
            let dx = selection.minX - originalSelection.minX
            let dy = selection.minY - originalSelection.minY
            for index in annotations.indices { annotations[index].points = annotations[index].points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) } }
        }
        if let selection, selection.width >= 4, selection.height >= 4 { onSelection?(selection) }
        else { selection = nil }
        dragMode = nil; origin = nil
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() }
        else if event.keyCode == 36 { onConfirm?() }
        else if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "z" { undo() }
        else if event.charactersIgnoringModifiers?.lowercased() == "c", let color = screenFrame.color(atPixelX: Int(pointer.x * screenFrame.scale), y: Int(pointer.y * screenFrame.scale)) {
            let hex = ScreenFrame.hex(color)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
            onColorCopy?(hex)
        } else { super.keyDown(with: event) }
    }

    func undo() {
        if !annotations.isEmpty { annotations.removeLast(); state.undoCount = annotations.count; needsDisplay = true }
    }

    func setSelection(_ rect: CGRect) { selection = rect; onSelection?(rect); needsDisplay = true }

    func result() -> NSImage? {
        commitText()
        guard let selection else { return nil }
        let scale = screenFrame.scale
        let pixels = CGRect(x: selection.minX * scale, y: selection.minY * scale, width: selection.width * scale, height: selection.height * scale).integral
        guard let cropped = image.cropping(to: pixels), let context = CGContext(data: nil, width: cropped.width, height: cropped.height, bitsPerComponent: 8, bytesPerRow: cropped.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
        context.translateBy(x: 0, y: CGFloat(cropped.height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -selection.minX, y: -selection.minY)
        for annotation in annotations { render(annotation, in: context) }
        guard let output = context.makeImage() else { return nil }
        return NSImage(cgImage: output, size: NSSize(width: CGFloat(output.width) / scale, height: CGFloat(output.height) / scale))
    }

    private func addText(at point: CGPoint) {
        commitText()
        guard window != nil else { return }
        textPoint = point
        let field = NSTextField(frame: CGRect(x: point.x, y: point.y - 12, width: 240, height: 26))
        field.font = NSFont.systemFont(ofSize: max(16, state.lineWidth * 6), weight: .medium)
        field.textColor = CaptureState.colors[state.colorIndex]
        field.backgroundColor = .clear
        field.isBordered = false
        field.focusRingType = .none
        field.placeholderString = loc("输入文字，回车确认", "Type text, press Return to confirm")
        field.delegate = self
        field.target = self
        field.action = #selector(commitTextAction)
        addSubview(field)
        textEditor = field
        window?.makeFirstResponder(field)
    }

    @objc private func commitTextAction() { commitText() }

    private func commitText() {
        guard let field = textEditor else { return }
        let text = field.stringValue
        textEditor = nil
        field.removeFromSuperview()
        if !text.isEmpty {
            annotations.append(Annotation(tool: .text, points: [textPoint], color: CaptureState.colors[state.colorIndex], width: state.lineWidth, text: text))
            state.undoCount = annotations.count
        }
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    private func cancelText() {
        guard let field = textEditor else { return }
        textEditor = nil
        field.removeFromSuperview()
        needsDisplay = true
        window?.makeFirstResponder(self)
    }

    private func render(_ annotation: Annotation, in context: CGContext) {
        context.saveGState(); defer { context.restoreGState() }
        context.setStrokeColor(annotation.color.cgColor)
        context.setFillColor(annotation.color.cgColor)
        context.setLineWidth(annotation.width)
        context.setLineCap(.round); context.setLineJoin(.round)
        guard let first = annotation.points.first, let last = annotation.points.last else { return }
        switch annotation.tool {
        case .rectangle: context.stroke(annotation.rect)
        case .ellipse: context.strokeEllipse(in: annotation.rect)
        case .arrow:
            context.move(to: first); context.addLine(to: last); context.strokePath()
            let angle = atan2(last.y - first.y, last.x - first.x)
            let length = max(10, annotation.width * 4)
            context.move(to: last)
            context.addLine(to: CGPoint(x: last.x - length * cos(angle - .pi / 6), y: last.y - length * sin(angle - .pi / 6)))
            context.addLine(to: CGPoint(x: last.x - length * cos(angle + .pi / 6), y: last.y - length * sin(angle + .pi / 6)))
            context.closePath(); context.fillPath()
        case .pen:
            context.addLines(between: annotation.points); context.strokePath()
        case .mosaic:
            let rect = annotation.rect.intersection(bounds)
            let step: CGFloat = 10
            for y in stride(from: rect.minY, to: rect.maxY, by: step) {
                for x in stride(from: rect.minX, to: rect.maxX, by: step) {
                    let px = Int(min(x + step / 2, bounds.maxX - 1) * screenFrame.scale)
                    let py = Int(min(y + step / 2, bounds.maxY - 1) * screenFrame.scale)
                    if let c = screenFrame.color(atPixelX: px, y: py) {
                        context.setFillColor(NSColor(srgbRed: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255, alpha: 1).cgColor)
                        context.fill(CGRect(x: x, y: y, width: min(step, rect.maxX - x), height: min(step, rect.maxY - y)))
                    }
                }
            }
        case .text:
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            (annotation.text as NSString).draw(at: first, withAttributes: [.font: NSFont.systemFont(ofSize: max(16, annotation.width * 6), weight: .medium), .foregroundColor: annotation.color])
            NSGraphicsContext.restoreGraphicsState()
        case .select: break
        }
    }

    private func clamp(_ point: CGPoint) -> CGPoint { CGPoint(x: min(max(0, point.x), bounds.width), y: min(max(0, point.y), bounds.height)) }
    private func normalized(_ first: CGPoint, _ last: CGPoint) -> CGRect { CGRect(x: min(first.x, last.x), y: min(first.y, last.y), width: abs(last.x - first.x), height: abs(last.y - first.y)) }
    private func handles(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.midY), CGPoint(x: rect.maxX, y: rect.midY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
    }
}

extension ScreenshotCanvas: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitText()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelText()
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitText()
    }
}
