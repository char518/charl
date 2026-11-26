import Foundation

/// 二十四节气：按太阳视黄经（Meeus 低精度公式，误差约 0.01°）求解交节时刻，
/// 不依赖外部历表数据；日期按东八区取日。
public enum SolarTerms {
    /// 索引 0 = 小寒 … 23 = 冬至（按公历一年内的先后顺序）。
    public static let names = [
        "小寒", "大寒", "立春", "雨水", "惊蛰", "春分",
        "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
        "小暑", "大暑", "立秋", "处暑", "白露", "秋分",
        "寒露", "霜降", "立冬", "小雪", "大雪", "冬至",
    ]

    static let longitudes: [Double] = [
        285, 300, 315, 330, 345, 0,
        15, 30, 45, 60, 75, 90,
        105, 120, 135, 150, 165, 180,
        195, 210, 225, 240, 255, 270,
    ]

    /// 节气显示文案：英文模式给出通行的英文名，未收录的名称保持原文。
    public static func display(_ name: String?) -> String? {
        name.map(AlmanacNames.solarTerm)
    }

    /// 日历格子用的紧凑版。
    static func cellDisplay(_ name: String?) -> String? {
        name.map(AlmanacNames.solarTermCell)
    }

    private static var cache: [Int: [Day: String]] = [:]

    /// 某公历年内全部节气：日期 → 节气名。
    public static func termMap(year: Int) -> [Day: String] {
        if let cached = cache[year] { return cached }
        var map: [Day: String] = [:]
        for index in 0..<24 {
            map[termDay(year: year, index: index)] = names[index]
        }
        cache[year] = map
        return map
    }

    public static func termDay(year: Int, index: Int) -> Day {
        let jde = findTermJDE(year: year, target: longitudes[index])
        let date = Date(timeIntervalSince1970: (jde - 2_440_587.5) * 86400)
        return Day(date: date)
    }

    /// 太阳视黄经（度），Meeus《天文算法》25 章低精度式。
    static func solarLongitude(jde: Double) -> Double {
        let t = (jde - 2_451_545.0) / 36525
        let l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
        let m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
        let mRad = m * .pi / 180
        let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(mRad)
            + (0.019993 - 0.000101 * t) * sin(2 * mRad)
            + 0.000289 * sin(3 * mRad)
        let trueLong = l0 + c
        let omega = 125.04 - 1934.136 * t
        let apparent = trueLong - 0.00569 - 0.00478 * sin(omega * .pi / 180)
        return apparent.truncatingRemainder(dividingBy: 360) + (apparent < 0 ? 360 : 0)
    }

    /// 在给定公历年内扫描视黄经与目标黄经的交点，再二分至秒级。
    static func findTermJDE(year: Int, target: Double) -> Double {
        func delta(_ jde: Double) -> Double {
            var d = solarLongitude(jde: jde) - target
            if d > 180 { d -= 360 }
            if d < -180 { d += 360 }
            return d
        }

        let start = Double(Day(year: year, month: 1, day: 1).epochDay) + 2_440_587.5
        var previous = delta(start)
        var lo = start
        for dayOffset in 1...366 {
            let jde = start + Double(dayOffset)
            let current = delta(jde)
            if previous < 0 && current >= 0 {
                lo = jde - 1
                var hi = jde
                for _ in 0..<40 {
                    let mid = (lo + hi) / 2
                    if delta(mid) < 0 { lo = mid } else { hi = mid }
                }
                return (lo + hi) / 2
            }
            previous = current
        }
        return start
    }
}