import Foundation

// MARK: - EMA Fetch Methods

extension StockService {

    private func fetchChartCloses(symbol: String, range: String, interval: String) async -> [Double]? {
        guard let url = APIEndpoints.chartURL(symbol: symbol, range: range, interval: interval) else { return nil }
        return await fetchYahooCloses(symbol: symbol, url: url)
    }

    private func fetchWeeklyClosesWithTimestamps(symbol: String) async -> (closes: [Double], timestamps: [Int])? {
        guard let url = APIEndpoints.chartURL(symbol: symbol, range: "6mo", interval: "1wk") else { return nil }
        return await fetchYahooClosesAndTimestamps(symbol: symbol, url: url)
    }

    private func completedWeeklyBarCount(timestamps: [Int], now: Date) -> Int {
        let calendar = MarketSchedule.easternCalendar
        let weekday = calendar.component(.weekday, from: now)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: now))!
        let cutoff = Int(monday.timeIntervalSince1970)
        return timestamps.filter { $0 < cutoff }.count
    }

    // MARK: - EMA Calculations

    private func fetchEMA(symbol: String, range: String, interval: String) async -> Double? {
        guard let closes = await fetchChartCloses(symbol: symbol, range: range, interval: interval) else { return nil }
        return EMAAnalysis.calculate(closes: closes)
    }

    func fetchDailyEMA(symbol: String) async -> Double? {
        await fetchEMA(symbol: symbol, range: "1mo", interval: "1d")
    }

    func fetchWeeklyEMA(symbol: String) async -> Double? {
        await fetchEMA(symbol: symbol, range: "6mo", interval: "1wk")
    }

    func fetchEMAEntry(symbol: String, precomputedDailyEMA: Double? = nil, precomputedDailyAboveCount: Int? = nil, now: Date = Date()) async -> EMACacheEntry? {
        async let weeklyData = fetchWeeklyClosesWithTimestamps(symbol: symbol)

        let day: Double?
        if let precomputed = precomputedDailyEMA {
            day = precomputed
        } else {
            day = await fetchDailyEMA(symbol: symbol)
        }

        let dayAbove: Int?
        if let precomputed = precomputedDailyAboveCount {
            dayAbove = precomputed
        } else {
            dayAbove = nil
        }

        let weekly = await weeklyData
        let weekEMA = weekly.flatMap { EMAAnalysis.calculate(closes: $0.closes) }

        // Use completed weekly bars only (before Friday 2PM) for all weekly metrics
        // to ensure crossover/crossdown/above/below are consistent with each other.
        //
        // During sneak peek, two fixes:
        // 1. Collapse current-week bars: Yahoo may return multiple bars for the current week
        //    (e.g., yesterday's close + today's intraday). Use completed + latest close only,
        //    so intermediate bars don't mask a crossover.
        // 2. Fallback to completed bars: if the crossover happened in the most recently
        //    completed week and the current week continues above, the collapsed view still
        //    misses it. Check completed bars as fallback for crossover/crossdown.
        let weeklyCloses: [Double]?
        let completedCloses: [Double]?
        if let weeklyData = weekly {
            let count = completedWeeklyBarCount(timestamps: weeklyData.timestamps, now: now)
            if isCurrentWeekSneakPeek(now: now) {
                let completed = count > 0 ? Array(weeklyData.closes[0..<count]) : []
                completedCloses = completed.isEmpty ? nil : completed
                if let lastClose = weeklyData.closes.last {
                    weeklyCloses = completed + [lastClose]
                } else {
                    weeklyCloses = completedCloses
                }
            } else {
                weeklyCloses = count > 0 ? Array(weeklyData.closes[0..<count]) : nil
                completedCloses = nil
            }
        } else {
            weeklyCloses = nil
            completedCloses = nil
        }
        let weekAbove = weeklyCloses.flatMap { EMAAnalysis.countPeriodsAbove(closes: $0) }
        let crossover = weeklyCloses.flatMap { EMAAnalysis.detectWeeklyCrossover(closes: $0) }
            ?? completedCloses.flatMap { EMAAnalysis.detectWeeklyCrossover(closes: $0) }
        let crossdown = weeklyCloses.flatMap { EMAAnalysis.detectWeeklyCrossdown(closes: $0) }
            ?? completedCloses.flatMap { EMAAnalysis.detectWeeklyCrossdown(closes: $0) }
        let belowCount = weeklyCloses.flatMap { EMAAnalysis.countWeeksBelow(closes: $0) }

        guard day != nil || weekEMA != nil else { return nil }
        return EMACacheEntry(day: day, week: weekEMA, weekCrossoverWeeksBelow: crossover, weekCrossdownWeeksAbove: crossdown, weekBelowCount: belowCount, dayAboveCount: dayAbove, weekAboveCount: weekAbove)
    }

    func fetchEMAEntry(symbol: String, precomputedDailyEMA: Double?, precomputedDailyAboveCount: Int? = nil) async -> EMACacheEntry? {
        await fetchEMAEntry(symbol: symbol, precomputedDailyEMA: precomputedDailyEMA, precomputedDailyAboveCount: precomputedDailyAboveCount, now: Date())
    }

    /// Include the current week's bar from Friday 2PM ET onward through the weekend.
    /// Before Friday 2PM, only completed prior-week bars are used. On Monday, the new week
    /// starts and the prior week naturally enters the completed set via timestamp filtering.
    private func isCurrentWeekSneakPeek(now: Date) -> Bool {
        let calendar = MarketSchedule.easternCalendar
        let weekday = calendar.component(.weekday, from: now)
        // Saturday (7) or Sunday (1): week's bar is complete
        if weekday == 1 || weekday == 7 { return true }
        // Friday (6): from 2PM ET onward
        guard weekday == 6 else { return false }
        let hour = calendar.component(.hour, from: now)
        return hour >= 14
    }

    func batchFetchEMAValues(symbols: [String]) async -> [String: EMACacheEntry] {
        await partitionedBatchFetch(symbols: symbols) { symbol in
            await self.fetchEMAEntry(symbol: symbol)
        }
    }

    func batchFetchEMAValues(symbols: [String], dailyEMAs: [String: Double], dailyAboveCounts: [String: Int] = [:]) async -> [String: EMACacheEntry] {
        await partitionedBatchFetch(symbols: symbols) { symbol in
            await self.fetchEMAEntry(symbol: symbol, precomputedDailyEMA: dailyEMAs[symbol], precomputedDailyAboveCount: dailyAboveCounts[symbol])
        }
    }
}
