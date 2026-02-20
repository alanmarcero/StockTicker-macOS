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

    static func detectWeeklyCrossover(closes: [Double], period: Int = defaultPeriod) -> Int? {
        guard closes.count >= period + 1 else { return nil }

        let multiplier = 2.0 / Double(period + 1)
        var ema = closes[0..<period].reduce(0.0, +) / Double(period)
        var emaValues = [ema]
        for i in period..<closes.count {
            ema = (closes[i] - ema) * multiplier + ema
            emaValues.append(ema)
        }

        let last = emaValues.count - 1
        guard last >= 1 else { return nil }
        let offset = period - 1

        guard closes[offset + last] > emaValues[last],
              closes[offset + last - 1] <= emaValues[last - 1] else { return nil }

        var weeksBelow = 1
        for j in stride(from: last - 2, through: 0, by: -1) {
            guard closes[offset + j] <= emaValues[j] else { break }
            weeksBelow += 1
        }
        return weeksBelow
    }

    static func countWeeksBelow(closes: [Double], period: Int = defaultPeriod) -> Int? {
        guard closes.count >= period + 1 else { return nil }

        let multiplier = 2.0 / Double(period + 1)
        var ema = closes[0..<period].reduce(0.0, +) / Double(period)
        var emaValues = [ema]
        for i in period..<closes.count {
            ema = (closes[i] - ema) * multiplier + ema
            emaValues.append(ema)
        }

        let last = emaValues.count - 1
        guard last >= 0 else { return nil }
        let offset = period - 1

        guard closes[offset + last] <= emaValues[last] else { return nil }

        var weeksBelow = 1
        for j in stride(from: last - 1, through: 0, by: -1) {
            guard closes[offset + j] <= emaValues[j] else { break }
            weeksBelow += 1
        }
        return weeksBelow
    }
}
