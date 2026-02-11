import Foundation
@testable import StockTicker

// MARK: - Mock File System

final class MockFileSystem: FileSystemProtocol {
    var files: [String: Data] = [:]
    var directories: Set<String> = []
    var writtenFiles: [URL: Data] = [:]
    var createdDirectories: [URL] = []
    var mockHomeDirectory: URL

    init(homeDirectory: String = "/tmp/test") {
        self.mockHomeDirectory = URL(fileURLWithPath: homeDirectory)
    }

    var homeDirectoryForCurrentUser: URL {
        mockHomeDirectory
    }

    func fileExists(atPath path: String) -> Bool {
        files[path] != nil || directories.contains(path)
    }

    func createDirectoryAt(_ url: URL, withIntermediateDirectories: Bool) throws {
        directories.insert(url.path)
        createdDirectories.append(url)
    }

    func contentsOfFile(atPath path: String) -> Data? {
        files[path]
    }

    func writeData(_ data: Data, to url: URL) throws {
        files[url.path] = data
        writtenFiles[url] = data
    }
}

// MARK: - Mock Date Provider

final class MockDateProvider: DateProvider {
    var currentDate: Date

    init(year: Int, month: Int = 1, day: Int = 15, hour: Int = 12, minute: Int = 0, timeZone: TimeZone? = nil) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = timeZone
        self.currentDate = Calendar.current.date(from: components) ?? Date()
    }

    func now() -> Date {
        currentDate
    }
}
