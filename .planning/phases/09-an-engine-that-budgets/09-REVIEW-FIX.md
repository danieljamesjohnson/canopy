---
phase: 09-an-engine-that-budgets
fixed_at: 2026-06-11T00:00:00Z
review_path: .planning/phases/09-an-engine-that-budgets/09-REVIEW.md
iteration: 2
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 09: Code Review Fix Report

**Fixed at:** 2026-06-11
**Source review:** .planning/phases/09-an-engine-that-budgets/09-REVIEW.md
**Iteration:** 2

**Summary:**
- Findings in scope: 2
- Fixed: 2
- Skipped: 0

## Fixed Issues

### WR-02: `computeStreak` Does Not Detect Missed Due Days

**Files modified:** `lib/services/schedule_generator.dart`, `test/services/schedule_generator_test.dart`
**Commit:** 50be7de
**Applied fix:** Replaced the log-only walk in `computeStreak` with a backward calendar walk starting from a new required `today: DateTime` named parameter. The function now walks day-by-day from today going back up to 365 days; for each due weekday it checks whether a completed log entry exists for that date using a `Set<String>` of `yyyy-MM-dd` values for O(1) lookup. A due weekday with no log entry (truly missed) breaks the streak immediately, matching the locked spec decision in 09-CONTEXT.md ("A due day that is skipped or missed resets the streak to 0"). Added `import 'package:intl/intl.dart'` for `DateFormat`. Updated the internal call site in `generate()` to pass `today: date`. Added two new unit tests: `T-09-WR02` (missed Friday gap breaks streak to 1, not 3) and `T-09-WR02b` (three consecutive completions yield streak 3) in `test/services/schedule_generator_test.dart`.

### WR-01: Streak Write-Back Introduces a New Log/Schedule Divergence Window

**Files modified:** `lib/providers/schedule_notifier.dart`
**Commit:** 92a0878
**Applied fix:** Wrapped the streak recompute+`_goalRepo.save()` block in its own nested `try/catch` in all three mark methods (`markComplete`, `markSkipped`, `markDeferred`). The streak block is still positioned after `_logRepo.append()` succeeds, but a failure in the streak block is now swallowed locally and never propagates to the outer catch. The outer catch retains its original purpose: reverting the in-memory flag and re-saving the schedule only when `_repo.save` or `_logRepo.append` fails. A goal-save failure therefore leaves the streak stale (acceptable) but no longer creates a divergence between the log (already written, append-only) and the schedule (reverted). Applied symmetrically to all three methods. Also updated all three call sites to pass the new required `today: DateTime.parse(_todaySchedule!.dateYmd)` parameter.

---

_Fixed: 2026-06-11_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
