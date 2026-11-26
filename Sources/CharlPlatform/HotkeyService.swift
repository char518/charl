import CharlCore
import Foundation

/// 全局快捷键能力。macOS 实现用 Carbon RegisterEventHotKey（无需辅助功能权限）；
/// Windows 可用 RegisterHotKey。
public protocol HotkeyService: AnyObject {
    @discardableResult
    func register(_ combo: KeyCombo, handler: @escaping () -> Void) -> Bool
    func unregisterAll()
    /// 原生键码 → 逻辑键（设置面板热键录制用）。
    func key(for keyCode: UInt16) -> KeyCombo.Key?
}