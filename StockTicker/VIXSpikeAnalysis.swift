import Foundation

// MARK: - VIX Spike Model

struct VIXSpike: Codable, Equatable {
    let dateString: String
    let timestamp: Int
    let vixClose: Double
}

// MARK: - VIX Spike Detection

enum VIXSpikeAnalysis {
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d/yy"
        return fmt
    }()

    static func detectSpikes(
        closes: [Double],
        timestamps: [Int],
        threshold: Double = 20.0,
        gapDays: Int = 5
    ) -> [VIXSpike] {
        guard closes.count == timestamps.count, !closes.isEmpty else { return [] }

        let spikeIndices = closes.indices.filter { closes[$0] >= threshold }
        guard !spikeIndices.isEmpty else { return [] }

        let initialClusters = (clusters: [[Int]](), current: [spikeIndices[0]])
        let finalClusters = spikeIndices.dropFirst().reduce(into: initialClusters) { res, index in
            let lastIndex = res.current.last!
            let gap = index - lastIndex
            if gap <= gapDays + 1 {
                res.current.append(index)
            } else {
                res.clusters.append(res.current)
                res.current = [index]
            }
        }
        let clusters = finalClusters.clusters + [finalClusters.current]

        return clusters.map { cluster in
            let peakIndex = cluster.max(by: { closes[$0] < closes[$1] })!
            let date = Date(timeIntervalSince1970: TimeInterval(timestamps[peakIndex]))
            let formatted = dateFormatter.string(from: date)
            return VIXSpike(dateString: formatted, timestamp: timestamps[peakIndex], vixClose: closes[peakIndex])
        }
    }
}
