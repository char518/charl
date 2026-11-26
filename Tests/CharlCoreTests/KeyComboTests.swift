import CharlCore
import Foundation

func testKeyCombo() {
    suite("KeyCombo") {
        let combo = KeyCombo(modifiers: [.command, .shift, .option, .control], key: .c)
        expectEqual(combo.displayString, "⌃⌥⇧⌘C", "HIG modifier order")

        let data = try! JSONEncoder().encode(KeyCombo(modifiers: [.option], key: .space))
        let decoded = try! JSONDecoder().decode(KeyCombo.self, from: data)
        expectEqual(decoded, KeyCombo(modifiers: [.option], key: .space), "Codable round trip")
    }
}