import Foundation

public struct ClipboardItem: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case text, image
    }

    public var id: UUID
    public var kind: Kind
    public var text: String?
    public var imageFile: String?
    public var imageWidth: Int?
    public var imageHeight: Int?
    public var byteSize: Int
    public var createdAt: Date
    public var sourceApp: String?
    public var sourceBundleID: String?
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        kind: Kind,
        text: String? = nil,
        imageFile: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        byteSize: Int = 0,
        createdAt: Date = Date(),
        sourceApp: String? = nil,
        sourceBundleID: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.imageFile = imageFile
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.byteSize = byteSize
        self.createdAt = createdAt
        self.sourceApp = sourceApp
        self.sourceBundleID = sourceBundleID
        self.isPinned = isPinned
    }

    public var preview: String {
        switch kind {
        case .text:
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let singleLine = trimmed.replacingOccurrences(of: "\n", with: " ")
            return String(singleLine.prefix(120))
        case .image:
            if let w = imageWidth, let h = imageHeight {
                return loc("图片 \(w)×\(h)", "Image \(w)×\(h)")
            }
            return loc("图片", "Image")
        }
    }
}

public struct CalendarEvent: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var calendarTitle: String
    public var colorHex: String
    public var location: String?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarTitle: String,
        colorHex: String,
        location: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.colorHex = colorHex
        self.location = location
    }
}

/// 跨平台矩形（点坐标，左上角原点），避免 CoreGraphics 类型进入接口层。
public struct Rect: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct DisplayInfo: Hashable, Sendable {
    public var id: UInt32
    public var widthPoints: Double
    public var heightPoints: Double
    public var scaleFactor: Double

    public init(id: UInt32, widthPoints: Double, heightPoints: Double, scaleFactor: Double) {
        self.id = id
        self.widthPoints = widthPoints
        self.heightPoints = heightPoints
        self.scaleFactor = scaleFactor
    }
}

/// 定格的整屏像素：BGRA8、预乘 alpha、左上角原点。平台无关，便于取色与裁剪。
public struct ScreenFrame: Sendable {
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var bytesPerRow: Int
    public var scale: Double
    public var pixels: Data

    public init(pixelWidth: Int, pixelHeight: Int, bytesPerRow: Int, scale: Double, pixels: Data) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.bytesPerRow = bytesPerRow
        self.scale = scale
        self.pixels = pixels
    }

    /// 像素坐标处颜色（r, g, b），越界返回 nil。
    public func color(atPixelX x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8)? {
        guard x >= 0, y >= 0, x < pixelWidth, y < pixelHeight else { return nil }
        let offset = y * bytesPerRow + x * 4
        guard offset + 3 < pixels.count else { return nil }
        return pixels.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            (raw[offset + 2], raw[offset + 1], raw[offset])
        }
    }

    public static func hex(_ color: (r: UInt8, g: UInt8, b: UInt8)) -> String {
        String(format: "#%02X%02X%02X", color.r, color.g, color.b)
    }
}

/// 截图时可自动识别的窗口（显示器局部点坐标，左上角原点）。
public struct DetectedWindow: Hashable, Sendable {
    public var frame: Rect
    public var title: String
    public var owner: String

    public init(frame: Rect, title: String, owner: String) {
        self.frame = frame
        self.title = title
        self.owner = owner
    }
}