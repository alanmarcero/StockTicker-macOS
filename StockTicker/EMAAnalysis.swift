import Foundation

// MARK: - EMA Analysis

enum EMAAnalysis {
    static let defaultPeriod = 5

    static func calculate(closes: [Double], period: Int = defaultPeriod) -> Double? {
        guard let emaValues = calculateEMAValues(closes: closes, period: period) else { return nil }
        return emaValues.last
    }

    private static func calculateEMAValues(closes: [Double], period: Int) -> [Double]? {
        guard closes.count >= period else { return nil }

        let sma = closes[0..<period].reduce(0.0, +) / Double(period)
        let emaValues = [sma]

        guard closes.count > period else { return emaValues }

        let multiplier = 2.0 / Double(period + 1)
        
        // Use reduce to build the EMA values array without a for loop
        return closes[period..<closes.count].reduce(into: emaValues) { values, close in
            let lastEma = values.last!
            let ema = (close - lastEma) * multiplier + lastEma
            values.append(ema)
        }
    }

    static func detectWeeklyCrossover(closes: [Double], period: Int = defaultPeriod) -> Int? {
        guard closes.count >= period + 1 else { return nil }
        guard let emaValues = calculateEMAValues(closes: closes, period: period),
              emaValues.count >= 2 else { return nil }

        let last = emaValues.count - 1
        let offset = period - 1

        guard closes[offset + last] > emaValues[last] * 1.02,
              closes[offset + last - 1] <= emaValues[last - 1] else { return nil }

        let consecutiveCount = stride(from: last - 2, through: 0, by: -1)
            .prefix { closes[offset + $0] <= emaValues[$0] }
            .count
        
        return 1 + consecutiveCount
    }

    static func detectWeeklyCrossdown(closes: [Double], period: Int = defaultPeriod) -> Int? {
        guard closes.count >= period + 1 else { return nil }
        guard let emaValues = calculateEMAValues(closes: closes, period: period),
              emaValues.count >= 2 else { return nil }

        let last = emaValues.count - 1
        let offset = period - 1

        guard closes[offset + last] < emaValues[last] * 0.98,
              closes[offset + last - 1] > emaValues[last - 1] else { return nil }

        let consecutiveCount = stride(from: last - 2, through: 0, by: -1)
            .prefix { closes[offset + $0] > emaValues[$0] }
            .count
            
        return 1 + consecutiveCount
    }

    static func countPeriodsAbove(closes: [Double], period: Int = defaultPeriod) -> Int? {
        guard closes.count >= period + 1 else { return nil }
        guard let emaValues = calculateEMAValues(closes: closes, period: period) else { return nil }

        let last = emaValues.count - 1
        let offset = period - 1

        guard last >= 0, closes[offset + last] > emaValues[last] else { return nil }

        let consecutiveCount = stride(from: last - 1, through: 0, by: -1)
            .prefix { closes[offset + $0] > emaValues[$0] }
            .count
            
        return 1 + consecutiveCount
    }

    static func countWeeksBelow(closes: [Double], period: Int = defaultPeriod) -> Int? {
        guard closes.count >= period + 1 else { return nil }
        guard let emaValues = calculateEMAValues(closes: closes, period: period) else { return nil }

        let last = emaValues.count - 1
        let offset = period - 1

        guard last >= 0, closes[offset + last] <= emaValues[last] else { return nil }

        let consecutiveCount = stride(from: last - 1, through: 0, by: -1)
            .prefix { closes[offset + $0] <= emaValues[$0] }
            .count
            
        return 1 + consecutiveCount
    }
}
