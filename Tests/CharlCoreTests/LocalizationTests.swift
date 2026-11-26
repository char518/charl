import Foundation
import CharlCore

/// 双语层：语言解析、文案切换、农历体系的英文表达，以及设置里的语言字段持久化。
func testLocalization() {
    let restore = Lang.preference
    Lang.preference = .chinese

    suite("语言解析", {
        expectEqual(Lang.resolve(preference: .chinese, preferredLanguages: ["en-US"]), .chinese, "手动中文覆盖系统英文")
        expectEqual(Lang.resolve(preference: .english, preferredLanguages: ["zh-CN"]), .english, "手动英文覆盖系统中文")
        expectEqual(Lang.resolve(preference: .system, preferredLanguages: ["zh-CN", "en-US"]), .chinese, "系统首选中文")
        expectEqual(Lang.resolve(preference: .system, preferredLanguages: ["zh-Hant-TW"]), .chinese, "繁体也走简体中文文案")
        expectEqual(Lang.resolve(preference: .system, preferredLanguages: ["en-US", "zh-CN"]), .english, "系统首选英文")
        expectEqual(Lang.resolve(preference: .system, preferredLanguages: ["ja-JP"]), .english, "其它语言回退英文")
        expectEqual(Lang.resolve(preference: .system, preferredLanguages: []), .english, "无系统语言时回退英文")
        expectEqual(loc("剪贴板", "Clipboard"), "剪贴板", "中文模式取第一参数")
        Lang.preference = .english
        expectEqual(loc("剪贴板", "Clipboard"), "Clipboard", "英文模式取第二参数")
    })

    suite("英文农历表达", {
        Lang.preference = .english
        expectEqual(LunarCalendar.dayName(LunarDate(year: 2026, month: 10, day: 23, isLeapMonth: false)), "23", "廿三 → 数字")
        expectEqual(LunarCalendar.monthName(LunarDate(year: 2026, month: 10, day: 1, isLeapMonth: false)), "Lunar 10", "十月 → Lunar 10")
        expectEqual(LunarCalendar.monthName(LunarDate(year: 2025, month: 6, day: 1, isLeapMonth: true)), "Leap 6", "闰六月 → Leap 6")
        expectEqual(LunarCalendar.ganZhi(year: 2026), "Fire Horse", "丙午 → Fire Horse")
        expectEqual(LunarCalendar.zodiac(year: 2026), "Horse", "生肖英文")
        expectEqual(SolarTerms.display("立春"), "Beginning of Spring", "节气英文名")
        expectEqual(SolarTerms.display("清明"), "Clear and Bright", "清明既是节气也是节日")
        expectEqual(SolarTerms.display(nil) ?? "nil", "nil", "无节气仍是 nil")
        expectEqual(AlmanacNames.festival("端午节"), "Dragon Boat Festival", "节日英文名")
        expectEqual(AlmanacNames.festival("自定义假日"), "自定义假日", "未收录名称保持原文")
        expectEqual(Day(year: 2026, month: 11, day: 18).weekdayName, "Wednesday", "星期英文")
        expectEqual(CalendarMonthModel(year: 2026, month: 11).title, "November 2026", "月份标题英文")
        expectEqual(CalendarMonthModel(year: 2026, month: 11).weekdaySymbols, ["M", "T", "W", "T", "F", "S", "S"], "周日开始的英文缩写")
        expectEqual(CalendarMonthModel(year: 2026, month: 11, weekStartsOnMonday: false).weekdaySymbols.count, 7, "周一起始仍是 7 列")
        expectEqual(WeatherCondition.text(code: 0), "Clear", "天气英文")
        expectEqual(RelativeTime.string(for: Date(timeIntervalSince1970: 0), now: Date(timeIntervalSince1970: 60)), "1 min ago", "单数分钟")
        expectEqual(RelativeTime.string(for: Date(timeIntervalSince1970: 0), now: Date(timeIntervalSince1970: 180)), "3 min ago", "复数分钟")

        // 节气/节日进入日历格子后必须是显示语言，且比较逻辑仍用中文原文。
        let qingMing = Day(year: 2026, month: 4, day: 5)
        let almanac = Almanac(day: qingMing)
        expectEqual(almanac.termName, "Clear and Bright", "详情区节气英文")
        expect(almanac.festivals.contains("Clear and Bright") || almanac.festivals.contains("Qingming Festival"),
               "节日 chip 与节气英文一致，不出现中英混排")
        Lang.preference = .chinese
        expectEqual(Almanac(day: qingMing).termName, "清明", "切回中文后是原文")
        expectEqual(loc("剪贴板", "Clipboard"), "剪贴板", "语言切换即时生效")
    })

    suite("日历格子短标签", {
        Lang.preference = .english
        let october = CalendarMonthModel(year: 2026, month: 10)
        expectEqual(october.cell(for: Day(year: 2026, month: 10, day: 1))?.lunarLabel, "National Day", "格子节日用短英文名")
        expectEqual(october.cell(for: Day(year: 2026, month: 10, day: 8))?.lunarLabel, "Cold Dew", "格子节气用短英文名")
        expectEqual(CalendarMonthModel(year: 2026, month: 11).cell(for: Day(year: 2026, month: 11, day: 7))?.lunarLabel, "Beg. Winter", "立冬缩写")
        expectEqual(AlmanacNames.solarTermCell("立春"), "Beg. Spring", "节气缩写")
        expectEqual(SolarTerms.display("立春"), "Beginning of Spring", "详情区仍是全称")
        expectEqual(AlmanacNames.festivalCell("春节"), "Spring Fest.", "春节缩写")
        expectEqual(AlmanacNames.festivalCell("清明节"), "Qingming", "法定节日名缩写")
        let day = Day(year: 2026, month: 11, day: 25)
        expectEqual(Almanac(day: day).lunarMonthDay, "10/17", "农历月/日数字")
        expectEqual(LunarCalendar.fullString(LunarCalendar.lunarDate(from: day)!), "Year of the Fire Horse, Lunar 10/17", "完整农历串")

        Lang.preference = .chinese
        expectEqual(CalendarMonthModel(year: 2026, month: 10).cell(for: Day(year: 2026, month: 10, day: 1))?.lunarLabel, "国庆节", "中文格子不变")
        expectEqual(CalendarMonthModel(year: 2026, month: 11).cell(for: Day(year: 2026, month: 11, day: 7))?.lunarLabel, "立冬", "中文节气不变")
        expectEqual(Almanac(day: day).lunarMonthDay, "十月十七", "中文农历不变")
    })

    suite("语言偏好持久化", {
        let json = try! JSONEncoder().encode(AppSettings(language: .english))
        let back = try! JSONDecoder().decode(AppSettings.self, from: json)
        expectEqual(back.language, .english, "编码后保留语言偏好")
        let legacy = try! JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        expectEqual(legacy.language, .system, "旧设置缺字段时跟随系统")
        expectEqual(LanguagePreference.english.title, "English", "语言名始终用本体写法")
        Lang.preference = .chinese
        expectEqual(LanguagePreference.system.title, "跟随系统", "选项标签跟随界面语言")
    })

    Lang.preference = restore
}
