import Foundation

enum ThrottledTaskGroup {
    private enum Limits {
        static let maxConcurrency = 5
        static let delayNanoseconds: UInt64 = 100_000_000 // 100ms between launches
    }

    enum Backfill {
        static let maxConcurrency = 1
        static let delayNanoseconds: UInt64 = 2_000_000_000 // 2s between launches
    }

    enum FinnhubBackfill {
        static let maxConcurrency = 5
        static let delayNanoseconds: UInt64 = 200_000_000 // 200ms between launches
    }

    enum FinnhubQuote {
        static let maxConcurrency = 5
        static let delayNanoseconds: UInt64 = 200_000_000 // 200ms between launches
        static let maxSymbolsPerCycle = 50  // Stay under 60 req/min
    }

    static func map<T: Sendable>(
        items: [String],
        maxConcurrency: Int = Limits.maxConcurrency,
        delay: UInt64 = Limits.delayNanoseconds,
        operation: @escaping @Sendable (String) async -> T?
    ) async -> [String: T] {
        await withTaskGroup(of: (String, T?).self) { group in
            var results: [String: T] = [:]
            var iterator = items.makeIterator()

            for _ in 0..<min(maxConcurrency, items.count) {
                guard let item = iterator.next() else { break }
                group.addTask { (item, await operation(item)) }
            }

            for await (key, value) in group {
                if let value { results[key] = value }
                if let nextItem = iterator.next() {
                    try? await Task.sleep(nanoseconds: delay)
                    group.addTask { (nextItem, await operation(nextItem)) }
                }
            }
            return results
        }
    }
}
