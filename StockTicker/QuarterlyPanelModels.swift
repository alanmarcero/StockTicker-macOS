import Foundation

// MARK: - Constants

enum QuarterlyWindowSize {
    static let width = LayoutConfig.QuarterlyWindow.width
    static let height = LayoutConfig.QuarterlyWindow.height
    static let minWidth = LayoutConfig.QuarterlyWindow.minWidth
    static let minHeight = LayoutConfig.QuarterlyWindow.minHeight
    static let symbolColumnWidth = LayoutConfig.QuarterlyWindow.symbolColumnWidth
    static let highColumnWidth = LayoutConfig.QuarterlyWindow.highColumnWidth
    static let quarterColumnWidth = LayoutConfig.QuarterlyWindow.quarterColumnWidth
    static let dateColumnWidth = LayoutConfig.QuarterlyWindow.dateColumnWidth
    static let rsiColumnWidth = LayoutConfig.QuarterlyWindow.rsiColumnWidth
}

enum QuarterlyFormatting {
    static let noData = "--"
}

// MARK: - View Mode

enum QuarterlyViewMode: String, CaseIterable {
    case sinceQuarter = "Since Quarter"
    case duringQuarter = "During Quarter"
    case forwardPE = "Forward P/E"
    case priceBreaks = "Price Breaks"
    case emas = "5 EMAs"
    case miscStats = "Misc Stats"
}

// MARK: - Row Model

struct QuarterlyRow: Identifiable {
    let id: String
    let symbol: String
    let highestCloseChangePercent: Double?
    let quarterChanges: [String: Double?]
    let currentForwardPE: Double?
    let breakoutPercent: Double?
    let breakoutDate: String?
    let breakdownPercent: Double?
    let breakdownDate: String?
    let rsi: Double?
}

// MARK: - Misc Stat Model

struct MiscStat: Identifiable {
    let id: String
    let description: String
    let value: String
}

// MARK: - Sort Column

enum QuarterlySortColumn: Equatable {
    case symbol
    case highestClose
    case currentPE
    case quarter(String)
    case date
    case priceBreakPercent
    case rsi
}
