import Foundation

/// 无时区的民用日期（年/月/日），内部用 Hinnant 算法做天数算术，跨平台行为一致。
public struct Day: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        // 归一化非法日期（如 2-30 → 3-2），保证分量与 epochDay 始终自洽
        self.init(epochDay: Self.daysFromCivil(year, month, day))
    }

    public init(epochDay: Int) {
        let comps = Self.civilFromDays(epochDay)
        year = comps.0
        month = comps.1
        day = comps.2
    }

    private static func civilFromDays(_ epochDay: Int) -> (Int, Int, Int) {
        let z = epochDay + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp + (mp < 10 ? 3 : -9)
        return (y + (m <= 2 ? 1 : 0), m, d)
    }

    /// 相对 1970-01-01 的天数。
    public var epochDay: Int {
        Self.daysFromCivil(year, month, day)
    }

    private static func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int {
        var y = year
        let m = month
        y -= m <= 2 ? 1 : 0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    public static let chinaTimeZone = TimeZone(identifier: "Asia/Shanghai")!

    public init(date: Date, timeZone: TimeZone = Day.chinaTimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: comps.year ?? 1970, month: comps.month ?? 1, day: comps.day ?? 1)
    }

    /// 该日在东八区的零点时刻。
    public func date(timeZone: TimeZone = Day.chinaTimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    /// 0 = 周日 … 6 = 周六
    public var weekday: Int { (epochDay + 4) % 7 }

    public var isWeekend: Bool { weekday == 0 || weekday == 6 }

    public func addingDays(_ count: Int) -> Day {
        Day(epochDay: epochDay + count)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        lhs.epochDay < rhs.epochDay
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func today(timeZone: TimeZone = Day.chinaTimeZone) -> Day {
        Day(date: Date(), timeZone: timeZone)
    }
}