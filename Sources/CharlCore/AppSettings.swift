import Foundation

public enum MenuBarStyle: String, Codable, CaseIterable, Sendable {
    case iconOnly, iconLunar, iconDate

    public var title: String {
        switch self {
        case .iconOnly: return loc("仅图标", "Icon Only")
        case .iconLunar: return loc("图标 + 农历", "Icon + Lunar Day")
        case .iconDate: return loc("图标 + 日期", "Icon + Date")
        }
    }
}

public enum CalendarPalette: String, Codable, CaseIterable, Sendable {
    case mist, cream, ocean, lavender, ruby, matcha, sakura, sunset, graphite, custom

    public var title: String {
        switch self {
        case .mist: return loc("柠檬石墨", "Lemon Graphite")
        case .cream: return loc("奶油杏桃", "Cream Apricot")
        case .ocean: return loc("雾海青蓝", "Misty Blue")
        case .lavender: return loc("薄雾紫藤", "Hazy Wisteria")
        case .ruby: return loc("朱砂红", "Cinnabar Red")
        case .matcha: return loc("抹茶奶绿", "Matcha Milk")
        case .sakura: return loc("樱花粉黛", "Sakura Pink")
        case .sunset: return loc("暮霞橙金", "Dusk Orange")
        case .graphite: return loc("石墨冷灰", "Cool Graphite")
        case .custom: return loc("自定义颜色", "Custom Color")
        }
    }
}

public enum CalendarBackground: String, Codable, CaseIterable, Sendable {
    case native, clear, solid

    public var title: String {
        switch self {
        case .native: return loc("原生毛玻璃", "Native Material")
        case .clear: return loc("更透明", "More Transparent")
        case .solid: return loc("纯色", "Solid Color")
        }
    }
}

public enum ClipboardPanelPosition: String, Codable, CaseIterable, Sendable {
    case bottom, center, top

    public var title: String {
        switch self {
        case .bottom: return loc("底部停靠", "Dock at Bottom")
        case .center: return loc("屏幕居中", "Screen Center")
        case .top: return loc("顶部停靠", "Dock at Top")
        }
    }
}

/// 用户设置，JSON 持久化，跨平台同构。
public struct AppSettings: Codable, Hashable, Sendable {
    /// 界面语言偏好，默认跟随系统首选语言。
    public var language: LanguagePreference
    public var clipboardHotkey: KeyCombo
    public var screenshotHotkey: KeyCombo
    public var pinHotkey: KeyCombo
    public var maxTextItems: Int
    public var maxImageItems: Int
    public var saveScreenshotsToDisk: Bool
    public var showMagnifier: Bool
    public var autoPaste: Bool
    public var launchAtLogin: Bool
    public var menuBarStyle: MenuBarStyle
    public var weekStartsOnMonday: Bool
    public var calendarPalette: CalendarPalette
    public var calendarAccentHex: String
    public var calendarBackground: CalendarBackground
    public var calendarFontSize: Int
    public var weatherEnabled: Bool
    public var holidayAutoUpdate: Bool
    public var clipboardPanelPosition: ClipboardPanelPosition
    public var clipboardRopeOpacity: Int
    public var clipboardPanelHeight: Int

    public init(
        language: LanguagePreference = .system,
        clipboardHotkey: KeyCombo = AppConfig.clipboardHotkey,
        screenshotHotkey: KeyCombo = AppConfig.screenshotHotkey,
        pinHotkey: KeyCombo = AppConfig.pinHotkey,
        maxTextItems: Int = AppConfig.maxTextItems,
        maxImageItems: Int = AppConfig.maxImageItems,
        saveScreenshotsToDisk: Bool = true,
        showMagnifier: Bool = true,
        autoPaste: Bool = false,
        launchAtLogin: Bool = false,
        menuBarStyle: MenuBarStyle = .iconLunar,
        weekStartsOnMonday: Bool = true,
        calendarPalette: CalendarPalette = .mist,
        calendarAccentHex: String = "#2FB3A6",
        calendarBackground: CalendarBackground = .native,
        calendarFontSize: Int = 13,
        weatherEnabled: Bool = true,
        holidayAutoUpdate: Bool = true,
        clipboardPanelPosition: ClipboardPanelPosition = .bottom,
        clipboardRopeOpacity: Int = 100,
        clipboardPanelHeight: Int = 300
    ) {
        self.language = language
        self.clipboardHotkey = clipboardHotkey
        self.screenshotHotkey = screenshotHotkey
        self.pinHotkey = pinHotkey
        self.maxTextItems = maxTextItems
        self.maxImageItems = maxImageItems
        self.saveScreenshotsToDisk = saveScreenshotsToDisk
        self.showMagnifier = showMagnifier
        self.autoPaste = autoPaste
        self.launchAtLogin = launchAtLogin
        self.menuBarStyle = menuBarStyle
        self.weekStartsOnMonday = weekStartsOnMonday
        self.calendarPalette = calendarPalette
        self.calendarAccentHex = calendarAccentHex
        self.calendarBackground = calendarBackground
        self.calendarFontSize = calendarFontSize
        self.weatherEnabled = weatherEnabled
        self.holidayAutoUpdate = holidayAutoUpdate
        self.clipboardPanelPosition = clipboardPanelPosition
        self.clipboardRopeOpacity = clipboardRopeOpacity
        self.clipboardPanelHeight = clipboardPanelHeight
    }

    public static let `default` = AppSettings()

    /// 逐字段兜底：新版本新增字段时，旧 settings.json 保留用户已改的值，缺的字段取默认。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        language = try c.decodeIfPresent(LanguagePreference.self, forKey: .language) ?? d.language
        clipboardHotkey = try c.decodeIfPresent(KeyCombo.self, forKey: .clipboardHotkey) ?? d.clipboardHotkey
        screenshotHotkey = try c.decodeIfPresent(KeyCombo.self, forKey: .screenshotHotkey) ?? d.screenshotHotkey
        pinHotkey = try c.decodeIfPresent(KeyCombo.self, forKey: .pinHotkey) ?? d.pinHotkey
        maxTextItems = try c.decodeIfPresent(Int.self, forKey: .maxTextItems) ?? d.maxTextItems
        maxImageItems = try c.decodeIfPresent(Int.self, forKey: .maxImageItems) ?? d.maxImageItems
        saveScreenshotsToDisk = try c.decodeIfPresent(Bool.self, forKey: .saveScreenshotsToDisk) ?? d.saveScreenshotsToDisk
        showMagnifier = try c.decodeIfPresent(Bool.self, forKey: .showMagnifier) ?? d.showMagnifier
        autoPaste = try c.decodeIfPresent(Bool.self, forKey: .autoPaste) ?? d.autoPaste
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        menuBarStyle = try c.decodeIfPresent(MenuBarStyle.self, forKey: .menuBarStyle) ?? d.menuBarStyle
        weekStartsOnMonday = try c.decodeIfPresent(Bool.self, forKey: .weekStartsOnMonday) ?? d.weekStartsOnMonday
        calendarPalette = try c.decodeIfPresent(CalendarPalette.self, forKey: .calendarPalette) ?? d.calendarPalette
        calendarAccentHex = try c.decodeIfPresent(String.self, forKey: .calendarAccentHex) ?? d.calendarAccentHex
        calendarBackground = try c.decodeIfPresent(CalendarBackground.self, forKey: .calendarBackground) ?? d.calendarBackground
        calendarFontSize = try c.decodeIfPresent(Int.self, forKey: .calendarFontSize) ?? d.calendarFontSize
        weatherEnabled = try c.decodeIfPresent(Bool.self, forKey: .weatherEnabled) ?? d.weatherEnabled
        holidayAutoUpdate = try c.decodeIfPresent(Bool.self, forKey: .holidayAutoUpdate) ?? d.holidayAutoUpdate
        clipboardPanelPosition = try c.decodeIfPresent(ClipboardPanelPosition.self, forKey: .clipboardPanelPosition) ?? d.clipboardPanelPosition
        clipboardRopeOpacity = try c.decodeIfPresent(Int.self, forKey: .clipboardRopeOpacity) ?? d.clipboardRopeOpacity
        clipboardPanelHeight = try c.decodeIfPresent(Int.self, forKey: .clipboardPanelHeight) ?? d.clipboardPanelHeight
    }

    public mutating func clamp() {
        maxTextItems = min(max(10, maxTextItems), 2000)
        maxImageItems = min(max(5, maxImageItems), 500)
        calendarFontSize = min(max(10, calendarFontSize), 20)
        clipboardRopeOpacity = min(max(0, clipboardRopeOpacity), 100)
        clipboardPanelHeight = min(max(280, clipboardPanelHeight), 480)
    }
}