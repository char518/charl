import CharlCore
import Foundation

/// 剪贴板能力：监听系统剪贴板、写回、图像数据读写。
/// macOS 实现基于 NSPasteboard changeCount 轮询；Windows 可用 AddClipboardFormatListener。
public protocol ClipboardService: AnyObject {
    /// 开始监听；有新内容（已过滤密码/瞬态内容）时回调。回调在主线程。
    func startMonitoring(onChange: @escaping (ClipboardItem) -> Void)
    func stopMonitoring()
    /// 把历史条目写回系统剪贴板（实现需抑制自身写入触发的再次捕获）。
    func copy(_ item: ClipboardItem)
    func imageData(for item: ClipboardItem) -> Data?
    func thumbnailData(for item: ClipboardItem) -> Data?
    func deleteImageFiles(for item: ClipboardItem)

    /// 自动粘贴（向前台 App 合成 ⌘V）：macOS 需辅助功能权限。
    var canAutoPaste: Bool { get }
    @discardableResult
    func requestAutoPastePermission() -> Bool
    func sendPasteKeystroke()
}