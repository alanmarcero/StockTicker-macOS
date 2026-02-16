import XCTest
@testable import StockTicker

// MARK: - Swing Analysis Tests

final class SwingAnalysisTests: XCTestCase {

    // MARK: - Empty / Trivial Input

    func testAnalyze_emptyCloses_returnsNils() {
        let result = SwingAnalysis.analyze(closes: [])
        XCTAssertNil(result.breakoutPrice)
        XCTAssertNil(result.breakdownPrice)
    }

    func testAnalyze_singleClose_returnsNils() {
        let result = SwingAnalysis.analyze(closes: [100.0])
        XCTAssertNil(result.breakoutPrice)
        XCTAssertNil(result.breakdownPrice)
    }

    // MARK: - Breakout Detection

    func testAnalyze_steadyRise_noBreakout() {
        // Prices only go up — no 10% decline ever occurs
        let closes = [100.0, 105.0, 110.0, 115.0, 120.0, 125.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertNil(result.breakoutPrice)
    }

    func testAnalyze_single10PercentDrop_detectsBreakout() {
        // Peak at 100, then drops to 90 (exactly 10% decline)
        let closes = [100.0, 90.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertEqual(result.breakoutPrice, 100.0)
    }

    func testAnalyze_largerDrop_detectsBreakout() {
        // Peak at 200, then drops to 170 (15% decline)
        let closes = [150.0, 180.0, 200.0, 190.0, 170.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertEqual(result.breakoutPrice, 200.0)
    }

    func testAnalyze_lessThan10PercentDrop_noBreakout() {
        // Peak at 100, drops to 91 (only 9% decline)
        let closes = [100.0, 91.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertNil(result.breakoutPrice)
    }

    func testAnalyze_multipleSwingHighs_returnsHighest() {
        // First peak 100 → drops to 89 (11% decline) — significant high at 100
        // Second peak 150 → drops to 130 (13.3% decline) — significant high at 150
        let closes = [100.0, 89.0, 120.0, 150.0, 130.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertEqual(result.breakoutPrice, 150.0)
    }

    // MARK: - Breakdown Detection

    func testAnalyze_steadyDecline_noBreakdown() {
        // Prices only go down — no 10% rise ever occurs
        let closes = [100.0, 95.0, 90.0, 85.0, 80.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertNil(result.breakdownPrice)
    }

    func testAnalyze_single10PercentRise_detectsBreakdown() {
        // Trough at 100, then rises to 110 (exactly 10% rise)
        let closes = [100.0, 110.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertEqual(result.breakdownPrice, 100.0)
    }

    func testAnalyze_largerRise_detectsBreakdown() {
        // Drops to 80, then rises to 96 (20% rise from 80)
        let closes = [100.0, 90.0, 80.0, 88.0, 96.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertEqual(result.breakdownPrice, 80.0)
    }

    func testAnalyze_lessThan10PercentRise_noBreakdown() {
        // Trough at 100, rises to 109 (only 9% rise)
        let closes = [100.0, 109.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertNil(result.breakdownPrice)
    }

    func testAnalyze_multipleSwingLows_returnsLowest() {
        // First trough 80 → rises to 90 (12.5% rise) — significant low at 80
        // Second trough 70 → rises to 80 (14.3% rise) — significant low at 70
        let closes = [100.0, 80.0, 90.0, 70.0, 80.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertEqual(result.breakdownPrice, 70.0)
    }

    // MARK: - Combined Detection

    func testAnalyze_bothBreakoutAndBreakdown() {
        // Peak at 200 → drops to 170 (15% decline) → trough at 150 → rises to 170 (13.3% rise)
        let closes = [150.0, 180.0, 200.0, 175.0, 170.0, 150.0, 165.0, 170.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertNotNil(result.breakoutPrice)
        XCTAssertNotNil(result.breakdownPrice)
    }

    // MARK: - Exact Threshold

    func testAnalyze_exact10PercentDrop_isDetected() {
        // 100 * 0.10 = 10, so 100 → 90 is exactly 10%
        let closes = [100.0, 90.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertEqual(result.breakoutPrice, 100.0)
    }

    func testAnalyze_exact10PercentRise_isDetected() {
        // 100 * 0.10 = 10, so 100 → 110 is exactly 10%
        let closes = [100.0, 110.0]
        let result = SwingAnalysis.analyze(closes: closes)
        XCTAssertEqual(result.breakdownPrice, 100.0)
    }

    // MARK: - Threshold Constant

    func testThreshold_is10Percent() {
        XCTAssertEqual(SwingAnalysis.threshold, 0.10)
    }
}
