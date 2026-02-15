import XCTest
@testable import StockTicker

@MainActor
final class TimerManagerTests: XCTestCase {

    private var timerManager: TimerManager!
    private var delegate: MockTimerDelegate!

    override func setUp() {
        super.setUp()
        timerManager = TimerManager()
        delegate = MockTimerDelegate()
        timerManager.delegate = delegate
    }

    override func tearDown() {
        timerManager.stopTimers()
        timerManager.stopHighlightTimer()
        timerManager = nil
        delegate = nil
        super.tearDown()
    }

    // MARK: - Start/Stop Tests

    func testStartTimers_triggersInitialCountdownTick() {
        timerManager.startTimers(cycleInterval: 5, refreshInterval: 15, newsEnabled: false, newsInterval: 300)
        XCTAssertEqual(delegate.countdownTickCount, 1)
    }

    func testStopTimers_preventsSubsequentTicks() {
        timerManager.startTimers(cycleInterval: 5, refreshInterval: 15, newsEnabled: false, newsInterval: 300)
        timerManager.stopTimers()

        let initialCount = delegate.countdownTickCount
        // Wait briefly to confirm no more ticks
        let expectation = expectation(description: "no more ticks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(delegate.countdownTickCount, initialCount)
    }

    func testStartTimers_withNewsEnabled_createsNewsTimer() {
        timerManager.startTimers(cycleInterval: 5, refreshInterval: 15, newsEnabled: true, newsInterval: 300)
        // No crash, timer created successfully
        timerManager.stopTimers()
    }

    func testStartTimers_withNewsDisabled_noNewsTimer() {
        timerManager.startTimers(cycleInterval: 5, refreshInterval: 15, newsEnabled: false, newsInterval: 300)
        // No crash, news timer not created
        timerManager.stopTimers()
    }

    // MARK: - Highlight Timer Tests

    func testStartHighlightTimer_canBeStoppedCleanly() {
        timerManager.startHighlightTimer()
        timerManager.stopHighlightTimer()
        // No crash, timer started and stopped cleanly
    }

    func testStartHighlightTimer_calledTwice_replacesTimer() {
        timerManager.startHighlightTimer()
        timerManager.startHighlightTimer()
        timerManager.stopHighlightTimer()
        // No crash, second call replaces first timer
    }

    func testStopHighlightTimer_whenNotStarted_doesNotCrash() {
        timerManager.stopHighlightTimer()
        // No crash when stopping a timer that was never started
    }

    // MARK: - Delegate Callbacks

    func testHighlightTimer_firesDelegate() {
        timerManager.startHighlightTimer()

        let expectation = expectation(description: "highlight tick")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertGreaterThan(delegate.highlightTickCount, 0)
        timerManager.stopHighlightTimer()
    }

    func testCountdownTimer_firesDelegate() {
        timerManager.startTimers(cycleInterval: 60, refreshInterval: 60, newsEnabled: false, newsInterval: 300)

        // Initial tick happens synchronously
        XCTAssertEqual(delegate.countdownTickCount, 1)

        let expectation = expectation(description: "countdown tick")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertGreaterThan(delegate.countdownTickCount, 1)
        timerManager.stopTimers()
    }
}

// MARK: - Mock Timer Delegate

@MainActor
private class MockTimerDelegate: TimerManagerDelegate {
    var cycleTickCount = 0
    var refreshTickCount = 0
    var countdownTickCount = 0
    var scheduleRefreshTickCount = 0
    var newsRefreshTickCount = 0
    var highlightTickCount = 0
    var midnightTickCount = 0

    func timerManagerCycleTick() { cycleTickCount += 1 }
    func timerManagerRefreshTick() async { refreshTickCount += 1 }
    func timerManagerCountdownTick() { countdownTickCount += 1 }
    func timerManagerScheduleRefreshTick() { scheduleRefreshTickCount += 1 }
    func timerManagerNewsRefreshTick() async { newsRefreshTickCount += 1 }
    func timerManagerHighlightTick() { highlightTickCount += 1 }
    func timerManagerMidnightTick() { midnightTickCount += 1 }
}
