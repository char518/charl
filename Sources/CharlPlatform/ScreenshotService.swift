import CharlCore
import Foundation

/// 截图能力。macOS 实现基于 ScreenCaptureKit；Windows 可用 DXGI Desktop Duplication + EnumWindows。
public protocol ScreenshotService: AnyObject {
    func hasPermission() -> Bool
    /// 触发系统授权流程（屏幕录制权限），返回当前是否已授权。
    @discardableResult
    func requestPermission() -> Bool
    func displays() async throws -> [DisplayInfo]
    /// 截取指定显示器；region 为点坐标、左上角原点，nil 表示整屏。返回 PNG 数据。
    func capture(displayID: UInt32, region: Rect?) async throws -> Data
    /// 定格整屏原始像素（Snipaste 式先冻结再框选）。
    func captureFrame(displayID: UInt32) async throws -> ScreenFrame
    /// 该显示器上可见窗口，前到后排序，用于悬停自动识别。
    func visibleWindows(displayID: UInt32, excludingProcess pid: Int32) -> [DetectedWindow]
}