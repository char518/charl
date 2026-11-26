import AppKit
import CharlCore
import SwiftUI

enum Theme {
    static let accentNS = NSColor.systemBlue
    static let accent = Color(nsColor: accentNS)
    static let holidayNS = NSColor.systemRed
    static let holiday = Color(nsColor: holidayNS)
    static let workday = Color(nsColor: .systemOrange)
    static let term = Color(nsColor: .systemGreen)
    static let label = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .secondaryLabelColor)
    static let tertiary = Color(nsColor: .tertiaryLabelColor)
    static let separator = Color(nsColor: .separatorColor)
    static let hairline = Color(nsColor: .separatorColor).opacity(0.5)

    static let panel = Color(nsColor: .windowBackgroundColor).opacity(0.94)
    static let sidebar = Color(nsColor: .tertiarySystemFill)
    static let card = Color(nsColor: .quaternarySystemFill)
    static let elevatedCard = Color(nsColor: .controlBackgroundColor)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let fill = Color.primary.opacity(0.04)
    static let hover = Color.primary.opacity(0.06)
    static let pressed = Color.primary.opacity(0.09)
    static let selected = Color.primary.opacity(0.065)
    static let selectedStrong = Color.primary.opacity(0.11)

    static let weekend = secondary
    static let holidaySoft = holiday
    static let termSoft = term

    static let radiusSmall: CGFloat = 6
    static let radius: CGFloat = 10
    static let radiusLarge: CGFloat = 16
    static let panelRadius: CGFloat = 18

    static let appHues: [Color] = [
        Color(nsColor: .systemBlue),
        Color(nsColor: .systemGreen),
        Color(nsColor: .systemOrange),
        Color(nsColor: .systemPurple),
        Color(nsColor: .systemPink),
        Color(nsColor: .systemTeal),
    ]

    static func hue(for key: String) -> Color {
        let hash = key.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return appHues[hash % appHues.count]
    }

    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static func motion(_ animation: Animation = .snappy(duration: 0.18)) -> Animation? {
        reduceMotion ? nil : animation
    }
}

private func calendarColor(_ light: NSColor, _ dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    })
}

enum DisplayScaling {
    static func apply(to view: NSView, scale: CGFloat) {
        view.wantsLayer = true
        view.layer?.contentsScale = scale
        view.layer?.rasterizationScale = scale
        view.layer?.needsDisplay()
        for subview in view.subviews { apply(to: subview, scale: scale) }
    }

    static func apply(to window: NSWindow) {
        guard let content = window.contentView else { return }
        apply(to: content, scale: window.backingScaleFactor)
    }
}

/// NSHostingView 跟随所在窗口的 backingScaleFactor 自动同步渲染倍率，
/// 在跨显示器（内建 2x / 外接 1x）移动或首次挂载时保持文字与矢量清晰。
final class ScaledHostingView<Content: View>: NSHostingView<Content> {
    var minimumScale: CGFloat = 1

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        syncScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        syncScale()
    }

    private func syncScale() {
        guard let window else { return }
        wantsLayer = true
        let scale = max(window.backingScaleFactor, minimumScale)
        layer?.contentsScale = scale
        layer?.rasterizationScale = scale
    }

    override func scrollWheel(with event: NSEvent) {
        if let scrollView = enclosingScrollView {
            scrollView.scrollWheel(with: event)
            return
        }
        if routingScroll { return }
        if let scrollView = firstDescendantScrollView() {
            routingScroll = true
            scrollView.scrollWheel(with: event)
            routingScroll = false
            return
        }
        // 面板内无人处理的滚轮事件在此消费，避免穿透滚动到背后的窗口
    }

    // 透明面板的空白处（如卡片间隙）默认 hitTest 返回 nil，会落到背后窗口；
    // 这里兜底返回自身，保证整块面板都接收鼠标/滚轮事件。
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) ?? self
    }

    private var routingScroll = false

    private func firstDescendantScrollView() -> NSScrollView? {
        charlDescendantScrollView()
    }
}

private extension NSView {
    func charlDescendantScrollView() -> NSScrollView? {
        for sub in subviews {
            if let scrollView = sub as? NSScrollView { return scrollView }
            if let found = sub.charlDescendantScrollView() { return found }
        }
        return nil
    }
}

extension CalendarPalette {
    var background: Color {
        switch self {
        case .mist:
            return calendarColor(
                NSColor(srgbRed: 0.961, green: 0.957, blue: 0.937, alpha: 1),
                NSColor(srgbRed: 0.125, green: 0.129, blue: 0.114, alpha: 1)
            )
        case .cream:
            return calendarColor(
                NSColor(srgbRed: 1.000, green: 0.973, blue: 0.929, alpha: 1),
                NSColor(srgbRed: 0.161, green: 0.137, blue: 0.118, alpha: 1)
            )
        case .ocean:
            return calendarColor(
                NSColor(srgbRed: 0.949, green: 0.969, blue: 0.980, alpha: 1),
                NSColor(srgbRed: 0.090, green: 0.141, blue: 0.169, alpha: 1)
            )
        case .lavender:
            return calendarColor(
                NSColor(srgbRed: 0.969, green: 0.957, blue: 0.984, alpha: 1),
                NSColor(srgbRed: 0.129, green: 0.118, blue: 0.161, alpha: 1)
            )
        case .ruby:
            return calendarColor(
                NSColor(srgbRed: 0.984, green: 0.961, blue: 0.957, alpha: 1),
                NSColor(srgbRed: 0.145, green: 0.102, blue: 0.102, alpha: 1)
            )
        case .matcha:
            return calendarColor(
                NSColor(srgbRed: 0.957, green: 0.973, blue: 0.949, alpha: 1),
                NSColor(srgbRed: 0.118, green: 0.137, blue: 0.122, alpha: 1)
            )
        case .sakura:
            return calendarColor(
                NSColor(srgbRed: 0.992, green: 0.961, blue: 0.969, alpha: 1),
                NSColor(srgbRed: 0.157, green: 0.118, blue: 0.133, alpha: 1)
            )
        case .sunset:
            return calendarColor(
                NSColor(srgbRed: 0.996, green: 0.965, blue: 0.929, alpha: 1),
                NSColor(srgbRed: 0.161, green: 0.129, blue: 0.102, alpha: 1)
            )
        case .graphite:
            return calendarColor(
                NSColor(srgbRed: 0.965, green: 0.969, blue: 0.976, alpha: 1),
                NSColor(srgbRed: 0.118, green: 0.125, blue: 0.137, alpha: 1)
            )
        case .custom:
            return calendarColor(
                NSColor(srgbRed: 0.973, green: 0.973, blue: 0.976, alpha: 1),
                NSColor(srgbRed: 0.137, green: 0.137, blue: 0.149, alpha: 1)
            )
        }
    }

    var accent: Color {
        switch self {
        case .mist:
            return calendarColor(
                NSColor(srgbRed: 0.514, green: 0.639, blue: 0.000, alpha: 1),
                NSColor(srgbRed: 0.827, green: 0.953, blue: 0.290, alpha: 1)
            )
        case .cream:
            return calendarColor(
                NSColor(srgbRed: 0.776, green: 0.482, blue: 0.275, alpha: 1),
                NSColor(srgbRed: 0.941, green: 0.682, blue: 0.463, alpha: 1)
            )
        case .ocean:
            return calendarColor(
                NSColor(srgbRed: 0.184, green: 0.498, blue: 0.624, alpha: 1),
                NSColor(srgbRed: 0.435, green: 0.765, blue: 0.875, alpha: 1)
            )
        case .lavender:
            return calendarColor(
                NSColor(srgbRed: 0.482, green: 0.380, blue: 0.722, alpha: 1),
                NSColor(srgbRed: 0.718, green: 0.612, blue: 0.910, alpha: 1)
            )
        case .ruby:
            return calendarColor(
                NSColor(srgbRed: 0.851, green: 0.227, blue: 0.227, alpha: 1),
                NSColor(srgbRed: 1.000, green: 0.420, blue: 0.420, alpha: 1)
            )
        case .matcha:
            return calendarColor(
                NSColor(srgbRed: 0.337, green: 0.525, blue: 0.329, alpha: 1),
                NSColor(srgbRed: 0.596, green: 0.800, blue: 0.565, alpha: 1)
            )
        case .sakura:
            return calendarColor(
                NSColor(srgbRed: 0.800, green: 0.329, blue: 0.459, alpha: 1),
                NSColor(srgbRed: 0.949, green: 0.565, blue: 0.678, alpha: 1)
            )
        case .sunset:
            return calendarColor(
                NSColor(srgbRed: 0.851, green: 0.451, blue: 0.180, alpha: 1),
                NSColor(srgbRed: 0.980, green: 0.659, blue: 0.380, alpha: 1)
            )
        case .graphite:
            return calendarColor(
                NSColor(srgbRed: 0.337, green: 0.380, blue: 0.443, alpha: 1),
                NSColor(srgbRed: 0.659, green: 0.710, blue: 0.780, alpha: 1)
            )
        case .custom:
            return calendarColor(
                NSColor(srgbRed: 0.184, green: 0.702, blue: 0.651, alpha: 1),
                NSColor(srgbRed: 0.435, green: 0.831, blue: 0.792, alpha: 1)
            )
        }
    }

    var label: Color {
        switch self {
        case .mist:
            return calendarColor(
                NSColor(srgbRed: 0.141, green: 0.149, blue: 0.122, alpha: 1),
                NSColor(srgbRed: 0.957, green: 0.961, blue: 0.925, alpha: 1)
            )
        case .cream:
            return calendarColor(
                NSColor(srgbRed: 0.243, green: 0.192, blue: 0.157, alpha: 1),
                NSColor(srgbRed: 0.965, green: 0.933, blue: 0.898, alpha: 1)
            )
        case .ocean:
            return calendarColor(
                NSColor(srgbRed: 0.133, green: 0.192, blue: 0.227, alpha: 1),
                NSColor(srgbRed: 0.918, green: 0.953, blue: 0.965, alpha: 1)
            )
        case .lavender:
            return calendarColor(
                NSColor(srgbRed: 0.176, green: 0.157, blue: 0.216, alpha: 1),
                NSColor(srgbRed: 0.945, green: 0.929, blue: 0.969, alpha: 1)
            )
        case .ruby:
            return calendarColor(
                NSColor(srgbRed: 0.169, green: 0.114, blue: 0.114, alpha: 1),
                NSColor(srgbRed: 0.965, green: 0.925, blue: 0.925, alpha: 1)
            )
        case .matcha:
            return calendarColor(
                NSColor(srgbRed: 0.141, green: 0.176, blue: 0.137, alpha: 1),
                NSColor(srgbRed: 0.945, green: 0.965, blue: 0.937, alpha: 1)
            )
        case .sakura:
            return calendarColor(
                NSColor(srgbRed: 0.200, green: 0.137, blue: 0.161, alpha: 1),
                NSColor(srgbRed: 0.973, green: 0.937, blue: 0.949, alpha: 1)
            )
        case .sunset:
            return calendarColor(
                NSColor(srgbRed: 0.220, green: 0.161, blue: 0.118, alpha: 1),
                NSColor(srgbRed: 0.976, green: 0.949, blue: 0.918, alpha: 1)
            )
        case .graphite:
            return calendarColor(
                NSColor(srgbRed: 0.137, green: 0.149, blue: 0.169, alpha: 1),
                NSColor(srgbRed: 0.949, green: 0.957, blue: 0.973, alpha: 1)
            )
        case .custom:
            return calendarColor(
                NSColor(srgbRed: 0.129, green: 0.129, blue: 0.141, alpha: 1),
                NSColor(srgbRed: 0.961, green: 0.961, blue: 0.969, alpha: 1)
            )
        }
    }

    var secondary: Color {
        switch self {
        case .mist:
            return calendarColor(
                NSColor(srgbRed: 0.400, green: 0.412, blue: 0.361, alpha: 1),
                NSColor(srgbRed: 0.710, green: 0.722, blue: 0.659, alpha: 1)
            )
        case .cream:
            return calendarColor(
                NSColor(srgbRed: 0.541, green: 0.463, blue: 0.396, alpha: 1),
                NSColor(srgbRed: 0.741, green: 0.663, blue: 0.604, alpha: 1)
            )
        case .ocean:
            return calendarColor(
                NSColor(srgbRed: 0.376, green: 0.463, blue: 0.506, alpha: 1),
                NSColor(srgbRed: 0.624, green: 0.706, blue: 0.741, alpha: 1)
            )
        case .lavender:
            return calendarColor(
                NSColor(srgbRed: 0.443, green: 0.416, blue: 0.494, alpha: 1),
                NSColor(srgbRed: 0.702, green: 0.667, blue: 0.761, alpha: 1)
            )
        case .ruby:
            return calendarColor(
                NSColor(srgbRed: 0.478, green: 0.384, blue: 0.384, alpha: 1),
                NSColor(srgbRed: 0.761, green: 0.643, blue: 0.643, alpha: 1)
            )
        case .matcha:
            return calendarColor(
                NSColor(srgbRed: 0.392, green: 0.447, blue: 0.380, alpha: 1),
                NSColor(srgbRed: 0.686, green: 0.737, blue: 0.667, alpha: 1)
            )
        case .sakura:
            return calendarColor(
                NSColor(srgbRed: 0.498, green: 0.396, blue: 0.435, alpha: 1),
                NSColor(srgbRed: 0.769, green: 0.667, blue: 0.706, alpha: 1)
            )
        case .sunset:
            return calendarColor(
                NSColor(srgbRed: 0.525, green: 0.435, blue: 0.361, alpha: 1),
                NSColor(srgbRed: 0.780, green: 0.690, blue: 0.612, alpha: 1)
            )
        case .graphite:
            return calendarColor(
                NSColor(srgbRed: 0.400, green: 0.424, blue: 0.463, alpha: 1),
                NSColor(srgbRed: 0.686, green: 0.710, blue: 0.753, alpha: 1)
            )
        case .custom:
            return calendarColor(
                NSColor(srgbRed: 0.420, green: 0.420, blue: 0.443, alpha: 1),
                NSColor(srgbRed: 0.702, green: 0.702, blue: 0.722, alpha: 1)
            )
        }
    }

    var todayFill: Color {
        switch self {
        case .mist:
            return calendarColor(
                NSColor(srgbRed: 0.780, green: 0.949, blue: 0.227, alpha: 1),
                NSColor(srgbRed: 0.851, green: 0.965, blue: 0.353, alpha: 1)
            )
        case .cream, .ocean, .lavender, .ruby, .matcha, .sakura, .sunset, .graphite, .custom: return accent
        }
    }

    var todayText: Color {
        switch self {
        case .mist: return Color(nsColor: NSColor(srgbRed: 0.149, green: 0.192, blue: 0.000, alpha: 1))
        case .cream, .ocean, .lavender, .ruby, .matcha, .sakura, .sunset, .graphite, .custom: return .white
        }
    }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0x007AFF
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return "#2FB3A6" }
        return String(
            format: "#%02X%02X%02X",
            Int((rgb.redComponent * 255).rounded()),
            Int((rgb.greenComponent * 255).rounded()),
            Int((rgb.blueComponent * 255).rounded())
        )
    }
}

struct MaterialBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

struct PanelBackground: View {
    var material: NSVisualEffectView.Material = .popover

    var body: some View {
        ZStack {
            MaterialBackground(material: material)
            Theme.panel
        }
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.5)
    }
}

struct Keycap: View {
    let glyph: String

    var body: some View {
        Text(glyph)
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .frame(minWidth: 20, minHeight: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.fill))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.hairline, lineWidth: 0.5))
    }
}

struct KeycapCombo: View {
    let combo: KeyCombo

    var body: some View {
        HStack(spacing: 3) {
            if combo.modifiers.contains(.control) { Keycap(glyph: "⌃") }
            if combo.modifiers.contains(.option) { Keycap(glyph: "⌥") }
            if combo.modifiers.contains(.shift) { Keycap(glyph: "⇧") }
            if combo.modifiers.contains(.command) { Keycap(glyph: "⌘") }
            Keycap(glyph: combo.key.displayName)
        }
    }
}

struct HintBar: View {
    let hints: [(keys: [String], label: String)]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                HStack(spacing: 4) {
                    ForEach(hint.keys, id: \.self) { Keycap(glyph: $0) }
                    Text(hint.label)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.tertiary)
                }
            }
        }
    }
}

struct IconTile: View {
    let symbol: String
    var tint: Color = Theme.accent
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.29).fill(tint.opacity(0.11)))
    }
}

struct BrandIcon: View {
    var size: CGFloat = 36

    var body: some View {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .frame(width: size, height: size)
        } else {
            IconTile(symbol: "sparkles", size: size)
        }
    }
}

struct Chip: View {
    let text: String
    var tint: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.10)))
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 27, weight: .light))
                .foregroundStyle(Theme.tertiary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.fill))
            Text(title)
                .font(.system(size: 15.5, weight: .medium))
                .foregroundStyle(Theme.label)
            Text(message)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InlineNotice: View {
    let symbol: String
    let text: String
    var tint: Color = Theme.accent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(tint.opacity(0.07)))
    }
}

struct AppIconView: View {
    let bundleID: String?
    let name: String
    var size: CGFloat = 18

    var body: some View {
        if let icon = AppIconCache.icon(for: bundleID) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.52, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: size * 0.27).fill(Theme.hue(for: name)))
        }
    }
}

enum AppIconCache {
    private static var cache: [String: NSImage] = [:]
    private static var missing: Set<String> = []

    static func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let cached = cache[bundleID] { return cached }
        if missing.contains(bundleID) { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            missing.insert(bundleID)
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)
        cache[bundleID] = icon
        return icon
    }

    static func releaseAll() {
        cache.removeAll()
        missing.removeAll()
    }
}

struct RowBackground: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(isSelected ? Theme.selected : (isHovered ? Theme.hover : .clear))
        )
    }
}

extension View {
    func rowBackground(isSelected: Bool, isHovered: Bool) -> some View {
        modifier(RowBackground(isSelected: isSelected, isHovered: isHovered))
    }
}

struct ToolButton: View {
    let symbol: String
    var help: String = ""
    var isActive = false
    var tint: Color = Theme.secondary
    var size: CGFloat = 28
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(isActive ? Theme.accent : tint)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: max(6, size * 0.25))
                        .fill(isActive ? Theme.selectedStrong : (hovering ? Theme.hover : .clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.motion(.easeOut(duration: 0.12)), value: hovering)
        .help(help)
        .accessibilityLabel(help.isEmpty ? symbol : help)
    }
}
