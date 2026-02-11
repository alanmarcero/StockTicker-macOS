import XCTest
import SwiftUI
@testable import StockTicker

final class ColorMappingTests: XCTestCase {

    // MARK: - NSColor Mapping

    func testAllNamedColors() {
        XCTAssertEqual(ColorMapping.nsColor(from: "yellow"), .systemYellow)
        XCTAssertEqual(ColorMapping.nsColor(from: "orange"), .systemOrange)
        XCTAssertEqual(ColorMapping.nsColor(from: "red"), .systemRed)
        XCTAssertEqual(ColorMapping.nsColor(from: "pink"), .systemPink)
        XCTAssertEqual(ColorMapping.nsColor(from: "purple"), .systemPurple)
        XCTAssertEqual(ColorMapping.nsColor(from: "blue"), .systemBlue)
        XCTAssertEqual(ColorMapping.nsColor(from: "cyan"), .systemCyan)
        XCTAssertEqual(ColorMapping.nsColor(from: "teal"), .systemTeal)
        XCTAssertEqual(ColorMapping.nsColor(from: "green"), .systemGreen)
        XCTAssertEqual(ColorMapping.nsColor(from: "gray"), .systemGray)
        XCTAssertEqual(ColorMapping.nsColor(from: "brown"), .systemBrown)
    }

    func testGreyAlias() {
        XCTAssertEqual(ColorMapping.nsColor(from: "grey"), .systemGray)
    }

    func testCaseInsensitivity() {
        XCTAssertEqual(ColorMapping.nsColor(from: "Yellow"), .systemYellow)
        XCTAssertEqual(ColorMapping.nsColor(from: "BLUE"), .systemBlue)
        XCTAssertEqual(ColorMapping.nsColor(from: "Red"), .systemRed)
        XCTAssertEqual(ColorMapping.nsColor(from: "GREY"), .systemGray)
    }

    func testDefaultFallback() {
        XCTAssertEqual(ColorMapping.nsColor(from: "invalid"), .systemYellow)
        XCTAssertEqual(ColorMapping.nsColor(from: ""), .systemYellow)
        XCTAssertEqual(ColorMapping.nsColor(from: "magenta"), .systemYellow)
    }

    // MARK: - SwiftUI Color Bridge

    func testSwiftUIColorBridge() {
        let nsColor = ColorMapping.nsColor(from: "blue")
        let swiftUIColor = ColorMapping.color(from: "blue")
        XCTAssertEqual(swiftUIColor, Color(nsColor: nsColor))
    }

    func testSwiftUIColorDefaultFallback() {
        let swiftUIColor = ColorMapping.color(from: "unknown")
        XCTAssertEqual(swiftUIColor, Color(nsColor: .systemYellow))
    }
}
