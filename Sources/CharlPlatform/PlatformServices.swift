import Foundation

/// 平台能力聚合。组合根（CharlApp）注入具体实现；
/// Windows 移植时替换整个 Mac 层并在此重新装配。
public struct PlatformServices {
    public let hotkeys: HotkeyService
    public let storage: StorageService
    public let clipboard: ClipboardService
    public let calendarEvents: CalendarEventsService
    public let screenshot: ScreenshotService
    public let loginItem: LoginItemService
    public let remote: RemoteInfoService

    public init(
        hotkeys: HotkeyService,
        storage: StorageService,
        clipboard: ClipboardService,
        calendarEvents: CalendarEventsService,
        screenshot: ScreenshotService,
        loginItem: LoginItemService,
        remote: RemoteInfoService
    ) {
        self.hotkeys = hotkeys
        self.storage = storage
        self.clipboard = clipboard
        self.calendarEvents = calendarEvents
        self.screenshot = screenshot
        self.loginItem = loginItem
        self.remote = remote
    }
}