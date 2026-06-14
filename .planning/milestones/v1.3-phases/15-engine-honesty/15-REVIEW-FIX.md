---
phase: 15-engine-honesty
fixed_at: 2026-06-13T22:25:00Z
review_path: .planning/phases/15-engine-honesty/15-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 15: Code Review Fix Report

**Fixed at:** 2026-06-13T22:25:00Z
**Source review:** .planning/phases/15-engine-honesty/15-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (CR-01, CR-02, WR-01)
- Fixed: 3
- Skipped: 0

## Fixed Issues

### CR-01: `greaterThan` relaxed to `greaterThanOrEqualTo` masks a genuine priority regression

**Files modified:** `lib/services/schedule_generator.dart`, `test/services/schedule_generator_test.dart`
**Commit:** `bbe1b8c`
**Applied fix:** Added a PRIORITY-03 surplus pass before the FILL-02 round-robin in Step 4 of
`schedule_generator.dart`. Goals with `priorityWeight >= 0.75` receive one extra chunk before
the round-robin begins. With cap=6 and two time-target goals (demand=4 each), the surplus produces
high=4 and low=2 chunks, satisfying success criterion 5 ("higher-priority goals receive more
chunks"). The relaxed `greaterThanOrEqualTo` assertion in the Phase-14 test was restored to
`greaterThan`, and the test name and comments were updated to document the correct expected
distribution (4 vs 2, not 3 vs 3 as before). CR-02 was also applied in this same commit
(both changes are in `lib/services/schedule_generator.dart`).

**Note on logic correctness:** The engine change involves a priority-ordering invariant. The
expected allocation (high=4, low=2) was verified by hand-tracing the surplus+round-robin logic
and confirmed by the test suite (all 221 tests pass). Requires human verification of the
priority semantics.

### CR-02: FILL-01 sets low-mood time-target demand to 1 unconditionally, scheduling exhausted goals

**Files modified:** `lib/services/schedule_generator.dart`
**Commit:** `bbe1b8c` (committed with CR-01 — both changes are in the same file)
**Applied fix:** Changed the demand calculation from the unconditional `isLowMood ? 1 : rawDemand`
to `rawDemand.clamp(0, 1)` on low-mood days, where `rawDemand = _demandForTimeTarget(goal, ...)`.
This correctly skips goals with zero remaining budget (`rawDemand == 0`) on low-mood days while
still capping demand at 1 for goals that do have remaining work. Applied in both the PRIORITY-03
surplus pass and the FILL-02 round-robin loop for consistency.

### WR-01: Misleading comment in STREAK-01 test incorrectly references the outer `testDate`

**Files modified:** `test/providers/schedule_notifier_engine_test.dart`
**Commit:** `de4e81f`
**Applied fix:** Corrected three wrong dates in test comments:
- Line 197: "Fri 2026-06-06" corrected to "Fri 2026-06-05" (matches actual seeded log date)
- Line 197: "Today = Mon 2026-06-09" corrected to "Today = Mon 2026-06-08" (matches `testDate` on line 94)
- Line 362: "testDate is Sunday 2026-06-07" corrected to "streak01TestDate is Sunday 2026-06-07"
  (the outer `testDate` is Monday 2026-06-08; the Sunday variable is `streak01TestDate` defined on line 374)

---

_Fixed: 2026-06-13T22:25:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
