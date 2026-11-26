import Foundation

/// 干支纪日 / 纪月 / 纪年。纪日以 1949-10-01 甲子日为锚（与 2000-01-01 戊午日交叉校验）；
/// 纪月以"节"（立春、惊蛰…）为月界；纪年沿用农历年。
public enum GanZhi {
    static let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    static let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

    private static let jiaZiAnchorEpochDay = Day(year: 1949, month: 10, day: 1).epochDay

    static func name(_ index: Int) -> String {
        let i = ((index % 60) + 60) % 60
        return Lang.isEnglish
            ? AlmanacNames.ganZhiEN(stem: i % 10, branch: i % 12)
            : stems[i % 10] + branches[i % 12]
    }

    public static func day(_ day: Day) -> String {
        name(day.epochDay - jiaZiAnchorEpochDay)
    }

    /// 节（奇数节气位）索引：小寒0 立春2 惊蛰4 清明6 立夏8 芒种10 小暑12 立秋14 白露16 寒露18 立冬20 大雪22
    public static func month(_ day: Day) -> String {
        var jieIndex = -1
        for index in stride(from: 22, through: 0, by: -2) where SolarTerms.termDay(year: day.year, index: index) <= day {
            jieIndex = index
            break
        }
        // 当年小寒之前属上一年大雪起的子月
        let branchIndex: Int
        let stemYear: Int
        if jieIndex < 0 {
            branchIndex = 0
            stemYear = day.year - 1
        } else {
            branchIndex = (jieIndex / 2 + 1) % 12
            stemYear = jieIndex >= 2 ? day.year : day.year - 1
        }
        // 立春年天干决定寅月天干：甲己丙寅、乙庚戊寅…  stem(寅) = (yearStem*2 + 2) % 10
        let yearStem = ((stemYear - 4) % 10 + 10) % 10
        let offsetFromYin = (branchIndex - 2 + 12) % 12
        let stem = (yearStem * 2 + 2 + offsetFromYin) % 10
        return Lang.isEnglish
            ? AlmanacNames.ganZhiEN(stem: stem, branch: branchIndex)
            : stems[stem] + branches[branchIndex]
    }

    public static func year(lunarYear: Int) -> String {
        LunarCalendar.ganZhi(year: lunarYear)
    }
}

extension Day {
    /// ISO 8601 周序（周一起始，含 1 月 4 日的周为第 1 周）。
    public var isoWeek: Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = Day.chinaTimeZone
        return calendar.component(.weekOfYear, from: date())
    }

    public var weekdayName: String {
        Lang.isEnglish
            ? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][weekday]
            : ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"][weekday]
    }
}