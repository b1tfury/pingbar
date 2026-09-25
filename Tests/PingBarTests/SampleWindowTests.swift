import Testing
@testable import PingBarCore

@Suite struct StatusTests {
    @Test func greenBelow60ms() {
        #expect(Status.classify(.rtt(0.0599)) == .green)
        #expect(Status.classify(.rtt(0.001)) == .green)
    }

    @Test func yellowFrom60To150ms() {
        #expect(Status.classify(.rtt(0.060)) == .yellow)
        #expect(Status.classify(.rtt(0.1499)) == .yellow)
    }

    @Test func redAt150msAndAbove() {
        #expect(Status.classify(.rtt(0.150)) == .red)
        #expect(Status.classify(.rtt(1.5)) == .red)
    }

    @Test func redOnTimeoutAndError() {
        #expect(Status.classify(.timeout) == .red)
        #expect(Status.classify(.error("boom")) == .red)
    }
}

@Suite struct SampleWindowTests {
    @Test func emptyWindow() {
        let w = SampleWindow(capacity: 12)
        #expect(w.latest == nil)
        #expect(w.avg == nil)
        #expect(w.min == nil)
        #expect(w.max == nil)
        #expect(w.lossPercent == 0)
        #expect(w.count == 0)
    }

    @Test func capsAtCapacity() {
        var w = SampleWindow(capacity: 3)
        for i in 1...5 { w.append(.rtt(Double(i))) }
        #expect(w.count == 3)
        #expect(w.min == 3)
        #expect(w.max == 5)
        #expect(w.latest == .rtt(5))
    }

    @Test func statsIgnoreLostSamples() {
        var w = SampleWindow(capacity: 12)
        w.append(.rtt(0.010))
        w.append(.timeout)
        w.append(.rtt(0.030))
        w.append(.error("x"))
        #expect(w.count == 4)
        #expect(w.min == 0.010)
        #expect(w.max == 0.030)
        #expect(abs((w.avg ?? 0) - 0.020) < 1e-9)
        #expect(w.lossPercent == 50)
    }

    @Test func statsNilWhenAllLost() {
        var w = SampleWindow(capacity: 12)
        w.append(.timeout)
        w.append(.timeout)
        #expect(w.avg == nil)
        #expect(w.min == nil)
        #expect(w.max == nil)
        #expect(w.lossPercent == 100)
        #expect(w.latest == .timeout)
    }

    @Test func resetClears() {
        var w = SampleWindow(capacity: 12)
        w.append(.rtt(0.01))
        w.reset()
        #expect(w.count == 0)
        #expect(w.latest == nil)
    }
}
