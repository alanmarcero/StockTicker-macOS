import XCTest
@testable import StockTicker

final class CacheStorageTests: XCTestCase {

    private struct TestData: Codable, Equatable {
        let name: String
        let value: Int
    }

    private let testCacheDirectory = URL(fileURLWithPath: "/tmp/test-cache")
    private let testCacheFile = "/tmp/test-cache/test.json"

    private func makeStorage(mockFS: MockFileSystem) -> CacheStorage<TestData> {
        CacheStorage(
            fileSystem: mockFS,
            cacheURL: URL(fileURLWithPath: testCacheFile),
            label: "test"
        )
    }

    // MARK: - Load Tests

    func testLoad_whenFileDoesNotExist_returnsNil() {
        let mockFS = MockFileSystem()
        let storage = makeStorage(mockFS: mockFS)

        XCTAssertNil(storage.load())
    }

    func testLoad_whenFileExistsWithValidData_returnsDecoded() {
        let mockFS = MockFileSystem()
        let testData = TestData(name: "hello", value: 42)
        let jsonData = try! JSONEncoder().encode(testData)
        mockFS.files[testCacheFile] = jsonData

        let storage = makeStorage(mockFS: mockFS)

        let loaded = storage.load()
        XCTAssertEqual(loaded, testData)
    }

    func testLoad_whenFileContainsCorruptData_returnsNil() {
        let mockFS = MockFileSystem()
        mockFS.files[testCacheFile] = Data("not json".utf8)

        let storage = makeStorage(mockFS: mockFS)

        XCTAssertNil(storage.load())
    }

    // MARK: - Save Tests

    func testSave_writesEncodedDataToFile() {
        let mockFS = MockFileSystem()
        let storage = makeStorage(mockFS: mockFS)
        let testData = TestData(name: "saved", value: 99)

        storage.save(testData)

        let cacheURL = URL(fileURLWithPath: testCacheFile)
        let writtenData = mockFS.writtenFiles[cacheURL]
        XCTAssertNotNil(writtenData)

        let decoded = try! JSONDecoder().decode(TestData.self, from: writtenData!)
        XCTAssertEqual(decoded, testData)
    }

    func testSave_createsDirectoryIfMissing() {
        let mockFS = MockFileSystem()
        let storage = makeStorage(mockFS: mockFS)

        storage.save(TestData(name: "test", value: 1))

        XCTAssertFalse(mockFS.createdDirectories.isEmpty)
        XCTAssertEqual(mockFS.createdDirectories.first?.path, testCacheDirectory.path)
    }

    func testSave_skipsDirectoryCreationIfExists() {
        let mockFS = MockFileSystem()
        mockFS.directories.insert(testCacheDirectory.path)
        let storage = makeStorage(mockFS: mockFS)

        storage.save(TestData(name: "test", value: 1))

        XCTAssertTrue(mockFS.createdDirectories.isEmpty)
    }

    // MARK: - Round-trip Test

    func testSave_thenLoad_roundTrips() {
        let mockFS = MockFileSystem()
        let storage = makeStorage(mockFS: mockFS)
        let testData = TestData(name: "roundtrip", value: 123)

        storage.save(testData)

        let loaded = storage.load()
        XCTAssertEqual(loaded, testData)
    }
}
