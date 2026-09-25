import Foundation

/// Outcome of a single probe.
public enum PingResult: Equatable, Sendable {
    case rtt(TimeInterval)
    case timeout
    case error(String)

    public var rtt: TimeInterval? {
        if case .rtt(let t) = self { return t }
        return nil
    }

    public var isLost: Bool { rtt == nil }
}

/// Traffic-light health indicator derived from a single probe.
public enum Status: Equatable, Sendable {
    case green, yellow, red

    public static let yellowThreshold: TimeInterval = 0.060
    public static let redThreshold: TimeInterval = 0.150

    public static func classify(_ result: PingResult) -> Status {
        guard let rtt = result.rtt else { return .red }
        if rtt < yellowThreshold { return .green }
        if rtt < redThreshold { return .yellow }
        return .red
    }
}
