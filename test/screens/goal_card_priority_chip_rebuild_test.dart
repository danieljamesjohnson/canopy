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

      // After reorder: assert IDENTITY of the High chip — which card owns it.
      //
      // A stale widget tree (broken Consumer rebuild) would leave g0 (Alpha) with
      // its pre-reorder High chip. A correctly rebuilt tree must show g1 (Beta) as
      // the High-chip owner and Alpha must have NO High chip.
      //
      // Strategy: use find.descendant to confirm the Beta GoalCard contains the
      // High chip text, then use find.ancestor to confirm NO Card ancestor of the
      // High chip also contains Alpha — these two assertions together cannot pass
      // in the stale-tree scenario.

      // 1. The High chip must still exist in the tree (sanity baseline).
      expect(
        find.text('High'),
        findsOneWidget,
        reason: 'g1 (Beta) at new position 0 must have priorityWeight 0.75 '
            '→ exactly one High chip',
      );

      // 2. The Beta GoalCard must contain the High chip text as a descendant.
      //    find.descendant(of: X, matching: Y) finds Y that lives inside X.
      //    GoalCard is a StatefulWidget; its root render object is the Card.
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Beta'),
            matching: find.byType(Card),
          ),
          matching: find.text('High'),
        ),
        findsOneWidget,
        reason: 'g1 (Beta) is at new position 0 → its Card must own the High '
            'chip; if Consumer rebuild is broken, Beta retains its stale Normal '
            'state and this assertion fails',
      );

      // 3. The Alpha GoalCard must NOT contain the High chip text.
      //    If Consumer rebuild is broken, Alpha retains its pre-reorder High chip
      //    and this assertion fails — making this the regression catch.
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Alpha'),
            matching: find.byType(Card),
          ),
          matching: find.text('High'),
        ),
        findsNothing,
        reason: 'g0 (Alpha) dropped to Normal after reorder — its Card must '
            'NOT contain a High chip; a stale tree would leave it there',
      );

      // 4. Low chip is still present on the Gamma GoalCard (g2 stays at position 2).
      expect(find.text('Low'), findsOneWidget,
          reason: 'g2 stays at position 2 → priorityWeight 0.25 → Low chip');
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      // 5. Arrow-upward icon exists exactly once — belongs to Beta (g1), not Alpha.
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget,
          reason:
              'Only g1 (Beta, new position 0) must show the upward arrow; '
              'g0 (Alpha, now Normal) must not render any priority chip');
    });
  });
}
