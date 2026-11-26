import Foundation

/// iCopy 式分组：全部 / 文本 / 图片 / 链接 / 收藏（置顶）。
public enum ClipboardGroup: String, CaseIterable, Identifiable, Sendable {
    case all, text, image, link, pinned

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return loc("全部", "All")
        case .text: return loc("文本", "Text")
        case .image: return loc("图片", "Images")
        case .link: return loc("链接", "Links")
        case .pinned: return loc("收藏", "Pinned")
        }
    }

    public func contains(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all: return true
        case .text: return item.kind == .text && !item.isLink
        case .image: return item.kind == .image
        case .link: return item.isLink
        case .pinned: return item.isPinned
        }
    }
}

extension ClipboardItem {
    /// 单行 http(s)/www 文本视为链接。
    public var isLink: Bool {
        guard kind == .text, let text else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return false }
        let lowered = trimmed.lowercased()
        return lowered.hasPrefix("http://") || lowered.hasPrefix("https://") || lowered.hasPrefix("www.")
    }

    public var linkHost: String? {
        guard isLink, let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased().hasPrefix("www.") ? "https://" + trimmed : trimmed
        return URL(string: normalized)?.host
    }

    public var characterCount: Int { text?.count ?? 0 }
}

public enum ClipboardQuery {
    /// 分组 + 关键词过滤；收藏项在"全部"中置前。
    public static func filter(_ items: [ClipboardItem], group: ClipboardGroup, keyword: String) -> [ClipboardItem] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = items.filter { item in
            guard group.contains(item) else { return false }
            guard !trimmed.isEmpty else { return true }
            return item.preview.localizedCaseInsensitiveContains(trimmed)
                || (item.text?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || (item.sourceApp?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
        guard group == .all else { return matched }
        return matched.filter(\.isPinned) + matched.filter { !$0.isPinned }
    }
}