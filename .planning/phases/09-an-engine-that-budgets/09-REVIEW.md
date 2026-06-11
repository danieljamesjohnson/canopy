---
phase: 09-an-engine-that-budgets
reviewed: 2026-06-11T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/services/schedule_generator.dart
  - lib/data/repositories/in_memory_completion_log_repository.dart
  - lib/providers/schedule_notifier.dart
  - lib/screens/goals/goal_form_sheet.dart
  - lib/screens/schedule/checkin_screen.dart
  - test/services/schedule_generator_test.dart
  - test/providers/schedule_notifier_engine_test.dart
  - test/screens/goal_form_priority_test.dart
findings:
  critical: 1
  warning: 2
  info: 4
  total: 7
status: issues_found
---

# Phase 09: Code Review Report

**Reviewed:** 2026-06-11T00:00:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

This phase introduced a budget-aware scheduling engine (weekly-hour budget, habit
frequency spread, deadline urgency, priority weight, lighter-day cap), streak
write-back in the notifier, and a priority `SegmentedButton` in the goal form.

The pure-Dart engine itself is arithmetically correct: no divide-by-zero is possible
(`remaining > 0` guards the division; `daysLeft` is clamped to `[1, 7]`), the
floor-div weekday spread produces the expected sets for all frequencies 1–7, and
the overlapping-block interval merge (WR-02) is sound. The `InMemoryCompletionLogRepository`
and `GoalFormSheet` are clean.

Three issues were found in the integration layer:

1. **BLOCKER** — `checkin_screen._generate()` has no error handler, so a Hive
   failure during `generateToday()` permanently disables the "Let's go" button for
   the session.

2. **WARNING** — The "revert on failure" contract in `markComplete` / `markSkipped`
   is only correct when _every_ persistence step fails before the first one succeeds.
   When `_repo.save()` succeeds and `_logRepo.append()` then fails, the schedule is
   already on disk with `isCompleted = true` but the in-memory flag is reverted to
   `false`, and no completion log exists. The disk and the log are in an inconsistent
   state.

3. **WARNING** — `markDeferred` is missing the streak write-back block that
   `markComplete` and `markSkipped` both contain. A deferred habit on a due day
   will not reset `streakCount` in `GoalRepository`, silently diverging from the
   behaviour of `markSkipped` (which logs the same `skipped` event and does persist
   the new streak).

---

## Critical Issues

### CR-01: `_generate()` leaves `_isGenerating = true` permanently on exception

**File:** `lib/screens/schedule/checkin_screen.dart:52`

**Issue:** `setState(() => _isGenerating = true)` is called on line 54 before the
`await generateToday(...)` call. There is no `try/catch` or `try/finally` block
around the awaited calls. If `generateToday()` throws (e.g., a Hive write failure)
or `NotificationService.requestIOSPermissions()` throws, the function exits before
reaching the `setState(() { _isGenerating = false; })` on line 70. The "Let's go"
button remains permanently disabled and the spinner keeps showing for the rest of
the app session. The user cannot retry without a full app restart.

**Fix:**

```dart
Future<void> _generate() async {
  if (_selectedMood == null || _isGenerating) return;
  setState(() => _isGenerating = true);
  try {
    await context.read<ScheduleNotifier>().generateToday(
      moodIndex: _selectedMood!,
      goals: context.read<GoalsNotifier>().goals,
      blocks: context.read<CommitmentsNotifier>().blocks,
      lighterDay: _lighterDay,
    );
    await NotificationService.requestIOSPermissions();
    if (mounted) {
      setState(() {
        _scheduleGenerated = true;
        _isGenerating = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isGenerating = false);
      // Optionally surface feedback to the user here.
    }
    rethrow;
  }
}
```

---

## Warnings

### WR-01: Partial-revert in `markComplete` / `markSkipped` creates disk–memory divergence

**File:** `lib/providers/schedule_notifier.dart:152`

**Issue:** The revert pattern (`chunk.isCompleted = false; rethrow`) assumes that all
three persistence steps fail atomically. In practice they do not. If step 2
(`_repo.save(_todaySchedule!)`) succeeds but step 3 (`_logRepo.append(...)`) throws,
the schedule is persisted to Hive with `isCompleted = true`, but the `catch` block
reverts the in-memory flag to `false` without re-saving the schedule. The result:

- **In-memory (current session):** chunk appears as not completed.
- **On disk (Hive):** chunk is stored as completed, with no matching `CompletionLog`.

On the next app startup, `getTodaysSchedule()` loads the Hive version, so the chunk
re-appears as completed — but no completion log exists, so the budget and streak
computations for that goal are incorrect for the rest of the week.

The same failure mode exists in `markSkipped` (lines 208–242) and, for both
`isDeferred` and `isSkipped`, in `markDeferred` (lines 265–285).

A complete fix would require either a two-phase write (save a "pending" record
before mutating, delete it on success) or saving the reverted schedule back to
disk in the catch block. A pragmatic short-term fix: re-save the reverted schedule
in the catch block so the on-disk and in-memory states agree:

```dart
} catch (_) {
  chunk.isCompleted = false;
  // Re-persist the reverted state so disk and memory stay in sync.
  try { await _repo.save(_todaySchedule!); } catch (_) {}
  rethrow;
}
```

### WR-02: `markDeferred` missing streak write-back — inconsistent with `markSkipped`

**File:** `lib/providers/schedule_notifier.dart:256`

**Issue:** `markDeferred` logs the event as `CompletionEvent.skipped` (line 274),
the same event type that `markSkipped` uses. `markSkipped` (lines 221–237) contains
the ENGINE-03 streak write-back block: it recomputes `streakCount` via
`computeStreak` and persists it via `_goalRepo.save()`. `markDeferred` does not
contain this block. The docstring on `markDeferred` defers streak behaviour to
Phase 10, but because the event is already stored as `skipped`, `computeStreak`
will break the streak on the next schedule generation call — the in-memory
`Goal.streakCount` and the UI just won't reflect this until the next generation
cycle, and `GoalRepository` is never updated for the current session.

For consistency with `markSkipped`, the same streak write-back block should be
added to `markDeferred`, or the docstring should explicitly document why the streak
is intentionally left stale and note the inconsistency.

```dart
// Add inside markDeferred's try block, after _logRepo.append():
if (chunk.goalId != null && chunk.goalId!.isNotEmpty) {
  final goal = await _goalRepo.getById(chunk.goalId!);
  if (goal != null && goal.goalType == GoalType.habit) {
    final due = ScheduleGeneratorService.computeDueWeekdays(
      goal.frequencyPerWeek ?? 7,
    );
    final updatedLogs = await _logRepo.getByGoalId(goal.id);
    goal.streakCount = ScheduleGeneratorService.computeStreak(
      goal.id, due, updatedLogs,
    );
    await _goalRepo.save(goal);
  }
}
```

---

## Info

### IN-01: Dead singularization branch in `_outcomeRationale`

**File:** `lib/services/schedule_generator.dart:146`

**Issue:** Line 145 returns `'Deadline tomorrow'` when `days == 1`, so the
`days == 1 ? "" : "s"` ternary on line 146 can never evaluate to `""`. The
singular branch is unreachable dead code.

**Fix:** Replace with a plain `"s"`:

```dart
return 'Deadline in $days days';
```

### IN-02: `init()` sets `_loading = true` without notifying listeners

**File:** `lib/providers/schedule_notifier.dart:59`

**Issue:** `_loading` is set to `true` on line 60 before the first `await`, but
`notifyListeners()` is only called once at the end (line 66). Any consumer that
checks `isLoading` will never see the `true` state because no rebuild is triggered
at that point. The single call at completion is correct for the final state, but the
intermediate loading state is invisible to the UI.

**Fix:** Add `notifyListeners()` immediately after setting `_loading = true`:

```dart
Future<void> init() async {
  _loading = true;
  notifyListeners(); // ← broadcast the loading state
  _todaySchedule = await _repo.getTodaysSchedule();
  _loading = false;
  _resetIfDayChanged();
  WidgetsBinding.instance.addObserver(this);
  notifyListeners();
}
```

### IN-03: T-09-02 test comment claims "strictly more" chunks but assertion uses `>=`

**File:** `test/services/schedule_generator_test.dart:519`

**Issue:** The test comment at line 519 says `"Expected: B gets >= A's chunks and
strictly more in this setup"`, but the computed demands are equal in this scenario
(both goals have `demand = 2` on Monday with the 2-log setup), so the test passes
trivially with the `>=` assertion without proving the sorting actually works. A
reader of the comment would expect the test to demonstrate a strict ordering, but
it does not.

**Fix:** Either update the comment to say `">= A's chunks in this setup (equal
demand at Monday start)"`, or adjust the log count so `demand_B > demand_A`
(e.g., add a third completed log for goal A this week to reduce its remaining hours
below the level that rounds to the same demand).

### IN-04: Wrong date in test comment (`2026-06-06` is a Saturday, not Friday)

**File:** `test/providers/schedule_notifier_engine_test.dart:197`

**Issue:** Line 197 comment reads: `"due days (Wed 2026-06-03 and Fri 2026-06-06)"`.
`2026-06-06` is a Saturday (weekday 6), not a Friday. The actual log in the test
uses `'2026-06-05'` (Friday, weekday 5), which is correct. The same comment also
states `"Today = Mon 2026-06-09"` but `testDate` is `DateTime(2026, 6, 8)` (Monday
the 8th). The log dates and the code are correct; only the prose comment is wrong.

**Fix:** Correct the comment:

```dart
// due days (Wed 2026-06-03 and Fri 2026-06-05). Today = Mon 2026-06-08
```

---

_Reviewed: 2026-06-11T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
