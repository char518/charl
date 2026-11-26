import CharlCore
import Foundation

/// 远程公开信息（天气 / 法定假日）。仅出站请求、无密钥、不上传个人数据。
/// macOS 实现：IP 定位 ipwho.is/ipapi.co，天气 wttr.in/Open-Meteo，假日 holiday-cn（gov.cn 通知镜像）；
/// 失败返回 nil，由调用方回退缓存或内置数据。
public protocol RemoteInfoService: AnyObject {
    func fetchWeather() async -> WeatherInfo?
    func fetchHolidays(year: Int) async -> HolidayYear?
}