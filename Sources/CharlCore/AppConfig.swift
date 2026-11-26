import Foundation

public enum AppConfig {
    public static let appName = "charl"
    public static let bundleID = "com.charl.charl"
    public static let logSubsystem = "com.charl.charl"
    public static let dataDirectoryName = "charl"
    public static let legacyDataDirectoryName = "Chao"

    public static let clipboardHotkey = KeyCombo(modifiers: [.control, .option], key: .c)
    public static let screenshotHotkey = KeyCombo(modifiers: [.control, .option], key: .s)
    public static let pinHotkey = KeyCombo(modifiers: [.control, .option], key: .p)

    public static let clipboardPollInterval: TimeInterval = 0.5
    public static let maxTextItems = 200
    public static let maxImageItems = 50
    public static let maxImageBytes = 20 * 1024 * 1024
    public static let thumbnailMaxPixel: Double = 480

    public static let screenshotDirectoryName = "charl"
}