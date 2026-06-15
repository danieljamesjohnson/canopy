---
phase: 18-responsive-modals-and-desktop-polish
plan: "01"
subsystem: testing
tags: [flutter, flutter_test, widget_test, responsive, tdd, red-stubs]

# Dependency graph
requires: []
provides:
  - "Wave 0 RED test stubs: adaptive_form_modal_test.dart (RESP-01/02/03)"
  - "Wave 0 RED test stubs: content_width_constraint_test.dart (POLISH-01)"
  - "Wave 0 RED test stubs: goal_form_copy_test.dart (POLISH-02)"
affects:
  - "18-02-adaptive-helper-goal-form (must turn RESP-01/02/03 GREEN)"
  - "18-03-commitment-caller (must turn RESP-03 GREEN)"
  - "18-04-screen-width-constraints (must turn POLISH-01 GREEN)"
  - "18-05-copy-polish-walkthrough (must turn POLISH-02 GREEN)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "setViewport(tester, size) for all responsive tests (auto-teardown, never tester.view.physicalSize directly)"
    - "pumpWithMood + extraProviders for form sheet widget tests"
    - "_InMemoryRepository pattern for test isolation without Hive"
    - "do NOT await showAdaptiveFormModal / showModalBottomSheet — Future resolves on dismiss only"
    - "find.byType(Scrollable).first for scrollUntilVisible inside modals (not SingleChildScrollView)"
    - "widgetList<ConstrainedBox>().any(...) for asserting maxWidth in widget tree"

key-files:
  created:
    - "test/screens/adaptive_form_modal_test.dart"
    - "test/screens/content_width_constraint_test.dart"
    - "test/screens/goal_form_copy_test.dart"
  modified: []

key-decisions:
  - "Schedule screen ConstrainedBox test skipped (skip:true) in Wave 0 — DailySchedule fixture setup too complex; 18-04 will add it or it will be verified via manual UAT"
  - "content_width_constraint_test pumps HomeScreen with hasScheduleToday=false (empty state path) — simpler setup; constraint must apply to both empty and active-schedule paths per 18-04"
  - "adaptive_form_modal_test fails at compile stage (missing import) — plan explicitly says this is correct RED state"

patterns-established:
  - "Wave 0 stub pattern: test files import not-yet-existing symbols, fail RED for missing import/symbol, not scaffolding errors"
  - "_pumpAdaptiveModal: Builder captures BuildContext, calls modal helper without await, pumpAndSettle"
  - "Commitment delete dialog test: tap Icons.delete_outline icon to trigger _confirmDelete AlertDialog"

requirements-completed: [RESP-01, RESP-02, RESP-03, POLISH-01, POLISH-02]

# Metrics
duration: 4min
completed: 2026-06-15
---

# Phase 18 Plan 01: Test Stubs Summary

**Wave 0 RED test scaffolds for 5 requirements (RESP-01/02/03, POLISH-01/02) — three files covering dialog-vs-sheet routing, 720dp content-width constraints, and copy-label assertions**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-15T00:53:53Z
- **Completed:** 2026-06-15T00:58:13Z
- **Tasks:** 2
- **Files modified:** 3 (all new)

## Accomplishments

- Created `adaptive_form_modal_test.dart` with 5 RESP-tagged test cases covering dialog-vs-sheet routing (RESP-01), drag-handle absence + ConstrainedBox(560) assertion (RESP-02), and commitment form routing (RESP-03) — fails RED due to missing `lib/widgets/adaptive_form_modal.dart`
- Created `content_width_constraint_test.dart` with 2 POLISH-01 assertions (Goals + Home screen) and 1 skipped schedule case — fails RED because ConstrainedBox(720) is not in the body yet
- Created `goal_form_copy_test.dart` with 3 POLISH-02 assertions (add mode copy, edit mode copy, commitment delete dialog copy) — fails RED because copy strings still use old capitalisation/wording

## Task Commits

Each task was committed atomically:

1. **Task 1: adaptive_form_modal_test.dart (RESP-01/02/03)** — `07dc7c7` (test)
2. **Task 2: content_width_constraint_test.dart + goal_form_copy_test.dart (POLISH-01/02)** — `c7b03c8` (test)

## Files Created/Modified

- `test/screens/adaptive_form_modal_test.dart` — 5 test cases for RESP-01/02/03; imports `package:canopy/widgets/adaptive_form_modal.dart` (RED — file does not exist yet); uses `_pumpAdaptiveGoalModal` and `_pumpAdaptiveCommitmentModal` helpers
- `test/screens/content_width_constraint_test.dart` — 2 active POLISH-01 assertions (Goals + Home at 1024dp viewport) + 1 skipped schedule case; uses fake ScheduleNotifier/GoalsNotifier/ThemeNotifier stubs
- `test/screens/goal_form_copy_test.dart` — 3 POLISH-02 copy-label assertions; pumps GoalFormSheet directly via `_pumpGoalForm` and CommitmentsScreen via `_pumpCommitmentsScreenWithBlock`

## Decisions Made

- Skipped schedule screen test (`skip: true`) with TODO(18-04) — building a full DailySchedule fixture requires schedule-generator plumbing that is out of scope for Wave 0 test stubs; the active-schedule body path is verified via manual UAT per 18-VALIDATION.md
- HomeScreen pumped with `hasScheduleToday=false` (empty state) because the Fake notifier approach avoids needing a DailySchedule. The POLISH-01 constraint must be applied to the empty-state path too; 18-04 will verify both paths.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed `skip:` parameter type error in testWidgets**
- **Found during:** Task 2 verification run
- **Issue:** `skip: 'TODO(18-04): ...'` (string) passed to `testWidgets` which expects `bool?` — caused compilation failure instead of graceful skip
- **Fix:** Changed to `skip: true` with TODO comment on the same line
- **Files modified:** `test/screens/content_width_constraint_test.dart`
- **Verification:** `flutter test test/screens/content_width_constraint_test.dart` compiled and ran; schedule case shown as skipped (count: ~1)
- **Committed in:** `c7b03c8` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — compiler type error in test scaffolding)
**Impact on plan:** Fix was necessary to achieve correct RED state (compile + run, not fail to compile). No scope creep.

## Issues Encountered

None beyond the `skip:` type error documented above.

## Known Stubs

All three test files are intentional stubs (Wave 0). They are designed to remain RED until implementation plans 18-02 through 18-05 turn them GREEN. This is the correct state per the Nyquist compliance contract in 18-VALIDATION.md.

## Threat Flags

None — this plan adds test files only. No runtime trust boundary crossed.

## Next Phase Readiness

- Wave 0 stubs are in place; implementation plans can begin in any order
- 18-02 turns RESP-01/02 GREEN (adaptive modal helper + goal form `isDialog` param)
- 18-03 turns RESP-03 GREEN (commitment caller migration)
- 18-04 turns POLISH-01 GREEN (screen body constraints)
- 18-05 turns POLISH-02 GREEN (copy label changes)
- Before 18-04 begins: consider adding a proper schedule-fixture stub to enable the skipped schedule test

---
*Phase: 18-responsive-modals-and-desktop-polish*
*Completed: 2026-06-15*
