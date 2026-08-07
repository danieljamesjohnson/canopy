---
phase: 21-mood-scaled-breaks-honest-rationale
plan: 02
subsystem: engine
tags: [flutter, dart, schedule-generator, tdd, unit-test, copywriting]

# Dependency graph
requires:
  - phase: 21-mood-scaled-breaks-honest-rationale plan 01
    provides: "Mood-scaled break cadence table (_moodBreakCadence) — no shared surface with this plan, sequenced after it by wave order only"
provides:
  - "_timeTargetRationale's under-pace branch returns 'Working toward <N.N>h this week' instead of '<N.N>h behind this week'"
  - "First-ever test coverage on _timeTargetRationale: one test per branch (deficit-turned-working-toward, and the pre-existing on-track branch)"
  - "Repo-wide confirmation that 'behind this week' appears nowhere under lib/"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Rationale copy asserted through integration-style sut.generate(...).rationale, never against the private helper directly — matches this test file's established convention"

key-files:
  created: []
  modified:
    - lib/services/schedule_generator.dart
    - test/services/schedule_generator_test.dart

key-decisions:
  - "Reworded the case-insensitive 'no behind anywhere' assertion's reason string from 'TONE-01: no rationale...' to 'TONE-01 requires that no rationale...' to keep grep -c \"TONE-01:\" at exactly 2 (the two test names), matching the plan's acceptance criteria — same wording-precision pattern plan 21-01 used for its own grep-count criteria"

patterns-established: []

requirements-completed: [TONE-01]

# Metrics
duration: 4min
completed: 2026-08-07
---

# Phase 21 Plan 02: Honest Time-Target Rationale Summary

**Replaced the deficit-framed `'Xh behind this week'` time-target rationale with `'Working toward Xh this week'` — a single-line production change in `_timeTargetRationale`, backed by two new tests that are the first coverage that helper has ever had.**

## Performance

- **Duration:** ~4 min
- **Tasks:** 2 (TDD: RED then GREEN)
- **Files modified:** 2

## Accomplishments
- Two new tests added to `test/services/schedule_generator_test.dart`: `TONE-01: under-pace time-target rationale reads as working toward, not behind` (asserts the exact replacement string on both work chunks it produces, plus a case-insensitive "no chunk rationale contains 'behind'" guard across the whole result) and `TONE-01: on-track branch is unchanged` (regression guard on the untouched `'On track this week'` sibling branch)
- RED step verified precisely: 61/62 tests passing, with the working-toward test as the sole failure, actual value `'5.0h behind this week'` against expected `'Working toward 5.0h this week'` — confirming the assertion was actually reading the live rationale before any production change
- GREEN step: one-line production edit in `_timeTargetRationale` — `return '${remaining.toStringAsFixed(1)}h behind this week';` became `return 'Working toward ${remaining.toStringAsFixed(1)}h this week';`. Everything else in the helper (`_completedChunksThisWeek`, the `* 25.0 / 60.0` conversion, the `.clamp(0.0, double.infinity)`, the `remaining < 0.1` threshold, `toStringAsFixed(1)`) is byte-for-byte unchanged
- All 62 tests in `schedule_generator_test.dart` pass; full suite is 348 tests, 0 failures; `flutter analyze lib/services/schedule_generator.dart` reports "No issues found!"
- `grep -rn "behind this week" lib/ | wc -l` returns `0` — the phase gate from 21-VALIDATION.md is green, both on executable lines and in comments
- Production diff confirmed as exactly one changed line: `git diff --stat lib/` shows `1 file changed, 1 insertion(+), 1 deletion(-)`

## Task Commits

Each task was committed atomically:

1. **Task 1: Pin both rationale branches with tests (RED)** - `9fe6adf` (test)
2. **Task 2: Reframe the time-target rationale (GREEN) and close the grep gate** - `37668dd` (feat)

**Plan metadata:** commit pending (this SUMMARY + STATE/ROADMAP update)

## Files Created/Modified
- `test/services/schedule_generator_test.dart` - Two new tests: `TONE-01: under-pace time-target rationale reads as working toward, not behind` and `TONE-01: on-track branch is unchanged`, appended after plan 21-01's BREAK-02 test
- `lib/services/schedule_generator.dart` - `_timeTargetRationale`'s deficit-branch return literal changed from `'${remaining.toStringAsFixed(1)}h behind this week'` to `'Working toward ${remaining.toStringAsFixed(1)}h this week'`

## Decisions Made
- Reworded the "no behind anywhere" assertion's `reason:` string to avoid a third literal match of `TONE-01:` in the file, so `grep -c "TONE-01:"` lands on exactly 2 (the plan's stated acceptance criterion), matching each test name once — no behavior or coverage difference, wording-only

## Deviations from Plan

None — plan executed exactly as written. The one adjustment (rewording the `reason:` string in Task 1's guard assertion) was made during test-writing to satisfy the plan's own stated `grep -c "TONE-01:"` acceptance criterion precisely; it does not change what is asserted or covered.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

- TONE-01 requirement complete and test-verified; both branches of `_timeTargetRationale` now have coverage where none existed before this plan
- The repo-wide grep gate (`behind this week` under `lib/`) is green, satisfying the automated portion of the 21-VALIDATION.md phase gate; the one remaining manual UAT step (reading the rationale badge in a live chunk card to confirm it *feels* like help rather than a deficit report) is deferred to `/gsd-verify-work` / UAT per the plan's verification section, not blocking here
- Phase 21 (both plans 21-01 and 21-02) is now fully executed: BREAK-01/02 and TONE-01 all test-verified, full 348-test suite green, `flutter analyze` clean

---
*Phase: 21-mood-scaled-breaks-honest-rationale*
*Completed: 2026-08-07*

## Self-Check: PASSED

- FOUND: lib/services/schedule_generator.dart
- FOUND: test/services/schedule_generator_test.dart
- FOUND: 9fe6adf (test commit)
- FOUND: 37668dd (feat commit)
