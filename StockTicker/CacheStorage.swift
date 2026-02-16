import Foundation

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
