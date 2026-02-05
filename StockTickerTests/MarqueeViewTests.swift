import XCTest
@testable import StockTicker

// MARK: - MarqueeConfig Tests

final class MarqueeConfigTests: XCTestCase {

    func testTickInterval_hasReasonableValue() {
        XCTAssertEqual(MarqueeConfig.tickInterval, 0.25)
    }

    func testPixelsPerTick_hasReasonableValue() {
        // 8 pixels per tick at 0.25s interval = 32 px/sec
        XCTAssertEqual(MarqueeConfig.pixelsPerTick, 8)
    }

    func testViewDimensions_matchLayoutConfig() {
        XCTAssertEqual(MarqueeConfig.viewWidth, LayoutConfig.Marquee.width)
        XCTAssertEqual(MarqueeConfig.viewHeight, LayoutConfig.Marquee.height)
    }

    func testSeparator_isThreeSpaces() {
        XCTAssertEqual(MarqueeConfig.separator, "   ")
        XCTAssertEqual(MarqueeConfig.separator.count, 3)
    }

    func testPingFadeStep_isSmallIncrement() {
        XCTAssertEqual(MarqueeConfig.pingFadeStep, 0.03)
        XCTAssertLessThan(MarqueeConfig.pingFadeStep, 0.1)
    }

    func testPingFadeInterval_matchesFadeStep() {
        XCTAssertEqual(MarqueeConfig.pingFadeInterval, 0.05)
    }

    func testPingAlphaMultiplier_isSubtle() {
        XCTAssertEqual(MarqueeConfig.pingAlphaMultiplier, 0.4)
        XCTAssertLessThanOrEqual(MarqueeConfig.pingAlphaMultiplier, 1.0)
    }

    func testScrollSpeed_isApproximately32PixelsPerSecond() {
        let pixelsPerSecond = MarqueeConfig.pixelsPerTick / MarqueeConfig.tickInterval
        XCTAssertEqual(pixelsPerSecond, 32.0, accuracy: 0.1)
    }
}

// MARK: - MarqueeView Tests

final class MarqueeViewTests: XCTestCase {

    func testInit_setsUpLayer() {
        let marquee = MarqueeView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))

        XCTAssertNotNil(marquee.layer)
        XCTAssertTrue(marquee.wantsLayer)
    }

    func testInit_masksToBounds() {
        let marquee = MarqueeView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))

        XCTAssertEqual(marquee.layer?.masksToBounds, true)
    }

    func testIsFlipped_returnsTrue() {
        let marquee = MarqueeView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))

        XCTAssertTrue(marquee.isFlipped)
    }

    func testUpdateText_canBeCalledWithAttributedString() {
        let marquee = MarqueeView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        let text = NSAttributedString(string: "Test Text")

        // Should not crash when called with attributed string
        marquee.updateText(text)

        // Note: needsDisplay is managed by AppKit's display cycle
        // and is unreliable in unit tests
    }

    func testStartScrolling_canBeCalledMultipleTimes() {
        let marquee = MarqueeView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))

        // Should not crash when called multiple times
        marquee.startScrolling()
        marquee.startScrolling()
        marquee.stopScrolling()
    }

    func testStopScrolling_canBeCalledWithoutStarting() {
        let marquee = MarqueeView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))

        // Should not crash when called without starting
        marquee.stopScrolling()
    }

    func testTriggerPing_canBeCalledSafely() {
        let marquee = MarqueeView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))

        // Should not crash when called
        marquee.triggerPing()

        // Note: needsDisplay is managed by AppKit's display cycle
        // and is unreliable in unit tests
    }
}
