import Foundation

// MARK: - Centralized Layout Configuration
// All width, height, and size constants for the app in one place

enum LayoutConfig {

    // MARK: - Menu Bar Ticker Display

    enum Ticker {
        static let symbolWidth = 6
        static let marketCapWidth = 7  // "$3.8T", "$131B"
        static let percentWidth = 7
        static let ytdWidth = 13  // "YTD: +12.34%"
        static let highWidth = 14  // "High: -12.34%"
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
        static let maxLength = 70
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

    // MARK: - Extra Stats Window

    enum QuarterlyWindow {
        static let width: CGFloat = 1150
        static let height: CGFloat = 500
        static let minWidth: CGFloat = 900
        static let minHeight: CGFloat = 350
        static let symbolColumnWidth: CGFloat = 80
        static let quarterColumnWidth: CGFloat = 85
        static let highColumnWidth: CGFloat = 85
        static let dateColumnWidth: CGFloat = 75
    }

    // MARK: - Watchlist

    enum Watchlist {
        static let maxSize = 128
    }
}
