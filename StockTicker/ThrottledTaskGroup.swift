import Foundation

enum ThrottledTaskGroup {
    private enum Limits {
        static let maxConcurrency = 20
    }

    static func map<T: Sendable>(
        items: [String],
        maxConcurrency: Int = Limits.maxConcurrency,
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
                    group.addTask { (nextItem, await operation(nextItem)) }
                }
            }
            return results
        }
    }
}
