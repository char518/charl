import CharlCore
import Foundation

/// 系统日历事件能力。macOS 实现基于 EventKit；Windows 可对接 Outlook/系统日历或本地 ICS。
public protocol CalendarEventsService: AnyObject {
    func hasAccess() -> Bool
    /// 触发系统授权流程，返回是否已授权。
    func requestAccess() async -> Bool
    func events(from start: Date, to end: Date) async throws -> [CalendarEvent]
}