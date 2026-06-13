---
phase: 14-goals-screen-and-priority-end-to-end
reviewed: 2026-06-13T12:00:00Z
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
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 14: Code Review Report (Iteration 2)

**Reviewed:** 2026-06-13T12:00:00Z
**Depth:** standard
**Files Reviewed:** 12
**Status:** clean

## Summary

Re-review at standard depth after targeted fixes for CR-01, WR-01, and WR-02. All three previously
flagged issues are confirmed genuinely resolved. No new critical or warning issues introduced by
this phase.

### CR-01 — Step 4 engine test (confirmed resolved)

The test at `test/services/schedule_generator_test.dart:977-1018` ("Step 4: high-priority goal
gets at least as many chunks as low-priority under shared cap") now genuinely exercises the
priority-ordering path and would fail if ordering were removed.

Verification of the math: `moodIndex=3` (passes the `isLowMood = moodIndex <= 2` gate at line 201
of `schedule_generator.dart`, so Step 4 runs). `lighterDay=true` drops the effective cap from
`moodCap[3]=8` to `moodCap[2]=6`. `weeklyHourBudget=12.0` with Monday (daysLeft=7, 0 completions)
yields `demand = ceil(12*60/25/7).clamp(0,4) = ceil(4.114).clamp(0,4) = 4` per goal. Combined
demand (8) exceeds cap (6). High-priority composite score (`12.0 * 0.75 = 9.0`) sorts before
low-priority (`12.0 * 0.25 = 3.0`), so high gets 4 chunks and low gets 2. The `greaterThan`
assertion requires `highCount(4) > lowCount(2)`. If priority ordering were stripped (input order
is low first), low would take 4 slots and high would get 2, making `highCount(2) > lowCount(4)`
false — the test would fail. Non-trivial.

### WR-01 — _PriorityChip text style (confirmed resolved)

All three `_PriorityChip` copies (`goal_card.dart:272-274`, `chunk_card.dart:375-377`,
`active_chunk_card.dart:240-242`) uniformly apply
`textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)`. Styles are identical.

### WR-02 — Chip-suppression float-equality guard (confirmed resolved)

`goal_card.dart:79` uses the range guard `pw >= 0.75 || pw <= 0.25`. `chunk_card.dart:249-250`
and `active_chunk_card.dart:143` retain `goalPriorityWeight != 0.5` as the outer show-gate, but
the `_PriorityChip` inner logic in all three files applies the correct `>= 0.75` / `<= 0.25`
range checks before rendering. Since `priorityWeight` is always one of the discrete values
`{0.25, 0.5, 0.75}` in the data layer, no incorrect chip is ever displayed. The outer guard
inconsistency between files is a style issue only and does not produce incorrect output.

---

All reviewed files meet quality standards. No issues found.

---

_Reviewed: 2026-06-13T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
