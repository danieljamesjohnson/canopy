// Widget tests for the GoalsScreen quick-add bar — frictionless slate entry.
//
// The critical case (regression guard): pasting a newline-separated list must
// explode into N goals, not collapse into one mashed goal. A single-line
// TextField strips newlines; the quick-add field must be multi-line.

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/screens/goals/goals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

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
  group('GoalsScreen quick-add', () {
    late _InMemoryGoalRepository repo;
    late GoalsNotifier notifier;

    setUp(() async {
      repo = _InMemoryGoalRepository();
      notifier = GoalsNotifier(repository: repo);
      await notifier.loadGoals();
    });

    Future<void> pump(WidgetTester tester) async {
      await pumpWithMood(
        tester,
        const GoalsScreen(),
        extraProviders: [
          ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
        ],
      );
      await tester.pump(); // settle addPostFrameCallback loadGoals
    }

    testWidgets('pasting a newline-separated slate creates N goals', (
      tester,
    ) async {
      await pump(tester);

      // Simulate a paste of a full slate of 8 into the quick-add field.
      final names = List.generate(8, (i) => 'Goal ${i + 1}');
      await tester.enterText(
        find.byType(TextField).first,
        names.join('\n'),
      );
      await tester.pumpAndSettle();

      // Every complete line (all but the last, which has no trailing newline)
      // commits immediately; flush the trailing one via the field's submit.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(notifier.goals, hasLength(8));
      expect(notifier.goals.map((g) => g.name).toSet(), names.toSet());
    });

    testWidgets('type-and-Enter adds one goal and clears the field', (
      tester,
    ) async {
      await pump(tester);

      final field = find.byType(TextField).first;
      // Typing a line that ends in a newline == pressing Enter after the name.
      await tester.enterText(field, 'Exercise\n');
      await tester.pumpAndSettle();

      expect(notifier.goals, hasLength(1));
      expect(notifier.goals.single.name, 'Exercise');
      // Field is cleared and ready for the next goal.
      expect(tester.widget<TextField>(field).controller!.text, '');
    });
  });
}
