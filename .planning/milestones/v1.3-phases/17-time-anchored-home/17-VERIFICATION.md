---
phase: 17-time-anchored-home
verified: 2026-06-13T00:00:00Z
status: passed
human_uat_cleared: 2026-06-14
score: 8/8 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Live on-device Now/Next transition across a real chunk boundary"
    expected: "At the actual minute a chunk window opens, the Now zone flips from
      pre-start or gap to ActiveChunkCard without a manual refresh."
    why_human: "Timer.periodic fires every 60 seconds; verifying the transition
      happens at the correct wall-clock minute requires watching a real device
      — no programmatic shortcut can substitute for the lived experience."
  - test: "Visual confirmation of pre-start state on device"
    expected: "'Your day starts at [TIME]' heading and goal body line render with
      the correct font weight and onSurfaceVariant color; no accent color or emoji
      present."
    why_human: "Color correctness and typography weight cannot be verified by
      grep or unit tests — requires visual inspection on device."
  - test: "Visual confirmation of day-complete state on device"
    expected: "'That's a wrap' and 'You've reached the end of today's schedule.'
      render with titleMedium w600 and bodyMedium onSurfaceVariant; no emoji; no
      accent color."
    why_human: "Same visual-inspection requirement as pre-start."
  - test: "Background/foreground lifecycle on a physical device"
    expected: "Send app to background (home button), wait >1 min, return to
      foreground — the Now zone refreshes immediately (timer restarts, no ANR,
      no setState-after-dispose crash)."
    why_human: "AppLifecycleState.paused/resumed behavior varies by platform and
      OS version; widget test fakes the lifecycle signal but cannot reproduce true
      background-battery behavior."
---

# Phase 17: Time-Anchored Home — Verification Report

**Phase Goal:** Home's Now and Next always reflect the chunk whose clock window contains the current time — not the first unresolved chunk — with clear pre-start and day-complete states when no chunk is active.
**Verified:** 2026-06-13
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | At 6pm with no chunks checked off, Home does not show the 8am chunk as Now — it shows a time-anchored state (overdue/active for the current window, or day-complete). | VERIFIED | Unit test "day-complete (time past last window): chunk 8am–9am, now 6pm" passes (`isA<DayComplete>()`). Widget test "day-complete (6pm, all windows passed)" finds `"That's a wrap"` and `ActiveChunkCard findsNothing`. |
| 2  | Before the first chunk's start time, Home shows a pre-start state ("Your day starts at [TIME]"), not a stale Now card. | VERIFIED | Unit test "pre-start: 6am, chunk at 480 min" passes (`isA<PreStart>`, `firstChunk.displayStartMinutes == 480`). Widget test "pre-start: 6am before 8am chunk" finds `"Your day starts at"` and `ActiveChunkCard findsNothing`. |
| 3  | After the last chunk's window has passed, Home shows a day-complete state ("That's a wrap"), not the last chunk stuck as Now. | VERIFIED | Same tests as Truth 1. `"That's a wrap"` text present in `_buildDayCompleteContent` (home_screen.dart line 612). `"All done today"` count is 0 in both production and test files. |
| 4  | Now/Next refresh as wall-clock time passes via a 1-minute timer that pauses on background and resumes on foreground. | VERIFIED | `Timer.periodic(const Duration(minutes: 1), ...)` at home_screen.dart line 260. `didChangeAppLifecycleState` pauses/resumes at lines 266–271. Timer/lifecycle widget test confirms pre-start → active transition after `pump(Duration(minutes: 1))` with advanced injected clock. WR-03 idempotency check passes (`nowCallCount == 1` after two paused→resumed cycles). |
| 5  | `resolveNowState` is a pure, top-level, clock-injectable function. | VERIFIED | Top-level public function at home_screen.dart line 115. Injectable via `required DateTime Function() now`. All 10 pure unit tests (including `GapBeforeNext` additions) pass with no widget pump. |
| 6  | "Now" is selected by clock window `[start, end)` containing current time — NOT first-unresolved. | VERIFIED | `resolveNowState` algorithm: filter→sort by `displayStartMinutes`, compare `currentMinutes` against window boundaries, THEN check resolution. Enforced by the "active advances past resolved chunk" unit test (c1 completed, c2 unresolved, now inside c1 window → `Active(c2)`). |
| 7  | An early-finish gap (resolve a chunk, next chunk's window not yet open, future unresolved work remains) shows an honest `GapBeforeNext` state — NOT a false day-complete. | VERIFIED | `GapBeforeNext` NowState added beyond the original 4-state PLAN contract (see note below). Unit tests: "gap: c1 resolved 9:00–9:25, c2 starts 10:00, now=9:30 → `GapBeforeNext(c2)`" and near-gap companion both pass. Widget test: "gap state … shows 'Up next' and NOT 'That's a wrap'" passes. |
| 8  | Existing `active_chunk_card_test.dart` migrated: "All done today!" removed, NAV-02 chunks carry `syntheticStartMinutes`, injected `now` threaded through. | VERIFIED | Zero occurrences of "All done today" in home_screen.dart and active_chunk_card_test.dart. `_scheduleWithTwoChunks()` assigns `syntheticStartMinutes` 540/600. `_pumpHomeScreen` accepts `DateTime Function()? now` and forwards to `HomeScreen(now:)`. All 31 targeted tests pass. |

**Score:** 8/8 truths verified

---

### Note: GapBeforeNext — Additive Fifth State (Not in PLAN Must-Haves)

The PLAN specified a 4-state `NowState` hierarchy (`PreStart`, `Active`, `Overdue`, `DayComplete`). The implementation adds a fifth state: `GapBeforeNext`. This is an additive correction that makes the goal MORE honest, not less — without it, the original 4-state logic would return `DayComplete` when a chunk is resolved but a future unresolved chunk's window has not yet opened (falsely telling the user their day is done). `GapBeforeNext` is:

- Fully implemented in `home_screen.dart` (class, renderer `_buildGapBeforeNextContent`, exhaustive switch arm)
- Covered by 3 pure unit tests and 1 widget test
- All tests pass

This is not a gap. It is an honest extension of the goal.

---

### Required Artifacts

| Artifact | Expected (PLAN) | Status | Details |
|----------|-----------------|--------|---------|
| `lib/screens/home/home_screen.dart` | `resolveNowState` pure function, `NowState` sealed hierarchy, 1-min timer + `WidgetsBindingObserver`, pre-start and day-complete inline states | VERIFIED | All symbols present; `resolveNowState` defined at line 115 and called in `build()` at line 329; timer at line 260; `WidgetsBindingObserver` mixin at line 212; `_buildPreStartContent`, `_buildGapBeforeNextContent`, `_buildDayCompleteContent` all present. |
| `test/screens/home_screen_now_state_test.dart` | Pure unit tests for `resolveNowState` (4+ states) + `HomeScreen` widget tests at simulated times + timer/lifecycle tests | VERIFIED | 10 pure unit tests (7 from PLAN + 3 gap tests added) + 6 widget tests (including gap state) + timer/lifecycle test with WR-03 idempotency check. All 31 tests in both files pass. |
| `test/screens/active_chunk_card_test.dart` | Migrated: "All done today!" → "That's a wrap"; NAV-02 chunks carry `syntheticStartMinutes` | VERIFIED | "All done today!" count 0 in file. `_scheduleWithTwoChunks()` assigns 540/600. `_pumpHomeScreen` accepts optional `now`. All NAV-02 tests inject `navNow`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `_HomeScreenState build()` | `resolveNowState` | `switch (nowState)` drives Now zone via `_buildNowContent` | VERIFIED | home_screen.dart lines 329–332 call `resolveNowState(chunks:, now: _nowFn)`, line 380 calls `_buildNowContent(context, nowState)`, line 512 exhaustive switch. |
| `_HomeScreenState` timer | `resolveNowState` | `Timer.periodic(1 min)` → `setState(() {})` → rebuild re-evaluates with fresh `_nowFn()` | VERIFIED | home_screen.dart lines 258–262. Widget test confirms transition after `pump(Duration(minutes: 1))`. |
| `resolveNowState` | `ScheduledChunk.displayStartMinutes` | filter + sort by clock-window start | VERIFIED | home_screen.dart lines 127–134: filter `c.displayStartMinutes != null`, sort by `displayStartMinutes`. Comparisons at lines 140, 145, 152, 169. |

### Data-Flow Trace (Level 4)

`resolveNowState` consumes `schedule.chunks` (sourced from `ScheduleNotifier.todaySchedule!.chunks` at line 321). This is a live `ChangeNotifier` — no static/hardcoded data is returned. The `now` parameter defaults to `DateTime.now` at runtime (line 218), providing real wall-clock data. No hollow props or disconnected state paths found.

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `_buildNowContent` / `ActiveChunkCard` | `nowState` from `resolveNowState` | `schedule.chunks` from `ScheduleNotifier.todaySchedule` (live provider) | Yes | FLOWING |
| `resolveNowState` `now` param | `_nowFn` | `DateTime.now` at runtime / injected in tests | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `resolveNowState` pure unit tests (10 tests) | `flutter test test/screens/home_screen_now_state_test.dart --plain-name "resolveNowState unit tests"` | 10/10 pass | PASS |
| HomeScreen widget tests (6 tests) | `flutter test test/screens/home_screen_now_state_test.dart` (widget group) | 6/6 pass | PASS |
| `active_chunk_card_test.dart` migrated tests | `flutter test test/screens/active_chunk_card_test.dart` | 21/21 pass | PASS |
| Static analysis | `flutter analyze lib/screens/home/home_screen.dart` | No issues found | PASS |
| Full test suite | `flutter test` | 243/243 pass | PASS |
| "All done today" removed from production | `grep -c "All done today" home_screen.dart` | 0 | PASS |
| "All done today" removed from test | `grep -c "All done today" active_chunk_card_test.dart` | 0 | PASS |
| `resolveNowState` defined AND called in build() | grep confirms lines 115 and 329 | Both present | PASS |
| `Timer.periodic` present | grep confirms line 260 | Present | PASS |
| "That's a wrap" in production code | grep confirms line 612 | Present | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| NOW-01 | 17-01-PLAN.md | "Now" reflects the chunk whose clock-time window contains the current time (not the first unresolved chunk); at 6pm the 8am chunk is not shown as "Now." | SATISFIED | `resolveNowState` uses clock-window selection. Day-complete at 6pm verified by unit test + widget test. Overdue/active identity pinned by WR-02 assertion. |
| NOW-02 | 17-01-PLAN.md | Before the day's first chunk and after the last resolved/ended chunk, Home shows a clear pre-start / day-complete state rather than a stale "Now." | SATISFIED | Pre-start state shown before first window (unit + widget tests). Day-complete shown after last window AND when all resolved (unit + widget tests). `GapBeforeNext` (early-finish gap) correctly NOT shown as day-complete. |

### Anti-Patterns Found

No blocking anti-patterns found.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `home_screen.dart` | 502 | `return null` in `_lookupGoalName` | Info | Intentional null-return for chunks without a `goalId` (commitment-anchored); not a stub. |

No `TBD`, `FIXME`, or `XXX` markers in any of the three modified files. No placeholder copy, no empty implementations, no hardcoded empty data passed to rendering paths.

---

### Human Verification Required

#### 1. Live Now/Next Transition on Device

**Test:** Install app on a real device. Set the device clock to 1 minute before a scheduled chunk's `displayStartMinutes` window opens. Watch the Home screen without touching it.
**Expected:** At the exact minute the window opens, the Now zone transitions from pre-start (or gap) to `ActiveChunkCard` — without a manual refresh or hot-reload.
**Why human:** The 1-minute `Timer.periodic` is correctly wired in code and the widget test confirms it fires, but the widget test uses `tester.pump(Duration(minutes: 1))` to advance a fake timer. Real-device behavior at the OS level (battery optimization, background process limits, timer precision) cannot be reproduced programmatically.

#### 2. Visual Confirmation — Pre-Start State

**Test:** On a real device or emulator, view Home before the day's first chunk starts.
**Expected:** "Your day starts at [TIME]" heading in `titleMedium` w600 weight; body line in `bodyMedium` with `onSurfaceVariant` color; no accent color; no emoji; no `ActiveChunkCard`.
**Why human:** Font weight and color token rendering require visual inspection — automated tests verify widget presence but not visual fidelity.

#### 3. Visual Confirmation — Day-Complete State

**Test:** On a real device or emulator, view Home after all chunk windows have passed (or mark all chunks complete).
**Expected:** "That's a wrap" heading in `titleMedium` w600; body "You've reached the end of today's schedule." in `bodyMedium onSurfaceVariant`; no emoji; no accent color; no `ActiveChunkCard`.
**Why human:** Same visual-inspection requirement as pre-start.

#### 4. Background/Foreground Lifecycle

**Test:** With Home visible and a chunk active, press the home button (app to background). Wait 2+ minutes. Return to foreground.
**Expected:** Now zone reflects the correct current time immediately on return — no stale state, no crash, no ANR.
**Why human:** `AppLifecycleState.paused/resumed` behavior varies by OS version and battery-optimization settings. Widget tests fake the lifecycle signal; real device behavior cannot be substituted.

---

### Gaps Summary

No gaps. All 8 must-have truths are VERIFIED by codebase evidence and passing tests.

The `GapBeforeNext` fifth state is a correct additive improvement beyond the PLAN's 4-state contract — it handles the early-finish gap case honestly (prevents a false day-complete when unresolved future chunks remain) and is fully tested.

Four items are deferred to human (on-device) verification per the PLAN's own `<verification>` section ("Manual-only (deferred to UAT, per 17-VALIDATION.md)").

---

_Verified: 2026-06-13_
_Verifier: Claude (gsd-verifier)_
