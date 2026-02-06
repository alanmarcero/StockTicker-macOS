import Foundation

// MARK: - Protocol for Dependency Injection

protocol NewsServiceProtocol: Sendable {
    func fetchNews() async -> [NewsItem]
}

// MARK: - News Service Implementation

actor NewsService: NewsServiceProtocol {
    private let httpClient: HTTPClient

    private enum Constants {
        static let itemsPerSource = LayoutConfig.Headlines.itemsPerSource
        static let similarityThreshold = 0.6
    }

    init(httpClient: HTTPClient = LoggingHTTPClient()) {
        self.httpClient = httpClient
    }

    func fetchNews() async -> [NewsItem] {
        let itemsBySource = await fetchFromAllSources()
        let processedItems = processItemsBySource(itemsBySource)
        let deduplicated = deduplicateHeadlines(processedItems)
        return sortByDate(deduplicated)
    }

    // MARK: - Private

    private func fetchFromAllSources() async -> [String: [NewsItem]] {
        await withTaskGroup(of: (String, [NewsItem]).self) { group in
            for source in NewsSource.allCases {
                group.addTask {
                    let items = await self.fetchFromSource(source)
                    return (source.displayName, items)
                }
            }

            var itemsBySource: [String: [NewsItem]] = [:]
            for await (sourceName, items) in group {
                itemsBySource[sourceName] = items
            }
            return itemsBySource
        }
    }

    private func fetchFromSource(_ source: NewsSource) async -> [NewsItem] {
        guard let url = URL(string: source.feedURL) else { return [] }

        do {
            let (data, response) = try await httpClient.data(from: url)
            guard response.isSuccessfulHTTP else { return [] }

            let parser = RSSParser(source: source.displayName)
            return parser.parse(data: data)
        } catch {
            return []
        }
    }

    private func processItemsBySource(_ itemsBySource: [String: [NewsItem]]) -> [NewsItem] {
        var result: [NewsItem] = []

        for (_, items) in itemsBySource {
            let sorted = sortByDate(items)
            let topItems = Array(sorted.prefix(Constants.itemsPerSource))

            for (index, item) in topItems.enumerated() {
                // Mark the first (most recent) item from each source
                let processedItem = item.withTopFromSource(index == 0)
                result.append(processedItem)
            }
        }

        return result
    }

    private func deduplicateHeadlines(_ items: [NewsItem]) -> [NewsItem] {
        var result: [NewsItem] = []
        for item in items {
            let isDuplicate = result.contains { existing in
                headlineSimilarity(existing.headline, item.headline) > Constants.similarityThreshold
            }
            if !isDuplicate {
                result.append(item)
            }
        }
        return result
    }

    private func sortByDate(_ items: [NewsItem]) -> [NewsItem] {
        items.sorted { item1, item2 in
            let date1 = item1.publishedAt ?? .distantPast
            let date2 = item2.publishedAt ?? .distantPast
            return date1 > date2
        }
    }

    /// Calculates similarity between two headlines using word overlap (Jaccard similarity)
    private func headlineSimilarity(_ headline1: String, _ headline2: String) -> Double {
        let words1 = Set(normalizeHeadline(headline1))
        let words2 = Set(normalizeHeadline(headline2))

        guard !words1.isEmpty, !words2.isEmpty else { return 0 }

        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count

        return Double(intersection) / Double(union)
    }

    private func normalizeHeadline(_ headline: String) -> [String] {
        headline
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }  // Filter out short words
    }
}
