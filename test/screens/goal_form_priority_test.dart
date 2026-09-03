// Widget tests for the priority SegmentedButton in GoalFormSheet — Phase 9 Plan 02.
//
// Covers ENGINE-06 (UI half):
//   1. Priority label and Low/Normal/High segment labels render.
//   2. New goal defaults to Normal selected (null → 0.5 coalesce).
//   3. Tapping High yields priorityWeight == 0.75 on save.
//   4. Existing goal with null priorityWeight renders as Normal selected.
//   5. Control is visible for every goal type (not inside a type guard).
//
// GOALFORM-02 (Phase 16 Plan 01):
//   Replaces two setSurfaceSize(800,1200) tests with constrained-modal-height tests
//   at 390x844 viewport / initialChildSize 0.5 — covering time-target, outcome,
//   AND habit goals, and folding in the High-saves-0.75 and 3-hr-default
//   assertions so no coverage is lost. initialChildSize 0.5 (422pt) forces ALL
//   three goal types to require real scrolling to reach Priority and Save.

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

/// Opens GoalFormSheet inside a real showModalBottomSheet + DraggableScrollableSheet
/// at a constrained modal height (390x844 viewport, initialChildSize 0.5).
///
/// initialChildSize 0.5 → modal height = 844 * 0.5 = 422pt. This is small
/// enough that ALL three goal types (time-target, outcome, habit) require real
/// scrolling to reach the Priority selector and Save button, so every
/// scrollUntilVisible call in GOALFORM-02 does genuine work.
///
/// Returns the [_InMemoryGoalRepository] so callers can assert on [lastSaved].
/// [setViewport] auto-registers teardown — caller must NOT add another teardown.
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

  // Do NOT await — showModalBottomSheet's Future only resolves on dismiss.
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

    testWidgets('priority control visible when Habit goal type is selected', (
      tester,
    ) async {
      await _pumpForm(tester);

      await tester.tap(find.text('I want to build a daily habit'));
      await tester.pumpAndSettle();

      expect(
        find.byType(SegmentedButton<double>),
        findsOneWidget,
        reason: 'Priority control must be visible for Habit goal type',
      );
    });

    testWidgets('priority control visible when Outcome goal type is selected', (
      tester,
    ) async {
      await _pumpForm(tester);

      await tester.tap(find.text("I'm working toward a specific outcome"));
      await tester.pumpAndSettle();

      expect(
        find.byType(SegmentedButton<double>),
        findsOneWidget,
        reason: 'Priority control must be visible for Outcome goal type',
      );
    });

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

  // ---------------------------------------------------------------------------
  // GOALFORM-02 — true modal height contract (Phase 16 Plan 01)
  //
  // Replaces the two deprecated setSurfaceSize(800,1200) tests.
  // All tests pump GoalFormSheet inside a real showModalBottomSheet +
  // DraggableScrollableSheet at initialChildSize 0.5 on a 390x844 viewport.
  // Modal height = 844 * 0.5 = 422pt.
  //
  // initialChildSize 0.5 is small enough that ALL three goal types require
  // real scrolling to reach Priority and Save — so scrollUntilVisible does
  // genuine work for every variant, not just outcome. Tests in this group
  // would fail if Priority or Save were clipped or missing from the scroll
  // extent entirely.
  // ---------------------------------------------------------------------------
  group('GOALFORM-02 — true modal height contract', () {
    testWidgets(
      'time-target goal: Priority selector and Save reachable via scroll '
      'at constrained modal height (390x844 / initialChildSize 0.5)',
      (tester) async {
        await _pumpModal(tester);

        // Select the time-target goal type.
        await tester.tap(
          find.text('I want to spend regular time on something'),
        );
        await tester.pumpAndSettle();

        // Priority selector (SegmentedButton<double>) must be reachable via scroll.
        // Type parameter required — find.byType(SegmentedButton) without <double>
        // does not match (16-RESEARCH.md Pitfall 6).
        //
        // find.byType(Scrollable).first finds the SingleChildScrollView's Scrollable
        // inside GoalFormSheet. DraggableScrollableSheet has no separate Scrollable
        // of its own — it delegates to the content's ScrollController (sc), which is
        // the controller for GoalFormSheet's SingleChildScrollView. Using
        // find.byType(SingleChildScrollView) as the scrollable arg fails because
        // scrollUntilVisible casts the found widget to Scrollable directly.
        await tester.scrollUntilVisible(
          find.byType(SegmentedButton<double>),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(SegmentedButton<double>), findsOneWidget);

        // Save button (ElevatedButton) must be reachable via scroll.
        await tester.scrollUntilVisible(
          find.byType(ElevatedButton),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(ElevatedButton), findsOneWidget);
      },
    );

    testWidgets(
      'outcome goal: Priority selector and Save reachable via scroll at '
      'constrained modal height — outcome content exceeds modal (422pt), '
      'so real scrolling is required',
      (tester) async {
        await _pumpModal(tester);

        // Select the outcome goal type — deepest variant with most fields.
        await tester.tap(find.text("I'm working toward a specific outcome"));
        await tester.pumpAndSettle();

        // Priority selector must be reachable via scroll (may be below fold).
        await tester.scrollUntilVisible(
          find.byType(SegmentedButton<double>),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(SegmentedButton<double>), findsOneWidget);

        // Save button (ElevatedButton) must be reachable via scroll.
        // The outcome form's Save is below the date picker + description field —
        // this scroll is the core correctness assertion for GOALFORM-02.
        await tester.scrollUntilVisible(
          find.byType(ElevatedButton),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(ElevatedButton), findsOneWidget);
      },
    );

    testWidgets(
      'habit goal: Priority selector and Save reachable via scroll at '
      'constrained modal height (390x844 / initialChildSize 0.5)',
      (tester) async {
        await _pumpModal(tester);

        // Select the habit goal type.
        await tester.tap(find.text('I want to build a daily habit'));
        await tester.pumpAndSettle();

        // Priority selector must be reachable via scroll.
        await tester.scrollUntilVisible(
          find.byType(SegmentedButton<double>),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(SegmentedButton<double>), findsOneWidget);

        // Save button (ElevatedButton) must be reachable via scroll.
        await tester.scrollUntilVisible(
          find.byType(ElevatedButton),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(ElevatedButton), findsOneWidget);
      },
    );

    testWidgets(
      'tapping High selects it and save persists priorityWeight == 0.75 '
      '(folded in from replaced setSurfaceSize test — at true modal height)',
      (tester) async {
        final repo = await _pumpModal(tester);

        // Select time-target (minimal extra fields; avoids date-picker
        // complications and enables Add goal).
        await tester.tap(
          find.text('I want to spend regular time on something'),
        );
        await tester.pumpAndSettle();

        // Scroll to and tap the High segment.
        await tester.scrollUntilVisible(
          find.byType(SegmentedButton<double>),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('High'));
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

        // Enter a goal name so Save is enabled (_canSave requires non-empty name).
        await tester.enterText(find.byType(TextField).first, 'Test Goal');
        await tester.pumpAndSettle();

        // Scroll to and tap 'Add Goal'. Use .last because 'Add Goal' also
        // appears as the sheet title Text above the ElevatedButton.
        await tester.scrollUntilVisible(
          find.byType(ElevatedButton),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Add Goal').last);
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
      'selecting Regular time defaults the weekly budget to 3 hrs and saves it '
      '(folded in from replaced setSurfaceSize test — at true modal height)',
      (tester) async {
        final repo = await _pumpModal(tester);

        // Enter a goal name first (Save is disabled until name is non-empty).
        await tester.enterText(find.byType(TextField).first, 'Family');
        await tester.pumpAndSettle();

        // Select time-target type — this sets weeklyHourBudget to 3.0.
        await tester.tap(
          find.text('I want to spend regular time on something'),
        );
        await tester.pumpAndSettle();

        // Scroll to the weekly-hours field and verify it shows '3.0'.
        await tester.scrollUntilVisible(
          find.text('3.0'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text('3.0'),
          findsOneWidget,
          reason: 'Regular-time goal must default the weekly budget to 3.0 hrs',
        );

        // Scroll to and tap 'Add Goal'.
        await tester.scrollUntilVisible(
          find.byType(ElevatedButton),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Add Goal').last);
        await tester.pumpAndSettle();

        expect(
          repo.lastSaved?.weeklyHourBudget,
          closeTo(3.0, 0.001),
          reason:
              'A regular-time goal saved without edits must persist 3.0 hrs/week '
              'so the engine has a budget to schedule against',
        );
      },
    );
  });
}
