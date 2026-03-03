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

        var clusters: [[Int]] = []
        var currentCluster: [Int] = [spikeIndices[0]]

        for i in 1..<spikeIndices.count {
            let gap = spikeIndices[i] - spikeIndices[i - 1]
            if gap <= gapDays + 1 {
                currentCluster.append(spikeIndices[i])
            } else {
                clusters.append(currentCluster)
                currentCluster = [spikeIndices[i]]
            }
        }
        clusters.append(currentCluster)

        return clusters.map { cluster in
            let peakIndex = cluster.max(by: { closes[$0] < closes[$1] })!
            let date = Date(timeIntervalSince1970: TimeInterval(timestamps[peakIndex]))
            let formatted = dateFormatter.string(from: date)
            return VIXSpike(dateString: formatted, timestamp: timestamps[peakIndex], vixClose: closes[peakIndex])
        }
    }
}
