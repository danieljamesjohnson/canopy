---
phase: 14-goals-screen-and-priority-end-to-end
plan: "01"
subsystem: goals-screen-ui
tags: [goals, priority, ui, drag-handle, chip]
dependency_graph:
  requires: []
  provides:
    - _PriorityChip widget in goal_card.dart
    - GoalsScreen heading (Your goals + subhead)
    - Icons.drag_indicator on desktop and mobile
    - reorderAllWithPriority wiring in onReorderItem
    - _buildFullOrderedIds helper on _GoalsScreenState
  affects:
    - lib/screens/goals/widgets/goal_card.dart
    - lib/screens/goals/goals_screen.dart
tech_stack:
  added: []
  patterns:
    - file-private _PriorityChip widget (no shared export, file-disjoint Wave 1 parallelism)
    - pumpWithMood with extraProviders for GoalsNotifier in heading test
    - _InMemoryGoalRepository (no Hive) for goals_screen_heading_test
key_files:
  created:
    - test/screens/goal_card_priority_chip_test.dart
    - test/screens/goals_screen_heading_test.dart
  modified:
    - lib/screens/goals/widgets/goal_card.dart
    - lib/screens/goals/goals_screen.dart
    - test/screens/goal_card_drag_handle_test.dart
decisions:
  - "labelMedium used for _PriorityChip label (12sp w600) per UI-SPEC §Typography table; PATTERNS.md snippet showed labelSmall but UI-SPEC typography table is authoritative — labelMedium wins"
  - "goals_screen_heading_test uses _InMemoryGoalRepository (same pattern as goals_notifier_priority_test and goal_form_priority_test); notifier.loadGoals() called before pumpWithMood so heading renders on first frame without waiting for addPostFrameCallback"
  - "No MouseRegion hover-brightening added to drag handle (explicitly OUT of scope per RESEARCH Open Questions RESOLVED)"
metrics:
  duration: "~3 minutes"
  completed: "2026-06-13"
  tasks: 2
  files: 5
---

# Phase 14 Plan 01: Goals Screen UI and Priority Chip Summary

GoalCard gains a `_PriorityChip` private widget and the Goals screen gains its "Your goals" heading, an always-visible `Icons.drag_indicator` drag handle on both desktop and mobile, and reorder-writes-priority wiring via `reorderAllWithPriority`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add _PriorityChip and priority chip to GoalCard | 3ef6b0a | goal_card.dart, goal_card_priority_chip_test.dart |
| 2 | GoalsScreen heading, drag_indicator (desktop+mobile), reorder-writes-priority | 53e42fb | goals_screen.dart, goal_card_drag_handle_test.dart, goals_screen_heading_test.dart |

## What Was Built

**Task 1 — _PriorityChip (GOALS-02):**
- Added `_PriorityChip extends StatelessWidget` at the bottom of `goal_card.dart` (file-private)
- Tier logic: `>= 0.75` → `Icons.arrow_upward` + `primaryContainer` chip + label "High"; `<= 0.25` → `Icons.arrow_downward` + `surfaceContainerHighest` chip + label "Low"; else → `SizedBox.shrink()`
- Integrated chip in secondary row: `showPriorityChip = (goal.priorityWeight ?? 0.5) != 0.5` guard; chip trails the secondary text in a Row
- No `GestureDetector` / `InkWell` on chip (display-only, Pitfall 4 avoided)
- Typography: `labelMedium` 12sp w600 (per UI-SPEC §Typography table — overrides PATTERNS.md snippet which showed `labelSmall`)

**Task 2 — GoalsScreen (GOALS-01):**
- Added heading `SliverToBoxAdapter` as first sliver in the non-empty branch: "Your goals" (`titleMedium` w600) + "Drag to prioritize. Tap to edit." (`bodySmall` `onSurfaceVariant`)
- Desktop drag handle: `Tooltip` → `ReorderableDelayedDragStartListener` → `Semantics` → `SizedBox(44×44)` → `Center` → `AnimatedOpacity(0.6)` → `Icon(Icons.drag_indicator, colorScheme.outline)`
- Mobile drag handle: `ReorderableDelayedDragStartListener` → `Semantics` → `Padding(horizontal:8)` → `Icon(Icons.drag_indicator, size:20, colorScheme.outlineVariant)` — always visible
- `onReorderItem` now calls `reorderAllWithPriority` via `_buildFullOrderedIds` (timeTarget → outcome → habit display order)
- `_buildFullOrderedIds` is a private method on `_GoalsScreenState` that reconstructs the flat ID list across all type groups

## Test Results

All 8 widget tests pass:

```
flutter test test/screens/goal_card_priority_chip_test.dart \
             test/screens/goal_card_drag_handle_test.dart \
             test/screens/goals_screen_heading_test.dart
→ All tests passed!
```

`flutter analyze` — zero new issues for `goals_screen.dart` and `goal_card.dart`.

## Decisions Made

1. **labelMedium vs labelSmall**: Used `labelMedium` 12sp w600 for `_PriorityChip` label. The PATTERNS.md verbatim snippet showed `labelSmall`, but the UI-SPEC §Typography table explicitly lists "Priority chip label" as `labelMedium` 12sp w600. UI-SPEC is authoritative.

2. **goals_screen_heading_test approach**: Used `_InMemoryGoalRepository` (same pattern as `goals_notifier_priority_test.dart` and `goal_form_priority_test.dart`) with `GoalsNotifier(repository: repo)` and `notifier.loadGoals()` called before `pumpWithMood`. This pre-seeds the notifier so the heading renders on first frame without depending on `addPostFrameCallback` timing. One `await tester.pump()` added after initial pump to settle the screen's own `addPostFrameCallback` call.

3. **Hover-brightening omitted**: The `AnimatedOpacity` on the desktop drag handle remains static at 0.6 — no `MouseRegion` added. Per RESEARCH §Open Questions RESOLVED, hover-brightening is explicitly out of scope for Phase 14.

## Deviations from Plan

None — plan executed exactly as written.

The one typography clarification (labelMedium vs labelSmall) was pre-documented in the plan's `<action>` block: "Per the Phase 14 planning guidance and UI-SPEC §Typography table, use `textTheme.labelMedium?.copyWith(...)` ... labelMedium is authoritative."

## Known Stubs

None. All implementation is complete for the GOALS-01 and GOALS-02 goal-card scope of this plan.

## Threat Flags

No new security-relevant surface introduced. Changes are pure UI (widget rendering) and a provider call (`reorderAllWithPriority` — already implemented and tested in Phase 11). No new network endpoints, auth paths, file access, or schema changes.

## Self-Check: PASSED

- `lib/screens/goals/widgets/goal_card.dart` — FOUND
- `lib/screens/goals/goals_screen.dart` — FOUND
- `test/screens/goal_card_priority_chip_test.dart` — FOUND
- `test/screens/goal_card_drag_handle_test.dart` — FOUND (modified)
- `test/screens/goals_screen_heading_test.dart` — FOUND
- Commit `3ef6b0a` (Task 1) — FOUND
- Commit `53e42fb` (Task 2) — FOUND
