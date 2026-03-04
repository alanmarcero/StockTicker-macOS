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
            } else if viewModel.shouldShowEmptyState {
                emptyState
            } else {
                scrollableContent
            }
        }
        .frame(minWidth: QuarterlyWindowSize.minWidth, minHeight: QuarterlyWindowSize.minHeight)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Extra Stats")
                .font(.headline)
            Picker("View Mode", selection: Binding(
                get: { viewModel.viewMode },
                set: { viewModel.switchMode($0) }
            )) {
                ForEach(QuarterlyViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            if !viewModel.hasFinnhubApiKey {
                Text("No Finnhub API key found")
                    .foregroundColor(.red)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Text(headerDescription)
                .foregroundColor(.secondary)
                .font(.caption)
            if !highColumnDescription.isEmpty {
                Text(highColumnDescription)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            if !belowColumnDescription.isEmpty {
                Text(belowColumnDescription)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            filterBar
        }
        .padding()
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            TextField("Search symbol", text: $viewModel.filterText)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(width: 120)
                .onChange(of: viewModel.filterText) { _ in
                    viewModel.rebuildRows()
                }

            filterToggle("ETFs", filter: .etf)
            filterToggle("Assets", filter: .asset)

            if !viewModel.filterText.isEmpty || !viewModel.typeFilter.isEmpty {
                Button("Clear") {
                    viewModel.filterText = ""
                    viewModel.typeFilter = []
                    viewModel.rebuildRows()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            Spacer()
        }
    }

    private func filterToggle(_ label: String, filter: TickerFilter) -> some View {
        let isActive = viewModel.typeFilter.contains(filter)
        return Button(label) {
            if isActive {
                viewModel.typeFilter = []
            } else {
                viewModel.typeFilter = filter
            }
            viewModel.rebuildRows()
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(isActive ? Color.accentColor.opacity(0.25) : Color.clear)
        )
        .overlay(
            Capsule()
                .strokeBorder(isActive ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .buttonStyle(.plain)
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
                emaTable("Closing Above 5D", rows: viewModel.emaDayRows, columnLabel: "Days Above", suffix: "d")
                Divider()
                emaTable("Closing Above 5W", rows: viewModel.emaWeekRows, columnLabel: "Wks Above", suffix: "w")
                Divider()
                emaCrossTable("5W Closing Cross Above", rows: viewModel.emaCrossRows, columnLabel: "Wks Below")
                Divider()
                emaCrossTable("5W Closing Cross Below", rows: viewModel.emaCrossdownRows, columnLabel: "Wks Above")
                Divider()
                emaCrossTable("Closing Below 5W", rows: viewModel.emaBelowRows, columnLabel: "Wks Below")
            }
        } else if viewModel.isPriceBreaksMode {
            HStack(alignment: .top, spacing: 0) {
                priceBreaksTable("Breakout", rows: viewModel.breakoutRows, isBreakout: true)
                Divider()
                priceBreaksTable("Breakdown", rows: viewModel.breakdownRows, isBreakout: false)
            }
        } else if viewModel.isVIXSpikesMode {
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header: vixSpikePinnedHeaders) {
                        ForEach(viewModel.rows) { row in
                            vixSpikeRowView(row)
                            Divider().opacity(0.3)
                        }
                    }
                }
                .padding(.horizontal, 8)
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
        .overlay(contextMenuOverlay(for: row.symbol))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleHighlight(for: row.symbol)
        }
        .contextMenu { watchlistContextMenu(for: row.symbol) }
    }

    private func emaTable(_ title: String, rows: [QuarterlyRow], columnLabel: String, suffix: String) -> some View {
        ScrollView([.vertical]) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section(header: emaPinnedHeaders(title, columnLabel: columnLabel)) {
                    ForEach(rows) { row in
                        emaRowView(row, suffix: suffix)
                        Divider().opacity(0.3)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func emaPinnedHeaders(_ title: String, columnLabel: String) -> some View {
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
                sortableHeader(columnLabel, column: .priceBreakPercent, width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            Divider()
        }
        .background(.background)
    }

    private func emaRowView(_ row: QuarterlyRow, suffix: String) -> some View {
        HStack(spacing: 0) {
            Text(row.symbol)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(width: QuarterlyWindowSize.symbolColumnWidth, alignment: .leading)

            Group {
                if let count = row.breakoutPercent {
                    Text("\(Int(count))\(suffix)")
                        .foregroundColor(.green)
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
        .overlay(contextMenuOverlay(for: row.symbol))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleHighlight(for: row.symbol)
        }
        .contextMenu { watchlistContextMenu(for: row.symbol) }
    }

    private func emaCrossTable(_ title: String, rows: [QuarterlyRow], columnLabel: String) -> some View {
        ScrollView([.vertical]) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section(header: emaCrossPinnedHeaders(title, columnLabel: columnLabel)) {
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

    private func emaCrossPinnedHeaders(_ title: String, columnLabel: String) -> some View {
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
                sortableHeader(columnLabel, column: .priceBreakPercent, width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)
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
                        .foregroundColor(.green)
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
        .overlay(contextMenuOverlay(for: row.symbol))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleHighlight(for: row.symbol)
        }
        .contextMenu { watchlistContextMenu(for: row.symbol) }
    }

    // MARK: - VIX Spike Views

    private var vixSpikePinnedHeaders: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sortableHeader("Symbol", column: .symbol, width: QuarterlyWindowSize.symbolColumnWidth, alignment: .leading)
                sortableHeader("High", column: .highestClose, width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)
                ForEach(Array(viewModel.vixSpikeHeaders.enumerated()), id: \.element.dateString) { _, spike in
                    sortableHeader(
                        "\(spike.dateString) (\(String(format: "%.1f", spike.vixClose)))",
                        column: .quarter(spike.dateString),
                        width: QuarterlyWindowSize.quarterColumnWidth + 20,
                        alignment: .trailing
                    )
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            Divider()
        }
        .background(.background)
    }

    private func vixSpikeRowView(_ row: QuarterlyRow) -> some View {
        HStack(spacing: 0) {
            Text(row.symbol)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(width: QuarterlyWindowSize.symbolColumnWidth, alignment: .leading)

            highCellView(row.highestCloseChangePercent)
                .frame(width: QuarterlyWindowSize.highColumnWidth, alignment: .trailing)

            ForEach(Array(viewModel.vixSpikeHeaders.enumerated()), id: \.element.dateString) { _, spike in
                cellView(row.quarterChanges[spike.dateString] ?? nil)
                    .frame(width: QuarterlyWindowSize.quarterColumnWidth + 20, alignment: .trailing)
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
        .overlay(contextMenuOverlay(for: row.symbol))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleHighlight(for: row.symbol)
        }
        .contextMenu { watchlistContextMenu(for: row.symbol) }
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
                    Image(systemName: viewModel.isSortAscending ? "chevron.up" : "chevron.down")
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

    @ViewBuilder
    private func watchlistContextMenu(for symbol: String) -> some View {
        if viewModel.isInPersonalWatchlist(symbol) {
            Button("Remove from My Watchlist") {
                viewModel.removeFromWatchlist(symbol)
                viewModel.setContextMenuSymbol(symbol)
            }
        } else {
            Button("Add to My Watchlist") {
                viewModel.addToWatchlist(symbol)
                viewModel.setContextMenuSymbol(symbol)
            }
        }
    }

    private func contextMenuOverlay(for symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.accentColor.opacity(viewModel.contextMenuSymbol == symbol ? 0.2 : 0))
            .animation(.easeInOut(duration: 0.15), value: viewModel.contextMenuSymbol)
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
        .overlay(contextMenuOverlay(for: row.symbol))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleHighlight(for: row.symbol)
        }
        .contextMenu { watchlistContextMenu(for: row.symbol) }
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
            return "Closing Above: price above the 5-period EMA with at least 1 consecutive close above (count = consecutive closes above)."
        case .vixSpikes:
            return "Percent gain from each symbol's close on the VIX spike date to current price. Spike = peak VIX close in a cluster of days >= $20."
        case .miscStats:
            return "Aggregate statistics across the \(viewModel.isUniverseActive ? "universe" : "watchlist"). Updated every \(viewModel.refreshInterval)s."
        }
    }

    private var highColumnDescription: String {
        if viewModel.isForwardPEMode {
            return "Current: latest forward P/E from most recent quote"
        }
        if viewModel.isEMAsMode {
            return "Closing Cross: weekly close reversal after 3+ weeks on the other side. Crosses recalculate Fridays at 2 PM ET."
        }
        if viewModel.isPriceBreaksMode || viewModel.isMiscStatsMode || viewModel.isVIXSpikesMode {
            return ""
        }
        return "High: percent from highest daily close over trailing 3 years"
    }

    private var belowColumnDescription: String {
        if viewModel.isEMAsMode {
            return "Closing Below: weekly close below 5-week EMA for 3+ consecutive weeks."
        }
        return ""
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
        quarterInfos: [QuarterInfo],
        highlightedSymbols: Set<String> = [],
        highlightColor: String = "yellow",
        highlightOpacity: Double = 0.25,
        data: QuarterlyPanelData,
        personalWatchlist: Set<String> = [],
        onWatchlistChange: ((String, Bool) -> Void)? = nil,
        isUniverseActive: Bool = false,
        refreshInterval: Int = 15,
        hasFinnhubApiKey: Bool = true
    ) {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vm = QuarterlyPanelViewModel()
        vm.setupHighlights(symbols: highlightedSymbols, color: highlightColor, opacity: highlightOpacity)
        vm.onWatchlistChange = onWatchlistChange
        vm.update(watchlist: watchlist, quarterInfos: quarterInfos, data: data, personalWatchlist: personalWatchlist, isUniverseActive: isUniverseActive, refreshInterval: refreshInterval, hasFinnhubApiKey: hasFinnhubApiKey)
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

    func refresh(data: QuarterlyPanelData, personalWatchlist: Set<String>? = nil) {
        guard let window = window, window.isVisible else { return }
        viewModel?.refresh(data: data, personalWatchlist: personalWatchlist)
    }
}
