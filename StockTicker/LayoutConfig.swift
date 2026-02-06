import Foundation

// MARK: - Centralized Layout Configuration
// All width, height, and size constants for the app in one place

enum LayoutConfig {

    // MARK: - Menu Bar Ticker Display

    enum Ticker {
        static let symbolWidth = 6
        static let priceWidth = 9
        static let changeWidth = 8
        static let percentWidth = 7
        static let ytdWidth = 13  // "YTD: +12.34%"
        static let extendedHoursWidth = 12  // "Pre: +12.34%"
    }

    // MARK: - Font Sizes

    enum Font {
        static let size: CGFloat = 12
        static let headerSize: CGFloat = 13
        static let scheduleSize: CGFloat = 11
    }

    // MARK: - Index Marquee

    enum Marquee {
        static let width: CGFloat = 450
        static let height: CGFloat = 18
    }

    // MARK: - News Headlines

    enum Headlines {
        static let maxLength = 60
        static let itemsPerSource = 3
    }

    // MARK: - Watchlist Editor Window

    enum EditorWindow {
        static let defaultWidth: CGFloat = 400
        static let defaultHeight: CGFloat = 500
        static let minWidth: CGFloat = 300
        static let minHeight: CGFloat = 400
        static let buttonWidth: CGFloat = 40
    }

    // MARK: - Debug Window

    enum DebugWindow {
        static let width: CGFloat = 700
        static let height: CGFloat = 400
        static let minWidth: CGFloat = 600
        static let minHeight: CGFloat = 300
        static let statusColumnWidth: CGFloat = 60
    }

    // MARK: - Watchlist

    enum Watchlist {
        static let maxSize = 40
    }
}
