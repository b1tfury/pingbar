import Foundation

/// One probe result with the wall-clock time it was taken.
public struct HistoryPoint: Equatable, Sendable {
    public let time: Date
    public let result: PingResult

    public init(time: Date, result: PingResult) {
        self.time = time
        self.result = result
    }
}

/// Bounded, timestamped record of recent probes. Capacity bounds memory; `span`
/// bounds what `points(asOf:)` returns so the chart always covers a fixed window.
public struct History: Sendable {
    public let capacity: Int
    public let span: TimeInterval
    private var buffer: [HistoryPoint] = []

    /// Defaults cover 15 minutes at the fastest (3 s) interval.
    public init(capacity: Int = 300, span: TimeInterval = 900) {
        precondition(capacity > 0 && span > 0)
        self.capacity = capacity
        self.span = span
    }

    public mutating func append(_ result: PingResult, at time: Date = Date()) {
        buffer.append(HistoryPoint(time: time, result: result))
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    public mutating func reset() {
        buffer.removeAll()
    }

    /// Points within `span` of `now`, oldest first.
    public func points(asOf now: Date = Date()) -> [HistoryPoint] {
        let cutoff = now.addingTimeInterval(-span)
        return buffer.filter { $0.time >= cutoff }
    }

    /// The highest successful RTT within the span, or nil if no replies.
    public func maxRTT(asOf now: Date = Date()) -> HistoryPoint? {
        points(asOf: now)
            .filter { $0.result.rtt != nil }
            .max { ($0.result.rtt ?? 0) < ($1.result.rtt ?? 0) }
    }

    public func lossPercent(asOf now: Date = Date()) -> Double {
        let pts = points(asOf: now)
        guard !pts.isEmpty else { return 0 }
        let lost = pts.filter(\.result.isLost).count
        return Double(lost) / Double(pts.count) * 100
    }
}
