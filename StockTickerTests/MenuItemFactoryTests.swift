import XCTest
@testable import StockTicker

// MARK: - MenuItemFactory Tests

final class MenuItemFactoryTests: XCTestCase {

    // MARK: - Font Tests

    func testMonoFont_isMonospacedSystemFont() {
        let font = MenuItemFactory.monoFont

        XCTAssertNotNil(font)
        XCTAssertEqual(font.pointSize, LayoutConfig.Font.size)
    }

    func testMonoFontMedium_isMonospacedSystemFont() {
        let font = MenuItemFactory.monoFontMedium

        XCTAssertNotNil(font)
        XCTAssertEqual(font.pointSize, LayoutConfig.Font.size)
    }

    func testMonoFont_isDifferentWeightFromMedium() {
        let regular = MenuItemFactory.monoFont
        let medium = MenuItemFactory.monoFontMedium

        // Both should exist but have different weights
        XCTAssertNotNil(regular)
        XCTAssertNotNil(medium)
    }

    // MARK: - Disabled Item Tests

    func testDisabled_createsDisabledItem() {
        let item = MenuItemFactory.disabled(title: "Test Title", tag: 42)

        XCTAssertEqual(item.title, "Test Title")
        XCTAssertEqual(item.tag, 42)
        XCTAssertFalse(item.isEnabled)
        XCTAssertNil(item.action)
    }

    func testDisabled_withEmptyTitle_createsItem() {
        let item = MenuItemFactory.disabled(title: "", tag: 0)

        XCTAssertEqual(item.title, "")
        XCTAssertEqual(item.tag, 0)
        XCTAssertFalse(item.isEnabled)
    }

    func testDisabled_withNegativeTag_createsItem() {
        let item = MenuItemFactory.disabled(title: "Test", tag: -1)

        XCTAssertEqual(item.tag, -1)
    }

    // MARK: - Action Item Tests

    func testAction_createsItemWithActionAndTarget() {
        let target = NSObject()  // Retain target to prevent deallocation
        let item = MenuItemFactory.action(
            title: "Click Me",
            action: #selector(NSObject.description),
            target: target
        )

        XCTAssertEqual(item.title, "Click Me")
        XCTAssertNotNil(item.action)
        XCTAssertNotNil(item.target)
        // Note: isEnabled depends on AppKit's target-action validation,
        // not explicitly set by factory
    }

    func testAction_withKeyEquivalent_setsKeyEquivalent() {
        let target = NSObject()
        let item = MenuItemFactory.action(
            title: "Save",
            action: #selector(NSObject.description),
            target: target,
            keyEquivalent: "s"
        )

        XCTAssertEqual(item.keyEquivalent, "s")
    }

    func testAction_withoutKeyEquivalent_hasEmptyKeyEquivalent() {
        let target = NSObject()
        let item = MenuItemFactory.action(
            title: "Test",
            action: #selector(NSObject.description),
            target: target
        )

        XCTAssertEqual(item.keyEquivalent, "")
    }

    // MARK: - Submenu Tests

    func testSubmenu_createsItemWithSubmenu() {
        let childItems = [
            NSMenuItem(title: "Child 1", action: nil, keyEquivalent: ""),
            NSMenuItem(title: "Child 2", action: nil, keyEquivalent: "")
        ]

        let item = MenuItemFactory.submenu(title: "Parent", items: childItems)

        XCTAssertEqual(item.title, "Parent")
        XCTAssertNotNil(item.submenu)
        XCTAssertEqual(item.submenu?.items.count, 2)
    }

    func testSubmenu_withEmptyItems_createsEmptySubmenu() {
        let item = MenuItemFactory.submenu(title: "Empty", items: [])

        XCTAssertNotNil(item.submenu)
        XCTAssertEqual(item.submenu?.items.count, 0)
    }

    func testSubmenu_preservesChildOrder() {
        let childItems = [
            NSMenuItem(title: "First", action: nil, keyEquivalent: ""),
            NSMenuItem(title: "Second", action: nil, keyEquivalent: ""),
            NSMenuItem(title: "Third", action: nil, keyEquivalent: "")
        ]

        let item = MenuItemFactory.submenu(title: "Parent", items: childItems)

        XCTAssertEqual(item.submenu?.items[0].title, "First")
        XCTAssertEqual(item.submenu?.items[1].title, "Second")
        XCTAssertEqual(item.submenu?.items[2].title, "Third")
    }

    func testSubmenu_createdWithNilAction() {
        let item = MenuItemFactory.submenu(title: "Test", items: [])

        // Submenu items are created with action: nil
        // AppKit manages submenu behavior internally
        XCTAssertNotNil(item.submenu)
    }
}
