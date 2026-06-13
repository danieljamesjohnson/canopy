// Widget test for the GoalsScreen heading — Phase 14 Plan 01 (GOALS-01).
//
// Verifies that when goals exist, the screen renders:
//   - "Your goals" heading (titleMedium w600)
//   - "Drag to prioritize. Tap to edit." subhead (bodySmall onSurfaceVariant)

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/screens/goals/goals_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// In-memory GoalRepository — no Hive I/O.
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
  group('GoalsScreen heading', () {
    testWidgets('shows "Your goals" heading and subhead when goals exist',
        (tester) async {
      final repo = _InMemoryGoalRepository();
      // Seed one goal so allEmpty == false → heading renders.
      await repo.save(
        Goal(
          id: 'g1',
          name: 'Exercise',
          goalTypeIndex: GoalType.habit.index,
          color: '#4CAF50',
        ),
      );
      final notifier = GoalsNotifier(repository: repo);
      // Pre-load goals before pump so the notifier has data immediately.
      await notifier.loadGoals();

      await pumpWithMood(
        tester,
        const GoalsScreen(),
        extraProviders: [
          ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
        ],
      );

      // Pump one more frame to settle the addPostFrameCallback loadGoals call.
      await tester.pump();

      expect(find.text('Your goals'), findsOneWidget);
      expect(
        find.text('Drag to prioritize. Tap to edit.'),
        findsOneWidget,
      );
    });
  });
}
