import Foundation

public struct CalendarDayCell: Identifiable, Hashable, Sendable {
    public var day: Day
    public var inMonth: Bool
    public var lunar: LunarDate
    public var lunarLabel: String
    public var festivals: [String]
    public var termName: String?
    public var holiday: HolidayStatus?

    public var id: Day { day }
    public var isWeekend: Bool { day.isWeekend }
    public var isFestivalLabel: Bool { !festivals.isEmpty }
}

public struct CalendarMonthModel: Sendable {
    public var year: Int
    public var month: Int
    public var weekStartsOnMonday: Bool
    /// 最多 6 行 × 7 列；整行月外时裁掉末行。
    public var weeks: [[CalendarDayCell]]

    public var title: String {
        if Lang.isEnglish {
            return "\(AlmanacNames.monthsEN[month - 1]) \(year)"
        }
        return "\(year)年\(month)月"
    }

    public var weekdaySymbols: [String] {
        if Lang.isEnglish {
            let symbols = ["S", "M", "T", "W", "T", "F", "S"]
            return weekStartsOnMonday ? Array(symbols[1...]) + ["S"] : symbols
        }
        return weekStartsOnMonday ? ["一", "二", "三", "四", "五", "六", "日"] : ["日", "一", "二", "三", "四", "五", "六"]
    }

    public init(year: Int, month: Int, weekStartsOnMonday: Bool = true, holidays: HolidayCalendar = .standard()) {
        self.year = year
        self.month = month
        self.weekStartsOnMonday = weekStartsOnMonday
        let first = Day(year: year, month: month, day: 1)
        let leading = weekStartsOnMonday ? (first.weekday + 6) % 7 : first.weekday
        let start = first.addingDays(-leading)

        var cells: [CalendarDayCell] = []
        for offset in 0..<42 {
            let day = start.addingDays(offset)
            let info = DayInfo(day: day)
            cells.append(CalendarDayCell(
                day: day,
                inMonth: day.month == month && day.year == year,
                lunar: info.lunar,
                lunarLabel: LunarCalendar.lunarDate(from: day) == nil ? "—" : (info.cellFestivals.first ?? SolarTerms.cellDisplay(info.termName) ?? LunarCalendar.shortLabel(info.lunar)),
                festivals: info.displayFestivals,
                termName: SolarTerms.display(info.termName),
                holiday: holidays.status(on: day)
            ))
        }
        weeks = stride(from: 0, to: 42, by: 7).map { Array(cells[$0..<$0 + 7]) }
        if let last = weeks.last, last.allSatisfy({ !$0.inMonth }) {
            weeks.removeLast()
        }
    }

    public func cell(for day: Day) -> CalendarDayCell? {
        weeks.flatMap { $0 }.first { $0.day == day }
    }

    public func shifted(by months: Int, holidays: HolidayCalendar) -> CalendarMonthModel {
        let index = year * 12 + (month - 1) + months
        return CalendarMonthModel(
            year: index / 12,
            month: index % 12 + 1,
            weekStartsOnMonday: weekStartsOnMonday,
            holidays: holidays
        )
    }
}

/// 单日的农历 / 节气 / 节日推导结果。
struct DayInfo {
    var lunar: LunarDate
    var termName: String?
    var festivals: [String]
    /// 显示用（已按界面语言转换），canonical `festivals` 保持中文供数据比较。
    var displayFestivals: [String] { festivals.map(AlmanacNames.festival) }
    var cellFestivals: [String] { festivals.map(AlmanacNames.festivalCell) }

    init(day: Day) {
        lunar = LunarCalendar.lunarDate(from: day) ?? LunarDate(year: day.year, month: 1, day: 1, isLeapMonth: false)
        termName = SolarTerms.termMap(year: day.year)[day]
        let next = LunarCalendar.lunarDate(from: day.addingDays(1))
        let isLunarYearLastDay = next?.month == 1 && next?.day == 1 && next?.isLeapMonth == false
        festivals = Festivals.names(day: day, lunar: lunar, termName: termName, isLunarYearLastDay: isLunarYearLastDay)
    }
}

/// 某一天的完整黄历摘要（万年历详情区）。
public struct Almanac: Sendable {
    public var day: Day
    public var lunar: LunarDate
    public var lunarText: String
    public var lunarMonthDay: String
    public var zodiac: String
    public var ganZhiYear: String
    public var ganZhiMonth: String
    public var ganZhiDay: String
    public var festivals: [String]
    public var termName: String?
    public var weekdayName: String
    public var isoWeek: Int
    public var holiday: HolidayStatus?

    public init(day: Day, holidays: HolidayCalendar = .standard()) {
        self.day = day
        let info = DayInfo(day: day)
        lunar = info.lunar
        lunarText = LunarCalendar.fullString(info.lunar)
        // 英文给紧凑的 月/日 数字，菜单栏标题与详情行都用它，避免 "Lunar Lunar 10 17" 这类重复。
        lunarMonthDay = Lang.isEnglish ? "\(info.lunar.month)/\(info.lunar.day)" : LunarCalendar.monthName(info.lunar) + LunarCalendar.dayName(info.lunar)
        zodiac = LunarCalendar.zodiac(year: info.lunar.year)
        ganZhiYear = GanZhi.year(lunarYear: info.lunar.year)
        ganZhiMonth = GanZhi.month(day)
        ganZhiDay = GanZhi.day(day)
        termName = SolarTerms.display(info.termName)
        festivals = info.displayFestivals
        weekdayName = day.weekdayName
        isoWeek = day.isoWeek
        holiday = holidays.status(on: day)
    }
}

public enum Countdown {
    /// 距离下一个节日：优先法定假期数据，无数据年份回退到传统 / 公历节日。
    public static func next(after day: Day, holidays: HolidayCalendar) -> (name: String, days: Int)? {
        if let next = holidays.nextHoliday(after: day) {
            return (AlmanacNames.festival(next.name), next.start.epochDay - day.epochDay)
        }
        var cursor = day.addingDays(1)
        for _ in 0..<400 {
            if let name = DayInfo(day: cursor).festivals.first {
                return (AlmanacNames.festival(name), cursor.epochDay - day.epochDay)
            }
            cursor = cursor.addingDays(1)
        }
        return nil
    }
}