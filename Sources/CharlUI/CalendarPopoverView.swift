import CharlCore
import SwiftUI

struct CalendarPopoverView: View {
    @ObservedObject var model: CalendarModuleModel
    var palette: CalendarPalette = .mist
    var customAccent: Color? = nil
    var onContentChange: (() -> Void)? = nil
    var fontSize: Double = 13

    @FocusState private var focused: Bool
    @State private var showDetail: Bool

    init(model: CalendarModuleModel, palette: CalendarPalette = .mist, customAccent: Color? = nil, onContentChange: (() -> Void)? = nil, fontSize: Double = 13, expanded: Bool = false) {
        self.model = model
        self.palette = palette
        self.customAccent = customAccent
        self.onContentChange = onContentChange
        self.fontSize = fontSize
        _showDetail = State(initialValue: expanded)
    }

    private var s: CGFloat { CGFloat(fontSize) / 13.0 }

    private var layoutSignature: String {
        let countdown = model.countdown.map { "\($0.name)\($0.days)" } ?? "-"
        return [
            String(showDetail),
            String(model.month.year), String(model.month.month), String(model.month.weeks.count),
            String(model.selectedDay.year), String(model.selectedDay.month), String(model.selectedDay.day),
            String(model.events.count), String(model.accessGranted), countdown, String(fontSize),
        ].joined(separator: "|")
    }

    private var accent: Color {
        palette == .custom ? (customAccent ?? palette.accent) : palette.accent
    }

    private var todayFill: Color {
        palette == .custom ? accent : palette.todayFill
    }

    private var todayText: Color {
        palette == .custom ? .white : palette.todayText
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            weatherRow
            weekdayRow
            grid
            if showDetail {
                Hairline().padding(.horizontal, 14)
                detail
                    .transition(.opacity)
            }
        }
        .frame(width: 320 * s)
        .background(Color.clear)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.leftArrow) { model.moveSelection(days: -1); return .handled }
        .onKeyPress(.rightArrow) { model.moveSelection(days: 1); return .handled }
        .onKeyPress(.upArrow) { model.moveSelection(days: -7); return .handled }
        .onKeyPress(.downArrow) { model.moveSelection(days: 7); return .handled }
        .onKeyPress(.pageUp) { showDetail = false; model.shiftMonth(-1); onContentChange?(); return .handled }
        .onKeyPress(.pageDown) { showDetail = false; model.shiftMonth(1); onContentChange?(); return .handled }
        .onKeyPress("t") { showDetail = false; model.goToday(); onContentChange?(); return .handled }
        .onChange(of: layoutSignature) { _, _ in onContentChange?() }
    }

    private var header: some View {
        let today = Day.today()
        let away = model.month.year != today.year || model.month.month != today.month
        return ZStack {
            Text(model.month.title)
                .font(.system(size: 17 * s, weight: .semibold))
                .foregroundStyle(Theme.label)
            HStack(spacing: 6) {
                ToolButton(symbol: "chevron.left", help: loc("上个月 (PageUp)", "Previous month (PageUp)"), size: 26) {
                    showDetail = false
                    model.shiftMonth(-1)
                    onContentChange?()
                }
                Spacer(minLength: 0)
                if away {
                    Button {
                        showDetail = false
                        model.goToday()
                        onContentChange?()
                    } label: {
                        Text(loc("今天", "Today"))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(accent.opacity(0.16)))
                    }
                    .buttonStyle(.plain)
                    .help(loc("回到今天 (T)", "Back to today (T)"))
                }
                ToolButton(symbol: "chevron.right", help: loc("下个月 (PageDown)", "Next month (PageDown)"), size: 26) {
                    showDetail = false
                    model.shiftMonth(1)
                    onContentChange?()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var weatherRow: some View {
        if let weather = model.weather {
            HStack(spacing: 7) {
                Image(systemName: WeatherCondition.symbol(code: weather.code))
                    .font(.system(size: 14 * s))
                    .foregroundStyle(accent)
                Text(WeatherCondition.text(code: weather.code))
                    .font(.system(size: 11.5 * s, weight: .medium))
                    .foregroundStyle(Theme.label)
                Text(weather.city)
                    .font(.system(size: 10 * s))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("\(Int(weather.temperature.rounded()))°")
                    .font(.system(size: 15 * s, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.label)
                if let high = weather.high, let low = weather.low {
                    HStack(spacing: 4) {
                        Text("↑\(Int(high.rounded()))°")
                        Text("↓\(Int(low.rounded()))°")
                    }
                    .font(.system(size: 10 * s, design: .rounded))
                    .foregroundStyle(Theme.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.secondary.opacity(0.08)))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(model.month.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 10.5 * s, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var grid: some View {
        VStack(spacing: 2) {
            ForEach(Array(model.month.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 2) {
                    ForEach(week) { cell in
                        DayCellView(
                            cell: cell,
                            accent: accent,
                            todayFill: todayFill,
                            todayText: todayText,
                            isToday: cell.day == Day.today(),
                            isSelected: cell.day == model.selectedDay,
                            hasEvents: !model.events(on: cell.day).isEmpty,
                            s: s
                        )
                        .onTapGesture { toggleDetail(cell.day) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { toggleDetail(cell.day) }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
    }

    private func toggleDetail(_ day: Day) {
        let alreadyOpen = showDetail && model.selectedDay == day
        model.select(day)
        showDetail = !alreadyOpen
        onContentChange?()
    }

    private var detail: some View {
        let almanac = model.almanac
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(dayTitle(almanac.day, weekdayName: almanac.weekdayName))
                    .font(.system(size: 13 * s, weight: .semibold))
                    .foregroundStyle(Theme.label)
                Spacer(minLength: 6)
                if let countdown = model.countdown {
                    HStack(spacing: 3) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 8.5 * s))
                        Text(countdownText(countdown))
                            .font(.system(size: 10 * s, weight: .medium))
                    }
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .fixedSize()
                } else {
                    Text(loc("第 \(almanac.isoWeek) 周", "Week \(almanac.isoWeek)"))
                        .font(.system(size: 9.5 * s))
                        .foregroundStyle(Theme.tertiary)
                }
                ToolButton(symbol: "xmark", help: loc("收起详情", "Hide details"), size: 20) { showDetail = false }
            }

            Text(lunarLine(almanac))
                .font(.system(size: 10 * s))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            if let festivalChips = chips(almanac) {
                festivalChips
            }

            eventsSection
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    /// 「距 X N 天」：英文整句重写为「X in N days」，days == 1 用单数。
    /// 名称来源兼容两种情况：`Countdown.next` 已按语言给值（festival() 幂等），UI 层回退值仍是中文原文。
    private func countdownText(_ countdown: (name: String, days: Int)) -> String {
        let displayName = AlmanacNames.festival(countdown.name)
        return loc("距\(displayName) \(countdown.days) 天",
                   "\(displayName) in \(countdown.days) day\(countdown.days == 1 ? "" : "s")")
    }

    /// 农历 / 干支 / 生肖详情行：core 的字段已按语言给值，这里只组织标签词。
    private func lunarLine(_ almanac: Almanac) -> String {
        // 三柱按年/月/日顺序，用 Y/M/D 标位；生肖已含在年柱英文里（Fire Horse），不再重复。
        let english = "Lunar \(almanac.lunarMonthDay) · Y \(almanac.ganZhiYear) · M \(almanac.ganZhiMonth) · D \(almanac.ganZhiDay)"
        return loc("农历 \(almanac.lunarMonthDay) · \(almanac.ganZhiYear)年 \(almanac.ganZhiMonth)月 \(almanac.ganZhiDay)日 · 属\(almanac.zodiac)", english)
    }

    /// 详情标题：core 已给 weekdayName，这里只组织「X月X日 · 星期X」/「18 November · Wednesday」。
    private func dayTitle(_ day: Day, weekdayName: String) -> String {
        let english = "\(day.day) \(AlmanacNames.monthsEN[day.month - 1]) · \(weekdayName)"
        return loc("\(day.month)月\(day.day)日 · \(weekdayName)", english)
    }

    private func chips(_ almanac: Almanac) -> AnyView? {
        var items: [(String, Color)] = []
        // 法定节假日的原始中文名，用于与传统节日 chip 去重（两边都转成显示文案再比较）。
        var offName: String? = nil
        if case .off(let name) = almanac.holiday {
            offName = name
            items.append((loc("休 · \(AlmanacNames.festival(name))", "Off · \(AlmanacNames.festival(name))"), Theme.holidaySoft))
        } else if almanac.holiday == .work {
            items.append((loc("调休上班", "Make-up workday"), Theme.workday))
        }
        for festival in almanac.festivals.prefix(2) {
            if let offName, festival == AlmanacNames.festival(offName) { continue }
            items.append((festival, Theme.holidaySoft))
        }
        if let term = almanac.termName, !almanac.festivals.contains(term) {
            items.append((term, Theme.termSoft))
        }
        guard !items.isEmpty else { return nil }
        return AnyView(
            HStack(spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Chip(text: item.0, tint: item.1)
                }
                Spacer(minLength: 0)
            }
        )
    }

    @ViewBuilder
    private var eventsSection: some View {
        if !model.accessGranted {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.accent)
                if model.accessDenied {
                    Text(loc("日历权限已关闭，请在系统设置中开启", "Calendar access is off — enable it in System Settings"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.secondary)
                } else {
                    Button(loc("接入系统日历", "Connect Calendar")) { model.requestAccess() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(palette.accent)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 1)
        } else {
            let dayEvents = model.events(on: model.selectedDay)
            if dayEvents.isEmpty {
                HStack(spacing: 5) {
                    Circle().fill(Theme.tertiary.opacity(0.5)).frame(width: 3, height: 3)
                    Text(loc("这一天没有日程", "No events"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.tertiary)
                    Spacer(minLength: 0)
                }
                .padding(.top, 1)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(dayEvents.prefix(3)) { event in
                        EventRow(event: event, s: s)
                    }
                    if dayEvents.count > 3 {
                        Text(loc("另有 \(dayEvents.count - 3) 项日程", "+\(dayEvents.count - 3) more"))
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.tertiary)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

}

private struct DayCellView: View {
    let cell: CalendarDayCell
    let accent: Color
    let todayFill: Color
    let todayText: Color
    let isToday: Bool
    let isSelected: Bool
    let hasEvents: Bool
    let s: CGFloat

    @State private var hovering = false

    private var isOff: Bool {
        if case .off = cell.holiday { return true }
        return false
    }

    private var numberColor: Color {
        if isToday { return todayText }
        if isSelected { return accent }
        if cell.isWeekend { return Theme.secondary }
        return Theme.label
    }

    private var labelColor: Color {
        if isToday { return accent }
        if cell.isFestivalLabel { return Theme.holidaySoft }
        if cell.termName != nil { return Theme.termSoft }
        return Theme.secondary
    }

    var body: some View {
        VStack(spacing: 1) {
            Text("\(cell.day.day)")
                .font(.system(size: 13.5 * s, weight: isToday || isSelected ? .semibold : .medium))
                .foregroundStyle(numberColor)
                .frame(width: 24 * s, height: 24 * s)
                .background(Circle().fill(isToday ? todayFill : .clear))
            Text(cell.lunarLabel)
                .font(.system(size: 8.5 * s))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(labelColor)
                .frame(height: 10 * s)
            Circle()
                .fill(hasEvents ? accent : .clear)
                .frame(width: 2.5 * s, height: 2.5 * s)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40 * s)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(isSelected && !isToday ? Theme.selected : (hovering ? Theme.hover : .clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(isSelected ? accent.opacity(isToday ? 0.35 : 0.65) : .clear, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) { badge }
        .opacity(cell.inMonth ? 1 : 0.32)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(Theme.motion(.easeOut(duration: 0.1)), value: hovering)
    }

    @ViewBuilder
    private var badge: some View {
        if isOff {
            badgeText(loc("休", "Off"), color: Theme.holidaySoft)
        } else if cell.holiday == .work {
            badgeText(loc("班", "Work"), color: Theme.workday)
        }
    }

    private func badgeText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 7.5 * s, weight: .semibold))
            .foregroundStyle(color)
            .padding(.top, 2)
            .padding(.trailing, 3)
    }
}

private struct EventRow: View {
    let event: CalendarEvent
    let s: CGFloat

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var timeText: String {
        event.isAllDay ? loc("全天", "All day") : "\(Self.formatter.string(from: event.startDate))–\(Self.formatter.string(from: event.endDate))"
    }

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(hex: event.colorHex))
                .frame(width: 3 * s, height: 13 * s)
            Text(event.title)
                .font(.system(size: 11 * s, weight: .medium))
                .foregroundStyle(Theme.label)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Text(timeText)
                .font(.system(size: 9.5 * s, design: .rounded))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(height: 17 * s)
        .help("\(event.title) · \(event.calendarTitle)")
    }
}
