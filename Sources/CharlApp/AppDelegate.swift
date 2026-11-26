import AppKit
import CharlCore
import CharlMac
import CharlUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var model = AppModel(services: MacPlatform.makeServices(), monitorClipboard: !CommandLine.arguments.contains(where: { $0.hasPrefix("--render=") }))
    /// 命令行 --lang 优先于 settings.json：SettingsModel.init 会用设置值覆盖 Lang.preference，
    /// 这里先记下解析结果，在 model 初始化之后、render/panel 分支之前重新写回。
    private let commandLineLanguage: LanguagePreference? = CommandLine.arguments
        .first(where: { $0.hasPrefix("--lang=") })
        .flatMap { arg in
            switch String(arg.dropFirst("--lang=".count)) {
            case "zh", "chinese": return .chinese
            case "en", "english": return .english
            case "system": return .system
            default: return nil
            }
        }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier, NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }
        // 首次访问 self.model 会触发 SettingsModel.init（它把 Lang.preference 覆盖成设置值），
        // 因此命令行 --lang 必须在这之后再写回，才能压过设置；下面的 render / panel 分支都取不到更早的值。
        _ = model
        if let commandLineLanguage { Lang.preference = commandLineLanguage }
        setupMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(rebuildMenu), name: .charlLanguageChanged, object: nil)
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--render=") }) {
            let name = String(arg.dropFirst(9))
            let query = CommandLine.arguments.first(where: { $0.hasPrefix("--query=") }).map { String($0.dropFirst(8)) } ?? ""
            DispatchQueue.main.async {
                do {
                    try OffscreenRenderer.render(model: self.model, name: name, query: query, to: URL(fileURLWithPath: "/tmp/charl-render-\(name).png"))
                    Log.app.notice("render completed")
                } catch { Log.app.error("render failed: \(error.localizedDescription, privacy: .public)") }
                NSApp.terminate(nil)
            }
            return
        }
        model.start()
        Log.app.notice("charl launched")
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--display=") }), let index = Int(arg.dropFirst(10)) {
            model.preferredDisplayIndex = index
        }
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--open=") }), arg == "--open=settings" {
            DispatchQueue.main.async { self.model.openSettings() }
        }
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--panel=") }), let tab = PanelTab(rawValue: String(arg.dropFirst(8))) {
            DispatchQueue.main.async { self.model.show(tab) }
        }
        if CommandLine.arguments.contains("--capture") {
            DispatchQueue.main.async { self.model.startCapture() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        model.clipboard.flushSave()
        model.settingsModel.flushSave()
    }

    /// 语言切换后重建 AppKit 主菜单（菜单标题在创建时就固化了）。
    @objc private func rebuildMenu() { setupMenu() }

    private func setupMenu() {
        let main = NSMenu()
        let app = NSMenu(title: "charl")
        let item = NSMenuItem(title: "charl", action: nil, keyEquivalent: "")
        item.submenu = app
        app.addItem(NSMenuItem(title: loc("关于 charl", "About charl"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        let settings = NSMenuItem(title: loc("设置…", "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        app.addItem(settings)
        app.addItem(.separator())
        app.addItem(NSMenuItem(title: loc("退出 charl", "Quit charl"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        main.addItem(item)
        let edit = NSMenu(title: loc("编辑", "Edit"))
        for (title, action, key) in [(loc("撤销", "Undo"), "undo:", "z"), (loc("剪切", "Cut"), "cut:", "x"), (loc("复制", "Copy"), "copy:", "c"), (loc("粘贴", "Paste"), "paste:", "v"), (loc("全选", "Select All"), "selectAll:", "a")] {
            edit.addItem(NSMenuItem(title: title, action: Selector(action), keyEquivalent: key))
        }
        let editItem = NSMenuItem(title: loc("编辑", "Edit"), action: nil, keyEquivalent: "")
        editItem.submenu = edit
        main.addItem(editItem)
        let tools = NSMenu(title: loc("工具", "Tools"))
        for (title, action) in [(loc("剪贴板历史", "Clipboard History"), #selector(showClipboard)), (loc("万年历", "Calendar"), #selector(showCalendar)), (loc("截图", "Capture"), #selector(startCapture)), (loc("全屏截图", "Full Screen Capture"), #selector(captureFullScreen)), (loc("贴图（剪贴板）", "Pin Clipboard"), #selector(pinClipboard)), (loc("关闭全部贴图", "Close All Pins"), #selector(closePins))] {
            let command = NSMenuItem(title: title, action: action, keyEquivalent: "")
            command.target = self
            tools.addItem(command)
        }
        let toolsItem = NSMenuItem(title: loc("工具", "Tools"), action: nil, keyEquivalent: "")
        toolsItem.submenu = tools
        main.addItem(toolsItem)
        NSApp.mainMenu = main
    }

    @objc private func openSettings() { model.openSettings() }
    @objc private func showClipboard() { model.showClipboard() }
    @objc private func showCalendar() { model.showCalendar() }
    @objc private func startCapture() { model.startCapture() }
    @objc private func captureFullScreen() { model.captureFullScreen() }
    @objc private func pinClipboard() { model.pinClipboard() }
    @objc private func closePins() { model.closeAllPins() }
}
