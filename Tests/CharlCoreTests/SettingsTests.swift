import CharlCore
import Foundation

func testAppSettings() {
    suite("AppSettings") {
        let defaults = AppSettings.default
        expectEqual(defaults.clipboardHotkey, AppConfig.clipboardHotkey, "default clipboard hotkey")
        expectEqual(defaults.pinHotkey, AppConfig.pinHotkey, "default pin hotkey")
        expectEqual(defaults.maxTextItems, 200, "default text cap")
        expectEqual(defaults.autoPaste, false, "autoPaste off by default")
        expectEqual(defaults.menuBarStyle, .iconLunar, "menu bar shows lunar by default")
        expectEqual(defaults.weekStartsOnMonday, true, "monday first by default")

        var custom = defaults
        custom.clipboardHotkey = KeyCombo(modifiers: [.command, .shift], key: .space)
        custom.maxTextItems = 99999
        custom.maxImageItems = 0
        custom.clamp()
        expectEqual(custom.maxTextItems, 2000, "clamp upper")
        expectEqual(custom.maxImageItems, 5, "clamp lower")

        let data = try! JSONEncoder().encode(custom)
        let decoded = try! JSONDecoder().decode(AppSettings.self, from: data)
        expectEqual(decoded, custom, "settings Codable round trip")

        // 旧版 settings.json（含已移除的 searchHotkey、缺 pinHotkey / menuBarStyle 等新字段）：忽略移除键，保留用户已改的热键，新字段取默认
        let legacy = #"{"searchHotkey":{"modifiers":4,"key":"space"},"clipboardHotkey":{"modifiers":6,"key":"k"},"screenshotHotkey":{"modifiers":6,"key":"s"},"maxTextItems":300,"maxImageItems":50,"saveScreenshotsToDisk":true,"autoPaste":false,"launchAtLogin":false}"#
        let migrated = try? JSONDecoder().decode(AppSettings.self, from: Data(legacy.utf8))
        expectEqual(migrated?.clipboardHotkey, KeyCombo(modifiers: [.control, .option], key: .k), "legacy hotkey kept")
        expectEqual(migrated?.maxTextItems, 300, "legacy cap kept")
        expectEqual(migrated?.pinHotkey, AppConfig.pinHotkey, "new field defaulted")
        expectEqual(migrated?.menuBarStyle, .iconLunar, "new enum defaulted")
    }
}

func testClipboardGroups() {
    suite("ClipboardGroup") {
        let link = ClipboardItem(kind: .text, text: "https://www.apple.com/mac")
        let www = ClipboardItem(kind: .text, text: "www.example.com")
        let sentence = ClipboardItem(kind: .text, text: "see https://a.com for details")
        let image = ClipboardItem(kind: .image, imageFile: "a.png")
        let pinned = ClipboardItem(kind: .text, text: "keep me", sourceApp: "Notes", isPinned: true)
        let items = [link, www, sentence, image, pinned]

        expect(link.isLink, "https is link")
        expect(www.isLink, "www is link")
        expect(!sentence.isLink, "sentence with url is text")
        expectEqual(link.linkHost, "www.apple.com", "link host")
        expectEqual(www.linkHost, "www.example.com", "www host")

        expectEqual(ClipboardQuery.filter(items, group: .link, keyword: "").count, 2, "link group")
        expectEqual(ClipboardQuery.filter(items, group: .text, keyword: "").count, 2, "text group excludes links")
        expectEqual(ClipboardQuery.filter(items, group: .image, keyword: "").count, 1, "image group")
        expectEqual(ClipboardQuery.filter(items, group: .pinned, keyword: "").count, 1, "pinned group")
        expectEqual(ClipboardQuery.filter(items, group: .all, keyword: "").first?.id, pinned.id, "pinned first in all")
        expectEqual(ClipboardQuery.filter(items, group: .all, keyword: "notes").count, 1, "keyword matches source app")
        expectEqual(ClipboardQuery.filter(items, group: .all, keyword: "APPLE").count, 1, "case insensitive")

        let legacyJSON = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"text","text":"old","byteSize":3,"createdAt":0,"isPinned":false}"#
        let legacy = try? JSONDecoder().decode(ClipboardItem.self, from: Data(legacyJSON.utf8))
        expectEqual(legacy?.text, "old", "legacy item without bundle id decodes")
        expectEqual(legacy?.sourceBundleID, nil, "missing bundle id is nil")
    }
}