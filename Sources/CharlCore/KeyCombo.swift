import Foundation

/// 跨平台逻辑按键；各平台层负责映射到原生键码（macOS: Carbon kVK_*）。
public struct KeyCombo: Codable, Hashable, Sendable {
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let control = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)
    }

    public enum Key: String, Codable, Hashable, Sendable, CaseIterable {
        case a, b, c, d, e, f, g, h, i, j, k, l, m
        case n, o, p, q, r, s, t, u, v, w, x, y, z
        case zero = "0", one = "1", two = "2", three = "3", four = "4"
        case five = "5", six = "6", seven = "7", eight = "8", nine = "9"
        case space, escape, `return`, tab, delete
        case up, down, left, right
        case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

        public var displayName: String {
            switch self {
            case .space: return "Space"
            case .escape: return "Esc"
            case .return: return "↩"
            case .tab: return "⇥"
            case .delete: return "⌫"
            case .up: return "↑"
            case .down: return "↓"
            case .left: return "←"
            case .right: return "→"
            default: return rawValue.uppercased()
            }
        }
    }

    public var modifiers: Modifiers
    public var key: Key

    public init(modifiers: Modifiers, key: Key) {
        self.modifiers = modifiers
        self.key = key
    }

    /// HIG 顺序：⌃⌥⇧⌘
    public var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + key.displayName
    }
}