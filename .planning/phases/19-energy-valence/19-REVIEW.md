---
phase: 19-energy-valence
reviewed: 2026-06-14T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - lib/data/models/energy_valence.dart
  - lib/data/models/goal.dart
  - lib/data/database/migrations.dart
  - lib/screens/goals/goal_form_sheet.dart
  - lib/screens/goals/widgets/goal_card.dart
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/screens/schedule/widgets/swipeable_chunk_card.dart
  - lib/screens/schedule/schedule_screen.dart
  - lib/screens/onboarding/onboarding_screen.dart
findings:
  critical: 2
  warning: 2
  info: 1
  total: 5
status: issues_found
---

# Phase 19: Code Review Report

**Reviewed:** 2026-06-14
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 19 adds `EnergyValence` (gives / neutral / costs) and `emojiTag` to the `Goal` model via an additive Hive schema migration (7→8), a valence `SegmentedButton` + emoji picker in the goal form, `_ValenceBadge` / `_ValenceChip` display widgets on goal cards and chunk cards, and a new onboarding Screen 4 ("What gives you energy?").

The migration and model layer are structurally sound: the no-op `_migration7to8` is correct for additive nullable fields, the `assert` invariant in `runMigrations` protecting against version/migration count skew is present and correct, and the `energyValence` getter default-to-neutral path is correct. The goal form, chunk card, and schedule screen lookup chains are correct.

Two blockers were found, both in the onboarding flow. One is a silent data-loss bug when the user selects "habit" as their goal type on Screen 1 of onboarding: the `_completeOnboarding` dispatch logic uses a type filter that silently drops this goal. The second is that quick-added goals on Screen 4 appear to have a deselectable "Energizing" chip but the deselection has no effect, meaning the chip is misleading — goals added via "Add something energizing" are always saved with `gives` valence regardless of user interaction.

---

## Critical Issues

### CR-01: Screen 1 habit-type goal silently dropped during onboarding completion

**File:** `lib/screens/onboarding/onboarding_screen.dart:102-107`

**Issue:** `_completeOnboarding` dispatches Screen 1 goal persistence using:

```dart
final screen1Goal = pendingGoals
    .where((g) => g.goalTypeIndex != GoalType.habit.index)
    .firstOrNull;
if (screen1Goal != null) {
  screen1Goal.color = goalsNotifier.autoColor();
  await goalsNotifier.saveGoal(screen1Goal);
}
```

The filter `goalTypeIndex != GoalType.habit.index` was designed to exclude the Screen 3 habit from the Screen 1 save path. However, `_Screen1` presents `GoalTypePicker` which exposes all three goal types including `GoalType.habit`. When a user selects habit on Screen 1 and enters a name, `_getPendingGoalsForScreen4()` creates a valid `Goal` with `goalTypeIndex = GoalType.habit.index`. That goal then:

- Is excluded from step 1 (filter removes it)
- Is excluded from step 3 (only saves `_screen3Habit`, which is a different field)
- Is therefore never persisted

If the user also completes Screen 3, only the Screen 3 habit is saved. The Screen 1 habit is silently discarded. There is no error, no warning to the user. Any `energyValenceIndex` marking on Screen 4 for that goal's UUID also silently fails (step 3.5 looks it up in `goalsNotifier.goals`, does not find it, and skips it).

**Fix:** Save the Screen 1 goal unconditionally based on its position in `pendingGoals`, not its type. The Screen 1 goal is always `pendingGoals[0]` when present (since `_getPendingGoalsForScreen4` adds the Screen 1 goal first and the Screen 3 habit second). Use positional identity rather than type filtering:

```dart
// (1) Save Screen 1 goal if filled.
// pendingGoals[0] is always the Screen 1 goal (if present); [1] is the Screen 3 habit.
final screen1Goal = pendingGoals.isNotEmpty ? pendingGoals[0] : null;
// Only save if it is the Screen 1 goal — exclude the habit if Screen 3 added it as [0].
// Safer: track screen1Goal separately in state rather than filtering by type.
if (screen1Goal != null && screen1Goal != _screen3Habit) {
  screen1Goal.color = goalsNotifier.autoColor();
  await goalsNotifier.saveGoal(screen1Goal);
}
```

The most robust fix is to keep a direct reference to the Screen 1 `Goal` object separately from the cache list, so no type-based discrimination is needed. Alternatively, if Screen 1 must exclude habit (by design), the `GoalTypePicker` call in `_Screen1` should be restricted to non-habit types to prevent the inconsistent state from arising in the first place.

---

### CR-02: Screen 4 quick-added goal "Energizing" chip is permanently stuck selected — user interaction has no effect

**File:** `lib/screens/onboarding/onboarding_screen.dart:745-759` and `124-127`

**Issue:** When a user adds a goal via the "Add something energizing" quick-add flow, `_confirmQuickAdd` creates the goal with `energyValenceIndex: EnergyValence.gives.index` already set (line 695). The display logic for the `FilterChip` then computes:

```dart
final isMarked =
    _markedGoalIds.contains(goal.id) ||
    goal.energyValenceIndex == EnergyValence.gives.index;
```

Because `goal.energyValenceIndex == EnergyValence.gives.index` is always `true` for quick-added goals (baked in at creation), `isMarked` is permanently `true`. The user can tap the chip to deselect it — `_toggleMark(goal.id, false)` executes and removes the ID from `_markedGoalIds` — but the next `setState` re-evaluates `isMarked` and it flips back to `true` because of the `||` branch. The chip visually resets to selected on the very next frame.

Additionally, `_completeOnboarding` step 3.5 saves every goal in `_quickGoals` with `gives` unconditionally (line 124-127), so even if the chip logic were fixed, the save path would still ignore any deselection. The user is presented with an interactive control that has no observable or persisted effect.

**Fix (two parts):**

Part A — Fix `isMarked` to not use `energyValenceIndex` as the truth source; use only `_markedGoalIds`, and pre-populate it with quick-goal IDs at creation time so they start as selected but can be toggled:

```dart
void _confirmQuickAdd() {
  final name = _quickAddController.text.trim();
  if (name.isEmpty) return;
  final goal = Goal(
    name: name,
    goalTypeIndex: GoalType.timeTarget.index,
    weeklyHourBudget: 3.0,
    // Do NOT pre-set energyValenceIndex here; let marking control it.
  );
  setState(() {
    _quickGoals.add(goal);
    _markedGoalIds.add(goal.id); // pre-mark as energizing
    _quickAddController.clear();
    _showQuickAdd = false;
  });
}
```

Part B — In `_completeOnboarding`, only apply `gives` to goals whose IDs are in the combined marked set (both pending-goal marks and quick-goal marks), rather than saving every quick-goal unconditionally:

```dart
// Replace unconditional quick-goal save with mark-based save:
for (final goal in _screen4QuickGoals) {
  // Only apply gives if the user left it marked.
  if (_screen4MarkedGoalIds.contains(goal.id)) {
    goal.energyValenceIndex = EnergyValence.gives.index;
  }
  await goalsNotifier.saveGoal(goal);
}
```

---

## Warnings

### WR-01: `energyValence` getter has no bounds guard — corrupt index causes `RangeError` crash

**File:** `lib/data/models/goal.dart:98-99`

**Issue:**

```dart
EnergyValence get energyValence =>
    EnergyValence.values[energyValenceIndex ?? 0];
```

`EnergyValence.values` has exactly 3 entries (indices 0–2). If `energyValenceIndex` holds a value outside this range — e.g. from a future enum extension on a newer schema read by rolled-back code, or from database corruption — this throws `RangeError` at the point the getter is called, which is in multiple display widgets. The `GoalType.goalType` getter on line 60 has the same unguarded pattern and is a pre-existing issue; the new `energyValence` getter repeats it.

**Fix:** Clamp or guard the index:

```dart
EnergyValence get energyValence {
  final idx = energyValenceIndex ?? 0;
  if (idx < 0 || idx >= EnergyValence.values.length) {
    return EnergyValence.neutral; // safe default
  }
  return EnergyValence.values[idx];
}
```

---

### WR-02: In-flight quick-add text silently discarded when user taps "Let's go" on Screen 4

**File:** `lib/screens/onboarding/onboarding_screen.dart:704-708` and `767-795`

**Issue:** When `_showQuickAdd` is `true` (the inline text field is visible) and the user taps "Let's go" without pressing the confirm icon or submitting, `_onComplete` is called immediately. The `_quickAddController` text is neither committed to `_quickGoals` nor cleared. The goal the user was typing is silently dropped, and there is no warning. This is particularly likely on mobile where a user might tap "Let's go" after typing the name but before tapping the checkmark.

**Fix:** Attempt to commit the in-progress quick-add before completing:

```dart
void _onComplete() {
  if (_showQuickAdd && _quickAddController.text.trim().isNotEmpty) {
    _confirmQuickAdd(); // commit the in-progress entry
  }
  widget.onComplete(
    Set<String>.from(_markedGoalIds),
    List<Goal>.from(_quickGoals),
  );
}
```

---

## Info

### IN-01: `_lookupGoal*` helpers in `ScheduleScreen` perform repeated linear scans per chunk

**File:** `lib/screens/schedule/schedule_screen.dart:228-280`

**Issue:** `_lookupGoalColor`, `_lookupGoalName`, `_lookupGoalPriorityWeight`, `_lookupGoalValence`, and `_lookupGoalEmojiTag` each independently call `context.read<GoalsNotifier>().goals` and run a `.where((g) => g.id == chunk.goalId).firstOrNull` scan. For a typical schedule with N chunks and M goals, this is 5×N×M comparisons per `build()`. The new `_lookupGoalValence` and `_lookupGoalEmojiTag` added in Phase 19 each add another full scan per chunk, bringing the per-chunk lookup count to 5. This is not a current performance issue given typical data sizes, but the pattern degrades proportionally as goals and chunks grow.

**Suggestion:** Consolidate into a single `_resolveGoal(context, chunk)` helper that returns one nullable `Goal` object, and call it once per `_buildSwipeableCard`. All five attributes are then read from the single resolved goal:

```dart
Goal? _resolveGoal(BuildContext context, ScheduledChunk chunk) {
  if (chunk.goalId == null) return null;
  return context.read<GoalsNotifier>().goals
      .where((g) => g.id == chunk.goalId)
      .firstOrNull;
}
```

---

_Reviewed: 2026-06-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
