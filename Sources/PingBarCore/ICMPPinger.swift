import Darwin
import Foundation

/// Sends ICMPv4 echo requests over an unprivileged datagram socket (macOS allows
/// `SOCK_DGRAM` + `IPPROTO_ICMP` without root). One instance per target host.
/// Synchronous; call from a background queue.
public final class ICMPPinger {
    public let host: String
    private var fd: Int32 = -1
    private var addr = sockaddr_in()
    private let identifier: UInt16
    private var sequence: UInt16 = 0
    private let payloadSize = 56

    public init(host: String) {
        self.host = host
        self.identifier = UInt16(truncatingIfNeeded: getpid())
    }

    deinit { close() }

    private func close() {
        if fd >= 0 { Darwin.close(fd); fd = -1 }
    }

    /// Opens the socket lazily; returns an error string on failure.
    private func ensureSocket() -> String? {
        if fd >= 0 { return nil }

        var a = sockaddr_in()
        a.sin_family = sa_family_t(AF_INET)
        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        guard inet_pton(AF_INET, host, &a.sin_addr) == 1 else {
            return "invalid IPv4 address: \(host)"
        }
        addr = a

        let s = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard s >= 0 else {
            return "socket(): \(String(cString: strerror(errno)))"
        }
        fd = s
        return nil
    }

    public func ping(timeout: TimeInterval = 2.0) -> PingResult {
        if let err = ensureSocket() { return .error(err) }

        sequence &+= 1
        let seq = sequence
        let packet = ICMPPacket.echoRequest(identifier: identifier, sequence: seq, payloadSize: payloadSize)

        let start = DispatchTime.now()
        let sent = packet.withUnsafeBytes { buf -> Int in
            withUnsafePointer(to: &addr) { aptr in
                aptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, buf.baseAddress, buf.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == packet.count else {
            let msg = String(cString: strerror(errno))
            close()  // force a fresh socket next tick (e.g. after interface change)
            return .error("sendto(): \(msg)")
        }

        let deadline = start + .nanoseconds(Int(timeout * 1_000_000_000))
        var buffer = [UInt8](repeating: 0, count: 1024)

        while true {
            let now = DispatchTime.now()
            if now >= deadline { return .timeout }
            let remainingMs = Int32((deadline.uptimeNanoseconds - now.uptimeNanoseconds) / 1_000_000) + 1

            var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = poll(&pfd, 1, remainingMs)
            if ready < 0 {
                if errno == EINTR { continue }
                return .error("poll(): \(String(cString: strerror(errno)))")
            }
            if ready == 0 { return .timeout }

            var from = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = buffer.withUnsafeMutableBytes { buf -> Int in
                withUnsafeMutablePointer(to: &from) { fptr in
                    fptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        recvfrom(fd, buf.baseAddress, buf.count, 0, sa, &fromLen)
                    }
                }
            }
            if n < 0 {
                if errno == EINTR || errno == EAGAIN { continue }
                return .error("recvfrom(): \(String(cString: strerror(errno)))")
            }

            let received = DispatchTime.now()
            if Self.isMatchingReply(Array(buffer[0..<n]), identifier: identifier, sequence: seq) {
                let ns = received.uptimeNanoseconds - start.uptimeNanoseconds
                return .rtt(Double(ns) / 1_000_000_000)
            }
            // Not ours (stale reply, other ICMP type). Keep waiting until deadline.
        }
    }

    /// macOS datagram ICMP sockets deliver the IPv4 header before the ICMP message.
    /// Returns true for an echo reply carrying our identifier + sequence.
    static func isMatchingReply(_ bytes: [UInt8], identifier: UInt16, sequence: UInt16) -> Bool {
        var offset = 0
        if let first = bytes.first, first >> 4 == 4 {
            offset = Int(first & 0x0F) * 4
        }
        guard bytes.count >= offset + ICMPPacket.headerLength else { return false }
        let icmp = bytes[offset...]
        let base = icmp.startIndex
        guard icmp[base] == ICMPPacket.echoReplyType else { return false }
        let id = UInt16(icmp[base + 4]) << 8 | UInt16(icmp[base + 5])
        let seq = UInt16(icmp[base + 6]) << 8 | UInt16(icmp[base + 7])
        return id == identifier && seq == sequence
    }
}
