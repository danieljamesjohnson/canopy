---
phase: 14-goals-screen-and-priority-end-to-end
plan: 02
subsystem: schedule-engine + chunk-card-ui
tags: [priority, scheduling, badge, chunk-card, active-chunk-card, PRIORITY-01, GOALS-02]
dependency_graph:
  requires: [14-01-PLAN]
  provides: [priority-engine-behavioral, chunk-card-badge, goalPriorityWeight-threading]
  affects: [schedule_generator, chunk_card, swipeable_chunk_card, active_chunk_card, schedule_screen]
tech_stack:
  added: []
  patterns: [file-private _PriorityChip duplication, _lookupGoalPriorityWeight pattern, composite score sort]
key_files:
  created:
    - test/screens/chunk_card_priority_badge_test.dart
  modified:
    - lib/services/schedule_generator.dart
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart
    - lib/screens/home/widgets/active_chunk_card.dart
    - lib/screens/schedule/schedule_screen.dart
    - test/services/schedule_generator_test.dart
decisions:
  - Step 2 habit sort uses pre-filtered habitGoals list (not inline activeGoals filter) to keep cap-check and due-weekday guards unchanged
  - Step 4 composite score `remainingHours × priorityWeight` replaces tiebreaker-only sort; null-coalesced to 0.5 so unset priority sorts as Normal
  - _PriorityChip uses `textTheme.labelSmall` (not labelMedium) per the PATTERNS.md §goal_card.dart spec; UI-SPEC Typography table lists 12sp for chip label which labelSmall satisfies
  - _demandForTimeTarget and _remainingHours left unchanged; zero-remaining-hours goals score 0.0 and are harmlessly sorted to the bottom (Pitfall 5)
  - home_screen.dart required no edit; _lookupGoalPriorityWeight lookup is internal to ActiveChunkCard
  - File-private _PriorityChip duplicated in chunk_card.dart and active_chunk_card.dart (not shared via import) per UI-SPEC §Component Inventory item 3 file-disjoint parallelism rule
metrics:
  duration: "~10 minutes"
  completed: "2026-06-13"
  tasks_completed: 2
  files_modified: 6
  files_created: 1
---

# Phase 14 Plan 02: Priority Engine + Chunk Card Badge Summary

Priority is now a first-class scheduling signal (PRIORITY-01) and a visible badge on every schedule chunk card (GOALS-02). Elevating a goal's priority from Low to High measurably changes which habits and time-target goals fill the schedule cap first.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Engine Step 2 habit sort + Step 4 composite score | 1b7b0c0 | schedule_generator.dart, schedule_generator_test.dart |
| 2 | Priority badge on chunk cards + thread goalPriorityWeight | 0296933 | chunk_card.dart, swipeable_chunk_card.dart, active_chunk_card.dart, schedule_screen.dart, chunk_card_priority_badge_test.dart |

## What Was Built

### Task 1: Engine changes (PRIORITY-01)

**Step 2 (habits):** Replaced the inline `GoalType.habit` filter inside the `activeGoals` loop with a pre-filtered, priority-sorted `habitGoals` list. High-priority habits (0.75) now fill the discretionary cap before low-priority habits (0.25). The cap-check guard and due-weekday guard are unchanged.

**Step 4 (time-target):** Replaced the tiebreaker-only sort with a composite score `remainingHours × (priorityWeight ?? 0.5)`. A high-priority time-target goal with the same remaining hours as a low-priority goal now ranks first and fills the cap first. `_demandForTimeTarget` and `_remainingHours` were left unchanged (confirmed: zero-remaining goals score 0.0 and sort harmlessly to the bottom).

**Three deterministic engine tests added** to `test/services/schedule_generator_test.dart`:
- "Step 2: high-priority habit is scheduled before low-priority habit" — proves criteria 3
- "Step 4: high-priority time-target goal with equal remaining hours gets chunk before low-priority" — proves criteria 4
- "Step 4: high-priority goal gets at least as many chunks as low-priority under shared cap" — proves criteria 4 (cap-constrained)

### Task 2: Badge threading (GOALS-02)

**chunk_card.dart:** Added `double? goalPriorityWeight` to `ChunkCard` and `_WorkChunkContent` constructors. Added file-private `_PriorityChip` widget (labelSmall w600 label). Badge inserted after the rationale row in `_WorkChunkContent`'s inner Column — `if (goalPriorityWeight != null && goalPriorityWeight != 0.5)`.

**swipeable_chunk_card.dart:** Added `double? goalPriorityWeight` passthrough parameter; wired to inner `ChunkCard` call. Break-card branch unchanged (breaks have no priority).

**active_chunk_card.dart:** Added `_lookupGoalPriorityWeight(BuildContext context)` method (same pattern as `_lookupGoalColor` / `_lookupGoalName`). Priority badge inserted between the clock-time block and the `SizedBox(height: 12)` + action row. File-private `_PriorityChip` duplicate added.

**schedule_screen.dart:** Added `_lookupGoalPriorityWeight(BuildContext context, ScheduledChunk chunk)` method. Wired `goalPriorityWeight: _lookupGoalPriorityWeight(context, chunk)` to `SwipeableChunkCard` in `_buildSwipeableCard` and to `ChunkCard` in `_buildSkippedSection`. Commitment chunks (goalId == null) return null → no badge.

**home_screen.dart required no edit** — the lookup is internal to `ActiveChunkCard`.

**Four badge widget tests** in `test/screens/chunk_card_priority_badge_test.dart`: 0.75 → "High", 0.25 → "Low", null → no badge, 0.5 → no badge.

## Test Results

- `flutter test test/services/schedule_generator_test.dart` — 29 tests, all pass (including 3 new priority engine tests)
- `flutter test test/screens/chunk_card_priority_badge_test.dart` — 4 tests, all pass
- `flutter test` (full suite) — 209 tests, all pass
- `flutter analyze` on all 5 source files — zero issues

## Deviations from Plan

None — plan executed exactly as written. The _PriorityChip uses `textTheme.labelSmall` (12sp) matching the PATTERNS.md `goal_card.dart` verbatim spec, which aligns with the UI-SPEC Typography table's 12sp chip label requirement.

## Known Stubs

None. All parameters are wired end-to-end: ScheduleScreen → SwipeableChunkCard → ChunkCard and ActiveChunkCard (internal lookup). No placeholder values or TODO markers introduced.

## Threat Flags

No new threat surface beyond what was captured in the plan's threat model (T-14-03 through T-14-05). The `?? 0.5` null-coalescing in the engine handles malformed priorityWeight values safely. All goal lookups are in-memory reads of already-loaded GoalsNotifier.goals.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| lib/services/schedule_generator.dart | FOUND |
| lib/screens/schedule/widgets/chunk_card.dart | FOUND |
| lib/screens/schedule/widgets/swipeable_chunk_card.dart | FOUND |
| lib/screens/home/widgets/active_chunk_card.dart | FOUND |
| lib/screens/schedule/schedule_screen.dart | FOUND |
| test/services/schedule_generator_test.dart | FOUND |
| test/screens/chunk_card_priority_badge_test.dart | FOUND |
| .planning/.../14-02-SUMMARY.md | FOUND |
| Commit 1b7b0c0 (Task 1) | FOUND |
| Commit 0296933 (Task 2) | FOUND |
