---
phase: 16-priority-model-reconciliation
plan: 01
subsystem: testing
tags: [flutter, widget-test, priority-model, modal-bottom-sheet, scrollUntilVisible, Consumer-rebuild]

# Dependency graph
requires:
  - phase: 14-priority-chip-display
    provides: _PriorityChip widget with High/Low band thresholds
  - phase: 15-energy-scheduling
    provides: reorderAllWithPriority with linear-spread formula
provides:
  - PRIORITY-03 widget test: chip reflects fresh priorityWeight after reorder rebuild (no stale value)
  - GOALFORM-02 test group: true-modal-height reachability tests for all three goal types
affects: [any future GoalCard/GoalFormSheet changes, priority model refactors]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "scrollUntilVisible with find.byType(Scrollable).first targets the DraggableScrollableSheet scrollable (linked to form's SingleChildScrollView via shared scrollController)"
    - "Consumer<GoalsNotifier> rebuild test: pump slim Consumer wrapping Column(GoalCard), call reorderAllWithPriority, pumpAndSettle, then assert through widget tree (not pre-call references)"
    - "Modal pump: Builder captures BuildContext via pumpWithMood, then showModalBottomSheet (not awaited) + pumpAndSettle opens the sheet at true height"
    - "setViewport(tester, Size(390,844)) for true iPhone viewport; teardown auto-registered"

key-files:
  created:
    - test/screens/goal_card_priority_chip_rebuild_test.dart
  modified:
    - test/screens/goal_form_priority_test.dart

key-decisions:
  - "Use find.byType(Scrollable).first as scrollable arg to scrollUntilVisible — the research doc incorrectly specified find.byType(SingleChildScrollView), which fails because scrollUntilVisible casts the found widget to Scrollable. The DraggableScrollableSheet's scrollable is at index 0 and is linked to the form's scroll via the shared scrollController."
  - "goal_form_sheet.dart not modified — SingleChildScrollView already wraps the form, so the outcome-goal content (692px) scrolls cleanly within the 506px modal; no restructuring needed."
  - "Leaner _InMemoryGoalRepository (no lastSaved) used in PRIORITY-03 test; lastSaved variant reused from existing goal_form_priority_test.dart for GOALFORM-02 tests."

patterns-established:
  - "PRIORITY-03 pattern: assert chip state through Consumer rebuild tree after pumpAndSettle, never from pre-call Goal references"
  - "GOALFORM-02 pattern: _pumpModal helper encapsulates setViewport + pumpWithMood + showModalBottomSheet for reuse across 5 modal tests"

requirements-completed: [PRIORITY-03, GOALFORM-02]

# Metrics
duration: 25min
completed: 2026-06-13
---

# Phase 16 Plan 01: Priority Model Reconciliation Summary

**Widget tests locking priority chip rebuild correctness and goal-form modal reachability: PRIORITY-03 proves Consumer rebuilds atomically after reorderAllWithPriority; GOALFORM-02 replaces two deprecated setSurfaceSize tests with true-modal-height scroll tests covering all three goal types.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-13T23:08:00Z
- **Completed:** 2026-06-13T23:33:54Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified; no production files changed)

## Accomplishments

- PRIORITY-03: New test file `goal_card_priority_chip_rebuild_test.dart` with two widget tests proving the priority chip reflects the goal's current `priorityWeight` after `reorderAllWithPriority` — g0 drops its High chip when demoted to mid-list Normal, g1 gains the High chip, total High count stays at exactly 1 (no stale duplicate). No production code changed (D-01: position IS the priority model).
- GOALFORM-02: Replaced two deprecated `tester.binding.setSurfaceSize(800,1200)` tests with a 5-test `group('GOALFORM-02 — true modal height contract')` covering time-target, outcome, and habit goal types. Tests use `setViewport(390,844)` + `showModalBottomSheet` + `DraggableScrollableSheet(initialChildSize: 0.6)` at the true modal height (506px).
- Auto-fixed a research doc error: `scrollUntilVisible(scrollable: find.byType(SingleChildScrollView))` throws a type cast error at runtime — correct arg is `find.byType(Scrollable).first`.
- Full suite: 226 tests all pass. `flutter analyze` clean on all new/modified test files.

## Task Commits

1. **Task 1: PRIORITY-03 chip rebuild test** - `fb9130c` (test)
2. **Task 2: GOALFORM-02 modal-height scroll tests** - `c65e918` (feat)

## Files Created/Modified

- `test/screens/goal_card_priority_chip_rebuild_test.dart` — PRIORITY-03: two widget tests asserting chip rebuilds atomically after `reorderAllWithPriority` via Consumer<GoalsNotifier>
- `test/screens/goal_form_priority_test.dart` — GOALFORM-02: removed 2 setSurfaceSize tests, added 5 true-modal-height tests; added `import '../test_helpers/viewport.dart'`; 5 existing tests untouched

## Decisions Made

- Used `find.byType(Scrollable).first` instead of `find.byType(SingleChildScrollView)` as the `scrollable` arg to `scrollUntilVisible`. The research doc specified `SingleChildScrollView` but the flutter_test API internally casts the result to `Scrollable` — using the non-Scrollable type throws `_TypeError`. The `DraggableScrollableSheet`'s `_DraggableScrollableSheetScrollController` scrollable (index 0, vertical) is linked to the form's `SingleChildScrollView` via the shared `scrollController`, so scrolling index 0 scrolls the form.
- Did not modify `goal_form_sheet.dart`. `SingleChildScrollView` is already in place; the outcome goal's ~692px content scrolls within the 506px modal correctly. No restructuring needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] scrollUntilVisible scrollable arg type mismatch**
- **Found during:** Task 2 (GOALFORM-02 test execution)
- **Issue:** Research doc (16-RESEARCH.md §Pitfall 3 and §Code Examples) specified `scrollable: find.byType(SingleChildScrollView)` but `scrollUntilVisible` internally calls `widget<Scrollable>(scrollable!)` which casts the found widget to `Scrollable`. `SingleChildScrollView` is not `Scrollable`, causing `_TypeError: type 'SingleChildScrollView' is not a subtype of type 'Scrollable' in type cast`.
- **Fix:** Changed all `scrollable` args from `find.byType(SingleChildScrollView)` to `find.byType(Scrollable).first`. Verified via debug tests that index 0 is the `_DraggableScrollableSheetScrollController` (vertical/down) linked to the form's `SingleChildScrollView`.
- **Files modified:** `test/screens/goal_form_priority_test.dart`
- **Verification:** All 5 GOALFORM-02 tests pass; outcome test confirms real scrolling needed (ElevatedButton at y=1109px, viewport 844px, hitTestable=false before scroll).
- **Committed in:** `c65e918` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Fix was necessary for correctness. The research doc's scrollable type was incorrect for the flutter_test API version in use. No scope creep.

## Issues Encountered

- `scrollUntilVisible`'s `scrollable` parameter requires a finder that yields a `Scrollable` widget, not a container widget like `SingleChildScrollView`. Discovered by running the tests, diagnosed via debug test showing the scrollable tree structure. Resolved by using `find.byType(Scrollable).first`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- PRIORITY-03 and GOALFORM-02 requirements are locked behind automated regressions.
- Future changes to `GoalCard`, `GoalFormSheet`, or `GoalsNotifier.reorderAllWithPriority` will be caught by these tests if they introduce stale chips or clip the Save button.
- No blockers.

## Self-Check: PASSED

- `test/screens/goal_card_priority_chip_rebuild_test.dart` — FOUND
- `test/screens/goal_form_priority_test.dart` — FOUND (modified)
- Commit `fb9130c` — FOUND (git log)
- Commit `c65e918` — FOUND (git log)
- All 226 tests pass (`flutter test`)
- `flutter analyze` clean on modified files

---
*Phase: 16-priority-model-reconciliation*
*Completed: 2026-06-13*
