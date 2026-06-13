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
  critical: 0
  warning: 0
  info: 1
  total: 1
status: clean
---

# Phase 15: Code Review Report (Iteration 3 — Final)

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 4
**Status:** clean

## Summary

This is the final iteration re-review, verifying that the iteration-2 fixes are present and correct and scanning for any remaining or new Critical/Warning issues.

**Iteration-2 fixes verified:**

- **WR-01 (PRIORITY-03 docstring):** Lines 369–376 of `schedule_generator.dart` now contain the corrected docstring. The false guarantee ("lower-priority goals are still guaranteed at least one chunk") has been replaced with an explicit NOTE that three or more high-priority goals can exhaust capacity before lower-priority goals are reached, and that this is accepted spec-faithful behavior. Fix is correct and complete.

- **IN-01 (allLogs re-filter):** Lines 154–155 of `schedule_notifier.dart` now include the explanatory comment: "allLogs already contains only entries for goals in this loop (built via getByGoalId above), but re-filter defensively in case the log-fetch strategy changes and allLogs starts containing mixed entries." Fix is correct and complete.

- **IN-02 (habitCeiling bypass):** Lines 437–440 of `schedule_generator.dart` now include the comment explaining the intentional bypass: "CLOSE-02: deferred injection bypasses the habitCeiling guard intentionally. A goal deferred from yesterday has already been counted against yesterday's cap. Re-materializing it today should not be blocked by today's ceiling — the goal was already 'paid for' and the user explicitly asked to defer it." Fix is correct and complete.

**Adversarial re-pass findings — no new Critical or Warning issues found.** All previously identified logic paths were re-traced:

- `computeStreak` calendar-walk, deferred-date handling, and 365-day bound are correct.
- `_effectiveCap` mood=1 lighter-day clamp stays at mood-1 cap (not underflows). Correct.
- `PRIORITY-03` surplus pass correctly seeds `placedCountPerGoal[goal.id] = 1` before the round-robin, so each surplus goal's round-robin demand is reduced by 1. No double-counting.
- `markComplete`/`markSkipped`/`markDeferred` revert-and-rethrow pattern is correct. The in-memory flag is set before the first `await`, so Dart's cooperative concurrency prevents a double-fire race.
- Commitment chunk `goalId == null` → empty-string guard at `markComplete` line 219 is correct.
- Null-safe `?.chunks ?? {}` for missing yesterday's schedule in `generateToday` is correct.
- Overlapping commitment block merge in `_assignSyntheticStartTimes` is correct (proper interval merge, not adjacency-only).
- `startFloorMinutes` late-night edge case (after 22:00) correctly produces no discretionary chunks.

One new Info-level observation is noted below.

---

## Info

### IN-01: `generateToday` uses `DateTime.now()` directly for `generatedAt` instead of injectable `_now`

**File:** `lib/providers/schedule_notifier.dart:181`
**Issue:** `schedule.generatedAt = DateTime.now().toUtc()` hard-codes the real wall clock for the `generatedAt` field. The notifier accepts an injectable `_now` function specifically to allow time-controlled unit tests. All other time references in `generateToday` use `_now()`. This inconsistency means test-injected `now` values do not affect `generatedAt`, so any future test that asserts on generation timestamps will use the real clock rather than the test-controlled time.

Currently no test asserts on `generatedAt`, so there is no test failure. The defect is latent.

**Fix:**
```dart
schedule.generatedAt = _now().toUtc();
```

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
