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

    // MARK: - FinnhubQuoteResponse decoding

    func testQuoteDecode_validResponse_parsesCorrectly() throws {
        let json = """
        {"c":263.84,"d":-0.51,"dp":-0.1929,"h":264.48,"l":262.29,"o":263.21,"pc":264.35,"t":1771519213}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: data)

        XCTAssertEqual(response.c, 263.84)
        XCTAssertEqual(response.d, -0.51)
        XCTAssertEqual(response.dp, -0.1929)
        XCTAssertEqual(response.h, 264.48)
        XCTAssertEqual(response.l, 262.29)
        XCTAssertEqual(response.o, 263.21)
        XCTAssertEqual(response.pc, 264.35)
        XCTAssertEqual(response.t, 1771519213)
        XCTAssertTrue(response.isValid)
    }

    func testQuoteDecode_zeroPrice_isNotValid() throws {
        let json = """
        {"c":0,"d":null,"dp":null,"h":0,"l":0,"o":0,"pc":0,"t":0}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: data)

        XCTAssertFalse(response.isValid)
        XCTAssertEqual(response.c, 0)
        XCTAssertEqual(response.pc, 0)
    }

    func testQuoteDecode_nullChangeFields_parsesCorrectly() throws {
        let json = """
        {"c":150.0,"d":null,"dp":null,"h":152.0,"l":148.0,"o":149.0,"pc":148.5,"t":1700000000}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: data)

        XCTAssertTrue(response.isValid)
        XCTAssertNil(response.d)
        XCTAssertNil(response.dp)
        XCTAssertEqual(response.c, 150.0)
        XCTAssertEqual(response.pc, 148.5)
    }

    func testQuoteIsValid_positivePriceAndClose_returnsTrue() {
        let response = FinnhubQuoteResponse(c: 100.0, d: 1.0, dp: 1.0, h: 101.0, l: 99.0, o: 99.5, pc: 99.0, t: 1700000000)
        XCTAssertTrue(response.isValid)
    }

    func testQuoteIsValid_zeroPreviousClose_returnsFalse() {
        let response = FinnhubQuoteResponse(c: 100.0, d: nil, dp: nil, h: 100.0, l: 100.0, o: 100.0, pc: 0, t: 0)
        XCTAssertFalse(response.isValid)
    }

    func testQuoteIsValid_negativePrice_returnsFalse() {
        let response = FinnhubQuoteResponse(c: -1.0, d: nil, dp: nil, h: 0, l: 0, o: 0, pc: 100.0, t: 0)
        XCTAssertFalse(response.isValid)
    }
}
