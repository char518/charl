import Foundation

/// 农历体系专有名词的英文对照。英文模式下日历与详情区用它们显示；
/// 表内没有的名称（例如用户自定义节假日、远程数据里的陌生节日）保持原文。
public enum AlmanacNames {
    /// 公历月份英文名。
    public static let monthsEN = ["January", "February", "March", "April", "May", "June",
                                   "July", "August", "September", "October", "November", "December"]

    static let elements = ["Wood", "Wood", "Fire", "Fire", "Earth", "Earth", "Metal", "Metal", "Water", "Water"]
    static let animals = ["Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake", "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig"]

    /// 干支（天干序号, 地支序号）→ 英文，例如 (1, 5) = 乙巳 → Wood Snake。
    static func ganZhiEN(stem: Int, branch: Int) -> String {
        elements[((stem % 10) + 10) % 10] + " " + animals[((branch % 12) + 12) % 12]
    }

    /// 生肖英文（与地支同序：子 = Rat）。
    static func zodiacEN(branchIndex: Int) -> String {
        animals[((branchIndex % 12) + 12) % 12]
    }

    private static let solarTerms: [String: String] = [
        "小寒": "Minor Cold", "大寒": "Major Cold", "立春": "Beginning of Spring", "雨水": "Rain Water",
        "惊蛰": "Awakening of Insects", "春分": "Spring Equinox", "清明": "Clear and Bright", "谷雨": "Grain Rain",
        "立夏": "Beginning of Summer", "小满": "Grain Buds", "芒种": "Grain in Ear", "夏至": "Summer Solstice",
        "小暑": "Minor Heat", "大暑": "Major Heat", "立秋": "Beginning of Autumn", "处暑": "End of Heat",
        "白露": "White Dew", "秋分": "Autumn Equinox", "寒露": "Cold Dew", "霜降": "Frost's Descent",
        "立冬": "Beginning of Winter", "小雪": "Minor Snow", "大雪": "Major Snow", "冬至": "Winter Solstice",
    ]

    /// 公历 / 农历节日与法定节假日名称。
    private static let festivals: [String: String] = [
        "元旦": "New Year's Day", "情人节": "Valentine's Day", "妇女节": "International Women's Day",
        "植树节": "Arbor Day", "劳动节": "Labour Day", "青年节": "Youth Day", "儿童节": "Children's Day",
        "建党节": "Founding of the CPC", "建军节": "Army Day", "教师节": "Teachers' Day",
        "国庆节": "National Day", "圣诞节": "Christmas", "除夕": "New Year's Eve",
        "春节": "Spring Festival", "元宵节": "Lantern Festival", "清明节": "Qingming Festival",
        "端午节": "Dragon Boat Festival", "七夕": "Qixi Festival", "中元节": "Hungry Ghost Festival",
        "中秋节": "Mid-Autumn Festival", "重阳节": "Double Ninth Festival", "腊八节": "Laba Festival",
        "清明": "Clear and Bright",
    ]

    /// 节气紧凑英文名：日历格子宽度只有 ~45pt，全称（Beginning of Winter）会被截断。
    private static let solarTermsShort: [String: String] = [
        "小寒": "Minor Cold", "大寒": "Major Cold", "立春": "Beg. Spring", "雨水": "Rain Water",
        "惊蛰": "Insects Stir", "春分": "Mid Spring", "清明": "Clear", "谷雨": "Grain Rain",
        "立夏": "Beg. Summer", "小满": "Grain Buds", "芒种": "Grain in Ear", "夏至": "Midsummer",
        "小暑": "Minor Heat", "大暑": "Major Heat", "立秋": "Beg. Autumn", "处暑": "End of Heat",
        "白露": "White Dew", "秋分": "Mid Autumn", "寒露": "Cold Dew", "霜降": "Frost Falls",
        "立冬": "Beg. Winter", "小雪": "Minor Snow", "大雪": "Major Snow", "冬至": "Midwinter",
    ]

    /// 节日紧凑英文名，同上只用于日历格子。
    private static let festivalsShort: [String: String] = [
        "元旦": "New Year", "情人节": "Valentine's", "妇女节": "Women's Day", "植树节": "Arbor Day",
        "劳动节": "Labour Day", "青年节": "Youth Day", "儿童节": "Kids' Day", "建党节": "CPC Day",
        "建军节": "Army Day", "教师节": "Teachers' Day", "国庆节": "National Day", "圣诞节": "Christmas",
        "除夕": "NY Eve", "春节": "Spring Fest.", "元宵节": "Lantern", "清明节": "Qingming",
        "端午节": "Dragon Boat", "七夕": "Qixi", "中元节": "Hungry Ghost", "中秋节": "Mid-Autumn",
        "重阳节": "Double Ninth", "腊八节": "Laba", "清明": "Clear",
    ]

    public static func solarTerm(_ name: String) -> String {
        Lang.isEnglish ? (solarTerms[name] ?? name) : name
    }

    /// 日历格子用的短标签：英文走紧凑表，中文与全称一致。
    public static func solarTermCell(_ name: String) -> String {
        Lang.isEnglish ? (solarTermsShort[name] ?? solarTerms[name] ?? name) : name
    }

    public static func festivalCell(_ name: String) -> String {
        Lang.isEnglish ? (festivalsShort[name] ?? festivals[name] ?? name) : name
    }

    /// 节日与法定节假日（含 holiday-cn 通知里的名称）的显示文案。
    public static func festival(_ name: String) -> String {
        Lang.isEnglish ? (festivals[name] ?? name) : name
    }
}
