import CharlCore
import CharlPlatform
import Combine
import Foundation

/// 万年历模块：弹窗每次打开回到今天；日程首次进入才授权拉取（懒加载）。
public final class CalendarModuleModel: ObservableObject {
    @Published public private(set) var month: CalendarMonthModel
    @Published public private(set) var selectedDay: Day
    @Published public private(set) var events: [CalendarEvent] = []
    @Published public private(set) var accessGranted: Bool
    @Published public private(set) var accessDenied = false
    @Published public private(set) var weekStartsOnMonday: Bool
    @Published public private(set) var weather: WeatherInfo?

    public private(set) var holidays: HolidayCalendar
    private let service: CalendarEventsService

    public init(service: CalendarEventsService, holidays: HolidayCalendar, weekStartsOnMonday: Bool) {
        self.service = service
        self.holidays = holidays
        self.weekStartsOnMonday = weekStartsOnMonday
        let today = Day.today()
        month = CalendarMonthModel(year: today.year, month: today.month, weekStartsOnMonday: weekStartsOnMonday, holidays: holidays)
        selectedDay = today
        accessGranted = service.hasAccess()
    }

    public var almanac: Almanac { Almanac(day: selectedDay, holidays: holidays) }

    /// 下一个节日：core 已按语言给出显示名称；界面层的 `AlmanacNames.festival` 对已翻译名称是幂等的。
    public var countdown: (name: String, days: Int)? {
        Countdown.next(after: Day.today(), holidays: holidays)
    }

    public func updateWeekStart(_ mondayFirst: Bool) {
        guard mondayFirst != weekStartsOnMonday else { return }
        weekStartsOnMonday = mondayFirst
        rebuild(year: month.year, month: month.month)
    }

    public func updateHolidays(_ calendar: HolidayCalendar) {
        holidays = calendar
        rebuild(year: month.year, month: month.month)
    }

    public func updateWeather(_ info: WeatherInfo?) {
        weather = info
    }

    public func onOpen() {
        goToday()
        if accessGranted {
            Task { await loadMonthEvents() }
        }
    }

    public func requestAccess() {
        Task { await ensureAccessAndLoad() }
    }

    public func goToday() {
        let today = Day.today()
        selectedDay = today
        rebuild(year: today.year, month: today.month)
    }

    public func shiftMonth(_ delta: Int) {
        let next = month.shifted(by: delta, holidays: holidays)
        guard (1900...2100).contains(next.year) else { return }
        month = next
        let lastDay = Day(year: month.year, month: month.month + 1, day: 1).addingDays(-1).day
        let number = month.year == 1900 && month.month == 1 ? 31 : min(selectedDay.day, lastDay)
        selectedDay = Day(year: month.year, month: month.month, day: number)
        reloadEvents()
    }

    public func jump(year: Int, month monthNumber: Int) {
        guard (1900...2100).contains(year), (1...12).contains(monthNumber) else { return }
        let lastDay = Day(year: year, month: monthNumber + 1, day: 1).addingDays(-1).day
        let number = year == 1900 && monthNumber == 1 ? 31 : min(selectedDay.day, lastDay)
        selectedDay = Day(year: year, month: monthNumber, day: number)
        rebuild(year: year, month: monthNumber)
    }

    public func select(_ day: Day) {
        guard (1900...2100).contains(day.year), LunarCalendar.lunarDate(from: day) != nil else { return }
        selectedDay = day
        if day.year != month.year || day.month != month.month {
            rebuild(year: day.year, month: day.month)
        }
    }

    public func moveSelection(days: Int) {
        select(selectedDay.addingDays(days))
    }

    public func events(on day: Day) -> [CalendarEvent] {
        let start = day.date()
        let end = day.addingDays(1).date()
        return events
            .filter { $0.startDate < end && $0.endDate > start }
            .sorted { $0.startDate < $1.startDate }
    }

    private func rebuild(year: Int, month monthNumber: Int) {
        month = CalendarMonthModel(year: year, month: monthNumber, weekStartsOnMonday: weekStartsOnMonday, holidays: holidays)
        reloadEvents()
    }

    private func reloadEvents() {
        guard accessGranted else { return }
        Task { await loadMonthEvents() }
    }

    @MainActor
    private func ensureAccessAndLoad() async {
        if !accessGranted {
            accessGranted = await service.requestAccess()
            accessDenied = !accessGranted
        }
        await loadMonthEvents()
    }

    @MainActor
    private func loadMonthEvents() async {
        guard accessGranted, let first = month.weeks.first?.first?.day, let last = month.weeks.last?.last?.day else {
            events = []
            return
        }
        do {
            events = try await service.events(from: first.date(), to: last.addingDays(1).date())
        } catch {
            events = []
        }
    }
}
