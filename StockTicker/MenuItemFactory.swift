import AppKit

// MARK: - Menu Item Factory

enum MenuItemFactory {
    static let monoFont = NSFont.monospacedSystemFont(ofSize: LayoutConfig.Font.size, weight: .regular)
    static let monoFontMedium = NSFont.monospacedSystemFont(ofSize: LayoutConfig.Font.size, weight: .medium)

    static func disabled(title: String, tag: Int) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.tag = tag
        return item
    }

    static func action(title: String, action: Selector, target: AnyObject, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        return item
    }

    static func submenu(title: String, items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()
        items.forEach { menu.addItem($0) }
        item.submenu = menu
        return item
    }
}
