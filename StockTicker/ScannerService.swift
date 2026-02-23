import Foundation

// MARK: - Scanner Response Models

struct ScannerAboveItem: Codable, Equatable {
    let symbol: String
    let close: Double
    let ema: Double
    let pctAbove: Double
    let count: Int
}

struct ScannerCrossoverItem: Codable, Equatable {
    let symbol: String
    let close: Double
    let ema: Double
    let pctAbove: Double
    let weeksBelow: Int
}

struct ScannerBelowItem: Codable, Equatable {
    let symbol: String
    let close: Double
    let ema: Double
    let pctBelow: Double
    let weeksBelow: Int
}

struct ScannerAboveResponse: Codable {
    let dayAbove: [ScannerAboveItem]
    let weekAbove: [ScannerAboveItem]
}

struct ScannerCrossoverResponse: Codable {
    let crossovers: [ScannerCrossoverItem]
}

struct ScannerBelowResponse: Codable {
    let below: [ScannerBelowItem]
}

struct ScannerEMAData: Equatable {
    let dayAbove: [ScannerAboveItem]
    let weekAbove: [ScannerAboveItem]
    let crossovers: [ScannerCrossoverItem]
    let below: [ScannerBelowItem]
}

// MARK: - Protocol

protocol ScannerServiceProtocol: Sendable {
    func fetchEMAData(baseURL: String) async -> ScannerEMAData?
}

// MARK: - Scanner Service

actor ScannerService: ScannerServiceProtocol {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = LoggingHTTPClient()) {
        self.httpClient = httpClient
    }

    func fetchEMAData(baseURL: String) async -> ScannerEMAData? {
        let trimmed = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL

        guard let aboveURL = URL(string: "\(trimmed)/results/latest-above.json"),
              let crossoverURL = URL(string: "\(trimmed)/results/latest.json"),
              let belowURL = URL(string: "\(trimmed)/results/latest-below.json") else {
            return nil
        }

        async let aboveResult = fetchJSON(ScannerAboveResponse.self, from: aboveURL)
        async let crossoverResult = fetchJSON(ScannerCrossoverResponse.self, from: crossoverURL)
        async let belowResult = fetchJSON(ScannerBelowResponse.self, from: belowURL)

        guard let above = await aboveResult,
              let crossover = await crossoverResult,
              let below = await belowResult else {
            return nil
        }

        return ScannerEMAData(
            dayAbove: above.dayAbove,
            weekAbove: above.weekAbove,
            crossovers: crossover.crossovers,
            below: below.below
        )
    }

    private func fetchJSON<T: Decodable>(_ type: T.Type, from url: URL) async -> T? {
        do {
            let (data, response) = try await httpClient.data(from: url)
            guard response.isSuccessfulHTTP else { return nil }
            return try JSONDecoder().decode(type, from: data)
        } catch {
            return nil
        }
    }
}
