import Foundation

/// 语言偏好：system 跟随系统首选语言，其余为手动指定。
public enum LanguagePreference: String, Codable, CaseIterable, Sendable {
    case system, chinese, english

    public var title: String {
        switch self {
        case .system: return loc("跟随系统", "Follow System")
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }
}

/// 实际生效的界面语言。
public enum AppLanguage: Equatable, Sendable {
    case chinese, english
}

/// 双语界面文案。中文是基准文案，英文对照；偏好由设置写入点同步到 `preference`。
public enum Lang {
    public static var preference: LanguagePreference = .system

    public static var current: AppLanguage { resolve(preference: preference) }
    public static var isEnglish: Bool { current == .english }

    public static func resolve(preference: LanguagePreference, preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        switch preference {
        case .chinese: return .chinese
        case .english: return .english
        case .system:
            guard let first = preferredLanguages.first?.lowercased() else { return .english }
            return first.hasPrefix("zh") ? .chinese : .english
        }
    }
}

/// 取当前语言的界面文案。含插值的两侧都要写全，便于对照校对。
@inline(__always)
public func loc(_ chinese: String, _ english: String) -> String {
    Lang.isEnglish ? english : chinese
}
