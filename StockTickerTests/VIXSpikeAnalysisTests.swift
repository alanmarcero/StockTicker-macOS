import XCTest
@testable import StockTicker

// MARK: - VIX Spike Analysis Tests

final class VIXSpikeAnalysisTests: XCTestCase {

    // MARK: - No Spikes

    func testDetectSpikes_allBelowThreshold_returnsEmpty() {
        let closes = [15.0, 18.0, 12.0, 19.9, 14.0]
        let timestamps = [1000, 2000, 3000, 4000, 5000]
        let result = VIXSpikeAnalysis.detectSpikes(closes: closes, timestamps: timestamps)
        XCTAssertTrue(result.isEmpty)
    }

    func testDetectSpikes_emptyData_returnsEmpty() {
        let result = VIXSpikeAnalysis.detectSpikes(closes: [], timestamps: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testDetectSpikes_mismatchedArrays_returnsEmpty() {
        let result = VIXSpikeAnalysis.detectSpikes(closes: [25.0], timestamps: [1000, 2000])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Single Spike Day

    func testDetectSpikes_singleSpikeDay_returnsSingleSpike() {
        let closes = [15.0, 25.0, 14.0]
        let timestamps = [1000, 2000, 3000]
        let result = VIXSpikeAnalysis.detectSpikes(closes: closes, timestamps: timestamps)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].timestamp, 2000)
        XCTAssertEqual(result[0].vixClose, 25.0)
    }

    // MARK: - Cluster Detection

    func testDetectSpikes_consecutiveDays_picksHighest() {
        let closes = [22.0, 28.0, 25.0, 21.0, 15.0]
        let timestamps = [1000, 2000, 3000, 4000, 5000]
        let result = VIXSpikeAnalysis.detectSpikes(closes: closes, timestamps: timestamps)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].vixClose, 28.0)
        XCTAssertEqual(result[0].timestamp, 2000)
    }

    // MARK: - Separate Clusters

    func testDetectSpikes_twoClusters_separatedByLargeGap() {
        // Two spike groups separated by more than gapDays
        let closes = [25.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 30.0]
        let timestamps = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000]
        let result = VIXSpikeAnalysis.detectSpikes(closes: closes, timestamps: timestamps, gapDays: 5)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].vixClose, 25.0)
        XCTAssertEqual(result[1].vixClose, 30.0)
    }

    // MARK: - Merging Clusters Within Gap

    func testDetectSpikes_clustersWithinGap_merged() {
        // Two spikes with a gap of 3 (within default gapDays=5)
        let closes = [22.0, 15.0, 14.0, 13.0, 28.0]
        let timestamps = [1000, 2000, 3000, 4000, 5000]
        let result = VIXSpikeAnalysis.detectSpikes(closes: closes, timestamps: timestamps, gapDays: 5)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].vixClose, 28.0)
    }

    // MARK: - Chronological Ordering

    func testDetectSpikes_returnedChronologically() {
        // Two separate spike clusters (gap of 7 indices between them, > gapDays+1=6)
        let closes = [25.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 9.0, 30.0]
        let timestamps = Array(1...9).map { $0 * 1000 }
        let result = VIXSpikeAnalysis.detectSpikes(closes: closes, timestamps: timestamps, gapDays: 5)
        XCTAssertEqual(result.count, 2)
        XCTAssertLessThan(result[0].timestamp, result[1].timestamp)
        XCTAssertEqual(result[0].vixClose, 25.0)
        XCTAssertEqual(result[1].vixClose, 30.0)
    }

    // MARK: - Custom Threshold

    func testDetectSpikes_customThreshold() {
        let closes = [15.0, 18.0, 25.0, 12.0]
        let timestamps = [1000, 2000, 3000, 4000]

        let highThreshold = VIXSpikeAnalysis.detectSpikes(closes: closes, timestamps: timestamps, threshold: 30.0)
        XCTAssertTrue(highThreshold.isEmpty)

        let lowThreshold = VIXSpikeAnalysis.detectSpikes(closes: closes, timestamps: timestamps, threshold: 17.0)
        XCTAssertEqual(lowThreshold.count, 1)
        XCTAssertEqual(lowThreshold[0].vixClose, 25.0)
    }

    // MARK: - Date String Format

    func testDetectSpikes_dateStringFormat() {
        // March 15, 2023 timestamp
        let timestamp = 1678867200
        let closes = [25.0]
        let timestamps = [timestamp]
        let result = VIXSpikeAnalysis.detectSpikes(closes: closes, timestamps: timestamps)
        XCTAssertEqual(result.count, 1)
        XCTAssertFalse(result[0].dateString.isEmpty)
    }
}
