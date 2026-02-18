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

    static func extractMarketState(from quotes: [String: StockQuote], symbol: String = "SPY") -> String? {
        quotes[symbol]?.yahooMarketState
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

        let quotes = await fetchedQuotes

        var combinedIndexQuotes = await fetchedIndexQuotes
        combinedIndexQuotes.merge(await fetchedAlwaysOpen) { _, new in new }

        // Extract market state from SPY quote (already fetched as part of watchlist/index)
        // On weekends, force CLOSED regardless of what API returns
        let marketState = isWeekend ? "CLOSED" : extractMarketState(from: quotes) ?? extractMarketState(from: combinedIndexQuotes)

        return FetchResult(
            quotes: quotes,
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

        let quotes = await fetchedQuotes

        return FetchResult(
            quotes: quotes,
            indexQuotes: await fetchedIndexQuotes,
            yahooMarketState: extractMarketState(from: quotes),
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

        let quotes = await fetchedQuotes

        return FetchResult(
            quotes: quotes,
            indexQuotes: await fetchedAlwaysOpen,
            yahooMarketState: extractMarketState(from: quotes),
            fetchedSymbols: Set(allSymbols),
            isInitialLoadComplete: false,
            shouldMergeQuotes: false
        )
    }
}
