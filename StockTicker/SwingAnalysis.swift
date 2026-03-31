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
        struct State {
            var significantHighs: [(price: Double, index: Int)] = []
            var runningMax: Double
            var runningMaxIndex: Int
        }

        let initialState = State(runningMax: closes[0], runningMaxIndex: 0)
        
        let finalState = closes.enumerated().reduce(into: initialState) { state, element in
            let (i, close) = element
            
            if close > state.runningMax {
                state.runningMax = close
                state.runningMaxIndex = i
            }
            
            let decline = (state.runningMax - close) / state.runningMax
            if decline >= threshold {
                state.significantHighs.append((price: state.runningMax, index: state.runningMaxIndex))
                state.runningMax = close
                state.runningMaxIndex = i
            }
        }

        return finalState.significantHighs.last
    }

    private static func findBreakdownPrice(closes: [Double]) -> (price: Double, index: Int)? {
        struct State {
            var significantLows: [(price: Double, index: Int)] = []
            var runningMin: Double
            var runningMinIndex: Int
        }

        let initialState = State(runningMin: closes[0], runningMinIndex: 0)

        let finalState = closes.enumerated().reduce(into: initialState) { state, element in
            let (i, close) = element
            
            if close < state.runningMin {
                state.runningMin = close
                state.runningMinIndex = i
            }
            
            guard state.runningMin > 0 else { return }
            
            let rise = (close - state.runningMin) / state.runningMin
            if rise >= threshold {
                state.significantLows.append((price: state.runningMin, index: state.runningMinIndex))
                state.runningMin = close
                state.runningMinIndex = i
            }
        }

        return finalState.significantLows.last
    }
}
