import SwiftUI

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
            Text(controller.countdownText)
                .font(.system(size: LayoutConfig.Font.scheduleSize, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            MarqueeViewRepresentable(marqueeView: controller.marqueeView ?? MarqueeView(frame: .zero))
                .frame(width: LayoutConfig.Marquee.width, height: LayoutConfig.Marquee.height)
        }
        .padding(.horizontal, 12)
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
            filterRow
            sortAndClosedMarketRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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
            ForEach(TickerFilter.typeOptions, id: \.rawValue) { filter in
                capsuleToggle(
                    filter.displayName,
                    isActive: controller.currentFilter.contains(filter)
                ) {
                    controller.toggleFilter(filter)
                }
            }
            if !controller.currentFilter.isEmpty {
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
                    tickerRow(symbol: symbol)
                }
            }
        }
    }

    private func tickerRow(symbol: String) -> some View {
        let quote = controller.quotes[symbol]
        let intensity = controller.highlightIntensity[symbol] ?? 0
        let isPersistentHighlighted = controller.config.highlightedSymbols.contains(symbol)

        return Button {
            controller.openYahooFinance(symbol: symbol)
        } label: {
            tickerRowContent(symbol: symbol, quote: quote)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .background(tickerRowBackground(intensity: intensity, isPersistent: isPersistentHighlighted, quote: quote))
    }

    private func tickerRowContent(symbol: String, quote: StockQuote?) -> some View {
        HStack(spacing: 0) {
            if let quote = quote, !quote.isPlaceholder {
                Text(padded(symbol, to: LayoutConfig.Ticker.symbolWidth))
                    .foregroundColor(quote.swiftUIDisplayColor)
                Text(" ")
                Text(padded(quote.formattedMarketCap, to: LayoutConfig.Ticker.marketCapWidth))
                    .foregroundColor(quote.swiftUIDisplayColor)
                Text(" ")
                Text(padded(quote.formattedChangePercent, to: LayoutConfig.Ticker.percentWidth))
                    .foregroundColor(quote.swiftUIDisplayColor)

                if let ytd = quote.formattedYTDChangePercent {
                    Text("  ")
                    Text(padded("YTD: \(ytd)", to: LayoutConfig.Ticker.ytdWidth))
                        .foregroundColor(quote.swiftUIYTDColor)
                }
                if let high = quote.formattedHighestCloseChangePercent {
                    Text("  ")
                    Text(padded("High: \(high)", to: LayoutConfig.Ticker.highWidth))
                        .foregroundColor(quote.swiftUIHighestCloseColor)
                }
                if let low = quote.formattedLowestCloseChangePercent {
                    Text("  ")
                    Text(padded("Low: \(low)", to: LayoutConfig.Ticker.lowWidth))
                        .foregroundColor(quote.swiftUILowestCloseColor)
                }
                if quote.isInExtendedHoursPeriod(), let label = quote.extendedHoursPeriodLabel() {
                    if quote.shouldShowExtendedHours(), let ext = quote.formattedExtendedHoursChangePercent {
                        Text("  \(label): \(ext)")
                            .foregroundColor(quote.swiftUIExtendedHoursColor)
                    } else {
                        Text("  \(label): --")
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("\(symbol) --")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .font(.system(size: LayoutConfig.Font.size, design: .monospaced))
    }

    private func tickerRowBackground(intensity: CGFloat, isPersistent: Bool, quote: StockQuote?) -> some View {
        Group {
            if intensity > 0.01, let quote = quote {
                Color(nsColor: quote.highlightColor)
                    .opacity(Double(intensity) * 0.6)
            } else if isPersistent {
                ColorMapping.color(from: controller.config.highlightColor)
                    .opacity(controller.config.highlightOpacity)
            } else {
                Color.clear
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

    private func capsuleToggle(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(label) { action() }
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

    private func padded(_ string: String, to length: Int) -> String {
        string.count >= length ? string : string.padding(toLength: length, withPad: " ", startingAt: 0)
    }
}
