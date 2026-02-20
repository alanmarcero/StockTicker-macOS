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

    // MARK: - Weekly Crossover Detection

    func testDetectWeeklyCrossover_noData_returnsNil() {
        let result = EMAAnalysis.detectWeeklyCrossover(closes: [])
        XCTAssertNil(result)
    }

    func testDetectWeeklyCrossover_insufficientData_returnsNil() {
        let result = EMAAnalysis.detectWeeklyCrossover(closes: [100.0, 101.0, 102.0, 103.0, 104.0])
        XCTAssertNil(result)
    }

    func testDetectWeeklyCrossover_noCrossover_allAbove_returnsNil() {
        // All closes above their EMA — no crossover
        let closes = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
        let result = EMAAnalysis.detectWeeklyCrossover(closes: closes)
        XCTAssertNil(result)
    }

    func testDetectWeeklyCrossover_noCrossover_allBelow_returnsNil() {
        // All closes below their EMA — downtrend, no crossover
        let closes = [100.0, 90.0, 80.0, 70.0, 60.0, 50.0, 40.0, 30.0, 20.0, 10.0]
        let result = EMAAnalysis.detectWeeklyCrossover(closes: closes)
        XCTAssertNil(result)
    }

    func testDetectWeeklyCrossover_crossover_oneWeekBelow() {
        // Build: above EMA for a while, then one week below, then cross back above
        // Period=5, SMA seed from first 5
        // First 5: [50, 52, 54, 56, 58] → SMA = 54.0
        // idx5: close=56, EMA = (56-54)*0.3333+54 = 54.667 → 56 > 54.667 (above)
        // idx6: close=53, EMA = (53-54.667)*0.3333+54.667 = 54.111 → 53 < 54.111 (below)
        // idx7: close=56, EMA = (56-54.111)*0.3333+54.111 = 54.740 → 56 > 54.740 (above — crossover!)
        let closes = [50.0, 52.0, 54.0, 56.0, 58.0, 56.0, 53.0, 56.0]
        let result = EMAAnalysis.detectWeeklyCrossover(closes: closes)
        XCTAssertEqual(result, 1)
    }

    func testDetectWeeklyCrossover_crossover_threeWeeksBelow() {
        // Uptrend, then three weeks below EMA, then cross above
        // First 5: [100, 102, 104, 106, 108] → SMA = 104.0
        // idx5: close=100, EMA=102.667 → below
        // idx6: close=101, EMA=102.111 → below
        // idx7: close=101, EMA=101.741 → below
        // idx8: close=106, EMA=103.160 → above — crossover!
        let closes = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0, 101.0, 106.0]
        let result = EMAAnalysis.detectWeeklyCrossover(closes: closes)
        XCTAssertEqual(result, 3)
    }

    func testDetectWeeklyCrossover_crossover_atBoundary() {
        // Minimum data: period+1 = 6 closes, crossover at last bar
        // First 5: [50, 48, 46, 44, 42] → SMA = 46.0
        // idx5: close=48, EMA = (48-46)*0.3333+46 = 46.667 → 48 > 46.667 (above)
        // Need previous close at or below EMA. idx4 = 42, EMA at that point = SMA = 46.0, 42 <= 46 (below)
        let closes = [50.0, 48.0, 46.0, 44.0, 42.0, 48.0]
        let result = EMAAnalysis.detectWeeklyCrossover(closes: closes)
        XCTAssertEqual(result, 1)
    }

    // MARK: - Count Weeks Below

    func testCountWeeksBelow_noData_returnsNil() {
        let result = EMAAnalysis.countWeeksBelow(closes: [])
        XCTAssertNil(result)
    }

    func testCountWeeksBelow_insufficientData_returnsNil() {
        let result = EMAAnalysis.countWeeksBelow(closes: [100.0, 101.0, 102.0, 103.0, 104.0])
        XCTAssertNil(result)
    }

    func testCountWeeksBelow_aboveEMA_returnsNil() {
        // Strong uptrend — last close above EMA
        let closes = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
        let result = EMAAnalysis.countWeeksBelow(closes: closes)
        XCTAssertNil(result)
    }

    func testCountWeeksBelow_oneWeekBelow() {
        // Uptrend then one week drop below EMA
        // First 5: [50, 52, 54, 56, 58] → SMA = 54.0
        // idx5: close=56, EMA = (56-54)*0.3333+54 = 54.667 → 56 > 54.667 (above)
        // idx6: close=53, EMA = (53-54.667)*0.3333+54.667 = 54.111 → 53 <= 54.111 (below)
        let closes = [50.0, 52.0, 54.0, 56.0, 58.0, 56.0, 53.0]
        let result = EMAAnalysis.countWeeksBelow(closes: closes)
        XCTAssertEqual(result, 1)
    }

    func testCountWeeksBelow_threeWeeksBelow() {
        // Downtrend — all closes below EMA after initial setup
        // First 5: [100, 102, 104, 106, 108] → SMA = 104.0
        // idx5: close=100, EMA=102.667 → below
        // idx6: close=101, EMA=102.111 → below
        // idx7: close=101, EMA=101.741 → below
        let closes = [100.0, 102.0, 104.0, 106.0, 108.0, 100.0, 101.0, 101.0]
        let result = EMAAnalysis.countWeeksBelow(closes: closes)
        XCTAssertEqual(result, 3)
    }

    func testCountWeeksBelow_atBoundary() {
        // Minimum data: period+1 = 6 closes, last close at or below EMA
        // First 5: [50, 52, 54, 56, 58] → SMA = 54.0
        // idx5: close=50, EMA = (50-54)*0.3333+54 = 52.667 → 50 <= 52.667 (below)
        let closes = [50.0, 52.0, 54.0, 56.0, 58.0, 50.0]
        let result = EMAAnalysis.countWeeksBelow(closes: closes)
        XCTAssertEqual(result, 1)
    }
}
