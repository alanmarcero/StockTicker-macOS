import Foundation

// MARK: - Request Log Entry

struct RequestLogEntry: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let method: String
    let url: URL
    let statusCode: Int?
    let responseSize: Int?
    let duration: TimeInterval
    let error: String?
    let requestHeaders: [String: String]
    let responseHeaders: [String: String]
    let responseBody: String?

    init(
        method: String = "GET",
        url: URL,
        statusCode: Int? = nil,
        responseSize: Int? = nil,
        duration: TimeInterval,
        error: String? = nil,
        requestHeaders: [String: String] = [:],
        responseHeaders: [String: String] = [:],
        responseBody: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.responseSize = responseSize
        self.duration = duration
        self.error = error
        self.requestHeaders = requestHeaders
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var formattedDuration: String {
        String(format: "%.0fms", duration * 1000)
    }

    var formattedSize: String {
        guard let size = responseSize else { return "--" }
        if size < 1024 {
            return "\(size) B"
        } else {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        }
    }

    var statusDescription: String {
        if let error = error {
            return "Error: \(error)"
        }
        guard let code = statusCode else { return "--" }
        return "\(code)"
    }

    var isSuccess: Bool {
        guard let code = statusCode else { return false }
        return (200..<300).contains(code)
    }

    // MARK: - Copy Helpers

    var formattedRequestHeaders: String {
        if requestHeaders.isEmpty {
            return "(no headers)"
        }
        return requestHeaders.map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n")
    }

    var formattedResponseHeaders: String {
        if responseHeaders.isEmpty {
            return "(no headers)"
        }
        return responseHeaders.map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n")
    }

    var formattedResponseBody: String {
        guard let body = responseBody else { return "(no body)" }
        // Try to pretty-print JSON
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        return body
    }

    var copyableRequest: String {
        """
        \(method) \(url.absoluteString)

        Headers:
        \(formattedRequestHeaders)
        """
    }

    var copyableResponse: String {
        """
        Status: \(statusDescription)
        Duration: \(formattedDuration)
        Size: \(formattedSize)

        Headers:
        \(formattedResponseHeaders)

        Body:
        \(formattedResponseBody)
        """
    }
}

// MARK: - Request Logger

actor RequestLogger {
    static let shared = RequestLogger()

    private enum Constants {
        static let maxEntryAgeSeconds: TimeInterval = 60
    }

    private var entries: [RequestLogEntry] = []

    private init() {}

    func log(_ entry: RequestLogEntry) {
        pruneOldEntries()
        entries.append(entry)
    }

    func getEntries() -> [RequestLogEntry] {
        pruneOldEntries()
        return entries.sorted { $0.timestamp > $1.timestamp }
    }

    func clear() {
        entries.removeAll()
    }

    private func pruneOldEntries() {
        let cutoff = Date().addingTimeInterval(-Constants.maxEntryAgeSeconds)
        entries.removeAll { $0.timestamp < cutoff }
    }
}

// MARK: - Logging HTTP Client

final class LoggingHTTPClient: HTTPClient, @unchecked Sendable {
    private let wrapped: HTTPClient
    private let logger: RequestLogger

    private enum RetryConfig {
        static let maxAttempts = 2
        static let retryDelayNanoseconds: UInt64 = 500_000_000  // 0.5 seconds

        /// Skip retries during extended hours (pre-market/after-hours) since data is less critical
        static var shouldRetry: Bool {
            let session = StockQuote.currentTimeBasedSession()
            return session == .regular || session == .closed
        }
    }

    init(wrapping client: HTTPClient = URLSession.shared, logger: RequestLogger = .shared) {
        self.wrapped = client
        self.logger = logger
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 1...RetryConfig.maxAttempts {
            let startTime = Date()

            do {
                let (data, response) = try await wrapped.data(from: url)
                let duration = Date().timeIntervalSince(startTime)
                let httpResponse = response as? HTTPURLResponse
                let statusCode = httpResponse?.statusCode

                // Capture response headers
                var responseHeaders: [String: String] = [:]
                if let allHeaders = httpResponse?.allHeaderFields {
                    for (key, value) in allHeaders {
                        responseHeaders[String(describing: key)] = String(describing: value)
                    }
                }

                // Capture response body (limit to 50KB to avoid memory issues)
                let maxBodySize = 50 * 1024
                let bodyString: String?
                if data.count <= maxBodySize {
                    bodyString = String(data: data, encoding: .utf8)
                } else {
                    bodyString = "(body too large: \(data.count) bytes)"
                }

                let entry = RequestLogEntry(
                    url: url,
                    statusCode: statusCode,
                    responseSize: data.count,
                    duration: duration,
                    responseHeaders: responseHeaders,
                    responseBody: bodyString
                )
                await logger.log(entry)

                // Retry on non-2xx status codes (skip during extended hours)
                if let code = statusCode, !(200..<300).contains(code) {
                    if attempt < RetryConfig.maxAttempts && RetryConfig.shouldRetry {
                        try? await Task.sleep(nanoseconds: RetryConfig.retryDelayNanoseconds)
                        continue
                    }
                }

                return (data, response)

            } catch {
                let duration = Date().timeIntervalSince(startTime)

                let entry = RequestLogEntry(
                    url: url,
                    duration: duration,
                    error: error.localizedDescription
                )
                await logger.log(entry)

                lastError = error

                // Retry on network errors (skip during extended hours)
                if attempt < RetryConfig.maxAttempts && RetryConfig.shouldRetry {
                    try? await Task.sleep(nanoseconds: RetryConfig.retryDelayNanoseconds)
                    continue
                }
            }
        }

        throw lastError ?? URLError(.unknown)
    }
}
