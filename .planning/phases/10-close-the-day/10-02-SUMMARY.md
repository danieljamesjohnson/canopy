---
phase: 10-close-the-day
plan: "02"
subsystem: schedule_engine
tags: [defer, carry-in, streak, completion_event, schedule_generator, schedule_notifier, tdd]

# Dependency graph
requires:
  - phase: 10-close-the-day
    plan: "01"
    provides: "commitmentId HiveField 9, markDeferred log-site with commitmentId ?? goalId ?? '', InMemoryCompletionLogRepository test seam"
provides:
  - markDeferred logs CompletionEvent.deferred.index (not skipped) — CLOSE-02
  - computeStreak deferredDates branch — deferred due-day is non-breaking (move, not miss)
  - generate() accepts Set<String> deferredGoalIds = const {} — injects one fresh-demand slot per carried goal respecting mood cap, no duplicates
  - generateToday single-hop carry-in — loads prior-day schedule, extracts isDeferred && !isCompleted && goalId != null, passes to generate()
  - test/defer_carryover_test.dart — 13 CLOSE-02 regression tests
affects: [10-03, 11-review-aggregation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TDD RED/GREEN cycle: compile-error RED (deferredGoalIds not yet on generate()) confirmed feature absent before implementing"
    - "deferredDates index in computeStreak parallel to completedDates index — same filter shape, different event"
    - "generateToday single-hop: subtract one day, format yyyy-MM-dd, getByDate, filter isDeferred && !isCompleted && goalId != null"

key-files:
  created:
    - test/defer_carryover_test.dart
  modified:
    - lib/services/schedule_generator.dart
    - lib/providers/schedule_notifier.dart

key-decisions:
  - "Deferred days continue the streak walk without incrementing (move semantics): streak for Mon-completed + Tue-deferred + Wed-completed = 2 (not 3; deferred days contribute 0 to the count)"
  - "deferredGoalIds injection placed after Steps 2-4 in generate() so normal scheduling always takes priority; carry-in only fills residual capacity"
  - "Single-hop carry-in calls getByDate(yesterdayYmd) — the same repo method already used elsewhere; no new seam needed"
  - "Carry-in goalId != null filter on ScheduledChunk naturally excludes commitment chunks (their goalId is null per Plan 01 design decision)"

patterns-established:
  - "deferredDates index alongside completedDates in computeStreak — canonical pattern for any future non-breaking event types"
  - "generate() deferredGoalIds optional set — call site in generateToday owns the lookup; generator stays pure"

requirements-completed: [CLOSE-02]

# Metrics
duration: 5min
completed: 2026-06-11
---

# Phase 10 Plan 02: Defer-to-Tomorrow Carryover Summary

**CLOSE-02 complete: markDeferred logs CompletionEvent.deferred; computeStreak treats deferred as non-breaking; generate() accepts deferredGoalIds carry-in; generateToday performs single-hop prior-day lookup and passes carried goal IDs to generate()**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-11T20:48:33Z
- **Completed:** 2026-06-11T20:53:31Z
- **Tasks:** 2
- **Files modified:** 2 (plus 1 new test file)

## Accomplishments

- Switched `markDeferred` to log `CompletionEvent.deferred.index` (was `skipped.index`) so deferral events are distinguishable from skips in the log
- Added `deferredDates` index to `computeStreak` (parallel to `completedDates`); deferred due-days continue the streak walk without incrementing or resetting — a move, not a miss
- Added `Set<String> deferredGoalIds = const {}` optional named parameter to `generate()`; post-Steps-2-4 injection creates one fresh-demand chunk per carried goal not already scheduled, respects mood cap, no duplicates
- Added single-hop carry-in lookup to `generateToday`: computes previous calendar day ymd, loads its schedule via `getByDate`, extracts `isDeferred && !isCompleted && goalId != null` chunks, passes their goalIds to `generate()` as `deferredGoalIds`
- Wrote 13-test `test/defer_carryover_test.dart` regression suite covering all four plan behaviors plus negative cases (completed-deferred exclusion, commitment-chunk exclusion, two-days-ago single-hop boundary)

## Task Commits

Each task was committed atomically:

1. **RED phase — failing tests** — `d6b1a7f` (test)
2. **Task 1 GREEN — deferred event + non-breaking streak + deferredGoalIds** — `16ddc57` (feat)
3. **Task 2 GREEN — single-hop carry-in in generateToday** — `bc500b7` (feat)

## Files Created/Modified

- `lib/services/schedule_generator.dart` — Added `deferredDates` index to `computeStreak`; added `else if (deferredDates.contains(ymd))` non-breaking branch; added `Set<String> deferredGoalIds = const {}` to `generate()` signature; added carry-in injection block after Steps 2-4
- `lib/providers/schedule_notifier.dart` — Changed `markDeferred` log `eventIndex` from `CompletionEvent.skipped.index` to `CompletionEvent.deferred.index`; updated docstring; added single-hop carry-in lookup before `_generator.generate()` call in `generateToday`
- `test/defer_carryover_test.dart` — New: 13 CLOSE-02 regression tests across four behavior groups

## Decisions Made

- Deferred days contribute 0 to the streak count (they continue the backward walk without incrementing). A user who defers Mon, completes Tue gets streak=1, not streak=2. This matches "a move, not a miss" — the day was not completed, just postponed.
- `deferredGoalIds` injection occurs after all normal scheduling steps (Steps 1-4) so normal scheduling always takes priority; carry-in only consumes residual capacity.
- `goalId != null` filter in the carry-in lookup is the natural mechanism for excluding commitment chunks — no separate `commitmentId` check needed.

## Deviations from Plan

**1. [Rule 1 - Bug] Fixed incorrect streak test expectation**
- **Found during:** Task 1 GREEN phase
- **Issue:** Test expected streak=3 for Mon-completed + Tue-deferred + Wed-completed but the correct value is 2 — deferred days do NOT increment the streak count, they only prevent the reset
- **Fix:** Updated test expectation from 3 to 2 with a correct reasoning comment; this matches the spec ("deferred day is non-breaking but does not increment")
- **Files modified:** test/defer_carryover_test.dart
- **Commit:** 16ddc57 (GREEN commit includes this fix)

**2. [Rule 2 - Lint] Removed unused import**
- **Found during:** flutter analyze after Task 1 GREEN
- **Issue:** `package:canopy/data/models/commitment_block.dart` import was unused in the test file
- **Fix:** Removed the import
- **Files modified:** test/defer_carryover_test.dart

## Issues Encountered

- Pre-existing `onReorder` deprecation warnings (5 issues) are out-of-scope — carried from Plan 01 SUMMARY

## Threat Flags

No new threat surface. The changes are purely local Hive data reads (single-hop prior-day schedule lookup) and event-enum constant changes. No new network endpoints, auth paths, or trust boundary changes. T-10-04 (unbounded carry-in DOS) was explicitly mitigated by the single-hop + fresh-demand pattern — only the immediately-preceding day is scanned, and no stale chunk objects accumulate.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| test/defer_carryover_test.dart | FOUND |
| lib/services/schedule_generator.dart | FOUND |
| lib/providers/schedule_notifier.dart | FOUND |
| .planning/phases/10-close-the-day/10-02-SUMMARY.md | FOUND |
| Commit d6b1a7f (test RED) | FOUND |
| Commit 16ddc57 (feat Task 1 GREEN) | FOUND |
| Commit bc500b7 (feat Task 2 GREEN) | FOUND |
| flutter test (141 tests) | PASSED |
| flutter analyze (no new issues) | PASSED |
