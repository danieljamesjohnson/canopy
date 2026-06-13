---
phase: 14-goals-screen-and-priority-end-to-end
reviewed: 2026-06-13T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - lib/services/schedule_generator.dart
  - lib/screens/goals/goals_screen.dart
  - lib/screens/goals/widgets/goal_card.dart
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/screens/schedule/widgets/swipeable_chunk_card.dart
  - lib/screens/home/widgets/active_chunk_card.dart
  - lib/screens/schedule/schedule_screen.dart
  - test/services/schedule_generator_test.dart
  - test/screens/chunk_card_priority_badge_test.dart
  - test/screens/goal_card_priority_chip_test.dart
  - test/screens/goals_screen_heading_test.dart
  - test/screens/goal_card_drag_handle_test.dart
findings:
  critical: 1
  warning: 2
  info: 2
  total: 5
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-06-13
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Reviewed the priority scheduling engine changes (Steps 2 and 4), the Goals screen heading and drag-handle additions, the `_PriorityChip` triplicated across three card variants, and all new tests. The engine logic itself is sound: the `priorityWeight ?? 0.5` null-coalescing default is applied correctly at every call site, and the composite score `remainingHours × priorityWeight` in Step 4 correctly makes priority a primary ordering factor rather than a tiebreaker. The `reorderAllWithPriority` formula produces monotonically distinct weights across all `n >= 2` scenarios. The `onReorderItem` callback semantics (pre-adjusted `newIndex`) are correctly handled in `goals_screen.dart`.

One test is a confirmed false pass: it exercises time-target scheduling at `moodIndex: 1`, which the engine guards off entirely, making both count assertions trivially `0 >= 0`. One visual inconsistency across the triplicated `_PriorityChip` components diverges the chip text size between `GoalCard` and both chunk card variants.

---

## Critical Issues

### CR-01: Step 4 time-target priority test passes trivially at moodIndex=1 — validates nothing

**File:** `test/services/schedule_generator_test.dart:977-1005`

**Issue:** The test `'Step 4: high-priority goal gets at least as many chunks as low-priority under shared cap'` calls `generate()` with `moodIndex: 1`. In the engine, `isLowMood = moodIndex <= 2`, and Step 4 is guarded by `if (!isLowMood)` (line 315 of `schedule_generator.dart`). At `moodIndex: 1`, Step 4 never executes. Both `highCount` and `lowCount` resolve to `0`, and `expect(0, greaterThanOrEqualTo(0))` trivially passes. The test was supposed to validate that a high-priority time-target goal wins cap slots over a low-priority one, but it actually exercises nothing — neither goal is ever scheduled.

**Fix:** Change `moodIndex: 1` to a value that enables Step 4, for example `moodIndex: 3`. At mood 3 with `lighterDay: false`, the cap is 8. Both `weeklyHourBudget: 2.0` goals have demand `ceil(2.0×60/25/7) = ceil(0.69) = 1` chunk each, so both get 1 chunk regardless of priority (equal demand is satisfied). To actually exercise the priority tiebreaker under a shared cap, either use a larger budget so demand > remaining cap, or use the same structure as `T-09-06` (fill cap with habits first, leaving 1 slot). The existing `T-09-06` already covers the 1-slot competition case; this test needs a distinct, valid scenario:

```dart
test('Step 4: high-priority goal gets at least as many chunks as low-priority under shared cap', () {
  final highTT = makeTimeTarget(
    name: 'High TT',
    weeklyHourBudget: 2.0,
    priorityWeight: 0.75,
  );
  final lowTT = makeTimeTarget(
    name: 'Low TT',
    weeklyHourBudget: 2.0,
    priorityWeight: 0.25,
  );

  final result = sut.generate(
    goals: [lowTT, highTT],
    blocks: [],
    moodIndex: 3,  // mood 3+ required — Step 4 is disabled at mood 1-2
    date: monday,
    completionLogs: [],
    lighterDay: false,
  );
  final highCount = result
      .where((c) => c.chunkType == ChunkType.work && c.goalId == highTT.id)
      .length;
  final lowCount = result
      .where((c) => c.chunkType == ChunkType.work && c.goalId == lowTT.id)
      .length;
  expect(highCount, greaterThanOrEqualTo(lowCount),
    reason: 'High-priority goal must get at least as many chunks as low-priority');
});
```

---

## Warnings

### WR-01: _PriorityChip text style diverges between GoalCard and chunk card variants

**File:** `lib/screens/goals/widgets/goal_card.dart:271` vs `lib/screens/schedule/widgets/chunk_card.dart:375` and `lib/screens/home/widgets/active_chunk_card.dart:240`

**Issue:** The three intentionally-duplicated `_PriorityChip` classes use different `TextTheme` slots for the label:

- `goal_card.dart`: `textTheme.labelMedium` (larger)
- `chunk_card.dart`: `textTheme.labelSmall` (smaller)
- `active_chunk_card.dart`: `textTheme.labelSmall` (smaller)

In Material 3, `labelMedium` is 12sp and `labelSmall` is 11sp. This means the "High" / "Low" chip in `GoalCard` renders visibly larger than the same chip in `ChunkCard` and `ActiveChunkCard`, creating an inconsistent priority indicator across the three surfaces. Because these are intentional copies (per `UI-SPEC §Component Inventory item 3`), they are expected to be pixel-identical.

**Fix:** Align all three files to the same style. `labelSmall` is the correct choice for a compact badge in a card — use it in `goal_card.dart` as well:

```dart
// goal_card.dart line 271 — change labelMedium → labelSmall
style: textTheme.labelSmall?.copyWith(
  color: onColor,
  fontWeight: FontWeight.w600,
),
```

### WR-02: Floating-point equality used to suppress the Normal priority chip in goal_card.dart

**File:** `lib/screens/goals/widgets/goal_card.dart:78`

**Issue:** `showPriorityChip = (goal.priorityWeight ?? 0.5) != 0.5` uses exact float equality to decide whether to show the chip. This is distinct from the chip's internal guard (`_PriorityChip.build` returns `SizedBox.shrink()` for values strictly between 0.25 and 0.75), so the outer guard and the chip's internal guard form a two-layer defense. The outer guard in `goal_card.dart` is additionally used to decide whether to render the secondary row at all (line 160). If a future code path produces a value like `0.5000000000000001` (e.g., the `reorderAllWithPriority` formula for a specific `n`), the chip row will be shown but the chip itself will return `SizedBox.shrink()` — producing an empty `Row` with a `SizedBox(height: 4)` spacer above it and visual blank space below the goal name.

Concretely: for `n=3` goals the formula yields `{0.75, 0.5, 0.25}` — `0.5` is exactly representable and the check passes safely. For `n=6` the middle values are `0.55` and `0.45`, neither of which compares equal to `0.5`. The current formula space is safe, but the equality guard is a fragile pattern to maintain.

**Fix:** Replace the outer guard with the same range check used inside `_PriorityChip`:

```dart
// goal_card.dart line 78
final pw = goal.priorityWeight ?? 0.5;
final showPriorityChip = pw >= 0.75 || pw <= 0.25;
```

This is robust to floating-point noise and matches the chip's own branching criteria exactly.

---

## Info

### IN-01: Test cascade assignment bypasses the Goal constructor's named parameter

**File:** `test/services/schedule_generator_test.dart:927-929`

**Issue:** The two new Phase 14 habit test objects use a cascade `..frequencyPerWeek = 7` after construction:

```dart
final highHabit = makeHabit(name: 'High Habit', priorityWeight: 0.75)
  ..frequencyPerWeek = 7;
```

`makeHabit()` at line 24 creates a `Goal` via the constructor, which accepts `frequencyPerWeek` as a named parameter. The cascade is redundant and the pattern is inconsistent with the rest of the test suite (every other frequency-setting test, e.g. `T-09-03a`, constructs `Goal` directly with `frequencyPerWeek:` in the constructor). Functionally harmless since both habits default to `frequencyPerWeek = null` → `effectiveFreq = 7` in the engine anyway.

**Fix:** Pass `frequencyPerWeek` through `makeHabit()` or construct directly, matching suite convention.

### IN-02: Dead _PriorityChip comment reference in active_chunk_card.dart

**File:** `lib/screens/home/widgets/active_chunk_card.dart:196`

**Issue:** The doc-comment on `_PriorityChip` in `active_chunk_card.dart` says "Intentionally duplicated from `goal_card.dart` and `chunk_card.dart`." The correct source files are `goal_card.dart` and `chunk_card.dart` — this is accurate — but the comment says "for file-disjoint plan parallelism (UI-SPEC §Component Inventory item 3)." There is no such section in `14-UI-SPEC.md` visible in the phase directory — the spec reference appears to be a forward-reference to a document section that was written as if it existed. This is a documentation accuracy issue rather than a code bug, but it will mislead future readers looking up the rationale.

**Fix:** Either verify the spec section exists and adjust the reference, or replace with an inline rationale:

```dart
/// Intentionally duplicated from goal_card.dart and chunk_card.dart.
/// Kept file-private to avoid cross-file widget coupling; all three copies
/// must be kept visually identical (same colors, icon sizes, text style).
```

---

_Reviewed: 2026-06-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
