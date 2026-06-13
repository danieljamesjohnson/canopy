---
phase: 09-an-engine-that-budgets
plan: 03
subsystem: scheduling
tags: [dart, flutter, schedule-engine, completion-log, streak, lighter-day, tdd, unit-test]

# Dependency graph
requires:
  - phase: 09-an-engine-that-budgets
    plan: 01
    provides: "ScheduleGeneratorService.computeDueWeekdays / computeStreak public static helpers; generate() with completionLogs + lighterDay params"

provides:
  - "ScheduleNotifier.generateToday() with lighterDay param + per-goal log fetch"
  - "GoalRepository injection into ScheduleNotifier"
  - "Streak write-back in markComplete/markSkipped via ScheduleGeneratorService.computeStreak + GoalRepository.save"
  - "lighter-day toggle visible for all moods in checkin_screen.dart"
  - "ENGINE-03b + ENGINE-05 notifier-level tests (3 tests)"

affects:
  - "Phase 10 (close/deferral) — will consume the revert pattern established here"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GoalRepository injected into ScheduleNotifier following existing DailyScheduleRepository / CompletionLogRepository injectable-repo pattern"
    - "Per-goal getByGoalId fetch in generateToday — never getAll (T-09-08/T-09-09)"
    - "Streak write-back inside existing try block (WR-05): revert flag on persistence failure"
    - "Non-empty goalId UUID guard before GoalRepository.getById (T-09-08)"

key-files:
  created:
    - test/providers/schedule_notifier_engine_test.dart
  modified:
    - lib/providers/schedule_notifier.dart
    - lib/screens/schedule/checkin_screen.dart
    - test/screens/cold_launch_morning_loop_test.dart

key-decisions:
  - "Streak write-back placed inside existing try block (after _logRepo.append) so the revert catch covers it — a failed GoalRepository.save reverts chunk.isCompleted/isSkipped"
  - "Non-empty UUID guard (chunk.goalId != null && chunk.goalId!.isNotEmpty) prevents commitment chunks (goalId='') from triggering getByGoalId calls"
  - "getByGoalId called AFTER _logRepo.append so the just-appended entry is included in the streak computation"
  - "cold_launch_morning_loop_test.dart override updated to include lighterDay param (Rule 1 auto-fix)"
  - "Test date 2026-06-08 chosen (verified Monday, weekday=1); prior due-day logs use 2026-06-03 (Wed) and 2026-06-05 (Fri)"

patterns-established:
  - "Streak write-back call path: _goalRepo.getById(goalId) → computeDueWeekdays(freq) → _logRepo.getByGoalId(id) → computeStreak → goal.streakCount = streak → _goalRepo.save(goal)"

requirements-completed: [ENGINE-03, ENGINE-05, ENGINE-06]

# Metrics
duration: 5min
completed: 2026-06-11
---

# Phase 09 Plan 03: Streak Write-Back and Lighter-Day Plumbing Summary

**GoalRepository injected into ScheduleNotifier; generateToday fetches logs per goal and threads lighterDay into generate(); markComplete/markSkipped recompute and persist streakCount; lighter-day toggle now visible for all moods**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-06-11T13:54:11Z
- **Completed:** 2026-06-11T13:58:23Z
- **Tasks:** 2
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- Added `GoalRepository? goalRepo` constructor param to `ScheduleNotifier`; defaults to `HiveGoalRepository()`
- Added `bool lighterDay = true` to `generateToday()`; builds `allLogs` via per-goal `getByGoalId` loop and passes `completionLogs: allLogs, lighterDay: lighterDay` into `generate()`
- Added streak write-back in both `markComplete` and `markSkipped`: non-empty UUID guard, `_goalRepo.getById`, `computeDueWeekdays`, `computeStreak` (including just-appended log entry), `goal.streakCount = streak`, `_goalRepo.save` — all inside the existing `try` block so WR-05 revert covers it
- Changed toggle visibility in `checkin_screen.dart` from `_selectedMood! <= 2` to `_selectedMood != null` (visible for all moods once selected)
- Added `lighterDay: _lighterDay` to the `generateToday()` call in `checkin_screen.dart`
- Created `test/providers/schedule_notifier_engine_test.dart` with 3 tests: ENGINE-05 (lighterDay reduces chunk count), ENGINE-03b completion (streak increments), ENGINE-03b skip (streak resets to 0)
- All 121 tests pass; `flutter analyze` clean (5 pre-existing info-level `onReorder` deprecations in unrelated files)

## Final generateToday Signature

```dart
Future<void> generateToday({
  required int moodIndex,
  required List<Goal> goals,
  required List<CommitmentBlock> blocks,
  bool lighterDay = true,
}) async {
  // ... fetch logs per active goal via getByGoalId ...
  // ... call _generator.generate(completionLogs: allLogs, lighterDay: lighterDay) ...
}
```

## Streak Write-Back Call Path

```
markComplete/markSkipped
  └─ (inside existing try block, after _logRepo.append)
      └─ if (chunk.goalId != null && chunk.goalId!.isNotEmpty)
          └─ _goalRepo.getById(chunk.goalId!)
              └─ if (goal != null && goal.goalType == GoalType.habit)
                  └─ due = ScheduleGeneratorService.computeDueWeekdays(freq)
                  └─ logs = _logRepo.getByGoalId(goal.id)   // includes just-appended entry
                  └─ goal.streakCount = ScheduleGeneratorService.computeStreak(id, due, logs)
                  └─ _goalRepo.save(goal)
  └─ catch (_) { chunk.isCompleted/isSkipped = false; rethrow; }   // WR-05 revert covers streak save
```

## Task Commits

1. **Task 1 RED: Failing ENGINE-03b + ENGINE-05 notifier tests** - `91bf6b1` (test)
2. **Task 1 GREEN: Inject GoalRepository, fetch logs, thread lighterDay, streak write-back** - `27c8da3` (feat)
3. **Task 2: Plumb lighter-day toggle for all moods** - `f1ed45b` (feat)

## Files Created/Modified

- `lib/providers/schedule_notifier.dart` — GoalRepository injection; generateToday lighterDay param + log fetch; streak write-back in markComplete + markSkipped
- `lib/screens/schedule/checkin_screen.dart` — lighterDay: _lighterDay added to generateToday call; toggle visibility guard changed from <= 2 to != null
- `test/providers/schedule_notifier_engine_test.dart` — 3 new ENGINE-05 / ENGINE-03b tests (TDD RED + GREEN)
- `test/screens/cold_launch_morning_loop_test.dart` — Override signature updated to include lighterDay param (Rule 1 auto-fix)

## Decisions Made

- Streak write-back placed inside existing try block so WR-05 revert (chunk.isCompleted = false on failure) also covers a failed GoalRepository.save — keeps schedule, log, and streak in sync
- `getByGoalId` called AFTER `_logRepo.append` so the just-appended completion/skip entry is included in the streak walk
- Non-empty UUID guard `chunk.goalId != null && chunk.goalId!.isNotEmpty` prevents commitment chunks from triggering goal lookups (T-09-08 mitigation)
- Test date 2026-06-08 (verified Monday, weekday=1); prior logs seeded for Wed 2026-06-03 and Fri 2026-06-05 (correct 3x/week due-day pattern)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] cold_launch_morning_loop_test.dart override signature incompatible with new generateToday param**
- **Found during:** Task 1 GREEN (full test suite run)
- **Issue:** `_InMemoryScheduleNotifier.generateToday` overrides `ScheduleNotifier.generateToday` without the new `lighterDay` parameter — Dart compilation error
- **Fix:** Added `bool lighterDay = true` to the override signature and passed `lighterDay: lighterDay` into `_gen.generate()`
- **Files modified:** test/screens/cold_launch_morning_loop_test.dart
- **Committed in:** 27c8da3 (Task 1 GREEN commit)

**2. [Rule 1 - Bug] Test dates were wrong: 2026-06-09 is Tuesday not Monday**
- **Found during:** Task 1 GREEN (streak tests failed: expected 3, got 1)
- **Issue:** Test set `testDate = DateTime(2026, 6, 9)` but 2026-06-09 is a Tuesday (weekday=2), not Monday. The 3x/week habit (due Mon/Wed/Fri = {1,3,5}) is NOT due on Tuesday, so the just-appended completion log lands on a non-due day and the streak only counts the one prior log that happened to be on a due day
- **Fix:** Changed `testDate` to `DateTime(2026, 6, 8)` (Monday, verified weekday=1); changed prior log dateYmd from '2026-06-06' (Saturday) to '2026-06-05' (Friday); changed schedule dateYmd from '2026-06-09' to '2026-06-08'
- **Files modified:** test/providers/schedule_notifier_engine_test.dart
- **Committed in:** 27c8da3 (Task 1 GREEN commit)

---

**Total deviations:** 2 auto-fixed (Rule 1 — incompatible override + wrong test dates)
**Impact on plan:** Necessary correctness fixes; no scope creep.

## Known Stubs

None — all data paths are wired to real repositories (or injectable in-memory fakes for tests).

## Threat Surface Scan

No new network endpoints, auth paths, or file access patterns introduced. All changes are local Hive persistence. T-09-07 (streak/flag divergence) and T-09-08 (empty goalId) mitigations are implemented as designed.

## Self-Check: PASSED

- FOUND: lib/providers/schedule_notifier.dart (modified)
- FOUND: lib/screens/schedule/checkin_screen.dart (modified)
- FOUND: test/providers/schedule_notifier_engine_test.dart (created)
- FOUND: test/screens/cold_launch_morning_loop_test.dart (modified)
- FOUND: commit 91bf6b1 (Task 1 RED)
- FOUND: commit 27c8da3 (Task 1 GREEN)
- FOUND: commit f1ed45b (Task 2)
- All 121 tests pass; flutter analyze clean (5 pre-existing info items in unrelated files)
