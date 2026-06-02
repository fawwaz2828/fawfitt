import Foundation

/// Median + outlier-rejection smoother ported from Good-GYM's `smooth_angle`.
///
/// Keeps a rolling window of the most recent angles. Once at least three samples
/// are present it drops samples more than two standard deviations from the median
/// (rejecting single-frame spikes from a misdetected joint) and returns the mean
/// of what remains. With fewer than three samples it passes the value through.
struct AngleSmoother {
    let windowSize: Int
    private var history: [Double] = []

    init(windowSize: Int = 5) {
        precondition(windowSize >= 1, "windowSize must be >= 1")
        self.windowSize = windowSize
        history.reserveCapacity(windowSize)
    }

    mutating func append(_ value: Double) -> Double {
        history.append(value)
        if history.count > windowSize { history.removeFirst() }

        guard history.count >= 3 else { return value }

        let median = Self.median(of: history)
        let std = Self.standardDeviation(of: history)
        // std == 0 → all samples equal; keep them all.
        let filtered = std > 0 ? history.filter { abs($0 - median) <= 2 * std } : history
        guard !filtered.isEmpty else { return value }
        return filtered.reduce(0, +) / Double(filtered.count)
    }

    mutating func reset() {
        history.removeAll(keepingCapacity: true)
    }

    private static func median(of values: [Double]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    private static func standardDeviation(of values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot()
    }
}
