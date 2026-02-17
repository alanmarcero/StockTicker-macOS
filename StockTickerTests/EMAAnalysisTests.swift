import XCTest
@testable import StockTicker

// MARK: - EMA Analysis Tests

final class EMAAnalysisTests: XCTestCase {

    // MARK: - Empty / Insufficient Data

    func testCalculate_emptyCloses_returnsNil() {
        let result = EMAAnalysis.calculate(closes: [])
        XCTAssertNil(result)
    }

    func testCalculate_insufficientData_returnsNil() {
        let closes = [100.0, 101.0, 102.0, 103.0]
        let result = EMAAnalysis.calculate(closes: closes)
        XCTAssertNil(result)
    }

    // MARK: - Exactly Period (SMA)

    func testCalculate_exactlyPeriod_returnsSMA() {
        let closes = [10.0, 20.0, 30.0, 40.0, 50.0]
        let result = EMAAnalysis.calculate(closes: closes)
        XCTAssertEqual(result, 30.0)
    }

    // MARK: - Known Sequence

    func testCalculate_knownSequence_returnsCorrectEMA() {
        // SMA of first 5: (10+20+30+40+50)/5 = 30.0
        // Multiplier: 2/(5+1) = 0.3333
        // EMA[5] = (60 - 30) * 0.3333 + 30 = 40.0
        let closes = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0]
        let result = EMAAnalysis.calculate(closes: closes)!
        XCTAssertEqual(result, 40.0, accuracy: 0.01)
    }

    // MARK: - Constant Values

    func testCalculate_constantValues_returnsConstant() {
        let closes = Array(repeating: 50.0, count: 10)
        let result = EMAAnalysis.calculate(closes: closes)
        XCTAssertEqual(result, 50.0)
    }

    // MARK: - Custom Period

    func testCalculate_customPeriod() {
        let closes = [10.0, 20.0, 30.0, 40.0]
        let result = EMAAnalysis.calculate(closes: closes, period: 3)
        // SMA of first 3: (10+20+30)/3 = 20.0
        // Multiplier: 2/(3+1) = 0.5
        // EMA[3] = (40 - 20) * 0.5 + 20 = 30.0
        XCTAssertEqual(result!, 30.0, accuracy: 0.01)
    }

    // MARK: - Uptrend

    func testCalculate_uptrend_emaRises() {
        let closes = [100.0, 105.0, 110.0, 115.0, 120.0, 125.0, 130.0, 135.0]
        let result = EMAAnalysis.calculate(closes: closes)!
        XCTAssertGreaterThan(result, 110.0)
    }

    // MARK: - Downtrend

    func testCalculate_downtrend_emaFalls() {
        let closes = [135.0, 130.0, 125.0, 120.0, 115.0, 110.0, 105.0, 100.0]
        let result = EMAAnalysis.calculate(closes: closes)!
        XCTAssertLessThan(result, 125.0)
    }

    // MARK: - Default Period

    func testDefaultPeriod_is5() {
        XCTAssertEqual(EMAAnalysis.defaultPeriod, 5)
    }
}
