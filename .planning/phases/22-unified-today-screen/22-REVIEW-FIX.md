---
phase: 22-unified-today-screen
fixed_at: 2026-08-07T20:50:36Z
review_path: .planning/phases/22-unified-today-screen/22-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 22: Code Review Fix Report

**Fixed at:** 2026-08-07T20:50:36Z
**Source review:** .planning/phases/22-unified-today-screen/22-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope (critical + warning): 2
- Fixed: 2
- Skipped: 0

One additional out-of-scope Info finding (IN-01) was also applied as a
bonus fix — it was trivial, used an already-existing seam, and did not
perturb the test suite. It is reported separately below and does not
count toward the in-scope totals.

## Fixed Issues

### WR-01: AppBar "Start focus" still uses an ad-hoc first-unresolved-chunk scan, independent of `resolveNowState`

**Files modified:** `lib/screens/today/today_screen.dart`, `test/screens/today_screen_test.dart`
**Commit:** `8bb253a`
**Applied fix:** `_buildAppBar` now takes the already-computed `nowState` as
a parameter and derives the "Start focus" target with a `switch` over
`Active`/`Overdue`/`GapBeforeNext`/`PreStart`/`DayComplete` — the same
single detector `timeline.dart` renders from — instead of re-scanning
`schedule.chunks` for the first `!completed && !skipped` work chunk in
list order. When there is no meaningful target (`DayComplete`, or no
schedule at all), the button's `onPressed` is set to `null` (disabled)
rather than guessing.

Added a regression test group ("WR-01 — Start focus follows nowState, not
a list-order scan") with two tests:
1. A fixture with an earlier unresolved 8:00 chunk and a currently-Active
   10:45 chunk — the button must push the 10:45 chunk's id, not the stale
   8:00 one. Verified this test **fails against the pre-fix code** (by
   temporarily reverting `today_screen.dart` to the pre-fix version and
   re-running: the test failed with `Expected: 'focus-target:current'
   Actual: 'focus-target:stale'`), then restored the fix.
2. A `DayComplete` fixture asserting `IconButton.onPressed` is `null`.

Both new tests, plus the existing 23 tests in `today_screen_test.dart`,
pass against the fixed code (25/25).

### WR-02: Three `shouldShowEodCard` "trigger logic" tests never call the function under test

**Files modified:** `test/end_of_day_card_test.dart`
**Commit:** `330d20e`
**Applied fix:** Rewrote all three flagged tests (previously at
`test/end_of_day_card_test.dart:125-140`, `:142-159`, `:189-201`) to call
`shouldShowEodCard` through its existing injectable `now` seam instead of
recomputing the resolved/total ratio inline and asserting against the
test's own arithmetic. The third test (previously a near-duplicate
"empty work-chunk list, hour < 18" case) was repurposed to cover the
hour >= 18 "true" branch with a below-50%-resolved fixture — a branch the
old comments explicitly called out as untestable ("cannot control
DateTime.now().hour") even though the seam already made it testable.
Updated the group's leading NOTE comment to reflect that all six tests
in `shouldShowEodCard trigger logic` now exercise the function directly.

Making the tests real did **not** uncover a hidden bug — all six pass
against the existing (unmodified) `shouldShowEodCard` implementation.

## Info fix applied outside fix_scope (bonus, not counted above)

### IN-01: `_openAddEvent` bypasses the screen's injectable clock

**Files modified:** `lib/screens/today/today_screen.dart`
**Commit:** `1035339`
**Applied fix:** Changed `_openAddEvent`'s `final now = DateTime.now();` to
`final now = _nowFn();`, matching the clock-injection discipline used
elsewhere in the screen (header date, ticker, live-row remaining-time
calc). This is outside `fix_scope: critical_warning`, but the guidance
allowed applying it since it was a genuinely trivial one-line change
using an already-existing seam. Verified with the full test suite
(420/420 passing, `flutter analyze` clean) before committing — no test
was perturbed.

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-08-07T20:50:36Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
