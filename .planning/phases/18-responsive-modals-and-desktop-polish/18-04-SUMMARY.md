---
phase: 18-responsive-modals-and-desktop-polish
plan: "04"
subsystem: ui
tags: [flutter, constrainedbox, align, responsive-layout, desktop-polish]

# Dependency graph
requires:
  - phase: 18-responsive-modals-and-desktop-polish
    plan: "02"
    provides: "goals_screen.dart with adaptive modal callers already in place"
provides:
  - "Home screen body (active-schedule + empty-state) constrained to 720dp via Align(topCenter)+ConstrainedBox"
  - "Goals screen CustomScrollView constrained to 720dp via Align(topCenter)+ConstrainedBox"
  - "Schedule screen ListView constrained to 720dp; ScheduleProgressBar remains full-width"
affects:
  - 18-05-polish-02-copy-fixes
  - any phase verifying POLISH-01

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Align(topCenter)+ConstrainedBox(maxWidth: 720) around Scaffold body content for desktop width constraint"
    - "ScheduleProgressBar stays full-width as Column sibling; only Expanded(ListView) is constrained"
    - "Empty-state body also gets 720dp constraint (same widget path the test exercises)"

key-files:
  created: []
  modified:
    - lib/screens/home/home_screen.dart
    - lib/screens/goals/goals_screen.dart
    - lib/screens/schedule/schedule_screen.dart

key-decisions:
  - "Wrap both active-schedule body and empty-state body in home_screen.dart — test pumps the empty-state path (hasScheduleToday=false), so both must carry the ConstrainedBox for the test to find it"
  - "Align(topCenter) used instead of Center to prevent short-content vertical floating"
  - "ScheduleProgressBar intentionally excluded from the 720dp constraint — full-width horizontal progress indicator follows Material 3 convention"

patterns-established:
  - "Primary screen body wrap pattern: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: <scrollable/column>))"
  - "Schedule split-constraint pattern: progress bar full-width in Column, only Expanded(ListView) is wrapped"

requirements-completed: [POLISH-01]

# Metrics
duration: 20min
completed: 2026-06-15
---

# Phase 18 Plan 04: Screen Width Constraints Summary

**Align(topCenter)+ConstrainedBox(maxWidth: 720dp) applied to Home, Goals, and Schedule screens — primary content no longer full-bleed at desktop widths**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-06-15T00:54:00Z
- **Completed:** 2026-06-15T01:14:02Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Home screen active-schedule body and empty-state body each wrapped in `Align(topCenter)+ConstrainedBox(maxWidth: 720)` — content columns no longer span full browser width at wide viewports
- Goals screen `Consumer<GoalsNotifier>` returns `CustomScrollView` wrapped in same pattern — the sole scrollable, no double-scroll
- Schedule screen `Expanded(ListView)` wrapped in `Align(topCenter)+ConstrainedBox(maxWidth: 720)` while `ScheduleProgressBar` remains the unconstrained full-width first child of the body Column
- `content_width_constraint_test.dart` Goals and Home cases turn GREEN; Schedule case remains skip:true (documented in Wave 0 test file, requires DailySchedule fixture)
- Full test suite: 254 passing, 1 skipped, 3 pre-existing RED tests for POLISH-02 (goal_form_copy_test.dart) — no regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: Constrain Home and Goals body content to 720dp** - `0433010` (feat)
2. **Task 2: Constrain Schedule chunk list to 720dp (progress bar stays full-width)** - `530fb59` (feat)

## Files Created/Modified
- `lib/screens/home/home_screen.dart` — active-schedule body Column and empty-state body Column each wrapped in Align(topCenter)+ConstrainedBox(maxWidth: 720)
- `lib/screens/goals/goals_screen.dart` — Consumer builder's returned CustomScrollView wrapped in Align(topCenter)+ConstrainedBox(maxWidth: 720)
- `lib/screens/schedule/schedule_screen.dart` — Expanded(ListView) wrapped in Align(topCenter)+ConstrainedBox(maxWidth: 720); ScheduleProgressBar unchanged

## Decisions Made

1. **Both home_screen bodies get the constraint.** The test file (`_pumpHomeScreenAt`) uses `hasScheduleToday == false` (empty-state path). The test comment says "The empty state still renders a Scaffold body that must be constrained at 720dp." To turn the test GREEN, both the active-schedule body and the empty-state body needed `ConstrainedBox(maxWidth: 720)`. The plan's research note that "the empty state has no visible effect at 720dp" remains true — the constraint is structurally present but visually no-op for the centered empty state.

2. **`Align(topCenter)` not `Center`.** Following 18-RESEARCH anti-pattern guidance — `Center` vertically centers short content, which floats it mid-screen on large viewports. `Align(topCenter)` keeps content top-aligned like normal scroll behavior.

3. **ScheduleProgressBar stays outside the constraint.** Per 18-RESEARCH §Open Questions #2 and 18-PATTERNS §schedule_screen.dart: the progress bar is a full-width horizontal indicator (Material 3 convention); only the chunk ListView is constrained.

## Deviations from Plan

**1. [Rule 2 - Missing Critical] Applied 720dp constraint to HomeScreen empty-state body in addition to active-schedule body**
- **Found during:** Task 1 (Constrain Home and Goals body content)
- **Issue:** The plan's note said "constrain active-schedule body only; empty state is already centered/narrow." However, the TDD test pumps the empty-state path (`hasScheduleToday == false`) and asserts a ConstrainedBox with maxWidth 720 exists. Without constraining the empty-state body, the Home test stays RED.
- **Fix:** Added `Align(topCenter)+ConstrainedBox(maxWidth: 720)` around the `_buildEmptyState` body Column as well. The constraint has no visible effect (the empty state is centered within a fixed horizontal padding of 32dp anyway) but satisfies the POLISH-01 test assertion.
- **Files modified:** `lib/screens/home/home_screen.dart`
- **Verification:** `content_width_constraint_test.dart` Home case GREEN; `flutter analyze` clean
- **Committed in:** `0433010`

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing constraint on empty-state body to satisfy TDD test)
**Impact on plan:** Minor scope extension (3 lines extra), no behavior change — the empty-state constraint is visually inert but required for correctness of the POLISH-01 test.

## Issues Encountered
- None beyond the deviation above.

## Known Stubs
None — all three screens wire directly to their existing data notifiers. No placeholder data or TODO comments introduced.

## Threat Flags
None — layout-only wrappers, no new network, auth, file access, or schema changes.

## Self-Check: PASSED
- [x] `lib/screens/home/home_screen.dart` exists with `maxWidth: 720`
- [x] `lib/screens/goals/goals_screen.dart` exists with `maxWidth: 720`
- [x] `lib/screens/schedule/schedule_screen.dart` exists with `maxWidth: 720`
- [x] Commit `0433010` found in git log
- [x] Commit `530fb59` found in git log
- [x] `content_width_constraint_test.dart` Goals + Home GREEN; Schedule skip:true

## Next Phase Readiness
- POLISH-01 is complete. Home, Schedule, and Goals are 720dp-constrained and top-centered at desktop widths. Phone widths (< 720dp) are unaffected.
- POLISH-02 copy label changes (goal_form_copy_test.dart, 3 RED tests) are the remaining open work in phase 18. Those tests were written in Wave 0 (18-01) as RED stubs for a future plan — they are pre-existing and not a regression from 18-04.
- `flutter test` suite is clean except for those 3 pre-existing POLISH-02 RED tests.

---
*Phase: 18-responsive-modals-and-desktop-polish*
*Completed: 2026-06-15*
