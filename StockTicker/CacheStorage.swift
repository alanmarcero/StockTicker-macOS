import Foundation

// MARK: - Cache Timestamp Utilities

enum CacheTimestamp {
    static func current(dateProvider: DateProvider) -> String {
        ISO8601DateFormatter().string(from: dateProvider.now())
    }

    static func needsDailyRefresh(lastUpdated: String, dateProvider: DateProvider) -> Bool {
        let formatter = ISO8601DateFormatter()
        guard let lastDate = formatter.date(from: lastUpdated) else { return true }
        return !Calendar.current.isDate(lastDate, inSameDayAs: dateProvider.now())
    }
}

// MARK: - Generic Cache Storage

struct CacheStorage<T: Codable> {
    let fileSystem: FileSystemProtocol
    let cacheURL: URL
    let label: String

    func load() -> T? {
        guard fileSystem.fileExists(atPath: cacheURL.path),
              let data = fileSystem.contentsOfFile(atPath: cacheURL.path) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Failed to decode \(label) cache: \(error.localizedDescription)")
            return nil
        }
    }

    func save(_ value: T) {
        let directory = cacheURL.deletingLastPathComponent()
        if !fileSystem.fileExists(atPath: directory.path) {
            do {
                try fileSystem.createDirectoryAt(directory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create \(label) cache directory: \(error.localizedDescription)")
                return
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(value)
            try fileSystem.writeData(data, to: cacheURL)
        } catch {
            print("Failed to save \(label) cache: \(error.localizedDescription)")
        }
    }
}
