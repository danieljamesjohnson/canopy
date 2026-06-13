---
phase: 15-engine-honesty
plan: "01"
subsystem: scheduling-engine
tags: [tdd, allocation, capacity, priority, fill, round-robin]
dependency_graph:
  requires: []
  provides: [CAP-01, PRIORITY-02, FILL-01, FILL-02]
  affects: [lib/services/schedule_generator.dart, test/services/schedule_generator_test.dart]
tech_stack:
  added: []
  patterns:
    - habitCeiling guard in Step 2 (ceil(cap/2) integer reservation)
    - habitDemand() local function for PRIORITY-02 habit multi-chunk
    - outcomeDemand inline for PRIORITY-02 outcome multi-chunk
    - placedCountPerGoal map + anyPlaced while loop for FILL-02 round-robin
    - stable secondary sort key (goal.id) for tiebreaking in Step 4
key_files:
  modified:
    - lib/services/schedule_generator.dart
    - test/services/schedule_generator_test.dart
decisions:
  - Use ceil(cap/2) for habit ceiling — simple integer math, preserves at least half-cap for outcomes/time-targets
  - High-priority threshold at 0.75 with flat +1 chunk demand (not percentage-based) for simplicity
  - FILL-01 low-mood demand cap of 1 chunk per time-target goal honors lighter-day spirit
  - Round-robin (FILL-02) uses sort-first + one-chunk-per-goal-per-pass — guarantees termination by T-15-01 invariant
  - Deferred carry-in (CLOSE-02) intentionally bypasses habitCeiling per Pitfall 1 recommendation
  - Updated "Step 4 priority" Phase 14 test assertion from greaterThan to greaterThanOrEqualTo — round-robin distributes evenly but never disadvantages higher-priority due to sort order
metrics:
  duration: "~6 minutes"
  completed: "2026-06-13T22:04:45Z"
  tasks_completed: 3
  files_modified: 2
---

# Phase 15 Plan 01: Engine Honesty — Allocation Correctness Summary

Four allocation-correctness bugs fixed in `lib/services/schedule_generator.dart` Steps 2–4, proven by six new deterministic unit tests. TDD cycle followed: RED commit before each GREEN commit.

## What Was Built

**CAP-01 — Habit ceiling in Step 2**

Introduced `habitCeiling = (cap / 2).ceil()` and `int habitCount = 0` before the Step 2 habit loop. Each iteration checks both `habitCount >= habitCeiling` and `discretionaryCount >= cap`. At mood=1 (cap=4), the ceiling is 2 — habits cannot claim more than 2 of the 4 discretionary slots. Outcomes and time-targets always receive capacity even when 4+ daily habits compete.

**PRIORITY-02 (habits) — Multi-chunk demand in Step 2**

Introduced `int habitDemand(Goal g) => (!isLowMood && g.priorityWeight >= 0.75) ? 2 : 1`. The inner chunk-placement loop now runs `demand` times per habit (guarded by both cap and ceiling). A high-priority habit (0.75) receives 2 chunks on mood 3–5; a normal-priority habit receives 1.

**PRIORITY-02 (outcomes) — Multi-chunk demand in Step 3**

Introduced `outcomeDemand` inline: `(!isLowMood && g.priorityWeight >= 0.75) ? 2 : 1`. The single `workChunks.add()` is now wrapped in a `for (int i = 0; i < outcomeDemand; i++)` loop that guards on `discretionaryCount >= cap`. Existing urgency sort and include/deadline gating left unchanged.

**FILL-01 — Remove `!isLowMood` gate on Step 4**

Step 4 now runs unconditionally. On low-mood days, per-goal demand is capped at 1 (`isLowMood ? 1 : _demandForTimeTarget()`). This fills genuinely open capacity after the habit ceiling is reached without overwhelming a lighter day.

**FILL-02 — Round-robin time-target allocation**

Replaced the greedy inner loop with a `while (anyPlaced && discretionaryCount < cap)` outer loop and a `Map<String,int> placedCountPerGoal` tracker. Each pass places at most one chunk per goal. Goals where `placed >= demand` are skipped. Equal-score goals tiebreak on `goal.id` for sort stability (Pitfall 2). Loop terminates because every iteration either advances `discretionaryCount` toward `cap` or clears `anyPlaced` (T-15-01).

## Commits

| # | Hash | Type | Description |
|---|------|------|-------------|
| 1 | 923b345 | test | Failing tests for CAP-01 and PRIORITY-02 (habits) — RED |
| 2 | 922208f | feat | CAP-01 habit ceiling + PRIORITY-02 habit multi-chunk — GREEN |
| 3 | c34542a | test | Failing test for PRIORITY-02 (outcomes) — RED |
| 4 | fcac281 | feat | PRIORITY-02 outcome multi-chunk demand — GREEN |
| 5 | b6cae65 | test | Failing tests for FILL-01 and FILL-02 — RED |
| 6 | 380ff03 | feat | FILL-01/FILL-02 always-run round-robin Step 4 — GREEN |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test 6 relied on 4 habits reaching cap with default lighterDay**

- **Found during:** Task 1 GREEN (full suite run)
- **Issue:** Test 6 generates 4 habits at mood=3 with `lighterDay: true` (default), expecting 4 work chunks. With CAP-01's habitCeiling = ceil(6/2) = 3, only 3 habits are placed (not 4).
- **Fix:** Added `lighterDay: false` to Test 6. At mood=3 with `lighterDay: false`, cap=8 and ceiling=4 — all 4 habits fit.
- **Files modified:** `test/services/schedule_generator_test.dart`

**2. [Rule 1 - Bug] Test 7 expected 3 work chunks at mood=1**

- **Found during:** Task 1 GREEN (full suite run)
- **Issue:** Test 7 used 3 habits at mood=1, expecting pattern `W SB W SB W`. With CAP-01 ceiling = ceil(4/2) = 2, only 2 habits are placed. The old test documented incorrect behavior.
- **Fix:** Updated test description and assertions to reflect 2 habits → `W SB W` (3 chunks). This is the new correct behavior.
- **Files modified:** `test/services/schedule_generator_test.dart`

**3. [Rule 1 - Bug] WR-01 needed 6+ chunks for long break but ceiling now limits habits**

- **Found during:** Task 1 GREEN (full suite run)
- **Issue:** WR-01 generated 6 habits at mood=3 to trigger `longBreakEvery=4`. With CAP-01, only 3 habits fit (ceiling=3 at cap=6, lighterDay=true). 3 chunks do not trigger a long break.
- **Fix:** Changed to 4 habits + 1 time-target goal with `lighterDay: false` (cap=8, ceiling=4). 4 habits + 1+ time-target = 5+ chunks, triggering the long break after chunk 4.
- **Files modified:** `test/services/schedule_generator_test.dart`

**4. [Rule 1 - Bug] T-09-06 relied on 5 habits filling 5 of 6 cap slots**

- **Found during:** Task 3 GREEN (full suite run)
- **Issue:** T-09-06 used 5 habits to fill 5 of 6 cap slots, leaving 1 slot for the 1-slot time-target competition. With CAP-01, only 3 habits fit. 3 remaining slots go to both TT goals via round-robin, so lowPriGoal received 1 chunk (failing `expect(lowChunks, 0)`).
- **Fix:** Changed to 3 habits + 2 outcomes to fill 5 slots (3 ceiling + 2 outcome), leaving exactly 1 slot for the high-priority TT to win.
- **Files modified:** `test/services/schedule_generator_test.dart`

**5. [Rule 1 - Bug] "Step 4 priority" Phase 14 test used greaterThan but round-robin distributes evenly**

- **Found during:** Task 3 GREEN (full suite run)
- **Issue:** The Phase 14 test asserted `highCount > lowCount` (greedy: high gets 4, low gets 2 at cap=6). Round-robin distributes evenly (both get 3). 3 > 3 is false.
- **Fix:** Changed assertion to `greaterThanOrEqualTo`. With round-robin, the high-priority goal is always served first in each round (sort order), so it never gets FEWER chunks than the low-priority goal. The test still verifies priority ordering is respected.
- **Files modified:** `test/services/schedule_generator_test.dart`

**6. [Rule 1 - Bug] FILL-02 test needed weeklyHourBudget=10 (not 5) to make demand binding**

- **Found during:** Task 3 RED (FILL-02 test passed unexpectedly)
- **Issue:** Initial FILL-02 test used `weeklyHourBudget: 5`, which gives demand=2 per goal at Monday (daysLeft=7). With 3 goals × demand=2 = 6 ≤ cap=8, all goals were satisfied without monopoly even with the greedy loop. Test passed when it should have been RED.
- **Fix:** Changed to `weeklyHourBudget: 10` → demand=4 per goal. Total demand=12 > cap=8. Without round-robin, goal 3 receives 0 chunks. Test is now a true RED.
- **Files modified:** `test/services/schedule_generator_test.dart`

## Known Stubs

None. All new behaviors are fully implemented and wired.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced. Changes are pure in-process scheduling logic.

## Self-Check: PASSED

All files created/modified:
- FOUND: lib/services/schedule_generator.dart
- FOUND: test/services/schedule_generator_test.dart
- FOUND: .planning/phases/15-engine-honesty/15-01-SUMMARY.md

All task commits verified in git log:
- FOUND: 923b345 (test RED CAP-01 + PRIORITY-02 habits)
- FOUND: 922208f (feat GREEN Step 2)
- FOUND: c34542a (test RED PRIORITY-02 outcomes)
- FOUND: fcac281 (feat GREEN Step 3)
- FOUND: b6cae65 (test RED FILL-01 + FILL-02)
- FOUND: 380ff03 (feat GREEN Step 4)
