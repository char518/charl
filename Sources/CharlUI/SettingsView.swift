import AppKit
import CharlCore
import SwiftUI

private let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.1"

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, hotkeys, clipboard, capture, calendar
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return loc("通用", "General")
        case .hotkeys: return loc("快捷键", "Hotkeys")
        case .clipboard: return loc("剪贴板", "Clipboard")
        case .capture: return loc("截图与贴图", "Capture & Pin")
        case .calendar: return loc("日历", "Calendar")
        }
    }

    var subtitle: String {
        switch self {
        case .general: return loc("启动、菜单栏与应用数据", "Launch, menu bar and app data")
        case .hotkeys: return loc("让常用操作触手可及", "Keep common actions within reach")
        case .clipboard: return loc("历史容量、粘贴与隐私", "History size, pasting and privacy")
        case .capture: return loc("截图辅助与贴图手势", "Capture helpers and pin gestures")
        case .calendar: return loc("周起始与个人日程", "Week start and personal events")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .hotkeys: return "keyboard"
        case .clipboard: return "doc.on.clipboard"
        case .capture: return "camera.viewfinder"
        case .calendar: return "calendar"
        }
    }

    var tint: Color {
        switch self {
        case .general: return Color(nsColor: .systemBlue)
        case .hotkeys: return Color(nsColor: .systemPurple)
        case .clipboard: return Color(nsColor: .systemTeal)
        case .capture: return Color(nsColor: .systemOrange)
        case .calendar: return Color(nsColor: .systemRed)
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var store: SettingsModel
    @State private var selection: SettingsTab = .general
    @State private var loginEnabled = false
    @State private var message: String?

    public init(model: AppModel) {
        self.init(model: model, initialTab: .general)
    }

    init(model: AppModel, initialTab: SettingsTab) {
        self.model = model
        store = model.settingsModel
        _selection = State(initialValue: initialTab)
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)
            VStack(spacing: 0) {
                header
                Hairline()
                ScrollView {
                    content
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.windowBackground)
        }
        .frame(width: 740, height: 540)
        .background(Theme.windowBackground)
        .toggleStyle(.switch)
        .tint(Theme.accent)
        .onAppear { loginEnabled = model.services.loginItem.isEnabled }
        .onDisappear { model.cancelRecording() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                BrandIcon(size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("charl")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(loc("菜单栏效率工具", "Menu bar utility"))
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.tertiary)
                }
            }
            .padding(.horizontal, 7)
            .padding(.bottom, 22)

            ForEach(SettingsTab.allCases) { tab in
                SidebarButton(tab: tab, isSelected: selection == tab) {
                    selection = tab
                }
            }

            Spacer()
            Text(loc("版本 \(appVersion)", "Version \(appVersion)"))
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiary)
                .padding(.horizontal, 9)
                .padding(.bottom, 5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 19)
        .frame(width: 184)
        .frame(maxHeight: .infinity)
        .background(Theme.sidebar)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selection.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.label)
                Text(selection.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .general: general
        case .hotkeys: hotkeys
        case .clipboard: clipboard
        case .capture: capture
        case .calendar: CalendarSettings(model: model)
        }
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard(loc("启动与外观", "Launch & Appearance")) {
                SettingsRow(title: loc("登录时启动", "Launch at Login"), detail: loc("登录 Mac 后自动在菜单栏运行 charl", "Run charl in the menu bar after you sign in")) {
                    Toggle("", isOn: Binding(get: { loginEnabled }, set: { enabled in
                        do {
                            try model.services.loginItem.setEnabled(enabled)
                            loginEnabled = model.services.loginItem.isEnabled
                            store.settings.launchAtLogin = loginEnabled
                            message = loginEnabled == enabled ? nil : loc("请在系统设置的登录项中确认允许 charl。", "Allow charl in Login Items in System Settings.")
                        } catch {
                            message = error.localizedDescription
                        }
                    }))
                    .labelsHidden()
                }
                SettingsSeparator()
                SettingsRow(title: loc("界面语言", "Language"), detail: loc("默认跟随系统首选语言", "Defaults to your system language")) {
                    Picker("", selection: $store.settings.language) {
                        ForEach(LanguagePreference.allCases, id: \.self) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 158)
                }
                SettingsSeparator()
                SettingsRow(title: loc("菜单栏显示", "Menu Bar Display"), detail: loc("选择日期信息的显示方式", "Choose how date info appears")) {
                    Picker("", selection: $store.settings.menuBarStyle) {
                        ForEach(MenuBarStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 158)
                }
            }

            if let message {
                InlineNotice(symbol: "exclamationmark.circle", text: message, tint: Theme.workday)
            }

            SettingsCard(loc("数据", "Data")) {
                SettingsRow(title: loc("应用数据", "App Data"), detail: loc("设置、剪贴板历史与节假日配置", "Settings, clipboard history and holidays")) {
                    Button(loc("打开数据目录", "Open Data Folder")) {
                        NSWorkspace.shared.open(model.services.storage.url(for: ""))
                    }
                    .controlSize(.small)
                }
                SettingsSeparator()
                SettingsRow(title: loc("存储位置", "Storage Location"), detail: "~/Library/Application Support/charl") {
                    Image(systemName: "folder")
                        .foregroundStyle(Theme.tertiary)
                }
            }

            Text(loc("左键菜单栏图标打开日历，右键打开全部工具。", "Left-click the menu bar icon for the calendar, right-click for all tools."))
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiary)
                .padding(.horizontal, 2)
        }
    }

    private var hotkeys: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard(loc("全局快捷键", "Global Hotkeys")) {
                ForEach(HotkeySlot.allCases) { slot in
                    HotkeyRow(model: model, slot: slot)
                    if slot != .pin { SettingsSeparator() }
                }
            }

            if let error = model.hotkeyError {
                InlineNotice(symbol: "exclamationmark.triangle", text: error, tint: Theme.workday)
            }

            HStack(alignment: .center, spacing: 16) {
                Text(loc("点击组合键开始录制，Esc 或再次点击取消。修改立即生效，冲突时保留旧值。", "Click a combo to start recording; press Esc or click again to cancel. Changes apply immediately, and conflicts keep the previous value."))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(loc("恢复默认", "Restore Defaults")) { model.resetHotkeys() }
                    .controlSize(.small)
            }

            InlineNotice(symbol: "checkmark.shield", text: loc("全局快捷键由系统注册，不需要辅助功能权限。", "Global hotkeys are registered by the system and don't need Accessibility access."), tint: Theme.term)
        }
    }

    private var clipboard: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard(loc("历史容量", "History Size")) {
                SettingsRow(title: loc("文本记录", "Text Items"), detail: loc("文本与链接共享上限，可输入 10—2000 条", "Shared by text and links. 10–2000 items")) {
                    NumericSettingField(title: loc("文本历史上限", "Text history limit"), value: $store.settings.maxTextItems, range: 10...2000, step: 10)
                }
                SettingsSeparator()
                SettingsRow(title: loc("图片记录", "Image Items"), detail: loc("图片独立计数，可输入 5—500 张", "Counted separately. 5–500 images")) {
                    NumericSettingField(title: loc("图片历史上限", "Image history limit"), value: $store.settings.maxImageItems, range: 5...500, step: 5)
                }
            }

            SettingsCard(loc("面板布局", "Panel Layout")) {
                SettingsRow(title: loc("停靠位置", "Docking Position"), detail: loc("选择底部、居中或顶部停靠", "Bottom, center or top")) {
                    Picker("", selection: $store.settings.clipboardPanelPosition) {
                        ForEach(ClipboardPanelPosition.allCases, id: \.self) { position in
                            Text(position.title).tag(position)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 128)
                }
                SettingsSeparator()
                SettingsRow(title: loc("面板高度", "Panel Height"), detail: loc("280—480 pt，也可拖拽窗口上下边缘调整", "280–480 pt; drag the top or bottom edge")) {
                    NumericSettingField(title: loc("剪贴板面板高度", "Clipboard panel height"), value: $store.settings.clipboardPanelHeight, range: 280...480, step: 20, suffix: "pt")
                }
                SettingsSeparator()
                SettingsRow(title: loc("挂绳透明度", "Strap Opacity"), detail: loc("调低可减少挂绳与吊夹对视线的遮挡", "Lower values reduce visual clutter")) {
                    HStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { Double(store.settings.clipboardRopeOpacity) },
                            set: { store.settings.clipboardRopeOpacity = Int($0) }
                        ), in: 0...100, step: 5)
                        .frame(width: 120)
                        Text("\(store.settings.clipboardRopeOpacity)%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
            }

            Text(loc("面板宽度自动铺满当前屏幕；拖拽窗口左右边缘可手动调整，切换屏幕时恢复铺满。", "Panel width fills the current screen by default; drag the left or right edge to adjust. Switching screens restores full width."))
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiary)
                .padding(.horizontal, 2)

            SettingsCard(loc("激活与粘贴", "Activation & Pasting")) {
                SettingsRow(title: loc("激活后自动粘贴", "Paste After Activating"), detail: loc("先复制记录，再把焦点归还给之前的应用", "Copies first, then returns focus to the previous app")) {
                    Toggle("", isOn: $store.settings.autoPaste)
                        .labelsHidden()
                        .onChange(of: store.settings.autoPaste) { _, value in
                            if value && !model.services.clipboard.canAutoPaste {
                                _ = model.services.clipboard.requestAutoPastePermission()
                            }
                        }
                }
            }

            if store.settings.autoPaste && !model.services.clipboard.canAutoPaste {
                InlineNotice(symbol: "hand.raised", text: loc("自动粘贴需要辅助功能权限。未授权时仍会正常复制，不会向其他应用发送按键。", "Auto-paste needs Accessibility access. Without it, copying still works and no keystrokes are sent to other apps."), tint: Theme.workday)
            }

            InlineNotice(symbol: "lock.shield", text: loc("淘汰策略：超出各自上限时，从最旧的未收藏记录开始清理；收藏不会被自动淘汰或“清空未收藏”删除。单图最大 20MB，敏感与临时内容不记录。", "Eviction: over the limit, the oldest unpinned items are removed first. Pinned items survive auto-eviction and \"Clear Unpinned\". Max 20 MB per image; sensitive and transient content isn't recorded."), tint: Theme.term)
        }
    }

    private var capture: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard(loc("截图", "Screenshots")) {
                SettingsRow(title: loc("放大镜与取色", "Magnifier & Color Picker"), detail: loc("框选前显示像素放大镜、坐标和 HEX 色值", "Pixel magnifier, coordinates and HEX before you select")) {
                    Toggle("", isOn: $store.settings.showMagnifier)
                        .labelsHidden()
                }
                SettingsSeparator()
                SettingsRow(title: loc("自动保存截图", "Auto-Save Screenshots"), detail: loc("确认后保存到 ~/图片/charl，同时复制到剪贴板", "After confirming, save to ~/Pictures/charl and copy")) {
                    Toggle("", isOn: $store.settings.saveScreenshotsToDisk)
                        .labelsHidden()
                }
            }

            InlineNotice(symbol: "cursorarrow.rays", text: loc("从鼠标位置拖拽框选，或单击选择窗口，再调整或标注。松开鼠标保留选区，双击或回车复制，Esc 取消。", "Drag from the pointer to select, or click a window, then adjust or annotate. Release keeps the selection; double-click or press Return to copy, Esc cancels."))

            SettingsCard(loc("贴图手势", "Pin Gestures")) {
                SettingsRow(title: loc("移动与缩放", "Move & Zoom"), detail: loc("拖动移动位置，滚轮缩放图片", "Drag to move, scroll to zoom")) {
                    Keycap(glyph: loc("滚动", "Scroll"))
                }
                SettingsSeparator()
                SettingsRow(title: loc("调整透明度", "Adjust Opacity"), detail: loc("按住 Option 的同时滚动", "Hold Option while scrolling")) {
                    HStack(spacing: 4) { Keycap(glyph: "⌥"); Keycap(glyph: loc("滚动", "Scroll")) }
                }
                SettingsSeparator()
                SettingsRow(title: loc("关闭贴图", "Close Pin"), detail: loc("也可以使用右键菜单复制、保存或恢复原大小", "The context menu also offers copy, save and reset size")) {
                    HStack(spacing: 4) { Keycap(glyph: "esc"); Text(loc("或双击", "or double-click")).font(.system(size: 11)).foregroundStyle(Theme.secondary) }
                }
            }
        }
    }
}

private struct NumericSettingField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var suffix: String?
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .focused($focused)
                .accessibilityLabel(title)
                .onSubmit(commit)
                .onChange(of: focused) { _, active in
                    if !active { commit() }
                }
                .onChange(of: text) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue {
                        text = filtered
                        return
                    }
                    if let number = Int(filtered), range.contains(number) { value = number }
                }
                .onAppear { text = String(value) }
                .onChange(of: value) { _, newValue in
                    if !focused { text = String(newValue) }
                }
            Text(suffix ?? loc("条", "items"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
            Stepper("", onIncrement: { adjust(step) }, onDecrement: { adjust(-step) })
                .labelsHidden()
        }
    }

    private func adjust(_ delta: Int) {
        value = min(max(value + delta, range.lowerBound), range.upperBound)
        text = String(value)
    }

    private func commit() {
        guard let number = Int(text) else {
            text = String(value)
            return
        }
        value = min(max(number, range.lowerBound), range.upperBound)
        text = String(value)
    }
}

private struct SidebarButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tab.tint)
                    .frame(width: 20)
                Text(tab.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.label : Theme.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(isSelected ? Theme.selectedStrong : (hovering ? Theme.hover : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .onHover { hovering = $0 }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.secondary)
                .padding(.horizontal, 2)
            VStack(spacing: 0) { content }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 0.6))
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String?
    let control: Control

    init(title: String, detail: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.label)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

private struct SettingsSeparator: View {
    var body: some View {
        Hairline().padding(.leading, 16)
    }
}

private struct HotkeyRow: View {
    @ObservedObject var model: AppModel
    let slot: HotkeySlot
    @State private var hovering = false
    @State private var pulse = false

    private var recording: Bool { model.recordingSlot == slot }
    private var justSaved: Bool { model.recentlyUpdatedSlot == slot }
    private var hasError: Bool { recording && model.hotkeyError != nil }

    private var detail: String {
        switch slot {
        case .clipboard: return loc("打开剪贴板历史，跟随鼠标所在屏幕", "Open clipboard history on the screen under the pointer")
        case .screenshot: return loc("定格屏幕并框选截图", "Freeze the screen and select a region")
        case .pin: return loc("将剪贴板图片钉在屏幕上", "Pin the clipboard image to the screen")
        }
    }

    private var borderColor: Color {
        if hasError { return Theme.workday }
        if recording { return Theme.accent }
        if justSaved { return Theme.term }
        return Theme.hairline
    }

    private var fillColor: Color {
        if hasError { return Theme.workday.opacity(0.10) }
        if recording { return Theme.accent.opacity(0.12) }
        if justSaved { return Theme.term.opacity(0.12) }
        return hovering ? Theme.hover : Theme.fill
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.title)
                    .font(.system(size: 12.5, weight: .medium))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
            Button {
                recording ? model.cancelRecording() : model.beginRecording(slot)
            } label: {
                HStack(spacing: 6) {
                    if recording {
                        Circle()
                            .fill(hasError ? Theme.workday : Theme.accent)
                            .frame(width: 7, height: 7)
                            .opacity(pulse ? 1 : 0.35)
                        HStack(spacing: 3) {
                            if model.liveModifiers.contains(.control) { Keycap(glyph: "⌃") }
                            if model.liveModifiers.contains(.option) { Keycap(glyph: "⌥") }
                            if model.liveModifiers.contains(.shift) { Keycap(glyph: "⇧") }
                            if model.liveModifiers.contains(.command) { Keycap(glyph: "⌘") }
                        }
                        Text(loc("按下组合键", "Press a combo"))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(hasError ? Theme.workday : Theme.accent)
                    } else {
                        KeycapCombo(combo: model.settingsModel.settings[keyPath: slot.path])
                        if justSaved {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                Text(loc("已保存", "Saved"))
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(Theme.term)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        } else if hovering {
                            Image(systemName: "pencil")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.tertiary)
                                .transition(.opacity)
                        }
                    }
                }
                .frame(minWidth: 152, minHeight: 32)
                .padding(.horizontal, 9)
                .background(RoundedRectangle(cornerRadius: Theme.radius).fill(fillColor))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .strokeBorder(borderColor, lineWidth: (recording || justSaved || hasError) ? 1.3 : 0.6)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(recording ? loc("Esc 取消 · 再次点击放弃", "Esc to cancel · click again to discard") : loc("点击修改快捷键", "Click to change the hotkey"))
            .accessibilityLabel(loc("修改\(slot.title)快捷键", "Change the \(slot.title) hotkey"))
            .onHover { hovering = $0 }
            .animation(Theme.motion(.easeOut(duration: 0.16)), value: hovering)
            .animation(Theme.motion(.spring(response: 0.3, dampingFraction: 0.7)), value: justSaved)
            .animation(Theme.motion(.easeOut(duration: 0.16)), value: recording)
            .onChange(of: recording) { _, rec in
                if rec {
                    withAnimation(Theme.reduceMotion ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { pulse = false }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct CalendarSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var store: SettingsModel
    @ObservedObject private var calendar: CalendarModuleModel

    init(model: AppModel) {
        self.model = model
        store = model.settingsModel
        calendar = model.calendar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard(loc("日历显示", "Calendar Display")) {
                SettingsRow(title: loc("周一作为一周的开始", "Start Weeks on Monday"), detail: loc("关闭后，每周从周日开始", "When off, weeks start on Sunday")) {
                    Toggle("", isOn: $store.settings.weekStartsOnMonday)
                        .labelsHidden()
                }
                SettingsSeparator()
                SettingsRow(title: loc("背景", "Background"), detail: loc("纯色与系统右键菜单一致；也可选原生毛玻璃或更透明", "Solid matches the system menu; native material or more transparent")) {
                    Picker("", selection: $store.settings.calendarBackground) {
                        ForEach(CalendarBackground.allCases, id: \.self) { background in
                            Text(background.title).tag(background)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 138)
                }
                SettingsSeparator()
                SettingsRow(title: loc("字体大小", "Font Size"), detail: loc("窗口宽高会随字体自动调整", "Window size scales with the font")) {
                    NumericSettingField(title: loc("日历字体大小", "Calendar font size"), value: $store.settings.calendarFontSize, range: 10...20, step: 1, suffix: "pt")
                }
                SettingsSeparator()
                SettingsRow(title: loc("强调色", "Accent Color"), detail: loc("只影响今天、选中环、倒计时与按钮，不改背景", "Only today, selection, countdown and buttons — never the background")) {
                    Picker("", selection: $store.settings.calendarPalette) {
                        ForEach(CalendarPalette.allCases, id: \.self) { palette in
                            Text(palette.title).tag(palette)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 138)
                }
                if store.settings.calendarPalette == .custom {
                    SettingsSeparator()
                    SettingsRow(title: loc("自定义颜色", "Custom Color"), detail: loc("为今天、选中与倒计时选择强调色", "Pick accents for today, selection and countdown")) {
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: store.settings.calendarAccentHex) },
                            set: { store.settings.calendarAccentHex = $0.hexString }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 44)
                    }
                }
                SettingsSeparator()
                SettingsRow(title: loc("显示天气", "Show Weather"), detail: loc("IP 定位城市 + wttr.in / Open-Meteo 公开接口；仅出站请求，可关闭", "City by IP, via public wttr.in / Open-Meteo APIs. Outbound only; can be off")) {
                    Toggle("", isOn: $store.settings.weatherEnabled)
                        .labelsHidden()
                }
                SettingsSeparator()
                SettingsRow(title: loc("假日自动更新", "Auto-Update Holidays"), detail: loc("holiday-cn（国务院通知）实时获取节假日与调休；离线回退内置数据", "holiday-cn fetches holidays and swap days live; falls back to bundled data offline")) {
                    Toggle("", isOn: $store.settings.holidayAutoUpdate)
                        .labelsHidden()
                }
            }

            SettingsCard(loc("个人日程", "Personal Events")) {
                SettingsRow(title: loc("接入系统日历", "Use System Calendar"), detail: loc("只读取日程用于展示；农历与节气无需授权", "Events are read-only. Lunar dates and solar terms need no access")) {
                    if calendar.accessGranted {
                        Label(loc("已授权", "Granted"), systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.term)
                    } else {
                        Button(loc("授权系统日历", "Grant Access")) { calendar.requestAccess() }
                            .controlSize(.small)
                    }
                }
            }

            if calendar.accessDenied {
                InlineNotice(symbol: "exclamationmark.triangle", text: loc("日历权限已拒绝。请在系统设置 → 隐私与安全性 → 日历中允许 charl。", "Calendar access is denied. Allow charl in System Settings → Privacy & Security → Calendars."), tint: Theme.workday)
            }

            InlineNotice(symbol: "info.circle", text: loc("法定节假日与调休仅收录已核实的 2026、2027 年安排。其他年份不会推测，可在数据目录中添加 holidays.json。", "Public holidays and swap days cover verified 2026 and 2027 only. Other years aren't guessed; add holidays.json to the data folder."))
            Text(loc("月标题可选择年月；方向键移动日期，PageUp / PageDown 换月，T 回到今天。", "The month title picks year and month. Arrows move the date, PageUp / PageDown change month, T returns to today."))
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiary)
                .padding(.horizontal, 2)
        }
    }
}
