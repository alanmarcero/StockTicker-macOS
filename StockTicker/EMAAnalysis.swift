import Foundation

// MARK: - EMA Analysis

enum EMAAnalysis {
    static let defaultPeriod = 5

    static func calculate(closes: [Double], period: Int = defaultPeriod) -> Double? {
        guard closes.count >= period else { return nil }

        let sma = closes[0..<period].reduce(0.0, +) / Double(period)
        guard closes.count > period else { return sma }

        let multiplier = 2.0 / Double(period + 1)
        var ema = sma
        for i in period..<closes.count {
            ema = (closes[i] - ema) * multiplier + ema
        }
        return ema
    }
}
