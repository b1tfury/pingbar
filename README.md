# PingBar

Tiny native macOS menu bar app that shows live internet latency with a green / yellow / red indicator.

```
● 14ms
```

- Pings Cloudflare `1.1.1.1` (anycast → nearest PoP, e.g. Mumbai/Delhi/Chennai when in India) every 5 s. Falls back to Google `8.8.8.8` on a timeout.
- 64-byte ICMP echo over an unprivileged datagram socket — no root, no `ping` subprocess.
- Green `< 60 ms`, yellow `< 150 ms`, red otherwise / timeout.
- Dropdown: last-minute avg/min/max + packet loss, interval (3/5/10 s), target, Launch at Login.
- Swift + AppKit, zero dependencies, no Xcode project.

## Build

Requires macOS 13+ and Swift 5.9+ (Xcode Command Line Tools are enough).

```sh
make app       # → build/PingBar.app
make run       # build and open it
make install   # copy to /Applications
make test      # unit tests
make dev       # swift run (no bundle; Launch at Login disabled)
```

## Layout

- `Sources/PingBarCore/` — `ICMPPacket` (pure builder/checksum), `ICMPPinger` (socket I/O), `SampleWindow`, `Status`, `LatencyMonitor`, `Settings`
- `Sources/PingBar/` — `StatusBarController` (NSStatusItem + menu), `main.swift`
- `Tests/PingBarTests/` — swift-testing suites for the pure parts
- `docs/superpowers/` — design spec and implementation plan
