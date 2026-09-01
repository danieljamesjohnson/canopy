// Widget test for the GoalsScreen heading.
//
// Phase 33 Plan 03 (OBVIOUS-02, UI-SPEC items 10 + 28) — Kind B repoint. The
// PREMISE changed, not just the expected value: this file used to assert a
// "Your goals" heading plus a "Drag to prioritize. Tap to edit." sub-line
// (Phase 14 Plan 01, GOALS-01). The screen now names its own purpose in the
// heading itself, and the sub-line was DELETED rather than reworded —
// instructions go, labels stay. So the two old assertions are inverted here
// on purpose: their absence is the requirement.
//
// Verifies that when goals exist, the screen renders:
//   - "Priority order" heading (titleMedium w600) and nothing beneath it
//   - neither of the two retired strings

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/data/repositories/in_memory_completion_log_repository.dart';
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
    testWidgets(
        'shows the "Priority order" heading and no sub-line when goals exist',
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
        // An in-memory log repository so no Hive box is touched.
        GoalsScreen(
          completionLogRepository: InMemoryCompletionLogRepository(),
        ),
        extraProviders: [
          ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
        ],
      );

      // Pump one more frame to settle the addPostFrameCallback loadGoals call.
      await tester.pump();

      expect(find.text('Priority order'), findsOneWidget);

      // The retired copy. Both strings are gone, not reworded.
      expect(find.text('Your goals'), findsNothing);
      expect(find.text('Drag to prioritize. Tap to edit.'), findsNothing);
    });
  });
}
