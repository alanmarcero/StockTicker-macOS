import XCTest
@testable import StockTicker

// MARK: - RSI Analysis Tests

final class RSIAnalysisTests: XCTestCase {

    // MARK: - Empty / Insufficient Data

    func testCalculate_emptyCloses_returnsNil() {
        let result = RSIAnalysis.calculate(closes: [])
        XCTAssertNil(result)
    }

    func testCalculate_insufficientData_returnsNil() {
        let closes = Array(repeating: 100.0, count: 14)
        let result = RSIAnalysis.calculate(closes: closes)
        XCTAssertNil(result)
    }

    func testCalculate_exactlyPeriodPlusOne_returnsValue() {
        let closes = Array(repeating: 100.0, count: 15)
        let result = RSIAnalysis.calculate(closes: closes)
        XCTAssertNotNil(result)
    }

    // MARK: - All Gains

    func testCalculate_allGains_returns100() {
        let closes = (0...20).map { Double($0) * 10.0 + 100.0 }
        let result = RSIAnalysis.calculate(closes: closes)
        XCTAssertEqual(result, 100.0)
    }

    // MARK: - All Losses

    func testCalculate_allLosses_returnsNearZero() {
        let closes = (0...20).map { 200.0 - Double($0) * 5.0 }
        let result = RSIAnalysis.calculate(closes: closes)!
        XCTAssertLessThan(result, 1.0)
    }

    // MARK: - Alternating

    func testCalculate_alternating_returnsNear50() {
        var closes: [Double] = []
        for i in 0...30 {
            closes.append(i % 2 == 0 ? 100.0 : 110.0)
        }
        let result = RSIAnalysis.calculate(closes: closes)!
        XCTAssertEqual(result, 50.0, accuracy: 5.0)
    }

    // MARK: - Strong Uptrend

    func testCalculate_strongUptrend_above70() {
        // Most gains, few small losses
        var closes: [Double] = [100.0]
        for _ in 1...30 {
            let last = closes.last!
            closes.append(last + 3.0)
        }
        // Add one small dip
        closes[15] = closes[14] - 0.5
        let result = RSIAnalysis.calculate(closes: closes)!
        XCTAssertGreaterThan(result, 70.0)
    }

    // MARK: - Strong Downtrend

    func testCalculate_strongDowntrend_below30() {
        var closes: [Double] = [200.0]
        for _ in 1...30 {
            let last = closes.last!
            closes.append(last - 3.0)
        }
        // Add one small bounce
        closes[15] = closes[14] + 0.5
        let result = RSIAnalysis.calculate(closes: closes)!
        XCTAssertLessThan(result, 30.0)
    }

    // MARK: - Custom Period

    func testCalculate_customPeriod() {
        let closes = (0...10).map { Double($0) * 5.0 + 100.0 }
        let result = RSIAnalysis.calculate(closes: closes, period: 5)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, 100.0)
    }

    // MARK: - Default Period

    func testDefaultPeriod_is14() {
        XCTAssertEqual(RSIAnalysis.defaultPeriod, 14)
    }
}
