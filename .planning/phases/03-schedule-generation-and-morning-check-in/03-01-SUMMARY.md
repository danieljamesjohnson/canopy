---
phase: 03-schedule-generation-and-morning-check-in
plan: 01
subsystem: scheduling
tags: [dart, tdd, schedule-generator, mood-capacity, break-insertion, commitment-blocks]

# Dependency graph
requires:
  - phase: 02-goals-and-commitments
    provides: Goal, CommitmentBlock Hive models with goalTypeIndex, deadline, priorityWeight, daysOfWeek, startMinutes, endMinutes fields
  - phase: 01-foundation
    provides: ScheduledChunk Hive model with ChunkType enum, anchoredStartMinutes, rationale fields
provides:
  - ScheduleGeneratorService — pure Dart service generating ordered List<ScheduledChunk> from goals, blocks, mood, and date
  - Comprehensive test suite (10 tests) covering all allocation rules and break patterns
affects:
  - 03-02 (morning check-in screen wiring to ScheduleGeneratorService)
  - 03-03 (schedule display UI consuming List<ScheduledChunk>)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Pure Dart service class (no Flutter imports) for testable business logic
    - TDD (RED-GREEN) with flutter_test for algorithm correctness
    - Local function for urgency scoring inside generate() method

key-files:
  created:
    - lib/services/schedule_generator.dart
    - test/services/schedule_generator_test.dart
  modified: []

key-decisions:
  - "Commitment chunks are not counted against discretionary capacity — they are fixed anchored slots"
  - "80% cap is applied at the discretionary level only (habits + outcome + time-target count; commitment chunks do not)"
  - "daysRemaining floors at 1 via max(1, ...) to prevent division-by-zero in urgency score"
  - "Null deadline outcome goals receive urgency score = priorityWeight * 0.1 (low but non-zero)"
  - "longBreakEvery = 3 for mood 1-2, = 4 for mood 3-5; applied in a single post-allocation pass"
  - "Phase 3 uses placeholder chunksRemaining = 2.0 in urgency formula (no CompletionLog until Phase 4)"

patterns-established:
  - "Services in lib/services/ are pure Dart — no flutter/ imports allowed"
  - "Test files mirror lib/ structure under test/ (e.g., lib/services/foo.dart -> test/services/foo_test.dart)"

requirements-completed: [SCHED-01, SCHED-02, SCHED-03, SCHED-04]

# Metrics
duration: 8min
completed: 2026-03-23
---

# Phase 3 Plan 01: Schedule Generator Summary

**Mood-aware schedule generation algorithm as a pure Dart service with TDD — commitment chunking, 80% discretionary capacity cap, urgency-sorted outcome goals, and interleaved short/long breaks**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-23T18:05:00Z
- **Completed:** 2026-03-23T18:13:00Z
- **Tasks:** 2 (RED + GREEN)
- **Files modified:** 2

## Accomplishments
- Implemented `ScheduleGeneratorService.generate()` — pure Dart, no Flutter dependencies, fully synchronous
- All 10 TDD test cases pass covering: empty schedule, commitment block anchoring, mood filtering, deadline-today exception, 80% capacity cap, break pattern (mood 1-2 vs 3-5), and division-by-zero safety
- Zero `flutter analyze` issues after inline lint fix

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — Write failing tests** - `8845ff3` (test)
2. **Task 2: GREEN — Implement ScheduleGeneratorService** - `eaf6675` (feat)

**Plan metadata:** (docs commit follows)

_Note: TDD plan — test commit precedes implementation commit._

## Files Created/Modified
- `lib/services/schedule_generator.dart` - ScheduleGeneratorService with generate() method; pure Dart
- `test/services/schedule_generator_test.dart` - 10 behavior tests covering all allocation rules and break insertion

## Decisions Made
- Commitment chunks are excluded from discretionary capacity counting — they are fixed and always appear regardless of mood or cap
- `daysRemaining` uses `max(1, ...)` to floor at 1, preventing division-by-zero when deadline is today or in the past
- Null-deadline outcome goals receive `priorityWeight * 0.1` urgency so they still appear in mood 3-5 schedules but ranked last
- Phase 3 placeholder `chunksRemaining = 2.0` in urgency formula; will be replaced with CompletionLog data in Phase 4
- `longBreakEvery` is derived from `moodIndex` at start of generate() — 3 for low mood, 4 for normal/high

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Renamed local function to remove leading underscore**
- **Found during:** Task 2 (GREEN implementation)
- **Issue:** Local function `_urgencyScore` triggered `no_leading_underscores_for_local_identifiers` lint rule
- **Fix:** Renamed to `urgencyScore` — local functions should not use private-style underscore prefix in Dart
- **Files modified:** lib/services/schedule_generator.dart
- **Verification:** `flutter analyze lib/services/` reports zero issues
- **Committed in:** eaf6675 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — lint/naming)
**Impact on plan:** Trivial rename; no logic change. All tests still pass.

## Issues Encountered
None — algorithm matched spec on first implementation pass.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `ScheduleGeneratorService` is ready for wiring to a `ScheduleNotifier` or morning check-in screen
- The service is stateless and pure — safe to call synchronously from any notifier or widget
- Phase 4 will replace the `chunksRemaining = 2.0` placeholder with real CompletionLog data

---
*Phase: 03-schedule-generation-and-morning-check-in*
*Completed: 2026-03-23*

## Self-Check: PASSED

- FOUND: lib/services/schedule_generator.dart
- FOUND: test/services/schedule_generator_test.dart
- FOUND: .planning/phases/03-schedule-generation-and-morning-check-in/03-01-SUMMARY.md
- FOUND: commit 8845ff3 (test RED)
- FOUND: commit eaf6675 (feat GREEN)
