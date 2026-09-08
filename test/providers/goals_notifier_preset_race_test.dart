// Regression tests for GoalsNotifier.addPresetGoal's double-tap and
// concurrent-different-preset races — 34-REVIEW.md WR-01 and WR-02.
//
// Both defects were reproduced by the reviewer directly against this method
// with a 20ms-delayed fake repository, NOT through the widget layer — a
// pumpAndSettle-based widget test cannot hold the async gap open long enough
// to discriminate this class of bug, and a synchronous fake repo resolves
// before the second call is even issued, which is exactly the shape of test
// CLAUDE.md's "assertions that cannot fail" section warns about. This file
// reuses the reviewer's own technique so the tests can actually fail: each
// mutation below was verified RED against the pre-fix `addPresetGoal` (no
// `_pendingPresetNames` guard) before the guard was added, then GREEN after.

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

/// Wraps an in-memory repository's `save` with an artificial delay so a test
/// can hold the async gap between two `addPresetGoal` calls open long enough
/// for both to have started before either resolves — mirrors
/// `test/screens/goals/goal_preset_picker_test.dart`'s `_SlowSaveGoalRepository`
/// exactly, and the delay the reviewer used to reproduce WR-01/WR-02.
class _SlowSaveGoalRepository implements GoalRepository {
  _SlowSaveGoalRepository(this._inner);
  final _InMemoryGoalRepository _inner;

  @override
  Future<List<Goal>> getAll() => _inner.getAll();

  @override
  Future<Goal?> getById(String id) => _inner.getById(id);

  @override
  Future<void> delete(String id) => _inner.delete(id);

  @override
  Future<List<Goal>> getActive() => _inner.getActive();

  @override
  Future<void> save(Goal goal) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await _inner.save(goal);
  }
}

void main() {
  group('GoalsNotifier.addPresetGoal races (34-REVIEW.md WR-01/WR-02)', () {
    late GoalsNotifier notifier;

    setUp(() async {
      final repo = _SlowSaveGoalRepository(_InMemoryGoalRepository());
      notifier = GoalsNotifier(repository: repo);
      await notifier.loadGoals();
    });

    test(
      'WR-01: two concurrent taps on the SAME preset create exactly one '
      'goal — the second is a no-op, not a second creation',
      () async {
        final first = notifier.addPresetGoal('Reading', emoji: '📚');
        final second = notifier.addPresetGoal('Reading', emoji: '📚');

        final results = await Future.wait([first, second]);

        // Ruling (a): the FIRST tap still creates immediately — this is not
        // a guard that delays or blocks creation, only the redundant second.
        expect(results.where((g) => g != null).length, 1);
        expect(notifier.goals, hasLength(1));
        expect(notifier.goals.single.name, 'Reading');
      },
    );

    test(
      'WR-01: the same guard does not block two DIFFERENT presets tapped '
      'concurrently — both create',
      () async {
        final first = notifier.addPresetGoal('Reading', emoji: '📚');
        final second = notifier.addPresetGoal('Exercise', emoji: '🏃');

        await Future.wait([first, second]);

        expect(notifier.goals, hasLength(2));
        expect(notifier.goals.map((g) => g.name).toSet(), {
          'Reading',
          'Exercise',
        });
      },
    );

    test(
      'WR-01: after the in-flight save resolves, the same preset can be '
      'tapped again as a genuinely new call (guard is not permanent)',
      () async {
        final created = await notifier.addPresetGoal('Reading', emoji: '📚');
        expect(created, isNotNull);

        // Archive it, then tap "Reading" again — a fresh, sequential call
        // for a name no longer pending must not be silently swallowed.
        await notifier.archiveGoal(created!.id);
        final recreated = await notifier.addPresetGoal('Reading', emoji: '📚');

        expect(recreated, isNotNull);
        expect(notifier.goals.where((g) => g.name == 'Reading'), hasLength(1));
      },
    );

    test(
      'WR-02: two different presets tapped before either save resolves land '
      'with DISTINCT sortOrder and DISTINCT auto-assigned color',
      () async {
        final first = notifier.addPresetGoal('Reading', emoji: '📚');
        final second = notifier.addPresetGoal('Exercise', emoji: '🏃');

        final results = await Future.wait([first, second]);
        final a = results[0]!;
        final b = results[1]!;

        expect(
          a.sortOrder,
          isNot(equals(b.sortOrder)),
          reason:
              'identical sortOrder defeats goals_screen.dart\'s tie-break, '
              'the exact regression WR-02 reproduced',
        );
        expect(a.color, isNot(equals(b.color)));
      },
    );

    test(
      'WR-02: three presets tapped concurrently all land with distinct '
      'sortOrder values',
      () async {
        final futures = [
          notifier.addPresetGoal('Reading', emoji: '📚'),
          notifier.addPresetGoal('Exercise', emoji: '🏃'),
          notifier.addPresetGoal('Outdoors', emoji: '🌲'),
        ];
        final results = await Future.wait(futures);

        final sortOrders = results.map((g) => g!.sortOrder).toSet();
        expect(sortOrders, hasLength(3));
      },
    );

    test(
      'a failed save releases the guard so the same preset can be retried',
      () async {
        final failing = _FailOnceThenSlowRepository();
        final n = GoalsNotifier(repository: failing);
        await n.loadGoals();

        final failed = await n.addPresetGoal('Reading', emoji: '📚');
        expect(failed, isNull);

        final retried = await n.addPresetGoal('Reading', emoji: '📚');
        expect(retried, isNotNull);
        expect(n.goals, hasLength(1));
      },
    );
  });
}

/// Fails the first save, then delegates subsequent saves to a slow in-memory
/// repository — proves the WR-01 guard releases on failure rather than
/// permanently blocking a retried preset.
class _FailOnceThenSlowRepository implements GoalRepository {
  final _inner = _SlowSaveGoalRepository(_InMemoryGoalRepository());
  var _first = true;

  @override
  Future<List<Goal>> getAll() => _inner.getAll();

  @override
  Future<Goal?> getById(String id) => _inner.getById(id);

  @override
  Future<void> delete(String id) => _inner.delete(id);

  @override
  Future<List<Goal>> getActive() => _inner.getActive();

  @override
  Future<void> save(Goal goal) async {
    if (_first) {
      _first = false;
      throw StateError('simulated save failure');
    }
    await _inner.save(goal);
  }
}
