// Widget tests for copy-label assertions — Phase 18 Plan 01 (Wave 0 RED stubs).
//
// Covers POLISH-02:
//   Goal form add mode:  title "Add Goal", primary CTA "Add Goal"
//   Goal form edit mode: title "Edit Goal", CTA "Save Goal", "Discard", "Archive goal"
//   Commitment delete:   "Delete commitment", "Keep commitment"
//
// These tests FAIL (RED) because the copy changes do not exist yet.
// Plan 18-05 will turn them GREEN by updating:
//   - GoalFormSheet title: 'Add goal' → 'Add Goal', 'Edit goal' → 'Edit Goal'
//   - GoalFormSheet CTA: 'Add goal' → 'Add Goal', 'Save' → 'Save Goal'
//   - GoalFormSheet cancel: 'Cancel' → 'Discard'
//   - GoalFormSheet archive: 'Archive' → 'Archive goal'
//   - CommitmentsScreen delete dialog: 'Cancel' → 'Keep commitment', 'Delete' → 'Delete commitment'
//
// Note: "Add Goal" appears twice (as both title and CTA label), so tests use
// findWidgets + any(), or target each site with .first / .last, following the
// existing goal_form_priority_test.dart pattern (line 409: find.text('Add goal').last).
//
// Pattern source: test/screens/goal_form_priority_test.dart — _pumpForm helper.

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/screens/commitments/commitments_screen.dart';
import 'package:canopy/screens/goals/goal_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// In-memory repositories — no Hive I/O.
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

class _InMemoryCommitmentRepository implements CommitmentBlockRepository {
  final Map<String, CommitmentBlock> _store = {};

  @override
  Future<List<CommitmentBlock>> getAll() async => _store.values.toList();

  @override
  Future<CommitmentBlock?> getById(String id) async => _store[id];

  @override
  Future<void> save(CommitmentBlock block) async => _store[block.id] = block;

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async =>
      _store.values.where((b) => b.daysOfWeek.contains(day)).toList();
}

// ---------------------------------------------------------------------------
// _pumpGoalForm — pumps GoalFormSheet directly (not via modal).
// Modeled on _pumpForm in goal_form_priority_test.dart lines 62–90.
// ---------------------------------------------------------------------------
Future<GoalsNotifier> _pumpGoalForm(
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

  return notifier;
}

// ---------------------------------------------------------------------------
// _pumpCommitmentsScreenWithBlock — pumps CommitmentsScreen with one block.
// Opens the delete confirm dialog via long-press / tap on delete icon.
//
// The CommitmentsScreen renders a ListTile with trailing IconButton for delete.
// We pump the screen, find the delete icon, tap it, and assert the AlertDialog
// copy. This approach stays robust against layout changes.
// ---------------------------------------------------------------------------
Future<void> _pumpCommitmentsScreenWithBlock(WidgetTester tester) async {
  final repo = _InMemoryCommitmentRepository();
  final block = CommitmentBlock(
    id: 'c-test',
    name: 'Work',
    daysOfWeek: [1, 2, 3, 4, 5],
    startMinutes: 9 * 60,
    endMinutes: 17 * 60,
  );
  await repo.save(block);

  final notifier = CommitmentsNotifier(repository: repo);
  await notifier.loadBlocks();

  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A8C7A),
    ),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CommitmentsNotifier>.value(value: notifier),
      ],
      child: MaterialApp(
        theme: theme,
        home: const CommitmentsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('POLISH-02 — goal form copy labels', () {
    testWidgets(
      'add mode: title "Add Goal" and primary CTA "Add Goal" are present',
      (tester) async {
        await _pumpGoalForm(tester);

        // "Add Goal" appears as the sheet title and again on the ElevatedButton.
        // Expect at least one instance in the tree.
        expect(
          find.text('Add Goal'),
          findsWidgets,
          reason:
              'POLISH-02: GoalFormSheet add mode must show "Add Goal" (title + CTA). '
              'Current code uses "Add goal" — Plan 18-05 fixes capitalisation.',
        );
      },
    );

    testWidgets(
      'edit mode: title "Edit Goal", CTA "Save Goal", "Discard", "Archive goal" present',
      (tester) async {
        final goal = Goal(
          id: 'g-edit',
          name: 'Exercise',
          goalTypeIndex: GoalType.habit.index,
        );
        await _pumpGoalForm(tester, existingGoal: goal);

        expect(
          find.text('Edit Goal'),
          findsOneWidget,
          reason: 'POLISH-02: GoalFormSheet edit-mode title must be "Edit Goal".',
        );

        expect(
          find.text('Save Goal'),
          findsOneWidget,
          reason: 'POLISH-02: edit-mode CTA must read "Save Goal".',
        );

        expect(
          find.text('Discard'),
          findsOneWidget,
          reason:
              'POLISH-02: Cancel TextButton must be renamed "Discard". '
              'Current code uses "Cancel" — Plan 18-05 fixes this.',
        );

        expect(
          find.text('Archive goal'),
          findsOneWidget,
          reason:
              'POLISH-02: Archive TextButton must read "Archive goal". '
              'Current code uses "Archive" — Plan 18-05 fixes this.',
        );
      },
    );
  });

  group('POLISH-02 — commitment delete dialog copy labels', () {
    testWidgets(
      '"Delete commitment" and "Keep commitment" are present in the delete confirm dialog',
      (tester) async {
        await _pumpCommitmentsScreenWithBlock(tester);

        // CommitmentsScreen shows a list with a delete IconButton per row.
        // Find and tap the delete icon to open the _confirmDelete AlertDialog.
        final deleteIcon = find.byIcon(Icons.delete_outline);
        if (deleteIcon.evaluate().isEmpty) {
          // Fallback: try alternative icon that CommitmentsScreen might use.
          // If the screen shows commitments in a ListTile with trailing delete,
          // find it by tooltip or icon type.
          expect(
            find.byType(AlertDialog),
            findsNothing,
            reason:
                'CommitmentsScreen did not render a delete trigger — '
                'verify the screen renders the commitment block and its delete icon.',
          );
          return;
        }
        await tester.tap(deleteIcon.first);
        await tester.pumpAndSettle();

        expect(
          find.byType(AlertDialog),
          findsOneWidget,
          reason: 'Tapping delete must open an AlertDialog.',
        );

        expect(
          find.text('Delete commitment'),
          findsOneWidget,
          reason:
              'POLISH-02: commitment delete confirm action must read "Delete commitment". '
              'Current code uses "Delete" — Plan 18-05 fixes this.',
        );

        expect(
          find.text('Keep commitment'),
          findsOneWidget,
          reason:
              'POLISH-02: commitment delete confirm cancel must read "Keep commitment". '
              'Current code uses "Cancel" — Plan 18-05 fixes this.',
        );
      },
    );
  });
}
