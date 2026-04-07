---
phase: 05-quarterly-review
plan: "01"
subsystem: quarterly-review-data
tags: [aggregation, hive, data-models, unit-tests, charting]
dependency_graph:
  requires: [completion_log.dart, quarterly_snapshot.dart, goals_notifier.dart]
  provides: [QuarterlyAggregationService, expanded-QuarterlySnapshot, GoalsNotifier.reorderAll, fl_chart]
  affects: [05-02, 05-03, 05-04]
tech_stack:
  added: [fl_chart ^1.2.0]
  patterns: [pure-Dart service class, TDD red-green, Hive additive field extension]
key_files:
  created:
    - lib/services/quarterly_aggregation_service.dart
    - test/services/quarterly_aggregation_test.dart
  modified:
    - pubspec.yaml
    - lib/data/models/quarterly_snapshot.dart
    - lib/data/models/quarterly_snapshot.g.dart
    - lib/providers/goals_notifier.dart
decisions:
  - "String.compareTo() used for YYYY-MM-DD range filtering instead of >= operator (Dart does not define >= for String)"
  - "isInReviewWindow window: 7 days before 90-day mark through 30 days after, per D-12"
  - "QuarterlyAggregationService has no Flutter imports — fully testable as plain Dart unit tests"
metrics:
  duration: "8 minutes"
  completed: "2026-04-07"
  tasks: 1
  files: 6
---

# Phase 05 Plan 01: Data Foundation — Aggregation Service and Expanded Model Summary

**One-liner:** Pure-Dart QuarterlyAggregationService with 6 aggregation methods, QuarterlySnapshot extended with goalPrioritySnapshot/archivedGoalIds HiveFields, GoalsNotifier.reorderAll, and fl_chart dependency added.

## What Was Built

### QuarterlyAggregationService (`lib/services/quarterly_aggregation_service.dart`)

Pure-Dart class (no Flutter imports) with six methods:

- `completedByGoal(logs, startYmd, endYmd)` — `Map<String, int>` of completed events per goalId in date range
- `completedByWeek(logs, startYmd, endYmd)` — `Map<String, int>` of completed events per ISO Monday date key
- `notSpentCount(logs, startYmd, endYmd)` — count of skipped + deferred logs in range
- `totalCompleted(logs, startYmd, endYmd)` — total completed count in range
- `isInReviewWindow({latestSnapshot, allLogs, now})` — true when now is within 7 days before the 90-day mark through 30 days after; falls back to earliest log date when no snapshot exists
- `completionRateByGoal(logs, startYmd, endYmd)` — `Map<String, double>` of completed / total events per goal

### QuarterlySnapshot Model Extensions

Added two new Hive fields (additive, backward-compatible):

- `@HiveField(6) Map<String, int> goalPrioritySnapshot = {}` — goalId -> sortOrder captured at review time
- `@HiveField(7) List<String> archivedGoalIds = []` — goals archived during this review

TypeAdapter regenerated via build_runner: `quarterly_snapshot.g.dart` now writes 8 fields.

### GoalsNotifier.reorderAll

Added `Future<void> reorderAll(List<String> orderedGoalIds)` to `lib/providers/goals_notifier.dart`. Sets sortOrder = index position for each goal found in the provided ordered list, saves, then calls loadGoals(). Enables cross-type priority reordering required by the quarterly review priority adjustment UI.

### fl_chart Dependency

Added `fl_chart: ^1.2.0` to `pubspec.yaml`. Resolved to `fl_chart 1.2.0`.

## Tests

15 unit tests in `test/services/quarterly_aggregation_test.dart` — all pass.

Coverage:
- completedByGoal: range filtering, skipped events not counted, empty logs
- completedByWeek: Monday bucketing, skipped/deferred exclusion
- notSpentCount: range filtering
- totalCompleted: basic count
- isInReviewWindow: within window, outside window, log fallback, no-data false, post-mark window
- completionRateByGoal: rate calculation, empty logs

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] String comparison operators not available in Dart**
- **Found during:** Task 1 GREEN phase
- **Issue:** `l.dateYmd >= startYmd` fails to compile — Dart does not define `>=`/`<=` for `String`
- **Fix:** Replaced with `l.dateYmd.compareTo(startYmd) >= 0 && l.dateYmd.compareTo(endYmd) <= 0`
- **Files modified:** `lib/services/quarterly_aggregation_service.dart`
- **Commit:** f3ab513

## Self-Check

### Files exist

- `lib/services/quarterly_aggregation_service.dart` — FOUND
- `lib/data/models/quarterly_snapshot.dart` — FOUND (HiveField 6 and 7 present)
- `lib/data/models/quarterly_snapshot.g.dart` — FOUND (goalPrioritySnapshot in generated code)
- `lib/providers/goals_notifier.dart` — FOUND (reorderAll present)
- `test/services/quarterly_aggregation_test.dart` — FOUND (260 lines, 15 tests)
- `pubspec.yaml` — FOUND (fl_chart: ^1.2.0)

### Commits exist

- `2575bd5` — test(05-01): add failing tests for QuarterlyAggregationService
- `f3ab513` — feat(05-01): QuarterlyAggregationService, expanded model, reorderAll, fl_chart

## Self-Check: PASSED
