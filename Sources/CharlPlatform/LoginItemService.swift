import Foundation

/// 登录项能力。macOS 用 SMAppService；Windows 可用注册表 Run 键或任务计划。
public protocol LoginItemService: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}