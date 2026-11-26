import CharlCore
import Foundation

func testRemote() {
    suite("WeatherCondition") {
        expectEqual(WeatherCondition.text(code: 0), "晴", "clear")
        expectEqual(WeatherCondition.text(code: 3), "阴", "overcast")
        expectEqual(WeatherCondition.text(code: 61), "雨", "rain")
        expectEqual(WeatherCondition.text(code: 71), "雪", "snow")
        expectEqual(WeatherCondition.text(code: 95), "雷暴", "thunder")
        expectEqual(WeatherCondition.text(code: 12345), "未知", "unknown code")
        expectEqual(WeatherCondition.symbol(code: 0), "sun.max.fill", "clear symbol")
        expectEqual(WeatherCondition.symbol(code: 95), "cloud.bolt.rain.fill", "thunder symbol")
        expectEqual(WeatherCondition.symbol(code: 12345), "questionmark.circle", "unknown symbol")
    }

    suite("RemoteHolidays") {
        let json = """
        {
          "year": 2026,
          "days": [
            {"name": "元旦", "date": "2026-01-01", "isOffDay": true},
            {"name": "元旦", "date": "2026-01-02", "isOffDay": true},
            {"name": "元旦", "date": "2026-01-03", "isOffDay": true},
            {"name": "元旦", "date": "2026-01-04", "isOffDay": false},
            {"name": "拆分假", "date": "2026-03-01", "isOffDay": true},
            {"name": "拆分假", "date": "2026-03-03", "isOffDay": true}
          ]
        }
        """
        let data = Data(json.utf8)
        let parsed = RemoteHolidays.parse(year: 2026, data: data)
        expect(parsed != nil, "parse succeeds")
        expectEqual(parsed?.year, 2026, "year")
        expectEqual(parsed?.holidays.count, 3, "consecutive grouped, gap split")
        expectEqual(parsed?.holidays.first?.start, "2026-01-01", "range start")
        expectEqual(parsed?.holidays.first?.end, "2026-01-03", "range end")
        expectEqual(parsed?.workdays, ["2026-01-04"], "调休上班")

        expect(RemoteHolidays.parse(year: 2027, data: data) == nil, "wrong year filtered out")
        expect(RemoteHolidays.parse(year: 2026, data: Data(#"{"year":2026,"days":[]}"#.utf8)) == nil, "empty days rejected")
        expect(RemoteHolidays.parse(year: 2026, data: Data("not json".utf8)) == nil, "malformed rejected")

        if let parsed {
            let merged = HolidayCalendar.standard(overrides: [parsed])
            expectEqual(merged.status(on: Day(year: 2026, month: 1, day: 1)), .off("元旦"), "remote off day")
            expectEqual(merged.status(on: Day(year: 2026, month: 1, day: 3)), .off("元旦"), "remote range end")
            expectEqual(merged.status(on: Day(year: 2026, month: 1, day: 4)), .work, "remote workday")
            expectEqual(merged.status(on: Day(year: 2026, month: 3, day: 2)), nil, "gap not off")
            expectEqual(merged.status(on: Day(year: 2026, month: 3, day: 3)), .off("拆分假"), "split range")
            expectEqual(merged.status(on: Day(year: 2026, month: 10, day: 1)), nil, "remote replaces built-in year")
            expectEqual(merged.status(on: Day(year: 2027, month: 2, day: 5)), .off("春节"), "other years keep built-in")
        }
    }
}