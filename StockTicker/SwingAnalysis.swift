import Foundation

// MARK: - Swing Analysis

enum SwingAnalysis {
    struct SwingResult {
        let breakoutPrice: Double?
        let breakoutIndex: Int?
        let breakdownPrice: Double?
        let breakdownIndex: Int?
    }

    static let threshold = 0.10

    static func analyze(closes: [Double]) -> SwingResult {
        guard !closes.isEmpty else {
            return SwingResult(breakoutPrice: nil, breakoutIndex: nil, breakdownPrice: nil, breakdownIndex: nil)
        }

        let breakout = findBreakoutPrice(closes: closes)
        let breakdown = findBreakdownPrice(closes: closes)

        return SwingResult(
            breakoutPrice: breakout?.price,
            breakoutIndex: breakout?.index,
            breakdownPrice: breakdown?.price,
            breakdownIndex: breakdown?.index
        )
    }

    private static func findBreakoutPrice(closes: [Double]) -> (price: Double, index: Int)? {
        var significantHighs: [(price: Double, index: Int)] = []
        var runningMax = closes[0]
        var runningMaxIndex = 0

        for (i, close) in closes.enumerated() {
            if close > runningMax {
                runningMax = close
                runningMaxIndex = i
            }
            let decline = (runningMax - close) / runningMax
            if decline >= threshold {
                significantHighs.append((price: runningMax, index: runningMaxIndex))
                runningMax = close
                runningMaxIndex = i
            }
        }

        return significantHighs.max(by: { $0.price < $1.price })
    }

    private static func findBreakdownPrice(closes: [Double]) -> (price: Double, index: Int)? {
        var significantLows: [(price: Double, index: Int)] = []
        var runningMin = closes[0]
        var runningMinIndex = 0

        for (i, close) in closes.enumerated() {
            if close < runningMin {
                runningMin = close
                runningMinIndex = i
            }
            guard runningMin > 0 else { continue }
            let rise = (close - runningMin) / runningMin
            if rise >= threshold {
                significantLows.append((price: runningMin, index: runningMinIndex))
                runningMin = close
                runningMinIndex = i
            }
        }

        return significantLows.max(by: { $0.price < $1.price })
    }
}
