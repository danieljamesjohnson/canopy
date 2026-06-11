---
phase: 11-honest-long-loop
plan: "02"
subsystem: quarterly-review
tags:
  - review
  - cold-launch
  - tdd
  - data-loading
  - priority
dependency_graph:
  requires:
    - "11-01 (DonutChart archivedGoals+commitmentBlocks params, GoalsNotifier.reorderAllWithPriority)"
  provides:
    - "REVIEW-03: QuarterlyReviewScreen cold-launch data loading (archived goals + commitment blocks)"
    - "REVIEW-02: AdjustmentsSection._finish() calls reorderAllWithPriority end-to-end"
  affects:
    - "lib/screens/quarterly_review/quarterly_review_screen.dart"
    - "lib/screens/quarterly_review/sections/adjustments_section.dart"
    - "test/screens/quarterly_review_test.dart"
tech_stack:
  added: []
  patterns:
    - "context.read before await (async safety — capture provider refs before first await)"
    - "Injectable CompletionLogRepository + QuarterlySnapshotRepository on StatefulWidget for test isolation"
    - "allLogs.isEmpty empty-state guard (data-independent of provider goal-list state)"
key_files:
  created: []
  modified:
    - lib/screens/quarterly_review/quarterly_review_screen.dart
    - lib/screens/quarterly_review/sections/adjustments_section.dart
    - lib/router.dart
    - test/screens/quarterly_review_test.dart
decisions:
  - "Injectable repositories (CompletionLogRepository + QuarterlySnapshotRepository) added to QuarterlyReviewScreen for test isolation — production defaults to Hive implementations"
  - "allLogs.isEmpty replaces (totalCompleted == 0 && goals.isEmpty) — guard is now independent of provider goal-list state"
  - "CommitmentsNotifier must be in provider tree for QuarterlyReviewScreen — already loaded at startup per main.dart"
metrics:
  duration: "6 minutes"
  completed: "2026-06-11"
  tasks: 2
  files: 4
---

# Phase 11 Plan 02: Screen Wiring + Cold-Launch Fix Summary

**One-liner:** `_loadData` loads archived goals + commitment blocks with provider refs captured before await, empty-state keyed on `allLogs.isEmpty`, and `_finish()` swapped to `reorderAllWithPriority` for priority write-back.

## What Was Built

### Task 1: RED Cold-Launch Regression Test (REVIEW-03)

**`test/screens/quarterly_review_test.dart`:**
- Added three in-memory test doubles: `_InMemoryGoalRepository`, `_InMemoryCommitmentBlockRepository`, `_InMemorySnapshotRepository`
- Added cold-launch `testWidgets` group pumping `QuarterlyReviewScreen` directly with in-memory providers seeded with one active goal ("Morning Run"), one archived goal ("Old Habit"), one commitment block ("Work"), and completion logs attributed to each
- Asserts `Morning Run`, `Old Habit (archived)`, and `Commitments` legend rows appear; `Not enough data yet` is absent
- Confirmed RED: "Old Habit (archived)" not found until Task 2 wired `_loadData`

**`lib/screens/quarterly_review/quarterly_review_screen.dart` (testability prerequisite):**
- Added optional `completionLogRepository` and `snapshotRepository` constructor params so the screen is testable without Hive initialisation
- Production usage unchanged (defaults to Hive implementations when params omitted)

**`lib/router.dart`:**
- Removed `const` from `QuarterlyReviewScreen()` call site (no longer a const constructor)

### Task 2: GREEN _loadData Fix + Adjustments Call-Site Swap (REVIEW-03, REVIEW-02)

**`lib/screens/quarterly_review/quarterly_review_screen.dart`:**
- Added imports: `commitment_block.dart`, `commitments_notifier.dart`
- Added state fields `_archivedGoals` and `_commitmentBlocks` (both initialised to empty lists)
- In `_loadData()`: capture `context.read<GoalsNotifier>()` and `context.read<CommitmentsNotifier>()` as local variables BEFORE the first `await` (async safety per Pitfall 6)
- After `allLogs` load: `await goalsNotifier.getArchivedGoals()` and `commitmentsNotifier.blocks` (sync, loaded at startup)
- Empty-state guard changed from `totalCompleted == 0 && goals.isEmpty` to `allLogs.isEmpty`
- `setState()` block assigns `_archivedGoals` and `_commitmentBlocks`
- `DataSection` call site passes `archivedGoals: _archivedGoals` and `commitmentBlocks: _commitmentBlocks` (removes Plan 01 stubs)

**`lib/screens/quarterly_review/sections/adjustments_section.dart`:**
- Swapped `await notifier.reorderAll(orderedIds)` → `await notifier.reorderAllWithPriority(orderedIds)` in `_finish()`
- No other changes (archive loop, snapshot construction, Navigator.pop unchanged)
- `ScheduleNotifier.generate()` intentionally NOT called (next-day pickup per REVIEW-02)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] QuarterlyReviewScreen not testable without Hive**
- **Found during:** Task 1 — writing the cold-launch test
- **Issue:** `_loadData()` hardcoded `HiveCompletionLogRepository()` and `HiveQuarterlySnapshotRepository()`. Without Hive initialised, pumping `QuarterlyReviewScreen` in a test threw exceptions rather than failing assertions (can't write a proper RED test).
- **Fix:** Added optional `completionLogRepository` and `snapshotRepository` constructor params. Production usage unchanged (defaults to Hive). Router.dart `const QuarterlyReviewScreen()` → `QuarterlyReviewScreen()`.
- **Files modified:** `lib/screens/quarterly_review/quarterly_review_screen.dart`, `lib/router.dart`
- **Commit:** 8c290f8

## Known Stubs

None — the Plan 01 stubs (`archivedGoals: const []`, `commitmentBlocks: const []`) are fully wired in this plan.

## Verification Results

- `flutter test test/screens/quarterly_review_test.dart` — 19/19 pass (cold-launch test + all prior review tests green)
- `flutter test` — 158/158 pass (full suite, no regressions)
- `flutter analyze` — 0 errors, 0 warnings (5 pre-existing info-level `onReorder` deprecation notices, all pre-existing)
- `dart format lib/` — no diff after formatting

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Changes are confined to in-process read paths (loading existing Hive data) and the existing write path (`reorderAllWithPriority` was already implemented in Plan 01). T-11-04, T-11-05, T-11-06 mitigations all applied as planned.

## Self-Check: PASSED
