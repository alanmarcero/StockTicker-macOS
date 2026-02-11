import XCTest
@testable import StockTicker

// MARK: - MarketState Tests

final class MarketStateTests: XCTestCase {

    func testInit_regularState_returnsOpen() {
        XCTAssertEqual(MarketState(fromYahooState: "REGULAR"), .open)
    }

    func testInit_preState_returnsPreMarket() {
        XCTAssertEqual(MarketState(fromYahooState: "PRE"), .preMarket)
    }

    func testInit_prepreState_returnsPreMarket() {
        XCTAssertEqual(MarketState(fromYahooState: "PREPRE"), .preMarket)
    }

    func testInit_postState_returnsAfterHours() {
        XCTAssertEqual(MarketState(fromYahooState: "POST"), .afterHours)
    }

    func testInit_postpostState_returnsAfterHours() {
        XCTAssertEqual(MarketState(fromYahooState: "POSTPOST"), .afterHours)
    }

    func testInit_nilState_returnsClosed() {
        XCTAssertEqual(MarketState(fromYahooState: nil), .closed)
    }

    func testInit_unknownState_returnsClosed() {
        XCTAssertEqual(MarketState(fromYahooState: "UNKNOWN"), .closed)
    }

    func testRawValue_correctStrings() {
        XCTAssertEqual(MarketState.preMarket.rawValue, "Pre-Market")
        XCTAssertEqual(MarketState.open.rawValue, "Open")
        XCTAssertEqual(MarketState.afterHours.rawValue, "After-Hours")
        XCTAssertEqual(MarketState.closed.rawValue, "Closed")
    }
}

// MARK: - MarketSchedule Tests

final class MarketScheduleTests: XCTestCase {

    private let eastern = MarketSchedule.easternTimeZone

    // MARK: - Weekend tests

    func testGetTodaySchedule_saturday_returnsClosed() {
        // January 4, 2025 is a Saturday
        let dateProvider = MockDateProvider(year: 2025, month: 1, day: 4, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, scheduleText, holiday) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .closed)
        XCTAssertEqual(scheduleText, "Closed - Weekend")
        XCTAssertNil(holiday)
    }

    func testGetTodaySchedule_sunday_returnsClosed() {
        // January 5, 2025 is a Sunday
        let dateProvider = MockDateProvider(year: 2025, month: 1, day: 5, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, scheduleText, holiday) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .closed)
        XCTAssertEqual(scheduleText, "Closed - Weekend")
        XCTAssertNil(holiday)
    }

    // MARK: - Regular trading day tests

    func testGetTodaySchedule_regularDay_beforePreMarket_returnsClosed() {
        // 3:00 AM ET on a Monday
        let dateProvider = MockDateProvider(year: 2025, month: 1, day: 6, hour: 3, minute: 0, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, _, _) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .closed)
    }

    func testGetTodaySchedule_regularDay_preMarket_returnsPreMarket() {
        // 5:00 AM ET on a Monday
        let dateProvider = MockDateProvider(year: 2025, month: 1, day: 6, hour: 5, minute: 0, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, _, _) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .preMarket)
    }

    func testGetTodaySchedule_regularDay_marketOpen_returnsOpen() {
        // 10:00 AM ET on a Monday
        let dateProvider = MockDateProvider(year: 2025, month: 1, day: 6, hour: 10, minute: 0, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, scheduleText, _) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .open)
        XCTAssertEqual(scheduleText, "9:30 AM - 4:00 PM ET")
    }

    func testGetTodaySchedule_regularDay_afterHours_returnsAfterHours() {
        // 5:00 PM ET on a Monday
        let dateProvider = MockDateProvider(year: 2025, month: 1, day: 6, hour: 17, minute: 0, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, _, _) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .afterHours)
    }

    func testGetTodaySchedule_regularDay_afterClose_returnsClosed() {
        // 9:00 PM ET on a Monday
        let dateProvider = MockDateProvider(year: 2025, month: 1, day: 6, hour: 21, minute: 0, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, _, _) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .closed)
    }

    // MARK: - Holiday tests

    func testGetTodaySchedule_newYearsDay_returnsClosed() {
        // January 1, 2025 (Wednesday)
        let dateProvider = MockDateProvider(year: 2025, month: 1, day: 1, hour: 12, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, scheduleText, holiday) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .closed)
        XCTAssertEqual(scheduleText, "Closed")
        XCTAssertEqual(holiday, "New Year's Day")
    }

    func testGetTodaySchedule_christmas_returnsClosed() {
        // December 25, 2025 (Thursday)
        let dateProvider = MockDateProvider(year: 2025, month: 12, day: 25, hour: 12, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, scheduleText, holiday) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .closed)
        XCTAssertEqual(scheduleText, "Closed")
        XCTAssertEqual(holiday, "Christmas Day")
    }

    func testGetTodaySchedule_mlkDay2025_returnsClosed() {
        // January 20, 2025 is MLK Day (3rd Monday of January)
        let dateProvider = MockDateProvider(year: 2025, month: 1, day: 20, hour: 12, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, _, holiday) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .closed)
        XCTAssertEqual(holiday, "Martin Luther King Jr. Day")
    }

    // MARK: - Early close tests

    func testGetTodaySchedule_blackFriday_returnsEarlyClose() {
        // November 28, 2025 is Black Friday (day after Thanksgiving)
        let dateProvider = MockDateProvider(year: 2025, month: 11, day: 28, hour: 12, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, scheduleText, holiday) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .open)
        XCTAssertEqual(scheduleText, "9:30 AM - 1:00 PM ET")
        XCTAssertEqual(holiday, "Day After Thanksgiving")
    }

    func testGetTodaySchedule_earlyCloseDay_afterClose_returnsClosed() {
        // Black Friday at 2:00 PM (after early close)
        let dateProvider = MockDateProvider(year: 2025, month: 11, day: 28, hour: 14, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let (state, _, _) = schedule.getTodaySchedule()

        XCTAssertEqual(state, .closed)
    }

    // MARK: - Holiday calculation tests

    func testGetHolidaysForYear_containsExpectedHolidays() {
        let schedule = MarketSchedule()
        let holidays = schedule.getHolidaysForYear(2025)

        let holidayNames = Set(holidays.map { $0.name })

        XCTAssertTrue(holidayNames.contains("New Year's Day"))
        XCTAssertTrue(holidayNames.contains("Martin Luther King Jr. Day"))
        XCTAssertTrue(holidayNames.contains("Presidents' Day"))
        XCTAssertTrue(holidayNames.contains("Good Friday"))
        XCTAssertTrue(holidayNames.contains("Memorial Day"))
        XCTAssertTrue(holidayNames.contains("Juneteenth"))
        XCTAssertTrue(holidayNames.contains("Independence Day"))
        XCTAssertTrue(holidayNames.contains("Labor Day"))
        XCTAssertTrue(holidayNames.contains("Thanksgiving Day"))
        XCTAssertTrue(holidayNames.contains("Christmas Day"))
    }

    func testGetHolidaysForYear_holidaysAreSorted() {
        let schedule = MarketSchedule()
        let holidays = schedule.getHolidaysForYear(2025)

        for i in 0..<holidays.count - 1 {
            XCTAssertLessThan(holidays[i].date, holidays[i + 1].date)
        }
    }

    func testGetHolidaysForYear_2025SpecialClosure() {
        let schedule = MarketSchedule()
        let holidays = schedule.getHolidaysForYear(2025)

        let mourningDay = holidays.first { $0.name == "National Day of Mourning" }
        XCTAssertNotNil(mourningDay)
    }

    // MARK: - Next holiday tests

    func testGetNextHoliday_returnsNextFullClosure() {
        // January 2, 2025
        let dateProvider = MockDateProvider(year: 2025, month: 1, day: 2, hour: 12, timeZone: eastern)
        let schedule = MarketSchedule(dateProvider: dateProvider)

        let nextHoliday = schedule.getNextHoliday()

        XCTAssertNotNil(nextHoliday)
        // Should skip early close days and return next full closure
        XCTAssertFalse(nextHoliday!.earlyClose)
    }

    // MARK: - Observed holiday tests

    func testGetHolidaysForYear_saturdayHoliday_observedOnFriday() {
        // July 4, 2026 falls on Saturday - should be observed on July 3
        let schedule = MarketSchedule()
        let holidays = schedule.getHolidaysForYear(2026)

        let july4 = holidays.first { $0.name.contains("Independence Day") && !$0.earlyClose }

        XCTAssertNotNil(july4)
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: MarketSchedule.easternTimeZone, from: july4!.date)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 3) // Observed on Friday
    }

    func testGetHolidaysForYear_sundayHoliday_observedOnMonday() {
        // January 1, 2028 falls on Saturday, so observed on Dec 31, 2027
        // But let's test July 4, 2027 which falls on Sunday
        let schedule = MarketSchedule()
        let holidays = schedule.getHolidaysForYear(2027)

        let july4 = holidays.first { $0.name.contains("Independence Day") && !$0.earlyClose }

        XCTAssertNotNil(july4)
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: MarketSchedule.easternTimeZone, from: july4!.date)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 5) // Observed on Monday
    }
}
