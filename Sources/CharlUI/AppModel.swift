import AppKit
import CharlCore
import CharlPlatform
import Combine
import SwiftUI

public extension Notification.Name {
    /// 界面语言变化；CharlApp 用它重建 AppKit 主菜单（其余界面靠 settings 发布刷新）。
    static let charlLanguageChanged = Notification.Name("com.charl.charl.languageChanged")
}

public enum PanelTab: String { case clipboard, calendar }

public enum HotkeySlot: String, CaseIterable, Identifiable {
    case clipboard, screenshot, pin
    public var id: String { rawValue }
    var title: String {
        switch self {
        case .clipboard: return loc("剪贴板历史", "Clipboard History")
        case .screenshot: return loc("截图", "Screenshot")
        case .pin: return loc("贴图", "Pin Image")
        }
    }
    var path: WritableKeyPath<AppSettings, KeyCombo> {
        switch self {
        case .clipboard: return \.clipboardHotkey
        case .screenshot: return \.screenshotHotkey
        case .pin: return \.pinHotkey
        }
    }
}

public final class AppModel: ObservableObject {
    public let services: PlatformServices
    public let clipboard: ClipboardModuleModel
    public let settingsModel: SettingsModel
    @Published public var hotkeyError: String?
    @Published public private(set) var recordingSlot: HotkeySlot?
    @Published public private(set) var liveModifiers: KeyCombo.Modifiers = []
    @Published public private(set) var recentlyUpdatedSlot: HotkeySlot?
    private var recordingMonitor: Any?
    private var flagsMonitor: Any?
    private var hotkeyFeedbackTask: DispatchWorkItem?
    private var subscriptions: Set<AnyCancellable> = []
    private var boundSettings: AppSettings?
    private var statusBar: StatusBarController?
    private var clipboardPanel: PanelController?
    private var calendarStorage: CalendarModuleModel?
    private var captureStorage: ScreenshotController?
    private var settingsWindow: SettingsWindowController?
    private var pasteTarget: NSRunningApplication?
    private var lastClipboardScreenID: UInt32?
    public var preferredDisplayIndex: Int?
    private let preview = ClipboardPreviewController()
    public lazy var toast = Toast()
    private let pins = PinWindowController()

    public init(services: PlatformServices, monitorClipboard: Bool = true) {
        self.services = services
        settingsModel = SettingsModel(storage: services.storage)
        clipboard = ClipboardModuleModel(service: services.clipboard, storage: services.storage, monitoring: monitorClipboard)
        clipboard.maxTextItems = settingsModel.settings.maxTextItems
        clipboard.maxImageItems = settingsModel.settings.maxImageItems
        settingsModel.onChange = { [weak self] settings in self?.applySettings(settings) }
        settingsModel.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.activationPolicy == .regular else { return }
                self?.pasteTarget = app
            }
            .store(in: &subscriptions)
        rememberTarget()
        preview.onClose = { [weak self] in
            guard let self else { return }
            self.clipboardPanel?.keepsOpenOnResign = false
            if NSApp.isActive { self.clipboardPanel?.focus() }
            else { self.clipboardPanel?.close() }
        }
    }

    public var calendar: CalendarModuleModel {
        if let calendarStorage { return calendarStorage }
        let overrides = (try? services.storage.read("holidays.json")).flatMap { try? JSONDecoder().decode([HolidayYear].self, from: $0) } ?? []
        let value = CalendarModuleModel(service: services.calendarEvents, holidays: .standard(overrides: overrides), weekStartsOnMonday: settingsModel.settings.weekStartsOnMonday)
        calendarStorage = value
        return value
    }

    public func start() {
        statusBar = StatusBarController(model: self)
        applyHotkeys()
        refreshRemoteInfo()
    }

    private func applySettings(_ settings: AppSettings) {
        let previousLanguage = boundSettings?.language ?? Lang.preference
        clipboard.maxTextItems = settings.maxTextItems
        clipboard.maxImageItems = settings.maxImageItems
        calendarStorage?.updateWeekStart(settings.weekStartsOnMonday)
        statusBar?.refresh(force: true)
        if recordingSlot == nil, HotkeySlot.allCases.contains(where: { boundSettings?[keyPath: $0.path] != settings[keyPath: $0.path] }) {
            applyHotkeys()
        }
        // 语言切换后关闭临时面板，避免新旧语言混排；设置窗口自身保持打开。
        if previousLanguage != settings.language {
            closePanels()
            preview.close()
            NotificationCenter.default.post(name: .charlLanguageChanged, object: nil)
        }
    }

    public func applyHotkeys() {
        let settings = settingsModel.settings
        let failures = bind(settings)
        boundSettings = settings
        hotkeyError = failures.isEmpty ? nil : loc("快捷键已被其他应用占用：", "Hotkeys already used by other apps: ") + failures.joined(separator: loc("、", ", "))
    }

    private func bind(_ settings: AppSettings) -> [String] {
        services.hotkeys.unregisterAll()
        var failures: [String] = []
        for slot in HotkeySlot.allCases {
            let combo = settings[keyPath: slot.path]
            let success = services.hotkeys.register(combo) { [weak self] in
                guard let self else { return }
                switch slot {
                case .clipboard: self.showClipboard()
                case .screenshot: self.startCapture()
                case .pin: self.pinClipboard()
                }
            }
            if !success { failures.append(slot.title + " " + combo.displayString) }
        }
        return failures
    }

    public func beginRecording(_ slot: HotkeySlot) {
        if recordingSlot != nil { cancelRecording() }
        hotkeyError = nil
        liveModifiers = []
        recordingSlot = slot
        services.hotkeys.unregisterAll()
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self, self.recordingSlot != nil else { return event }
            self.liveModifiers = Self.modifiers(from: event.modifierFlags)
            return event
        }
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let slot = self.recordingSlot else { return event }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == 53 && flags.isEmpty { self.cancelRecording(); return nil }
            guard let key = self.services.hotkeys.key(for: event.keyCode) else { return nil }
            let modifiers = Self.modifiers(from: event.modifierFlags)
            let functionKey = key.rawValue.hasPrefix("f") && Int(key.rawValue.dropFirst()) != nil
            guard functionKey || !flags.intersection([.command, .option, .control]).isEmpty else {
                self.hotkeyError = loc("请包含 ⌘、⌥ 或 ⌃ 修饰键；F1–F12 可单独使用。", "Include the ⌘, ⌥ or ⌃ modifier; F1–F12 can be used alone.")
                return nil
            }
            if self.setHotkey(KeyCombo(modifiers: modifiers, key: key), for: slot) { self.endRecording() }
            return nil
        }
    }

    static func modifiers(from flags: NSEvent.ModifierFlags) -> KeyCombo.Modifiers {
        var modifiers: KeyCombo.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }

    public func resetHotkeys() {
        cancelRecording()
        var next = settingsModel.settings
        next.clipboardHotkey = AppConfig.clipboardHotkey
        next.screenshotHotkey = AppConfig.screenshotHotkey
        next.pinHotkey = AppConfig.pinHotkey
        settingsModel.settings = next
        settingsModel.flushSave()
        hotkeyError = nil
        toast.show(loc("已恢复默认快捷键", "Default hotkeys restored"), symbol: "arrow.counterclockwise")
    }

    @discardableResult
    public func setHotkey(_ combo: KeyCombo, for slot: HotkeySlot) -> Bool {
        var candidate = settingsModel.settings
        candidate[keyPath: slot.path] = combo
        let combos = HotkeySlot.allCases.map { candidate[keyPath: $0.path] }
        guard Set(combos).count == combos.count else {
            hotkeyError = loc("这个组合已分配给 charl 的另一个功能，请换一个。", "This combo is already assigned to another charl feature. Pick a different one.")
            return false
        }
        let failures = bind(candidate)
        if !failures.isEmpty {
            if recordingSlot == nil { _ = bind(settingsModel.settings) }
            else { services.hotkeys.unregisterAll() }
            hotkeyError = loc("系统拒绝注册此组合，旧快捷键已保留；按 Esc 取消或选择其他组合。", "The system refused this combo and the previous hotkey is kept. Press Esc or choose another combo.")
            return false
        }
        boundSettings = candidate
        hotkeyError = nil
        settingsModel.settings = candidate
        settingsModel.flushSave()
        markHotkeyUpdated(slot)
        toast.show(loc("快捷键已更新：\(combo.displayString)", "Hotkey updated: \(combo.displayString)"), symbol: "checkmark.circle")
        return true
    }

    private func markHotkeyUpdated(_ slot: HotkeySlot) {
        recentlyUpdatedSlot = slot
        hotkeyFeedbackTask?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.recentlyUpdatedSlot = nil }
        hotkeyFeedbackTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    private func endRecording() {
        if let recordingMonitor { NSEvent.removeMonitor(recordingMonitor); self.recordingMonitor = nil }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor); self.flagsMonitor = nil }
        liveModifiers = []
        recordingSlot = nil
    }

    public func cancelRecording() {
        guard recordingSlot != nil else { return }
        endRecording()
        applyHotkeys()
    }

    func rememberTarget() {
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            pasteTarget = front
        }
    }

    private var mouseScreen: NSScreen? {
        if let preferredDisplayIndex, NSScreen.screens.indices.contains(preferredDisplayIndex) {
            return NSScreen.screens[preferredDisplayIndex]
        }
        return NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    public func show(_ tab: PanelTab) {
        switch tab {
        case .clipboard: showClipboard()
        case .calendar: showCalendar()
        }
    }

    public func showCalendar(selecting day: Day? = nil) {
        rememberTarget()
        closePanels()
        refreshRemoteInfo()
        let screen = preferredDisplayIndex.flatMap { NSScreen.screens.indices.contains($0) ? NSScreen.screens[$0] : nil }
        statusBar?.showCalendar(selecting: day, screen: screen)
    }

    public func showClipboard() {
        guard let screen = mouseScreen else { return }
        rememberTarget()
        statusBar?.closePopover()
        clipboard.onOpen()
        clipboardPanel?.keepsOpenOnResign = false
        if clipboardPanel == nil {
            let value = PanelController(title: "charl Clipboard", content: ClipboardPanelView(model: clipboard, actions: clipboardActions, ropeOpacity: Double(settingsModel.settings.clipboardRopeOpacity) / 100.0), size: NSSize(width: 1120, height: 340), resizable: true)
            value.onKey = { [weak self] event in self?.handleClipboardKey(event) ?? false }
            value.onClose = { [weak self] in self?.clipboard.releaseCaches(); AppIconCache.releaseAll() }
            clipboardPanel = value
        }
        let screenID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        if lastClipboardScreenID != screenID {
            clipboardPanel?.resetPreferredSize()
            lastClipboardScreenID = screenID
        }
        let settings = settingsModel.settings
        let width = screen.visibleFrame.width
        let height = min(max(CGFloat(settings.clipboardPanelHeight), 280), screen.visibleFrame.height - 48)
        let placement: PanelPlacement
        switch settings.clipboardPanelPosition {
        case .bottom: placement = .bottom
        case .center: placement = .center
        case .top: placement = .top
        }
        clipboardPanel?.show(on: screen, size: NSSize(width: width, height: height), placement: placement)
        if CommandLine.arguments.contains("--keep-open") { clipboardPanel?.keepsOpenOnResign = true }
    }

    var clipboardActions: ClipboardActions {
        ClipboardActions(
            activate: { [weak self] item in self?.activateClipboard(item) },
            preview: { [weak self] item in self?.previewClipboard(item) },
            copyOnly: { [weak self] item in self?.activateClipboard(item, copyOnly: true) },
            pinImage: { [weak self] item in self?.pinImage(item) },
            settings: { [weak self] in self?.openSettings() },
            close: { [weak self] in self?.closePanels() }
        )
    }

    public func previewClipboard(_ item: ClipboardItem) {
        clipboardPanel?.keepsOpenOnResign = true
        preview.show(item: item, image: clipboard.fullImage(for: item))
    }

    public func activateClipboard(_ item: ClipboardItem, copyOnly: Bool = false) {
        clipboard.copy(item)
        closePanels()
        let target = pasteTarget
        if let target {
            NSApp.yieldActivation(to: target)
            target.activate(from: .current, options: [])
        }
        guard !copyOnly && settingsModel.settings.autoPaste else { toast.show(loc("已复制", "Copied")); return }
        guard services.clipboard.canAutoPaste else { toast.show(loc("已复制；自动粘贴需要辅助功能权限", "Copied; auto-paste needs Accessibility access"), symbol: "exclamationmark.triangle"); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, let target, !target.isTerminated,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else { return }
            self.services.clipboard.sendPasteKeystroke()
        }
    }

    public func closePanels() {
        clipboardPanel?.close()
        statusBar?.closePopover()
        clipboard.releaseCaches()
    }

    private func handleClipboardKey(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), let text = event.charactersIgnoringModifiers, let number = Int(text), number >= 1, number <= 9 {
            let values = clipboard.visibleItems
            if values.indices.contains(number - 1) { activateClipboard(values[number - 1]) }
            return true
        }
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "," { openSettings(); return true }
        let editing = (event.window?.firstResponder as? NSTextView)?.isFieldEditor == true
        switch event.keyCode {
        case 53: closePanels(); return true
        case 123 where !editing: clipboard.moveSelection(-1); return true
        case 124 where !editing: clipboard.moveSelection(1); return true
        case 36, 76:
            if let item = clipboard.selectedItem { activateClipboard(item) }
            return true
        case 49 where !editing:
            if let item = clipboard.selectedItem { previewClipboard(item) }
            return true
        default: return false
        }
    }

    private func captureController() -> ScreenshotController {
        if let captureStorage { return captureStorage }
        let value = ScreenshotController(service: services.screenshot, toast: toast, settings: { [weak self] in self?.settingsModel.settings ?? .default }, onPin: { [weak self] image in self?.pins.show(image: image) })
        value.onCaptureEnd = { [weak self] in self?.setPanelsSuspended(false) }
        captureStorage = value
        return value
    }

    /// 截图期间暂停面板的“失焦自动关闭”：charl 自身窗口本就被排除在捕获外，
    /// 无需隐藏日历/剪贴板，截图结束后恢复其正常失焦行为。
    private func setPanelsSuspended(_ suspended: Bool) {
        clipboardPanel?.keepsOpenOnResign = suspended
        statusBar?.setCalendarKeepsOpen(suspended)
    }

    public func startCapture() { rememberTarget(); setPanelsSuspended(true); captureController().captureRegion() }
    public func captureFullScreen() { captureController().captureFullScreen() }
    public func pinClipboard() {
        closePanels()
        guard let image = NSImage(pasteboard: .general) else { toast.show(loc("剪贴板中没有图片", "No image in the clipboard"), symbol: "photo"); return }
        pins.show(image: image)
    }
    private func pinImage(_ item: ClipboardItem) {
        guard let image = clipboard.fullImage(for: item) else { return }
        closePanels()
        pins.show(image: image)
    }
    public func closeAllPins() { pins.closeAll() }
    public func openSettings() {
        closePanels()
        if settingsWindow == nil { settingsWindow = SettingsWindowController(model: self) }
        settingsWindow?.show()
    }

    // MARK: - 远程天气 / 法定假日（带缓存与离线回退）

    private struct RemoteCache: Codable {
        var weather: WeatherInfo?
        var weatherAt: Date?
        var holidays: [HolidayYear] = []
        var holidaysAt: Date?
    }

    private static let remoteCachePath = "remote-cache.json"

    private func loadRemoteCache() -> RemoteCache {
        (try? services.storage.read(Self.remoteCachePath))
            .flatMap { try? JSONDecoder().decode(RemoteCache.self, from: $0) } ?? RemoteCache()
    }

    private func saveRemoteCache(_ cache: RemoteCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? services.storage.write(data, to: Self.remoteCachePath)
    }

    private func userHolidayOverrides() -> [HolidayYear] {
        (try? services.storage.read("holidays.json"))
            .flatMap { try? JSONDecoder().decode([HolidayYear].self, from: $0) } ?? []
    }

    private func applyHolidays(remote: [HolidayYear]) {
        calendar.updateHolidays(.standard(overrides: remote + userHolidayOverrides()))
    }

    /// 打开日历/启动时刷新：天气 30 分钟缓存、假日 1 天缓存；失败回退缓存/内置。
    func refreshRemoteInfo() {
        let settings = settingsModel.settings
        let cache = loadRemoteCache()
        if settings.weatherEnabled {
            if let weather = cache.weather, let at = cache.weatherAt, Date().timeIntervalSince(at) < 1800 {
                calendar.updateWeather(weather)
            } else {
                Task { [weak self] in
                    guard let self, let weather = await self.services.remote.fetchWeather() else { return }
                    await MainActor.run {
                        self.calendar.updateWeather(weather)
                        var fresh = self.loadRemoteCache()
                        fresh.weather = weather
                        fresh.weatherAt = Date()
                        self.saveRemoteCache(fresh)
                    }
                }
            }
        } else {
            calendar.updateWeather(nil)
        }
        if settings.holidayAutoUpdate {
            let year = Day.today().year
            let cachedYear = cache.holidays.first(where: { $0.year == year })
            if let cachedYear, let at = cache.holidaysAt, Date().timeIntervalSince(at) < 86400 {
                applyHolidays(remote: [cachedYear])
            } else {
                Task { [weak self] in
                    guard let self, let holiday = await self.services.remote.fetchHolidays(year: year) else { return }
                    await MainActor.run {
                        self.applyHolidays(remote: [holiday])
                        var fresh = self.loadRemoteCache()
                        fresh.holidays = [holiday]
                        fresh.holidaysAt = Date()
                        self.saveRemoteCache(fresh)
                    }
                }
            }
        }
    }
}
