import SwiftUI

// MARK: - Equatable Ticker Row

struct TickerRowData: Equatable {
    let symbol: String
    let hasValidQuote: Bool
    let displayColor: Color
    let paddedSymbol: String
    let paddedMarketCap: String
    let paddedChangePercent: String
    let ytdText: String?
    let ytdColor: Color
    let highText: String?
    let highColor: Color
    let lowText: String?
    let lowColor: Color
    let extHoursText: String?
    let extHoursColor: Color
    let highlightIntensity: CGFloat
    let highlightBgColor: Color
    let isPersistentHighlighted: Bool
    let persistentHighlightColor: Color
    let persistentHighlightOpacity: Double

    static func from(
        symbol: String,
        quote: StockQuote?,
        intensity: CGFloat,
        isPersistentHighlighted: Bool,
        highlightColor: String,
        highlightOpacity: Double
    ) -> TickerRowData {
        let hasValid = quote.map { !$0.isPlaceholder } ?? false
        let validQuote: StockQuote? = hasValid ? quote : nil

        return TickerRowData(
            symbol: symbol,
            hasValidQuote: hasValid,
            displayColor: validQuote?.swiftUIDisplayColor ?? .secondary,
            paddedSymbol: padded(symbol, to: LayoutConfig.Ticker.symbolWidth),
            paddedMarketCap: padded(validQuote?.formattedMarketCap ?? "", to: LayoutConfig.Ticker.marketCapWidth),
            paddedChangePercent: padded(validQuote?.formattedChangePercent ?? "", to: LayoutConfig.Ticker.percentWidth),
            ytdText: validQuote?.formattedYTDChangePercent.map { padded("YTD: \($0)", to: LayoutConfig.Ticker.ytdWidth) },
            ytdColor: validQuote?.swiftUIYTDColor ?? .secondary,
            highText: validQuote?.formattedHighestCloseChangePercent.map { padded("High: \($0)", to: LayoutConfig.Ticker.highWidth) },
            highColor: validQuote?.swiftUIHighestCloseColor ?? .secondary,
            lowText: validQuote?.formattedLowestCloseChangePercent.map { padded("Low: \($0)", to: LayoutConfig.Ticker.lowWidth) },
            lowColor: validQuote?.swiftUILowestCloseColor ?? .secondary,
            extHoursText: buildExtHoursText(quote: validQuote),
            extHoursColor: buildExtHoursColor(quote: validQuote),
            highlightIntensity: intensity,
            highlightBgColor: validQuote.map { Color(nsColor: $0.highlightColor) } ?? .clear,
            isPersistentHighlighted: isPersistentHighlighted,
            persistentHighlightColor: ColorMapping.color(from: highlightColor),
            persistentHighlightOpacity: highlightOpacity
        )
    }

    private static func buildExtHoursText(quote: StockQuote?) -> String? {
        guard let validQuote = quote, validQuote.isInExtendedHoursPeriod(), let label = validQuote.extendedHoursPeriodLabel() else { return nil }
        if validQuote.shouldShowExtendedHours(), let ext = validQuote.formattedExtendedHoursChangePercent {
            return "  \(label): \(ext)"
        }
        return "  \(label): --"
    }

    private static func buildExtHoursColor(quote: StockQuote?) -> Color {
        guard let validQuote = quote, validQuote.isInExtendedHoursPeriod(), validQuote.extendedHoursPeriodLabel() != nil else { return .secondary }
        if validQuote.shouldShowExtendedHours(), validQuote.formattedExtendedHoursChangePercent != nil {
            return validQuote.swiftUIExtendedHoursColor
        }
        return .secondary
    }

    private static func padded(_ string: String, to length: Int) -> String {
        string.count >= length ? string : string.padding(toLength: length, withPad: " ", startingAt: 0)
    }
}

struct TickerRowView: View, Equatable {
    let data: TickerRowData
    let onTap: () -> Void

    static func == (lhs: TickerRowView, rhs: TickerRowView) -> Bool {
        lhs.data == rhs.data
    }

    var body: some View {
        Button { onTap() } label: { content }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .background(background)
    }

    private var content: some View {
        HStack(spacing: 0) {
            if data.hasValidQuote {
                Text(data.paddedSymbol)
                    .foregroundColor(data.displayColor)
                Text(" ")
                Text(data.paddedMarketCap)
                    .foregroundColor(data.displayColor)
                Text(" ")
                Text(data.paddedChangePercent)
                    .foregroundColor(data.displayColor)

                if let ytd = data.ytdText {
                    Text("  ")
                    Text(ytd)
                        .foregroundColor(data.ytdColor)
                }
                if let high = data.highText {
                    Text("  ")
                    Text(high)
                        .foregroundColor(data.highColor)
                }
                if let low = data.lowText {
                    Text("  ")
                    Text(low)
                        .foregroundColor(data.lowColor)
                }
                if let ext = data.extHoursText {
                    Text(ext)
                        .foregroundColor(data.extHoursColor)
                }
            } else {
                Text("\(data.symbol) --")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .font(.system(size: LayoutConfig.Font.size, design: .monospaced))
    }

    private var background: some View {
        Group {
            if data.highlightIntensity > 0.01, data.hasValidQuote {
                data.highlightBgColor
                    .opacity(Double(data.highlightIntensity) * 0.6)
            } else if data.isPersistentHighlighted {
                data.persistentHighlightColor
                    .opacity(data.persistentHighlightOpacity)
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Popover Content View

struct PopoverContentView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            controlsSection
            Divider()
            if controller.config.showNewsHeadlines {
                newsSection
                Divider()
            }
            tickerList
            Divider()
            footerSection
        }
        .frame(width: LayoutConfig.Popover.width, height: LayoutConfig.Popover.height)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            marketStatusRow
                .padding(.horizontal, 12)
            MarqueeViewRepresentable(marqueeView: controller.marqueeView ?? MarqueeView(frame: .zero))
                .frame(maxWidth: .infinity)
                .frame(height: LayoutConfig.Marquee.height)
        }
        .padding(.vertical, 8)
    }

    private var marketStatusRow: some View {
        HStack(spacing: 4) {
            Text("NYSE:")
                .font(.system(size: LayoutConfig.Font.headerSize, weight: .medium))
            Circle()
                .fill(controller.marketStatusState.swiftUIColor)
                .frame(width: 8, height: 8)
            Text(controller.marketStatusState.rawValue)
                .font(.system(size: LayoutConfig.Font.headerSize, weight: .bold))
                .foregroundColor(controller.marketStatusState.swiftUIColor)
            Text("\u{2022}")
                .foregroundColor(.secondary)
            let scheduleString = controller.marketHolidayName.map {
                "\(controller.marketScheduleText) (\($0))"
            } ?? controller.marketScheduleText
            Text(scheduleString)
                .font(.system(size: LayoutConfig.Font.scheduleSize))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 6) {
            sourceToggles
            filterRow
            sortAndClosedMarketRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var sourceToggles: some View {
        HStack(spacing: 6) {
            capsuleToggle(
                "All",
                isActive: controller.currentWatchlistSource == .allSources,
                action: { controller.selectAllSources() }
            )
            ForEach(WatchlistSource.allCases, id: \.rawValue) { source in
                capsuleToggle(
                    source.displayName,
                    isActive: controller.currentWatchlistSource.contains(source),
                    action: { controller.toggleSource(source) }
                )
            }
            capsuleToggle(
                "None",
                isActive: controller.currentWatchlistSource.isEmpty,
                action: { controller.clearAllSources() }
            )
            Spacer()
        }
    }

    private var filterRow: some View {
        HStack(spacing: 6) {
            ForEach(TickerFilter.greenOptions, id: \.rawValue) { filter in
                capsuleToggle(
                    filter.displayName,
                    isActive: controller.currentFilter.contains(filter)
                ) {
                    controller.toggleFilter(filter)
                }
            }
            ForEach(TickerFilter.redOptions, id: \.rawValue) { filter in
                capsuleToggle(
                    filter.displayName,
                    isActive: controller.currentFilter.contains(filter)
                ) {
                    controller.toggleFilter(filter)
                }
            }
            ForEach(TickerFilter.typeOptions, id: \.rawValue) { filter in
                capsuleToggle(
                    filter.displayName,
                    isActive: controller.currentFilter.contains(filter)
                ) {
                    controller.toggleFilter(filter)
                }
            }
            if !controller.currentFilter.isEmpty || controller.currentWatchlistSource != .allSources {
                Button("Clear") {
                    controller.clearFilters()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            Spacer()
        }
    }

    private var sortAndClosedMarketRow: some View {
        HStack(spacing: 12) {
            sortPicker
            cyclingModePicker
            closedMarketPicker
            Spacer()
        }
    }

    private var sortPicker: some View {
        HStack(spacing: 4) {
            Text("Sort:")
                .font(.caption)
                .foregroundColor(.secondary)
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    if !option.isExtendedHoursSort || isExtendedHoursSession {
                        Button {
                            controller.selectSortOption(option)
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if option == controller.currentSortOption {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                Text(controller.currentSortOption.rawValue)
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var cyclingModePicker: some View {
        HStack(spacing: 4) {
            Text("Cycling:")
                .font(.caption)
                .foregroundColor(.secondary)
            Menu {
                ForEach(MenuBarCyclingMode.allCases, id: \.self) { mode in
                    Button {
                        controller.selectCyclingMode(mode)
                    } label: {
                        HStack {
                            Text(mode.displayName)
                            if mode == controller.config.menuBarCyclingMode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(controller.config.menuBarCyclingMode.displayName)
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var closedMarketPicker: some View {
        HStack(spacing: 4) {
            Text("Closed Mkt:")
                .font(.caption)
                .foregroundColor(.secondary)
            Menu {
                ForEach(ClosedMarketAsset.allCases, id: \.self) { asset in
                    Button {
                        controller.selectClosedMarketAsset(asset)
                    } label: {
                        HStack {
                            Text(asset.displayName)
                            if asset == controller.config.menuBarAssetWhenClosed {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(controller.config.menuBarAssetWhenClosed.displayName)
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var isExtendedHoursSession: Bool {
        controller.marketStatusState == .preMarket || controller.marketStatusState == .afterHours
    }

    // MARK: - News

    private var newsSection: some View {
        VStack(spacing: 2) {
            if controller.newsItems.isEmpty {
                Text("No news available")
                    .font(.system(size: LayoutConfig.Font.size))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(controller.newsItems.prefix(6)) { item in
                    newsRow(item)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func newsRow(_ item: NewsItem) -> some View {
        let maxLength = LayoutConfig.Headlines.maxLength
        let headline = item.headline.count > maxLength
            ? String(item.headline.prefix(maxLength - 3)) + "..."
            : item.headline

        return Button {
            controller.openNewsArticle(item)
        } label: {
            Text(headline)
                .font(item.isTopFromSource ? .system(size: 11, weight: .bold) : .system(size: 11))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 1)
                .background(
                    item.isTopFromSource
                        ? ColorMapping.color(from: controller.config.highlightColor)
                            .opacity(controller.config.highlightOpacity)
                        : Color.clear
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ticker List

    private var tickerList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(controller.sortedFilteredSymbols, id: \.self) { symbol in
                    let data = TickerRowData.from(
                        symbol: symbol,
                        quote: controller.quotes[symbol],
                        intensity: controller.highlightIntensity[symbol] ?? 0,
                        isPersistentHighlighted: controller.config.highlightedSymbols.contains(symbol),
                        highlightColor: controller.config.highlightColor,
                        highlightOpacity: controller.config.highlightOpacity
                    )
                    TickerRowView(data: data) {
                        controller.openYahooFinance(symbol: symbol)
                    }
                    .equatable()
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 12) {
            Button("Edit Watchlist") { controller.editWatchlistHere() }
            Button("Extra Stats") { controller.showQuarterlyPanel() }
            configMenu
            cacheMenu
            Spacer()
            Button("API Errors") { controller.showDebugWindow() }
            Button("Quit") { controller.quitApp() }
        }
        .font(.system(size: 12))
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var configMenu: some View {
        Menu("Config") {
            Button("Edit Config...") { controller.editConfigJson() }
            Button("Reset Config to Default") { controller.resetConfigToDefault() }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var cacheMenu: some View {
        Menu("Cache") {
            Button("Clear All Caches") { controller.clearAllCaches() }
            Button("Clear 5-EMA Cache") { controller.clearEMACache() }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Helpers

    private func capsuleToggle(
        _ label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Text(label)
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
            .onTapGesture { action() }
    }

}
