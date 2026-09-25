import Testing
@testable import PingBarCore

@Suite struct ICMPPacketTests {
    // Classic RFC 1071 worked example (IPv4 header with zeroed checksum field).
    @Test func checksumMatchesKnownVector() {
        let header: [UInt8] = [
            0x45, 0x00, 0x00, 0x3c, 0x1c, 0x46, 0x40, 0x00, 0x40, 0x06,
            0x00, 0x00, 0xac, 0x10, 0x0a, 0x63, 0xac, 0x10, 0x0a, 0x0c,
        ]
        #expect(ICMPPacket.checksum(header) == 0xB1E6)
    }

    @Test func checksumHandlesOddLength() {
        // Odd-length input must be padded with a zero byte, not crash or drop data.
        #expect(ICMPPacket.checksum([0x01, 0x02, 0x03]) == ~UInt16(0x0102 + 0x0300))
    }

    @Test func echoRequestLayout() {
        let pkt = ICMPPacket.echoRequest(identifier: 0xBEEF, sequence: 0x0102, payloadSize: 56)
        #expect(pkt.count == 8 + 56)
        #expect(pkt[0] == 8)   // type: echo request
        #expect(pkt[1] == 0)   // code
        #expect(pkt[4] == 0xBE)
        #expect(pkt[5] == 0xEF)
        #expect(pkt[6] == 0x01)
        #expect(pkt[7] == 0x02)
        // Checksum over the entire packet (including the checksum field) must verify to 0.
        #expect(ICMPPacket.checksum(pkt) == 0)
    }

    @Test func echoRequestChecksumIsNonZero() {
        let pkt = ICMPPacket.echoRequest(identifier: 1, sequence: 1, payloadSize: 56)
        #expect(!(pkt[2] == 0 && pkt[3] == 0))
    }
}
