import Foundation

/// Fixed-capacity ring of recent probe results with derived statistics.
public struct SampleWindow: Sendable {
    public let capacity: Int
    private var samples: [PingResult] = []

    public init(capacity: Int = 12) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    public mutating func append(_ result: PingResult) {
        samples.append(result)
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    public mutating func reset() {
        samples.removeAll()
    }

    public var count: Int { samples.count }
    public var latest: PingResult? { samples.last }

    private var rtts: [TimeInterval] { samples.compactMap(\.rtt) }

    public var avg: TimeInterval? {
        let r = rtts
        return r.isEmpty ? nil : r.reduce(0, +) / Double(r.count)
    }

    public var min: TimeInterval? { rtts.min() }
    public var max: TimeInterval? { rtts.max() }

    /// Percentage of samples in the window that were timeouts or errors. 0 when empty.
    public var lossPercent: Double {
        guard !samples.isEmpty else { return 0 }
        let lost = samples.filter(\.isLost).count
        return Double(lost) / Double(samples.count) * 100
    }
}
