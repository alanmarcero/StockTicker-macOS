import XCTest
@testable import StockTicker

// MARK: - Thread-Safe Mock for Concurrent Scanner Fetches

/// Actor-based mock HTTP client that safely handles concurrent `async let` calls.
/// MockHTTPClient's `requestedURLs.append()` is not thread-safe for parallel access.
private actor ScannerMockHTTPClient: HTTPClient {
    nonisolated let patternResponses: [(pattern: String, result: Result<(Data, URLResponse), Error>)]

    init(patterns: [(pattern: String, result: Result<(Data, URLResponse), Error>)]) {
        self.patternResponses = patterns
    }

    nonisolated func data(from url: URL) async throws -> (Data, URLResponse) {
        let urlString = url.absoluteString
        for (pattern, result) in patternResponses {
            guard urlString.contains(pattern) else { continue }
            switch result {
            case .success(let response): return response
            case .failure(let error): throw error
            }
        }
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }

    nonisolated func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else { throw URLError(.badURL) }
        return try await data(from: url)
    }
}

// MARK: - ScannerService Tests

final class ScannerServiceTests: XCTestCase {

    private let response200 = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!

    // MARK: - Successful Fetch

    func testFetchEMAData_allEndpointsSucceed_returnsUnifiedData() async {
        let client = makeMock(above: aboveJSON, crossover: crossoverJSON, crossdown: crossdownJSON, below: belowJSON)
        let service = ScannerService(httpClient: client)
        let result = await service.fetchEMAData(baseURL: "https://abc123.cloudfront.net")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.dayAbove.count, 1)
        XCTAssertEqual(result?.dayAbove[0].symbol, "AAPL")
        XCTAssertEqual(result?.dayAbove[0].count, 12)
        XCTAssertEqual(result?.weekAbove.count, 1)
        XCTAssertEqual(result?.weekAbove[0].symbol, "MSFT")
        XCTAssertEqual(result?.crossovers.count, 1)
        XCTAssertEqual(result?.crossovers[0].symbol, "TSLA")
        XCTAssertEqual(result?.crossovers[0].weeksBelow, 5)
        XCTAssertEqual(result?.crossdowns.count, 1)
        XCTAssertEqual(result?.crossdowns[0].symbol, "META")
        XCTAssertEqual(result?.crossdowns[0].weeksAbove, 4)
        XCTAssertEqual(result?.below.count, 1)
        XCTAssertEqual(result?.below[0].symbol, "GOOG")
        XCTAssertEqual(result?.below[0].weeksBelow, 4)
        XCTAssertEqual(result?.scanDate, "2026-02-23")
    }

    // MARK: - Partial Failure

    func testFetchEMAData_aboveEndpointFails_returnsNil() async {
        let client = makeMock(aboveFails: true, crossover: crossoverJSON, crossdown: crossdownJSON, below: belowJSON)
        let service = ScannerService(httpClient: client)
        let result = await service.fetchEMAData(baseURL: "https://abc123.cloudfront.net")

        XCTAssertNil(result)
    }

    func testFetchEMAData_crossoverEndpointFails_returnsNil() async {
        let client = makeMock(above: aboveJSON, crossoverFails: true, crossdown: crossdownJSON, below: belowJSON)
        let service = ScannerService(httpClient: client)
        let result = await service.fetchEMAData(baseURL: "https://abc123.cloudfront.net")

        XCTAssertNil(result)
    }

    func testFetchEMAData_belowEndpointFails_returnsNil() async {
        let client = makeMock(above: aboveJSON, crossover: crossoverJSON, crossdown: crossdownJSON, belowFails: true)
        let service = ScannerService(httpClient: client)
        let result = await service.fetchEMAData(baseURL: "https://abc123.cloudfront.net")

        XCTAssertNil(result)
    }

    func testFetchEMAData_crossdownEndpointFails_returnsDataWithEmptyCrossdowns() async {
        let client = makeMock(above: aboveJSON, crossover: crossoverJSON, crossdownFails: true, below: belowJSON)
        let service = ScannerService(httpClient: client)
        let result = await service.fetchEMAData(baseURL: "https://abc123.cloudfront.net")

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.crossdowns.isEmpty)
        XCTAssertEqual(result?.crossovers.count, 1)
    }

    // MARK: - Empty Arrays

    func testFetchEMAData_emptyArrays_returnsEmptyData() async {
        let emptyAbove = """
        {"dayAbove":[],"weekAbove":[],"scanDate":"2026-02-23","scanTime":"2026-02-23T14:00:00Z","sneakPeek":true,"symbolsScanned":0,"errors":0}
        """
        let emptyCross = """
        {"crossovers":[],"scanDate":"2026-02-23","scanTime":"2026-02-23T14:00:00Z","sneakPeek":true,"symbolsScanned":0,"errors":0}
        """
        let emptyCrossdown = """
        {"crossdowns":[],"scanDate":"2026-02-23","scanTime":"2026-02-23T14:00:00Z","sneakPeek":true,"symbolsScanned":0,"errors":0}
        """
        let emptyBelow = """
        {"below":[],"scanDate":"2026-02-23","scanTime":"2026-02-23T14:00:00Z","sneakPeek":true,"symbolsScanned":0,"errors":0}
        """
        let client = makeMock(above: emptyAbove, crossover: emptyCross, crossdown: emptyCrossdown, below: emptyBelow)
        let service = ScannerService(httpClient: client)
        let result = await service.fetchEMAData(baseURL: "https://abc123.cloudfront.net")

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.dayAbove.isEmpty)
        XCTAssertTrue(result!.weekAbove.isEmpty)
        XCTAssertTrue(result!.crossovers.isEmpty)
        XCTAssertTrue(result!.crossdowns.isEmpty)
        XCTAssertTrue(result!.below.isEmpty)
    }

    // MARK: - Invalid JSON

    func testFetchEMAData_invalidJSON_returnsNil() async {
        let client = makeMock(above: "not json", crossover: crossoverJSON, crossdown: crossdownJSON, below: belowJSON)
        let service = ScannerService(httpClient: client)
        let result = await service.fetchEMAData(baseURL: "https://abc123.cloudfront.net")

        XCTAssertNil(result)
    }

    // MARK: - Trailing Slash

    func testFetchEMAData_trailingSlash_handledCorrectly() async {
        let client = makeMock(above: aboveJSON, crossover: crossoverJSON, crossdown: crossdownJSON, below: belowJSON)
        let service = ScannerService(httpClient: client)
        let result = await service.fetchEMAData(baseURL: "https://abc123.cloudfront.net/")

        XCTAssertNotNil(result)
    }

    // MARK: - Model Decoding

    func testScannerAboveItem_decoding() throws {
        let json = """
        {"symbol":"AAPL","close":225.5,"ema":220.1234,"pctAbove":2.44,"count":12}
        """
        let item = try JSONDecoder().decode(ScannerAboveItem.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(item.symbol, "AAPL")
        XCTAssertEqual(item.close, 225.5)
        XCTAssertEqual(item.ema, 220.1234)
        XCTAssertEqual(item.pctAbove, 2.44)
        XCTAssertEqual(item.count, 12)
    }

    func testScannerCrossoverItem_decoding() throws {
        let json = """
        {"symbol":"TSLA","close":245.0,"ema":240.5678,"pctAbove":1.84,"weeksBelow":5}
        """
        let item = try JSONDecoder().decode(ScannerCrossoverItem.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(item.symbol, "TSLA")
        XCTAssertEqual(item.weeksBelow, 5)
    }

    func testScannerCrossdownItem_decoding() throws {
        let json = """
        {"symbol":"META","close":520.0,"ema":525.5678,"pctBelow":1.06,"weeksAbove":4}
        """
        let item = try JSONDecoder().decode(ScannerCrossdownItem.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(item.symbol, "META")
        XCTAssertEqual(item.close, 520.0)
        XCTAssertEqual(item.ema, 525.5678)
        XCTAssertEqual(item.pctBelow, 1.06)
        XCTAssertEqual(item.weeksAbove, 4)
    }

    func testScannerBelowItem_decoding() throws {
        let json = """
        {"symbol":"GOOG","close":145.5,"ema":148.2567,"pctBelow":1.86,"weeksBelow":4}
        """
        let item = try JSONDecoder().decode(ScannerBelowItem.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(item.symbol, "GOOG")
        XCTAssertEqual(item.pctBelow, 1.86)
        XCTAssertEqual(item.weeksBelow, 4)
    }

    // MARK: - HTTP Error Status

    func testFetchEMAData_httpError_returnsNil() async {
        let response500 = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        let patterns: [(pattern: String, result: Result<(Data, URLResponse), Error>)] = [
            ("latest-above.json", .success((Data(), response500))),
            ("latest-below.json", .success((belowJSON.data(using: .utf8)!, response200))),
            ("latest-crossdown.json", .success((crossdownJSON.data(using: .utf8)!, response200))),
            ("latest.json", .success((crossoverJSON.data(using: .utf8)!, response200))),
        ]
        let client = ScannerMockHTTPClient(patterns: patterns)
        let service = ScannerService(httpClient: client)
        let result = await service.fetchEMAData(baseURL: "https://abc123.cloudfront.net")

        XCTAssertNil(result)
    }

    // MARK: - Helpers

    private let aboveJSON = """
    {
        "scanDate": "2026-02-23", "scanTime": "2026-02-23T14:00:00Z", "sneakPeek": true, "symbolsScanned": 10000, "errors": 0,
        "dayAbove": [{"symbol":"AAPL","close":225.5,"ema":220.0,"pctAbove":2.5,"count":12}],
        "weekAbove": [{"symbol":"MSFT","close":430.0,"ema":425.0,"pctAbove":1.18,"count":6}]
    }
    """

    private let crossoverJSON = """
    {
        "scanDate": "2026-02-23", "scanTime": "2026-02-23T14:00:00Z", "sneakPeek": true, "symbolsScanned": 10000, "errors": 0,
        "crossovers": [{"symbol":"TSLA","close":245.0,"ema":240.0,"pctAbove":2.08,"weeksBelow":5}]
    }
    """

    private let belowJSON = """
    {
        "scanDate": "2026-02-23", "scanTime": "2026-02-23T14:00:00Z", "sneakPeek": true, "symbolsScanned": 10000, "errors": 0,
        "below": [{"symbol":"GOOG","close":145.5,"ema":148.2567,"pctBelow":1.86,"weeksBelow":4}]
    }
    """

    private let crossdownJSON = """
    {
        "scanDate": "2026-02-23", "scanTime": "2026-02-23T14:00:00Z", "sneakPeek": true, "symbolsScanned": 10000, "errors": 0,
        "crossdowns": [{"symbol":"META","close":520.0,"ema":525.5678,"pctBelow":1.06,"weeksAbove":4}]
    }
    """

    private func makeMock(
        above: String? = nil, aboveFails: Bool = false,
        crossover: String? = nil, crossoverFails: Bool = false,
        crossdown: String? = nil, crossdownFails: Bool = false,
        below: String? = nil, belowFails: Bool = false
    ) -> ScannerMockHTTPClient {
        // Order: most specific patterns first to avoid substring collisions
        var patterns: [(pattern: String, result: Result<(Data, URLResponse), Error>)] = []

        if aboveFails {
            patterns.append(("latest-above.json", .failure(URLError(.notConnectedToInternet))))
        } else if let json = above {
            patterns.append(("latest-above.json", .success((json.data(using: .utf8)!, response200))))
        }

        if belowFails {
            patterns.append(("latest-below.json", .failure(URLError(.notConnectedToInternet))))
        } else if let json = below {
            patterns.append(("latest-below.json", .success((json.data(using: .utf8)!, response200))))
        }

        if crossdownFails {
            patterns.append(("latest-crossdown.json", .failure(URLError(.notConnectedToInternet))))
        } else if let json = crossdown {
            patterns.append(("latest-crossdown.json", .success((json.data(using: .utf8)!, response200))))
        }

        // Crossover pattern last since "latest.json" could match if patterns weren't specific
        if crossoverFails {
            patterns.append(("latest.json", .failure(URLError(.notConnectedToInternet))))
        } else if let json = crossover {
            patterns.append(("latest.json", .success((json.data(using: .utf8)!, response200))))
        }

        return ScannerMockHTTPClient(patterns: patterns)
    }
}
