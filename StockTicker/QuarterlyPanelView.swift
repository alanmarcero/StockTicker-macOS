import SwiftUI
import AppKit

// MARK: - Constants

private enum QuarterlyWindowSize {
    static let width = LayoutConfig.QuarterlyWindow.width
    static let height = LayoutConfig.QuarterlyWindow.height
    static let minWidth = LayoutConfig.QuarterlyWindow.minWidth
    static let minHeight = LayoutConfig.QuarterlyWindow.minHeight
    static let symbolColumnWidth = LayoutConfig.QuarterlyWindow.symbolColumnWidth
    static let highColumnWidth = LayoutConfig.QuarterlyWindow.highColumnWidth
    static let quarterColumnWidth = LayoutConfig.QuarterlyWindow.quarterColumnWidth
    static let dateColumnWidth = LayoutConfig.QuarterlyWindow.dateColumnWidth
    static let rsiColumnWidth = LayoutConfig.QuarterlyWindow.rsiColumnWidth
}

private enum QuarterlyFormatting {
    static let noData = "--"
}

// MARK: - View Mode

enum QuarterlyViewMode: String, CaseIterable {
    case sinceQuarter = "Since Quarter"
    case duringQuarter = "During Quarter"
    case forwardPE = "Forward P/E"
    case priceBreaks = "Price Breaks"
}

// MARK: - Row Model

struct QuarterlyRow: Identifiable {
    let id: String
    let symbol: String
    let highestCloseChangePercent: Double?
    let quarterChanges: [String: Double?]  // quarter identifier -> percent change (or P/E value)
    let currentForwardPE: Double?
    let breakoutPercent: Double?
    let breakoutDate: String?
    let breakdownPercent: Double?
    let breakdownDate: String?
    let rsi: Double?
}

// MARK: - Sort Column

enum QuarterlySortColumn: Equatable {
    case symbol
    case highestClose
    case currentPE
    case quarter(String)  // quarter identifier
    case date
    case priceBreakPercent
    case rsi
}

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

    var isForwardPEMode: Bool { viewMode == .forwardPE }
    var isPriceBreaksMode: Bool { viewMode == .priceBreaks }

    private var storedWatchlist: [String] = []
    private var storedQuotes: [String: StockQuote] = [:]
    private var storedQuarterPrices: [String: [String: Double]] = [:]
    private var storedHighestClosePrices: [String: Double] = [:]
    private var storedForwardPEData: [String: [String: Double]] = [:]
    private var storedCurrentForwardPEs: [String: Double] = [:]
    private var storedSwingLevelEntries: [String: SwingLevelCacheEntry] = [:]
    private var storedRSIValues: [String: Double] = [:]

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

    func update(watchlist: [String], quotes: [String: StockQuote], quarterPrices: [String: [String: Double]], quarterInfos: [QuarterInfo], highestClosePrices: [String: Double] = [:], forwardPEData: [String: [String: Double]] = [:], currentForwardPEs: [String: Double] = [:], swingLevelEntries: [String: SwingLevelCacheEntry] = [:], rsiValues: [String: Double] = [:]) {
        self.quarters = quarterInfos
        self.storedWatchlist = watchlist
        self.storedQuotes = quotes
        self.storedQuarterPrices = quarterPrices
        self.storedHighestClosePrices = highestClosePrices
        self.storedForwardPEData = forwardPEData
        self.storedCurrentForwardPEs = currentForwardPEs
        self.storedSwingLevelEntries = swingLevelEntries
        self.storedRSIValues = rsiValues

        rows = buildRows(for: viewMode)
        applySorting()
    }

    func refresh(quotes: [String: StockQuote], quarterPrices: [String: [String: Double]], highestClosePrices: [String: Double] = [:], forwardPEData: [String: [String: Double]] = [:], currentForwardPEs: [String: Double] = [:], swingLevelEntries: [String: SwingLevelCacheEntry] = [:], rsiValues: [String: Double] = [:]) {
        guard !quarters.isEmpty else { return }

        self.storedQuotes = quotes
        self.storedQuarterPrices = quarterPrices
        self.storedHighestClosePrices = highestClosePrices
        self.storedForwardPEData = forwardPEData
        self.storedCurrentForwardPEs = currentForwardPEs
        self.storedSwingLevelEntries = swingLevelEntries
        self.storedRSIValues = rsiValues

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

    private func highestClosePercent(for symbol: String) -> Double? {
        guard let highest = storedHighestClosePrices[symbol], highest > 0,
              let quote = storedQuotes[symbol], !quote.isPlaceholder else { return nil }
        return ((quote.price - highest) / highest) * 100
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
        let f = DateFormatter()
        f.dateFormat = "M/d/yy"
        return f
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
        rows.sort(by: comparator)
    }
}

// MARK: - Quarterly Panel View

struct QuarterlyPanelView: View {
    @ObservedObject var viewModel: QuarterlyPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if viewModel.isPriceBreaksMode ? (viewModel.breakoutRows.isEmpty && viewModel.breakdownRows.isEmpty) : viewModel.rows.isEmpty {
                emptyState
            } else {
                scrollableContent
            }
        }
        .frame(minWidth: QuarterlyWindowSize.minWidth, minHeight: QuarterlyWindowSize.minHeight)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Extra Stats")
                    .font(.headline)
                Spacer()
                Text(symbolCountText)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            Picker("View Mode", selection: Binding(
                get: { viewModel.viewMode },
                set: { viewModel.switchMode($0) }
            )) {
                ForEach(QuarterlyViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text(headerDescription)
                .foregroundColor(.secondary)
                .font(.caption)
            if !highColumnDescription.isEmpty {
                Text(highColumnDescription)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No symbols in watchlist")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    @ViewBuilder
    private var scrollableContent: some View {
        if viewModel.isPriceBreaksMode {
            HStack(alignment: .top, spacing: 0) {
                priceBreaksTable("Breakout", rows: viewModel.breakoutRows, isBreakout: true)
                Divider()
                priceBreaksTable("Breakdown", rows: viewModel.breakdownRows, isBreakout: false)
            }
        } else {
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header: pinnedColumnHeaders) {
                        ForEach(viewModel.rows) { row in
                            rowView(row)
                            Divider().opacity(0.3)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func priceBreaksTable(_ title: String, rows: [QuarterlyRow], isBreakout: Bool) -> some View {
        ScrollView([.vertical]) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section(header: priceBreaksPinnedHeaders(title, isBreakout: isBreakout)) {
                    ForEach(rows) { row in
                        priceBreaksRowView(row, isBreakout: isBreakout)
                        Divider().opacity(0.3)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func priceBreaksPinnedHeaders(_ title: String, isBreakout: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.top, 4)
            HStack(spacing: 0) {
                sortableHeader("Symbol", column: .symbol, width: QuarterlyWindowSize.symbolColumnWidth, alignment: .leading)
                sortableHeader("Date", column: .date, width: QuarterlyWindowSize.dateColumnWidth, alignment: .trailing)
                sortableHeader("%", column: .priceBreakPercent, width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)
                sortableHeader("RSI", column: .rsi, width: QuarterlyWindowSize.rsiColumnWidth, alignment: .trailing)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            Divider()
        }
        .background(.background)
    }

    private func priceBreaksRowView(_ row: QuarterlyRow, isBreakout: Bool) -> some View {
        HStack(spacing: 0) {
            Text(row.symbol)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(width: QuarterlyWindowSize.symbolColumnWidth, alignment: .leading)

            dateCellView(isBreakout ? row.breakoutDate : row.breakdownDate)
                .frame(width: QuarterlyWindowSize.dateColumnWidth, alignment: .trailing)
            cellView(isBreakout ? row.breakoutPercent : row.breakdownPercent)
                .frame(width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)
            rsiCellView(row.rsi)
                .frame(width: QuarterlyWindowSize.rsiColumnWidth, alignment: .trailing)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(viewModel.highlightColor.opacity(
                    viewModel.highlightedSymbols.contains(row.symbol) ? viewModel.highlightOpacity : 0
                ))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleHighlight(for: row.symbol)
        }
    }

    private var pinnedColumnHeaders: some View {
        VStack(spacing: 0) {
            columnHeaders
            Divider()
        }
        .background(.background)
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            sortableHeader("Symbol", column: .symbol, width: QuarterlyWindowSize.symbolColumnWidth, alignment: .leading)

            if viewModel.isForwardPEMode {
                sortableHeader("Current", column: .currentPE, width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)
                ForEach(viewModel.quarters, id: \.identifier) { qi in
                    sortableHeader(qi.displayLabel, column: .quarter(qi.identifier), width: QuarterlyWindowSize.quarterColumnWidth, alignment: .trailing)
                }
            } else {
                sortableHeader("High", column: .highestClose, width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)
                ForEach(viewModel.quarters, id: \.identifier) { qi in
                    sortableHeader(qi.displayLabel, column: .quarter(qi.identifier), width: QuarterlyWindowSize.quarterColumnWidth, alignment: .trailing)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private func sortableHeader(_ title: String, column: QuarterlySortColumn, width: CGFloat, alignment: Alignment) -> some View {
        Button {
            viewModel.sort(by: column)
        } label: {
            HStack(spacing: 2) {
                if alignment == .trailing {
                    Spacer(minLength: 0)
                }
                Text(title)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                if viewModel.sortColumn == column {
                    Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
                if alignment == .leading {
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: alignment)
    }

    private func rowView(_ row: QuarterlyRow) -> some View {
        HStack(spacing: 0) {
            Text(row.symbol)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(width: QuarterlyWindowSize.symbolColumnWidth, alignment: .leading)

            if viewModel.isForwardPEMode {
                currentPECellView(row.currentForwardPE)
                    .frame(width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)

                ForEach(viewModel.quarters, id: \.identifier) { qi in
                    let currentValue = row.quarterChanges[qi.identifier] ?? nil
                    let priorValue = priorQuarterValue(for: qi, in: row)
                    peCellView(currentValue, priorValue: priorValue)
                        .frame(width: QuarterlyWindowSize.quarterColumnWidth, alignment: .trailing)
                }
            } else {
                cellView(row.highestCloseChangePercent)
                    .frame(width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)

                ForEach(viewModel.quarters, id: \.identifier) { qi in
                    cellView(row.quarterChanges[qi.identifier] ?? nil)
                        .frame(width: QuarterlyWindowSize.quarterColumnWidth, alignment: .trailing)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(viewModel.highlightColor.opacity(
                    viewModel.highlightedSymbols.contains(row.symbol) ? viewModel.highlightOpacity : 0
                ))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleHighlight(for: row.symbol)
        }
    }

    private func cellView(_ change: Double?) -> some View {
        Group {
            if let pct = change {
                Text(Formatting.signedPercent(pct, isPositive: pct >= 0))
                    .foregroundColor(cellColor(pct))
            } else {
                Text(QuarterlyFormatting.noData)
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(.body, design: .monospaced))
    }

    private func cellColor(_ pct: Double) -> Color {
        if abs(pct) < TradingHours.nearZeroThreshold { return .secondary }
        return pct > 0 ? .green : .red
    }

    private func dateCellView(_ date: String?) -> some View {
        Text(date ?? QuarterlyFormatting.noData)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.secondary)
    }

    private func rsiCellView(_ value: Double?) -> some View {
        Group {
            if let rsi = value {
                Text(String(format: "%.1f", rsi))
                    .foregroundColor(rsiColor(rsi))
            } else {
                Text(QuarterlyFormatting.noData)
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(.body, design: .monospaced))
    }

    private func rsiColor(_ rsi: Double) -> Color {
        if rsi > 70 { return .red }
        if rsi < 30 { return .green }
        return .secondary
    }

    // MARK: - Header Helpers

    private var symbolCountText: String {
        if viewModel.isPriceBreaksMode {
            return "\(viewModel.breakoutRows.count) breakout, \(viewModel.breakdownRows.count) breakdown"
        }
        return "\(viewModel.rows.count) symbols"
    }

    // MARK: - Forward P/E Cell Views

    private var headerDescription: String {
        switch viewModel.viewMode {
        case .sinceQuarter:
            return "Percent change from each quarter's open to current price"
        case .duringQuarter:
            return "Percent change from start to end of each quarter"
        case .forwardPE:
            return "Forward P/E ratio as of each quarter end"
        case .priceBreaks:
            return "Breakout: % from highest significant high. Breakdown: % from lowest significant low. Swing analysis over trailing 3 years."
        }
    }

    private var highColumnDescription: String {
        if viewModel.isForwardPEMode {
            return "Current: latest forward P/E from most recent quote"
        }
        if viewModel.isPriceBreaksMode {
            return ""
        }
        return "High: percent from highest daily close over trailing 3 years"
    }

    private func peCellView(_ value: Double?, priorValue: Double?) -> some View {
        Group {
            if let pe = value {
                Text(String(format: "%.1f", pe))
                    .foregroundColor(peChangeColor(current: pe, prior: priorValue))
            } else {
                Text(QuarterlyFormatting.noData)
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(.body, design: .monospaced))
    }

    private func currentPECellView(_ value: Double?) -> some View {
        Group {
            if let pe = value {
                Text(String(format: "%.1f", pe))
                    .foregroundColor(.secondary)
            } else {
                Text(QuarterlyFormatting.noData)
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(.body, design: .monospaced))
    }

    private func peChangeColor(current: Double, prior: Double?) -> Color {
        guard let prior else { return .secondary }
        let diff = current - prior
        if abs(diff) < TradingHours.nearZeroThreshold { return .secondary }
        return diff < 0 ? .green : .red  // Lower P/E = green (cheaper), higher = red
    }

    private func priorQuarterValue(for qi: QuarterInfo, in row: QuarterlyRow) -> Double? {
        let quarters = viewModel.quarters
        guard let currentIndex = quarters.firstIndex(where: { $0.identifier == qi.identifier }),
              currentIndex + 1 < quarters.count else { return nil }
        let priorQI = quarters[currentIndex + 1]
        return row.quarterChanges[priorQI.identifier] ?? nil
    }
}

// MARK: - Window Controller

@MainActor
class QuarterlyPanelWindowController {
    private var window: NSWindow?
    private var viewModel: QuarterlyPanelViewModel?

    func showWindow(
        watchlist: [String],
        quotes: [String: StockQuote],
        quarterPrices: [String: [String: Double]],
        quarterInfos: [QuarterInfo],
        highlightedSymbols: Set<String> = [],
        highlightColor: String = "yellow",
        highlightOpacity: Double = 0.25,
        highestClosePrices: [String: Double] = [:],
        forwardPEData: [String: [String: Double]] = [:],
        currentForwardPEs: [String: Double] = [:],
        swingLevelEntries: [String: SwingLevelCacheEntry] = [:],
        rsiValues: [String: Double] = [:]
    ) {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vm = QuarterlyPanelViewModel()
        vm.setupHighlights(symbols: highlightedSymbols, color: highlightColor, opacity: highlightOpacity)
        vm.update(watchlist: watchlist, quotes: quotes, quarterPrices: quarterPrices, quarterInfos: quarterInfos, highestClosePrices: highestClosePrices, forwardPEData: forwardPEData, currentForwardPEs: currentForwardPEs, swingLevelEntries: swingLevelEntries, rsiValues: rsiValues)
        self.viewModel = vm

        let panelView = QuarterlyPanelView(viewModel: vm)
        let hostingView = NSHostingView(rootView: panelView)
        hostingView.autoresizingMask = [.width, .height]

        let opaqueContainer = OpaqueContainerView(frame: NSRect(
            x: 0, y: 0,
            width: QuarterlyWindowSize.width,
            height: QuarterlyWindowSize.height
        ))
        hostingView.frame = opaqueContainer.bounds
        opaqueContainer.addSubview(hostingView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: QuarterlyWindowSize.width, height: QuarterlyWindowSize.height),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = "Extra Stats"
        newWindow.contentView = opaqueContainer
        newWindow.isOpaque = true
        newWindow.backgroundColor = .windowBackgroundColor
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }

    func refresh(quotes: [String: StockQuote], quarterPrices: [String: [String: Double]], highestClosePrices: [String: Double] = [:], forwardPEData: [String: [String: Double]] = [:], currentForwardPEs: [String: Double] = [:], swingLevelEntries: [String: SwingLevelCacheEntry] = [:], rsiValues: [String: Double] = [:]) {
        guard let window = window, window.isVisible else { return }
        viewModel?.refresh(quotes: quotes, quarterPrices: quarterPrices, highestClosePrices: highestClosePrices, forwardPEData: forwardPEData, currentForwardPEs: currentForwardPEs, swingLevelEntries: swingLevelEntries, rsiValues: rsiValues)
    }
}
