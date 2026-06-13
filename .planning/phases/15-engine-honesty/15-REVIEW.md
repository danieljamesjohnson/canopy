---
phase: 15-engine-honesty
reviewed: 2026-06-13T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - lib/services/schedule_generator.dart
  - lib/providers/schedule_notifier.dart
  - test/services/schedule_generator_test.dart
  - test/providers/schedule_notifier_engine_test.dart
findings:
  critical: 2
  warning: 1
  info: 2
  total: 5
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Phase 15 ("Engine Honesty") introduced four allocation-correctness changes to the scheduling engine: a habit ceiling (CAP-01), priority-driven multi-chunk demand for habits and outcomes (PRIORITY-02), unconditional time-target scheduling with low-mood cap (FILL-01), and round-robin distribution across time-target goals (FILL-02). It also added a generation-time streak write-back (STREAK-01) in `schedule_notifier.dart`.

Two blockers were found. The first is a spec regression: the Phase-14 test that previously asserted `greaterThan` was relaxed to `greaterThanOrEqualTo` to accommodate the round-robin behavior, but the phase's own success criterion 5 requires that higher-priority time-target goals receive _more_ chunks — not merely equal chunks. The round-robin gives equal chunks when both goals have equal remaining hours and cap divides evenly, contradicting the spec. The second is a logic error in FILL-01: on low-mood days, the demand for time-target goals is unconditionally set to 1 regardless of whether the goal's weekly budget has already been met, causing exhausted goals to be scheduled unnecessarily.

The streak write-back in `schedule_notifier.dart` is structurally sound: the no-op guard is present, each goal's save is isolated in its own try/catch, and a save failure does not abort generation. No reentrancy risk was found.

---

## Critical Issues

### CR-01: `greaterThan` relaxed to `greaterThanOrEqualTo` masks a genuine priority regression

**File:** `test/services/schedule_generator_test.dart:1041`
**Issue:** The Phase-14 "Step 4 priority" test (cap=6, two time-target goals with equal `weeklyHourBudget=12h` and priorities 0.75 vs 0.25) previously asserted `highCount > lowCount`. The Phase-15 FILL-02 round-robin distributes capacity evenly — when cap=6 and both goals have demand=4, both receive 3 chunks each, so `3 > 3` fails. The assertion was relaxed to `greaterThanOrEqualTo`.

This means the test now passes when high-priority and low-priority goals receive _the same_ number of chunks. But the phase's own success criterion 5 (15-CONTEXT.md) states: "higher-priority goals receive **more** chunks and no single goal claims the entire open day." The `>=` relaxation makes the test trivially satisfied when there is no priority effect at all (e.g., if the sort order were removed entirely, round-robin would still give equal counts and the test would still pass).

The root cause is architectural: FILL-02 round-robin distributes one chunk per goal per pass with no mechanism to give a higher-priority goal an extra chunk when demand ties. The composite score (`remaining * priorityWeight`) affects sort position within each pass, but not how many passes a goal participates in — both goals exit the round-robin at the same pass count.

**Fix:** Two options depending on which guarantee the product intends:

Option A (spec as written — higher-priority gets MORE): In the round-robin loop, allow a higher-priority goal to receive a second chunk in the same pass when its composite score exceeds the next goal's score by a meaningful threshold. A simpler approach: use _weighted_ demand so that `demand = _demandForTimeTarget(goal, ...) + (priorityWeight >= 0.75 ? 1 : 0)` for time-target goals, mirroring the existing PRIORITY-02 pattern for habits and outcomes. This gives the high-priority goal demand=5, low-priority demand=4; with cap=6, round-robin gives high=3, low=3 again — still equal. A more direct fix is to reintroduce a per-priority boost _outside_ the round-robin: place one extra chunk for goals with `priorityWeight >= 0.75` before the round-robin pass, capped at the remaining capacity.

Option B (relax the spec to "at least as many"): Update 15-CONTEXT.md criterion 5 from "more chunks" to "at least as many chunks" and restore the `greaterThanOrEqualTo` assertion with an explicit comment documenting that round-robin parity is the intended behavior, and add a separate test asserting that the high-priority goal is served _first_ in each round. This preserves correctness under the weaker guarantee.

Whichever option is chosen, the test comment and assertion must match the spec, and the spec must match the implementation. The current state has them in conflict.

---

### CR-02: FILL-01 sets low-mood time-target demand to 1 unconditionally, scheduling exhausted goals

**File:** `lib/services/schedule_generator.dart:378`
**Issue:** In Step 4, when `isLowMood` is true, the demand for a time-target goal is hardcoded to `1`:

```dart
final demand = isLowMood
    ? 1
    : _demandForTimeTarget(goal, completionLogs, date);
```

`_demandForTimeTarget` returns `0` when `_remainingHours` is `<= 0` (line 154). On good-mood days this correctly skips exhausted goals (`demand = 0 → continue`). On low-mood days, demand is always `1`, so a time-target goal whose weekly budget is already met — or whose `weeklyHourBudget` is `null` — still receives a chunk in the schedule. This creates false demand: the user has no actual time-target work remaining but the engine fills their lighter day with it anyway.

A goal with `weeklyHourBudget = null` also gets `_remainingHours = 0` (line 141 returns 0 when budget is null), but on low-mood days it still gets demand=1. And a goal with budget fully spent also falls into this path.

The comment (line 353) describes FILL-01 as "open-capacity filling, not a restorative floor" — which is correct intent — but the implementation violates it by treating demand as unconditionally 1 rather than capping actual demand at 1.

**Fix:** Change the demand calculation to cap the actual demand at 1 on low-mood days rather than replacing it with 1:

```dart
final rawDemand = _demandForTimeTarget(goal, completionLogs, date);
final demand = isLowMood ? rawDemand.clamp(0, 1) : rawDemand;
```

This preserves the FILL-01 intent (at most 1 chunk per time-target goal on low-mood days) while correctly skipping goals that have no remaining budget. The `clamp(0, 1)` is equivalent to `min(rawDemand, 1)` and is explicit about the lower bound.

---

## Warnings

### WR-01: Misleading comment in STREAK-01 test incorrectly references the outer `testDate`

**File:** `test/providers/schedule_notifier_engine_test.dart:362`
**Issue:** The comment immediately above the STREAK-01 sub-test reads "testDate is Sunday 2026-06-07 (weekday=7, not a due day for 3x/week)." The outer `testDate` (line 94) is `DateTime(2026, 6, 8)` — **Monday**, weekday 1. The Sunday variable is named `streak01TestDate` (line 374). A developer reading the comment while debugging a streak failure would be sent to the wrong date and could waste significant time.

The same test block (line 197) also contains two date errors in a single comment: it says the Friday log is "2026-06-06" when the actual log at line 225 is `'2026-06-05'`, and it says "Today = Mon 2026-06-09" when `testDate` is `2026-06-08`. The logic is correct (the code uses the right dates) but all three comment mistakes cluster in the same test file and will confuse future maintainers.

**Fix:** Correct line 362 to read "streak01TestDate is Sunday 2026-06-07 (weekday=7, not a due day for 3x/week)." Correct line 197 to read "Fri 2026-06-05" (not 06-06) and "Today = Mon 2026-06-08" (not 06-09).

---

## Info

### IN-01: STREAK-01 write-back double-filters logs unnecessarily

**File:** `lib/providers/schedule_notifier.dart:152`
**Issue:** `allLogs` is built via `_logRepo.getByGoalId(goal.id)` for each goal (line 113), so it already contains only logs for active goals. The STREAK-01 write-back then re-filters: `allLogs.where((l) => l.goalId == goal.id).toList()` (line 152). This is a no-op — `getByGoalId` guarantees `l.goalId == goal.id` for every entry it returns — but it is visually confusing because it implies allLogs might contain entries for other goals.

**Fix:** Replace with a direct call `_logRepo.getByGoalId(goal.id)` inside the write-back loop, matching what `markComplete`/`markSkipped`/`markDeferred` do (each fetches `getByGoalId` fresh after the log append). Alternatively, keep the filter but add a comment explaining why allLogs is being re-filtered despite being built per-goal.

---

### IN-02: `habitCeiling` bypass in CLOSE-02 deferred injection is undocumented in source

**File:** `lib/services/schedule_generator.dart:404`
**Issue:** The CLOSE-02 deferred carry-in block (lines 404–431) checks only `discretionaryCount >= cap` before injecting a deferred goal's chunk. It does not check `habitCount >= habitCeiling`. This means a deferred habit goal can push the habit allocation past the CAP-01 ceiling. The 15-01-SUMMARY documents this as intentional ("bypasses habitCeiling per Pitfall 1 recommendation"), but there is no comment in the source code explaining this decision. Future readers maintaining the deferred injection block may view the missing ceiling check as a bug and "fix" it incorrectly.

**Fix:** Add a comment at line 404 explaining why the habitCeiling check is absent:

```dart
// CLOSE-02: deferred injection bypasses the habitCeiling guard intentionally.
// A goal deferred from yesterday has already been counted against yesterday's cap.
// Re-materializing it today should not be blocked by today's ceiling.
```

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
