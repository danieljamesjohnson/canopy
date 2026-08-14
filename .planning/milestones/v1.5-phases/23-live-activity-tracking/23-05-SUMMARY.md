---
phase: 23-live-activity-tracking
plan: 05
subsystem: ui
tags: [flutter, timer, app-lifecycle, widget-test, gap-closure]

# Dependency graph
requires:
  - phase: 23-live-activity-tracking (plans 01-04)
    provides: TodayScreen's live row, its 1-minute/1-second timer pair, and the UAT that surfaced G-03
provides:
  - "A lifecycle handler with no single point of failure: the 1-minute tick survives a paused with no matching resumed"
  - "A _isBackgrounded guard proving the 1-second fast tick still cannot run while backgrounded (battery contract intact)"
  - "A build()-time self-heal that revives a dead _nowTimer as a secondary layer"
  - "A discovered, documented Flutter engine constraint (SchedulerBinding disables frame scheduling on hidden/paused/detached) relevant to any future lifecycle-related widget test in this codebase"
affects: [any future today_screen.dart lifecycle work, any future widget test that simulates AppLifecycleState.paused]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AppLifecycleState.inactive as a test-only frame-scheduling re-enabler that does NOT invoke an app's `resumed` handler — isolates 'frames drawable, resumed never delivered' from 'resumed properly recovers'"

key-files:
  created: []
  modified:
    - lib/screens/today/today_screen.dart
    - test/screens/today_screen_now_state_test.dart
    - .planning/phases/23-live-activity-tracking/23-UI-SPEC.md

key-decisions:
  - "Stop cancelling _nowTimer on AppLifecycleState.paused; only _fastTimer is cancelled there, guarded further by a new _isBackgrounded field so it cannot restart via a background rebuild"
  - "Add a build()-time self-heal for _nowTimer (belt-and-braces, not primary — a plan-checker-flagged limitation: it only fires if a later build() happens)"
  - "Route the regression tests through AppLifecycleState.inactive after paused, discovered necessary because Flutter's SchedulerBinding disables ALL frame scheduling on hidden/paused/detached and only re-enables on resumed/inactive — verified in packages/flutter/lib/src/scheduler/binding.dart:414-428"

patterns-established:
  - "Pattern: when a widget test needs to observe post-timer state after AppLifecycleState.paused without invoking the app's own `resumed` branch, deliver `inactive` (re-enables frame drawing, no app-level special case) rather than asserting immediately after `paused` (which can never observe a rendered frame in any implementation)"

requirements-completed: [LIVE-01, LIVE-02, G-03]

duration: 32min
completed: 2026-08-08
---

# Phase 23 Plan 05: G-03 Live Row Stranding Fix Summary

**Stopped cancelling the 1-minute timer on app pause (the single point of failure behind Dan's "had to refresh the browser" bug), added a `_isBackgrounded` guard so the 1-second fast timer still can't restart in the background, and added a build()-time self-heal as a second recovery layer.**

## Performance

- **Duration:** ~32 min
- **Started:** 2026-08-08T09:58:07-05:00 (plan read)
- **Completed:** 2026-08-08T10:16:32-05:00
- **Tasks:** 3 planned, all completed (with one mid-flight test-methodology correction, see Deviations)
- **Files modified:** 3

## Accomplishments

- Closed G-03: a `paused` lifecycle event with no matching `resumed` no longer permanently strands the live row — the 1-minute tick keeps firing and PreStart→Active still happens on its own.
- Proved the fix genuinely fixes something: the regression tests fail against the pre-fix handler (captured verbatim below) and pass against the fix, with the RED/GREEN cycle re-verified by hand (reverted `today_screen.dart` to its committed pre-fix state, re-ran the tests, restored the fix, re-ran again).
- The battery contract that motivated the 1-second fast timer is intact and asserted: it still cannot run while the app is backgrounded, now enforced by an explicit `_isBackgrounded` guard rather than relying solely on the timer having been cancelled.
- `23-UI-SPEC.md`'s tick-cost rule now describes the timer contract that actually ships, dated and tagged as an amendment rather than silently rewritten.
- Discovered and documented a genuine Flutter engine constraint — `SchedulerBinding` disables all frame scheduling while `hidden`/`paused`/`detached` and only re-enables it on `resumed`/`inactive` — that would otherwise make any widget test asserting rendered state immediately after `AppLifecycleState.paused` (with no further lifecycle event) unable to pass in ANY implementation, correct or buggy.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the G-03 regression tests FIRST and prove they fail (RED)** — `f3643c9` (test)
2. **Test methodology correction** (see Deviations) — `91e001c` (test)
3. **Task 2: Stop cancelling the minute tick on pause, guard fast tick, add self-heal (GREEN)** — `a76dcb7` (fix)
4. **Task 3: Amend the tick-cost rule in 23-UI-SPEC.md and run the full gate** — `4799ec8` (docs)

_No plan-metadata-only commit needed beyond Task 3's docs commit; STATE.md/ROADMAP.md updates land in the standard post-summary commit._

## Files Created/Modified

- `lib/screens/today/today_screen.dart` — `didChangeAppLifecycleState`'s `paused` branch no longer cancels `_nowTimer` (only `_fastTimer`); new `_isBackgrounded` field guards the `_syncFastTimer` call site in `build()`; a build()-time self-heal restarts `_nowTimer` if found dead.
- `test/screens/today_screen_now_state_test.dart` — new `G-03 timer resilience` group with two regression tests, proven to fail pre-fix and pass post-fix.
- `.planning/phases/23-live-activity-tracking/23-UI-SPEC.md` — amended the "Countdown granularity" tick-cost paragraph to state the coarse tick is deliberately not cancelled on pause, dated and tagged `Amended 2026-08-08 (UAT G-03)`.

## Decisions Made

- **Not cancelling `_nowTimer` on pause is the primary fix**, matching the plan's diagnosis: `resumed` was the only revival path anywhere in the file, so a missed/delayed `resumed` stranded the screen permanently. One wakeup a minute was already argued as negligible by the code's own pre-existing doc comment.
- **`_isBackgrounded` is a new, minimal field** rather than reusing any existing state, specifically because it needs to gate `_syncFastTimer`'s single call site in `build()` against a background rebuild driven by the now-surviving minute tick.
- **The build()-time self-heal is accepted as a secondary layer with a known gap**, per the plan-checker's residual finding: it only fires if some later `build()` happens, so a dead timer with zero subsequent rebuilds still would not revive on its own. Not over-engineered further (no `visibilitychange` listener, no `package:web` dependency) — that would be a larger change than this gap warrants.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Corrected the G-03 test methodology after discovering Flutter's SchedulerBinding disables frame scheduling on pause**

- **Found during:** Task 2 (implementing the GREEN fix and running the Task 1 tests against it)
- **Issue:** The original Task 1 tests (written exactly per the plan's literal spec) delivered `AppLifecycleState.paused` and then expected `find.byType(LiveRowCard)` / a `build()`-driven `nowCallCount` to reflect state changes, with no further lifecycle event. Debug instrumentation showed `build()` executing exactly once for the whole test — the periodic `Timer` DID fire and call `setState()` (confirmed via print), but no frame was ever drawn to observe it. Root cause, verified by reading `packages/flutter/lib/src/scheduler/binding.dart:414-428`: `SchedulerBinding.handleAppLifecycleStateChanged` disables ALL frame scheduling (`_setFramesEnabledState(false)`) on `hidden`/`paused`/`detached`, and only re-enables it (`_setFramesEnabledState(true)`) on `resumed`/`inactive`. `WidgetTester.pump()` gates its own frame draw behind `hasScheduledFrame`, which stays permanently false once `scheduleFrame()` starts no-op'ing. This is engine-level behavior — true in production exactly as in tests — and made the tests, as originally written, unobservable in ANY implementation, correct or buggy. It is not a flaw in the app's fix; it is a flaw in the literal test recipe.
- **Fix:** Both tests now deliver `AppLifecycleState.inactive` after `paused`, before observing anything. `inactive` re-enables frame scheduling at the engine level (Flutter groups it with `resumed` for that purpose) but `today_screen.dart`'s `didChangeAppLifecycleState` has no special case for `inactive` — it only branches on `resumed`/`paused` — so delivering it does NOT run the `resumed` branch's own explicit `_startNowTimer()` + `setState()`, which would otherwise mask the very bug under test by giving the screen a second, unrelated recovery path. This isolates exactly what the fix claims: a still-running minute tick alone, with no `resumed` callback ever delivered to the app, revives the screen.
- **Files modified:** `test/screens/today_screen_now_state_test.dart`
- **Verification:** Re-ran the full RED/GREEN cycle by hand after the correction: reverted `today_screen.dart` to its just-committed pre-fix state via `git checkout --`, ran `flutter test --plain-name 'G-03'` (both tests failed at the intended assertions — captured verbatim below), restored the fix, re-ran (`+2: All tests passed!`), then ran the full 461-test suite and `flutter analyze` clean.
- **Committed in:** `91e001c` (separate commit, landed between the original RED commit `f3643c9` and the GREEN commit `a76dcb7`, preserving the RED→GREEN sequence with a corrected RED)

---

**Total deviations:** 1 auto-fixed (1 blocking — test-harness methodology, not app logic)
**Impact on plan:** The app-level fix (Task 2) matches the plan exactly — no change to the architectural approach (still: don't cancel `_nowTimer` on pause, guard the fast timer, self-heal in `build()`). Only the *test delivery mechanism* for simulating "paused with no resume, but later observable" changed, and only because the literal mechanism specified in the plan cannot be observed in Flutter's widget-test harness at all, in any implementation. No scope creep.

## Verbatim Pre-Fix Failure Output (RED — the evidence the tests discriminate)

Captured by reverting `lib/screens/today/today_screen.dart` to its just-committed pre-fix state (`git checkout --`) and running:

```
export PATH="$PATH:/home/dan/development/flutter/bin"
flutter test test/screens/today_screen_now_state_test.dart --plain-name 'G-03'
```

```
00:00 +0: loading /home/dan/CodeProjects/canopy/test/screens/today_screen_now_state_test.dart
00:00 +0: G-03 timer resilience G-03: the minute tick still fires after a paused with no matching resumed
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TypeWidgetFinder:<Found 0 widgets with type "LiveRowCard": []>
   Which: means none were found but one was expected
G-03: a paused-without-resume must not permanently strand the screen — the minute tick must still
carry pre-start into active on its own, with no manual refresh required

When the exception was thrown, this was the stack:
#4      main.<anonymous closure>.<anonymous closure> (file:///home/dan/CodeProjects/canopy/test/screens/today_screen_now_state_test.dart:1746:9)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1952:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/dan/CodeProjects/canopy/test/screens/today_screen_now_state_test.dart line 1746
The test description was:
  G-03: the minute tick still fires after a paused with no matching resumed
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +0 -1: G-03 timer resilience G-03: the minute tick still fires after a paused with no matching resumed [E]
  Test failed. See exception logs above.
  The test description was: G-03: the minute tick still fires after a paused with no matching resumed
  
00:00 +0 -1: G-03 timer resilience G-03: the fast timer stays off while backgrounded but the minute tick survives
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a value greater than <0>
  Actual: <0>
   Which: is not a value greater than <0>
G-03: the coarse minute tick must survive a pause with no matching resume

When the exception was thrown, this was the stack:
#4      main.<anonymous closure>.<anonymous closure> (file:///home/dan/CodeProjects/canopy/test/screens/today_screen_now_state_test.dart:1830:9)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1952:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/dan/CodeProjects/canopy/test/screens/today_screen_now_state_test.dart line 1830
The test description was:
  G-03: the fast timer stays off while backgrounded but the minute tick survives
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +0 -2: G-03 timer resilience G-03: the fast timer stays off while backgrounded but the minute tick survives [E]
  Test failed. See exception logs above.
  The test description was: G-03: the fast timer stays off while backgrounded but the minute tick survives
  
00:00 +0 -2: Some tests failed.

Failing tests:
  /home/dan/CodeProjects/canopy/test/screens/today_screen_now_state_test.dart: G-03 timer resilience G-03: the fast timer stays off while backgrounded but the minute tick survives
  /home/dan/CodeProjects/canopy/test/screens/today_screen_now_state_test.dart: G-03 timer resilience G-03: the minute tick still fires after a paused with no matching resumed
```

Test A fails exactly where predicted (`LiveRowCard` findsNothing — the cancelled `_nowTimer` never fires). Test B fails exactly at its minute-tick-while-backgrounded assertion (count stays 0 because `_nowTimer` was cancelled by `paused` in the pre-fix code). After restoring the fix, both pass (`+2: All tests passed!`) and the full suite (461 tests) is green with `flutter analyze` clean.

## Issues Encountered

- The literal test recipe specified in the plan (deliver `paused`, advance the clock, assert on rendered widgets, with no further lifecycle event) turned out to be unobservable in Flutter's widget-test harness in any implementation — see Deviations above for the full root-cause and fix. This was caught by disciplined RED verification (the plan's own instruction to capture and inspect the pre-fix failure output), not assumed.

## Next Phase Readiness

- G-03 closed; the highest-priority UAT gap (the only outright defect Dan found) is resolved and pinned by a genuinely discriminating regression test.
- The `AppLifecycleState.inactive`-as-frame-enabler pattern discovered here is worth knowing about for any future lifecycle-related widget test in this codebase (documented inline in the test file's group-level comment).
- Remaining gaps from `23-UAT.md` (G-01, G-02, G-04 through G-07) are scoped to other plans in this phase per `23-GAP-ANALYSIS.md`'s priority ranking; not addressed here.

---
*Phase: 23-live-activity-tracking*
*Completed: 2026-08-08*

## Self-Check: PASSED

- FOUND: lib/screens/today/today_screen.dart
- FOUND: test/screens/today_screen_now_state_test.dart
- FOUND: .planning/phases/23-live-activity-tracking/23-UI-SPEC.md
- FOUND: .planning/phases/23-live-activity-tracking/23-05-SUMMARY.md
- FOUND commit: f3643c9 (test: add G-03 regression tests, proven RED)
- FOUND commit: 91e001c (test: fix G-03 test methodology)
- FOUND commit: a76dcb7 (fix: G-03 lifecycle handler fix)
- FOUND commit: 4799ec8 (docs: amend UI-SPEC tick-cost rule)
