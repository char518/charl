import CharlPlatform
import Foundation

/// macOS 平台装配。Windows 移植时以同构的 WindowsPlatform 替换本文件所在层。
public enum MacPlatform {
    public static func makeServices() -> PlatformServices {
        let storage = MacStorage()
        return PlatformServices(
            hotkeys: CarbonHotkeyCenter(),
            storage: storage,
            clipboard: PasteboardMonitor(storage: storage),
            calendarEvents: EventKitService(),
            screenshot: ScreenCaptureService(),
            loginItem: MacLoginItem(),
            remote: MacRemoteInfoService()
        )
    }
}