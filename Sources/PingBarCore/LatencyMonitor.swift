import Foundation

/// Immutable view of the monitor's state, delivered on the main queue.
public struct Snapshot: Sendable {
    public let latest: PingResult
    public let host: String
    public let avg: TimeInterval?
    public let min: TimeInterval?
    public let max: TimeInterval?
    public let lossPercent: Double
    public let status: Status
}

/// Drives periodic probes on a background queue, keeps a rolling window,
/// and publishes snapshots to `onUpdate` on the main queue.
public final class LatencyMonitor {
    public var onUpdate: ((Snapshot) -> Void)?

    private let settings: Settings
    private let makePinger: (String) -> ICMPPinger
    private let queue = DispatchQueue(label: "dev.bitfury.pingbar.monitor", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var window = SampleWindow(capacity: 12)
    private var pingers: [String: ICMPPinger] = [:]
    private let pingTimeout: TimeInterval = 2.0

    public init(settings: Settings, pingerFactory: @escaping (String) -> ICMPPinger = { ICMPPinger(host: $0) }) {
        self.settings = settings
        self.makePinger = pingerFactory
    }

    public var interval: TimeInterval { settings.interval }
    public var primary: Target { settings.primary }

    public func start() {
        queue.async { self.restartTimer() }
    }

    public func stop() {
        queue.async {
            self.timer?.cancel()
            self.timer = nil
        }
    }

    public func setInterval(_ interval: TimeInterval) {
        settings.interval = interval
        queue.async {
            self.window.reset()
            self.restartTimer()
        }
    }

    public func setTarget(_ target: Target) {
        settings.primary = target
        queue.async {
            self.window.reset()
            self.restartTimer()
        }
    }

    // MARK: - Internals (always on `queue`)

    private func restartTimer() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: settings.interval, leeway: .milliseconds(200))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    private func pinger(for host: String) -> ICMPPinger {
        if let p = pingers[host] { return p }
        let p = makePinger(host)
        pingers[host] = p
        return p
    }

    private func tick() {
        let primary = settings.primary
        var host = primary.host
        var result = pinger(for: host).ping(timeout: pingTimeout)

        if result == .timeout {
            let fb = primary.fallback
            let fbResult = pinger(for: fb.host).ping(timeout: pingTimeout)
            if case .rtt = fbResult {
                host = fb.host
                result = fbResult
            }
        }

        window.append(result)
        let snap = Snapshot(
            latest: result,
            host: host,
            avg: window.avg,
            min: window.min,
            max: window.max,
            lossPercent: window.lossPercent,
            status: Status.classify(result)
        )
        DispatchQueue.main.async { [onUpdate] in onUpdate?(snap) }
    }
}
