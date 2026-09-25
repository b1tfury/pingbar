import Foundation

/// A probe destination. Anycast addresses route to the nearest PoP automatically.
public struct Target: Equatable, Hashable, Sendable {
    public let host: String
    public let name: String

    public static let cloudflare = Target(host: "1.1.1.1", name: "Cloudflare")
    public static let google = Target(host: "8.8.8.8", name: "Google")
    public static let all: [Target] = [.cloudflare, .google]

    /// The other known target, used when the primary times out.
    public var fallback: Target {
        Self.all.first { $0 != self } ?? .google
    }

    public static func named(host: String) -> Target? {
        all.first { $0.host == host }
    }
}

/// UserDefaults-backed preferences.
public final class Settings {
    public static let allowedIntervals: [TimeInterval] = [3, 5, 10]
    public static let defaultInterval: TimeInterval = 5

    private let defaults: UserDefaults
    private enum Key {
        static let interval = "interval"
        static let primaryTarget = "primaryTarget"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var interval: TimeInterval {
        get {
            let v = defaults.double(forKey: Key.interval)
            return Self.allowedIntervals.contains(v) ? v : Self.defaultInterval
        }
        set { defaults.set(newValue, forKey: Key.interval) }
    }

    public var primary: Target {
        get {
            guard let host = defaults.string(forKey: Key.primaryTarget),
                  let t = Target.named(host: host) else { return .cloudflare }
            return t
        }
        set { defaults.set(newValue.host, forKey: Key.primaryTarget) }
    }
}
