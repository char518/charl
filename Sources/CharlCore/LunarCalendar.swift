import Foundation

public struct LunarDate: Hashable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var isLeapMonth: Bool

    public init(year: Int, month: Int, day: Int, isLeapMonth: Bool) {
        self.year = year
        self.month = month
        self.day = day
        self.isLeapMonth = isLeapMonth
    }
}

/// 农历换算（1900–2100）。数据表为公开历法压缩表：
/// bit16 = 闰月大小(30/29)，bit15..4 = 正月..十二月大小，bit3..0 = 闰月月份(0 无)。
public enum LunarCalendar {
    public static let minYear = 1900
    public static let maxYear = 2100

    static let info: [Int] = [
        0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2, // 1900-1909
        0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977, // 1910-1919
        0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970, // 1920-1929
        0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950, // 1930-1939
        0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557, // 1940-1949
        0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0, // 1950-1959
        0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0, // 1960-1969
        0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6, // 1970-1979
        0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570, // 1980-1989
        0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0, // 1990-1999
        0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5, // 2000-2009
        0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930, // 2010-2019
        0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530, // 2020-2029
        0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45, // 2030-2039
        0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0, // 2040-2049
        0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0, // 2050-2059
        0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4, // 2060-2069
        0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0, // 2070-2079
        0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160, // 2080-2089
        0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252, // 2090-2099
        0x0d520, // 2100
    ]

    private static let baseEpochDay = Day(year: 1900, month: 1, day: 31).epochDay

    public static func leapMonth(_ year: Int) -> Int { info[year - minYear] & 0xf }

    public static func leapDays(_ year: Int) -> Int {
        leapMonth(year) == 0 ? 0 : (info[year - minYear] & 0x10000 != 0 ? 30 : 29)
    }

    public static func monthDays(_ year: Int, _ month: Int) -> Int {
        info[year - minYear] & (0x10000 >> month) != 0 ? 30 : 29
    }

    public static func yearDays(_ year: Int) -> Int {
        var sum = 348
        var bit = 0x8000
        while bit > 0x8 {
            if info[year - minYear] & bit != 0 { sum += 1 }
            bit >>= 1
        }
        return sum + leapDays(year)
    }

    public static func lunarDate(from day: Day) -> LunarDate? {
        var offset = day.epochDay - baseEpochDay
        guard offset >= 0 else { return nil }
        var year = minYear
        while year <= maxYear {
            let days = yearDays(year)
            if offset < days { break }
            offset -= days
            year += 1
        }
        guard year <= maxYear else { return nil }

        let leap = leapMonth(year)
        for month in 1...12 {
            let days = monthDays(year, month)
            if offset < days {
                return LunarDate(year: year, month: month, day: offset + 1, isLeapMonth: false)
            }
            offset -= days
            if month == leap {
                let leapDayCount = leapDays(year)
                if offset < leapDayCount {
                    return LunarDate(year: year, month: month, day: offset + 1, isLeapMonth: true)
                }
                offset -= leapDayCount
            }
        }
        return nil
    }

    private static let monthNames = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]
    private static let dayNames = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十",
    ]
    private static let zodiacNames = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]
    private static let ganNames = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private static let zhiNames = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

    public static func monthName(_ lunar: LunarDate) -> String {
        if Lang.isEnglish { return (lunar.isLeapMonth ? "Leap " : "Lunar ") + String(lunar.month) }
        return (lunar.isLeapMonth ? "闰" : "") + monthNames[lunar.month - 1]
    }

    /// 农历日：英文模式直接给数字（廿三 → 23）。
    public static func dayName(_ lunar: LunarDate) -> String {
        Lang.isEnglish ? String(lunar.day) : dayNames[lunar.day - 1]
    }

    /// 日历格子用的短标签：初一显示月名，其余显示日名。
    public static func shortLabel(_ lunar: LunarDate) -> String {
        lunar.day == 1 ? monthName(lunar) : dayName(lunar)
    }

    public static func zodiac(year: Int) -> String {
        Lang.isEnglish ? AlmanacNames.zodiacEN(branchIndex: year - 4) : zodiacNames[(year - 4) % 12]
    }

    public static func ganZhi(year: Int) -> String {
        Lang.isEnglish
            ? AlmanacNames.ganZhiEN(stem: (year - 4) % 10, branch: (year - 4) % 12)
            : ganNames[(year - 4) % 10] + zhiNames[(year - 4) % 12]
    }

    public static func fullString(_ lunar: LunarDate) -> String {
        if Lang.isEnglish {
            return "Year of the \(ganZhi(year: lunar.year)), Lunar \(lunar.month)/\(lunar.day)"
        }
        return "\(ganZhi(year: lunar.year))年\(monthName(lunar))\(dayName(lunar))"
    }
}