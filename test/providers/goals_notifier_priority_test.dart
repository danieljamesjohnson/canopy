// Unit tests for GoalsNotifier.reorderAllWithPriority (REVIEW-02).
//
// These are RED scaffolds written before the production method exists.
// They are expected to fail until Task 3 implements reorderAllWithPriority
// in goals_notifier.dart.

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// In-memory GoalRepository — no Hive.
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

void main() {
  group('GoalsNotifier.reorderAllWithPriority', () {
    late _InMemoryGoalRepository repo;
    late GoalsNotifier notifier;

    setUp(() async {
      repo = _InMemoryGoalRepository();
      notifier = GoalsNotifier(repository: repo);
    });

    test(
      'three goals: persists priorityWeight 0.75 / 0.5 / 0.25 and sortOrder 0 / 1 / 2',
      () async {
        final g0 = Goal(name: 'First', goalTypeIndex: GoalType.habit.index);
        final g1 = Goal(name: 'Second', goalTypeIndex: GoalType.habit.index);
        final g2 = Goal(name: 'Third', goalTypeIndex: GoalType.habit.index);

        // Seed goals into repo and load notifier
        await repo.save(g0);
        await repo.save(g1);
        await repo.save(g2);
        await notifier.loadGoals();

        // Reorder: g0 top (index 0), g1 middle (index 1), g2 bottom (index 2)
        await notifier.reorderAllWithPriority([g0.id, g1.id, g2.id]);

        final saved0 = await repo.getById(g0.id);
        final saved1 = await repo.getById(g1.id);
        final saved2 = await repo.getById(g2.id);

        expect(saved0, isNotNull);
        expect(saved1, isNotNull);
        expect(saved2, isNotNull);

        // sortOrder checks
        expect(saved0!.sortOrder, equals(0));
        expect(saved1!.sortOrder, equals(1));
        expect(saved2!.sortOrder, equals(2));

        // priorityWeight checks: linear spread 0.75 → 0.5 → 0.25
        expect(saved0.priorityWeight, closeTo(0.75, 0.001));
        expect(saved1.priorityWeight, closeTo(0.5, 0.001));
        expect(saved2.priorityWeight, closeTo(0.25, 0.001));
      },
    );

    test('single goal: persists priorityWeight 0.75 and sortOrder 0', () async {
      final g = Goal(name: 'Only', goalTypeIndex: GoalType.habit.index);

      await repo.save(g);
      await notifier.loadGoals();

      await notifier.reorderAllWithPriority([g.id]);

      final saved = await repo.getById(g.id);
      expect(saved, isNotNull);
      expect(saved!.sortOrder, equals(0));
      expect(saved.priorityWeight, closeTo(0.75, 0.001));
    });

    test('weights are monotonically decreasing (top → bottom)', () async {
      final g0 = Goal(name: 'A', goalTypeIndex: GoalType.habit.index);
      final g1 = Goal(name: 'B', goalTypeIndex: GoalType.habit.index);
      final g2 = Goal(name: 'C', goalTypeIndex: GoalType.habit.index);

      await repo.save(g0);
      await repo.save(g1);
      await repo.save(g2);
      await notifier.loadGoals();

      await notifier.reorderAllWithPriority([g0.id, g1.id, g2.id]);

      final w0 = (await repo.getById(g0.id))!.priorityWeight!;
      final w1 = (await repo.getById(g1.id))!.priorityWeight!;
      final w2 = (await repo.getById(g2.id))!.priorityWeight!;

      expect(
        w0,
        greaterThan(w1),
        reason: 'top goal must have higher weight than middle goal',
      );
      expect(
        w1,
        greaterThan(w2),
        reason: 'middle goal must have higher weight than bottom goal',
      );
    });
  });
}
