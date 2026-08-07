---
phase: 23-live-activity-tracking
plan: 02
subsystem: ui
tags: [flutter, timer, countdown, today-screen, live-row]

# Dependency graph
requires:
  - phase: 23-live-activity-tracking (plan 01)
    provides: break-aware resolveNowState, _liveTitle/_liveKicker, the live row's Active branch this plan replaces
provides:
  - _liveSecondsRemaining(NowState) — the single seconds-remaining source, threaded through _buildTimelineRow into _buildLiveRow, feeding the label, the progress bar, and the fast-timer decision
  - two-branch countdown label — whole minutes rounded up at >=60s, seconds at <60s ("42s left")
  - _fastTimer + _syncFastTimer — a 1-second timer that exists only during the live activity's final 60 seconds, lifecycle-managed identically to the existing 1-minute _nowTimer
affects: [23-03-edge-state-copy, 23-04-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "One seconds computation, threaded down: _liveSecondsRemaining is called exactly once per build() and passed as an int? parameter through _buildTimelineRow into _buildLiveRow — no second derivation path (P-5)"
    - "Dual-cadence timer: a second, narrowly-scoped Timer (_fastTimer) added alongside the existing _nowTimer rather than replacing its 1-minute cadence; mirrors _nowTimer's lifecycle (idempotent start, mounted guard, dispose/pause cancellation) with one addition — resume re-evaluates via setState rather than blindly restarting (P-5a)"

key-files:
  created: []
  modified:
    - lib/screens/today/today_screen.dart
    - test/screens/today_screen_now_state_test.dart

key-decisions:
  - "_liveSecondsRemaining reads nowState directly (nowState is Active, then nowState.current) rather than taking chunk/start/end as separate parameters — keeps the single-source contract explicit: the function owns both 'is there a live activity' and 'how much time is left'"
  - "Progress bar formula changed from the old '(nowMinutes - start) / durationMinutes' to '1 - secondsRemaining / (durationMinutes * 60)' — algebraically the same value at second precision, derived from the same secondsRemaining the label uses, so the two can never disagree (D-04)"
  - "Resume rebuilds via setState rather than re-deriving the <60s condition inline in didChangeAppLifecycleState — the single _syncFastTimer call site in build() stays the only place the fast-timer decision is made, and this incidentally fixes a pre-existing staleness bug where resuming showed stale content until the next minute boundary"

requirements-completed: [LIVE-02]

# Metrics
duration: ~15min
completed: 2026-08-07
---

# Phase 23 Plan 02: Live Countdown Summary

**The live row's remaining-time label now counts down in real seconds during the final minute of a running work chunk or break — whole minutes rounded up above 60s, seconds below it — driven by a 1-second timer that exists only during that final minute, never continuously.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-07T22:10Z (approx.)
- **Completed:** 2026-08-07T22:15Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `_liveSecondsRemaining(NowState)` is the single source of "how much of the current activity is left" — computed once in `build()`, threaded through `_buildTimelineRow` into `_buildLiveRow`, and used by the label, the progress bar, and the fast-timer decision. Grep-verified: exactly one definition, one call site.
- The live row's countdown label branches at the 60-second boundary: `"15 min left · until 8:30 AM"` while ≥60s remain (rounded up — 8:15:30 with 14.5 minutes left still reads "15 min left", never "14 min left"), `"59s left · until 8:30 AM"` below it, and never `"0 min left"` at any point, including the final second.
- A new `_fastTimer` (1-second `Timer.periodic`) exists only while the live chunk has under 60 seconds left — bounded at roughly 60 wakeups per activity boundary rather than running continuously all day (T-23-04). It mirrors the existing `_nowTimer`'s lifecycle exactly: idempotent start/cancel via `_syncFastTimer`, `mounted`-guarded `setState`, cancelled on `dispose()` and on `paused`, and — on `resumed` — the screen rebuilds so `build()` re-decides the fast-timer condition against the fresh clock rather than blindly restarting it (this also fixes a pre-existing bug where resuming the app showed stale content until the next minute boundary).
- 14 new tests (8 countdown-label boundary cases + 6 fast-timer lifecycle cases) all pass; the full suite is green at 452/452 (up from 438 baseline + 14 new), `flutter analyze` reports no issues, and no "Timer is still pending" failures occurred anywhere.

## Task Commits

Each task was committed atomically:

1. **Task 1: Second-precision remaining-time label with a ceil-to-minutes branch (D-01, D-04, P-5)** - `b049fa2` (feat)
2. **Task 2: The dual-cadence tick — a fast timer that exists only in the final minute (D-01, P-5a, T-23-04)** - `d825709` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `lib/screens/today/today_screen.dart` - Added `_liveSecondsRemaining(NowState)` before `_buildLiveRow`; threaded an `int? secondsRemaining` parameter through `_buildTimelineRow` into `_buildLiveRow`, replacing the old inline minute-only computation with the two-branch label and the seconds-derived progress bar; added `Timer? _fastTimer` and `_syncFastTimer(bool)`, wired into `build()`'s main path and empty-state early return, `dispose()`, and both branches of `didChangeAppLifecycleState`
- `test/screens/today_screen_now_state_test.dart` - Added 8 countdown-boundary widget cases (whole-minute rounding, both sides of the 60s boundary, a running break, the progress-bar/label agreement) to the existing `TodayScreen time-anchored Now` group, and a new `LIVE-02 fast tick` group with 6 lifecycle cases (1Hz advance inside the final minute, no timer outside it, start/stop across the boundary, no duplicate across a double paused/resumed cycle, no pending timer after dispose, no survival past the schedule disappearing)

## Decisions Made
- Kept `_liveSecondsRemaining` reading `nowState` directly (`nowState is Active`, `nowState.current`) rather than accepting pre-extracted `chunk`/`start`/`end` parameters, so the function is unambiguously the single place that answers both "is there a live activity" and "how much time is left."
- Rewrote the progress-bar formula from minute-granularity (`(nowMinutes - start) / durationMinutes`) to `1 - secondsRemaining / (durationMinutes * 60)` — the same value at second precision, and because it's derived from the identical `secondsRemaining` the label uses, the two can never drift apart (D-04).
- Resume triggers a plain `setState` rather than re-implementing the `<60s` check inline in `didChangeAppLifecycleState` — this keeps `_syncFastTimer`'s call site in `build()` the *only* place the fast-timer decision is made (matches the plan's single-now-detector-style invariant for this new decision point) and, as a side effect, fixes a real pre-existing bug: before this plan, resuming from background showed a stale label until the next 1-minute timer tick.

## Deviations from Plan

None - plan executed exactly as written. All acceptance-criteria greps (`_liveSecondsRemaining` count 2, `_nowFn()` count 3, `DateTime.now()` count 0, `Duration(minutes: 1)` count 1, `Duration(seconds: 1)` count 1, `_fastTimer?.cancel()` count 2, `_syncFastTimer(` count 3, `Future.delayed` count 0) matched the plan's expected values on the first pass, and `now_state.dart`/`live_row_card.dart`/`time_format.dart` received zero changes as required.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The live row now has a working, leak-free, battery-bounded countdown at both the whole-minute and seconds granularity, satisfying LIVE-02 in full.
- `_nowFn`, the single-now-detector invariant, and `LiveRowCard`'s injected-string contract are all unchanged — every constraint this plan was scoped against held.
- Plan 23-03 (edge-state copy) can proceed without re-touching the countdown or timer machinery this plan added.
- No blockers.

---
*Phase: 23-live-activity-tracking*
*Completed: 2026-08-07*

## Self-Check: PASSED

Both modified files verified present on disk; both commit hashes (`b049fa2`, `d825709`) verified present in `git log --oneline --all`.
