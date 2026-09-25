/// Pure helpers for building ICMPv4 echo requests. No I/O.
public enum ICMPPacket {
    public static let echoRequestType: UInt8 = 8
    public static let echoReplyType: UInt8 = 0
    public static let headerLength = 8

    /// RFC 1071 Internet checksum. Odd-length input is padded with a zero byte.
    public static func checksum(_ bytes: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        while i + 1 < bytes.count {
            sum += UInt32(bytes[i]) << 8 | UInt32(bytes[i + 1])
            i += 2
        }
        if i < bytes.count {
            sum += UInt32(bytes[i]) << 8
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return ~UInt16(truncatingIfNeeded: sum)
    }

    /// Builds an echo request: type 8, code 0, checksum, identifier, sequence, payload.
    /// Identifier and sequence are big-endian. Payload is a simple ramp so it's distinguishable on the wire.
    public static func echoRequest(identifier: UInt16, sequence: UInt16, payloadSize: Int) -> [UInt8] {
        var pkt = [UInt8](repeating: 0, count: headerLength + payloadSize)
        pkt[0] = echoRequestType
        pkt[1] = 0
        pkt[4] = UInt8(identifier >> 8)
        pkt[5] = UInt8(identifier & 0xFF)
        pkt[6] = UInt8(sequence >> 8)
        pkt[7] = UInt8(sequence & 0xFF)
        for i in 0..<payloadSize {
            pkt[headerLength + i] = UInt8(truncatingIfNeeded: i)
        }
        let sum = checksum(pkt)
        pkt[2] = UInt8(sum >> 8)
        pkt[3] = UInt8(sum & 0xFF)
        return pkt
    }
}
