---
phase: 02-goals-and-commitments
plan: 03
subsystem: ui
tags: [flutter, goals, widgets, draggable-sheet, reorderable-list, provider]

dependency_graph:
  requires:
    - phase: 02-02
      provides: GoalsNotifier with loadGoals, saveGoal, archiveGoal, reorder, autoColor, getArchivedGoals
  provides:
    - GoalCard widget with colored left border, type icon, secondary stat
    - GoalTypePicker widget with three plain-language type cards
    - GoalsScreen with CustomScrollView three-section layout and FAB
    - GoalFormSheet DraggableScrollableSheet for add/edit/archive
    - ArchivedGoalsScreen read-only list
    - /goals/archived route in go_router
  affects: [04-commitments-ui, 05-onboarding-ui]

tech-stack:
  added: []
  patterns:
    - DraggableScrollableSheet wrapped in showModalBottomSheet for form sheets
    - ReorderableListView.builder with buildDefaultDragHandles: false inside SliverToBoxAdapter
    - WidgetsBinding.instance.addPostFrameCallback for safe initState provider reads
    - Plain-language goal type labels — GoalType enum values never shown in UI

key-files:
  created:
    - lib/screens/goals/widgets/goal_card.dart
    - lib/screens/goals/widgets/goal_type_picker.dart
    - lib/screens/goals/goal_form_sheet.dart
    - lib/screens/goals/archived_goals_screen.dart
  modified:
    - lib/screens/goals/goals_screen.dart
    - lib/router.dart

key-decisions:
  - "DraggableScrollableSheet constructed inline in showModalBottomSheet builder so scrollController flows correctly to GoalFormSheet.scrollController"
  - "Type-specific fields (weeklyHourBudget, deadline, frequencyPerWeek) reset to null when GoalType changes in form sheet to avoid stale cross-type data"
  - "/goals/archived added as child route of /goals inside StatefulShellBranch (not a top-level route) so shell nav bar remains visible"

patterns-established:
  - "Plain-language type labels: GoalType.timeTarget='Regular time', GoalType.outcome='Working toward', GoalType.habit='Daily habits'"
  - "GoalTypePicker description strings: never use GoalType.name or .toString(); all labels are hardcoded plain English"
  - "hexToColor(String hex) helper in goal_card.dart converts '#RRGGBB' to Flutter Color"

requirements-completed: [goal-types]

duration: 2min
completed: 2026-02-26
---

# Phase 02 Plan 03: Goals UI Summary

**Goals list with three plain-language sections, DraggableScrollableSheet add/edit form, archive flow, and GoalCard/GoalTypePicker reusable widgets — zero GoalType enum labels exposed in UI.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-26T13:05:12Z
- **Completed:** 2026-02-26T13:07:46Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- GoalCard and GoalTypePicker reusable widgets with plain-language labels and no enum exposure
- GoalsScreen: CustomScrollView with three SliverToBoxAdapter sections (Regular time, Working toward, Daily habits), drag-reorder within groups, FAB
- GoalFormSheet: DraggableScrollableSheet with scrollController, add/edit/archive mode, type-specific fields
- ArchivedGoalsScreen and /goals/archived child route wired into go_router

## Task Commits

Each task was committed atomically:

1. **Task 1: Create GoalCard and GoalTypePicker reusable widgets** - `e02ab2a` (feat)
2. **Task 2: Build GoalsScreen, GoalFormSheet, ArchivedGoalsScreen, router** - `3473834` (feat)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified

- `lib/screens/goals/widgets/goal_card.dart` - GoalCard with colored left border, type icon, name, optional secondary stat; hexToColor helper
- `lib/screens/goals/widgets/goal_type_picker.dart` - GoalTypePicker vertical card stack; _TypeCard with selected/unselected highlight
- `lib/screens/goals/goals_screen.dart` - GoalsScreen StatefulWidget; CustomScrollView + ReorderableListView sections; empty state; FAB
- `lib/screens/goals/goal_form_sheet.dart` - GoalFormSheet StatefulWidget; DraggableScrollableSheet consumer; add/edit/archive mode; type-specific fields
- `lib/screens/goals/archived_goals_screen.dart` - ArchivedGoalsScreen; postFrameCallback load; empty state
- `lib/router.dart` - /goals/archived child route added inside Goals StatefulShellBranch

## Decisions Made

- DraggableScrollableSheet constructed inline in `showModalBottomSheet` builder so `scrollController` flows directly to `GoalFormSheet.scrollController` — no intermediate controller.
- Type-specific fields (`weeklyHourBudget`, `deadline`, `frequencyPerWeek`) reset to null when GoalType changes in form sheet, preventing stale cross-type data from persisting.
- `/goals/archived` added as a child route of `/goals` inside the `StatefulShellBranch` so the bottom navigation bar remains visible on the archived screen.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Lint] Fixed null-aware element syntax in GoalCard**
- **Found during:** Task 1 (GoalCard widget)
- **Issue:** `if (trailing != null) trailing!` triggered `use_null_aware_elements` lint warning
- **Fix:** Replaced with `?trailing` spread syntax
- **Files modified:** `lib/screens/goals/widgets/goal_card.dart`
- **Verification:** `flutter analyze lib/screens/goals/widgets/` — zero issues
- **Committed in:** `e02ab2a` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 lint)
**Impact on plan:** Minor lint compliance fix. No scope creep.

## Issues Encountered

None — both tasks executed cleanly.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Goals UI fully functional: list, add, edit, archive, reorder, archived view
- GoalsNotifier is the single state source; all UI reads via `context.watch<GoalsNotifier>()` / `context.read<GoalsNotifier>()`
- Plan 04 can build CommitmentsScreen and add the `/commitments` top-level route to router.dart

---
*Phase: 02-goals-and-commitments*
*Completed: 2026-02-26*

## Self-Check: PASSED

All 7 files verified present. Both task commits (e02ab2a, 3473834) confirmed in git log.
