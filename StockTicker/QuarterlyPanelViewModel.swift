import SwiftUI

// MARK: - View Model

@MainActor
class QuarterlyPanelViewModel: ObservableObject {
    @Published var rows: [QuarterlyRow] = []
    @Published var sortColumn: QuarterlySortColumn = .symbol
    @Published var isSortAscending: Bool = true
    @Published var quarters: [QuarterInfo] = []
    @Published var highlightedSymbols: Set<String> = []
    @Published var viewMode: QuarterlyViewMode = .sinceQuarter
    private(set) var configSymbols: Set<String> = []
    var highlightColor: Color = .yellow
    var highlightOpacity: Double = 0.25

    @Published var breakoutRows: [QuarterlyRow] = []
    @Published var breakdownRows: [QuarterlyRow] = []

    @Published var miscStats: [MiscStat] = []

    @Published var emaDayRows: [QuarterlyRow] = []
    @Published var emaWeekRows: [QuarterlyRow] = []
    @Published var emaCrossRows: [QuarterlyRow] = []
    @Published var emaCrossdownRows: [QuarterlyRow] = []
    @Published var emaBelowRows: [QuarterlyRow] = []

    var isForwardPEMode: Bool { viewMode == .forwardPE }
    var isPriceBreaksMode: Bool { viewMode == .priceBreaks }
    var isEMAsMode: Bool { viewMode == .emas }
    var isVIXSpikesMode: Bool { viewMode == .vixSpikes }
    var isMiscStatsMode: Bool { viewMode == .miscStats }
    var hasScannerData: Bool { storedScannerEMAData != nil }

    @Published var vixSpikeHeaders: [(dateString: String, vixClose: Double)] = []

    var shouldShowEmptyState: Bool {
        if isPriceBreaksMode { return breakoutRows.isEmpty && breakdownRows.isEmpty }
        if isEMAsMode { return emaDayRows.isEmpty && emaWeekRows.isEmpty && emaCrossRows.isEmpty && emaCrossdownRows.isEmpty && emaBelowRows.isEmpty }
        if isVIXSpikesMode { return rows.isEmpty }
        return rows.isEmpty
    }

    private(set) var isUniverseActive = false
    private(set) var refreshInterval: Int = 15
    private(set) var hasFinnhubApiKey = true
    private var storedWatchlist: [String] = []
    private var storedQuotes: [String: StockQuote] = [:]
    private var storedQuarterPrices: [String: [String: Double]] = [:]
    private var storedHighestClosePrices: [String: Double] = [:]
    private var storedForwardPEData: [String: [String: Double]] = [:]
    private var storedCurrentForwardPEs: [String: Double] = [:]
    private var storedSwingLevelEntries: [String: SwingLevelCacheEntry] = [:]
    private var storedRSIValues: [String: Double] = [:]
    private var storedEMAEntries: [String: EMACacheEntry] = [:]
    private var storedScannerEMAData: ScannerEMAData?
    private var storedVIXSpikes: [VIXSpike] = []
    private var storedVIXSpikePrices: [String: [String: Double]] = [:]

    func setupHighlights(symbols: Set<String>, color: String, opacity: Double) {
        configSymbols = symbols
        highlightedSymbols = symbols
        highlightColor = ColorMapping.color(from: color)
        highlightOpacity = opacity
    }

    func toggleHighlight(for symbol: String) {
        guard !configSymbols.contains(symbol) else { return }
        if highlightedSymbols.contains(symbol) {
            highlightedSymbols.remove(symbol)
        } else {
            highlightedSymbols.insert(symbol)
        }
    }

    func update(watchlist: [String], quarterInfos: [QuarterInfo], data: QuarterlyPanelData, isUniverseActive: Bool = false, refreshInterval: Int = 15, hasFinnhubApiKey: Bool = true) {
        self.quarters = quarterInfos
        self.isUniverseActive = isUniverseActive
        self.refreshInterval = refreshInterval
        self.hasFinnhubApiKey = hasFinnhubApiKey
        self.storedWatchlist = watchlist
        applyData(data)

        rows = buildRows(for: viewMode)
        applySorting()
    }

    func refresh(data: QuarterlyPanelData) {
        guard !quarters.isEmpty else { return }
        applyData(data)

        rows = buildRows(for: viewMode)
        applySorting()
    }

    private func applyData(_ data: QuarterlyPanelData) {
        self.storedQuotes = data.quotes
        self.storedQuarterPrices = data.quarterPrices
        self.storedHighestClosePrices = data.highestClosePrices
        self.storedForwardPEData = data.forwardPEData
        self.storedCurrentForwardPEs = data.currentForwardPEs
        self.storedSwingLevelEntries = data.swingLevelEntries
        self.storedRSIValues = data.rsiValues
        self.storedEMAEntries = data.emaEntries
        self.storedScannerEMAData = data.scannerEMAData
        self.storedVIXSpikes = data.vixSpikes
        self.storedVIXSpikePrices = data.vixSpikePrices
    }

    func switchMode(_ mode: QuarterlyViewMode) {
        viewMode = mode
        rows = buildRows(for: mode)
        applySorting()
    }

    private func buildRows(for mode: QuarterlyViewMode) -> [QuarterlyRow] {
        switch mode {
        case .sinceQuarter:
            return buildSinceQuarterRows()
        case .duringQuarter:
            return buildDuringQuarterRows()
        case .forwardPE:
            return buildForwardPERows()
        case .priceBreaks:
            return buildPriceBreaksRows()
        case .emas:
            return buildEMAsRows()
        case .vixSpikes:
            return buildVIXSpikeRows()
        case .miscStats:
            buildMiscStats()
            return []
        }
    }

    private func buildSinceQuarterRows() -> [QuarterlyRow] {
        storedWatchlist.map { symbol in
            var changes: [String: Double?] = [:]
            for qi in quarters {
                guard let quarterEndPrice = storedQuarterPrices[qi.identifier]?[symbol],
                      quarterEndPrice > 0,
                      let quote = storedQuotes[symbol],
                      !quote.isPlaceholder else {
                    changes[qi.identifier] = nil
                    continue
                }
                changes[qi.identifier] = ((quote.price - quarterEndPrice) / quarterEndPrice) * 100
            }
            let highPct = highestClosePercent(for: symbol)
            return QuarterlyRow(id: symbol, symbol: symbol, highestCloseChangePercent: highPct, quarterChanges: changes, currentForwardPE: nil, breakoutPercent: nil, breakoutDate: nil, breakdownPercent: nil, breakdownDate: nil, rsi: nil)
        }
    }

    private func buildDuringQuarterRows() -> [QuarterlyRow] {
        storedWatchlist.map { symbol in
            var changes: [String: Double?] = [:]
            for qi in quarters {
                var priorYear = qi.year
                var priorQ = qi.quarter - 1
                if priorQ < 1 { priorQ = 4; priorYear -= 1 }
                let priorId = QuarterCalculation.quarterIdentifier(year: priorYear, quarter: priorQ)
                guard let endPrice = storedQuarterPrices[qi.identifier]?[symbol],
                      endPrice > 0,
                      let startPrice = storedQuarterPrices[priorId]?[symbol],
                      startPrice > 0 else {
                    changes[qi.identifier] = nil
                    continue
                }
                changes[qi.identifier] = ((endPrice - startPrice) / startPrice) * 100
            }
            let highPct = highestClosePercent(for: symbol)
            return QuarterlyRow(id: symbol, symbol: symbol, highestCloseChangePercent: highPct, quarterChanges: changes, currentForwardPE: nil, breakoutPercent: nil, breakoutDate: nil, breakdownPercent: nil, breakdownDate: nil, rsi: nil)
        }
    }

    private func buildForwardPERows() -> [QuarterlyRow] {
        storedWatchlist.compactMap { symbol in
            let symbolPEs = storedForwardPEData[symbol]
            guard let symbolPEs, !symbolPEs.isEmpty else { return nil }

            var changes: [String: Double?] = [:]
            for qi in quarters {
                changes[qi.identifier] = symbolPEs[qi.identifier]
            }
            let currentPE = storedCurrentForwardPEs[symbol]
            return QuarterlyRow(id: symbol, symbol: symbol, highestCloseChangePercent: nil, quarterChanges: changes, currentForwardPE: currentPE, breakoutPercent: nil, breakoutDate: nil, breakdownPercent: nil, breakdownDate: nil, rsi: nil)
        }
    }

    private func buildPriceBreaksRows() -> [QuarterlyRow] {
        var outRows: [QuarterlyRow] = []
        var bkdnRows: [QuarterlyRow] = []
        for symbol in storedWatchlist {
            guard let entry = storedSwingLevelEntries[symbol],
                  let quote = storedQuotes[symbol], !quote.isPlaceholder else { continue }
            let symbolRSI = storedRSIValues[symbol]
            if let breakoutPrice = entry.breakoutPrice, breakoutPrice > 0 {
                let pct = ((quote.price - breakoutPrice) / breakoutPrice) * 100
                if pct > 0 {
                    outRows.append(QuarterlyRow(id: "\(symbol)-breakout", symbol: symbol, highestCloseChangePercent: nil, quarterChanges: [:], currentForwardPE: nil, breakoutPercent: pct, breakoutDate: entry.breakoutDate, breakdownPercent: nil, breakdownDate: nil, rsi: symbolRSI))
                }
            }
            if let breakdownPrice = entry.breakdownPrice, breakdownPrice > 0 {
                let pct = ((quote.price - breakdownPrice) / breakdownPrice) * 100
                if pct < 0 {
                    bkdnRows.append(QuarterlyRow(id: "\(symbol)-breakdown", symbol: symbol, highestCloseChangePercent: nil, quarterChanges: [:], currentForwardPE: nil, breakoutPercent: nil, breakoutDate: nil, breakdownPercent: pct, breakdownDate: entry.breakdownDate, rsi: symbolRSI))
                }
            }
        }
        breakoutRows = outRows
        breakdownRows = bkdnRows
        return outRows + bkdnRows
    }

    private func buildEMAsRows() -> [QuarterlyRow] {
        var dayRows: [QuarterlyRow] = []
        var weekRows: [QuarterlyRow] = []
        for symbol in storedWatchlist {
            guard let entry = storedEMAEntries[symbol],
                  let quote = storedQuotes[symbol], !quote.isPlaceholder else { continue }
            if let ema = entry.day, quote.price > ema, ema > 0, let aboveCount = entry.dayAboveCount {
                dayRows.append(makeEMARow(symbol: symbol, suffix: "day", count: aboveCount))
            }
            if let ema = entry.week, quote.price > ema, ema > 0, let aboveCount = entry.weekAboveCount {
                weekRows.append(makeEMARow(symbol: symbol, suffix: "week", count: aboveCount))
            }
        }

        var crossRows: [QuarterlyRow] = []
        for symbol in storedWatchlist {
            guard let entry = storedEMAEntries[symbol],
                  let weeksBelow = entry.weekCrossoverWeeksBelow,
                  weeksBelow >= 3 else { continue }
            crossRows.append(makeEMARow(symbol: symbol, suffix: "cross", count: weeksBelow))
        }

        var crossdownRows: [QuarterlyRow] = []
        for symbol in storedWatchlist {
            guard let entry = storedEMAEntries[symbol],
                  let weeksAbove = entry.weekCrossdownWeeksAbove,
                  weeksAbove >= 3 else { continue }
            crossdownRows.append(makeEMARow(symbol: symbol, suffix: "crossdown", count: weeksAbove))
        }

        var belowRows: [QuarterlyRow] = []
        for symbol in storedWatchlist {
            guard let entry = storedEMAEntries[symbol],
                  let ema = entry.week, ema > 0,
                  let weeksBelow = entry.weekBelowCount,
                  weeksBelow >= 3,
                  let quote = storedQuotes[symbol], !quote.isPlaceholder else { continue }
            belowRows.append(makeEMARow(symbol: symbol, suffix: "below", count: weeksBelow))
        }

        // Merge scanner-only symbols (skip any already in local data)
        if let scanner = storedScannerEMAData {
            let localSymbols = Set(storedWatchlist)
            for item in scanner.dayAbove where !localSymbols.contains(item.symbol) {
                dayRows.append(makeEMARow(symbol: item.symbol, suffix: "day", count: item.count))
            }
            for item in scanner.weekAbove where !localSymbols.contains(item.symbol) {
                weekRows.append(makeEMARow(symbol: item.symbol, suffix: "week", count: item.count))
            }
            for item in scanner.crossovers where !localSymbols.contains(item.symbol) {
                crossRows.append(makeEMARow(symbol: item.symbol, suffix: "cross", count: item.weeksBelow))
            }
            for item in scanner.crossdowns where !localSymbols.contains(item.symbol) {
                crossdownRows.append(makeEMARow(symbol: item.symbol, suffix: "crossdown", count: item.weeksAbove))
            }
            for item in scanner.below where !localSymbols.contains(item.symbol) {
                belowRows.append(makeEMARow(symbol: item.symbol, suffix: "below", count: item.weeksBelow))
            }
        }

        emaDayRows = dayRows
        emaWeekRows = weekRows
        emaCrossRows = crossRows
        emaCrossdownRows = crossdownRows
        emaBelowRows = belowRows

        return dayRows + weekRows + crossRows + crossdownRows + belowRows
    }

    private func buildVIXSpikeRows() -> [QuarterlyRow] {
        vixSpikeHeaders = storedVIXSpikes.reversed().map { (dateString: $0.dateString, vixClose: $0.vixClose) }
        return storedWatchlist.map { symbol in
            var changes: [String: Double?] = [:]
            let symbolPrices = storedVIXSpikePrices[symbol]
            for spike in storedVIXSpikes {
                guard let spikeClose = symbolPrices?[spike.dateString],
                      spikeClose > 0,
                      let quote = storedQuotes[symbol],
                      !quote.isPlaceholder else {
                    changes[spike.dateString] = nil
                    continue
                }
                changes[spike.dateString] = ((quote.price - spikeClose) / spikeClose) * 100
            }
            let highPct = highestClosePercent(for: symbol)
            return QuarterlyRow(id: symbol, symbol: symbol, highestCloseChangePercent: highPct, quarterChanges: changes, currentForwardPE: nil, breakoutPercent: nil, breakoutDate: nil, breakdownPercent: nil, breakdownDate: nil, rsi: nil)
        }
    }

    private func makeEMARow(symbol: String, suffix: String, count: Int) -> QuarterlyRow {
        QuarterlyRow(
            id: "\(symbol)-ema-\(suffix)", symbol: symbol,
            highestCloseChangePercent: nil, quarterChanges: [:], currentForwardPE: nil,
            breakoutPercent: Double(count), breakoutDate: nil,
            breakdownPercent: nil, breakdownDate: nil, rsi: nil
        )
    }

    private func highestClosePercent(for symbol: String) -> Double? {
        guard let highest = storedHighestClosePrices[symbol], highest > 0,
              let quote = storedQuotes[symbol], !quote.isPlaceholder else { return nil }
        return ((quote.price - highest) / highest) * 100
    }

    static let indexSymbols: Set<String> = ["SPY", "QQQ", "DIA", "IWM"]
    static let sectorSymbols: Set<String> = ["XLB", "XLC", "XLE", "XLF", "XLI", "XLK", "XLP", "XLRE", "XLU", "XLV", "XLY", "SMH"]

    private var symbolSetLabel: String { isUniverseActive ? "symbols" : "watchlist" }

    func buildMiscStats() {
        let label = symbolSetLabel
        miscStats = [
            MiscStat(id: "within5pctOfHigh", description: "% of \(label) within 5% of High", value: percentWithin5OfHigh(symbols: storedWatchlist)),
            MiscStat(id: "indexesWithin5pctOfHigh", description: "% of indexes within 5% of High", value: percentWithin5OfHigh(symbols: storedWatchlist.filter { Self.indexSymbols.contains($0) })),
            MiscStat(id: "sectorsWithin5pctOfHigh", description: "% of sectors within 5% of High", value: percentWithin5OfHigh(symbols: storedWatchlist.filter { Self.sectorSymbols.contains($0) })),
            MiscStat(id: "avgYTDChange", description: "Average YTD change %", value: averageYTDChange()),
            MiscStat(id: "pctPositiveYTD", description: "% of \(label) positive YTD", value: percentPositiveYTD(symbols: storedWatchlist)),
            MiscStat(id: "sectorsPositiveYTD", description: "% of sectors positive YTD", value: percentPositiveYTD(symbols: storedWatchlist.filter { Self.sectorSymbols.contains($0) })),
            MiscStat(id: "avgForwardPE", description: "Average forward P/E (equities)", value: averageForwardPE()),
            MiscStat(id: "medianForwardPE", description: "Median forward P/E (equities)", value: medianForwardPE()),
            MiscStat(id: "pctAbove5WEMA", description: "% of \(label) above 5W EMA", value: percentAbove5WEMA()),
            MiscStat(id: "pctBelow5WEMA", description: "% of \(label) below 5W EMA", value: percentBelow5WEMA()),
        ]
    }

    private func percentWithin5OfHigh(symbols: [String]) -> String {
        var total = 0
        var within = 0
        for symbol in symbols {
            guard let highest = storedHighestClosePrices[symbol], highest > 0,
                  let quote = storedQuotes[symbol], !quote.isPlaceholder else { continue }
            total += 1
            let pct = ((quote.price - highest) / highest) * 100
            if pct >= -5.0 { within += 1 }
        }
        guard total > 0 else { return QuarterlyFormatting.noData }
        return String(format: "%.0f%%", (Double(within) / Double(total)) * 100)
    }

    private func averageYTDChange() -> String {
        let ytdPercents = storedWatchlist.compactMap { storedQuotes[$0]?.ytdChangePercent }
        guard !ytdPercents.isEmpty else { return QuarterlyFormatting.noData }
        let avg = ytdPercents.reduce(0, +) / Double(ytdPercents.count)
        return Formatting.signedPercent(avg, isPositive: avg >= 0)
    }

    private func percentPositiveYTD(symbols: [String]) -> String {
        let ytdPercents = symbols.compactMap { storedQuotes[$0]?.ytdChangePercent }
        guard !ytdPercents.isEmpty else { return QuarterlyFormatting.noData }
        let positive = ytdPercents.filter { $0 > 0 }.count
        return String(format: "%.0f%%", (Double(positive) / Double(ytdPercents.count)) * 100)
    }

    private func averageForwardPE() -> String {
        let pes = storedWatchlist.compactMap { storedCurrentForwardPEs[$0] }.filter { $0 > 0 }
        guard !pes.isEmpty else { return QuarterlyFormatting.noData }
        let avg = pes.reduce(0, +) / Double(pes.count)
        return String(format: "%.1f", avg)
    }

    private func medianForwardPE() -> String {
        let pes = storedWatchlist.compactMap { storedCurrentForwardPEs[$0] }.filter { $0 > 0 }.sorted()
        guard !pes.isEmpty else { return QuarterlyFormatting.noData }
        let mid = pes.count / 2
        let median = pes.count.isMultiple(of: 2) ? (pes[mid - 1] + pes[mid]) / 2 : pes[mid]
        return String(format: "%.1f", median)
    }

    private func percentAbove5WEMA() -> String {
        var total = 0
        var above = 0
        for symbol in storedWatchlist {
            guard let entry = storedEMAEntries[symbol],
                  let weekEMA = entry.week, weekEMA > 0,
                  let quote = storedQuotes[symbol], !quote.isPlaceholder else { continue }
            total += 1
            if quote.price > weekEMA { above += 1 }
        }
        guard total > 0 else { return QuarterlyFormatting.noData }
        return String(format: "%.0f%%", (Double(above) / Double(total)) * 100)
    }

    private func percentBelow5WEMA() -> String {
        var total = 0
        var below = 0
        for symbol in storedWatchlist {
            guard let entry = storedEMAEntries[symbol],
                  let weekEMA = entry.week, weekEMA > 0,
                  let quote = storedQuotes[symbol], !quote.isPlaceholder else { continue }
            total += 1
            if quote.price <= weekEMA { below += 1 }
        }
        guard total > 0 else { return QuarterlyFormatting.noData }
        return String(format: "%.0f%%", (Double(below) / Double(total)) * 100)
    }

    func sort(by column: QuarterlySortColumn) {
        if sortColumn == column {
            isSortAscending.toggle()
        } else {
            sortColumn = column
            isSortAscending = true
        }
        applySorting()
    }

    private static let dateParseFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yy"
        return dateFormatter
    }()

    private func parseSortDate(_ row: QuarterlyRow) -> Date? {
        let dateString = row.breakoutDate ?? row.breakdownDate
        guard let dateString else { return nil }
        return Self.dateParseFormatter.date(from: dateString)
    }

    private func priceBreakPercent(_ row: QuarterlyRow) -> Double? {
        row.breakoutPercent ?? row.breakdownPercent
    }

    private func applySorting() {
        let comparator: (QuarterlyRow, QuarterlyRow) -> Bool = { a, b in
            let result: Bool
            switch self.sortColumn {
            case .symbol:
                result = a.symbol < b.symbol
            case .highestClose:
                switch (a.highestCloseChangePercent, b.highestCloseChangePercent) {
                case let (av?, bv?): result = av < bv
                case (nil, .some): result = true
                case (.some, nil): result = false
                case (nil, nil): result = a.symbol < b.symbol
                }
            case .currentPE:
                switch (a.currentForwardPE, b.currentForwardPE) {
                case let (av?, bv?): result = av < bv
                case (nil, .some): result = true
                case (.some, nil): result = false
                case (nil, nil): result = a.symbol < b.symbol
                }
            case .quarter(let qId):
                let aVal = a.quarterChanges[qId] ?? nil
                let bVal = b.quarterChanges[qId] ?? nil
                switch (aVal, bVal) {
                case let (av?, bv?): result = av < bv
                case (nil, .some): result = true
                case (.some, nil): result = false
                case (nil, nil): result = a.symbol < b.symbol
                }
            case .date:
                let aDate = self.parseSortDate(a)
                let bDate = self.parseSortDate(b)
                switch (aDate, bDate) {
                case let (ad?, bd?): result = ad < bd
                case (nil, .some): result = true
                case (.some, nil): result = false
                case (nil, nil): result = a.symbol < b.symbol
                }
            case .priceBreakPercent:
                let aVal = self.priceBreakPercent(a)
                let bVal = self.priceBreakPercent(b)
                switch (aVal, bVal) {
                case let (av?, bv?): result = av < bv
                case (nil, .some): result = true
                case (.some, nil): result = false
                case (nil, nil): result = a.symbol < b.symbol
                }
            case .rsi:
                switch (a.rsi, b.rsi) {
                case let (av?, bv?): result = av < bv
                case (nil, .some): result = true
                case (.some, nil): result = false
                case (nil, nil): result = a.symbol < b.symbol
                }
            }
            return self.isSortAscending ? result : !result
        }

        if isPriceBreaksMode {
            breakoutRows.sort(by: comparator)
            breakdownRows.sort(by: comparator)
        } else if isEMAsMode {
            emaDayRows.sort(by: comparator)
            emaWeekRows.sort(by: comparator)
            emaCrossRows.sort(by: comparator)
            emaCrossdownRows.sort(by: comparator)
            emaBelowRows.sort(by: comparator)
        }
        rows.sort(by: comparator)
    }
}
