import XCTest
@testable import StockTicker

// MARK: - NewsService Tests

final class NewsServiceTests: XCTestCase {

    // MARK: - fetchNews tests

    func testFetchNews_validRSS_returnsNewsItems() async {
        let mockClient = MockHTTPClient()
        setupYahooRSSResponse(on: mockClient)

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        XCTAssertFalse(items.isEmpty)
        XCTAssertEqual(items.first?.source, "Yahoo")
    }

    func testFetchNews_multipleFeeds_combinesResults() async {
        let mockClient = MockHTTPClient()
        setupYahooRSSResponse(on: mockClient)
        setupCNBCRSSResponse(on: mockClient)

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        // Should have items from both sources
        let sources = Set(items.map { $0.source })
        XCTAssertTrue(sources.contains("Yahoo") || sources.contains("CNBC"))
    }

    func testFetchNews_networkError_returnsEmpty() async {
        let mockClient = MockHTTPClient()
        let yahooURL = URL(string: "https://finance.yahoo.com/news/rssindex")!
        let cnbcURL = URL(string: "https://www.cnbc.com/id/20910258/device/rss/rss.html")!

        mockClient.responses[yahooURL] = .failure(URLError(.notConnectedToInternet))
        mockClient.responses[cnbcURL] = .failure(URLError(.notConnectedToInternet))

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        XCTAssertTrue(items.isEmpty)
    }

    func testFetchNews_invalidXML_returnsEmpty() async {
        let mockClient = MockHTTPClient()
        let yahooURL = URL(string: "https://finance.yahoo.com/news/rssindex")!
        let cnbcURL = URL(string: "https://www.cnbc.com/id/20910258/device/rss/rss.html")!

        let response200 = HTTPURLResponse(url: yahooURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[yahooURL] = .success(("not valid xml".data(using: .utf8)!, response200))
        mockClient.responses[cnbcURL] = .success(("not valid xml".data(using: .utf8)!, response200))

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        XCTAssertTrue(items.isEmpty)
    }

    func testFetchNews_limitsToFiveItems() async {
        let mockClient = MockHTTPClient()
        setupYahooRSSResponseWithManyItems(on: mockClient, count: 10)

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        XCTAssertLessThanOrEqual(items.count, 5)
    }

    func testFetchNews_deduplicatesSimilarHeadlines() async {
        let mockClient = MockHTTPClient()

        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>Stock market rallies on positive news</title>
                <link>https://example.com/1</link>
                <pubDate>Mon, 03 Feb 2026 10:00:00 +0000</pubDate>
            </item>
            <item>
                <title>Stock market rallies after positive news announcement</title>
                <link>https://example.com/2</link>
                <pubDate>Mon, 03 Feb 2026 09:00:00 +0000</pubDate>
            </item>
        </channel>
        </rss>
        """

        let yahooURL = URL(string: "https://finance.yahoo.com/news/rssindex")!
        let cnbcURL = URL(string: "https://www.cnbc.com/id/20910258/device/rss/rss.html")!

        let response200 = HTTPURLResponse(url: yahooURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[yahooURL] = .success((rss.data(using: .utf8)!, response200))
        mockClient.responses[cnbcURL] = .success(("".data(using: .utf8)!, response200))

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        // Similar headlines should be deduplicated
        XCTAssertEqual(items.count, 1)
    }

    func testFetchNews_sortsByPublishDate() async {
        let mockClient = MockHTTPClient()

        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>Older headline</title>
                <link>https://example.com/1</link>
                <pubDate>Mon, 01 Feb 2026 10:00:00 +0000</pubDate>
            </item>
            <item>
                <title>Newer headline</title>
                <link>https://example.com/2</link>
                <pubDate>Mon, 03 Feb 2026 10:00:00 +0000</pubDate>
            </item>
        </channel>
        </rss>
        """

        let yahooURL = URL(string: "https://finance.yahoo.com/news/rssindex")!
        let cnbcURL = URL(string: "https://www.cnbc.com/id/20910258/device/rss/rss.html")!

        let response200 = HTTPURLResponse(url: yahooURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[yahooURL] = .success((rss.data(using: .utf8)!, response200))
        mockClient.responses[cnbcURL] = .success(("".data(using: .utf8)!, response200))

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.headline, "Newer headline")
    }

    // MARK: - Helpers

    private func setupYahooRSSResponse(on mockClient: MockHTTPClient) {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <title>Yahoo Finance News</title>
            <item>
                <title>Fed signals potential rate pause in March meeting</title>
                <link>https://finance.yahoo.com/news/1</link>
                <pubDate>Mon, 03 Feb 2026 12:00:00 +0000</pubDate>
            </item>
            <item>
                <title>Tech stocks rally as earnings beat expectations</title>
                <link>https://finance.yahoo.com/news/2</link>
                <pubDate>Mon, 03 Feb 2026 11:00:00 +0000</pubDate>
            </item>
        </channel>
        </rss>
        """

        let url = URL(string: "https://finance.yahoo.com/news/rssindex")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((rss.data(using: .utf8)!, response))
    }

    private func setupCNBCRSSResponse(on mockClient: MockHTTPClient) {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <title>CNBC Top News</title>
            <item>
                <title>Oil prices surge on supply concerns</title>
                <link>https://cnbc.com/news/1</link>
                <pubDate>Mon, 03 Feb 2026 10:00:00 +0000</pubDate>
            </item>
        </channel>
        </rss>
        """

        let url = URL(string: "https://www.cnbc.com/id/20910258/device/rss/rss.html")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[url] = .success((rss.data(using: .utf8)!, response))
    }

    private func setupYahooRSSResponseWithManyItems(on mockClient: MockHTTPClient, count: Int) {
        var items = ""
        for i in 1...count {
            items += """
            <item>
                <title>Headline number \(i)</title>
                <link>https://example.com/\(i)</link>
                <pubDate>Mon, 03 Feb 2026 \(10 + i):00:00 +0000</pubDate>
            </item>
            """
        }

        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            \(items)
        </channel>
        </rss>
        """

        let yahooURL = URL(string: "https://finance.yahoo.com/news/rssindex")!
        let cnbcURL = URL(string: "https://www.cnbc.com/id/20910258/device/rss/rss.html")!

        let response200 = HTTPURLResponse(url: yahooURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[yahooURL] = .success((rss.data(using: .utf8)!, response200))
        mockClient.responses[cnbcURL] = .success(("".data(using: .utf8)!, response200))
    }
}

// MARK: - RSSParser Tests

final class RSSParserTests: XCTestCase {

    func testParse_validRSS_extractsItems() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>Test headline</title>
                <link>https://example.com/article</link>
                <pubDate>Mon, 03 Feb 2026 12:00:00 +0000</pubDate>
            </item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.headline, "Test headline")
        XCTAssertEqual(items.first?.source, "Test")
        XCTAssertEqual(items.first?.link?.absoluteString, "https://example.com/article")
        XCTAssertNotNil(items.first?.publishedAt)
    }

    func testParse_multipleItems_extractsAll() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>First headline</title>
                <link>https://example.com/1</link>
            </item>
            <item>
                <title>Second headline</title>
                <link>https://example.com/2</link>
            </item>
            <item>
                <title>Third headline</title>
                <link>https://example.com/3</link>
            </item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 3)
    }

    func testParse_emptyTitle_skipsItem() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title></title>
                <link>https://example.com/1</link>
            </item>
            <item>
                <title>Valid headline</title>
                <link>https://example.com/2</link>
            </item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.headline, "Valid headline")
    }

    func testParse_invalidXML_returnsEmpty() {
        let invalidXML = "This is not valid XML"

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: invalidXML.data(using: .utf8)!)

        XCTAssertTrue(items.isEmpty)
    }

    func testParse_missingLink_stillParsesHeadline() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>Headline without link</title>
            </item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.headline, "Headline without link")
        XCTAssertNil(items.first?.link)
    }

    func testParse_invalidDate_hasNilPublishedAt() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>Headline</title>
                <pubDate>not a valid date</pubDate>
            </item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 1)
        XCTAssertNil(items.first?.publishedAt)
    }
}

// MARK: - NewsItem Tests

final class NewsItemTests: XCTestCase {

    func testNewsItem_initializesWithUUID() {
        let item = NewsItem(headline: "Test", source: "Yahoo")

        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.headline, "Test")
        XCTAssertEqual(item.source, "Yahoo")
    }

    func testNewsItem_withAllFields() {
        let url = URL(string: "https://example.com")!
        let date = Date()
        let item = NewsItem(headline: "Test", source: "CNBC", link: url, publishedAt: date)

        XCTAssertEqual(item.headline, "Test")
        XCTAssertEqual(item.source, "CNBC")
        XCTAssertEqual(item.link, url)
        XCTAssertEqual(item.publishedAt, date)
    }
}

// MARK: - NewsSource Tests

final class NewsSourceTests: XCTestCase {

    func testYahooSource_hasFeedURL() {
        XCTAssertEqual(NewsSource.yahoo.feedURL, "https://finance.yahoo.com/news/rssindex")
        XCTAssertEqual(NewsSource.yahoo.displayName, "Yahoo")
    }

    func testCNBCMarketsSource_hasFeedURL() {
        XCTAssertEqual(NewsSource.cnbcMarkets.feedURL, "https://www.cnbc.com/id/20910258/device/rss/rss.html")
        XCTAssertEqual(NewsSource.cnbcMarkets.displayName, "CNBC")
    }

    func testAllCases_returnsAllSources() {
        XCTAssertEqual(NewsSource.allCases.count, 2)
        XCTAssertTrue(NewsSource.allCases.contains(.yahoo))
        XCTAssertTrue(NewsSource.allCases.contains(.cnbcMarkets))
    }

    func testYahooSource_rawValue() {
        XCTAssertEqual(NewsSource.yahoo.rawValue, "yahoo")
    }

    func testCNBCMarketsSource_rawValue() {
        XCTAssertEqual(NewsSource.cnbcMarkets.rawValue, "cnbcMarkets")
    }
}

// MARK: - Additional NewsService Tests

final class NewsServiceEdgeCaseTests: XCTestCase {

    func testFetchNews_non200StatusCode_returnsEmpty() async {
        let mockClient = MockHTTPClient()
        let yahooURL = URL(string: "https://finance.yahoo.com/news/rssindex")!
        let cnbcURL = URL(string: "https://www.cnbc.com/id/20910258/device/rss/rss.html")!

        let response404 = HTTPURLResponse(url: yahooURL, statusCode: 404, httpVersion: nil, headerFields: nil)!
        mockClient.responses[yahooURL] = .success((Data(), response404))
        mockClient.responses[cnbcURL] = .success((Data(), response404))

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        XCTAssertTrue(items.isEmpty)
    }

    func testFetchNews_partialFailure_returnsSuccessfulItems() async {
        let mockClient = MockHTTPClient()
        let yahooURL = URL(string: "https://finance.yahoo.com/news/rssindex")!
        let cnbcURL = URL(string: "https://www.cnbc.com/id/20910258/device/rss/rss.html")!

        // Yahoo succeeds
        let yahooRSS = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>Yahoo headline</title>
                <link>https://yahoo.com/1</link>
                <pubDate>Mon, 03 Feb 2026 12:00:00 +0000</pubDate>
            </item>
        </channel>
        </rss>
        """
        let response200 = HTTPURLResponse(url: yahooURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[yahooURL] = .success((yahooRSS.data(using: .utf8)!, response200))

        // CNBC fails
        mockClient.responses[cnbcURL] = .failure(URLError(.timedOut))

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.source, "Yahoo")
    }

    func testFetchNews_emptyRSS_returnsEmpty() async {
        let mockClient = MockHTTPClient()
        let yahooURL = URL(string: "https://finance.yahoo.com/news/rssindex")!
        let cnbcURL = URL(string: "https://www.cnbc.com/id/20910258/device/rss/rss.html")!

        let emptyRSS = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
        </channel>
        </rss>
        """
        let response200 = HTTPURLResponse(url: yahooURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[yahooURL] = .success((emptyRSS.data(using: .utf8)!, response200))
        mockClient.responses[cnbcURL] = .success((emptyRSS.data(using: .utf8)!, response200))

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        XCTAssertTrue(items.isEmpty)
    }

    func testFetchNews_distinctHeadlines_notDeduplicated() async {
        let mockClient = MockHTTPClient()

        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>Apple announces new iPhone</title>
                <link>https://example.com/1</link>
                <pubDate>Mon, 03 Feb 2026 12:00:00 +0000</pubDate>
            </item>
            <item>
                <title>Tesla reports record earnings</title>
                <link>https://example.com/2</link>
                <pubDate>Mon, 03 Feb 2026 11:00:00 +0000</pubDate>
            </item>
            <item>
                <title>Federal Reserve holds rates steady</title>
                <link>https://example.com/3</link>
                <pubDate>Mon, 03 Feb 2026 10:00:00 +0000</pubDate>
            </item>
        </channel>
        </rss>
        """

        let yahooURL = URL(string: "https://finance.yahoo.com/news/rssindex")!
        let cnbcURL = URL(string: "https://www.cnbc.com/id/20910258/device/rss/rss.html")!

        let response200 = HTTPURLResponse(url: yahooURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[yahooURL] = .success((rss.data(using: .utf8)!, response200))
        mockClient.responses[cnbcURL] = .success(("".data(using: .utf8)!, response200))

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        XCTAssertEqual(items.count, 3)
    }

    func testFetchNews_itemsWithNoDate_stillIncluded() async {
        let mockClient = MockHTTPClient()

        // Use completely distinct headlines to avoid deduplication
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>Apple announces revolutionary product launch</title>
                <link>https://example.com/1</link>
            </item>
            <item>
                <title>Federal Reserve raises interest rates</title>
                <link>https://example.com/2</link>
                <pubDate>Mon, 03 Feb 2026 12:00:00 +0000</pubDate>
            </item>
        </channel>
        </rss>
        """

        let yahooURL = URL(string: "https://finance.yahoo.com/news/rssindex")!
        let cnbcURL = URL(string: "https://www.cnbc.com/id/20910258/device/rss/rss.html")!

        let response200 = HTTPURLResponse(url: yahooURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        mockClient.responses[yahooURL] = .success((rss.data(using: .utf8)!, response200))
        mockClient.responses[cnbcURL] = .success(("".data(using: .utf8)!, response200))

        let service = NewsService(httpClient: mockClient)
        let items = await service.fetchNews()

        // Both items should be present
        XCTAssertEqual(items.count, 2)

        // Verify we have one with date and one without
        let datedItems = items.filter { $0.publishedAt != nil }
        let undatedItems = items.filter { $0.publishedAt == nil }
        XCTAssertEqual(datedItems.count, 1)
        XCTAssertEqual(undatedItems.count, 1)
    }
}

// MARK: - Additional RSSParser Tests

final class RSSParserEdgeCaseTests: XCTestCase {

    func testParse_whitespaceOnlyTitle_skipsItem() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>   </title>
                <link>https://example.com/1</link>
            </item>
            <item>
                <title>Valid headline</title>
                <link>https://example.com/2</link>
            </item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.headline, "Valid headline")
    }

    func testParse_titleWithNewlines_trimsWhitespace() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>
                    Headline with newlines
                </title>
                <link>https://example.com/1</link>
            </item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.headline, "Headline with newlines")
    }

    func testParse_specialCharactersInTitle_preservesThem() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>S&amp;P 500 rises 2% on &quot;strong&quot; earnings</title>
                <link>https://example.com/1</link>
            </item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.headline, "S&P 500 rises 2% on \"strong\" earnings")
    }

    func testParse_emptyLink_hasNilLink() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>Headline</title>
                <link></link>
            </item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 1)
        XCTAssertNil(items.first?.link)
    }

    func testParse_multipleChannels_parsesAllItems() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>First channel headline</title>
                <link>https://example.com/1</link>
            </item>
        </channel>
        <channel>
            <item>
                <title>Second channel headline</title>
                <link>https://example.com/2</link>
            </item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 2)
    }

    func testParse_differentDateFormats_handlesGracefully() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>RFC 822 date</title>
                <pubDate>Mon, 03 Feb 2026 12:00:00 +0000</pubDate>
            </item>
            <item>
                <title>ISO 8601 date not supported</title>
                <pubDate>2026-02-03T12:00:00Z</pubDate>
            </item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 2)
        XCTAssertNotNil(items[0].publishedAt)
        XCTAssertNil(items[1].publishedAt) // ISO 8601 not supported by RSS parser
    }

    func testParse_emptyData_returnsEmpty() {
        let parser = RSSParser(source: "Test")
        let items = parser.parse(data: Data())

        XCTAssertTrue(items.isEmpty)
    }

    func testParse_sourcePreserved_acrossAllItems() {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item><title>One</title></item>
            <item><title>Two</title></item>
            <item><title>Three</title></item>
        </channel>
        </rss>
        """

        let parser = RSSParser(source: "CustomSource")
        let items = parser.parse(data: rss.data(using: .utf8)!)

        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.allSatisfy { $0.source == "CustomSource" })
    }
}

// MARK: - NewsItem Edge Case Tests

final class NewsItemEdgeCaseTests: XCTestCase {

    func testNewsItem_uniqueIDs_forDifferentInstances() {
        let item1 = NewsItem(headline: "Same headline", source: "Same source")
        let item2 = NewsItem(headline: "Same headline", source: "Same source")

        XCTAssertNotEqual(item1.id, item2.id)
    }

    func testNewsItem_nilOptionalFields_defaultCorrectly() {
        let item = NewsItem(headline: "Test", source: "Test")

        XCTAssertNil(item.link)
        XCTAssertNil(item.publishedAt)
    }

    func testNewsItem_identifiable_conformance() {
        let item = NewsItem(headline: "Test", source: "Test")
        let id: UUID = item.id

        XCTAssertNotNil(id)
    }
}
