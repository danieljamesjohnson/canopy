// Widget tests for the valence SegmentedButton in GoalFormSheet — Phase 19 Plan 01.
//
// Covers ENERGY-02:
//   1. "Energy" section label renders.
//   2. SegmentedButton<EnergyValence> with "Gives energy"/"Neutral"/"Costs energy" segments renders.
//   3. New goal defaults to Neutral selected.
//   4. Tapping "Gives energy" then Save yields a saved Goal with energyValence == EnergyValence.gives.
//   5. Editing a goal with a persisted valence shows it pre-selected.
//
// RED: This file fails to compile because EnergyValence / Goal.energyValenceIndex
// / Goal.emojiTag / SegmentedButton<EnergyValence> in GoalFormSheet do not exist yet.

import 'package:canopy/data/models/energy_valence.dart'; // does not exist yet — RED
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/screens/goals/goal_form_sheet.dart';
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

/// Pumps GoalFormSheet directly as a scrollable body (avoids off-screen
/// hit-test failures from modal presentation).
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

/// Pumps GoalFormSheet inside a real showModalBottomSheet at a constrained
/// height (390x844 / initialChildSize 0.5) so scrollUntilVisible does genuine
/// work reaching the Energy selector and Save button.
Future<_InMemoryGoalRepository> _pumpModal(WidgetTester tester) async {
  setViewport(tester, const Size(390, 844));

  final repo = _InMemoryGoalRepository();
  final notifier = GoalsNotifier(repository: repo);

  late BuildContext capturedCtx;
  await pumpWithMood(
    tester,
    Builder(
      builder: (ctx) {
        capturedCtx = ctx;
        return const SizedBox.shrink();
      },
    ),
    extraProviders: [
      ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
    ],
  );

  showModalBottomSheet<void>(
    context: capturedCtx,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 1.0,
      expand: false,
      snap: true,
      snapSizes: const [0.5, 1.0],
      builder: (_, sc) => GoalFormSheet(scrollController: sc),
    ),
  );
  await tester.pumpAndSettle();

  return repo;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Energy valence SegmentedButton (ENERGY-02)', () {
    testWidgets('"Energy" section label renders', (tester) async {
      await _pumpForm(tester);

      expect(
        find.text('Energy'),
        findsOneWidget,
        reason: 'Energy section label must be visible in GoalFormSheet',
      );
    });

    testWidgets(
      'segment labels "Gives energy", "Neutral", "Costs energy" all render',
      (tester) async {
        await _pumpForm(tester);

        expect(find.text('Gives energy'), findsOneWidget);
        expect(find.text('Neutral'), findsOneWidget);
        expect(find.text('Costs energy'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Costs energy')).dx,
          lessThan(tester.getTopLeft(find.text('Gives energy')).dx),
          reason:
              'G-01: valence control must read Costs energy (left) -> Neutral -> Gives energy (right)',
        );
      },
    );

    testWidgets('new goal defaults to Neutral selected', (tester) async {
      await _pumpForm(tester);

      // SegmentedButton<EnergyValence> does not exist yet — RED
      final segBtn = tester.widget<SegmentedButton<EnergyValence>>(
        find.byType(SegmentedButton<EnergyValence>),
      );
      expect(
        segBtn.selected,
        equals({EnergyValence.neutral}),
        reason: 'New goal must default valence to Neutral',
      );
    });

    testWidgets(
      'editing an existing goal with gives valence shows "Gives energy" pre-selected',
      (tester) async {
        final goal = Goal(
          id: 'g-gives',
          name: 'Morning Run',
          goalTypeIndex: GoalType.habit.index,
          energyValenceIndex:
              EnergyValence.gives.index, // field does not exist — RED
        );
        await _pumpForm(tester, existingGoal: goal);

        final segBtn = tester.widget<SegmentedButton<EnergyValence>>(
          find.byType(SegmentedButton<EnergyValence>),
        );
        expect(
          segBtn.selected,
          equals({EnergyValence.gives}),
          reason:
              'Editing a goal with valence=gives must pre-select "Gives energy" segment',
        );
      },
    );

    testWidgets(
      'tapping "Gives energy" then Save persists energyValence == gives (ENERGY-02)',
      (tester) async {
        final repo = await _pumpModal(tester);

        // Select a goal type to enable Save button.
        await tester.tap(
          find.text('I want to spend regular time on something'),
        );
        await tester.pumpAndSettle();

        // Scroll to the Energy selector.
        await tester.scrollUntilVisible(
          find.byType(SegmentedButton<EnergyValence>),
          100,
          scrollable: find.byType(Scrollable).first,
        );

        // Tap "Gives energy".
        await tester.tap(find.text('Gives energy'));
        await tester.pumpAndSettle();

        // Verify selection changed.
        final segBtn = tester.widget<SegmentedButton<EnergyValence>>(
          find.byType(SegmentedButton<EnergyValence>),
        );
        expect(
          segBtn.selected,
          equals({EnergyValence.gives}),
          reason: 'Tapping "Gives energy" must select EnergyValence.gives',
        );

        // Enter a name so Save is enabled.
        await tester.enterText(find.byType(TextField).first, 'Morning Run');
        await tester.pumpAndSettle();

        // Scroll to and tap Save.
        await tester.scrollUntilVisible(
          find.byType(ElevatedButton),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Add Goal').last);
        await tester.pumpAndSettle();

        expect(
          repo.lastSaved?.energyValence, // getter does not exist — RED
          equals(EnergyValence.gives),
          reason:
              'Saved goal must have energyValence == EnergyValence.gives '
              'when "Gives energy" was selected — ENERGY-02',
        );
      },
    );
  });
}
