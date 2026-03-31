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
        async let weeklyDataFetch = fetchWeeklyClosesWithTimestamps(symbol: symbol)

        let day: Double?
        if let precomputed = precomputedDailyEMA {
            day = precomputed
        } else {
            day = await fetchDailyEMA(symbol: symbol)
        }
        
        let dayAbove = precomputedDailyAboveCount

        guard let weeklyData = await weeklyDataFetch else {
            guard day != nil else { return nil }
            return EMACacheEntry(day: day, week: nil, weekCrossoverWeeksBelow: nil, weekCrossdownWeeksAbove: nil, weekBelowCount: nil, dayAboveCount: dayAbove, weekAboveCount: nil)
        }

        let weekEMA = EMAAnalysis.calculate(closes: weeklyData.closes)
        
        let count = completedWeeklyBarCount(timestamps: weeklyData.timestamps, now: now)
        let weeklyCloses: [Double]?
        
        if isCurrentWeekSneakPeek(now: now) {
            let completed = count > 0 ? Array(weeklyData.closes[0..<count]) : []
            weeklyCloses = weeklyData.closes.last.map { completed + [$0] } ?? (completed.isEmpty ? nil : completed)
        } else {
            weeklyCloses = count > 0 ? Array(weeklyData.closes[0..<count]) : nil
        }
        
        let weekAbove = weeklyCloses.flatMap { EMAAnalysis.countPeriodsAbove(closes: $0) }
        let crossover = weeklyCloses.flatMap { EMAAnalysis.detectWeeklyCrossover(closes: $0) }
        let crossdown = weeklyCloses.flatMap { EMAAnalysis.detectWeeklyCrossdown(closes: $0) }
        let belowCount = weeklyCloses.flatMap { EMAAnalysis.countWeeksBelow(closes: $0) }

        guard day != nil || weekEMA != nil else { return nil }
        
        return EMACacheEntry(
            day: day,
            week: weekEMA,
            weekCrossoverWeeksBelow: crossover,
            weekCrossdownWeeksAbove: crossdown,
            weekBelowCount: belowCount,
            dayAboveCount: dayAbove,
            weekAboveCount: weekAbove
        )
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
        guard weekday != 1 && weekday != 7 else { return true }
        
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
