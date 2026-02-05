import Foundation

// MARK: - Date Provider Protocol

protocol DateProvider {
    func now() -> Date
}

struct SystemDateProvider: DateProvider {
    func now() -> Date { Date() }
}

// MARK: - Market State

enum MarketState: String {
    case preMarket = "Pre-Market"
    case open = "Open"
    case afterHours = "After-Hours"
    case closed = "Closed"

    init(fromYahooState state: String?) {
        switch state?.uppercased() {
        case "PRE", "PREPRE": self = .preMarket
        case "REGULAR": self = .open
        case "POST", "POSTPOST": self = .afterHours
        default: self = .closed
        }
    }
}

// MARK: - Market Holiday

struct MarketHoliday {
    let date: Date
    let name: String
    let earlyClose: Bool

    init(date: Date, name: String, earlyClose: Bool = false) {
        self.date = date
        self.name = name
        self.earlyClose = earlyClose
    }
}

// MARK: - Market Schedule Display Strings

enum MarketScheduleStrings {
    static let preMarketSchedule = "4:00 AM - 9:30 AM ET"
    static let regularSchedule = "9:30 AM - 4:00 PM ET"
    static let earlyCloseSchedule = "9:30 AM - 1:00 PM ET"
    static let afterHoursSchedule = "4:00 PM - 8:00 PM ET"
}

// MARK: - Market Schedule

class MarketSchedule {
    static let shared = MarketSchedule()
    static let easternTimeZone = TimeZone(identifier: "America/New_York")!

    private let dateProvider: DateProvider
    private let calendar: Calendar

    init(dateProvider: DateProvider = SystemDateProvider()) {
        self.dateProvider = dateProvider
        var cal = Calendar.current
        cal.timeZone = MarketSchedule.easternTimeZone
        self.calendar = cal
    }

    // MARK: - Public Methods

    func getTodaySchedule() -> (state: MarketState, schedule: String, holidayName: String?) {
        let now = dateProvider.now()

        if isWeekend(now) {
            return (.closed, "Closed - Weekend", nil)
        }

        let year = calendar.component(.year, from: now)
        let holidays = getHolidaysForYear(year)

        guard let holiday = holidays.first(where: { calendar.isDate($0.date, inSameDayAs: now) }) else {
            let state = calculateMarketState(now: now, earlyClose: false)
            return (state, scheduleString(for: state, earlyClose: false), nil)
        }

        if holiday.earlyClose {
            let state = calculateMarketState(now: now, earlyClose: true)
            return (state, scheduleString(for: state, earlyClose: true), holiday.name)
        }

        return (.closed, "Closed", holiday.name)
    }

    private func scheduleString(for state: MarketState, earlyClose: Bool) -> String {
        switch state {
        case .preMarket:
            return MarketScheduleStrings.preMarketSchedule
        case .open:
            return earlyClose ? MarketScheduleStrings.earlyCloseSchedule : MarketScheduleStrings.regularSchedule
        case .afterHours:
            return MarketScheduleStrings.afterHoursSchedule
        case .closed:
            return earlyClose ? MarketScheduleStrings.earlyCloseSchedule : MarketScheduleStrings.regularSchedule
        }
    }

    func getNextHoliday() -> MarketHoliday? {
        let now = dateProvider.now()
        let year = calendar.component(.year, from: now)
        let allHolidays = getHolidaysForYear(year) + getHolidaysForYear(year + 1)
        return allHolidays.first { $0.date > now && !$0.earlyClose }
    }

    // MARK: - Holiday Calculation

    func getHolidaysForYear(_ year: Int) -> [MarketHoliday] {
        var holidays: [MarketHoliday] = []

        // Fixed holidays with observation rules
        holidays += observedHoliday(month: 1, day: 1, year: year, name: "New Year's Day")
        holidays += observedHoliday(month: 6, day: 19, year: year, name: "Juneteenth")
        holidays += observedHoliday(month: 7, day: 4, year: year, name: "Independence Day")
        holidays += observedHoliday(month: 12, day: 25, year: year, name: "Christmas Day")

        // Floating holidays
        if let date = nthWeekday(nth: 3, weekday: .monday, month: 1, year: year) {
            holidays.append(MarketHoliday(date: date, name: "Martin Luther King Jr. Day"))
        }
        if let date = nthWeekday(nth: 3, weekday: .monday, month: 2, year: year) {
            holidays.append(MarketHoliday(date: date, name: "Presidents' Day"))
        }
        if let date = calculateGoodFriday(year: year) {
            holidays.append(MarketHoliday(date: date, name: "Good Friday"))
        }
        if let date = lastWeekday(.monday, month: 5, year: year) {
            holidays.append(MarketHoliday(date: date, name: "Memorial Day"))
        }
        if let date = nthWeekday(nth: 1, weekday: .monday, month: 9, year: year) {
            holidays.append(MarketHoliday(date: date, name: "Labor Day"))
        }
        if let date = nthWeekday(nth: 4, weekday: .thursday, month: 11, year: year) {
            holidays.append(MarketHoliday(date: date, name: "Thanksgiving Day"))
        }

        // Early close days
        if let earlyClose = earlyCloseBeforeJuly4(year: year) {
            holidays.append(earlyClose)
        }
        if let thanksgiving = nthWeekday(nth: 4, weekday: .thursday, month: 11, year: year),
           let blackFriday = calendar.date(byAdding: .day, value: 1, to: thanksgiving) {
            holidays.append(MarketHoliday(date: blackFriday, name: "Day After Thanksgiving", earlyClose: true))
        }
        if let earlyClose = earlyCloseChristmasEve(year: year) {
            holidays.append(earlyClose)
        }

        // Special closures
        if year == 2025 {
            holidays.append(MarketHoliday(date: makeDate(month: 1, day: 9, year: 2025)!, name: "National Day of Mourning"))
        }

        return holidays.sorted { $0.date < $1.date }
    }

    // MARK: - Private Helpers

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private func calculateMarketState(now: Date, earlyClose: Bool) -> MarketState {
        let currentMinutes = minutesSinceMidnight(now)
        let closeMinutes = earlyClose ? TradingHours.earlyClose : TradingHours.marketClose

        if currentMinutes < TradingHours.preMarketOpen { return .closed }
        if currentMinutes < TradingHours.marketOpen { return .preMarket }
        if currentMinutes < closeMinutes { return .open }
        if !earlyClose && currentMinutes < TradingHours.afterHoursClose { return .afterHours }
        return .closed
    }

    private func minutesSinceMidnight(_ date: Date) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return hour * 60 + minute
    }

    private func makeDate(month: Int, day: Int, year: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = MarketSchedule.easternTimeZone
        return calendar.date(from: components)
    }

    private enum Weekday: Int {
        case sunday = 1, monday = 2, tuesday = 3, wednesday = 4
        case thursday = 5, friday = 6, saturday = 7
    }

    private func nthWeekday(nth: Int, weekday: Weekday, month: Int, year: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday.rawValue
        components.weekdayOrdinal = nth
        components.timeZone = MarketSchedule.easternTimeZone
        return calendar.date(from: components)
    }

    private func lastWeekday(_ weekday: Weekday, month: Int, year: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday.rawValue
        components.weekdayOrdinal = -1
        components.timeZone = MarketSchedule.easternTimeZone
        return calendar.date(from: components)
    }

    private func observedHoliday(month: Int, day: Int, year: Int, name: String) -> [MarketHoliday] {
        guard let date = makeDate(month: month, day: day, year: year) else { return [] }

        let weekday = calendar.component(.weekday, from: date)

        switch weekday {
        case 1: // Sunday -> Monday
            if let observed = calendar.date(byAdding: .day, value: 1, to: date) {
                return [MarketHoliday(date: observed, name: "\(name) (Observed)")]
            }
        case 7: // Saturday -> Friday
            if let observed = calendar.date(byAdding: .day, value: -1, to: date) {
                return [MarketHoliday(date: observed, name: "\(name) (Observed)")]
            }
        default:
            return [MarketHoliday(date: date, name: name)]
        }
        return []
    }

    private func calculateGoodFriday(year: Int) -> Date? {
        // Anonymous Gregorian Easter algorithm - variable names match standard mathematical notation
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1

        guard let easterSunday = makeDate(month: month, day: day, year: year) else { return nil }
        return calendar.date(byAdding: .day, value: -2, to: easterSunday)
    }

    private func earlyCloseBeforeJuly4(year: Int) -> MarketHoliday? {
        guard let july4 = makeDate(month: 7, day: 4, year: year) else { return nil }

        let weekday = calendar.component(.weekday, from: july4)

        // Early close July 3rd only if July 4th is Tue-Fri (weekday 3-6)
        if (3...6).contains(weekday), let july3 = makeDate(month: 7, day: 3, year: year) {
            return MarketHoliday(date: july3, name: "Day Before Independence Day", earlyClose: true)
        }
        return nil
    }

    private func earlyCloseChristmasEve(year: Int) -> MarketHoliday? {
        guard let dec24 = makeDate(month: 12, day: 24, year: year),
              let dec25 = makeDate(month: 12, day: 25, year: year) else { return nil }

        let dec24Weekday = calendar.component(.weekday, from: dec24)
        let dec25Weekday = calendar.component(.weekday, from: dec25)

        // Early close if Dec 24 is Mon-Fri and Christmas isn't Saturday (observed on Dec 24)
        if (2...6).contains(dec24Weekday) && dec25Weekday != 7 {
            return MarketHoliday(date: dec24, name: "Christmas Eve", earlyClose: true)
        }
        return nil
    }
}
