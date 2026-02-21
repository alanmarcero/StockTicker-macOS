import Foundation

// MARK: - Backfill Caches

struct BackfillCaches: Sendable {
    let ytd: YTDCacheManager
    let quarterly: QuarterlyCacheManager
    let highestClose: HighestCloseCacheManager
    let forwardPE: ForwardPECacheManager
    let swingLevel: SwingLevelCacheManager
    let rsi: RSICacheManager
    let ema: EMACacheManager
}

// MARK: - Backfill Scheduler

actor BackfillScheduler {

    private enum Timing {
        static let delayBetweenCalls: UInt64 = 4_000_000_000  // 4s
        static let batchNotifySize = 10
    }

    enum Phase: Int, CaseIterable, Sendable {
        case ytd
        case dailyAnalysis
        case weeklyEMA
        case forwardPE
        case quarterly
    }

    private var task: Task<Void, Never>?
    private var delay: UInt64 = Timing.delayBetweenCalls

    var isRunning: Bool { task != nil }

    func start(
        symbols: [String],
        extraStatsSymbols: [String],
        quarterInfos: [QuarterInfo],
        period1: Int,
        period2: Int,
        forwardPEPeriod1: Int,
        stockService: StockServiceProtocol,
        caches: BackfillCaches,
        delayBetweenCalls: UInt64 = Timing.delayBetweenCalls,
        onBatchComplete: @escaping @Sendable (Phase) async -> Void
    ) {
        cancel()
        self.delay = delayBetweenCalls

        task = Task {
            for phase in Phase.allCases {
                guard !Task.isCancelled else { return }

                switch phase {
                case .ytd:
                    await runYTDPhase(
                        symbols: symbols, stockService: stockService,
                        cache: caches.ytd, onBatchComplete: onBatchComplete
                    )
                case .dailyAnalysis:
                    await runDailyAnalysisPhase(
                        symbols: symbols, period1: period1, period2: period2,
                        stockService: stockService, caches: caches,
                        onBatchComplete: onBatchComplete
                    )
                case .weeklyEMA:
                    await runWeeklyEMAPhase(
                        symbols: symbols, stockService: stockService,
                        caches: caches, onBatchComplete: onBatchComplete
                    )
                case .forwardPE:
                    await runForwardPEPhase(
                        symbols: extraStatsSymbols, period1: forwardPEPeriod1,
                        period2: period2, stockService: stockService,
                        cache: caches.forwardPE, onBatchComplete: onBatchComplete
                    )
                case .quarterly:
                    await runQuarterlyPhase(
                        symbols: extraStatsSymbols, quarterInfos: quarterInfos,
                        stockService: stockService, cache: caches.quarterly,
                        onBatchComplete: onBatchComplete
                    )
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    // MARK: - Batch Processing Helper

    private func processSymbols(
        _ symbols: [String],
        phase: Phase,
        onBatchComplete: @escaping @Sendable (Phase) async -> Void,
        body: (String) async -> Void
    ) async {
        var completed = 0
        for symbol in symbols {
            guard !Task.isCancelled else { return }
            await body(symbol)
            completed += 1
            if completed % Timing.batchNotifySize == 0 {
                await onBatchComplete(phase)
            }
            try? await Task.sleep(nanoseconds: delay)
        }
        if completed > 0 { await onBatchComplete(phase) }
    }

    // MARK: - Phase Implementations

    private func runYTDPhase(
        symbols: [String],
        stockService: StockServiceProtocol,
        cache: YTDCacheManager,
        onBatchComplete: @escaping @Sendable (Phase) async -> Void
    ) async {
        let missing = await cache.getMissingSymbols(from: symbols)
        await processSymbols(missing, phase: .ytd, onBatchComplete: onBatchComplete) { symbol in
            if let price = await stockService.fetchYTDStartPrice(symbol: symbol) {
                await cache.setStartPrice(for: symbol, price: price)
                await cache.save()
            }
        }
    }

    private func runDailyAnalysisPhase(
        symbols: [String],
        period1: Int,
        period2: Int,
        stockService: StockServiceProtocol,
        caches: BackfillCaches,
        onBatchComplete: @escaping @Sendable (Phase) async -> Void
    ) async {
        let highestCloseMissing = Set(await caches.highestClose.getMissingSymbols(from: symbols))
        let swingMissing = Set(await caches.swingLevel.getMissingSymbols(from: symbols))
        let rsiMissing = Set(await caches.rsi.getMissingSymbols(from: symbols))
        let emaMissing = Set(await caches.ema.getMissingSymbols(from: symbols))

        let allMissing = Array(highestCloseMissing.union(swingMissing).union(rsiMissing).union(emaMissing))

        await processSymbols(allMissing, phase: .dailyAnalysis, onBatchComplete: onBatchComplete) { symbol in
            guard let result = await stockService.fetchDailyAnalysis(symbol: symbol, period1: period1, period2: period2) else { return }
            if highestCloseMissing.contains(symbol), let highest = result.highestClose {
                await caches.highestClose.setHighestClose(for: symbol, price: highest)
                await caches.highestClose.save()
            }
            if swingMissing.contains(symbol), let entry = result.swingLevelEntry {
                await caches.swingLevel.setEntry(for: symbol, entry: entry)
                await caches.swingLevel.save()
            }
            if rsiMissing.contains(symbol), let rsi = result.rsi {
                await caches.rsi.setRSI(for: symbol, value: rsi)
                await caches.rsi.save()
            }
            if emaMissing.contains(symbol), let ema = result.dailyEMA {
                await caches.ema.setEntry(for: symbol, entry: EMACacheEntry(day: ema, week: nil, weekCrossoverWeeksBelow: nil, weekBelowCount: nil))
                await caches.ema.save()
            }
        }
    }

    private func runWeeklyEMAPhase(
        symbols: [String],
        stockService: StockServiceProtocol,
        caches: BackfillCaches,
        onBatchComplete: @escaping @Sendable (Phase) async -> Void
    ) async {
        let missing = await caches.ema.getMissingSymbols(from: symbols)

        // Also re-fetch symbols that have daily EMA but missing weekly EMA
        let allEntries = await caches.ema.getAllEntries()
        let needsWeekly = symbols.filter { symbol in
            guard let entry = allEntries[symbol] else { return false }
            return entry.day != nil && entry.week == nil
        }

        let toFetch = Array(Set(missing + needsWeekly))

        await processSymbols(toFetch, phase: .weeklyEMA, onBatchComplete: onBatchComplete) { symbol in
            let existingDaily = allEntries[symbol]?.day
            if let entry = await stockService.fetchEMAEntry(symbol: symbol, precomputedDailyEMA: existingDaily) {
                await caches.ema.setEntry(for: symbol, entry: entry)
                await caches.ema.save()
            }
        }
    }

    private func runForwardPEPhase(
        symbols: [String],
        period1: Int,
        period2: Int,
        stockService: StockServiceProtocol,
        cache: ForwardPECacheManager,
        onBatchComplete: @escaping @Sendable (Phase) async -> Void
    ) async {
        let missing = await cache.getMissingSymbols(from: symbols)
        await processSymbols(missing, phase: .forwardPE, onBatchComplete: onBatchComplete) { symbol in
            if let quarterPEs = await stockService.fetchForwardPERatios(symbol: symbol, period1: period1, period2: period2) {
                await cache.setForwardPE(symbol: symbol, quarterPEs: quarterPEs)
                await cache.save()
            }
        }
    }

    private func runQuarterlyPhase(
        symbols: [String],
        quarterInfos: [QuarterInfo],
        stockService: StockServiceProtocol,
        cache: QuarterlyCacheManager,
        onBatchComplete: @escaping @Sendable (Phase) async -> Void
    ) async {
        for qi in quarterInfos {
            guard !Task.isCancelled else { return }
            let missing = await cache.getMissingSymbols(for: qi.identifier, from: symbols)
            guard !missing.isEmpty else { continue }

            let (period1, period2) = QuarterCalculation.quarterEndDateRange(year: qi.year, quarter: qi.quarter)

            await processSymbols(missing, phase: .quarterly, onBatchComplete: onBatchComplete) { symbol in
                if let price = await stockService.fetchQuarterEndPrice(symbol: symbol, period1: period1, period2: period2) {
                    await cache.setPrices(quarter: qi.identifier, prices: [symbol: price])
                    await cache.save()
                }
            }
        }
    }
}

