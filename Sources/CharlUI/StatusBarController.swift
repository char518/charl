import AppKit
import CharlCore
import SwiftUI

/// 菜单栏入口（参考「万年历」）：图标显示今日日期，可选附带农历 / 公历文字；
/// 左键弹出日历，右键弹出功能菜单。
final class StatusBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let calendarWindow = CalendarWindowController()
    private weak var model: AppModel?
    private var timer: Timer?
    private var renderedDay: Day?

    init(model: AppModel) {
        self.model = model
        super.init()

        // 主内容在首次打开时创建，避免启动即初始化日历模块。
        refresh(force: true)
        if let button = item.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refresh(force: false) }
        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged), name: .NSCalendarDayChanged, object: nil)
    }

    func refresh(force: Bool) {
        let today = Day.today()
        guard force || today != renderedDay, let button = item.button else { return }
        renderedDay = today
        button.image = Self.dayIcon(day: today.day)
        let style = model?.settingsModel.settings.menuBarStyle ?? .iconLunar
        switch style {
        case .iconOnly:
            button.title = ""
        case .iconLunar:
            let lunar = Almanac(day: today).lunarMonthDay
            button.title = " " + lunar
        case .iconDate:
            let weekday = Lang.isEnglish
                ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][today.weekday]
                : ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][today.weekday]
            // 菜单栏标题必须极短：英文用 M/D + 三字母星期。
            button.title = " " + loc("\(today.month)月\(today.day)日 \(weekday)", "\(today.month)/\(today.day) \(weekday)")
        }
        button.toolTip = "charl · \(Almanac(day: today).lunarText)"
        button.setAccessibilityLabel(loc("charl 日历", "charl Calendar"))
        button.setAccessibilityValue(Almanac(day: today).lunarText)
        button.setAccessibilityHelp(loc("点击打开日历，右键打开工具菜单", "Click to open the calendar, right-click for the tools menu"))
    }

    func showCalendar(selecting day: Day? = nil, screen: NSScreen? = nil) {
        guard let button = item.button, let model else { return }
        calendarWindow.show(anchor: button, model: model, selecting: day, screen: screen)
    }

    func closePopover() {
        calendarWindow.close()
    }

    func setCalendarKeepsOpen(_ value: Bool) {
        calendarWindow.keepsOpenOnResign = value
    }

    @objc private func dayChanged() {
        DispatchQueue.main.async { [weak self] in self?.refresh(force: true) }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        model?.rememberTarget()
        let isRight = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRight {
            closePopover()
            showMenu()
        } else if calendarWindow.isShown {
            closePopover()
        } else {
            showCalendar()
        }
    }

    private func showMenu() {
        guard let model else { return }
        let settings = model.settingsModel.settings
        let menu = NSMenu()
        menu.addItem(menuItem(loc("剪贴板历史", "Clipboard History"), combo: settings.clipboardHotkey, symbol: "doc.on.clipboard") { model.showClipboard() })
        menu.addItem(.separator())
        menu.addItem(menuItem(loc("截图", "Capture"), combo: settings.screenshotHotkey, symbol: "scissors") { model.startCapture() })
        menu.addItem(menuItem(loc("全屏截图", "Full Screen"), combo: nil, symbol: "camera.viewfinder") { model.captureFullScreen() })
        menu.addItem(menuItem(loc("贴图（剪贴板）", "Pin Clipboard"), combo: settings.pinHotkey, symbol: "pin") { model.pinClipboard() })
        menu.addItem(menuItem(loc("关闭全部贴图", "Close All Pins"), combo: nil, symbol: "pin.slash") { model.closeAllPins() })
        menu.addItem(.separator())
        menu.addItem(menuItem(loc("万年历", "Calendar"), combo: nil, symbol: "calendar") { [weak self] in self?.showCalendar() })
        menu.addItem(.separator())
        menu.addItem(menuItem(loc("设置…", "Settings…"), combo: nil, symbol: "gearshape") { model.openSettings() })
        menu.addItem(menuItem(loc("退出 charl", "Quit charl"), combo: nil, symbol: "power") { NSApp.terminate(nil) })
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func menuItem(_ title: String, combo: KeyCombo?, symbol: String, action: @escaping () -> Void) -> NSMenuItem {
        let menuItem = ClosureMenuItem(title: title, action: action)
        menuItem.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        if let combo {
            menuItem.keyEquivalent = combo.key.menuKeyEquivalent
            menuItem.keyEquivalentModifierMask = combo.modifiers.eventFlags
        }
        return menuItem
    }

    /// 日历形状的模板图标，内嵌今日日期数字（随明暗自动着色）。
    static func dayIcon(day: Int) -> NSImage {
        let size = NSSize(width: 18, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            let body = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 0.75), xRadius: 3.5, yRadius: 3.5)
            body.lineWidth = 1.3
            NSColor.black.setStroke()
            body.stroke()
            let bar = NSBezierPath(rect: NSRect(x: rect.minX + 1, y: rect.maxY - 5, width: rect.width - 2, height: 4.25))
            NSColor.black.setFill()
            bar.fill()
            let text = "\(day)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8.5, weight: .bold),
                .foregroundColor: NSColor.black,
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.minY + 1.2), withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func fire() {
        handler()
    }
}

extension KeyCombo.Key {
    var menuKeyEquivalent: String {
        switch self {
        case .space: return " "
        case .escape: return "\u{1b}"
        case .return: return "\r"
        case .tab: return "\t"
        case .delete: return "\u{8}"
        case .up, .down, .left, .right: return ""
        case .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12: return ""
        default: return rawValue
        }
    }
}

extension KeyCombo.Modifiers {
    var eventFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command) { flags.insert(.command) }
        if contains(.control) { flags.insert(.control) }
        if contains(.option) { flags.insert(.option) }
        if contains(.shift) { flags.insert(.shift) }
        return flags
    }
}