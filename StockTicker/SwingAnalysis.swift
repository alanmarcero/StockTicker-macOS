import Foundation

// MARK: - Swing Analysis

enum SwingAnalysis {
    struct SwingResult {
        let breakoutPrice: Double?
        let breakdownPrice: Double?
    }

    static let threshold = 0.10

    static func analyze(closes: [Double]) -> SwingResult {
        guard !closes.isEmpty else {
            return SwingResult(breakoutPrice: nil, breakdownPrice: nil)
        }

        let breakoutPrice = findBreakoutPrice(closes: closes)
        let breakdownPrice = findBreakdownPrice(closes: closes)

        return SwingResult(breakoutPrice: breakoutPrice, breakdownPrice: breakdownPrice)
    }

    private static func findBreakoutPrice(closes: [Double]) -> Double? {
        var significantHighs: [Double] = []
        var runningMax = closes[0]

        for close in closes {
            if close > runningMax {
                runningMax = close
            }
            let decline = (runningMax - close) / runningMax
            if decline >= threshold {
                significantHighs.append(runningMax)
                runningMax = close
            }
        }

        return significantHighs.max()
    }

    private static func findBreakdownPrice(closes: [Double]) -> Double? {
        var significantLows: [Double] = []
        var runningMin = closes[0]

        for close in closes {
            if close < runningMin {
                runningMin = close
            }
            guard runningMin > 0 else { continue }
            let rise = (close - runningMin) / runningMin
            if rise >= threshold {
                significantLows.append(runningMin)
                runningMin = close
            }
        }

        return significantLows.min()
    }
}
