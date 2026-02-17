import Foundation

// MARK: - RSI Analysis

enum RSIAnalysis {
    static let defaultPeriod = 14

    static func calculate(closes: [Double], period: Int = defaultPeriod) -> Double? {
        guard closes.count > period else { return nil }

        var gains = 0.0
        var losses = 0.0

        for i in 1...period {
            let change = closes[i] - closes[i - 1]
            if change > 0 { gains += change }
            else { losses -= change }
        }

        var avgGain = gains / Double(period)
        var avgLoss = losses / Double(period)

        for i in (period + 1)..<closes.count {
            let change = closes[i] - closes[i - 1]
            let gain = change > 0 ? change : 0.0
            let loss = change < 0 ? -change : 0.0
            avgGain = (avgGain * Double(period - 1) + gain) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + loss) / Double(period)
        }

        guard avgLoss > 0 else { return 100.0 }

        let rs = avgGain / avgLoss
        return 100.0 - (100.0 / (1.0 + rs))
    }
}
