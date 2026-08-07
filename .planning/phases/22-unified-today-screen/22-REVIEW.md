---
phase: 22-unified-today-screen
reviewed: 2026-08-07T21:15:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - lib/router.dart
  - lib/screens/today/today_screen.dart
  - lib/screens/today/now_state.dart
  - lib/screens/today/timeline.dart
  - lib/screens/today/widgets/live_row_card.dart
  - lib/screens/today/widgets/timeline_row_tile.dart
  - lib/screens/today/widgets/free_time_row.dart
  - lib/screens/today/widgets/breathing_pulse_cta.dart
  - lib/screens/today/widgets/end_of_day_card.dart
  - lib/screens/today/widgets/review_banner.dart
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/screens/schedule/widgets/swipeable_chunk_card.dart
  - lib/widgets/responsive_shell.dart
  - lib/utils/time_format.dart
  - test/screens/today_screen_test.dart
  - test/end_of_day_card_test.dart
  - test/screens/router_redirect_test.dart
  - test/screens/today_timeline_model_test.dart
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 22: Code Review Report

**Reviewed:** 2026-08-07T21:15:00Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** clean

## Summary

Iteration 2 re-review. Iteration 1 found 0 critical / 2 warning / 1 info; three
fix commits (`8bb253a`, `330d20e`, `1035339`) landed against those findings.
This pass re-examined the fixed code directly rather than trusting the fix
commits' own claims — including reverting `today_screen.dart` to its pre-fix
state and re-running the new regression tests against it to confirm they
actually discriminate. All three findings are resolved and none introduced a
new defect.

**WR-01 (Start focus ad-hoc scan) — verified resolved.**
`_buildAppBar` (`lib/screens/today/today_screen.dart:658-677`) now derives
`focusTarget` from a `switch` over the nullable, sealed `NowState`:
`Active → current`, `Overdue → overdue`, `GapBeforeNext → next`,
`PreStart → firstChunk`, `DayComplete → null`, `null → null`. This is a real
Dart exhaustiveness-checked switch over a sealed class (no `default` arm is
present or possible without the analyzer flagging missing cases), so there is
no silent-fallthrough risk. Each arm's choice is defensible:
- `Overdue → overdue` and `GapBeforeNext → next` both point at the chunk the
  live row / edge-state line is already showing as the day's current focus —
  consistent with the single-detector goal of this phase.
- `PreStart → firstChunk` lets a user start early, which matches what the old
  scan would also have picked (nothing is resolved yet before the day starts).
- `DayComplete`/`null` correctly disable the button (`onPressed: null`) rather
  than guessing at a target — confirmed via the DayComplete regression test.
- Traced `resolveNowState`'s advance-past-resolved loop
  (`now_state.dart:149-167`): `GapBeforeNext` can only be reached after
  skipping past `isCompleted`/`isSkipped` chunks, so an earlier *unresolved*
  chunk (the WR-01 bug scenario) can never hide behind a `GapBeforeNext`
  result — it would already have been selected as `Active`/`Overdue` instead.
  No arm reintroduces a first-unresolved-chunk scan.
- **Verified the regression tests actually discriminate, not just trusted the
  claim.** Checked out `today_screen.dart` at its pre-fix revision (`8bb253a^`)
  with the new test file kept, and ran `flutter test --plain-name "WR-01"`:
  both new tests fail against the old scan (the "stale" 8:00 unresolved chunk
  is picked over the 10:45 Active chunk; the DayComplete case pushes a
  non-null closure instead of disabling). Restored the fixed file afterward
  (`git diff` on the file is clean). These are genuine regression tests, not
  incidental passes.

**WR-02 (shouldShowEodCard tests didn't call the function) — verified
resolved.** All six tests in `test/end_of_day_card_test.dart`'s "trigger
logic" group now call `shouldShowEodCard(...)` through its injectable `now`
seam and assert on its return value, including a new true-branch case for
`hour >= 18` that was previously untested. Two tests (ratio ≥ 50%, exactly
50%) still compute the ratio inline as a documentation comment but *also*
assert `shouldShowEodCard(...)` directly — the inline arithmetic no longer
stands in for the real assertion. No hidden bug was uncovered by making the
tests real, consistent with the fix commit's claim; the implementation in
`end_of_day_card.dart:99-113` matches the tests' expectations exactly.

**IN-01 (`_openAddEvent` used `DateTime.now()` directly) — verified
resolved.** `today_screen.dart:619` now reads `_nowFn()`, consistent with the
rest of the screen's clock-injection discipline. Grepped the full reviewed
file set for `DateTime.now()`: the only remaining occurrences are the doc
comment in `now_state.dart:66` and the intentional default-parameter value
`now = DateTime.now` in `end_of_day_card.dart:101` (a function reference, not
a call, deliberately designed to be overridden in tests) — no stray direct
calls remain in the render path.

**Nothing else regressed.** Full suite (`flutter test`) is 420/420 green;
`flutter analyze` on the touched files reports no issues. Confirmed via diff
that only `today_screen.dart` and `test/end_of_day_card_test.dart` /
`test/screens/today_screen_test.dart` changed across the three fix commits —
no other file in the reviewed set was touched, so the route-reachability,
disposal/mounted-guard, and single-now-detector properties iteration 1
already verified for the rest of the screen are untouched and still hold.
Grepped for `DateTime.now()` and `firstOrNull`/`!c.isCompleted` scan patterns
across `lib/screens/today/` and the schedule-card widgets: no new competing
"now" detector was introduced anywhere.

All reviewed files meet quality standards. No issues found.

---

_Reviewed: 2026-08-07T21:15:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
