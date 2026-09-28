import Foundation
import Testing
@testable import PingBarCore

@Suite struct HistoryTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func emptyHistory() {
        let h = History()
        #expect(h.points(asOf: t0).isEmpty)
        #expect(h.maxRTT(asOf: t0) == nil)
        #expect(h.lossPercent(asOf: t0) == 0)
    }

    @Test func capsAtCapacity() {
        var h = History(capacity: 3, span: 1000)
        for i in 0..<5 { h.append(.rtt(Double(i)), at: t0.addingTimeInterval(Double(i))) }
        let pts = h.points(asOf: t0.addingTimeInterval(4))
        #expect(pts.count == 3)
        #expect(pts.first?.result == .rtt(2))
        #expect(pts.last?.result == .rtt(4))
    }

    @Test func filtersToSpan() {
        var h = History(capacity: 100, span: 60)
        h.append(.rtt(0.010), at: t0)
        h.append(.rtt(0.020), at: t0.addingTimeInterval(30))
        h.append(.rtt(0.030), at: t0.addingTimeInterval(90))
        let pts = h.points(asOf: t0.addingTimeInterval(90))
        #expect(pts.map(\.result) == [.rtt(0.020), .rtt(0.030)])
    }

    @Test func maxIgnoresLostSamples() {
        var h = History(capacity: 100, span: 900)
        h.append(.rtt(0.010), at: t0)
        h.append(.timeout, at: t0.addingTimeInterval(5))
        h.append(.rtt(0.113), at: t0.addingTimeInterval(10))
        h.append(.rtt(0.020), at: t0.addingTimeInterval(15))
        let mx = h.maxRTT(asOf: t0.addingTimeInterval(15))
        #expect(mx?.result == .rtt(0.113))
        #expect(mx?.time == t0.addingTimeInterval(10))
        #expect(h.lossPercent(asOf: t0.addingTimeInterval(15)) == 25)
    }

    @Test func resetClears() {
        var h = History()
        h.append(.rtt(0.01), at: t0)
        h.reset()
        #expect(h.points(asOf: t0).isEmpty)
    }
}
