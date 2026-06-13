---
phase: 05-quarterly-review
plan: "02"
subsystem: quarterly-review-ui
tags: [flutter, charts, fl_chart, quarterly-review, page-view, reorderable-list]
dependency_graph:
  requires: ["05-01"]
  provides: ["quarterly-review-screen", "data-section", "reflection-section", "adjustments-section"]
  affects: ["goals-notifier", "quarterly-snapshot-repository"]
tech_stack:
  added: []
  patterns:
    - "PageView with NeverScrollableScrollPhysics for section and question navigation"
    - "ReorderableListView.builder with ReorderableDelayedDragStartListener for drag-to-reorder"
    - "AnimatedSwitcher for archive prompt appear/dismiss"
    - "AnimatedContainer step dots (OnboardingScreen pattern)"
    - "fl_chart PieChart with centerSpaceRadius=60 for donut chart"
    - "fl_chart BarChart with per-ISO-week bar groups"
key_files:
  created:
    - lib/screens/quarterly_review/widgets/donut_chart.dart
    - lib/screens/quarterly_review/widgets/bar_chart_weekly.dart
    - lib/screens/quarterly_review/widgets/reflection_question_card.dart
    - lib/screens/quarterly_review/widgets/goal_adjustment_tile.dart
    - lib/screens/quarterly_review/sections/data_section.dart
    - lib/screens/quarterly_review/sections/reflection_section.dart
    - lib/screens/quarterly_review/sections/adjustments_section.dart
    - test/screens/quarterly_review_test.dart
  modified:
    - lib/screens/quarterly_review/quarterly_review_screen.dart
    - lib/providers/goals_notifier.dart
decisions:
  - "GoalsNotifier._colorPalette exposed as public static colorPalette for chart color fallback (Pitfall 3 fix)"
  - "AdjustmentsSection maintains _dismissedPrompts set to allow 'Keep' to dismiss archive prompt without changing completionRates"
  - "QuarterlyReviewScreen uses Navigator.of(context).pop() (not context.pop()) for compatibility in test and runtime environments"
  - "ReflectionSection step dots use 5 dots matching question count, not 3 (section count is in outer screen)"
metrics:
  duration: "12 minutes"
  completed: "2026-04-07"
  tasks: 2
  files: 10
---

# Phase 5 Plan 02: Quarterly Review UI Summary

Full quarterly review screen with data visualization (hero stat, donut chart, bar chart), 5-question guided reflection flow with tap-to-pick answers, and drag-to-reorder goal adjustments that persist a QuarterlySnapshot on finish.

## What Was Built

### Task 1: Chart Widgets and DataSection (commit cc0287b)

**DonutChart** (`lib/screens/quarterly_review/widgets/donut_chart.dart`):
- `PieChart` wrapper with `centerSpaceRadius: 60`, `sectionsSpace: 2`
- One `PieChartSectionData` per goal using `hexToColor()` imported from `chunk_card.dart`
- "Time not spent" slice using `colorScheme.outlineVariant`
- Legend column below chart: `CircleAvatar(radius: 6)` + goal name + percentage
- Null-safe color fallback via `GoalsNotifier.colorPalette` (public accessor added)

**WeeklyBarChart** (`lib/screens/quarterly_review/widgets/bar_chart_weekly.dart`):
- `BarChart` in `SizedBox(height: 180)`, entries sorted by date key ascending
- Week axis labels using `DateFormat('MMM d')` at `fontSize: 9` (narrow exception per UI-SPEC)
- `colorScheme.primary` bar fill, `borderRadius: 4`, no grid, no border

**DataSection** (`lib/screens/quarterly_review/sections/data_section.dart`):
- Hero stat: `titleLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 48)`
- Label: "chunks completed this quarter" with `onSurfaceVariant` color
- DonutChart → WeeklyBarChart → top-3 goals (sorted by chunk count desc)
- "Next: Reflect" ElevatedButton with `EdgeInsets.fromLTRB(16, 24, 16, 48)`

**Widget tests** (`test/screens/quarterly_review_test.dart`): 6 initial tests

### Task 2: Reflection, Adjustments, and Full Screen (commit d7d3f56)

**ReflectionQuestionCard** (`lib/screens/quarterly_review/widgets/reflection_question_card.dart`):
- Stateful widget with `ActionChip` suggestions and "Other..." `TextButton` toggle
- Inline `TextField` with `Done` button; `onSubmitted` also fires `onAnswered`
- Card background: `colorScheme.surfaceContainerHighest`
- Question text: `headlineSmall`

**GoalAdjustmentTile** (`lib/screens/quarterly_review/widgets/goal_adjustment_tile.dart`):
- Left color bar (width: 5), goal name, drag handle with `ReorderableDelayedDragStartListener`
- Archive prompt via `AnimatedSwitcher(duration: 200ms, switchInCurve: Curves.easeIn)`
- "Archive" button uses `colorScheme.error` foreground color
- Copy: "This one rarely made it in — archive it?"

**ReflectionSection** (`lib/screens/quarterly_review/sections/reflection_section.dart`):
- 5 fixed questions with data-driven suggestions per question index
- Nested `PageView` with `NeverScrollableScrollPhysics`, programmatic `nextPage` on answer
- Step dots (5 dots, `AnimatedContainer` 200ms, active = `colorScheme.primary`)
- "A few questions" section heading; `onComplete` fires after last question

**AdjustmentsSection** (`lib/screens/quarterly_review/sections/adjustments_section.dart`):
- `ReorderableListView.builder` with `GoalAdjustmentTile` per visible goal
- Archive prompt for goals with `completionRates[goalId] <= 0.20`
- `_dismissedPrompts` set tracks "Keep" taps to dismiss prompts
- On "Finish review": archives goals, calls `reorderAll`, persists `QuarterlySnapshot` via `HiveQuarterlySnapshotRepository().append()`
- `_isSaving` guard prevents double-tap; button shows "Saving..." while in progress
- Error state shows retry message and "Retry" button

**QuarterlyReviewScreen** (replaced stub):
- `initState` loads logs via `HiveCompletionLogRepository().getAll()` and latest snapshot
- Runs all `QuarterlyAggregationService` methods to produce aggregated data
- Period: `latestSnapshot.periodEndYmd` → today, or earliest log → today for first review
- Empty state: "Not enough data yet" + body text when no data
- AppBar: "Your quarter" title, close (X) leading icon, elevation 0
- Outer `PageView` with `NeverScrollableScrollPhysics` + 3-dot section indicator
- Section 1 onNext → Section 2; Section 2 onComplete passes answers → Section 3

**Widget tests**: 15 tests total, all passing

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing] GoalsNotifier._colorPalette made public**
- **Found during:** Task 1 — DonutChart needed fallback colors for goals with null color
- **Issue:** `_colorPalette` was private static, inaccessible from chart widgets
- **Fix:** Added `static const List<String> colorPalette = _colorPalette` public accessor
- **Files modified:** `lib/providers/goals_notifier.dart`
- **Commit:** cc0287b

**2. [Rule 1 - Bug] AdjustmentsSection reorder logic fixed**
- **Found during:** Task 2 implementation — first draft had duplicate `_showArchivePrompt` method
- **Issue:** Initial draft accidentally defined the method twice and referenced undefined `_showArchivePromptChecked`
- **Fix:** Rewrote `adjustments_section.dart` cleanly with single `_showArchivePrompt` + separate `_dismissedPrompts` set for Keep tracking
- **Files modified:** `lib/screens/quarterly_review/sections/adjustments_section.dart`
- **Commit:** d7d3f56

## Known Stubs

None. All plan goals achieved with live data wired through.

## Self-Check: PASSED
