# Phase 40: Complete/Skip From the Wrist — Context

**Gathered:** 2026-11-10, autonomously. Owner decision 6 accepted the outbox design: wrist taps may reach the
phone the next time Canopy runs. No native Hive writes.

## Decisions

- **D-40-01 Buttons on the now screen only.** Done and Skip appear for the running or overdue chunk, gated by the
  snapshot's `canComplete`/`canSkip`. Those gates are the phone's: breaks are skip-only and meals get nothing. The
  complication is not interactive; tapping it opens the app (research §2: complication buttons reaching Dart state is
  untested).
- **D-40-02 Delivery.**
  - When the phone is reachable, `sendMessage` *with a reply handler*. Apple wakes the iPhone app in the background,
    and `WatchBridge` writes the tap to disk before replying `ok`.
  - When it is unreachable, or on any error or a non-ok reply, `transferUserInfo`. watchOS queues it in FIFO order
    and delivers it even while the phone app is suspended.

  Both carry the same JSON as Dart's `WristAction`.
- **D-40-03 Native outbox.** `WatchBridge` writes one file per tap (`Application Support/wrist-outbox/<id>.json`,
  atomic) and then calls `outboxChanged` on the channel if Dart is alive. Dart's `WristOutboxCoordinator` drains:
  at start, on resume, and on `outboxChanged`. The drain runs Phase 38's replayer, so the tap's own time feeds G-05.
- **D-40-04 Optimistic, never inventive.** The watch keeps a "pending" list in the App Group. Its now screen shows
  "Sent to iPhone" and the rectangular complication's kicker reads "SENT ✓". The schedule itself is untouched until
  the phone's next snapshot. A pending mark clears when a snapshot no longer offers that chunk an action (the phone
  applied it, or dropped it) or when the day changes.
- **D-40-05 Haptic confirmation** on tap (`.success`).

## What cannot be checked off the device

The Simulator does not support `transferUserInfo`, and only real hardware shows whether `sendMessage` wakes a
suspended Flutter app (research §5). Both are owner UAT items.
