---
phase: 11-honest-long-loop
plan: "01"
subsystem: quarterly-review
tags:
  - review
  - donut-chart
  - priority
  - tdd
dependency_graph:
  requires:
    - "10-close-the-day/10-01 (commitment attribution in completion logs)"
    - "09-an-engine-that-budgets/09-01 (priorityWeight in schedule generator)"
  provides:
    - "DonutChart with 3-set slice classification (REVIEW-01)"
    - "GoalsNotifier.reorderAllWithPriority (REVIEW-02 data layer)"
  affects:
    - "lib/screens/quarterly_review/quarterly_review_screen.dart (stub empty lists — wired in Plan 02)"
tech_stack:
  added: []
  patterns:
    - "3-set id classification loop (active goal ids / archived goal ids / commitment block ids / Other catch-all)"
    - "Linear-spread priorityWeight formula: high - (high - low) * i / (n - 1)"
    - "Zero-value slice guard: if (count > 0) per UI-SPEC"
key_files:
  created:
    - test/providers/goals_notifier_priority_test.dart
  modified:
    - lib/screens/quarterly_review/widgets/donut_chart.dart
    - lib/screens/quarterly_review/sections/data_section.dart
    - lib/providers/goals_notifier.dart
    - lib/screens/quarterly_review/quarterly_review_screen.dart
    - test/screens/quarterly_review_test.dart
    - test/services/schedule_generator_test.dart
decisions:
  - "Zero-value slices omitted for all slice types including Time not spent (UI-SPEC §Donut Chart Slice Contract)"
  - "percentage-sum test uses inInclusiveRange(99,101) — toStringAsFixed(0) per-slice rounding produces 99-101 sum, not exactly 100"
  - "quarterly_review_screen.dart DataSection call site uses archivedGoals: const [] and commitmentBlocks: const [] as stubs until Plan 02 wires actual data"
  - "0xFF607D8B palette collision risk accepted in v1 (rarity of 8+ active goals — documented in code comment)"
metrics:
  duration: "18 minutes"
  completed: "2026-06-11"
  tasks: 3
  files: 6
---

# Phase 11 Plan 01: Wave 0 Scaffolds + REVIEW-01 Donut Fix + REVIEW-02 Data Layer Summary

**One-liner:** 3-set commitment/archived/other slice classification for DonutChart plus linear-spread priorityWeight write-back in GoalsNotifier.reorderAllWithPriority, driven by TDD RED/GREEN cycle.

## What Was Built

### Task 1: RED Test Scaffolds

Added test scaffolds for both requirements before implementing production code:

- **`test/screens/quarterly_review_test.dart`:** Updated all existing DonutChart/DataSection call sites to include `archivedGoals: const []` and `commitmentBlocks: const []` (post-Task-2 required params). Added 3 new tests: commitment legend row, archived goal legend row with "(archived)" suffix, and a percentage-sum test.
- **`test/services/schedule_generator_test.dart`:** Added `'higher priorityWeight goal appears before lower priorityWeight goal in generated chunks'` test — passed low-priority goal first to confirm ordering by weight, not input order.
- **`test/providers/goals_notifier_priority_test.dart`:** Created new test file with `_InMemoryGoalRepository`, testing `reorderAllWithPriority` writes correct sortOrder (0/1/2) and priorityWeight (0.75/0.5/0.25), plus single-goal (0.75) and monotonically-decreasing cases.

RED state confirmed: `goals_notifier_priority_test.dart` failed with compilation error (`reorderAllWithPriority not defined`); `quarterly_review_test.dart` failed on `archivedGoals` parameter not found.

### Task 2: DonutChart 3-Set Slice Classification (REVIEW-01 GREEN)

**`lib/screens/quarterly_review/widgets/donut_chart.dart`:**
- Added `archivedGoals` and `commitmentBlocks` required constructor params
- Replaced active-goal-only loop with full 3-set classification:
  - Active goal slices: iterate `goals`, skip zero counts
  - Archived goal slices: keyed on `archivedGoalMap`, labeled `'${name} (archived)'`
  - Commitment chunks: accumulate into `commitmentTotal`
  - Unknown ids: accumulate into `otherTotal`
- Added Commitments slice (`Color(0xFF607D8B)`) — only when commitmentTotal > 0
- Added Other catch-all slice (`Color(0xFFBDBDBD)`) — only when otherTotal > 0
- Added zero-value guard on "Time not spent" slice per UI-SPEC
- Existing `totalValue` fold is correct as-is (covers all keys in goalChunkTotals)

**`lib/screens/quarterly_review/sections/data_section.dart`:**
- Added `archivedGoals` and `commitmentBlocks` required constructor params
- Forwarded both to DonutChart call site

**`lib/screens/quarterly_review/quarterly_review_screen.dart`:**
- Added stub `archivedGoals: const []` and `commitmentBlocks: const []` to DataSection call to keep it compiling — Plan 02 will wire actual data loading

### Task 3: GoalsNotifier.reorderAllWithPriority (REVIEW-02 GREEN)

**`lib/providers/goals_notifier.dart`:**
- Added `reorderAllWithPriority(List<String> orderedIds)` immediately after `reorderAll`
- Writes `sortOrder = i` and `priorityWeight = high - (high - low) * i / (n - 1)` for each goal
- Single-goal special case: `priorityWeight = 0.75`
- Existing `reorderAll` left unchanged (backward compatible with existing AdjustmentsSection widget tests)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] percentage-sum test uses inInclusiveRange(99, 101) instead of equals(100)**
- **Found during:** Task 2 GREEN verification
- **Issue:** `toStringAsFixed(0)` rounds each percentage to the nearest integer independently; 20/30=66.67→67, 5/30=16.67→17, 5/30=16.67→17 sums to 101. The plan's test body expected `equals(100)`.
- **Fix:** Changed expectation to `inInclusiveRange(99, 101)` with reason comment explaining the rounding.
- **Files modified:** `test/screens/quarterly_review_test.dart`
- **Commit:** 9c3fe9b

**2. [Rule 3 - Blocking] quarterly_review_screen.dart DataSection call site compilation**
- **Found during:** Task 2 — DataSection now has required params
- **Issue:** `quarterly_review_screen.dart` calls DataSection without the new `archivedGoals` and `commitmentBlocks` params, causing a compilation error. Plan 01 scopes only DonutChart/DataSection/GoalsNotifier; the screen's data loading is Plan 02.
- **Fix:** Added stub `archivedGoals: const []` and `commitmentBlocks: const []` with a code comment noting Plan 02 will wire actual data.
- **Files modified:** `lib/screens/quarterly_review/quarterly_review_screen.dart`
- **Commit:** 9c3fe9b

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| `archivedGoals: const []` | `lib/screens/quarterly_review/quarterly_review_screen.dart` | ~158 | Plan 02 will load archived goals via `GoalsNotifier.getArchivedGoals()` and wire them to DataSection |
| `commitmentBlocks: const []` | `lib/screens/quarterly_review/quarterly_review_screen.dart` | ~159 | Plan 02 will read `CommitmentsNotifier.blocks` and wire them to DataSection |

These stubs do not block Plan 01's goals (DonutChart/DataSection/GoalsNotifier implementations are complete and tested). The screen-level data loading is Plan 02's scope.

## Verification Results

- `flutter test test/screens/quarterly_review_test.dart` — 18/18 pass (REVIEW-01 commitment/archived/percentage-sum tests green)
- `flutter test test/providers/goals_notifier_priority_test.dart` — 3/3 pass (REVIEW-02 weight write-back green)
- `flutter test test/services/schedule_generator_test.dart` — 26/26 pass (REVIEW-02 ordering green, all prior tests preserved)
- `flutter test` (full suite) — 157/157 pass
- `flutter analyze` — 0 errors, 0 warnings (5 pre-existing info-level `onReorder` deprecation notices, all pre-existing)

## Self-Check: PASSED
