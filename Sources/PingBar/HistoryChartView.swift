import AppKit
import PingBarCore

/// Bar chart of the last 15 minutes of probes, drawn with Core Graphics.
/// Bars are positioned by timestamp so gaps and spikes read at a glance.
final class HistoryChartView: NSView {
    static let span: TimeInterval = 900
    static let size = NSSize(width: 360, height: 100)

    var points: [HistoryPoint] = [] {
        didSet { if window != nil { needsDisplay = true } }
    }

    private let inset = NSEdgeInsets(top: 20, left: 46, bottom: 16, right: 14)
    private let labelFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    private let headerFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    private lazy var timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    init() {
        super.init(frame: NSRect(origin: .zero, size: Self.size))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let now = Date()
        let plot = NSRect(
            x: inset.left, y: inset.top,
            width: bounds.width - inset.left - inset.right,
            height: bounds.height - inset.top - inset.bottom
        )

        let rtts = points.compactMap(\.result.rtt)
        let maxRTT = rtts.max() ?? 0
        let yMax = Swift.max(0.100, maxRTT)

        drawHeader(now: now)
        drawGuides(plot: plot, yMax: yMax)
        drawBars(plot: plot, yMax: yMax, now: now)
        drawAxes(plot: plot, yMax: yMax)
    }

    // MARK: - Pieces

    private func drawHeader(now: Date) {
        let text: String
        if points.isEmpty {
            text = "Last 15 min · no data yet"
        } else {
            let lost = points.filter(\.result.isLost).count
            let loss = Double(lost) / Double(points.count) * 100
            if let peak = points.filter({ $0.result.rtt != nil })
                .max(by: { ($0.result.rtt ?? 0) < ($1.result.rtt ?? 0) }),
               let rtt = peak.result.rtt {
                text = String(
                    format: "Last 15 min · max %d ms at %@ · loss %.0f%%",
                    Int((rtt * 1000).rounded()), timeFormatter.string(from: peak.time), loss
                )
            } else {
                text = String(format: "Last 15 min · no replies · loss %.0f%%", loss)
            }
        }
        (text as NSString).draw(
            at: NSPoint(x: inset.left, y: 3),
            withAttributes: [.font: headerFont, .foregroundColor: NSColor.secondaryLabelColor]
        )
    }

    private func drawGuides(plot: NSRect, yMax: TimeInterval) {
        for (threshold, color) in [(Status.yellowThreshold, NSColor.systemYellow), (Status.redThreshold, NSColor.systemRed)] {
            guard threshold < yMax else { continue }
            let y = plot.maxY - CGFloat(threshold / yMax) * plot.height
            let path = NSBezierPath()
            path.move(to: NSPoint(x: plot.minX, y: y))
            path.line(to: NSPoint(x: plot.maxX, y: y))
            path.lineWidth = 1
            path.setLineDash([3, 3], count: 2, phase: 0)
            color.withAlphaComponent(0.35).setStroke()
            path.stroke()
        }
    }

    private func drawBars(plot: NSRect, yMax: TimeInterval, now: Date) {
        let start = now.addingTimeInterval(-Self.span)
        let barWidth: CGFloat = 2
        for p in points {
            let frac = CGFloat(p.time.timeIntervalSince(start) / Self.span)
            guard frac >= 0, frac <= 1 else { continue }
            let x = plot.minX + frac * (plot.width - barWidth)
            if let rtt = p.result.rtt {
                let h = Swift.max(1, CGFloat(rtt / yMax) * plot.height)
                color(for: p.result).setFill()
                NSRect(x: x, y: plot.maxY - h, width: barWidth, height: h).fill()
            } else {
                NSColor.systemRed.setFill()
                NSRect(x: x, y: plot.minY, width: barWidth, height: 6).fill()
            }
        }
    }

    private func drawAxes(plot: NSRect, yMax: TimeInterval) {
        NSColor.separatorColor.setStroke()
        let base = NSBezierPath()
        base.move(to: NSPoint(x: plot.minX, y: plot.maxY))
        base.line(to: NSPoint(x: plot.maxX, y: plot.maxY))
        base.lineWidth = 1
        base.stroke()

        let attrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: NSColor.tertiaryLabelColor]

        for frac in [0.0, 0.5, 1.0] {
            let ms = Int((yMax * frac * 1000).rounded())
            let label = "\(ms) ms" as NSString
            let size = label.size(withAttributes: attrs)
            let y = plot.maxY - CGFloat(frac) * plot.height - size.height / 2
            label.draw(at: NSPoint(x: plot.minX - size.width - 4, y: y), withAttributes: attrs)
        }

        for (frac, label) in [(0.0, "-15m"), (1.0 / 3, "-10m"), (2.0 / 3, "-5m"), (1.0, "now")] {
            let s = label as NSString
            let size = s.size(withAttributes: attrs)
            var x = plot.minX + CGFloat(frac) * plot.width - size.width / 2
            x = Swift.min(Swift.max(x, plot.minX), plot.maxX - size.width)
            s.draw(at: NSPoint(x: x, y: plot.maxY + 2), withAttributes: attrs)
        }
    }

    private func color(for result: PingResult) -> NSColor {
        switch Status.classify(result) {
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .red: return .systemRed
        }
    }
}
