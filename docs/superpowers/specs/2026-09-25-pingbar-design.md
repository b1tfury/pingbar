# PingBar — macOS menu bar latency monitor

**Date:** 2026-09-25
**Status:** Approved

## Purpose

A tiny macOS menu bar app that continuously shows internet latency to the nearest
anycast PoP (Cloudflare `1.1.1.1`, fallback Google `8.8.8.8`) so the user can tell at a
glance whether the connection is healthy. Anycast routing means the probed server is
automatically the closest one to the user's current location (Mumbai/Delhi/Chennai/
Bangalore when in India) with no geo-detection logic.

## Constraints

- Super lightweight: native AppKit, no Electron/webview, no third-party dependencies.
  ~200 KB binary; RSS ≈ 55 MB (AppKit baseline, measured); ≈ 0% CPU when idle.
- Minimal network usage: one 64-byte ICMP echo every 5 s by default (~12 packets/min).
- No root privileges: use macOS's unprivileged ICMP datagram socket
  (`SOCK_DGRAM` + `IPPROTO_ICMP`).
- No Xcode project; builds with `swift build`. macOS 13+.

## Architecture

Swift Package with one executable target `PingBar` and one test target `PingBarTests`.

```
experiments/pingbar/
  Package.swift
  Makefile                      # `make app` -> build/PingBar.app ; `make run`
  Resources/Info.plist          # LSUIElement=true (no Dock icon)
  Sources/PingBar/
    main.swift                  # NSApplication, .accessory policy, wires components
    ICMPPinger.swift            # ICMP echo over unprivileged datagram socket
    LatencyMonitor.swift        # timer, sampling, rolling window, status
    StatusBarController.swift   # NSStatusItem + dropdown menu
    Settings.swift              # UserDefaults-backed prefs (interval, target)
  Tests/PingBarTests/
    ICMPPacketTests.swift
    LatencyMonitorTests.swift
  docs/superpowers/specs/...
```

### ICMPPinger

- `ICMPPacket.echoRequest(identifier:sequence:payloadSize:) -> [UInt8]` — pure function
  building an ICMP type-8 echo request with RFC 1071 checksum. Unit-tested.
- `ICMPPacket.checksum(_:) -> UInt16` — pure, unit-tested.
- `ICMPPinger(host:)` opens `socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)`. Failure to open
  is surfaced as `PingError.socketUnavailable`.
- `ping(timeout: 2.0) -> PingResult` where `PingResult = .rtt(TimeInterval) | .timeout | .error(String)`.
  Sends one echo request, waits with `poll`/`recvfrom` until a reply with matching
  identifier+sequence arrives or the timeout elapses. Synchronous; called from a
  background queue.

### LatencyMonitor

- Owns a `DispatchSourceTimer` on a background queue, firing every `interval` seconds
  (3, 5, or 10; default 5).
- Each tick: ping primary target. If `.timeout`, ping the fallback target once; if the
  fallback succeeds, record that RTT (tagged with the fallback host). If both fail,
  record a timeout sample.
- Rolling window: last 12 samples. Exposes `Snapshot`:
  `latest: PingResult`, `host: String`, `avg/min/max: TimeInterval?`, `lossPercent: Double`,
  `status: Status`.
- `Status.classify(_ result: PingResult) -> Status`: pure function.
  green `< 60 ms`, yellow `< 150 ms`, red `>= 150 ms` or timeout/error. Unit-tested.
- Delivers snapshots to an `onUpdate: (Snapshot) -> Void` callback on the main queue.
- `setInterval(_:)` and `setTarget(_:)` restart the timer and clear the window.

### StatusBarController

- `NSStatusItem` with variable length. Title is an `NSAttributedString`: a `●` colored
  green/yellow/red followed by ` 18ms` (or ` --` on timeout, ` !` on socket error) in the
  system menu bar font.
- Dropdown menu:
  - `Target: 1.1.1.1 (Cloudflare)` — disabled info row
  - `Last minute: avg 18 / min 12 / max 31 ms · loss 0%` — disabled info row
  - separator
  - `Interval ▸` 3 s / 5 s / 10 s (checkmark on current)
  - `Target ▸` Cloudflare 1.1.1.1 / Google 8.8.8.8 (checkmark on current; the other
    becomes the fallback)
  - `Launch at Login` (checkbox, via `SMAppService.mainApp`)
  - separator
  - `Quit PingBar` (⌘Q)
- Tooltip on the status item shows the last error string when in error state.

### Settings

`UserDefaults` keys: `interval` (Double, default 5), `primaryTarget` (String, default
`1.1.1.1`). Fallback is whichever of the two known targets is not primary.

### main.swift

Creates `NSApplication.shared`, sets `.accessory` activation policy (works even when run
as a bare binary via `swift run`, where `LSUIElement` is not read), constructs Settings →
LatencyMonitor → StatusBarController, starts the monitor, runs the app.

## Data flow

timer tick → `ICMPPinger.ping` → `PingResult` → appended to window → `Snapshot` computed →
`onUpdate` on main thread → `StatusBarController` redraws title + menu info rows.

## Error handling

- ICMP socket cannot be created: monitor emits `.error` samples; title `● !` red; tooltip
  carries the reason. App keeps retrying each tick (socket is reopened on failure).
- Timeout: counted as a lost sample; title `● --` red.
- DNS is never involved (IP literals only), so no resolver failures.
- Interface changes (Wi‑Fi ↔ hotspot) need no handling: each ping is a fresh sendto.

## Testing

- XCTest, run with `swift test`:
  - checksum of a known byte sequence matches RFC 1071 expected value
  - echo request layout: type 8, code 0, identifier/sequence big-endian, total length
    = 8 + payload, checksum verifies to 0 over the whole packet
  - `Status.classify` boundaries: 59.9 ms green, 60 ms yellow, 149.9 ms yellow,
    150 ms red, timeout red, error red
  - rolling window: caps at 12, `lossPercent` counts timeouts+errors, avg/min/max ignore
    lost samples and are `nil` when all lost
- Manual: `make run`, observe title; turn Wi‑Fi off → red `--` within one interval;
  back on → green.

## Out of scope

Notifications, history graph, TCP/HTTP fallback probes, IPv6, auto-update, code signing /
notarization, custom targets UI.
