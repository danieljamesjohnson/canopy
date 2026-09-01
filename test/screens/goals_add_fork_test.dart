// Widget tests for the front-door fork in front of the Goals FAB.
//
// Phase 33 Plan 04 — OBVIOUS-03, UI-SPEC items 24-27.
//
// The third test is the load-bearing one. Item 27 lets the restorative door
// promise "Never scheduled. Never counted toward a budget or a streak.", and
// that promise is only credible if choosing it genuinely never produces a
// `Goal` — a restorative that became a goal would acquire a weekly budget and
// enter the scheduler (threat register T-33-12). So the test asserts both the
// absence of `GoalFormSheet` at every step AND that `GoalsNotifier.goals` stays
// empty; asserting only the first would pass on a path that quietly saved a
// goal without showing its form.
//
// Mutation-tested rather than assumed (CLAUDE.md, "Assertions that cannot
// fail"): routing the restorative door back to `showAdaptiveFormModal` turns
// tests 1, 3 and 4 RED; dropping the fork in front of `_openAddSheet` turns
// tests 1, 3 and 4 RED; adding the fork to `_openEditSheet` turns test 5 RED.

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/data/repositories/in_memory_completion_log_repository.dart';
import 'package:canopy/data/repositories/in_memory_restorative_item_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:canopy/screens/goals/goal_form_sheet.dart';
import 'package:canopy/screens/goals/goals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';
import '../test_helpers/viewport.dart';

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

// The two door titles and the two consequence lines, as the user reads them.
const _goalDoor = 'Something to make time for';
const _restorativeDoor = 'Something that restores you';
const _goalConsequence =
    'Gets a type, a weekly budget and a priority. Canopy schedules it.';
const _restorativeConsequence =
    'Never scheduled. Never counted toward a budget or a streak.';

class _Harness {
  _Harness(this.goals, this.restoratives);

  final GoalsNotifier goals;
  final RestorativesNotifier restoratives;
}

Future<_Harness> _pumpGoals(
  WidgetTester tester, {
  List<Goal> seed = const [],
}) async {
  final goalRepo = _InMemoryGoalRepository();
  for (final g in seed) {
    await goalRepo.save(g);
  }
  final goals = GoalsNotifier(repository: goalRepo);
  await goals.loadGoals();
  final restoratives = RestorativesNotifier(
    repository: InMemoryRestorativeItemRepository(),
  );

  await pumpWithMood(
    tester,
    GoalsScreen(completionLogRepository: InMemoryCompletionLogRepository()),
    extraProviders: [
      ChangeNotifierProvider<GoalsNotifier>.value(value: goals),
      ChangeNotifierProvider<RestorativesNotifier>.value(value: restoratives),
    ],
  );
  await tester.pumpAndSettle();
  return _Harness(goals, restoratives);
}

Future<void> _tapFab(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

void main() {
  group('Goals add fork (OBVIOUS-03, UI-SPEC 24-27)', () {
    testWidgets('the FAB asks which kind FIRST — no goal form yet',
        (tester) async {
      await _pumpGoals(tester);

      await _tapFab(tester);

      expect(find.text(_goalDoor), findsOneWidget);
      expect(find.text(_restorativeDoor), findsOneWidget);
      // Each door states its own consequence in one line (item 27).
      expect(find.text(_goalConsequence), findsOneWidget);
      expect(find.text(_restorativeConsequence), findsOneWidget);
      // The fork comes BEFORE any form exists.
      expect(find.byType(GoalFormSheet), findsNothing);
    });

    testWidgets('the goal door opens the goal form', (tester) async {
      await _pumpGoals(tester);

      await _tapFab(tester);
      await tester.tap(find.text(_goalDoor));
      await tester.pumpAndSettle();

      expect(find.byType(GoalFormSheet), findsOneWidget);
      expect(find.text(_goalDoor), findsNothing);
    });

    testWidgets(
        'the restorative door saves a RestorativeItem and never a Goal — '
        'no goal form at any point (T-33-12)', (tester) async {
      final h = await _pumpGoals(tester);

      await _tapFab(tester);
      expect(find.byType(GoalFormSheet), findsNothing);

      await tester.tap(find.text(_restorativeDoor));
      await tester.pumpAndSettle();
      expect(find.byType(GoalFormSheet), findsNothing);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ).first,
        'Play guitar',
      );
      await tester.pumpAndSettle();
      expect(find.byType(GoalFormSheet), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Add'),
        ),
      );
      await tester.pumpAndSettle();

      // The promise, asserted on both sides.
      expect(h.restoratives.items.length, 1);
      expect(h.restoratives.items.single.name, 'Play guitar');
      expect(h.goals.goals, isEmpty);
      expect(find.byType(GoalFormSheet), findsNothing);

      // Let the confirmation SnackBar's display timer fire so it does not leak
      // into teardown as a pending timer.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('cancelling the fork creates nothing of either kind',
        (tester) async {
      final h = await _pumpGoals(tester);

      await _tapFab(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text(_goalDoor), findsNothing);
      expect(find.byType(GoalFormSheet), findsNothing);
      expect(h.goals.goals, isEmpty);
      expect(h.restoratives.items, isEmpty);
    });

    testWidgets('tapping an existing goal opens the form with NO fork',
        (tester) async {
      await _pumpGoals(
        tester,
        seed: [
          Goal(
            id: 'g1',
            name: 'Exercise',
            goalTypeIndex: GoalType.habit.index,
            color: '#4CAF50',
          ),
        ],
      );

      await tester.tap(find.text('Exercise'));
      await tester.pumpAndSettle();

      // Editing an existing goal has already answered the fork's question
      // (item 24's boundary) — neither door may appear on this path.
      expect(find.text(_goalDoor), findsNothing);
      expect(find.text(_restorativeDoor), findsNothing);
      expect(find.byType(GoalFormSheet), findsOneWidget);
    });

    testWidgets('on a phone both doors and both consequence lines still fit',
        (tester) async {
      // Below the 720dp breakpoint the goal door leads to a bottom sheet
      // rather than a dialog, and the fork itself has ~40dp less width than
      // its own 360dp cap. An overflow on either fails this test.
      setViewport(tester, const Size(390, 844));
      await _pumpGoals(tester);

      await _tapFab(tester);
      expect(find.text(_goalDoor), findsOneWidget);
      expect(find.text(_restorativeDoor), findsOneWidget);
      expect(find.text(_goalConsequence), findsOneWidget);
      expect(find.text(_restorativeConsequence), findsOneWidget);

      await tester.tap(find.text(_goalDoor));
      await tester.pumpAndSettle();
      expect(find.byType(GoalFormSheet), findsOneWidget);
    });
  });
}
