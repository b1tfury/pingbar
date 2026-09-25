# PingBar

**A tiny, native macOS menu bar app that tells you — at a glance — whether your internet is actually working.**

```
 ● 14ms        ← green: healthy
 ● 92ms        ← yellow: sluggish
 ● --          ← red: packets not coming back
```

PingBar sends one 64-byte ICMP ping every 5 seconds to Cloudflare's `1.1.1.1` and shows the round-trip time in your menu bar with a green / yellow / red dot. Because `1.1.1.1` is anycast, it automatically resolves to the PoP nearest to you (Mumbai, Delhi, Chennai, Bangalore, Singapore, Frankfurt — wherever you happen to be), so the number you see is the latency to *your* closest edge, not to some far-off server.

No Electron. No webview. No dependencies. No root. A ~200 KB Swift binary that idles at 0% CPU.

---

## Why

Wi‑Fi icons lie. They show signal strength to your router, not whether packets are making it to the internet. PingBar answers the question you actually have — *"is my connection fine right now?"* — without opening a terminal and typing `ping`.

## Features

- **Traffic-light status** — green `< 60 ms`, yellow `< 150 ms`, red `≥ 150 ms` or timeout.
- **Live latency** in the menu bar, updated every 3 / 5 / 10 seconds (your choice).
- **Nearest-edge probing** via anycast — no geo-detection, no config.
- **Automatic fallback** — if Cloudflare times out, it retries Google `8.8.8.8` once before showing red, so a single provider hiccup doesn't cry wolf.
- **Last-minute stats** in the dropdown: avg / min / max latency and packet loss over the last 12 samples.
- **Launch at Login** toggle.
- **Featherweight** — 64-byte packets, ~12 per minute by default. You will never notice it on your bill or your bandwidth.
- **No privileges** — uses macOS's unprivileged ICMP datagram socket. No `sudo`, no `ping` subprocess.

## Requirements

- macOS 13 Ventura or later (Apple Silicon or Intel)
- Swift 5.9+ — the **Xcode Command Line Tools** are enough, no full Xcode needed:

  ```sh
  xcode-select --install
  ```

## Install & run

```sh
git clone https://github.com/b1tfury/pingbar.git
cd pingbar
make install
open /Applications/PingBar.app
```

That's it. Look at the top-right of your menu bar for `● 14ms`.

Then click it → **Launch at Login** so it's always there.

### Other targets

| Command        | What it does                                              |
| -------------- | --------------------------------------------------------- |
| `make app`     | Build a release binary and assemble `build/PingBar.app`   |
| `make run`     | Build and open the app bundle                             |
| `make install` | Build and copy to `/Applications/PingBar.app`             |
| `make dev`     | `swift run` — quick iteration, no bundle (Launch at Login disabled) |
| `make test`    | Run the unit tests                                        |
| `make clean`   | Remove build artifacts                                    |

### First launch

The app is ad‑hoc signed (not notarized). If macOS shows *"PingBar can't be opened because it is from an unidentified developer"*, right‑click the app → **Open**, or run:

```sh
xattr -dr com.apple.quarantine /Applications/PingBar.app
```

## Using it

Click the status item to open the menu:

```
Target: 1.1.1.1 (Cloudflare)
Last minute: avg 14 / min 11 / max 23 ms · loss 0%
──────────────────────────────
Interval        ▸  3 s / 5 s / 10 s
Target          ▸  Cloudflare 1.1.1.1 / Google 8.8.8.8
Launch at Login
──────────────────────────────
Quit PingBar                ⌘Q
```

| Indicator | Meaning                                                              |
| --------- | -------------------------------------------------------------------- |
| `● 14ms`  | Green — latency under 60 ms. All good.                               |
| `● 92ms`  | Yellow — 60–150 ms. Works, but video calls may stutter.              |
| `● 240ms` | Red — over 150 ms. Something is congested.                           |
| `● --`    | Red — no reply within 2 s from either target. You're probably offline. |
| `● !`     | Red — couldn't open the ICMP socket. Hover for the error.            |

Try it: turn Wi‑Fi off and watch it go `● --` within one interval; turn it back on and it recovers by itself.

## How it works

```
DispatchSourceTimer (every N s, background queue)
        │
        ▼
 ICMPPinger.ping()  ──►  SOCK_DGRAM / IPPROTO_ICMP socket
        │                 64-byte echo request, 2 s timeout
        ▼
 PingResult (.rtt / .timeout / .error)
        │
        ▼
 SampleWindow (last 12)  ──►  avg · min · max · loss %
        │
        ▼
 Status.classify()  ──►  green / yellow / red
        │
        ▼ (main thread)
 NSStatusItem  "● 14ms"
```

- `Sources/PingBarCore/` — the logic: `ICMPPacket` (RFC 1071 checksum, echo request builder), `ICMPPinger` (socket I/O), `SampleWindow`, `Status`, `LatencyMonitor`, `Settings`.
- `Sources/PingBar/` — the UI: `StatusBarController` (NSStatusItem + menu), `main.swift`.
- `Tests/PingBarTests/` — swift‑testing suites for every pure function (checksum, packet layout, reply parsing, thresholds, window stats).
- `docs/superpowers/` — the design spec and implementation plan this was built from.

## Development

```sh
make dev     # run from source
make test    # 19 tests, ~1 s
```

Tests use [swift-testing](https://github.com/swiftlang/swift-testing) (`import Testing`) rather than XCTest so they work with Command Line Tools alone. The Makefile passes the macro‑plugin path explicitly because the CLT toolchain doesn't auto‑discover it.

Preferences live in `UserDefaults` under the bundle id `dev.bitfury.pingbar`. To reset:

```sh
defaults delete dev.bitfury.pingbar
```

## Roadmap / ideas

Not built yet — open an issue or PR if you want one of these:

- Notification when the link stays red for N consecutive ticks
- Sparkline of the last minute in the dropdown
- TCP `:443` fallback for networks that filter ICMP
- Custom targets
- IPv6

## License

[MIT](LICENSE) — do whatever you like with it.
