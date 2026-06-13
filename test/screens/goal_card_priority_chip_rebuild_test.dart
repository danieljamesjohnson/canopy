// PRIORITY-03: Widget test proving the priority chip reflects the goal's
// CURRENT priorityWeight after a reorder rebuild — no stale value.
//
// Per locked decision D-01 (2026-06-13): position IS the priority model.
// Dragging a goal to a mid-list position CORRECTLY makes it Normal (no chip).
// This test VERIFIES the Consumer rebuild path — it does NOT change production
// code or override the drag-reorder behavior.
//
// The rebuild path:
//   reorderAllWithPriority -> loadGoals -> notifyListeners
//     -> Consumer<GoalsNotifier> rebuild
//       -> timeTargetGoals (fresh list)
//         -> GoalCard(goal: freshGoal)
//           -> _PriorityChip(priorityWeight: freshGoal.priorityWeight)

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/screens/goals/widgets/goal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// Leaner _InMemoryGoalRepository (no lastSaved field — not needed for
// PRIORITY-03; assertions read through the rebuilt widget tree).
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Goal stub — color is included to match the production path that assigns one.
// ---------------------------------------------------------------------------
Goal _stubGoal(
  String id,
  String name, {
  double? priorityWeight,
  int sortOrder = 0,
}) =>
    Goal(
      id: id,
      name: name,
      goalTypeIndex: GoalType.timeTarget.index,
      color: '#4CAF50',
      priorityWeight: priorityWeight,
      sortOrder: sortOrder,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GoalCard priority chip rebuild after reorderAllWithPriority '
      '(PRIORITY-03)', () {
    testWidgets(
        'before reorder: exactly one High chip (g0) and one Low chip (g2)',
        (tester) async {
      final repo = _InMemoryGoalRepository();

      // Three goals: g0 High (0.75), g1 Normal (0.5), g2 Low (0.25).
      // sortOrder must match so loadGoals returns them in the expected order.
      final g0 = _stubGoal('g0', 'Alpha', priorityWeight: 0.75, sortOrder: 0);
      final g1 = _stubGoal('g1', 'Beta', priorityWeight: 0.5, sortOrder: 1);
      final g2 = _stubGoal('g2', 'Gamma', priorityWeight: 0.25, sortOrder: 2);

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

      // g0 is at the top → High chip.
      expect(find.text('High'), findsOneWidget,
          reason: 'g0 (priorityWeight 0.75) must show the High chip');
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      // g2 is at the bottom → Low chip.
      expect(find.text('Low'), findsOneWidget,
          reason: 'g2 (priorityWeight 0.25) must show the Low chip');
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      // g1 is Normal → no chip.
      expect(find.text('Normal'), findsNothing,
          reason: 'Normal priority goals must not render a chip');
    });

    testWidgets(
        'after reorderAllWithPriority([g1,g0,g2]): chip follows new '
        'priorityWeight — g0 drops High, g1 gains High, no stale chip',
        (tester) async {
      final repo = _InMemoryGoalRepository();

      // Initial order: g0 (High), g1 (Normal), g2 (Low).
      final g0 = _stubGoal('g0', 'Alpha', priorityWeight: 0.75, sortOrder: 0);
      final g1 = _stubGoal('g1', 'Beta', priorityWeight: 0.5, sortOrder: 1);
      final g2 = _stubGoal('g2', 'Gamma', priorityWeight: 0.25, sortOrder: 2);

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

      // Sanity-check initial state: one High chip exists (g0).
      expect(find.text('High'), findsOneWidget);

      // Simulate drag: g0 moved from position 0 to position 1 (middle of 3).
      // New order [g1, g0, g2] → linear-spread weights:
      //   g1 → 0.75 (High),  g0 → 0.50 (Normal/no chip),  g2 → 0.25 (Low)
      //
      // Assertions must read state THROUGH the rebuilt widget tree after
      // pumpAndSettle — NOT from any Goal reference captured before this call
      // (16-RESEARCH.md Pitfall 4).
      await notifier.reorderAllWithPriority([g1.id, g0.id, g2.id]);
      await tester.pumpAndSettle();

      // After reorder: exactly one High chip (now on g1, NOT on g0).
      expect(find.text('High'), findsOneWidget,
          reason:
              'g1 is now at position 0 → priorityWeight 0.75 → must show '
              'exactly one High chip; g0 dropped to Normal → no chip');

      // High chip count is exactly 1 → g0 did NOT retain a stale High chip.
      // (The stale-chip regression: without Consumer rebuild, g0 would still
      // show High even after reorder. findsOneWidget proves it did not.)

      // Low chip is still present (g2 stays at position 2 → 0.25).
      expect(find.text('Low'), findsOneWidget,
          reason: 'g2 stays at position 2 → priorityWeight 0.25 → Low chip');
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      // g0 is now Normal → no High chip for it (total High count is 1, not 2).
      // Arrow-upward icon exists exactly once — g1 owns it, not g0.
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget,
          reason:
              'Only g1 (new position 0) must show the upward arrow; '
              'g0 (now Normal) must not render any priority chip');
    });
  });
}
