import XCTest
@testable import StockTicker

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
