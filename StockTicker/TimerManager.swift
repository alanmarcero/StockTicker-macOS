import Foundation

// MARK: - Timer Manager Delegate

@MainActor
protocol TimerManagerDelegate: AnyObject {
    func timerManagerCycleTick()
    func timerManagerRefreshTick() async
    func timerManagerCountdownTick()
    func timerManagerScheduleRefreshTick()
    func timerManagerNewsRefreshTick() async
    func timerManagerHighlightTick()
    func timerManagerMidnightTick()
}

// MARK: - Timer Manager

@MainActor
class TimerManager {
    weak var delegate: TimerManagerDelegate?

    private var cycleTimer: Timer?
    private var refreshTimer: Timer?
    private var countdownTimer: Timer?
    private var scheduleRefreshTimer: Timer?
    private var highlightTimer: Timer?
    private var newsRefreshTimer: Timer?

    private enum Intervals {
        static let countdown: TimeInterval = 1.0
        static let scheduleRefresh: TimeInterval = 4 * 60 * 60  // 4 hours
        static let highlightFade: TimeInterval = 0.05
    }

    func startTimers(cycleInterval: Int, refreshInterval: Int, newsEnabled: Bool, newsInterval: Int) {
        cycleTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(cycleInterval), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.delegate?.timerManagerCycleTick() }
        }

        refreshTimer = createCommonModeTimer(interval: TimeInterval(refreshInterval)) { [weak self] in
            Task { @MainActor in await self?.delegate?.timerManagerRefreshTick() }
        }

        delegate?.timerManagerCountdownTick()
        countdownTimer = createCommonModeTimer(interval: Intervals.countdown) { [weak self] in
            DispatchQueue.main.async { self?.delegate?.timerManagerCountdownTick() }
        }

        scheduleRefreshTimer = Timer.scheduledTimer(withTimeInterval: Intervals.scheduleRefresh, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.delegate?.timerManagerScheduleRefreshTick() }
        }

        if newsEnabled {
            newsRefreshTimer = createCommonModeTimer(interval: TimeInterval(newsInterval)) { [weak self] in
                Task { @MainActor in await self?.delegate?.timerManagerNewsRefreshTick() }
            }
        }

        scheduleMidnightRefresh()
    }

    func stopTimers() {
        [cycleTimer, refreshTimer, countdownTimer, scheduleRefreshTimer, newsRefreshTimer].forEach { $0?.invalidate() }
        cycleTimer = nil
        refreshTimer = nil
        countdownTimer = nil
        scheduleRefreshTimer = nil
        newsRefreshTimer = nil
    }

    func startHighlightTimer() {
        highlightTimer?.invalidate()
        highlightTimer = createCommonModeTimer(interval: Intervals.highlightFade) { [weak self] in
            DispatchQueue.main.async { self?.delegate?.timerManagerHighlightTick() }
        }
    }

    func stopHighlightTimer() {
        highlightTimer?.invalidate()
        highlightTimer = nil
    }

    func scheduleMidnightRefresh() {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
              let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 5, of: tomorrow) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + midnight.timeIntervalSinceNow) { [weak self] in
            Task { @MainActor in
                self?.delegate?.timerManagerMidnightTick()
                self?.scheduleMidnightRefresh()
            }
        }
    }

    private func createCommonModeTimer(interval: TimeInterval, block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in block() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
