import CharlCore
import Foundation

func testSearchEngine() {
    suite("SearchEngine") {
        let today = Day(year: 2026, month: 11, day: 18)
        let items = [
            ClipboardItem(kind: .text, text: "Hello World", createdAt: Date(timeIntervalSince1970: 200)),
            ClipboardItem(kind: .text, text: "world peace", createdAt: Date(timeIntervalSince1970: 100)),
            ClipboardItem(kind: .text, text: "unrelated", createdAt: Date(timeIntervalSince1970: 300)),
        ]

        let empty = SearchEngine.results(query: "", items: items, today: today)
        expectEqual(empty.count, SearchAction.allCases.count + 3, "empty query: actions + recent")
        expectEqual(empty.first, .action(.regionScreenshot), "actions first")
        let pin = SearchEngine.results(query: "贴图", items: items, today: today)
        expect(pin.contains(.action(.pinClipboard)), "pin keyword")
        let settings = SearchEngine.results(query: "设置", items: items, today: today)
        expect(settings.contains(.action(.settings)), "settings keyword")

        let dated = SearchEngine.results(query: "2026-02-17", items: items, today: today)
        expectEqual(dated.first, .date(Day(year: 2026, month: 2, day: 17)), "iso date")
        let cn = SearchEngine.results(query: "2026年2月17日", items: items, today: today)
        expectEqual(cn.first, .date(Day(year: 2026, month: 2, day: 17)), "chinese date")
        let relative = SearchEngine.results(query: "明天", items: items, today: today)
        expectEqual(relative.first, .date(Day(year: 2026, month: 11, day: 19)), "relative date")
        let invalid = SearchEngine.results(query: "2026-02-30", items: items, today: today)
        expect(!invalid.contains(.date(Day(year: 2026, month: 2, day: 30))), "invalid date rejected")
        expectEqual(SearchEngine.parseDate("2026-02-30", today: today), nil, "feb 30 nil")
        expectEqual(SearchEngine.parseDate("9223372036854775807-12-31", today: today), nil, "oversized year rejected without arithmetic overflow")
        expectEqual(SearchEngine.parseDate("2026-9223372036854775807-1", today: today), nil, "oversized month rejected")
        expectEqual(SearchEngine.parseDate("1800-1-1", today: today), nil, "unsupported date rejected")
        expectEqual(SearchEngine.parseDate("0-3", today: today), nil, "month zero rejected")
        expectEqual(SearchEngine.parseDate("11-18", today: today), today, "month-day uses current year")

        let actions = SearchEngine.results(query: "截图", items: items, today: today)
        expect(actions.contains(.action(.regionScreenshot)), "screenshot keyword")
        expect(actions.contains(.action(.fullScreenshot)), "full screenshot keyword")

        let clipboard = SearchEngine.results(query: "world", items: items, today: today)
        let clipboardResults = clipboard.compactMap { result -> ClipboardItem? in
            if case .clipboard(let item) = result { return item }
            return nil
        }
        expectEqual(clipboardResults.count, 2, "substring match")
        expectEqual(clipboardResults.first?.text, "world peace", "prefix ranked first")

        let none = SearchEngine.results(query: "zzz-not-exist", items: items, today: today)
        expectEqual(none.count, 0, "no match empty")
    }
}