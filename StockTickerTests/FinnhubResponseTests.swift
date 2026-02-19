import XCTest
@testable import StockTicker

final class FinnhubResponseTests: XCTestCase {

    // MARK: - FinnhubCandleResponse decoding

    func testDecode_validOkResponse_parsesCorrectly() throws {
        let json = """
        {"c":[150.0,152.5,148.3],"t":[1700000000,1700086400,1700172800],"s":"ok","h":[155.0,156.0,153.0],"l":[149.0,150.0,147.0],"o":[151.0,153.0,149.0],"v":[1000000,1200000,900000]}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(FinnhubCandleResponse.self, from: data)

        XCTAssertTrue(response.isValid)
        XCTAssertEqual(response.c, [150.0, 152.5, 148.3])
        XCTAssertEqual(response.t, [1700000000, 1700086400, 1700172800])
        XCTAssertEqual(response.s, "ok")
    }

    func testDecode_noDataStatus_isNotValid() throws {
        let json = """
        {"s":"no_data"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(FinnhubCandleResponse.self, from: data)

        XCTAssertFalse(response.isValid)
        XCTAssertNil(response.c)
        XCTAssertNil(response.t)
    }

    func testDecode_okWithNullFields_isValidButNilArrays() throws {
        let json = """
        {"c":null,"t":null,"s":"ok"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(FinnhubCandleResponse.self, from: data)

        XCTAssertTrue(response.isValid)
        XCTAssertNil(response.c)
        XCTAssertNil(response.t)
    }

    func testDecode_emptyArrays_isValidWithEmptyData() throws {
        let json = """
        {"c":[],"t":[],"s":"ok"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(FinnhubCandleResponse.self, from: data)

        XCTAssertTrue(response.isValid)
        XCTAssertEqual(response.c, [])
        XCTAssertEqual(response.t, [])
    }

    func testDecode_minimalOkResponse_parsesWithoutExtraFields() throws {
        let json = """
        {"c":[100.0],"t":[1700000000],"s":"ok"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(FinnhubCandleResponse.self, from: data)

        XCTAssertTrue(response.isValid)
        XCTAssertEqual(response.c?.count, 1)
        XCTAssertEqual(response.t?.count, 1)
    }

    func testIsValid_okStatus_returnsTrue() {
        let response = FinnhubCandleResponse(c: [100.0], t: [1700000000], s: "ok")
        XCTAssertTrue(response.isValid)
    }

    func testIsValid_noDataStatus_returnsFalse() {
        let response = FinnhubCandleResponse(c: nil, t: nil, s: "no_data")
        XCTAssertFalse(response.isValid)
    }

    func testIsValid_unknownStatus_returnsFalse() {
        let response = FinnhubCandleResponse(c: nil, t: nil, s: "error")
        XCTAssertFalse(response.isValid)
    }
}
