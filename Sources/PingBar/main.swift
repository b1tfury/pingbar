import PingBarCore

// Temporary live probe; replaced by the app in Task 5.
for host in ["1.1.1.1", "8.8.8.8"] {
    let p = ICMPPinger(host: host)
    for _ in 0..<3 {
        print(host, p.ping(timeout: 2.0))
    }
}
