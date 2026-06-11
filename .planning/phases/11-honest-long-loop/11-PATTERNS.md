# Phase 11: Honest Long Loop — Pattern Map

**Mapped:** 2026-06-11
**Files analyzed:** 8 (6 source edits + 2 test files modified/created)
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/screens/quarterly_review/widgets/donut_chart.dart` | widget | transform | itself (primary edit site) | exact |
| `lib/screens/quarterly_review/sections/data_section.dart` | component | request-response | itself (constructor pass-through) | exact |
| `lib/screens/quarterly_review/quarterly_review_screen.dart` | screen/stateful | CRUD | itself + `cold_launch_morning_loop_test.dart` (loading pattern) | exact |
| `lib/screens/quarterly_review/sections/adjustments_section.dart` | component | request-response | itself (call-site swap) | exact |
| `lib/providers/goals_notifier.dart` | provider/notifier | CRUD | itself — `reorderAll` method (lines 78–87) | exact |
| `lib/services/quarterly_aggregation_service.dart` | service | transform | itself (no change needed per research) | exact (no-op) |
| `test/screens/quarterly_review_test.dart` | test | — | itself + `cold_launch_morning_loop_test.dart` | exact |
| `test/services/schedule_generator_test.dart` | test | — | itself | exact |

---

## Pattern Assignments

### `lib/screens/quarterly_review/widgets/donut_chart.dart` (widget, transform)

**Analog:** itself (lines 1–130, read directly)

**Imports pattern** (lines 1–6 — unchanged; no new imports needed):
```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../data/models/goal.dart';
import '../../../providers/goals_notifier.dart';
import '../../schedule/widgets/chunk_card.dart';
```
Add two new model imports alongside the existing `goal.dart` import:
```dart
import '../../../data/models/commitment_block.dart';   // NEW
```
`Goal` import already covers archived goals (same type).

**Constructor signature change** (lines 13–22 become):
```dart
const DonutChart({
  super.key,
  required this.goalChunkTotals,
  required this.notSpentCount,
  required this.goals,           // active goals — parameter name unchanged
  required this.archivedGoals,   // NEW: List<Goal>
  required this.commitmentBlocks, // NEW: List<CommitmentBlock>
});
```
Add corresponding final fields:
```dart
final List<Goal> archivedGoals;
final List<CommitmentBlock> commitmentBlocks;
```

**Existing active-goal slice loop** (lines 38–53 — copy this pattern for the new archived-goal loop):
```dart
for (var i = 0; i < goals.length; i++) {
  final goal = goals[i];
  final count = goalChunkTotals[goal.id] ?? 0;
  final color = _colorForGoal(goal, i);
  final pct = totalValue > 0 ? count / totalValue * 100 : 0.0;
  sections.add(PieChartSectionData(value: count.toDouble(), color: color, radius: 50, showTitle: false));
  legendEntries.add((color: color, label: goal.name, pct: pct));
}
```

**New classification loop — replace the active-goal loop with this full block:**
```dart
// Build lookup sets for ID resolution
final commitmentIds = {for (final b in commitmentBlocks) b.id};
final activeGoalIds = {for (final g in goals) g.id};
final archivedGoalMap = {for (final g in archivedGoals) g.id: g};

int commitmentTotal = 0;
int otherTotal = 0;

// Active goal slices (existing behavior, preserved)
for (var i = 0; i < goals.length; i++) {
  final goal = goals[i];
  final count = goalChunkTotals[goal.id] ?? 0;
  if (count == 0) continue;  // omit zero-value slices (UI-SPEC)
  final color = _colorForGoal(goal, i);
  final pct = totalValue > 0 ? count / totalValue * 100 : 0.0;
  sections.add(PieChartSectionData(value: count.toDouble(), color: color, radius: 50, showTitle: false));
  legendEntries.add((color: color, label: goal.name, pct: pct));
}

// Classify remaining keys (commitment chunks, archived goals, unknown)
for (final entry in goalChunkTotals.entries) {
  if (activeGoalIds.contains(entry.key)) continue; // already handled above
  if (entry.value == 0) continue;

  if (archivedGoalMap.containsKey(entry.key)) {
    final goal = archivedGoalMap[entry.key]!;
    final color = _colorForGoal(goal, goals.length + archivedGoals.indexOf(goal));
    final pct = totalValue > 0 ? entry.value / totalValue * 100 : 0.0;
    sections.add(PieChartSectionData(value: entry.value.toDouble(), color: color, radius: 50, showTitle: false));
    legendEntries.add((color: color, label: '${goal.name} (archived)', pct: pct));
  } else if (commitmentIds.contains(entry.key)) {
    commitmentTotal += entry.value;
  } else {
    otherTotal += entry.value;
  }
}

// Aggregated Commitments slice
// NOTE: 0xFF607D8B is also palette index 7; visual collision possible when
// 8+ active goals are present — acceptable in v1 given rarity.
if (commitmentTotal > 0) {
  const commitmentColor = Color(0xFF607D8B);
  final pct = totalValue > 0 ? commitmentTotal / totalValue * 100 : 0.0;
  sections.add(PieChartSectionData(value: commitmentTotal.toDouble(), color: commitmentColor, radius: 50, showTitle: false));
  legendEntries.add((color: commitmentColor, label: 'Commitments', pct: pct));
}

// Other catch-all slice
if (otherTotal > 0) {
  const otherColor = Color(0xFFBDBDBD);
  final pct = totalValue > 0 ? otherTotal / totalValue * 100 : 0.0;
  sections.add(PieChartSectionData(value: otherTotal.toDouble(), color: otherColor, radius: 50, showTitle: false));
  legendEntries.add((color: otherColor, label: 'Other', pct: pct));
}
```

**Existing "Time not spent" slice** (lines 55–69 — guard zero-value per UI-SPEC):
```dart
// Current: unconditionally adds slice. Change to:
if (notSpentCount > 0) {
  final notSpentPct = totalValue > 0 ? notSpentCount / totalValue * 100 : 0.0;
  sections.add(PieChartSectionData(value: notSpentCount.toDouble(), color: outlineVariant, radius: 50, showTitle: false));
  legendEntries.add((color: outlineVariant, label: 'Time not spent', pct: notSpentPct));
}
```

**Legend row pattern** (lines 92–116 — unchanged, copy as-is):
```dart
.map((e) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Row(
    children: [
      CircleAvatar(radius: 6, backgroundColor: e.color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(e.label, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
      ),
      Text('${e.pct.toStringAsFixed(0)}%',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ],
  ),
))
```

**`_colorForGoal` helper** (lines 123–129 — unchanged, reused for both active and archived goals):
```dart
Color _colorForGoal(Goal goal, int index) {
  if (goal.color != null) return hexToColor(goal.color!);
  const palette = GoalsNotifier.colorPalette;
  return Color(int.parse(palette[index % palette.length].replaceFirst('#', '0xFF')));
}
```

---

### `lib/screens/quarterly_review/sections/data_section.dart` (component, request-response)

**Analog:** itself (lines 1–137, read directly)

**Constructor addition** — add two required params after `goals:`:
```dart
// Current constructor ends at line 21:
required this.goals,
required this.onNext,

// New constructor:
required this.goals,
required this.archivedGoals,    // NEW: List<Goal>
required this.commitmentBlocks, // NEW: List<CommitmentBlock>
required this.onNext,
```
Add corresponding `final` fields.

**DonutChart call site** (lines 79–83 — add new required args):
```dart
// Current:
DonutChart(
  goalChunkTotals: goalChunkTotals,
  notSpentCount: notSpentCount,
  goals: goals,
),

// After fix:
DonutChart(
  goalChunkTotals: goalChunkTotals,
  notSpentCount: notSpentCount,
  goals: goals,
  archivedGoals: archivedGoals,         // NEW
  commitmentBlocks: commitmentBlocks,   // NEW
),
```
All other `DataSection` logic is unchanged.

---

### `lib/screens/quarterly_review/quarterly_review_screen.dart` (screen, CRUD)

**Analog:** itself (lines 1–255, read directly)

**New state variables** — add alongside existing state fields (after line 38):
```dart
List<Goal> _archivedGoals = [];
List<CommitmentBlock> _commitmentBlocks = [];
```
Add import at top: `import '../../data/models/commitment_block.dart';`
Add import: `import '../../providers/commitments_notifier.dart';`

**`_loadData()` pattern — safe context.read before any await** (anti-pattern fix from RESEARCH.md Pitfall 6):
```dart
// Read providers before any await to avoid unmounted-widget context access:
Future<void> _loadData() async {
  final goalsNotifier = context.read<GoalsNotifier>();
  final commitmentsNotifier = context.read<CommitmentsNotifier>();  // NEW

  final allLogs = await HiveCompletionLogRepository().getAll();
  final latestSnapshot = await HiveQuarterlySnapshotRepository().getLatest();

  // NEW: load archived goals and commitment blocks
  final archivedGoals = await goalsNotifier.getArchivedGoals();
  final commitmentBlocks = commitmentsNotifier.blocks;  // sync, loaded at startup

  // ... existing period-start logic unchanged (lines 64–80) ...
```

**Empty-state guard fix** (line 84 — replace buggy guard):
```dart
// BEFORE (bug):
if (totalCompleted == 0 && goals.isEmpty) { ... }

// AFTER (fix — guard on log data only, independent of provider state):
if (allLogs.isEmpty) { ... }
```

**setState block** — add new fields (lines 94–110):
```dart
setState(() {
  _loading = false;
  _hasData = true;
  _archivedGoals = archivedGoals;         // NEW
  _commitmentBlocks = commitmentBlocks;   // NEW
  _periodStartYmd = startYmd;
  // ... existing fields unchanged ...
});
```

**DataSection call site** (lines 154–162 — add two new args):
```dart
DataSection(
  totalCompleted: _totalCompleted,
  goalChunkTotals: _goalChunkTotals,
  notSpentCount: _notSpentCount,
  weeklyData: _weeklyData,
  goals: goals,
  archivedGoals: _archivedGoals,         // NEW
  commitmentBlocks: _commitmentBlocks,   // NEW
  onNext: () => _advanceToSection(1),
),
```

---

### `lib/screens/quarterly_review/sections/adjustments_section.dart` (component, request-response)

**Analog:** itself (lines 74–139 — `_finish()` body)

**Single call-site change** in `_finish()` (line 96):
```dart
// BEFORE:
await notifier.reorderAll(orderedIds);

// AFTER:
await notifier.reorderAllWithPriority(orderedIds);
```
No other changes. The rest of `_finish()` (archive loop, snapshot construction, Navigator.pop) is unchanged.

---

### `lib/providers/goals_notifier.dart` (provider/notifier, CRUD)

**Analog:** `reorderAll` method (lines 78–87) — copy its structure exactly

**New method `reorderAllWithPriority`** — add immediately after `reorderAll` (after line 87):
```dart
/// Reorders all goals using a flat ordered ID list, writing both [sortOrder]
/// and [priorityWeight] so the schedule generator picks up priority changes.
///
/// Linear spread: index 0 (top) → 0.75, index n-1 (bottom) → 0.25.
/// Single goal: weight = 0.75. Weights are monotonically distinct.
Future<void> reorderAllWithPriority(List<String> orderedIds) async {
  const double high = 0.75;
  const double low  = 0.25;
  final n = orderedIds.length;
  for (var i = 0; i < n; i++) {
    final goal = _goals.where((g) => g.id == orderedIds[i]).firstOrNull;
    if (goal != null) {
      goal.sortOrder = i;
      goal.priorityWeight = n <= 1 ? high : high - (high - low) * i / (n - 1);
      await _repository.save(goal);
    }
  }
  await loadGoals();
}
```
`reorderAll` (existing) is kept unchanged — backward compatible.

---

### `lib/services/quarterly_aggregation_service.dart` (service, transform)

**No changes required.** RESEARCH.md confirms: "already correct by design — keyed on `CompletionLog.goalId`; the classification work happens in `DonutChart`, not here." This file is listed for completeness only.

---

## Test Pattern Assignments

### `test/screens/quarterly_review_test.dart` — existing tests + new tests

**Analog:** itself (lines 1–272, read directly)

**Pattern: existing DonutChart test (lines 103–122) — must be updated to pass new required params:**
```dart
// All existing DonutChart pumpWithMood calls add:
DonutChart(
  goalChunkTotals: {'g1': 20, 'g2': 10},
  notSpentCount: 5,
  goals: goals,
  archivedGoals: const [],       // NEW — satisfies required param, keeps old behavior
  commitmentBlocks: const [],    // NEW — satisfies required param
)
```
Same pattern applies to any `DataSection` call site in the test file.

**Pattern: new REVIEW-01 commitment-slice test — follow existing DonutChart group structure:**
```dart
testWidgets('renders Commitments legend row when commitment logs present', (tester) async {
  // commitment block id in goalChunkTotals key — matches commitmentBlocks list
  final block = CommitmentBlock(name: 'Work', daysOfWeek: [1, 2, 3, 4, 5],
      startMinutes: 540, endMinutes: 600);
  await pumpWithMood(tester, DonutChart(
    goalChunkTotals: {block.id: 5},
    notSpentCount: 0,
    goals: const [],
    archivedGoals: const [],
    commitmentBlocks: [block],
  ));
  expect(find.text('Commitments'), findsOneWidget);
});
```

**Pattern: new REVIEW-01 archived-goal slice test:**
```dart
testWidgets('renders archived goal legend row with (archived) suffix', (tester) async {
  final archivedGoal = _stubGoal(id: 'g_arch', name: 'Old Habit', color: '#9C27B0');
  await pumpWithMood(tester, DonutChart(
    goalChunkTotals: {'g_arch': 8},
    notSpentCount: 0,
    goals: const [],
    archivedGoals: [archivedGoal],
    commitmentBlocks: const [],
  ));
  expect(find.text('Old Habit (archived)'), findsOneWidget);
});
```

**Pattern: new REVIEW-03 cold-launch test — follow `cold_launch_morning_loop_test.dart`'s in-memory provider pattern:**
```dart
// Use _InMemoryGoalRepository (already defined in cold_launch_morning_loop_test.dart
// — copy the class or move it to a shared test helper).
// Pump QuarterlyReviewScreen directly, no other screen visited first.
// Assert chart legend rows appear — proving _loadData resolved without prior tab visit.
```

### `test/services/schedule_generator_test.dart` — new REVIEW-02 ordering test

**Analog:** itself — `makeOutcome` helper (lines 31–41) + existing test structure

**Pattern for new priorityWeight ordering test:**
```dart
test('higher priorityWeight goal appears before lower priorityWeight goal in generated chunks', () {
  final highPriorityGoal = makeOutcome(name: 'High', priorityWeight: 0.75);
  final lowPriorityGoal  = makeOutcome(name: 'Low',  priorityWeight: 0.25);
  // Goals passed with low-priority first to confirm ordering is by weight, not input order:
  final schedule = sut.generate(
    goals: [lowPriorityGoal, highPriorityGoal],
    commitmentBlocks: [],
    existingLogs: [],
    date: monday,
  );
  final goalChunks = schedule.chunks.where((c) => c.goalId != null).toList();
  final highIdx = goalChunks.indexWhere((c) => c.goalId == highPriorityGoal.id);
  final lowIdx  = goalChunks.indexWhere((c) => c.goalId == lowPriorityGoal.id);
  expect(highIdx, lessThan(lowIdx));
});
```

**Helper already available** (lines 24–41 of schedule_generator_test.dart):
```dart
Goal makeOutcome({String name = 'Outcome goal', DateTime? deadline, double? priorityWeight}) =>
    Goal(name: name, goalTypeIndex: GoalType.outcome.index, deadline: deadline, priorityWeight: priorityWeight);
```

---

## Shared Patterns

### Context.read before await (Flutter async safety)
**Source:** RESEARCH.md Pitfall 6 + `cold_launch_morning_loop_test.dart` provider setup pattern
**Apply to:** `quarterly_review_screen.dart` `_loadData()`
```dart
// Always capture context.read results before the first await:
final goalsNotifier = context.read<GoalsNotifier>();
final commitmentsNotifier = context.read<CommitmentsNotifier>();
// ... then await ...
final archivedGoals = await goalsNotifier.getArchivedGoals();
```

### Zero-value slice guard
**Source:** `donut_chart.dart` existing pattern + UI-SPEC §Donut Chart Slice Contract
**Apply to:** every `sections.add(...)` call in the new `donut_chart.dart` loop
```dart
if (count == 0) continue; // omit — fl_chart 0-value slices produce layout artifacts
```

### pumpWithMood test helper
**Source:** `test/test_helpers/mood_pump.dart` (lines 24–48)
**Apply to:** all new widget tests in `quarterly_review_test.dart` and the new cold-launch review test
```dart
await pumpWithMood(tester, MyWidget(...), extraProviders: [
  ChangeNotifierProvider<GoalsNotifier>(create: (_) => GoalsNotifier(repository: _InMemoryGoalRepository())),
]);
```

### In-memory repository test double
**Source:** `test/screens/cold_launch_morning_loop_test.dart` lines 34–52
**Apply to:** new REVIEW-03 cold-launch quarterly review test
```dart
class _InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};
  @override Future<List<Goal>> getAll() async => _store.values.toList();
  @override Future<Goal?> getById(String id) async => _store[id];
  @override Future<void> save(Goal goal) async => _store[goal.id] = goal;
  @override Future<void> delete(String id) async => _store.remove(id);
  @override Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}
```

### reorderAll loop pattern
**Source:** `goals_notifier.dart` lines 78–87
**Apply to:** new `reorderAllWithPriority` method — identical structure, adds one field write
```dart
for (var i = 0; i < orderedGoalIds.length; i++) {
  final goal = _goals.where((g) => g.id == orderedGoalIds[i]).firstOrNull;
  if (goal != null) {
    goal.sortOrder = i;
    // NEW: also write priorityWeight
    await _repository.save(goal);
  }
}
await loadGoals();
```

---

## No Analog Found

None — all edit sites are well-established existing files with exact analogs. New tests follow existing test file patterns.

---

## Metadata

**Analog search scope:** `lib/screens/quarterly_review/`, `lib/providers/`, `lib/services/`, `test/screens/`, `test/services/`, `test/test_helpers/`
**Files read:** 9 source files
**Pattern extraction date:** 2026-06-11
