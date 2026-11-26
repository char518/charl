import CharlCore
import Foundation

func testClipboardHistory() {
    suite("ClipboardHistory") {
        var history = ClipboardHistory()
        let a = ClipboardItem(kind: .text, text: "alpha")
        let b = ClipboardItem(kind: .text, text: "beta")
        history.insert(a)
        history.insert(b)
        expectEqual(history.items.map(\.text), ["beta", "alpha"], "newest first")

        history.insert(ClipboardItem(kind: .text, text: "alpha"))
        expectEqual(history.items.map(\.text), ["alpha", "beta"], "duplicate moves to top")
        expectEqual(history.items.count, 2, "dedupe keeps count")

        history.togglePin(id: history.items[1].id)
        history.insert(ClipboardItem(kind: .text, text: "beta"))
        expectEqual(history.items.count, 2, "pinned duplicate not re-inserted")
        expect(history.items[1].isPinned, "pin preserved")

        var capped = ClipboardHistory()
        for i in 0..<10 {
            capped.insert(ClipboardItem(kind: .text, text: "t\(i)"), maxText: 5, maxImage: 5)
        }
        expectEqual(capped.items.count, 5, "text cap enforced")
        expectEqual(capped.items.first?.text, "t9", "newest kept")
        expectEqual(capped.items.last?.text, "t5", "oldest pruned")

        var pinned = ClipboardHistory()
        let pin = ClipboardItem(kind: .text, text: "keep", isPinned: true)
        pinned.insert(pin)
        for i in 0..<10 {
            pinned.insert(ClipboardItem(kind: .text, text: "x\(i)"), maxText: 3, maxImage: 3)
        }
        expect(pinned.items.contains(where: { $0.text == "keep" }), "pinned exempt from cap")

        var images = ClipboardHistory()
        for i in 0..<8 {
            images.insert(ClipboardItem(kind: .image, imageFile: "i\(i).png"), maxText: 100, maxImage: 3)
        }
        expectEqual(images.items.count, 3, "image cap enforced")

        let removed = images.clearUnpinned()
        expectEqual(removed.count, 3, "clearUnpinned returns removed")
        expectEqual(images.items.count, 0, "clearUnpinned empties")

        var mixed = ClipboardHistory()
        let keep = ClipboardItem(kind: .image, imageFile: "p.png", isPinned: true)
        mixed.insert(keep)
        mixed.insert(ClipboardItem(kind: .text, text: "gone"))
        let cleared = mixed.clearUnpinned()
        expectEqual(cleared.count, 1, "clearUnpinned skips pinned")
        expectEqual(mixed.items.count, 1, "pinned survives clear")

        let data = try! JSONEncoder().encode(mixed)
        let decoded = try! JSONDecoder().decode(ClipboardHistory.self, from: data)
        expectEqual(decoded.items, mixed.items, "history Codable round trip")
    }
}

func testRelativeTime() {
    suite("RelativeTime") {
        let now = Date(timeIntervalSince1970: 1_763_400_000)
        expectEqual(RelativeTime.string(for: now.addingTimeInterval(-30), now: now), "刚刚", "seconds")
        expectEqual(RelativeTime.string(for: now.addingTimeInterval(-300), now: now), "5 分钟前", "minutes")
        expectEqual(RelativeTime.string(for: now.addingTimeInterval(-7200), now: now), "2 小时前", "hours")
        expectEqual(RelativeTime.string(for: now.addingTimeInterval(-100_000), now: now), "昨天", "yesterday")
    }
}