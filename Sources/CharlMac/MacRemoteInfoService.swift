import CharlCore
import CharlPlatform
import Foundation

/// 公开接口读取天气与法定假日（仅出站、无密钥、不上传个人数据）。
/// IP 仅用于推断城市；失败时返回 nil，由调用方回退到缓存/内置数据。
public final class MacRemoteInfoService: RemoteInfoService {
    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    public func fetchWeather() async -> WeatherInfo? {
        guard let location = await fetchLocation() else { return nil }
        if let info = await fetchWttr(location) { return info }
        return await fetchOpenMeteo(location)
    }

    public func fetchHolidays(year: Int) async -> HolidayYear? {
        let sources = [
            "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json",
            "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json",
        ]
        for text in sources {
            guard let url = URL(string: text),
                  let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let holiday = RemoteHolidays.parse(year: year, data: data) else { continue }
            return holiday
        }
        return nil
    }

    private struct Location {
        var city: String
        var latitude: Double
        var longitude: Double
    }

    private struct IPWho: Codable {
        var success: Bool?
        var city: String?
        var latitude: Double?
        var longitude: Double?
    }

    private struct IPAPI: Codable {
        var city: String?
        var latitude: Double?
        var longitude: Double?
    }

    private func fetchLocation() async -> Location? {
        if let url = URL(string: "https://ipwho.is/"),
           let (data, response) = try? await session.data(from: url),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let payload = try? JSONDecoder().decode(IPWho.self, from: data),
           payload.success != false,
           let lat = payload.latitude, let lon = payload.longitude {
            return Location(city: payload.city ?? loc("未知", "Unknown"), latitude: lat, longitude: lon)
        }
        if let url = URL(string: "https://ipapi.co/json/"),
           let (data, response) = try? await session.data(from: url),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let payload = try? JSONDecoder().decode(IPAPI.self, from: data),
           let lat = payload.latitude, let lon = payload.longitude {
            return Location(city: payload.city ?? loc("未知", "Unknown"), latitude: lat, longitude: lon)
        }
        return nil
    }

    // MARK: - 天气：wttr.in（主，直连可达）→ Open-Meteo（备，需代理时更稳）

    private struct Wttr: Codable {
        struct Current: Codable {
            var temp_C: String
            var weatherCode: String
        }
        struct Daily: Codable {
            var maxtempC: String
            var mintempC: String
        }
        var current_condition: [Current]
        var weather: [Daily]
    }

    private func fetchWttr(_ location: Location) async -> WeatherInfo? {
        let coord = String(format: "%.4f,%.4f", location.latitude, location.longitude)
        guard let url = URL(string: "https://wttr.in/\(coord)?format=j1"),
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(Wttr.self, from: data),
              let current = payload.current_condition.first,
              let temp = Double(current.temp_C),
              let code = Int(current.weatherCode) else { return nil }
        let today = payload.weather.first
        return WeatherInfo(
            city: location.city,
            temperature: temp,
            code: Self.wmo(fromWWO: code),
            high: today.flatMap { Double($0.maxtempC) },
            low: today.flatMap { Double($0.mintempC) },
            fetchedAt: Date()
        )
    }

    private struct OpenMeteo: Codable {
        struct Current: Codable {
            var temperature_2m: Double
            var weather_code: Int
        }
        struct Daily: Codable {
            var temperature_2m_max: [Double]
            var temperature_2m_min: [Double]
        }
        var current: Current
        var daily: Daily
    }

    private func fetchOpenMeteo(_ location: Location) async -> WeatherInfo? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(OpenMeteo.self, from: data) else { return nil }
        return WeatherInfo(
            city: location.city,
            temperature: payload.current.temperature_2m,
            code: payload.current.weather_code,
            high: payload.daily.temperature_2m_max.first,
            low: payload.daily.temperature_2m_min.first,
            fetchedAt: Date()
        )
    }

    /// WorldWeatherOnline（wttr.in）代码 → WMO 代码，统一交由 WeatherCondition 映射。
    private static func wmo(fromWWO code: Int) -> Int {
        switch code {
        case 113: return 0
        case 116: return 2
        case 119, 122: return 3
        case 143, 248: return 45
        case 260: return 48
        case 263, 266: return 51
        case 185, 281: return 56
        case 284: return 57
        case 176, 293, 296: return 61
        case 299, 302: return 63
        case 305, 308: return 65
        case 182, 311, 317: return 66
        case 314, 320: return 67
        case 179, 227, 323, 326: return 71
        case 329, 332: return 73
        case 230, 335, 338: return 75
        case 350: return 77
        case 353: return 80
        case 356: return 81
        case 359: return 82
        case 362, 368, 374: return 85
        case 365, 371, 377: return 86
        case 200, 386, 389, 392, 395: return 95
        default: return 3
        }
    }
}