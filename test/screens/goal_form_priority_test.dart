// Widget tests for the priority SegmentedButton in GoalFormSheet — Phase 9 Plan 02.
//
// Covers ENGINE-06 (UI half):
//   1. Priority label and Low/Normal/High segment labels render.
//   2. New goal defaults to Normal selected (null → 0.5 coalesce).
//   3. Tapping High yields priorityWeight == 0.75 on save.
//   4. Existing goal with null priorityWeight renders as Normal selected.
//   5. Control is visible for every goal type (not inside a type guard).

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/screens/goals/goal_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// In-memory GoalRepository — no Hive I/O.
// ---------------------------------------------------------------------------
class _InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};
  Goal? lastSaved;

  @override
  Future<List<Goal>> getAll() async => _store.values.toList();

  @override
  Future<Goal?> getById(String id) async => _store[id];

  @override
  Future<void> save(Goal goal) async {
    _store[goal.id] = goal;
    lastSaved = goal;
  }

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps GoalFormSheet inside a Scaffold + GoalsNotifier provider.
/// The sheet is pumped directly (not via modal) so all widgets are in the
/// visible render tree, avoiding off-screen hit-test failures.
Future<_InMemoryGoalRepository> _pumpForm(
  WidgetTester tester, {
  Goal? existingGoal,
}) async {
  final repo = _InMemoryGoalRepository();
  if (existingGoal != null) {
    repo._store[existingGoal.id] = existingGoal;
  }
  final notifier = GoalsNotifier(repository: repo);
  await notifier.loadGoals();

  // Pump the sheet directly as a scrollable scaffold body to avoid
  // off-screen rendering that affects modal bottom sheets in test canvases.
  final scrollController = ScrollController();
  await pumpWithMood(
    tester,
    SingleChildScrollView(
      child: GoalFormSheet(
        scrollController: scrollController,
        goal: existingGoal,
      ),
    ),
    extraProviders: [
      ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
    ],
  );

  return repo;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Priority SegmentedButton (ENGINE-06 UI half)', () {
    testWidgets(
      'Priority label and segment labels Low/Normal/High are present',
      (tester) async {
        await _pumpForm(tester);

        expect(find.text('Priority'), findsOneWidget);
        expect(find.text('Low'), findsOneWidget);
        expect(find.text('Normal'), findsOneWidget);
        expect(find.text('High'), findsOneWidget);
      },
    );

    testWidgets(
      'new goal defaults to Normal selected (null coalesces to 0.5)',
      (tester) async {
        await _pumpForm(tester);

        final segBtn = tester.widget<SegmentedButton<double>>(
          find.byType(SegmentedButton<double>),
        );
        expect(
          segBtn.selected,
          equals({0.5}),
          reason: 'New goal: null priorityWeight must coalesce to Normal (0.5)',
        );
      },
    );

    testWidgets(
      'tapping High selects it and save persists priorityWeight == 0.75',
      (tester) async {
        // Use a taller test surface so the full form fits without scrolling.
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repo = await _pumpForm(tester);

        // Tap the High segment button (.first handles internal duplication).
        await tester.tap(find.text('High').first);
        await tester.pumpAndSettle();

        // Verify selected state updated to 0.75.
        final segBtn = tester.widget<SegmentedButton<double>>(
          find.byType(SegmentedButton<double>),
        );
        expect(
          segBtn.selected,
          equals({0.75}),
          reason: 'Tapping High must select 0.75',
        );

        // Type a goal name so Save is enabled.
        await tester.enterText(find.byType(TextField).first, 'Test Goal');
        await tester.pumpAndSettle();

        // Select Time Target type (minimal extra fields, no date picker) to
        // enable the Save button.
        await tester.tap(
          find.text('I want to spend regular time on something'),
        );
        await tester.pumpAndSettle();

        // Tap Add goal ElevatedButton — use .last since 'Add goal' also
        // appears as the sheet title Text above the button.
        await tester.tap(find.text('Add goal').last);
        await tester.pumpAndSettle();

        expect(
          repo.lastSaved?.priorityWeight,
          closeTo(0.75, 0.001),
          reason:
              'Save must persist priorityWeight == 0.75 when High is selected',
        );
      },
    );

    testWidgets(
      'existing goal with null priorityWeight renders Normal selected',
      (tester) async {
        final goal = Goal(
          id: 'g-legacy',
          name: 'Legacy Goal',
          goalTypeIndex: GoalType.habit.index,
          // priorityWeight intentionally omitted — null
        );
        await _pumpForm(tester, existingGoal: goal);

        final segBtn = tester.widget<SegmentedButton<double>>(
          find.byType(SegmentedButton<double>),
        );
        expect(
          segBtn.selected,
          equals({0.5}),
          reason:
              'Legacy goal with null priorityWeight must render as Normal (0.5)',
        );
      },
    );

    testWidgets(
      'priority control visible when Habit goal type is selected',
      (tester) async {
        await _pumpForm(tester);

        await tester.tap(find.text('I want to build a daily habit'));
        await tester.pumpAndSettle();

        expect(
          find.byType(SegmentedButton<double>),
          findsOneWidget,
          reason: 'Priority control must be visible for Habit goal type',
        );
      },
    );

    testWidgets(
      'priority control visible when Outcome goal type is selected',
      (tester) async {
        await _pumpForm(tester);

        await tester.tap(
          find.text("I'm working toward a specific outcome"),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(SegmentedButton<double>),
          findsOneWidget,
          reason: 'Priority control must be visible for Outcome goal type',
        );
      },
    );

    testWidgets(
      'priority control visible when Time Target goal type is selected',
      (tester) async {
        await _pumpForm(tester);

        await tester.tap(
          find.text('I want to spend regular time on something'),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(SegmentedButton<double>),
          findsOneWidget,
          reason: 'Priority control must be visible for Time Target goal type',
        );
      },
    );
  });
}
