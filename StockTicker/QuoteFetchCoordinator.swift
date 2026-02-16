import Foundation

// MARK: - Fetch Result

struct FetchResult {
    var quotes: [String: StockQuote]
    var indexQuotes: [String: StockQuote]
    var yahooMarketState: String?
    var fetchedSymbols: Set<String>
    var isInitialLoadComplete: Bool
    var shouldMergeQuotes: Bool
}

// MARK: - Quote Fetch Coordinator

enum QuoteFetchCoordinator {

    static func ensureClosedMarketSymbol(_ symbol: String, in symbols: [String]) -> [String] {
        guard !symbols.contains(symbol) else { return symbols }
        return symbols + [symbol]
    }

    static func fetchInitialLoad(
        service: StockServiceProtocol,
        watchlist: [String],
        indexSymbols: [String],
        alwaysOpenSymbols: [String],
        closedMarketSymbol: String,
        isWeekend: Bool
    ) async -> FetchResult {
        let allSymbols = ensureClosedMarketSymbol(closedMarketSymbol, in: watchlist)

        async let fetchedQuotes = service.fetchQuotes(symbols: allSymbols)
        async let fetchedIndexQuotes = service.fetchQuotes(symbols: indexSymbols)
        async let fetchedAlwaysOpen = service.fetchQuotes(symbols: alwaysOpenSymbols)
        async let fetchedMarketState = service.fetchMarketState(symbol: "SPY")

        var combinedIndexQuotes = await fetchedIndexQuotes
        combinedIndexQuotes.merge(await fetchedAlwaysOpen) { _, new in new }

        // On weekends, force CLOSED regardless of what API returns
        // (API may still report POST from Friday's after-hours)
        let marketState = isWeekend ? "CLOSED" : await fetchedMarketState

        return FetchResult(
            quotes: await fetchedQuotes,
            indexQuotes: combinedIndexQuotes,
            yahooMarketState: marketState,
            fetchedSymbols: Set(allSymbols),
            isInitialLoadComplete: true,
            shouldMergeQuotes: false
        )
    }

    static func fetchClosedMarket(
        service: StockServiceProtocol,
        closedMarketSymbol: String,
        alwaysOpenSymbols: [String]
    ) async -> FetchResult {
        let symbolsToFetch = Set([closedMarketSymbol] + alwaysOpenSymbols)
        let fetchedQuotes = await service.fetchQuotes(symbols: Array(symbolsToFetch))

        return FetchResult(
            quotes: fetchedQuotes,
            indexQuotes: fetchedQuotes,
            yahooMarketState: "CLOSED",
            fetchedSymbols: symbolsToFetch,
            isInitialLoadComplete: false,
            shouldMergeQuotes: true
        )
    }

    static func fetchRegularSession(
        service: StockServiceProtocol,
        watchlist: [String],
        indexSymbols: [String],
        closedMarketSymbol: String
    ) async -> FetchResult {
        let allSymbols = ensureClosedMarketSymbol(closedMarketSymbol, in: watchlist)

        async let fetchedQuotes = service.fetchQuotes(symbols: allSymbols)
        async let fetchedIndexQuotes = service.fetchQuotes(symbols: indexSymbols)
        async let fetchedMarketState = service.fetchMarketState(symbol: "SPY")

        return FetchResult(
            quotes: await fetchedQuotes,
            indexQuotes: await fetchedIndexQuotes,
            yahooMarketState: await fetchedMarketState,
            fetchedSymbols: Set(allSymbols),
            isInitialLoadComplete: false,
            shouldMergeQuotes: false
        )
    }

    static func fetchExtendedHours(
        service: StockServiceProtocol,
        watchlist: [String],
        alwaysOpenSymbols: [String],
        closedMarketSymbol: String
    ) async -> FetchResult {
        let allSymbols = ensureClosedMarketSymbol(closedMarketSymbol, in: watchlist)

        async let fetchedQuotes = service.fetchQuotes(symbols: allSymbols)
        async let fetchedAlwaysOpen = service.fetchQuotes(symbols: alwaysOpenSymbols)
        async let fetchedMarketState = service.fetchMarketState(symbol: "SPY")

        return FetchResult(
            quotes: await fetchedQuotes,
            indexQuotes: await fetchedAlwaysOpen,
            yahooMarketState: await fetchedMarketState,
            fetchedSymbols: Set(allSymbols),
            isInitialLoadComplete: false,
            shouldMergeQuotes: false
        )
    }
}
