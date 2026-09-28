# PingBar — 15-minute latency chart in the dropdown

**Date:** 2026-09-28
**Status:** Approved

## Purpose

The dropdown currently shows only a one-minute text summary. The user wants to see
*when* latency spiked over the last 15 minutes. Add a small, clear chart to the menu
without adding dependencies or idle cost.

## Constraints

- No third-party dependencies, no SwiftUI/Charts. Core Graphics in a custom `NSView`.
- Zero work while the menu is closed: the view only redraws when visible.
- Memory bounded: ≤ 300 samples (15 min at the fastest 3 s interval).

## Core changes (`PingBarCore`)

### `History`

Timestamped ring buffer, pure Swift, unit-tested.

```swift
public struct HistoryPoint: Equatable, Sendable { let time: Date; let result: PingResult }
public struct History: Sendable {
    init(capacity: Int = 300, span: TimeInterval = 900)
    mutating func append(_ result: PingResult, at: Date = Date())
    mutating func reset()
    func points(asOf now: Date = Date()) -> [HistoryPoint]   // only within `span`
    func maxRTT(asOf:) -> HistoryPoint?                       // highest RTT inside span
    func lossPercent(asOf:) -> Double
}
```

- `append` drops the oldest entry beyond `capacity`.
- `points(asOf:)` filters to `now - span ... now`, oldest first.

### `LatencyMonitor` / `Snapshot`

- Monitor owns a `History` alongside the existing `SampleWindow`.
- `Snapshot` gains `history: [HistoryPoint]` (already filtered to the 15-min span).
- `setTarget` resets history (different host, not comparable). `setInterval` keeps it.

## UI changes (`PingBar`)

### `HistoryChartView: NSView`

Placed as `menuItem.view` on a disabled menu item directly under the stats row.
Size 360 × 96 pt. Draws on `draw(_:)`:

- Header (11 pt, secondary label colour):
  `Last 15 min · max 113 ms at 11:52 · loss 0%` (or `no data yet`).
- Plot area with a faint baseline and left-side y labels `0`, mid, max (ms).
  Y scale = max(100 ms, window max) so spikes stand out.
- One vertical bar per sample, positioned by timestamp (not index) so gaps are
  visible. Bar colour by `Status.classify`: systemGreen / systemYellow / systemRed.
- Timeouts/errors: a short red tick at the top of the plot at that timestamp.
- Dashed hairlines at 60 ms and 150 ms in yellow/red at ~30 % alpha.
- X labels below the plot: `-15m`, `-10m`, `-5m`, `now`.
- Colours use dynamic system colours so light/dark menus both look right.

### `StatusBarController`

- Adds the chart item to the menu after `statsInfo`.
- On each `Snapshot`, stores `history` into the view; calls `needsDisplay = true`
  only when the menu is open (`menuWillOpen` / `menuDidClose` track this).

## Testing

- `HistoryTests`: caps at capacity, filters by span, `maxRTT` ignores lost samples,
  `lossPercent`, `reset`.
- Manual: `make dev`, wait a few minutes, open the menu; pull the Wi‑Fi to create
  red ticks; confirm the spike time in the header matches.

## Out of scope

Persisting history across restarts, hover tooltips on bars, configurable span.
