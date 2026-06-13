# Phase 16: Priority Model Reconciliation - Pattern Map

**Mapped:** 2026-06-13
**Files analyzed:** 2 (1 new test file, 1 modified test file)
**Analogs found:** 2 / 2

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/screens/goal_card_priority_chip_rebuild_test.dart` (NEW) | test | event-driven (notifier → Consumer → widget rebuild assertion) | `test/screens/goal_card_priority_chip_test.dart` + `test/screens/goals_screen_heading_test.dart` | exact (same GoalCard + pumpWithMood + InMemoryGoalRepository pattern; heading test adds notifier-driven rebuild assertion) |
| `test/screens/goal_form_priority_test.dart` (MODIFY — replace 2 tests) | test | request-response (modal pump → scrollUntilVisible → assertion) | self (5 remaining tests in the file) + RESEARCH.md modal pattern | role-match (same file; modal pump pattern is new to this file but mirrors Flutter SDK bottom_sheet_test pattern) |

---

## Pattern Assignments

### `test/screens/goal_card_priority_chip_rebuild_test.dart` (NEW — PRIORITY-03)

**Analogs:** `test/screens/goal_card_priority_chip_test.dart` (chip render assertions) and `test/screens/goals_screen_heading_test.dart` (InMemoryGoalRepository + GoalsNotifier + pumpWithMood + Consumer rebuild flow)

---

**Imports pattern** — copy from `test/screens/goal_card_priority_chip_test.dart` lines 1–12 and `test/screens/goals_screen_heading_test.dart` lines 1–15:

```dart
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/screens/goals/widgets/goal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';
```

---

**InMemoryGoalRepository pattern** — copy from `test/screens/goals_screen_heading_test.dart` lines 19–37. This version has no `lastSaved` field (heading test doesn't need it). For PRIORITY-03 the save assertions read from notifier post-reorder, not from `lastSaved`, so this leaner version is sufficient:

```dart
class _InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};

  @override
  Future<List<Goal>> getAll() async => _store.values.toList();

  @override
  Future<Goal?> getById(String id) async => _store[id];

  @override
  Future<void> save(Goal goal) async => _store[goal.id] = goal;

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}
```

---

**Goal stub pattern** — copy from `test/screens/goal_card_priority_chip_test.dart` lines 13–19. Adapt goalTypeIndex to use `GoalType.timeTarget.index` for the PRIORITY-03 scenario:

```dart
Goal _stubGoal(String id, String name, {double? priorityWeight}) => Goal(
      id: id,
      name: name,
      goalTypeIndex: GoalType.timeTarget.index,
      priorityWeight: priorityWeight,
    );
```

---

**Core Consumer rebuild test pattern** — copy from `test/screens/goals_screen_heading_test.dart` lines 39–75 (repo setup + notifier + pumpWithMood with extraProviders + pumpAndSettle). PRIORITY-03 pumps a slim Consumer<GoalsNotifier> wrapping Column(GoalCard) instead of GoalsScreen — the InMemoryGoalRepository + notifier.loadGoals() + pumpWithMood + extraProviders structure is identical:

```dart
testWidgets('chip updates after programmatic reorder via reorderAllWithPriority',
    (tester) async {
  final repo = _InMemoryGoalRepository();
  final g0 = Goal(id: 'g0', name: 'A',
      goalTypeIndex: GoalType.timeTarget.index, priorityWeight: 0.75);
  final g1 = Goal(id: 'g1', name: 'B',
      goalTypeIndex: GoalType.timeTarget.index, priorityWeight: 0.5);
  final g2 = Goal(id: 'g2', name: 'C',
      goalTypeIndex: GoalType.timeTarget.index, priorityWeight: 0.25);

  await repo.save(g0);
  await repo.save(g1);
  await repo.save(g2);

  final notifier = GoalsNotifier(repository: repo);
  await notifier.loadGoals();

  await pumpWithMood(
    tester,
    Consumer<GoalsNotifier>(
      builder: (ctx, n, _) => Column(
        children: n.timeTargetGoals.map((g) => GoalCard(goal: g)).toList(),
      ),
    ),
    extraProviders: [
      ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
    ],
  );

  // Before reorder: g0 shows High chip.
  expect(find.text('High'), findsOneWidget);

  // Simulate drag: g0 moves from position 0 to position 1 (middle of 3).
  // New order [g1, g0, g2] → weights 0.75, 0.5, 0.25 → g0 gets 0.5 (Normal, no chip).
  await notifier.reorderAllWithPriority([g1.id, g0.id, g2.id]);
  await tester.pumpAndSettle();  // always pumpAndSettle after async notifier call

  // After reorder: g1 is now High; g0 is Normal (no chip).
  expect(find.text('High'), findsOneWidget,
      reason: 'g1 now at position 0 → High chip');
  // g0 is now Normal → chip count unchanged at 1 (not 2), proving no stale High chip.
});
```

---

**Chip render assertion pattern** — copy from `test/screens/goal_card_priority_chip_test.dart` lines 23–58. For Low chip verification in the rebuild test (g2 at position 2 of 3 → weight 0.25 → Low chip):

```dart
expect(find.text('Low'), findsOneWidget);
expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
```

---

### `test/screens/goal_form_priority_test.dart` (MODIFY — GOALFORM-02)

**Analog:** self — the five surviving tests in this file (lines 90–240) plus the `setViewport` helper. The two tests to REPLACE are at lines 118–164 and 241–273.

---

**Imports to add** — `viewport.dart` import (not currently imported; the two removed tests used the deprecated `tester.binding.setSurfaceSize` directly):

```dart
import '../test_helpers/viewport.dart';
```

The existing imports (lines 10–18) supply everything else needed:

```dart
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/screens/goals/goal_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';
```

---

**InMemoryGoalRepository with `lastSaved`** — already defined in the file at lines 23–45. Re-use as-is for the new GOALFORM-02 tests:

```dart
class _InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};
  Goal? lastSaved;            // ← needed for save-assertion tests

  @override Future<List<Goal>> getAll() async => _store.values.toList();
  @override Future<Goal?> getById(String id) async => _store[id];
  @override Future<void> save(Goal goal) async {
    _store[goal.id] = goal;
    lastSaved = goal;
  }
  @override Future<void> delete(String id) async => _store.remove(id);
  @override Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}
```

---

**setViewport pattern** — from `test/test_helpers/viewport.dart` lines 17–21. Replace every `tester.binding.setSurfaceSize(const Size(800, 1200))` + `addTearDown(() => tester.binding.setSurfaceSize(null))` pair with a single call:

```dart
// BEFORE (lines 122–123 and 244–245 in goal_form_priority_test.dart — DELETE):
await tester.binding.setSurfaceSize(const Size(800, 1200));
addTearDown(() => tester.binding.setSurfaceSize(null));

// AFTER (single call, teardown registered automatically):
setViewport(tester, const Size(390, 844));
```

---

**Modal pump pattern** — derived from RESEARCH.md §GOALFORM-02 Modal Test Pattern and §Code Examples (context-capture pattern). This is the primary new pattern for GOALFORM-02:

```dart
// Step 1: build host scaffold via pumpWithMood to get a valid BuildContext.
final repo = _InMemoryGoalRepository();
final notifier = GoalsNotifier(repository: repo);

late BuildContext capturedCtx;
await pumpWithMood(
  tester,
  Builder(builder: (ctx) {
    capturedCtx = ctx;
    return const SizedBox.shrink();
  }),
  extraProviders: [
    ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
  ],
);

// Step 2: open the modal (NOT await — showModalBottomSheet returns a Future
// that only resolves on dismiss; pump instead).
showModalBottomSheet<void>(
  context: capturedCtx,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.6,
    minChildSize: 0.4,
    maxChildSize: 1.0,
    expand: false,
    snap: true,
    snapSizes: const [0.6, 1.0],
    builder: (_, sc) => GoalFormSheet(scrollController: sc),
  ),
);
await tester.pumpAndSettle();  // settle modal open animation
```

---

**Goal type selection pattern** — copy from existing test lines 194–198 (Habit), 206–213 (Outcome), 224–231 (Time Target). For GOALFORM-02 group, select goal type BEFORE scrolling to priority control:

```dart
// Time-target:
await tester.tap(find.text('I want to spend regular time on something'));
await tester.pumpAndSettle();

// Outcome (deepest — most content, most scroll needed):
await tester.tap(find.text("I'm working toward a specific outcome"));
await tester.pumpAndSettle();

// Habit:
await tester.tap(find.text('I want to build a daily habit'));
await tester.pumpAndSettle();
```

---

**scrollUntilVisible pattern** — documented in RESEARCH.md §scrollUntilVisible API. Pass `scrollable: find.byType(SingleChildScrollView)` to avoid ambiguity when DraggableScrollableSheet adds a second Scrollable to the tree:

```dart
// Assert SegmentedButton<double> (Priority control) is reachable via scroll.
await tester.scrollUntilVisible(
  find.byType(SegmentedButton<double>),
  100,
  scrollable: find.byType(SingleChildScrollView),
);
expect(find.byType(SegmentedButton<double>), findsOneWidget);

// Assert ElevatedButton (Save/Add goal) is reachable via scroll.
await tester.scrollUntilVisible(
  find.byType(ElevatedButton),
  100,
  scrollable: find.byType(SingleChildScrollView),
);
expect(find.byType(ElevatedButton), findsOneWidget);
```

Note: `find.byType(SegmentedButton<double>)` with the type parameter is required — `SegmentedButton` without `<double>` does not match (RESEARCH.md Pitfall 6).

---

**Save-persistence assertion pattern** — carry over from the test being replaced (line 157–163). After scrollUntilVisible finds the ElevatedButton, tap it and assert `repo.lastSaved`:

```dart
// Enter a goal name first (Save is disabled until name is non-empty).
await tester.enterText(find.byType(TextField).first, 'Test Goal');
await tester.pumpAndSettle();

// Tap Add goal — use .last because 'Add goal' also appears as sheet title text.
await tester.scrollUntilVisible(find.byType(ElevatedButton), 100,
    scrollable: find.byType(SingleChildScrollView));
await tester.tap(find.text('Add goal').last);
await tester.pumpAndSettle();

expect(
  repo.lastSaved?.priorityWeight,
  closeTo(0.75, 0.001),
  reason: 'Save must persist priorityWeight == 0.75 when High is selected',
);
```

---

**Weekly-budget assertion pattern** — carry over from the test being replaced (lines 255–272). After the modal-height infrastructure is in place, this assertion is unchanged in content:

```dart
expect(
  find.text('3.0'),
  findsOneWidget,
  reason: 'Regular-time goal must default the weekly budget to 3.0 hrs',
);
// ... after tap Save:
expect(
  repo.lastSaved?.weeklyHourBudget,
  closeTo(3.0, 0.001),
  reason:
      'A regular-time goal saved without edits must persist 3.0 hrs/week '
      'so the engine has a budget to schedule against',
);
```

---

## Shared Patterns

### pumpWithMood — standard pump helper
**Source:** `test/test_helpers/mood_pump.dart` lines 24–48
**Apply to:** ALL test files in this phase

```dart
// Signature:
Future<void> pumpWithMood(
  WidgetTester tester,
  Widget child, {
  int moodIndex = 3,           // default: seed #4A8C7A — locked test fixture
  Iterable<ChangeNotifierProvider> extraProviders = const [],
}) async { ... }

// With providers:
await pumpWithMood(
  tester,
  SomeWidget(),
  extraProviders: [
    ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
  ],
);
```

### setViewport — viewport helper with auto-teardown
**Source:** `test/test_helpers/viewport.dart` lines 17–21
**Apply to:** GOALFORM-02 test group (replaces deprecated `setSurfaceSize`)

```dart
void setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);  // auto-registered — caller does NOT add teardown
}
```

### Priority chip band thresholds (locked)
**Source:** `lib/screens/goals/widgets/goal_card.dart` lines 245–257
**Apply to:** all assertions on chip labels/icons — thresholds are inclusive at boundaries

```dart
if (priorityWeight >= 0.75) {
  label = 'High';   // chip renders
} else if (priorityWeight <= 0.25) {
  label = 'Low';    // chip renders
} else {
  return const SizedBox.shrink(); // Normal (0.25 < pw < 0.75) — no chip
}
```

### GoalsNotifier + InMemoryGoalRepository setup
**Source:** `test/screens/goals_screen_heading_test.dart` lines 19–55
**Apply to:** both new test files

```dart
final repo = _InMemoryGoalRepository();
await repo.save(someGoal);
final notifier = GoalsNotifier(repository: repo);
await notifier.loadGoals();  // pre-load before pump so notifier has data immediately
```

---

## No Analog Found

None. Both files have strong existing analogs.

---

## Deprecated Patterns Being Replaced

| Old Pattern (in `goal_form_priority_test.dart`) | Lines | Replace With |
|---|---|---|
| `await tester.binding.setSurfaceSize(const Size(800, 1200))` | 122, 244 | `setViewport(tester, const Size(390, 844))` from `test/test_helpers/viewport.dart` |
| `addTearDown(() => tester.binding.setSurfaceSize(null))` | 123, 245 | Remove — `setViewport` registers teardown automatically |
| `_pumpForm(tester)` (pumps form directly, no modal) | 125, 247 | Modal pump pattern: `showModalBottomSheet` → `DraggableScrollableSheet` → `GoalFormSheet` |

---

## Metadata

**Analog search scope:** `test/screens/`, `test/test_helpers/`, `lib/screens/goals/widgets/`
**Files read:** `goal_form_priority_test.dart`, `goal_card_priority_chip_test.dart`, `goals_screen_heading_test.dart`, `mood_pump.dart`, `viewport.dart`, `goal_card.dart` (lines 1–30, 220–281)
**Pattern extraction date:** 2026-06-13
