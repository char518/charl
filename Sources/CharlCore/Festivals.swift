import Foundation

public enum Festivals {
    private static let solar: [String: String] = [
        "1-1": "元旦", "2-14": "情人节", "3-8": "妇女节", "3-12": "植树节",
        "5-1": "劳动节", "5-4": "青年节", "6-1": "儿童节", "7-1": "建党节",
        "8-1": "建军节", "9-10": "教师节", "10-1": "国庆节", "12-25": "圣诞节",
    ]

    private static let lunarFestivals: [String: String] = [
        "1-1": "春节", "1-15": "元宵节", "5-5": "端午节", "7-7": "七夕",
        "7-15": "中元节", "8-15": "中秋节", "9-9": "重阳节", "12-8": "腊八节",
    ]

    public static func names(day: Day, lunar: LunarDate, termName: String?, isLunarYearLastDay: Bool) -> [String] {
        var result: [String] = []
        if let festival = solar["\(day.month)-\(day.day)"] {
            result.append(festival)
        }
        if !lunar.isLeapMonth, let festival = lunarFestivals["\(lunar.month)-\(lunar.day)"] {
            result.append(festival)
        }
        if termName == "清明" {
            result.append("清明")
        }
        if isLunarYearLastDay {
            result.append("除夕")
        }
        return result
    }
}