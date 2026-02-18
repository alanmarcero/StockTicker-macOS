import SwiftUI

// MARK: - View Model

@MainActor
class QuarterlyPanelViewModel: ObservableObject {
    @Published var rows: [QuarterlyRow] = []
    @Published var sortColumn: QuarterlySortColumn = .symbol
    @Published var sortAscending: Bool = true
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
    @Published var emaMonthRows: [QuarterlyRow] = []
    @Published var emaAllRows: [QuarterlyRow] = []
    @Published var emaCrossRows: [QuarterlyRow] = []

    var isForwardPEMode: Bool { viewMode == .forwardPE }
    var isPriceBreaksMode: Bool { viewMode == .priceBreaks }
    var isEMAsMode: Bool { viewMode == .emas }
    var isMiscStatsMode: Bool { viewMode == .miscStats }

    private var storedWatchlist: [String] = []
    private var storedQuotes: [String: StockQuote] = [:]
    private var storedQuarterPrices: [String: [String: Double]] = [:]
    private var storedHighestClosePrices: [String: Double] = [:]
    private var storedForwardPEData: [String: [String: Double]] = [:]
    private var storedCurrentForwardPEs: [String: Double] = [:]
    private var storedSwingLevelEntries: [String: SwingLevelCacheEntry] = [:]
    private var storedRSIValues: [String: Double] = [:]
    private var storedEMAEntries: [String: EMACacheEntry] = [:]

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

    func update(watchlist: [String], quotes: [String: StockQuote], quarterPrices: [String: [String: Double]], quarterInfos: [QuarterInfo], highestClosePrices: [String: Double] = [:], forwardPEData: [String: [String: Double]] = [:], currentForwardPEs: [String: Double] = [:], swingLevelEntries: [String: SwingLevelCacheEntry] = [:], rsiValues: [String: Double] = [:], emaEntries: [String: EMACacheEntry] = [:]) {
        self.quarters = quarterInfos
        self.storedWatchlist = watchlist
        self.storedQuotes = quotes
        self.storedQuarterPrices = quarterPrices
        self.storedHighestClosePrices = highestClosePrices
        self.storedForwardPEData = forwardPEData
        self.storedCurrentForwardPEs = currentForwardPEs
        self.storedSwingLevelEntries = swingLevelEntries
        self.storedRSIValues = rsiValues
        self.storedEMAEntries = emaEntries

        rows = buildRows(for: viewMode)
        applySorting()
    }

    func refresh(quotes: [String: StockQuote], quarterPrices: [String: [String: Double]], highestClosePrices: [String: Double] = [:], forwardPEData: [String: [String: Double]] = [:], currentForwardPEs: [String: Double] = [:], swingLevelEntries: [String: SwingLevelCacheEntry] = [:], rsiValues: [String: Double] = [:], emaEntries: [String: EMACacheEntry] = [:]) {
        guard !quarters.isEmpty else { return }

        self.storedQuotes = quotes
        self.storedQuarterPrices = quarterPrices
        self.storedHighestClosePrices = highestClosePrices
        self.storedForwardPEData = forwardPEData
        self.storedCurrentForwardPEs = currentForwardPEs
        self.storedSwingLevelEntries = swingLevelEntries
        self.storedRSIValues = rsiValues
        self.storedEMAEntries = emaEntries

        rows = buildRows(for: viewMode)
        applySorting()
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
        var monthRows: [QuarterlyRow] = []
        for symbol in storedWatchlist {
            guard let entry = storedEMAEntries[symbol],
                  let quote = storedQuotes[symbol], !quote.isPlaceholder else { continue }
            if let ema = entry.day, quote.price > ema, ema > 0 {
                let pct = ((quote.price - ema) / ema) * 100
                dayRows.append(QuarterlyRow(id: "\(symbol)-ema-day", symbol: symbol, highestCloseChangePercent: nil, quarterChanges: [:], currentForwardPE: nil, breakoutPercent: pct, breakoutDate: nil, breakdownPercent: nil, breakdownDate: nil, rsi: nil))
            }
            if let ema = entry.week, quote.price > ema, ema > 0 {
                let pct = ((quote.price - ema) / ema) * 100
                weekRows.append(QuarterlyRow(id: "\(symbol)-ema-week", symbol: symbol, highestCloseChangePercent: nil, quarterChanges: [:], currentForwardPE: nil, breakoutPercent: pct, breakoutDate: nil, breakdownPercent: nil, breakdownDate: nil, rsi: nil))
            }
            if let ema = entry.month, quote.price > ema, ema > 0 {
                let pct = ((quote.price - ema) / ema) * 100
                monthRows.append(QuarterlyRow(id: "\(symbol)-ema-month", symbol: symbol, highestCloseChangePercent: nil, quarterChanges: [:], currentForwardPE: nil, breakoutPercent: pct, breakoutDate: nil, breakdownPercent: nil, breakdownDate: nil, rsi: nil))
            }
        }
        emaDayRows = dayRows
        emaWeekRows = weekRows
        emaMonthRows = monthRows

        let daySymbols = Set(dayRows.map { $0.symbol })
        let weekSymbols = Set(weekRows.map { $0.symbol })
        let monthSymbols = Set(monthRows.map { $0.symbol })
        let allSymbols = daySymbols.intersection(weekSymbols).intersection(monthSymbols)

        emaAllRows = dayRows.filter { allSymbols.contains($0.symbol) }.map { row in
            QuarterlyRow(id: "\(row.symbol)-ema-all", symbol: row.symbol, highestCloseChangePercent: nil, quarterChanges: [:], currentForwardPE: nil, breakoutPercent: row.breakoutPercent, breakoutDate: nil, breakdownPercent: nil, breakdownDate: nil, rsi: nil)
        }

        var crossRows: [QuarterlyRow] = []
        for symbol in storedWatchlist {
            guard let entry = storedEMAEntries[symbol],
                  let weeksBelow = entry.weekCrossoverWeeksBelow else { continue }
            crossRows.append(QuarterlyRow(id: "\(symbol)-ema-cross", symbol: symbol, highestCloseChangePercent: nil, quarterChanges: [:], currentForwardPE: nil, breakoutPercent: Double(weeksBelow), breakoutDate: nil, breakdownPercent: nil, breakdownDate: nil, rsi: nil))
        }
        emaCrossRows = crossRows

        return dayRows + weekRows + monthRows + emaAllRows + crossRows
    }

    private func highestClosePercent(for symbol: String) -> Double? {
        guard let highest = storedHighestClosePrices[symbol], highest > 0,
              let quote = storedQuotes[symbol], !quote.isPlaceholder else { return nil }
        return ((quote.price - highest) / highest) * 100
    }

    static let indexSymbols: Set<String> = ["SPY", "QQQ", "DIA", "IWM"]
    static let sectorSymbols: Set<String> = ["XLB", "XLC", "XLE", "XLF", "XLI", "XLK", "XLP", "XLRE", "XLU", "XLV", "XLY", "SMH"]

    func buildMiscStats() {
        miscStats = [
            MiscStat(id: "within5pctOfHigh", description: "% of watchlist within 5% of High", value: percentWithin5OfHigh(symbols: storedWatchlist)),
            MiscStat(id: "indexesWithin5pctOfHigh", description: "% of indexes within 5% of High", value: percentWithin5OfHigh(symbols: storedWatchlist.filter { Self.indexSymbols.contains($0) })),
            MiscStat(id: "sectorsWithin5pctOfHigh", description: "% of sectors within 5% of High", value: percentWithin5OfHigh(symbols: storedWatchlist.filter { Self.sectorSymbols.contains($0) })),
            MiscStat(id: "avgYTDChange", description: "Average YTD change %", value: averageYTDChange()),
            MiscStat(id: "pctPositiveYTD", description: "% of watchlist positive YTD", value: percentPositiveYTD(symbols: storedWatchlist)),
            MiscStat(id: "sectorsPositiveYTD", description: "% of sectors positive YTD", value: percentPositiveYTD(symbols: storedWatchlist.filter { Self.sectorSymbols.contains($0) })),
            MiscStat(id: "avgForwardPE", description: "Average forward P/E (equities)", value: averageForwardPE()),
            MiscStat(id: "medianForwardPE", description: "Median forward P/E (equities)", value: medianForwardPE()),
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

    func sort(by column: QuarterlySortColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
        applySorting()
    }

    private static let dateParseFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yy"
        return dateFormatter
    }()

    private func parseSortDate(_ row: QuarterlyRow) -> Date? {
        let str = row.breakoutDate ?? row.breakdownDate
        guard let str else { return nil }
        return Self.dateParseFormatter.date(from: str)
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
            return self.sortAscending ? result : !result
        }

        if isPriceBreaksMode {
            breakoutRows.sort(by: comparator)
            breakdownRows.sort(by: comparator)
        }
        if isEMAsMode {
            emaDayRows.sort(by: comparator)
            emaWeekRows.sort(by: comparator)
            emaMonthRows.sort(by: comparator)
            emaAllRows.sort(by: comparator)
            emaCrossRows.sort(by: comparator)
        }
        rows.sort(by: comparator)
    }
}
