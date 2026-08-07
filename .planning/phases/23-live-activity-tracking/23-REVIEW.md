---
phase: 23-live-activity-tracking
reviewed: 2026-08-07T22:41:21Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - lib/screens/today/now_state.dart
  - lib/screens/today/today_screen.dart
  - test/screens/today_screen_now_state_test.dart
  - test/screens/today_screen_test.dart
  - test/screens/today_timeline_model_test.dart
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 23: Code Review Report

**Reviewed:** 2026-08-07T22:41:21Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the LIVE-01/LIVE-02/LIVE-03 diff (`git diff 0e4fcf0..HEAD`) at standard depth: `now_state.dart`'s work-only filter removal, `today_screen.dart`'s dual-cadence timer and break-aware live row, and the three associated test files. Ran the full suite (455 tests, all green) and `flutter analyze` (clean) as part of verification, not just static reading.

The five risks called out in the review brief were each traced through code and checked against test coverage, not assumed from the plan's own claims:

- **Timer leaks**: `_fastTimer` is cancelled in `dispose()`, in the `paused` lifecycle branch, and defensively at the top of `build()`'s empty-state early return (`_syncFastTimer(false)` before `return _buildEmptyState(...)`). The `resumed` branch restarts `_nowTimer` and forces a `setState` so `build()` re-evaluates `_syncFastTimer` against a fresh clock rather than blindly resuming the old cadence. `_syncFastTimer` is idempotent (checks `_fastTimer == null`/`!= null` before acting), so the two timers cannot double-fire or duplicate across repeated pause/resume cycles. Confirmed both by reading and by the dedicated `LIVE-02 fast tick` test group, which passes.
- **Single-detector discipline**: `resolveNowState` remains the only "what is now" classifier — `timeline.dart` and the AppBar's focus-target switch both consume its output rather than re-deriving. `_liveSecondsRemaining` is the only seconds-remaining computation and its output is threaded as a single parameter into the label, the progress bar, and the fast-timer decision, so those three can't disagree with each other. One caveat is filed as WR-01 below: `_liveSecondsRemaining` re-reads the injected clock independently of `resolveNowState`'s read.
- **"Start focus" never targets a break**: `_buildAppBar` narrows every non-null `NowState` arm (`Active`, `Overdue`, `GapBeforeNext`, `PreStart`) through a single `resolvedTarget?.chunkType == ChunkType.work` check before it becomes `focusTarget`. Verified this can't be bypassed — there is no other path to `focusTarget`. The regression tests genuinely discriminate: `today_screen_test.dart` has a disabled-button test for each of Active/GapBeforeNext/Overdue targeting a break, **and** a positive case ("Start focus still targets the Active work chunk when a break follows it") that would fail against an overly-broad fix that just disabled the button unconditionally.
- **Test honesty**: spot-checked the countdown and break-state tests — they pump the real `TodayScreen` widget with real chunk fixtures and real `resolveNowState`/`buildTimeline` calls, then assert against rendered text or classified state. Found no case that merely restates its own arithmetic instead of exercising the function under test. The countdown boundary tests (`59s`/`60s`/`61s`/`1s`) each pin a distinct rendered string rather than a computed value.
- **`LiveRowCard` zero-change claim**: confirmed via `git diff --name-only 0e4fcf0..HEAD -- lib/ test/` — `lib/screens/today/widgets/live_row_card.dart` and `lib/screens/today/timeline.dart` do not appear in the changed-file list at all. Read both anyway; no rendering logic has leaked into the widget layer — `kicker`/`title`/`remainingLabel` are all screen-computed and injected as plain strings/doubles.

No AI/nondeterminism surface was introduced — `resolveNowState` and `_liveSecondsRemaining` remain pure functions of `chunks` and an injected clock.

No Critical findings. Two Warnings and one Info item below — none block the change, but the first Warning is worth a follow-up since it reintroduces (at a smaller scale) exactly the class of hazard `resolveNowState`'s own doc comment says it exists to avoid.

## Warnings

### WR-01: `_liveSecondsRemaining` re-reads the clock instead of reusing the sample `resolveNowState` already took

**File:** `lib/screens/today/today_screen.dart:635` (and the call site at `today_screen.dart:867-868`)
**Issue:** `now_state.dart`'s `resolveNowState` doc comment is explicit about why the clock must be sampled exactly once per classification: "If now() were called twice ... a rollover at 8:59→9:00 could yield hour=8 from the first call and minute=0 from the second." `build()` honors that for `nowState` itself (`_nowFn` passed once as `resolveNowState(..., now: _nowFn)`), but the very next line, `_liveSecondsRemaining(nowState)`, calls `_nowFn()` again independently (`today_screen.dart:635`), and `_buildHeader` also calls `_nowFn()` a third time for the date text. In production the gap between these calls is sub-millisecond so the practical exposure is negligible, but it is a real, avoidable second (and third) clock read in the same render pass, and it means `_liveSecondsRemaining`'s countdown is not actually guaranteed consistent with the `nowState` it's given — it is only *usually* consistent. A slow build (e.g. under heavy widget-tree work, or a paused debugger) could in principle produce a countdown computed from a `now()` a full window-boundary later than the one that produced `Active`, in which case `rawSecondsLeft` goes negative and gets silently clamped to 0 rather than the state re-resolving to `Overdue`.
**Fix:** Sample `_nowFn()` once in `build()` and pass the resulting `DateTime` (or precomputed minute/second values) into both `resolveNowState` and `_liveSecondsRemaining`, e.g.:
```dart
final nowDt = _nowFn();
final nowState = resolveNowState(chunks: schedule.chunks, now: () => nowDt);
final liveSecondsLeft = _liveSecondsRemaining(nowState, nowDt);
```
and change `_liveSecondsRemaining`'s signature to accept the sampled `DateTime` instead of reaching back into `_nowFn` itself.

### WR-02: `DayComplete`'s correctness now depends on an unenforced cross-file invariant, with no defensive check in this file

**File:** `lib/screens/today/now_state.dart:74-83`
**Issue:** LIVE-01 removed the work-only filter, so the `DayComplete` window check (`currentMinutes >= scheduled.last.displayStartMinutes! + scheduled.last.durationMinutes`) now depends on `scheduled.last` always being work-typed even though breaks are eligible to appear in `scheduled`. The doc comment is admirably honest that this is guaranteed only by two other files' logic (`schedule_generator.dart` STEP E and `ScheduleNotifier._reflowDiscretionaryWork`) and says outright: "A future edit to either mechanism that breaks this guarantee would silently regress `DayComplete` here." That's a real regression vector with zero defense in this file — no assertion, no fallback if the trailing chunk turns out to be a break (e.g., a day ending on a long break would report `DayComplete` at the break's end rather than treating any trailing unresolved work as still owed, or vice versa depending on how the invariant breaks). This is a maintainability/robustness gap the authors already flagged rather than a hidden one, but adversarially it should be either asserted in debug builds or tested with a fixture that intentionally violates the assumption (trailing break) so a future regression fails loudly instead of silently.
**Fix:** Add a debug-mode assertion (e.g. `assert(scheduled.last.chunkType == ChunkType.work, 'trailing chunk must be work-typed — see DayComplete invariant doc')`) or a defensive fallback that walks backward past trailing non-work chunks when computing the day-end boundary, plus a `resolveNowState` unit test that constructs a schedule with a genuine trailing break and pins the (currently undefined-by-test) behavior.

## Info

### IN-01: No widget-level test pins the live row's copy for an *overdue* break

**File:** `test/screens/today_screen_now_state_test.dart`
**Issue:** LIVE-01's break-aware kicker/title (`RIGHT NOW — RESTING` / `Taking a break`) has dedicated widget tests for the *Active* break case (kicker, title, hidden actions, progress bar), and `resolveNowState`'s unit tests separately cover the *Overdue*-break classification. But nothing pins what the live row actually renders when a break is Overdue — `_liveKicker`/`_liveTitle` are type-based (not state-based), so an overdue break currently reads identically to an active one ("RIGHT NOW — RESTING" / "Taking a break") even though the break's own window has already elapsed. That may well be the intended behavior (it mirrors how overdue work chunks already reuse the active label), but as written it's an assumption rather than a verified contract — worth a small widget test to lock in the intended copy and catch an accidental future regression.
**Fix:** Add a widget test pumping a break with a past window (`Overdue`) and asserting on `find.text('RIGHT NOW — RESTING')` / `find.text('Taking a break')` plus the plain time-range `remainingLabel`, mirroring the existing Active-break tests.

---

_Reviewed: 2026-08-07T22:41:21Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
