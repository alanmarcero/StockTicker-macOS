import SwiftUI
import AppKit

// MARK: - Constants

private enum QuarterlyWindowSize {
    static let width = LayoutConfig.QuarterlyWindow.width
    static let height = LayoutConfig.QuarterlyWindow.height
    static let minWidth = LayoutConfig.QuarterlyWindow.minWidth
    static let minHeight = LayoutConfig.QuarterlyWindow.minHeight
    static let symbolColumnWidth = LayoutConfig.QuarterlyWindow.symbolColumnWidth
    static let quarterColumnWidth = LayoutConfig.QuarterlyWindow.quarterColumnWidth
}

private enum QuarterlyFormatting {
    static let noData = "--"
}

// MARK: - View Mode

enum QuarterlyViewMode: String, CaseIterable {
    case sinceQuarter = "Since Quarter"
    case duringQuarter = "During Quarter"
}

// MARK: - Row Model

struct QuarterlyRow: Identifiable {
    let id: String
    let symbol: String
    let quarterChanges: [String: Double?]  // quarter identifier -> percent change
}

// MARK: - Sort Column

enum QuarterlySortColumn: Equatable {
    case symbol
    case quarter(String)  // quarter identifier
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

    private var storedWatchlist: [String] = []
    private var storedQuotes: [String: StockQuote] = [:]
    private var storedQuarterPrices: [String: [String: Double]] = [:]

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

    func update(watchlist: [String], quotes: [String: StockQuote], quarterPrices: [String: [String: Double]], quarterInfos: [QuarterInfo]) {
        self.quarters = quarterInfos
        self.storedWatchlist = watchlist
        self.storedQuotes = quotes
        self.storedQuarterPrices = quarterPrices

        rows = buildRows(for: viewMode)
        applySorting()
    }

    func refresh(quotes: [String: StockQuote], quarterPrices: [String: [String: Double]]) {
        guard !quarters.isEmpty else { return }

        self.storedQuotes = quotes
        self.storedQuarterPrices = quarterPrices

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
            return QuarterlyRow(id: symbol, symbol: symbol, quarterChanges: changes)
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
            return QuarterlyRow(id: symbol, symbol: symbol, quarterChanges: changes)
        }
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

    private func applySorting() {
        rows.sort { a, b in
            let result: Bool
            switch sortColumn {
            case .symbol:
                result = a.symbol < b.symbol
            case .quarter(let qId):
                let aVal = a.quarterChanges[qId] ?? nil
                let bVal = b.quarterChanges[qId] ?? nil
                switch (aVal, bVal) {
                case let (av?, bv?): result = av < bv
                case (nil, .some): result = true   // nil sorts first
                case (.some, nil): result = false
                case (nil, nil): result = a.symbol < b.symbol
                }
            }
            return sortAscending ? result : !result
        }
    }
}

// MARK: - Quarterly Panel View

struct QuarterlyPanelView: View {
    @ObservedObject var viewModel: QuarterlyPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if viewModel.rows.isEmpty {
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
                Text("Quarterly Performance")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.rows.count) symbols")
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
            Text(viewModel.viewMode == .sinceQuarter
                 ? "Percent change from each quarter's open to current price"
                 : "Percent change from start to end of each quarter")
                .foregroundColor(.secondary)
                .font(.caption)
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

    private var scrollableContent: some View {
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

            ForEach(viewModel.quarters, id: \.identifier) { qi in
                sortableHeader(qi.displayLabel, column: .quarter(qi.identifier), width: QuarterlyWindowSize.quarterColumnWidth, alignment: .trailing)
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

            ForEach(viewModel.quarters, id: \.identifier) { qi in
                cellView(row.quarterChanges[qi.identifier] ?? nil)
                    .frame(width: QuarterlyWindowSize.quarterColumnWidth, alignment: .trailing)
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
        highlightOpacity: Double = 0.25
    ) {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vm = QuarterlyPanelViewModel()
        vm.setupHighlights(symbols: highlightedSymbols, color: highlightColor, opacity: highlightOpacity)
        vm.update(watchlist: watchlist, quotes: quotes, quarterPrices: quarterPrices, quarterInfos: quarterInfos)
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

        newWindow.title = "Quarterly Performance"
        newWindow.contentView = opaqueContainer
        newWindow.isOpaque = true
        newWindow.backgroundColor = .windowBackgroundColor
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }

    func refresh(quotes: [String: StockQuote], quarterPrices: [String: [String: Double]]) {
        guard let window = window, window.isVisible else { return }
        viewModel?.refresh(quotes: quotes, quarterPrices: quarterPrices)
    }
}
