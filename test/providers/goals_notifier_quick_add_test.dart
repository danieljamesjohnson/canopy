// Unit tests for GoalsNotifier.quickAddGoals — frictionless slate entry.
//
// Verifies a user can lay down a full slate (e.g. 8 goals) from plain names
// with sensible defaults, that blank lines are ignored, ordering is appended,
// and colors spread across the palette.

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

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
  group('GoalsNotifier.quickAddGoals', () {
    late _InMemoryGoalRepository repo;
    late GoalsNotifier notifier;

    setUp(() async {
      repo = _InMemoryGoalRepository();
      notifier = GoalsNotifier(repository: repo);
      await notifier.loadGoals();
    });

    test('adds a single goal with schedulable defaults', () async {
      final added = await notifier.quickAddGoals(['Exercise']);
      expect(added, 1);
      expect(notifier.goals, hasLength(1));
      final g = notifier.goals.single;
      expect(g.name, 'Exercise');
      expect(g.goalType, GoalType.timeTarget);
      // Non-null budget so the engine actually schedules it out of the box.
      expect(g.weeklyHourBudget, isNotNull);
      expect(g.weeklyHourBudget, greaterThan(0));
    });

    test('lays down a full slate of 8 in one paste', () async {
      final names = List.generate(8, (i) => 'Goal ${i + 1}');
      final added = await notifier.quickAddGoals(names);
      expect(added, 8);
      expect(notifier.goals, hasLength(8));
      // Preserved order, appended by sortOrder.
      final sorted = [...notifier.goals]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(sorted.map((g) => g.name), names);
      // Distinct sortOrder values so reorder/priority stays well-defined.
      expect(sorted.map((g) => g.sortOrder).toSet(), hasLength(8));
    });

    test('ignores blank and whitespace-only names', () async {
      final added = await notifier.quickAddGoals(['A', '', '   ', 'B']);
      expect(added, 2);
      expect(notifier.goals.map((g) => g.name).toSet(), {'A', 'B'});
    });

    test('appends after existing goals without clobbering order', () async {
      await notifier.quickAddGoals(['First']);
      await notifier.quickAddGoals(['Second', 'Third']);
      final sorted = [...notifier.goals]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(sorted.map((g) => g.name), ['First', 'Second', 'Third']);
      expect(sorted.map((g) => g.sortOrder).toSet(), hasLength(3));
    });

    test('empty input adds nothing', () async {
      final added = await notifier.quickAddGoals(['', '  ']);
      expect(added, 0);
      expect(notifier.goals, isEmpty);
    });

    test('reports accurate count and does not throw when a save fails', () async {
      // Repo that throws on the 3rd save — simulates disk full / closed box.
      final failing = _FailAfterNRepository(failOnSaveNumber: 3);
      final n = GoalsNotifier(repository: failing);
      await n.loadGoals();

      final added = await n.quickAddGoals(['A', 'B', 'C', 'D']);
      // First two persisted; the failing 3rd stops the run.
      expect(added, 2);
      expect(n.goals.map((g) => g.name).toSet(), {'A', 'B'});
    });
  });
}

/// Repository that throws on the Nth save call (1-indexed).
class _FailAfterNRepository extends _InMemoryGoalRepository {
  _FailAfterNRepository({required this.failOnSaveNumber});
  final int failOnSaveNumber;
  int _saveCount = 0;

  @override
  Future<void> save(Goal goal) async {
    _saveCount++;
    if (_saveCount == failOnSaveNumber) {
      throw StateError('simulated save failure');
    }
    return super.save(goal);
  }
}
