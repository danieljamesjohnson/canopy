---
phase: 09-an-engine-that-budgets
plan: 01
subsystem: scheduling
tags: [dart, flutter, schedule-engine, completion-log, tdd, unit-test]

# Dependency graph
requires:
  - phase: 08-scheduling-passes
    provides: "Steps A–E ordering/break pass that consumes workChunks list; ScheduledChunk model; 13 existing tests"

provides:
  - "ScheduleGeneratorService.generate() with completionLogs + lighterDay params"
  - "Public static ScheduleGeneratorService.computeDueWeekdays(freq) for Plan 03 streak write-back"
  - "Public static ScheduleGeneratorService.computeStreak(goalId, dueWeekdays, allLogs) for Plan 03 streak write-back"
  - "InMemoryCompletionLogRepository shared test seam under lib/"
  - "6 new ENGINE unit tests (T-09-01..T-09-06)"

affects:
  - "09-02 (priority UI — consumes priorityWeight scheduling behavior)"
  - "09-03 (streak write-back — calls computeDueWeekdays/computeStreak as public static methods)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Public static methods on service for Plan-03-accessible helpers (computeDueWeekdays, computeStreak)"
    - "Floor-div weekday spread: i * 7 ~/ freq + 1 (never round-based)"
    - "Multi-chunk demand allocation: ceil(remainingHrs*60/25/daysLeft).clamp(0,4)"
    - "Lighter-day cap: _effectiveCap drops one mood tier when lighterDay=true"
    - "Most-behind-first sort with priorityWeight tiebreaker for time-target goals"

key-files:
  created:
    - lib/data/repositories/in_memory_completion_log_repository.dart
  modified:
    - lib/services/schedule_generator.dart
    - test/services/schedule_generator_test.dart

key-decisions:
  - "computeDueWeekdays and computeStreak exposed as public static methods on ScheduleGeneratorService so Plan 03 (ScheduleNotifier) can call them without duplicating logic"
  - "Steps A–E (ordering/break pass) content is byte-identical to pre-edit; verified by sha256 of region from boundary comment to EOF"
  - "Test rationale assertions for Tests 3/4 updated from 'Habit' to 'Daily habit' — required by new _habitRationale helper (daily = freq 7 = no streak)"
  - "Threat T-09-01: daysLeft clamped to [1,7] — Sunday always has daysLeft=1, not 0"
  - "Threat T-09-02: max(1, daysRemaining) in urgency formula prevents division by zero for past deadlines"

patterns-established:
  - "Engine helpers exposed as public static for cross-plan consumption (Plan 03 contract)"
  - "InMemoryCompletionLogRepository in lib/ (not test/) following InMemoryAppSettingsRepository pattern"
  - "Dynamic rationale strings generated in service (not static mapper) for budget/streak/deadline"

requirements-completed: [ENGINE-01, ENGINE-02, ENGINE-03, ENGINE-04, ENGINE-05]

# Metrics
duration: 9min
completed: 2026-06-11
---

# Phase 09 Plan 01: An Engine That Budgets Summary

**Multi-chunk budget-aware schedule engine with floor-div habit spread, deadline-pressure outcome ordering, lighter-day cap reduction, and priority tiebreaker — all 23 tests pass with Steps A–E untouched**

## Performance

- **Duration:** 9 min
- **Started:** 2026-06-11T13:31:59Z
- **Completed:** 2026-06-11T13:40:24Z
- **Tasks:** 2
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments

- Rewrote Steps 1–4 of `ScheduleGeneratorService.generate()` to honor `weeklyHourBudget`, `frequencyPerWeek`, `deadline`, and `priorityWeight`
- Added `computeDueWeekdays` and `computeStreak` as public static methods (contract for Plan 03 streak write-back)
- Created `InMemoryCompletionLogRepository` as shared test seam under `lib/` (mirrors `InMemoryAppSettingsRepository` pattern)
- Added 6 new deterministic ENGINE unit tests (T-09-01..T-09-06) in Wave 0 before engine rewrite
- Removed `chunksRemaining = 2.0` placeholder entirely; replaced with `priority / daysRemaining` urgency formula
- Steps A–E (Phase 8 ordering/break pass) content is byte-identical to pre-edit — verified by sha256

## Task Commits

1. **Task 1: Wave 0 — InMemoryCompletionLogRepository + failing tests** - `a82850f` (test)
2. **Task 2: Rewrite Steps 1–4 of generate()** - `f7b5f61` (feat)

## Files Created/Modified

- `lib/data/repositories/in_memory_completion_log_repository.dart` — In-memory CompletionLogRepository fake (all 5 methods: getAll, getById, append, getByDate, getByGoalId); shared under lib/ for multi-file test reuse
- `lib/services/schedule_generator.dart` — Steps 1–4 rewritten; new public static helpers computeDueWeekdays/computeStreak; new private helpers _effectiveCap, _weekStart, _completedChunksThisWeek, _remainingHours, _demandForTimeTarget, _habitRationale, _outcomeRationale, _timeTargetRationale; Steps A–E untouched
- `test/services/schedule_generator_test.dart` — Added makeTimeTarget/makeLog helpers; added T-09-01..T-09-06 tests; updated all 13 existing sut.generate() call sites with completionLogs: []; updated Tests 3/4 rationale assertions to 'Daily habit'

## Decisions Made

- `computeDueWeekdays` and `computeStreak` exposed as public static methods on the service class so Plan 03 (`ScheduleNotifier`) can call them without duplicating logic or creating circular dependencies
- Floor-div spread `i * 7 ~/ freq + 1` used exclusively (round-based formula gives wrong results: freq=3 → Mon/Wed/SAT instead of Mon/Wed/Fri)
- `lighterDay = true` default in `generate()` signature so existing test sites that omit it are unaffected
- Test rationale assertions updated: `'Habit'` → `'Daily habit'` since `_habitRationale` now returns `'Daily habit'` for freq=7 with streak=0

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Test rationale assertions updated to match new dynamic strings**
- **Found during:** Task 2 (engine rewrite)
- **Issue:** Existing Tests 3 and 4 asserted rationale `'Habit'` — the new `_habitRationale` returns `'Daily habit'` for a daily (freq=7) habit with streak=0. Tests would fail with the new engine.
- **Fix:** Updated Test 3 assertion from `'Habit'` to `'Daily habit'`; updated Test 4 assertion from `containsAll(['Habit'])` to `containsAll(['Daily habit'])`. These are mechanical updates required for correctness with the new rationale system.
- **Files modified:** test/services/schedule_generator_test.dart
- **Committed in:** f7b5f61 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — test assertion update for new rationale behavior)
**Impact on plan:** Necessary correctness fix; no scope creep.

## Issues Encountered

None — plan executed cleanly. All 23 tests pass; `flutter analyze` clean for modified files (5 pre-existing deprecated-member-use infos in unrelated test files).

## Next Phase Readiness

- Plan 02 (priority SegmentedButton UI) can proceed — `priorityWeight` scheduling behavior is now tested and working
- Plan 03 (streak write-back + lighterDay plumbing) can consume `ScheduleGeneratorService.computeDueWeekdays` and `ScheduleGeneratorService.computeStreak` as public static methods
- The `InMemoryCompletionLogRepository` in `lib/data/repositories/` is available for all future test files

## Self-Check: PASSED

- FOUND: lib/data/repositories/in_memory_completion_log_repository.dart
- FOUND: lib/services/schedule_generator.dart
- FOUND: test/services/schedule_generator_test.dart
- FOUND: .planning/phases/09-an-engine-that-budgets/09-01-SUMMARY.md
- FOUND: commit a82850f (Task 1)
- FOUND: commit f7b5f61 (Task 2)
- All 23 tests pass
