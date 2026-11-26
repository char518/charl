import AppKit
import CharlCore
import CharlPlatform
import CharlMac
import SwiftUI
@testable import CharlUI

final class FakePlatform: HotkeyService, ClipboardService, StorageService, CalendarEventsService, ScreenshotService, LoginItemService, RemoteInfoService {
    var files: [String: Data] = [:]
    var keys: [KeyCombo: () -> Void] = [:]
    var rejected: Set<KeyCombo> = []
    var onClipboard: ((ClipboardItem) -> Void)?
    var copied: ClipboardItem?
    var pasteCount = 0
    var isEnabled = false
    var canAutoPaste = false
    func register(_ combo: KeyCombo, handler: @escaping () -> Void) -> Bool {
        guard !rejected.contains(combo), keys[combo] == nil else { return false }
        keys[combo] = handler
        return true
    }
    func unregisterAll() { keys.removeAll() }
    func key(for keyCode: UInt16) -> KeyCombo.Key? { keyCode == 40 ? .k : nil }
    func startMonitoring(onChange: @escaping (ClipboardItem) -> Void) { onClipboard = onChange }
    func stopMonitoring() { onClipboard = nil }
    func copy(_ item: ClipboardItem) { copied = item }
    func imageData(for item: ClipboardItem) -> Data? { nil }
    func thumbnailData(for item: ClipboardItem) -> Data? { nil }
    func deleteImageFiles(for item: ClipboardItem) {}
    func requestAutoPastePermission() -> Bool { false }
    func sendPasteKeystroke() { pasteCount += 1 }
    func url(for relativePath: String) -> URL { URL(fileURLWithPath: "/tmp/charl-tests").appendingPathComponent(relativePath) }
    func read(_ relativePath: String) throws -> Data? { files[relativePath] }
    func write(_ data: Data, to relativePath: String) throws { files[relativePath] = data }
    func remove(_ relativePath: String) throws { files.removeValue(forKey: relativePath) }
    func hasAccess() -> Bool { false }
    func requestAccess() async -> Bool { false }
    func events(from start: Date, to end: Date) async throws -> [CalendarEvent] { [] }
    func hasPermission() -> Bool { false }
    func requestPermission() -> Bool { false }
    func displays() async throws -> [DisplayInfo] { [] }
    func capture(displayID: UInt32, region: Rect?) async throws -> Data { Data() }
    func captureFrame(displayID: UInt32) async throws -> ScreenFrame { fatalError("Not used in these tests") }
    func visibleWindows(displayID: UInt32, excludingProcess pid: Int32) -> [DetectedWindow] { [] }
    func setEnabled(_ enabled: Bool) throws { isEnabled = enabled }
    func fetchWeather() async -> WeatherInfo? { nil }
    func fetchHolidays(year: Int) async -> HolidayYear? { nil }
    var services: PlatformServices {
        PlatformServices(hotkeys: self, storage: self, clipboard: self, calendarEvents: self, screenshot: self, loginItem: self, remote: self)
    }
}

@main
struct IntegrationChecks {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        Lang.preference = .chinese  // 断言中文文案，钉住语言保证 CI 可复现
        var checks = 0
        var failures = 0
        func expect(_ condition: Bool, _ label: String) {
            checks += 1
            if !condition { failures += 1; print("FAIL: " + label) }
        }
        let fake = FakePlatform()
        let model = AppModel(services: fake.services)
        model.applyHotkeys()
        let original = model.settingsModel.settings
        expect(fake.keys.count == 3, "three shortcuts registered")
        let candidate = KeyCombo(modifiers: [.control, .option], key: .k)
        expect(model.setHotkey(candidate, for: .clipboard), "new shortcut accepted")
        expect(fake.keys[candidate] != nil && fake.keys[original.clipboardHotkey] == nil, "registry updated")
        expect(model.recentlyUpdatedSlot == .clipboard, "successful hotkey set surfaces saved feedback")
        let stored = try JSONDecoder().decode(AppSettings.self, from: fake.files["settings.json"]!)
        expect(stored.clipboardHotkey == candidate, "new shortcut persisted")
        expect(!model.setHotkey(original.screenshotHotkey, for: .clipboard), "duplicate shortcut rejected")
        expect(model.settingsModel.settings.clipboardHotkey == candidate, "duplicate leaves old setting")
        expect(fake.keys[candidate] != nil, "duplicate leaves registered shortcut")
        let denied = KeyCombo(modifiers: [.control, .option], key: .j)
        fake.rejected.insert(denied)
        expect(!model.setHotkey(denied, for: .clipboard), "platform conflict rejected")
        expect(fake.keys.count == 3 && fake.keys[candidate] != nil, "failed registration restores all shortcuts")
        expect(model.settingsModel.settings.clipboardHotkey == candidate, "failed registration preserves setting")
        model.beginRecording(.clipboard)
        expect(fake.keys.isEmpty && model.recordingSlot == .clipboard, "recording suspends handlers")
        expect(!model.setHotkey(denied, for: .clipboard), "failed recording rejected")
        expect(fake.keys.isEmpty && model.recordingSlot == .clipboard, "failed recording keeps handlers suspended")
        model.cancelRecording()
        expect(fake.keys.count == 3 && model.recordingSlot == nil, "cancel restores handlers")
        model.settingsModel.settings.maxTextItems = 10
        expect(fake.keys.count == 3, "non-hotkey setting preserves registration")

        let text = ClipboardItem(kind: .text, text: "hello")
        let link = ClipboardItem(kind: .text, text: "https://example.com")
        fake.onClipboard?(text)
        fake.onClipboard?(link)
        expect(model.clipboard.visibleItems.count == 2, "capture inserts entries")
        model.clipboard.group = .link
        expect(model.clipboard.visibleItems.count == 1 && model.clipboard.selectedItem?.id == link.id, "link group and selection agree")
        model.clipboard.filter = "no-match"
        expect(model.clipboard.visibleItems.isEmpty && model.clipboard.selectedItem == nil, "empty filter has no selection")
        model.clipboard.onOpen()
        expect(model.clipboard.group == .all && model.clipboard.filter.isEmpty && model.clipboard.selection == 0, "opening history resets stale group and keyword")
        model.clipboard.group = .all
        model.clipboard.filter = ""
        model.clipboard.togglePin(text)
        expect(model.clipboard.visibleItems.first?.id == text.id, "favorite promoted")
        model.clipboard.flushSave()
        let reloaded = ClipboardModuleModel(service: fake, storage: fake, monitoring: false)
        reloaded.loadIfNeeded()
        expect(reloaded.items.count == 2 && reloaded.items.contains(where: { $0.isPinned }), "history reload retains favorite")
        model.clipboard.moveSelection(100)
        expect(model.clipboard.selection == 1, "keyboard selection bounded")
        model.calendar.jump(year: 2026, month: 12)
        model.calendar.moveSelection(days: 31)
        expect(model.calendar.month.month == 1 && model.calendar.month.year == 2027, "calendar selection moves across year")
        model.calendar.updateWeekStart(false)
        expect(model.calendar.month.weekdaySymbols.first == "日", "week start rebuilds grid")
        model.calendar.jump(year: 1900, month: 1)
        expect(model.calendar.selectedDay == Day(year: 1900, month: 1, day: 31), "minimum calendar month has a supported lunar date")
        model.calendar.jump(year: 2100, month: 12)
        model.calendar.shiftMonth(1)
        expect(model.calendar.month.year == 2100 && model.calendar.month.month == 12, "calendar does not navigate beyond supported range")
        model.clipboard.filter = "hello"
        expect(model.clipboard.visibleItems.count == 1, "clipboard panel filter searchable")
        model.clipboard.filter = ""
        let copiedBefore = fake.copied
        model.settingsModel.settings.autoPaste = false
        model.activateClipboard(text, copyOnly: true)
        expect(fake.copied?.id == text.id && copiedBefore == nil, "copy activation reaches platform")
        expect(fake.pasteCount == 0, "copy only never sends paste")

        var bytes = Data(count: 400 * 240 * 4)
        bytes.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            for y in 0..<240 {
                for x in 0..<400 {
                    let offset = (y * 400 + x) * 4
                    raw[offset] = 40; raw[offset + 1] = UInt8(y); raw[offset + 2] = UInt8(x % 255); raw[offset + 3] = 255
                }
            }
        }
        let frame = ScreenFrame(pixelWidth: 400, pixelHeight: 240, bytesPerRow: 1600, scale: 2, pixels: bytes)
        expect(frame.color(atPixelX: 40, y: 30)?.r == 40, "BGRA red sampled correctly")
        expect(frame.color(atPixelX: 40, y: 30)?.g == 30, "BGRA green sampled correctly")
        expect(frame.color(atPixelX: -1, y: 0) == nil, "negative sample rejected")
        let canvas = ScreenshotCanvas(frame: frame, state: CaptureState(), windows: [], magnifier: true)
        canvas.setSelection(CGRect(x: 20, y: 15, width: 80, height: 50))
        let result = canvas.result()!
        let image = result.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        expect(image.width == 160 && image.height == 100, "Retina crop size")
        let rep = NSBitmapImageRep(cgImage: image)
        let corner = rep.colorAt(x: 0, y: 0)!.usingColorSpace(.deviceRGB)!
        expect(abs(corner.redComponent * 255 - 40) < 2, "crop left edge maps to original pixels")
        expect(abs(corner.greenComponent * 255 - 30) < 2, "crop top edge maps to original pixels")
        let windows = [
            DetectedWindow(frame: Rect(x: 20, y: 20, width: 70, height: 70), title: "A", owner: "A"),
            DetectedWindow(frame: Rect(x: 120, y: 20, width: 70, height: 70), title: "B", owner: "B"),
        ]
        let tools = CaptureState()
        let selecting = ScreenshotCanvas(frame: frame, state: tools, windows: windows, magnifier: false)
        func mouse(_ type: NSEvent.EventType, _ x: Double, _ y: Double, clickCount: Int = 1) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: selecting.convert(CGPoint(x: x, y: y), to: nil), modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: clickCount, pressure: 1)!
        }
        selecting.mouseDown(with: mouse(.leftMouseDown, 50, 50))
        selecting.mouseUp(with: mouse(.leftMouseUp, 50, 50))
        expect(selecting.selection == nil, "single click keeps region selection at the pointer")
        selecting.mouseDown(with: mouse(.leftMouseDown, 50, 50, clickCount: 2))
        selecting.mouseUp(with: mouse(.leftMouseUp, 50, 50, clickCount: 2))
        expect(selecting.selection == CGRect(x: 20, y: 20, width: 70, height: 70), "double-click selects first window")
        selecting.mouseDown(with: mouse(.leftMouseDown, 150, 50, clickCount: 2))
        selecting.mouseUp(with: mouse(.leftMouseUp, 150, 50, clickCount: 2))
        expect(selecting.selection == CGRect(x: 120, y: 20, width: 70, height: 70), "double-click another window does not reuse old hover")
        tools.tool = .rectangle
        selecting.mouseDown(with: mouse(.leftMouseDown, 140, 40))
        selecting.mouseDragged(with: mouse(.leftMouseDragged, 170, 70))
        selecting.mouseUp(with: mouse(.leftMouseUp, 170, 70))
        expect(tools.undoCount == 1, "annotation committed on mouse release")
        selecting.undo()
        expect(tools.undoCount == 0, "annotation undo")
        tools.tool = .select
        selecting.mouseDown(with: mouse(.leftMouseDown, 190, 90))
        selecting.mouseDragged(with: mouse(.leftMouseDragged, 199, 110))
        selecting.mouseUp(with: mouse(.leftMouseUp, 199, 110))
        expect(selecting.selection == CGRect(x: 120, y: 20, width: 79, height: 90), "corner handle resizes selection")
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("charl-storage-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let legacy = temp.appendingPathComponent("Chao")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data("old-settings".utf8).write(to: legacy.appendingPathComponent("settings.json"))
        let migratedStorage = MacStorage(appSupport: temp)
        expect(try migratedStorage.read("settings.json") == Data("old-settings".utf8), "migration copies existing settings")
        expect(FileManager.default.fileExists(atPath: legacy.path), "migration retains original directory")
        try migratedStorage.write(Data("new-settings".utf8), to: "settings.json")
        let nextStorage = MacStorage(appSupport: temp)
        expect(try nextStorage.read("settings.json") == Data("new-settings".utf8), "later launches preserve new data")
        let scaleRoot = NSView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        let scaleChild = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        scaleRoot.addSubview(scaleChild)
        scaleRoot.wantsLayer = true
        scaleChild.wantsLayer = true
        scaleRoot.layer?.contentsScale = 1
        scaleChild.layer?.contentsScale = 1
        DisplayScaling.apply(to: scaleRoot, scale: 2)
        expect(scaleRoot.layer?.contentsScale == 2 && scaleChild.layer?.contentsScale == 2, "display scale propagates to subviews")
        var layoutSettings = AppSettings()
        layoutSettings.clipboardPanelPosition = .top
        let layoutData = try JSONEncoder().encode(layoutSettings)
        let restoredLayout = try JSONDecoder().decode(AppSettings.self, from: layoutData)
        expect(restoredLayout.clipboardPanelPosition == .top, "clipboard layout settings persist")
        let legacyLayout = Data("{\"clipboardPanelWidth\":900,\"clipboardPanelPosition\":\"center\"}".utf8)
        expect(try JSONDecoder().decode(AppSettings.self, from: legacyLayout).clipboardPanelPosition == .center, "legacy width key ignored on decode")
        expect(CalendarPalette.allCases.count == 10, "ten calendar presets including custom")
        expect(CalendarPalette.allCases.allSatisfy { !$0.title.isEmpty }, "every preset has a title")
        var paletteSettings = AppSettings()
        paletteSettings.calendarPalette = .matcha
        let paletteData = try JSONEncoder().encode(paletteSettings)
        expect(try JSONDecoder().decode(AppSettings.self, from: paletteData).calendarPalette == .matcha, "new palette persists")
        let scaleWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 40, height: 40), styleMask: [.borderless], backing: .buffered, defer: false)
        let scaledHosting = ScaledHostingView(rootView: Text("清晰"))
        scaleWindow.contentView = scaledHosting
        scaledHosting.viewDidMoveToWindow()
        expect(scaledHosting.layer?.contentsScale == scaleWindow.backingScaleFactor, "hosting view syncs to window backing scale")
        print("\(checks) integration checks, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
