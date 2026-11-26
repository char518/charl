import Foundation

/// 当前天气（由 IP 定位 + Open-Meteo 公开接口获取，仅出站请求，不上传个人数据）。
public struct WeatherInfo: Codable, Hashable, Sendable {
    public var city: String
    public var temperature: Double
    public var code: Int
    public var high: Double?
    public var low: Double?
    public var fetchedAt: Date

    public init(city: String, temperature: Double, code: Int, high: Double?, low: Double?, fetchedAt: Date) {
        self.city = city
        self.temperature = temperature
        self.code = code
        self.high = high
        self.low = low
        self.fetchedAt = fetchedAt
    }
}

/// WMO weather code → 界面描述（中英） / SF Symbol。
public enum WeatherCondition {
    public static func text(code: Int) -> String {
        switch code {
        case 0: return loc("晴", "Clear")
        case 1: return loc("大部晴朗", "Mainly Clear")
        case 2: return loc("多云", "Partly Cloudy")
        case 3: return loc("阴", "Overcast")
        case 45, 48: return loc("雾", "Fog")
        case 51, 53, 55: return loc("毛毛雨", "Drizzle")
        case 56, 57: return loc("冻毛毛雨", "Freezing Drizzle")
        case 61, 63, 65: return loc("雨", "Rain")
        case 66, 67: return loc("冻雨", "Freezing Rain")
        case 71, 73, 75, 77: return loc("雪", "Snow")
        case 80, 81, 82: return loc("阵雨", "Showers")
        case 85, 86: return loc("阵雪", "Snow Showers")
        case 95: return loc("雷暴", "Thunderstorm")
        case 96, 99: return loc("雷暴伴冰雹", "Thunderstorm with Hail")
        default: return loc("未知", "Unknown")
        }
    }

    public static func symbol(code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "cloud.sun.fill"
        case 2: return "cloud.fill"
        case 3: return "smoke.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "questionmark.circle"
        }
    }
}

/// 解析 holiday-cn 数据集（源自国务院办公厅通知，含调休），合并为 HolidayYear。
/// 镜像：jsDelivr / GitHub raw（NateScarlet/holiday-cn）。
public enum RemoteHolidays {
    private struct Payload: Codable {
        struct Entry: Codable {
            var name: String
            var date: String
            var isOffDay: Bool
        }
        var year: Int?
        var days: [Entry]
    }

    public static func parse(year: Int, data: Data) -> HolidayYear? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
        let days = payload.days
            .compactMap { entry -> (day: Day, name: String, off: Bool)? in
                guard let day = HolidayCalendar.parse(entry.date), day.year == year else { return nil }
                return (day, entry.name, entry.isOffDay)
            }
            .sorted { $0.day < $1.day }
        guard !days.isEmpty else { return nil }

        var ranges: [HolidayYear.Range] = []
        var workdays: [String] = []
        var current: (name: String, start: Day, end: Day)?
        for entry in days {
            if entry.off {
                if let cur = current, cur.name == entry.name, entry.day.epochDay == cur.end.epochDay + 1 {
                    current = (cur.name, cur.start, entry.day)
                } else {
                    if let cur = current { ranges.append(.init(name: cur.name, start: cur.start.description, end: cur.end.description)) }
                    current = (entry.name, entry.day, entry.day)
                }
            } else {
                if let cur = current { ranges.append(.init(name: cur.name, start: cur.start.description, end: cur.end.description)); current = nil }
                workdays.append(entry.day.description)
            }
        }
        if let cur = current { ranges.append(.init(name: cur.name, start: cur.start.description, end: cur.end.description)) }
        return HolidayYear(year: year, holidays: ranges, workdays: workdays)
    }
}
