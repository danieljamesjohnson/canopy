---
phase: 14-goals-screen-and-priority-end-to-end
fixed_at: 2026-06-13T00:00:00Z
review_path: .planning/phases/14-goals-screen-and-priority-end-to-end/14-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 14: Code Review Fix Report

**Fixed at:** 2026-06-13
**Source review:** .planning/phases/14-goals-screen-and-priority-end-to-end/14-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (CR-01, WR-01, WR-02)
- Fixed: 3
- Skipped: 0

## Fixed Issues

### CR-01: Step 4 time-target priority test passes trivially at moodIndex=1

**Files modified:** `test/services/schedule_generator_test.dart`
**Commits:** `67f05a0`, `dfe9fe6`
**Applied fix:** Changed `moodIndex: 1` to `moodIndex: 3` so Step 4 actually executes (Step 4 is gated by `!isLowMood`, where `isLowMood = moodIndex <= 2`). Increased `weeklyHourBudget` from 2.0h to 12.0h, which raises per-goal daily demand to 4 chunks (the per-goal daily cap in `_demandForTimeTarget`). Added `lighterDay: true` to reduce the effective cap from 8 to 6 (one mood tier lower), making combined demand (4+4=8) exceed the cap (6) so priority ordering is genuinely consequential. Changed the assertion from `greaterThanOrEqualTo` to `greaterThan` to prevent trivial satisfaction when both counts are equal. With this setup: high-priority goal (score=12.0×0.75=9.0) is sorted first and receives 4 chunks; low-priority goal (score=12.0×0.25=3.0) is sorted second and receives only 2. Reversing the priority order would make the assertion fail (2 > 4 is false). Added explanatory comments documenting the arithmetic so the test is self-verifying.

### WR-01: _PriorityChip text style diverges between GoalCard and chunk card variants

**Files modified:** `lib/screens/schedule/widgets/chunk_card.dart`, `lib/screens/home/widgets/active_chunk_card.dart`
**Commit:** `3590248`
**Applied fix:** Changed `textTheme.labelSmall` to `textTheme.labelMedium` in both `chunk_card.dart` (line 375) and `active_chunk_card.dart` (line 240). This aligns both chip copies to match `goal_card.dart` (which already used `labelMedium`) and the UI-SPEC typography table specifying 12sp w600. The `labelSmall` (11sp) copies were diverging from the authoritative spec.

### WR-02: Floating-point equality used to suppress the Normal priority chip in goal_card.dart

**Files modified:** `lib/screens/goals/widgets/goal_card.dart`
**Commit:** `d1141dc`
**Applied fix:** Replaced `final showPriorityChip = (goal.priorityWeight ?? 0.5) != 0.5` with a two-line range guard that exactly mirrors the chip's own internal branching criteria: `final pw = goal.priorityWeight ?? 0.5; final showPriorityChip = pw >= 0.75 || pw <= 0.25;`. This is robust to floating-point noise and eliminates the possibility of an empty Row being rendered when a future code path produces a value near but not exactly 0.5.

---

**Verification:** `flutter test` — 209/209 passed. `flutter analyze` — 2 pre-existing info-level warnings (underscore-prefixed local variables in `active_chunk_card_test.dart`), both present before these fixes and not introduced by them. No new issues.

---

_Fixed: 2026-06-13_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
