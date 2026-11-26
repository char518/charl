import Foundation

/// 法定节假日放假 / 调休上班。内置数据只收录经核实的国务院办公厅通知：
/// 2026（2025-11-04 发布）、2027（2026-11-05 发布）。其它年份不标注，不推测。
/// 用户可在数据目录 holidays.json 中追加或覆盖年份。
public struct HolidayYear: Codable, Hashable, Sendable {
    public struct Range: Codable, Hashable, Sendable {
        public var name: String
        public var start: String
        public var end: String

        public init(name: String, start: String, end: String) {
            self.name = name
            self.start = start
            self.end = end
        }
    }

    public var year: Int
    public var holidays: [Range]
    public var workdays: [String]

    public init(year: Int, holidays: [Range], workdays: [String]) {
        self.year = year
        self.holidays = holidays
        self.workdays = workdays
    }
}

public enum HolidayStatus: Hashable, Sendable {
    case off(String)
    case work
}

public struct HolidayCalendar: Sendable {
    private var offDays: [Day: String] = [:]
    private var workDays: Set<Day> = []
    private var starts: [(day: Day, name: String)] = []
    public private(set) var coveredYears: Set<Int> = []

    public init(years: [HolidayYear]) {
        var byYear: [Int: HolidayYear] = [:]
        for year in years { byYear[year.year] = year }
        for year in byYear.values {
            coveredYears.insert(year.year)
            for range in year.holidays {
                guard let start = Self.parse(range.start), let end = Self.parse(range.end),
                      start.year == year.year, end.year == year.year,
                      end >= start, end.epochDay - start.epochDay < 366 else { continue }
                starts.append((start, range.name))
                var cursor = start
                while cursor <= end {
                    offDays[cursor] = range.name
                    cursor = cursor.addingDays(1)
                }
            }
            for text in year.workdays {
                if let day = Self.parse(text) { workDays.insert(day) }
            }
        }
        starts.sort { $0.day < $1.day }
    }

    /// 内置数据 + 用户覆盖（同年份以用户为准）。
    public static func standard(overrides: [HolidayYear] = []) -> HolidayCalendar {
        HolidayCalendar(years: builtIn + overrides)
    }

    public func status(on day: Day) -> HolidayStatus? {
        if let name = offDays[day] { return .off(name) }
        if workDays.contains(day) { return .work }
        return nil
    }

    /// 下一个法定假期（开始日晚于 day）。
    public func nextHoliday(after day: Day) -> (name: String, start: Day)? {
        guard let next = starts.first(where: { $0.day > day }) else { return nil }
        return (next.name, next.day)
    }

    static func parse(_ text: String) -> Day? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1900...9999).contains(parts[0]), (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        let day = Day(year: parts[0], month: parts[1], day: parts[2])
        return day.year == parts[0] && day.month == parts[1] && day.day == parts[2] ? day : nil
    }

    public static let builtIn: [HolidayYear] = [
        HolidayYear(
            year: 2026,
            holidays: [
                .init(name: "元旦", start: "2026-01-01", end: "2026-01-03"),
                .init(name: "春节", start: "2026-02-15", end: "2026-02-23"),
                .init(name: "清明节", start: "2026-04-04", end: "2026-04-06"),
                .init(name: "劳动节", start: "2026-05-01", end: "2026-05-05"),
                .init(name: "端午节", start: "2026-06-19", end: "2026-06-21"),
                .init(name: "中秋节", start: "2026-09-25", end: "2026-09-27"),
                .init(name: "国庆节", start: "2026-10-01", end: "2026-10-07"),
            ],
            workdays: ["2026-01-04", "2026-02-14", "2026-02-28", "2026-05-09", "2026-09-20", "2026-10-10"]
        ),
        HolidayYear(
            year: 2027,
            holidays: [
                .init(name: "元旦", start: "2027-01-01", end: "2027-01-03"),
                .init(name: "春节", start: "2027-02-05", end: "2027-02-13"),
                .init(name: "清明节", start: "2027-04-03", end: "2027-04-05"),
                .init(name: "劳动节", start: "2027-05-01", end: "2027-05-05"),
                .init(name: "端午节", start: "2027-06-09", end: "2027-06-09"),
                .init(name: "中秋节", start: "2027-09-15", end: "2027-09-15"),
                .init(name: "国庆节", start: "2027-10-01", end: "2027-10-07"),
            ],
            workdays: ["2027-01-31", "2027-02-14", "2027-05-08", "2027-09-26", "2027-10-09"]
        ),
    ]
}