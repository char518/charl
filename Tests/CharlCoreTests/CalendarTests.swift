import CharlCore
import Foundation

func testDayMath() {
    suite("Day") {
        expectEqual(Day(year: 1970, month: 1, day: 1).epochDay, 0, "epoch")
        expectEqual(Day(epochDay: 0), Day(year: 1970, month: 1, day: 1), "inverse epoch")
        expectEqual(Day(year: 2000, month: 3, day: 1).epochDay - Day(year: 2000, month: 2, day: 28).epochDay, 2, "leap year feb")
        expectEqual(Day(year: 1900, month: 3, day: 1).epochDay - Day(year: 1900, month: 2, day: 28).epochDay, 1, "1900 not leap")
        expectEqual(Day(year: 2026, month: 11, day: 18).weekday, 3, "2026-11-18 wednesday")
        expectEqual(Day(year: 2026, month: 1, day: 1).addingDays(-1), Day(year: 2025, month: 12, day: 31), "year boundary")
        expectEqual(Day(year: 2026, month: 2, day: 30), Day(year: 2026, month: 3, day: 2), "invalid date normalized")
        expectEqual(Day(year: 2026, month: 11, day: 18).isoWeek, 47, "iso week 47")
        expectEqual(Day(year: 2026, month: 1, day: 1).isoWeek, 1, "iso week 1 (Thu)")
        expectEqual(Day(year: 2026, month: 11, day: 18).weekdayName, "星期三", "weekday name")
        for offset in stride(from: -20000, through: 20000, by: 37) {
            let day = Day(epochDay: offset)
            expectEqual(day.epochDay, offset, "round trip \(offset)")
        }
    }
}

func testLunarCalendar() {
    suite("LunarCalendar") {
        expectEqual(LunarCalendar.lunarDate(from: Day(year: 2024, month: 2, day: 10)), LunarDate(year: 2024, month: 1, day: 1, isLeapMonth: false), "2024 CNY")
        expectEqual(LunarCalendar.lunarDate(from: Day(year: 2025, month: 1, day: 29)), LunarDate(year: 2025, month: 1, day: 1, isLeapMonth: false), "2025 CNY")
        expectEqual(LunarCalendar.lunarDate(from: Day(year: 2026, month: 2, day: 17)), LunarDate(year: 2026, month: 1, day: 1, isLeapMonth: false), "2026 CNY")
        expectEqual(LunarCalendar.lunarDate(from: Day(year: 2025, month: 7, day: 25)), LunarDate(year: 2025, month: 6, day: 1, isLeapMonth: true), "2025 leap六月")
        expectEqual(LunarCalendar.lunarDate(from: Day(year: 2023, month: 3, day: 22)), LunarDate(year: 2023, month: 2, day: 1, isLeapMonth: true), "2023 leap二月")
        expectEqual(LunarCalendar.lunarDate(from: Day(year: 1900, month: 1, day: 31)), LunarDate(year: 1900, month: 1, day: 1, isLeapMonth: false), "base date")
        expect(LunarCalendar.lunarDate(from: Day(year: 1899, month: 12, day: 31)) == nil, "out of range")
        // 官方通知："2月15日（农历腊月二十八）""2月23日（农历正月初七）"
        expectEqual(LunarCalendar.lunarDate(from: Day(year: 2026, month: 2, day: 15)), LunarDate(year: 2025, month: 12, day: 28, isLeapMonth: false), "2026-02-15 腊月廿八")
        expectEqual(LunarCalendar.lunarDate(from: Day(year: 2026, month: 2, day: 23)), LunarDate(year: 2026, month: 1, day: 7, isLeapMonth: false), "2026-02-23 正月初七")
        // 2027 通知："2月5日（农历除夕）""13日（农历正月初八）"
        expectEqual(LunarCalendar.lunarDate(from: Day(year: 2027, month: 2, day: 13)), LunarDate(year: 2027, month: 1, day: 8, isLeapMonth: false), "2027-02-13 正月初八")
        expectEqual(LunarCalendar.lunarDate(from: Day(year: 2026, month: 11, day: 18)), LunarDate(year: 2026, month: 10, day: 10, isLeapMonth: false), "2026-11-18 十月初十")

        expectEqual(LunarCalendar.zodiac(year: 2026), "马", "zodiac 2026")
        expectEqual(LunarCalendar.ganZhi(year: 2026), "丙午", "ganzhi 2026")
        expectEqual(LunarCalendar.ganZhi(year: 1900), "庚子", "ganzhi 1900")
        expectEqual(LunarCalendar.dayName(LunarDate(year: 2026, month: 1, day: 1, isLeapMonth: false)), "初一", "day name 1")
        expectEqual(LunarCalendar.dayName(LunarDate(year: 2026, month: 1, day: 23, isLeapMonth: false)), "廿三", "day name 23")
        expectEqual(LunarCalendar.dayName(LunarDate(year: 2026, month: 1, day: 30, isLeapMonth: false)), "三十", "day name 30")
        expectEqual(LunarCalendar.monthName(LunarDate(year: 2025, month: 6, day: 1, isLeapMonth: true)), "闰六月", "leap month name")

        for year in 1900...2100 {
            let days = LunarCalendar.yearDays(year)
            expect(days >= 353 && days <= 385, "year \(year) days \(days) in range")
        }
    }
}

func testSolarTerms() {
    suite("SolarTerms") {
        expectEqual(SolarTerms.termDay(year: 2024, index: 2), Day(year: 2024, month: 2, day: 4), "2024 立春")
        expectEqual(SolarTerms.termDay(year: 2024, index: 23), Day(year: 2024, month: 12, day: 21), "2024 冬至")
        expectEqual(SolarTerms.termDay(year: 2025, index: 5), Day(year: 2025, month: 3, day: 20), "2025 春分")
        expectEqual(SolarTerms.termDay(year: 2025, index: 11), Day(year: 2025, month: 6, day: 21), "2025 夏至")
        expectEqual(SolarTerms.termDay(year: 2025, index: 23), Day(year: 2025, month: 12, day: 21), "2025 冬至")
        expectEqual(SolarTerms.termDay(year: 2026, index: 2), Day(year: 2026, month: 2, day: 4), "2026 立春")
        expectEqual(SolarTerms.termDay(year: 2026, index: 6), Day(year: 2026, month: 4, day: 5), "2026 清明")
        expectEqual(SolarTerms.termDay(year: 2026, index: 0), Day(year: 2026, month: 1, day: 5), "2026 小寒")

        let map = SolarTerms.termMap(year: 2026)
        expectEqual(map.count, 24, "24 terms per year")
        expectEqual(map[Day(year: 2026, month: 11, day: 7)], "立冬", "2026 立冬")
        expectEqual(map[Day(year: 2026, month: 11, day: 22)], "小雪", "2026 小雪")
    }
}

func testGanZhi() {
    suite("GanZhi") {
        expectEqual(GanZhi.day(Day(year: 1949, month: 10, day: 1)), "甲子", "1949-10-01 甲子日")
        expectEqual(GanZhi.day(Day(year: 2000, month: 1, day: 1)), "戊午", "2000-01-01 戊午日")
        expectEqual(GanZhi.day(Day(year: 1949, month: 11, day: 30)), "甲子", "60-day cycle")
        expectEqual(GanZhi.month(Day(year: 2026, month: 11, day: 18)), "己亥", "2026-11-18 己亥月（立冬后）")
        expectEqual(GanZhi.month(Day(year: 2026, month: 2, day: 10)), "庚寅", "2026 立春后 庚寅月")
        expectEqual(GanZhi.month(Day(year: 2026, month: 2, day: 1)), "己丑", "2026 立春前仍属乙巳年丑月")
        expectEqual(GanZhi.month(Day(year: 2026, month: 1, day: 2)), "戊子", "小寒前属上年子月")
        expectEqual(GanZhi.month(Day(year: 2026, month: 12, day: 20)), "庚子", "2026 大雪后 庚子月")
    }
}

func testHolidays() {
    suite("HolidayCalendar") {
        let holidays = HolidayCalendar.standard()
        expectEqual(holidays.status(on: Day(year: 2026, month: 10, day: 1)), .off("国庆节"), "2026 国庆")
        expectEqual(holidays.status(on: Day(year: 2026, month: 10, day: 7)), .off("国庆节"), "2026 国庆末日")
        expectEqual(holidays.status(on: Day(year: 2026, month: 10, day: 8)), nil, "2026-10-08 normal")
        expectEqual(holidays.status(on: Day(year: 2026, month: 10, day: 10)), .work, "2026-10-10 调休上班")
        expectEqual(holidays.status(on: Day(year: 2026, month: 2, day: 14)), .work, "2026-02-14 调休上班")
        expectEqual(holidays.status(on: Day(year: 2026, month: 2, day: 23)), .off("春节"), "2026 春节末日")
        expectEqual(holidays.status(on: Day(year: 2027, month: 2, day: 5)), .off("春节"), "2027 除夕放假")
        expectEqual(holidays.status(on: Day(year: 2027, month: 6, day: 9)), .off("端午节"), "2027 端午单日")
        expectEqual(holidays.status(on: Day(year: 2025, month: 10, day: 1)), nil, "未收录年份不标注")
        expectEqual(holidays.status(on: Day(year: 2026, month: 11, day: 18)), nil, "普通工作日")

        let next = holidays.nextHoliday(after: Day(year: 2026, month: 11, day: 18))
        expectEqual(next?.name, "元旦", "next holiday 元旦")
        expectEqual(next?.start, Day(year: 2027, month: 1, day: 1), "next holiday start")
        let countdown = Countdown.next(after: Day(year: 2026, month: 11, day: 18), holidays: holidays)
        expectEqual(countdown?.days, 44, "44 days to 元旦")

        let override = HolidayYear(year: 2026, holidays: [.init(name: "测试假", start: "2026-11-20", end: "2026-11-20")], workdays: [])
        let custom = HolidayCalendar.standard(overrides: [override])
        expectEqual(custom.status(on: Day(year: 2026, month: 11, day: 20)), .off("测试假"), "user override wins")
        expectEqual(custom.status(on: Day(year: 2026, month: 10, day: 1)), nil, "override replaces whole year")

        let fallback = Countdown.next(after: Day(year: 2030, month: 9, day: 1), holidays: holidays)
        expect(fallback != nil, "fallback to festivals when no data")
    }
}

func testCalendarMonth() {
    suite("CalendarMonth") {
        let sunday = CalendarMonthModel(year: 2026, month: 11, weekStartsOnMonday: false)
        expectEqual(sunday.weeks.count, 5, "nov 2026 sunday-first 5 weeks")
        expectEqual(sunday.weeks[0][0].day.weekday, 0, "sunday first")

        let month = CalendarMonthModel(year: 2026, month: 11)
        expectEqual(month.weeks.count, 6, "nov 2026 monday-first 6 weeks")
        expect(month.weeks.allSatisfy { $0.count == 7 }, "7 columns")
        expectEqual(month.weeks[0][0].day.weekday, 1, "monday first")
        expectEqual(month.weeks[0][0].day, Day(year: 2026, month: 10, day: 26), "leading days from Oct 26")
        expectEqual(month.weekdaySymbols.first, "一", "symbols start 一")
        let cell = month.cell(for: Day(year: 2026, month: 11, day: 18))
        expectEqual(cell?.inMonth, true, "in month")

        let oct = CalendarMonthModel(year: 2026, month: 10)
        expectEqual(oct.cell(for: Day(year: 2026, month: 10, day: 1))?.holiday, .off("国庆节"), "cell holiday off")
        expectEqual(oct.cell(for: Day(year: 2026, month: 10, day: 10))?.holiday, .work, "cell holiday work")

        let feb = CalendarMonthModel(year: 2026, month: 2)
        let cny = feb.cell(for: Day(year: 2026, month: 2, day: 17))
        expectEqual(cny?.festivals, ["春节"], "CNY festival")
        expectEqual(cny?.lunarLabel, "春节", "festival label wins")
        expectEqual(feb.cell(for: Day(year: 2026, month: 2, day: 16))?.festivals, ["除夕"], "除夕")

        let apr = CalendarMonthModel(year: 2026, month: 4)
        let qm = apr.cell(for: Day(year: 2026, month: 4, day: 5))
        expectEqual(qm?.termName, "清明", "清明 term")

        let shifted = month.shifted(by: 2, holidays: .standard())
        expectEqual(shifted.year, 2027, "shift across year")
        expectEqual(shifted.month, 1, "shift month")
        expectEqual(month.shifted(by: -11, holidays: .standard()).month, 12, "shift back across year")

        let almanac = Almanac(day: Day(year: 2026, month: 11, day: 18))
        expectEqual(almanac.lunarMonthDay, "十月初十", "almanac lunar")
        expectEqual(almanac.ganZhiYear, "丙午", "almanac year")
        expectEqual(almanac.ganZhiMonth, "己亥", "almanac month")
        expectEqual(almanac.isoWeek, 47, "almanac week")
        expectEqual(almanac.weekdayName, "星期三", "almanac weekday")
        expectEqual(Almanac(day: Day(year: 2026, month: 2, day: 17)).lunarText, "丙午年正月初一", "almanac text")
    }
}