import Foundation

// MARK: - RSI Analysis

enum RSIAnalysis {
    static let defaultPeriod = 14

    static func calculate(closes: [Double], period: Int = defaultPeriod) -> Double? {
        guard closes.count > period else { return nil }

        let initialChanges = (1...period).map { closes[$0] - closes[$0 - 1] }
        let gains = initialChanges.filter { $0 > 0 }.reduce(0.0, +)
        let losses = initialChanges.filter { $0 < 0 }.reduce(0.0, { $0 - $1 })

        var avgGain = gains / Double(period)
        var avgLoss = losses / Double(period)

        if closes.count > period + 1 {
            let smoothed = ((period + 1)..<closes.count).reduce(into: (avgGain: avgGain, avgLoss: avgLoss)) { state, i in
                let change = closes[i] - closes[i - 1]
                let gain = change > 0 ? change : 0.0
                let loss = change < 0 ? -change : 0.0
                state.avgGain = (state.avgGain * Double(period - 1) + gain) / Double(period)
                state.avgLoss = (state.avgLoss * Double(period - 1) + loss) / Double(period)
            }
            avgGain = smoothed.avgGain
            avgLoss = smoothed.avgLoss
        }

        guard avgLoss > 0 else { return 100.0 }

        let rs = avgGain / avgLoss
        return 100.0 - (100.0 / (1.0 + rs))
    }
}
