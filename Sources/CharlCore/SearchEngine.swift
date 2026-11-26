import Foundation

public enum SearchAction: String, CaseIterable, Sendable {
    case regionScreenshot, fullScreenshot, pinClipboard, clipboardPanel, calendarPanel, settings

    public var title: String {
        switch self {
        case .regionScreenshot: return loc("截图", "Screenshot")
        case .fullScreenshot: return loc("全屏截图", "Full-Screen Capture")
        case .pinClipboard: return loc("贴图", "Pin Image")
        case .clipboardPanel: return loc("剪贴板历史", "Clipboard History")
        case .calendarPanel: return loc("万年历", "Perpetual Calendar")
        case .settings: return loc("设置", "Settings")
        }
    }

    public var hint: String {
        switch self {
        case .regionScreenshot: return loc("定格屏幕，识别窗口，标注后复制 / 保存 / 贴图", "Freeze the screen, pick a window, then copy / save / pin")
        case .fullScreenshot: return loc("截取鼠标所在屏幕", "Capture the screen under the pointer")
        case .pinClipboard: return loc("把剪贴板图片钉在屏幕最上层", "Pin the clipboard image above everything")
        case .clipboardPanel: return loc("按分组浏览复制历史，⌘1–9 快速粘贴", "Browse history by group, paste with ⌘1–9")
        case .calendarPanel: return loc("农历 · 节气 · 法定节假日 · 日程", "Lunar dates · solar terms · public holidays · events")
        case .settings: return loc("快捷键、剪贴板、截图、日历选项", "Hotkeys, clipboard, capture and calendar options")
        }
    }

    public var symbol: String {
        switch self {
        case .regionScreenshot: return "scissors"
        case .fullScreenshot: return "camera.viewfinder"
        case .pinClipboard: return "pin"
        case .clipboardPanel: return "doc.on.clipboard"
        case .calendarPanel: return "calendar"
        case .settings: return "gearshape"
        }
    }

    var keywords: [String] {
        switch self {
        case .regionScreenshot: return ["截图", "截屏", "区域", "screenshot", "snip", "jt"]
        case .fullScreenshot: return ["截图", "全屏", "fullscreen", "full"]
        case .pinClipboard: return ["贴图", "钉", "pin", "tt"]
        case .clipboardPanel: return ["剪贴板", "粘贴板", "clipboard", "paste", "jtb"]
        case .calendarPanel: return ["日历", "万年历", "农历", "calendar", "rl", "wnl"]
        case .settings: return ["设置", "偏好", "settings", "preferences", "sz"]
        }
    }
}

public enum SearchResult: Identifiable, Hashable, Sendable {
    case clipboard(ClipboardItem)
    case date(Day)
    case action(SearchAction)

    public var id: String {
        switch self {
        case .clipboard(let item): return "c-\(item.id.uuidString)"
        case .date(let day): return "d-\(day.description)"
        case .action(let action): return "a-\(action.rawValue)"
        }
    }

    public var symbol: String {
        switch self {
        case .clipboard(let item): return item.kind == .image ? "photo" : "text.alignleft"
        case .date: return "calendar"
        case .action(let action): return action.symbol
        }
    }

    public var title: String {
        switch self {
        case .clipboard(let item): return item.preview
        case .date(let day):
            let almanac = Almanac(day: day)
            return "\(day.description) \(almanac.weekdayName)"
        case .action(let action): return action.title
        }
    }

    public var subtitle: String {
        switch self {
        case .clipboard(let item):
            return "\(item.sourceApp ?? loc("剪贴板", "Clipboard")) · \(RelativeTime.string(for: item.createdAt))"
        case .date(let day):
            let almanac = Almanac(day: day)
            let extras = (almanac.festivals + [almanac.termName].compactMap { $0 }).joined(separator: " · ")
            return extras.isEmpty ? almanac.lunarText : "\(almanac.lunarText) · \(extras)"
        case .action(let action): return action.hint
        }
    }
}

/// 统一搜索：日期解析 > 命令匹配 > 剪贴板内容匹配（前缀优先）。
public enum SearchEngine {
    public static func results(query: String, items: [ClipboardItem], today: Day = Day.today()) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return SearchAction.allCases.map { .action($0) } + items.prefix(8).map { .clipboard($0) }
        }

        var results: [SearchResult] = []
        if let day = parseDate(trimmed, today: today) {
            results.append(.date(day))
        }

        let lowered = trimmed.lowercased()
        for action in SearchAction.allCases {
            if action.title.lowercased().contains(lowered)
                || action.keywords.contains(where: { $0.trimmingCharacters(in: .whitespaces).lowercased().contains(lowered) || lowered.contains($0.trimmingCharacters(in: .whitespaces).lowercased()) }) {
                results.append(.action(action))
            }
        }

        let matched = items.filter { item in
            guard let text = item.text?.lowercased() else {
                return item.preview.lowercased().contains(lowered)
            }
            return text.contains(lowered)
        }
        let ranked = matched.sorted { lhs, rhs in
            let lp = lhs.preview.lowercased().hasPrefix(lowered)
            let rp = rhs.preview.lowercased().hasPrefix(lowered)
            if lp != rp { return lp }
            return lhs.createdAt > rhs.createdAt
        }
        results += ranked.prefix(12).map { .clipboard($0) }
        return results
    }

    public static func parseDate(_ query: String, today: Day) -> Day? {
        switch query {
        case "今天", "today": return today
        case "明天", "tomorrow": return today.addingDays(1)
        case "昨天", "yesterday": return today.addingDays(-1)
        case "前天", "the day before yesterday": return today.addingDays(-2)
        case "后天", "the day after tomorrow": return today.addingDays(2)
        default: break
        }

        var normalized = query
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        normalized = normalized.trimmingCharacters(in: .whitespaces)
        let parts = normalized.split(separator: "-").map(String.init)
        let numbers = parts.compactMap(Int.init)
        guard numbers.count == parts.count else { return nil }

        switch numbers.count {
        case 3:
            guard (1900...2100).contains(numbers[0]), (1...12).contains(numbers[1]), (1...31).contains(numbers[2]) else { return nil }
            let day = Day(year: numbers[0], month: numbers[1], day: numbers[2])
            return day.year == numbers[0] && day.month == numbers[1] && day.day == numbers[2] ? day : nil
        case 2:
            guard (1...12).contains(numbers[0]), (1...31).contains(numbers[1]) else { return nil }
            let day = Day(year: today.year, month: numbers[0], day: numbers[1])
            return day.month == numbers[0] && day.day == numbers[1] ? day : nil
        default:
            return nil
        }
    }
}