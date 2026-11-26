import Foundation

public enum RelativeTime {
    public static func string(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return loc("刚刚", "Just now") }
        if seconds < 3600 {
            let n = Int(seconds / 60)
            return loc("\(n) 分钟前", n == 1 ? "1 min ago" : "\(n) min ago")
        }
        if seconds < 86400 {
            let n = Int(seconds / 3600)
            return loc("\(n) 小时前", n == 1 ? "1 hour ago" : "\(n) hours ago")
        }
        if seconds < 172800 { return loc("昨天", "Yesterday") }

        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let nowComps = calendar.dateComponents([.year], from: now)
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        if Lang.isEnglish {
            let label = "\(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][max(0, month - 1)]) \(day)"
            return comps.year == nowComps.year ? label : "\(label), \(comps.year ?? 0)"
        }
        if comps.year == nowComps.year {
            return "\(month)-\(day)"
        }
        return "\(comps.year ?? 0)-\(month)-\(day)"
    }
}