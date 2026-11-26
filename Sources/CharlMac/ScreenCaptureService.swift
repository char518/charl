import AppKit
import CharlCore
import CharlPlatform
import CoreGraphics
import CoreVideo
import Foundation
import ScreenCaptureKit

public final class ScreenCaptureService: ScreenshotService {
    public init() {}

    public func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    public func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    public func displays() async throws -> [DisplayInfo] {
        let content = try await SCShareableContent.current
        return content.displays.map { display in
            DisplayInfo(
                id: display.displayID,
                widthPoints: Double(display.width),
                heightPoints: Double(display.height),
                scaleFactor: Double(CGDisplayPixelsWide(display.displayID)) / Double(max(display.width, 1))
            )
        }
    }

    public func capture(displayID: UInt32, region: Rect?) async throws -> Data {
        let (image, display) = try await captureImage(displayID: displayID)
        var output = image
        if let region {
            let scale = Double(image.width) / Double(display.width)
            let pixelRect = CGRect(
                x: region.x * scale,
                y: region.y * scale,
                width: region.width * scale,
                height: region.height * scale
            ).integral
            guard let cropped = image.cropping(to: pixelRect) else { throw ScreenshotError.cropFailed }
            output = cropped
        }
        guard let png = NSBitmapImageRep(cgImage: output).representation(using: .png, properties: [:]) else {
            throw ScreenshotError.encodeFailed
        }
        return png
    }

    public func captureFrame(displayID: UInt32) async throws -> ScreenFrame {
        let (image, display) = try await captureImage(displayID: displayID)
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var pixels = Data(count: bytesPerRow * height)
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw ScreenshotError.encodeFailed }
        return ScreenFrame(
            pixelWidth: width,
            pixelHeight: height,
            bytesPerRow: bytesPerRow,
            scale: Double(width) / Double(max(display.width, 1)),
            pixels: pixels
        )
    }

    public func visibleWindows(displayID: UInt32, excludingProcess pid: Int32) -> [DetectedWindow] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let displayBounds = CGDisplayBounds(CGDirectDisplayID(displayID))
        var result: [DetectedWindow] = []
        for info in list {
            if (info[kCGWindowOwnerPID as String] as? Int32) == pid { continue }
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer < 1000 else { continue }
            if let alpha = info[kCGWindowAlpha as String] as? Double, alpha < 0.05 { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            let clipped = bounds.intersection(displayBounds)
            guard !clipped.isNull, clipped.width >= 40, clipped.height >= 24 else { continue }
            result.append(DetectedWindow(
                frame: Rect(
                    x: clipped.minX - displayBounds.minX,
                    y: clipped.minY - displayBounds.minY,
                    width: clipped.width,
                    height: clipped.height
                ),
                title: info[kCGWindowName as String] as? String ?? "",
                owner: info[kCGWindowOwnerName as String] as? String ?? ""
            ))
        }
        return result
    }

    private func captureImage(displayID: UInt32) async throws -> (CGImage, SCDisplay) {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenshotError.displayNotFound
        }
        let configuration = SCStreamConfiguration()
        configuration.captureResolution = .best
        configuration.scalesToFit = false
        let directID = CGDirectDisplayID(displayID)
        let backing = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        }?.backingScaleFactor ?? CGFloat(CGDisplayPixelsWide(directID)) / CGFloat(max(display.width, 1))
        configuration.width = Int((CGFloat(display.width) * backing).rounded())
        configuration.height = Int((CGFloat(display.height) * backing).rounded())
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        // 不排除 charl 自身窗口：日历/剪贴板等应可被截入（截图遮罩在捕获后才创建，不会入镜）。
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return (image, display)
    }
}

public enum ScreenshotError: LocalizedError {
    case displayNotFound
    case cropFailed
    case encodeFailed

    public var errorDescription: String? {
        switch self {
        case .displayNotFound: return loc("找不到目标显示器", "Target display not found")
        case .cropFailed: return loc("选区裁剪失败", "Could not crop the selection")
        case .encodeFailed: return loc("图像编码失败", "Could not encode the image")
        }
    }
}