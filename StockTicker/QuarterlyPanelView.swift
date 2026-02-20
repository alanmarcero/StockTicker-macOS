import SwiftUI
import AppKit

// MARK: - Quarterly Panel View

struct QuarterlyPanelView: View {
    @ObservedObject var viewModel: QuarterlyPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if viewModel.isMiscStatsMode {
                miscStatsView
            } else if viewModel.isPriceBreaksMode ? (viewModel.breakoutRows.isEmpty && viewModel.breakdownRows.isEmpty) : viewModel.isEMAsMode ? (viewModel.emaDayRows.isEmpty && viewModel.emaWeekRows.isEmpty && viewModel.emaCrossRows.isEmpty && viewModel.emaBelowRows.isEmpty) : viewModel.rows.isEmpty {
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
        if viewModel.isEMAsMode {
            HStack(alignment: .top, spacing: 0) {
                emaTable("5-Day", rows: viewModel.emaDayRows)
                Divider()
                emaTable("5-Week", rows: viewModel.emaWeekRows)
                Divider()
                emaCrossTable("5W Cross", rows: viewModel.emaCrossRows)
                Divider()
                emaCrossTable("Below 5W", rows: viewModel.emaBelowRows)
            }
        } else if viewModel.isPriceBreaksMode {
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

    private var miscStatsView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(viewModel.miscStats) { stat in
                    HStack {
                        Text(stat.description)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(stat.value)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    Divider().opacity(0.3)
                }
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

    private func emaTable(_ title: String, rows: [QuarterlyRow]) -> some View {
        ScrollView([.vertical]) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section(header: emaPinnedHeaders(title)) {
                    ForEach(rows) { row in
                        emaRowView(row)
                        Divider().opacity(0.3)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func emaPinnedHeaders(_ title: String) -> some View {
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
                sortableHeader("%", column: .priceBreakPercent, width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            Divider()
        }
        .background(.background)
    }

    private func emaRowView(_ row: QuarterlyRow) -> some View {
        HStack(spacing: 0) {
            Text(row.symbol)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(width: QuarterlyWindowSize.symbolColumnWidth, alignment: .leading)

            cellView(row.breakoutPercent)
                .frame(width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)

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

    private func emaCrossTable(_ title: String, rows: [QuarterlyRow]) -> some View {
        ScrollView([.vertical]) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section(header: emaCrossPinnedHeaders(title)) {
                    ForEach(rows) { row in
                        emaCrossRowView(row)
                        Divider().opacity(0.3)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func emaCrossPinnedHeaders(_ title: String) -> some View {
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
                sortableHeader("Wks", column: .priceBreakPercent, width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            Divider()
        }
        .background(.background)
    }

    private func emaCrossRowView(_ row: QuarterlyRow) -> some View {
        HStack(spacing: 0) {
            Text(row.symbol)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(width: QuarterlyWindowSize.symbolColumnWidth, alignment: .leading)

            Group {
                if let weeks = row.breakoutPercent {
                    Text("\(Int(weeks))w")
                        .foregroundColor(Int(weeks) > 0 ? .green : .secondary)
                } else {
                    Text(QuarterlyFormatting.noData)
                        .foregroundColor(.secondary)
                }
            }
            .font(.system(.body, design: .monospaced))
            .frame(width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)

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
                highCellView(row.highestCloseChangePercent)
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

    private func highCellView(_ change: Double?) -> some View {
        Group {
            if let pct = change {
                Text(Formatting.signedPercent(pct, isPositive: pct >= 0))
                    .foregroundColor(pct >= -5.0 ? .green : .red)
            } else {
                Text(QuarterlyFormatting.noData)
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(.body, design: .monospaced))
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
        if viewModel.isMiscStatsMode {
            return "\(viewModel.miscStats.count) stats"
        }
        if viewModel.isEMAsMode {
            return "\(viewModel.emaDayRows.count) day, \(viewModel.emaWeekRows.count) week, \(viewModel.emaCrossRows.count) cross, \(viewModel.emaBelowRows.count) below"
        }
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
        case .emas:
            return "Symbols whose current price is above the 5-period EMA. 5W Cross: weekly close crossed above 5-week EMA."
        case .miscStats:
            return "Aggregate statistics across the \(viewModel.isUniverseActive ? "universe" : "watchlist")"
        }
    }

    private var highColumnDescription: String {
        if viewModel.isForwardPEMode {
            return "Current: latest forward P/E from most recent quote"
        }
        if viewModel.isPriceBreaksMode || viewModel.isEMAsMode || viewModel.isMiscStatsMode {
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

    var isWindowVisible: Bool {
        window?.isVisible ?? false
    }

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
        rsiValues: [String: Double] = [:],
        emaEntries: [String: EMACacheEntry] = [:],
        isUniverseActive: Bool = false
    ) {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vm = QuarterlyPanelViewModel()
        vm.setupHighlights(symbols: highlightedSymbols, color: highlightColor, opacity: highlightOpacity)
        vm.update(watchlist: watchlist, quotes: quotes, quarterPrices: quarterPrices, quarterInfos: quarterInfos, highestClosePrices: highestClosePrices, forwardPEData: forwardPEData, currentForwardPEs: currentForwardPEs, swingLevelEntries: swingLevelEntries, rsiValues: rsiValues, emaEntries: emaEntries, isUniverseActive: isUniverseActive)
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

    func refresh(quotes: [String: StockQuote], quarterPrices: [String: [String: Double]], highestClosePrices: [String: Double] = [:], forwardPEData: [String: [String: Double]] = [:], currentForwardPEs: [String: Double] = [:], swingLevelEntries: [String: SwingLevelCacheEntry] = [:], rsiValues: [String: Double] = [:], emaEntries: [String: EMACacheEntry] = [:]) {
        guard let window = window, window.isVisible else { return }
        viewModel?.refresh(quotes: quotes, quarterPrices: quarterPrices, highestClosePrices: highestClosePrices, forwardPEData: forwardPEData, currentForwardPEs: currentForwardPEs, swingLevelEntries: swingLevelEntries, rsiValues: rsiValues, emaEntries: emaEntries)
    }
}
