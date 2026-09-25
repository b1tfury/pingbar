import Testing
@testable import PingBarCore

@Suite struct ICMPReplyParsingTests {
    /// 20-byte IPv4 header followed by an ICMP echo reply.
    private func reply(id: UInt16, seq: UInt16, type: UInt8 = 0, withIPHeader: Bool = true) -> [UInt8] {
        var bytes: [UInt8] = []
        if withIPHeader {
            bytes += [0x45] + [UInt8](repeating: 0, count: 19)
        }
        bytes += [type, 0, 0, 0, UInt8(id >> 8), UInt8(id & 0xFF), UInt8(seq >> 8), UInt8(seq & 0xFF)]
        bytes += [UInt8](repeating: 0xAB, count: 56)
        return bytes
    }

    @Test func matchesReplyWithIPHeader() {
        #expect(ICMPPinger.isMatchingReply(reply(id: 0x1234, seq: 7), identifier: 0x1234, sequence: 7))
    }

    @Test func matchesReplyWithoutIPHeader() {
        #expect(ICMPPinger.isMatchingReply(reply(id: 9, seq: 1, withIPHeader: false), identifier: 9, sequence: 1))
    }

    @Test func rejectsWrongSequence() {
        #expect(!ICMPPinger.isMatchingReply(reply(id: 9, seq: 1), identifier: 9, sequence: 2))
    }

    @Test func rejectsWrongIdentifier() {
        #expect(!ICMPPinger.isMatchingReply(reply(id: 9, seq: 1), identifier: 10, sequence: 1))
    }

    @Test func rejectsNonEchoReply() {
        // type 11 = time exceeded
        #expect(!ICMPPinger.isMatchingReply(reply(id: 9, seq: 1, type: 11), identifier: 9, sequence: 1))
    }

    @Test func rejectsTruncated() {
        #expect(!ICMPPinger.isMatchingReply([0x45, 0, 0], identifier: 9, sequence: 1))
        #expect(!ICMPPinger.isMatchingReply([], identifier: 9, sequence: 1))
    }
}
