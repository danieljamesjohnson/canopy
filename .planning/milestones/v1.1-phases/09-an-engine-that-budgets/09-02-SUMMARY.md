---
phase: 09-an-engine-that-budgets
plan: 02
subsystem: ui
tags: [flutter, material3, segmented-button, goal-form, priority]

# Dependency graph
requires:
  - phase: 09-an-engine-that-budgets
    provides: _priorityWeight state, save path, and initState load already present in goal_form_sheet.dart
provides:
  - SegmentedButton<double> priority control (Low/Normal/High → 0.25/0.5/0.75) in GoalFormSheet for all goal types
  - Widget test suite: 7 assertions covering render, default Normal, High→0.75 persistence, null legacy→Normal, visibility for all 3 types
affects: [09-03, ENGINE-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SegmentedButton<double> follows the in-file Slider label-then-control pattern (Row label → widget → SizedBox(height:16))"
    - "null-coalesce to default: selected: {_priorityWeight ?? 0.5} guards against empty selection set"

key-files:
  created:
    - test/screens/goal_form_priority_test.dart
  modified:
    - lib/screens/goals/goal_form_sheet.dart

key-decisions:
  - "Inserted priority control after name TextField + SizedBox(16), before type-specific block — visible for all goal types with no type guard"
  - "null coalesces to 0.5 (Normal) at display time; state stays null until user selects; save path writes null if user never touched it (existing behavior preserved)"
  - "Test uses setSurfaceSize(800, 1200) for the save-path test to avoid off-screen button hit-test failures in the 800x600 default canvas"

patterns-established:
  - "Goal form widget tests: pump GoalFormSheet directly (not via showModalBottomSheet) to keep widgets in the render tree; provide GoalsNotifier via ChangeNotifierProvider.value with InMemoryGoalRepository"

requirements-completed: [ENGINE-06]

# Metrics
duration: 25min
completed: 2026-06-11
---

# Phase 9 Plan 02: Priority Control Summary

**Material 3 SegmentedButton<double> (Low/Normal/High → 0.25/0.5/0.75) added to GoalFormSheet for all goal types, backed by existing _priorityWeight state and save path (ENGINE-06 UI half)**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-11T13:25:00Z
- **Completed:** 2026-06-11T13:49:42Z
- **Tasks:** 1 automated (task 2 is deferred manual UAT — see below)
- **Files modified:** 2

## Accomplishments

- `SegmentedButton<double>` with segments Low/Normal/High inserted at the correct location in `goal_form_sheet.dart` — after the goal name field, before type-specific fields, outside any type guard
- `selected: {_priorityWeight ?? 0.5}` null-coalesces legacy goals to Normal; `onSelectionChanged` writes `_priorityWeight = val.first` via existing setState pattern
- No new imports, no new state, no save-path changes — wired entirely to existing infrastructure
- 7-assertion widget test covers: render, default Normal, High→0.75 persistence, null legacy→Normal, visibility for Habit/Outcome/Time Target
- `flutter analyze` clean; all 118 tests pass

## Task Commits

1. **Task 1: Add Low/Normal/High SegmentedButton + widget test** — `80b1805` (feat)

## Files Created/Modified

- `lib/screens/goals/goal_form_sheet.dart` — inserted priority SegmentedButton block (16 lines) after name TextField
- `test/screens/goal_form_priority_test.dart` — new widget test file, 7 tests

## Decisions Made

- Insertion point: after `const SizedBox(height: 16)` that follows the name TextField, before `// Type-specific fields` comment block — matches the UI-SPEC approved placement
- Taller test canvas (`setSurfaceSize(800, 1200)`) used for save-path test to prevent "Add goal" button being off-screen in the default 800x600 test canvas
- Pumped form directly as `SingleChildScrollView` child (not via `showModalBottomSheet`) to keep full widget tree in bounds during tests

## Deviations from Plan

None — plan executed exactly as written. The insertion block matches the UI-SPEC.md approved contract verbatim.

## Issues Encountered

- Widget test discovery: `find.text('High').first` required because `SegmentedButton` internally renders the label `Text` widget multiple times (visible + semantics). Used `.first` to resolve ambiguity.
- Form canvas: default test canvas (800×600) caused "Add goal" button to render off-screen after GoalTypePicker + priority row extended the form height. Resolved with `tester.binding.setSurfaceSize(const Size(800, 1200))` + `addTearDown`.
- GoalTypePicker labels: picker uses full sentence titles ("I want to build a daily habit"), not short enum names ("Habit"). Tests updated to use full sentence strings.

## Manual UAT (deferred — no simulator on this host)

The on-device human-verify checkpoint (task 2 in the plan) cannot run on this headless Linux box. The automated widget tests serve as the primary verification. Manual UAT should be performed on an iOS or Android device/simulator when available:

1. Run the app: `/home/dan/development/flutter/bin/flutter run`
2. Open Goals → tap "+" to add a goal. Confirm a "Priority" label with Low / Normal / High segmented control appears under the name field, for each goal type.
3. Create a goal with priority High; reopen it via Edit and confirm "High" is still selected (persistence).
4. Open an older goal that predates this control and confirm it shows "Normal" selected (null → Normal).

**All automated success criteria are met. This UAT is informational; it does not block plan completion.**

## Next Phase Readiness

- ENGINE-06 UI half complete; `priorityWeight` is now user-editable and will be consumed by the engine (Plan 01) and end-to-end pass (Plan 03)
- No blockers for Plan 03

---
*Phase: 09-an-engine-that-budgets*
*Completed: 2026-06-11*
