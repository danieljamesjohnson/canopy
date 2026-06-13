# Phase 14: Goals Screen and Priority End-to-End - Pattern Map

**Mapped:** 2026-06-13
**Files analyzed:** 10 (7 modified source + 3 new/updated test files)
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/screens/goals/goals_screen.dart` | screen/widget | event-driven (reorder → notifier) | itself (current file) | self |
| `lib/screens/goals/widgets/goal_card.dart` | component | request-response (render) | `lib/screens/home/widgets/active_chunk_card.dart` ("Now" badge pattern) | role-match |
| `lib/screens/schedule/widgets/chunk_card.dart` | component | request-response (render) | itself (current file) | self |
| `lib/screens/schedule/widgets/swipeable_chunk_card.dart` | component (passthrough wrapper) | request-response | itself (current file) | self |
| `lib/screens/home/widgets/active_chunk_card.dart` | component | request-response (render) | itself (current file) | self |
| `lib/screens/schedule/schedule_screen.dart` | screen | request-response | itself (current file) | self |
| `lib/services/schedule_generator.dart` | service | batch (pure Dart transform) | itself (current file) | self |
| `test/screens/goal_card_drag_handle_test.dart` | test (widget) | — | itself (UPDATE needed) | self |
| `test/screens/goal_card_priority_chip_test.dart` | test (widget) | — | `test/screens/goal_card_drag_handle_test.dart` | exact |
| `test/screens/chunk_card_priority_badge_test.dart` | test (widget) | — | `test/screens/goal_card_drag_handle_test.dart` | role-match |
| `test/screens/goals_screen_heading_test.dart` | test (widget) | — | `test/screens/goal_card_drag_handle_test.dart` | role-match |
| `test/services/schedule_generator_test.dart` | test (unit) | — | itself (ADD test cases) | self |

---

## Pattern Assignments

### `lib/screens/goals/goals_screen.dart` (screen, event-driven)

**Analog:** itself — current production file at `lib/screens/goals/goals_screen.dart`

**Imports pattern** (lines 1-10 of current file):
```dart
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/goal.dart';
import '../../providers/goals_notifier.dart';
import 'goal_form_sheet.dart';
import 'widgets/goal_card.dart';
```

**Heading SliverToBoxAdapter pattern** (new — insert before type-section slivers, after `allEmpty` guard):
```dart
// Source: 14-UI-SPEC.md §Goals Screen Redesign Contract
// Add as first sliver inside the `else` block, before timeTargetGoals section:
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Your goals',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Drag to prioritize. Tap to edit.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  ),
)
```

**Existing SliverToBoxAdapter analog** (lines 147-158 of goals_screen.dart — section header pattern to copy for structure):
```dart
Widget _buildSectionHeader(BuildContext context, String title) {
  final colorScheme = Theme.of(context).colorScheme;
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: colorScheme.primary,
        ),
      ),
    ),
  );
}
```

**Desktop drag handle pattern** (lines 188-201 of goals_screen.dart — REPLACE `Icons.drag_handle` with `Icons.drag_indicator`, add Tooltip + SizedBox 44×44):
```dart
// CURRENT (lines 188-201) — icon to replace:
trailing: isMobileTouch
    ? null
    : ReorderableDelayedDragStartListener(
        index: i,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: 0.6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.drag_handle,        // ← CHANGE to Icons.drag_indicator
              color: colorScheme.outline,
            ),
          ),
        ),
      ),

// REPLACEMENT for desktop branch:
Tooltip(
  message: 'Drag to reorder',
  child: ReorderableDelayedDragStartListener(
    index: i,
    child: Semantics(
      label: 'Drag to reorder',
      button: false,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: 0.6,
            child: Icon(
              Icons.drag_indicator,
              color: colorScheme.outline,
            ),
          ),
        ),
      ),
    ),
  ),
)
```

**Mobile drag handle pattern** (new — replaces `null` in isMobileTouch branch):
```dart
// Source: 14-UI-SPEC.md §Goals Screen Redesign Contract
// Replace `isMobileTouch ? null : ...` with always-visible handle:
trailing: isMobileTouch
    ? ReorderableDelayedDragStartListener(
        index: i,
        child: Semantics(
          label: 'Drag to reorder',
          button: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.drag_indicator,
              size: 20,
              color: colorScheme.outlineVariant,  // lighter than desktop
            ),
          ),
        ),
      )
    : /* desktop branch above */
```

**onReorderItem + _buildFullOrderedIds pattern** (replaces line 203-204 of goals_screen.dart):
```dart
// CURRENT (line 203-204):
onReorderItem: (oldIndex, newIndex) =>
    notifier.reorder(type, oldIndex, newIndex),

// REPLACEMENT:
onReorderItem: (oldIndex, newIndex) async {
  final reorderedGroup = [...group];
  final item = reorderedGroup.removeAt(oldIndex);
  reorderedGroup.insert(newIndex, item);
  final allOrdered = _buildFullOrderedIds(notifier, type, reorderedGroup);
  await notifier.reorderAllWithPriority(allOrdered);
},

// NEW private method on _GoalsScreenState:
// Source: 14-UI-SPEC.md §Goals Screen Redesign Contract
List<String> _buildFullOrderedIds(
  GoalsNotifier notifier,
  GoalType type,
  List<Goal> reorderedGroup,
) {
  // Display order: timeTarget, outcome, habit (matches goals_screen.dart section order).
  final timeTargetIds = type == GoalType.timeTarget
      ? reorderedGroup.map((g) => g.id).toList()
      : notifier.timeTargetGoals.map((g) => g.id).toList();
  final outcomeIds = type == GoalType.outcome
      ? reorderedGroup.map((g) => g.id).toList()
      : notifier.outcomeGoals.map((g) => g.id).toList();
  final habitIds = type == GoalType.habit
      ? reorderedGroup.map((g) => g.id).toList()
      : notifier.habitGoals.map((g) => g.id).toList();
  return [...timeTargetIds, ...outcomeIds, ...habitIds];
}
```

---

### `lib/screens/goals/widgets/goal_card.dart` (component, render)

**Analog:** itself (current file) + `active_chunk_card.dart` lines 113-132 for the "Now" badge — the existing badge `Container` is the direct analog for `_PriorityChip`.

**Imports pattern** (lines 1-3 of goal_card.dart — no new imports needed):
```dart
import 'package:flutter/material.dart';
import '../../../data/models/goal.dart';
import '../../../utils/time_format.dart';
```

**_PriorityChip private widget pattern** (new, file-private — add below `GoalCard` class):
```dart
// Source: 14-UI-SPEC.md §Priority Visual Language
// Analog: "Now" badge in active_chunk_card.dart lines 113-132 (same Container shape)
class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priorityWeight});

  final double priorityWeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final IconData icon;
    final Color chipColor;
    final Color onColor;
    final String label;

    if (priorityWeight >= 0.75) {
      icon = Icons.arrow_upward;
      chipColor = colorScheme.primaryContainer;
      onColor = colorScheme.onPrimaryContainer;
      label = 'High';
    } else if (priorityWeight <= 0.25) {
      icon = Icons.arrow_downward;
      chipColor = colorScheme.surfaceContainerHighest;
      onColor = colorScheme.onSurfaceVariant;
      label = 'Low';
    } else {
      return const SizedBox.shrink(); // Normal (0.5) — no chip
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Priority chip integration in secondary row** (replace lines 158-161 of goal_card.dart):
```dart
// CURRENT (lines 158-161):
if (secondary != null) ...[
  const SizedBox(height: 4),
  Text(secondary, style: theme.textTheme.bodySmall),
],

// REPLACEMENT:
// Source: 14-UI-SPEC.md §Priority Visual Language
final showPriorityChip = (goal.priorityWeight ?? 0.5) != 0.5;
if (secondary != null || showPriorityChip) ...[
  const SizedBox(height: 4),
  Row(
    children: [
      if (secondary != null)
        Expanded(
          child: Text(secondary, style: theme.textTheme.bodySmall),
        ),
      if (showPriorityChip)
        _PriorityChip(priorityWeight: goal.priorityWeight ?? 0.5),
    ],
  ),
]
```

---

### `lib/screens/schedule/widgets/chunk_card.dart` (component, render)

**Analog:** itself (current file). The `_PriorityChip` is a file-private duplicate (same code as in goal_card.dart — intentional per UI-SPEC §Component Inventory item 3).

**New parameter on ChunkCard and _WorkChunkContent** (add to constructors at lines 9-17 and 114-121):
```dart
// In ChunkCard constructor — add:
final double? goalPriorityWeight;

// In _WorkChunkContent constructor — add:
final double? goalPriorityWeight;
```

**Priority badge placement in _WorkChunkContent** (insert after rationale row, around line 237 — after the `displayRationale` block):
```dart
// Source: 14-UI-SPEC.md §Component Inventory item 4
// After the if(goalName != null && displayRationale != null ...) block:
if (goalPriorityWeight != null && goalPriorityWeight != 0.5) ...[
  const SizedBox(height: 4),
  _PriorityChip(priorityWeight: goalPriorityWeight!),
],
```

**_PriorityChip duplicate** — copy exactly from goal_card.dart pattern above. File-private, same widget code.

---

### `lib/screens/schedule/widgets/swipeable_chunk_card.dart` (passthrough wrapper)

**Analog:** itself (current file). Pattern: add one parameter and thread it through.

**Passthrough pattern** (add `goalPriorityWeight` following the existing `displayRationale` passthrough at lines 32-37 and 76-83):
```dart
// In SwipeableChunkCard constructor — add after displayRationale:
final double? goalPriorityWeight;

// In break-card branch (line 42) — no change needed (breaks have no priority).
// In Dismissible child ChunkCard (line 76) — add:
child: ChunkCard(
  chunk: chunk,
  goalColor: goalColor,
  goalName: goalName,
  displayRationale: displayRationale,
  goalPriorityWeight: goalPriorityWeight,   // NEW
  onTap: (chunk.isCompleted || chunk.isSkipped) ? null : onTap,
),
```

---

### `lib/screens/home/widgets/active_chunk_card.dart` (component, render)

**Analog:** itself (current file). The `_lookupGoalColor` / `_lookupGoalName` pattern at lines 23-36 is the direct template for `_lookupGoalPriorityWeight`.

**New lookup method** (add after `_lookupGoalName`, lines 31-36):
```dart
// Source: 14-UI-SPEC.md §Component Inventory item 5
// Same pattern as _lookupGoalColor (lines 23-29) and _lookupGoalName (lines 31-36):
double? _lookupGoalPriorityWeight(BuildContext context) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.priorityWeight;
}
```

**Priority badge placement in build()** (insert after clock-time block, before `SizedBox(height: 12)` + action row at line 134):
```dart
// After the clock-time/duration block (ends around line 109), before SizedBox(height: 12):
// Source: 14-UI-SPEC.md §Priority Badge in ChunkCard and ActiveChunkCard
final goalPriorityWeight = _lookupGoalPriorityWeight(context);
if (goalPriorityWeight != null && goalPriorityWeight != 0.5) ...[
  const SizedBox(height: 4),
  _PriorityChip(priorityWeight: goalPriorityWeight),
],
```

**_PriorityChip** — add as file-private widget (same code as goal_card.dart and chunk_card.dart). Active chunk card needs the `GoalsNotifier` import already present.

---

### `lib/screens/schedule/schedule_screen.dart` (screen, request-response)

**Analog:** itself (current file). The `_lookupGoalColor` / `_lookupGoalName` pair at lines 213-229 is the direct template for `_lookupGoalPriorityWeight`.

**New lookup method** (add after `_lookupGoalName`, line 229):
```dart
// Source: 14-UI-SPEC.md §Component Inventory item 6
// Copy the pattern of _lookupGoalColor (lines 213-218) exactly:
double? _lookupGoalPriorityWeight(BuildContext context, ScheduledChunk chunk) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.priorityWeight;
}
```

**Wire to SwipeableChunkCard in _buildSwipeableCard** (lines 161-181 — add one parameter):
```dart
// In _buildSwipeableCard, add to SwipeableChunkCard call:
return SwipeableChunkCard(
  chunk: chunk,
  goalColor: goalColor,
  goalName: goalName,
  displayRationale: displayRationale,
  goalPriorityWeight: _lookupGoalPriorityWeight(context, chunk),  // NEW
  onTap: ...,
);
```

**Wire to ChunkCard in _buildSkippedSection** (lines 199-207 — add one parameter):
```dart
// In skippedChunks.map() lambda:
return ChunkCard(
  chunk: chunk,
  goalColor: goalColor,
  goalName: _lookupGoalName(context, chunk),
  displayRationale: _toDisplayRationale(chunk.rationale),
  goalPriorityWeight: _lookupGoalPriorityWeight(context, chunk),  // NEW
);
```

---

### `lib/services/schedule_generator.dart` (service, batch)

**Analog:** itself (current file). Before/after code is verified against the production file.

**Step 2 habit sort** (insert before the `for (final goal in activeGoals)` loop at line 234, replacing the inline filter):
```dart
// CURRENT (lines 232-255) — activeGoals loop with inline GoalType.habit filter:
final activeGoals = goals.where((g) => !g.isArchived).toList();
for (final goal in activeGoals) {
  if (discretionaryCount >= cap) break;
  if (goal.goalType != GoalType.habit) continue;
  ...
}

// REPLACEMENT — pre-filtered sorted list:
// Source: 14-UI-SPEC.md §Priority Engine Contract
final activeGoals = goals.where((g) => !g.isArchived).toList();

final habitGoals = activeGoals
    .where((g) => g.goalType == GoalType.habit)
    .toList()
  ..sort((a, b) =>
      (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5));

for (final goal in habitGoals) {
  if (discretionaryCount >= cap) break;
  final effectiveFreq = goal.frequencyPerWeek ?? 7;
  final dueWeekdays = computeDueWeekdays(effectiveFreq);
  if (!dueWeekdays.contains(date.weekday)) continue;
  // ... rest of habit block unchanged
}
```

**Step 4 composite score sort** (replace lines 309-319 of schedule_generator.dart):
```dart
// CURRENT (lines 309-319) — tiebreaker only:
..sort((a, b) {
  final remA = _remainingHours(a, completionLogs, date);
  final remB = _remainingHours(b, completionLogs, date);
  if ((remA - remB).abs() > 0.01) return remB.compareTo(remA);
  return (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5);
});

// REPLACEMENT — composite score:
// Source: 14-UI-SPEC.md §Priority Engine Contract
double score(Goal g) =>
    _remainingHours(g, completionLogs, date) * (g.priorityWeight ?? 0.5);
timeTargetGoals.sort((a, b) => score(b).compareTo(score(a)));
```

---

### `test/screens/goal_card_drag_handle_test.dart` (widget test, UPDATE)

**Analog:** itself (current file). Three targeted changes.

**Change 1 — _reorderableSection helper** (lines 34-61, update icon in trailing):
```dart
// CURRENT (line 55):
child: Icon(Icons.drag_handle),

// REPLACEMENT:
child: Icon(Icons.drag_indicator),
```

**Change 2 — Android/iOS assertions** (lines 82-99, flip findsNothing to findsOneWidget):
```dart
// CURRENT (line 87):
expect(find.byIcon(Icons.drag_handle), findsNothing);

// REPLACEMENT (both Android and iOS tests):
expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
```

**Change 3 — macOS assertion** (line 107, icon name only):
```dart
// CURRENT (line 107):
expect(find.byIcon(Icons.drag_handle), findsOneWidget);

// REPLACEMENT:
expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
// Also update the ancestor lookup on line 109:
find.ancestor(
  of: find.byIcon(Icons.drag_indicator),   // was Icons.drag_handle
  matching: find.byType(AnimatedOpacity),
),
```

---

### `test/screens/goal_card_priority_chip_test.dart` (widget test, NEW)

**Analog:** `test/screens/goal_card_drag_handle_test.dart` — copy its import block, `_stubGoal` helper, `_underPlatform` helper, and `pumpWithMood` usage.

**Imports pattern** (copy from goal_card_drag_handle_test.dart lines 13-23):
```dart
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/screens/goals/widgets/goal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';
```

**Test structure pattern** (copy stub + pumpWithMood pattern from goal_card_drag_handle_test.dart):
```dart
Goal _stubGoal(String id, String name, {double? priorityWeight}) => Goal(
  id: id,
  name: name,
  goalTypeIndex: 0,
  color: '#4CAF50',
  priorityWeight: priorityWeight,
);

void main() {
  group('GoalCard priority chip', () {
    testWidgets('shows High chip for priorityWeight 0.75', (tester) async {
      await pumpWithMood(
        tester,
        GoalCard(goal: _stubGoal('g1', 'Exercise', priorityWeight: 0.75)),
      );
      expect(find.text('High'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('shows no chip for priorityWeight 0.5 (Normal)', (tester) async {
      await pumpWithMood(
        tester,
        GoalCard(goal: _stubGoal('g1', 'Exercise', priorityWeight: 0.5)),
      );
      expect(find.text('High'), findsNothing);
      expect(find.text('Low'), findsNothing);
    });

    testWidgets('shows Low chip for priorityWeight 0.25', (tester) async {
      await pumpWithMood(
        tester,
        GoalCard(goal: _stubGoal('g1', 'Exercise', priorityWeight: 0.25)),
      );
      expect(find.text('Low'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('shows no chip when priorityWeight is null (defaults Normal)', (tester) async {
      await pumpWithMood(
        tester,
        GoalCard(goal: _stubGoal('g1', 'Exercise')),
      );
      expect(find.text('High'), findsNothing);
      expect(find.text('Low'), findsNothing);
    });
  });
}
```

---

### `test/screens/chunk_card_priority_badge_test.dart` (widget test, NEW)

**Analog:** `test/screens/goal_card_drag_handle_test.dart` — same `pumpWithMood` + find.text pattern.

**Test structure pattern:**
```dart
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

ScheduledChunk _stubWorkChunk({String? goalId}) => ScheduledChunk(
  chunkTypeIndex: ChunkType.work.index,
  goalId: goalId,
  durationMinutes: 25,
  rationale: 'test',
);

void main() {
  group('ChunkCard priority badge', () {
    testWidgets('shows High badge when goalPriorityWeight is 0.75', (tester) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(goalId: 'g1'),
          goalPriorityWeight: 0.75,
        ),
      );
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('shows Low badge when goalPriorityWeight is 0.25', (tester) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(goalId: 'g1'),
          goalPriorityWeight: 0.25,
        ),
      );
      expect(find.text('Low'), findsOneWidget);
    });

    testWidgets('shows no badge when goalPriorityWeight is null', (tester) async {
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _stubWorkChunk()),
      );
      expect(find.text('High'), findsNothing);
      expect(find.text('Low'), findsNothing);
    });

    testWidgets('shows no badge when goalPriorityWeight is 0.5 (Normal)', (tester) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(goalId: 'g1'),
          goalPriorityWeight: 0.5,
        ),
      );
      expect(find.text('High'), findsNothing);
      expect(find.text('Low'), findsNothing);
    });
  });
}
```

---

### `test/screens/goals_screen_heading_test.dart` (widget test, NEW)

**Analog:** `test/screens/goal_card_drag_handle_test.dart` — same structure but pumps the full GoalsScreen or a minimal GoalsScreen harness. Because GoalsScreen requires `GoalsNotifier`, use `extraProviders` in `pumpWithMood`.

**Test structure pattern:**
```dart
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/screens/goals/goals_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// Stub GoalsNotifier with one goal so "has goals" branch renders.
// Pattern: same extraProviders approach as other screen tests.
void main() {
  group('GoalsScreen heading', () {
    testWidgets('shows "Your goals" heading when goals exist', (tester) async {
      final notifier = GoalsNotifier(/* stub repo */);
      await pumpWithMood(
        tester,
        const GoalsScreen(),
        extraProviders: [
          ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
        ],
      );
      // Seed notifier with a goal so allEmpty = false, heading renders.
      expect(find.text('Your goals'), findsOneWidget);
      expect(find.text('Drag to prioritize. Tap to edit.'), findsOneWidget);
    });
  });
}
```

---

### `test/services/schedule_generator_test.dart` (unit test, ADD test cases)

**Analog:** itself — existing helpers `makeHabit`, `makeTimeTarget`, `sut`, `monday` at lines 9-76.

**Existing helper pattern** (lines 24-63 — copy these directly, do not redefine):
```dart
// makeHabit already accepts priorityWeight:
Goal makeHabit({String name = 'Habit goal', double? priorityWeight}) => Goal(
  name: name,
  goalTypeIndex: GoalType.habit.index,
  priorityWeight: priorityWeight,
);

// makeTimeTarget already accepts priorityWeight:
Goal makeTimeTarget({
  String name = 'Time-target goal',
  double? weeklyHourBudget,
  double? priorityWeight,
}) => Goal(
  name: name,
  goalTypeIndex: GoalType.timeTarget.index,
  weeklyHourBudget: weeklyHourBudget,
  priorityWeight: priorityWeight,
);
```

**New test case pattern for Step 2** (add after existing habit tests):
```dart
// Source: 14-RESEARCH.md §Behavioral Engine Tests
test('Step 2: high-priority habit is scheduled before low-priority habit', () {
  final highHabit = makeHabit(name: 'High Habit', priorityWeight: 0.75)
    ..frequencyPerWeek = 7;
  final lowHabit = makeHabit(name: 'Low Habit', priorityWeight: 0.25)
    ..frequencyPerWeek = 7;

  final result = sut.generate(
    goals: [lowHabit, highHabit], // intentionally low first in input order
    blocks: [],
    moodIndex: 3,
    date: monday,
    completionLogs: [],
    lighterDay: false,
  );
  final workChunks = result.where((c) => c.chunkType == ChunkType.work).toList();
  expect(workChunks, isNotEmpty);
  expect(workChunks.first.goalId, equals(highHabit.id),
    reason: 'High-priority habit must be scheduled before low-priority habit');
});
```

**New test case pattern for Step 4 ordering** (add after existing time-target tests):
```dart
// Source: 14-RESEARCH.md §Behavioral Engine Tests
test('Step 4: high-priority time-target goal with equal remaining hours gets chunk before low-priority', () {
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
    goals: [lowTT, highTT], // intentionally low first
    blocks: [],
    moodIndex: 3,
    date: monday,
    completionLogs: [],
    lighterDay: false,
  );
  final workGoalIds = result
      .where((c) => c.chunkType == ChunkType.work && c.goalId != null)
      .map((c) => c.goalId!)
      .toList();
  expect(workGoalIds, isNotEmpty);
  expect(workGoalIds.first, equals(highTT.id),
    reason: 'High-priority time-target goal must receive chunks before low-priority goal');
});

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
    moodIndex: 1, // cap=4 — constrained
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
    reason: 'High-priority goal must get at least as many chunks as low-priority under a shared cap');
});
```

---

## Shared Patterns

### Goal lookup from GoalsNotifier by goalId
**Source:** `lib/screens/home/widgets/active_chunk_card.dart` lines 23-36 AND `lib/screens/schedule/schedule_screen.dart` lines 213-229
**Apply to:** `schedule_screen.dart` (`_lookupGoalPriorityWeight`), `active_chunk_card.dart` (`_lookupGoalPriorityWeight`)
```dart
// The canonical pattern — replicate for _lookupGoalPriorityWeight:
double? _lookupGoalPriorityWeight(BuildContext context) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.priorityWeight;
}
```

### pumpWithMood widget test helper
**Source:** `test/test_helpers/mood_pump.dart`
**Apply to:** All new widget test files (goal_card_priority_chip_test.dart, chunk_card_priority_badge_test.dart, goals_screen_heading_test.dart)
```dart
// Always import and use pumpWithMood — never create a raw MaterialApp in tests.
import '../test_helpers/mood_pump.dart';

await pumpWithMood(tester, widget);
// With providers:
await pumpWithMood(tester, widget, extraProviders: [
  ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
]);
```

### debugDefaultTargetPlatformOverride pattern
**Source:** `test/screens/goal_card_drag_handle_test.dart` lines 67-77
**Apply to:** goal_card_drag_handle_test.dart (UPDATE), any new test that needs platform-gated behavior
```dart
Future<void> _underPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}
```

### ColorScheme token usage in widgets
**Source:** `lib/screens/home/widgets/active_chunk_card.dart` lines 113-132 ("Now" badge)
**Apply to:** `_PriorityChip` in all three files (goal_card.dart, chunk_card.dart, active_chunk_card.dart)
```dart
// Always access colorScheme from Theme.of(context) — never hardcode colors:
final colorScheme = Theme.of(context).colorScheme;
// Tier-specific tokens:
//   High: chipColor = colorScheme.primaryContainer, onColor = colorScheme.onPrimaryContainer
//   Low:  chipColor = colorScheme.surfaceContainerHighest, onColor = colorScheme.onSurfaceVariant
```

---

## No Analog Found

No files in Phase 14 are net-new without a codebase analog. All files are modifications to existing source files, and the test file structure is fully covered by existing test patterns.

---

## Metadata

**Analog search scope:** `lib/screens/`, `lib/services/`, `lib/providers/`, `test/screens/`, `test/services/`, `test/test_helpers/`
**Files read:** 12 source files
**Pattern extraction date:** 2026-06-13
