// Widget tests for GoalPresetPickerSheet — the guided goal-add flow
// (Phase 34 Plan 01, GOALADD-01/02/03, D-34-01 through D-34-04).
//
// The load-bearing assertions here are mutation-tested, not assumed (CLAUDE.md
// "Assertions that cannot fail"). See 34-01-SUMMARY.md for the actual RED
// output recorded for each of the four Task 1 mutations plus Task 2 and
// Task 3's mutations.
//
// Deliberately avoids two shapes CLAUDE.md documents as measured traps in
// this repo: a bare type-finder on the chip widget (does not match
// subclasses, and over-counts once three screens share this widget) and a
// symbolic assertion on the goal's own budget field (derived from the same
// constant it claims to check, and cannot fail) — every budget assertion
// below reads the rendered text instead.

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/data/repositories/in_memory_completion_log_repository.dart';
import 'package:canopy/data/repositories/in_memory_restorative_item_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:canopy/screens/goals/goal_form_sheet.dart';
import 'package:canopy/screens/goals/goals_screen.dart';
import 'package:canopy/screens/goals/widgets/goal_card.dart';
import 'package:canopy/screens/goals/widgets/goal_preset_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// In-memory GoalRepository — no Hive I/O. Mirrors
// test/screens/goals_add_fork_test.dart's fake exactly.
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

/// Wraps an in-memory repository's `save` with an artificial delay, so a test
/// can observe the double-tap race window (UI-SPEC Decision 4). A settled
/// `pumpAndSettle` cannot see a single-frame race — this fake exists so a
/// test can hold the async gap open across exactly one `pump()`.
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
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _inner.save(goal);
  }
}

class _Harness {
  _Harness(this.goals);
  final GoalsNotifier goals;
}

Future<_Harness> _pumpGoals(
  WidgetTester tester, {
  List<Goal> seed = const [],
  GoalRepository? repository,
}) async {
  final repo = repository ?? _InMemoryGoalRepository();
  if (repository == null) {
    for (final g in seed) {
      await repo.save(g);
    }
  }
  final goals = GoalsNotifier(repository: repo);
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
  return _Harness(goals);
}

/// Taps the screen's one add-goal control, then the goal door — landing on
/// `GoalPresetPickerSheet`.
Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Add goal'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Something to make time for'));
  await tester.pumpAndSettle();
}

Finder _chip(String name) => find.widgetWithText(FilterChip, name);

void main() {
  group('GoalPresetPickerSheet (GOALADD-01/02/03, D-34-01..04)', () {
    testWidgets(
      'GOALADD-01: the goal door opens the preset picker, and no goal form',
      (tester) async {
        await _pumpGoals(tester);
        await _openPicker(tester);

        expect(find.byType(GoalPresetPickerSheet), findsOneWidget);
        expect(find.byType(GoalFormSheet), findsNothing);
      },
    );

    testWidgets(
      'GOALADD-01: all 8 kCommonGoals render as chips carrying word AND glyph',
      (tester) async {
        await _pumpGoals(tester);
        await _openPicker(tester);

        // "any chip subtype" — find.byType does not match subclasses
        // (CLAUDE.md), so a chip-family swap must be caught by a predicate.
        expect(
          find.byWidgetPredicate((w) => w is FilterChip),
          findsNWidgets(8),
        );
        for (final (name, emoji) in kCommonGoals) {
          expect(_chip(name), findsOneWidget, reason: 'missing chip: $name');
          expect(find.text(emoji), findsOneWidget, reason: 'no glyph for $name');
        }
      },
    );

    testWidgets(
      'D-34-01: tapping Reading creates exactly one goal, no dialog, no '
      'form, no spinner in between',
      (tester) async {
        final h = await _pumpGoals(tester);
        await _openPicker(tester);

        await tester.tap(_chip('Reading'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await tester.pumpAndSettle();

        expect(h.goals.goals.length, 1);
        expect(h.goals.goals.single.name, 'Reading');
        // No confirmation dialog appeared as a result of the tap. (The
        // picker sheet itself may render inside a Dialog on wide viewports —
        // that is the sheet's own chrome, not a new dialog the tap opened.)
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(GoalFormSheet), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      "GOALADD-03/D-34-03: the created row renders '3.0 hrs/week' as text",
      (tester) async {
        await _pumpGoals(tester);
        await _openPicker(tester);

        await tester.tap(_chip('Reading'));
        await tester.pumpAndSettle();

        // Scoped to a GoalCard descending from the picker sheet itself: the
        // Goals screen behind the (still-open) sheet also renders a GoalCard
        // for the newly-saved goal via its own Consumer<GoalsNotifier>, so an
        // unscoped find.byType(GoalCard) over-counts by one.
        expect(
          find.descendant(
            of: find.descendant(
              of: find.byType(GoalPresetPickerSheet),
              matching: find.byType(GoalCard),
            ),
            matching: find.text('3.0 hrs/week'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'D-34-04: the glyph renders on the created row AND the model carries '
      'emojiTag',
      (tester) async {
        final h = await _pumpGoals(tester);
        await _openPicker(tester);

        await tester.tap(_chip('Reading'));
        await tester.pumpAndSettle();

        // Scoped to the picker sheet for the same reason as the budget-line
        // test above — the Goals screen behind the sheet renders its own
        // GoalCard for the same goal.
        expect(
          find.descendant(
            of: find.descendant(
              of: find.byType(GoalPresetPickerSheet),
              matching: find.byType(GoalCard),
            ),
            matching: find.text('📚'),
          ),
          findsOneWidget,
        );
        expect(h.goals.goals.single.emojiTag, '📚');
      },
    );

    testWidgets(
      'UI-SPEC Decision 4: the chip is gone one frame after the tap, while '
      'the save is still pending',
      (tester) async {
        final slowRepo = _SlowSaveGoalRepository(_InMemoryGoalRepository());
        final h = await _pumpGoals(tester, repository: slowRepo);
        await _openPicker(tester);

        await tester.tap(_chip('Reading'));
        await tester.pump(); // exactly ONE frame — the save is still pending
        expect(_chip('Reading'), findsNothing);

        await tester.pumpAndSettle();
        expect(h.goals.goals.length, 1);
      },
    );

    testWidgets(
      'UI-SPEC duplicate row: a goal named "reading" (lowercase) hides the '
      'Reading chip',
      (tester) async {
        await _pumpGoals(
          tester,
          seed: [
            Goal(
              id: 'g1',
              name: 'reading',
              goalTypeIndex: GoalType.timeTarget.index,
              color: '#4CAF50',
            ),
          ],
        );
        await _openPicker(tester);

        expect(_chip('Reading'), findsNothing);
      },
    );

    testWidgets(
      'GOALADD-02: one tap on Add your own reaches a blank GoalFormSheet',
      (tester) async {
        await _pumpGoals(tester);
        await _openPicker(tester);

        await tester.tap(find.text('Add your own'));
        await tester.pumpAndSettle();

        expect(find.byType(GoalFormSheet), findsOneWidget);
        expect(find.byType(GoalPresetPickerSheet), findsNothing);
        // CREATE mode specifically, not edit mode with some other goal
        // attached: 'Edit Goal'/'Save Goal' only ever render in edit mode.
        expect(find.text('Edit Goal'), findsNothing);
        expect(find.text('Save Goal'), findsNothing);
      },
    );

    testWidgets(
      'UI-SPEC Decision 2: the picker sheet contains no editable text field '
      'of any kind',
      (tester) async {
        await _pumpGoals(tester);
        await _openPicker(tester);

        // EditableText with a predicate, not find.byType(TextField):
        // find.byType does not match subclasses, and both TextField and
        // TextFormField render an EditableText internally.
        expect(
          find.byWidgetPredicate((w) => w is EditableText),
          findsNothing,
        );
      },
    );

    testWidgets(
      "D-34-02: tapping a Just Added row reaches that goal's form in edit "
      'mode',
      (tester) async {
        await _pumpGoals(tester);
        await _openPicker(tester);

        await tester.tap(_chip('Reading'));
        await tester.pumpAndSettle();

        // Scoped to the picker sheet: the Goals screen behind it also
        // renders a GoalCard for the same goal, so an unscoped
        // find.byType(GoalCard) is ambiguous to tap.
        await tester.tap(
          find.descendant(
            of: find.byType(GoalPresetPickerSheet),
            matching: find.byType(GoalCard),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GoalFormSheet), findsOneWidget);
        // Proves EDIT mode, not create mode: the name field is prefilled.
        expect(find.widgetWithText(TextField, 'Reading'), findsOneWidget);
      },
    );

    testWidgets(
      'UI-SPEC Decision 5: with all 8 presets already claimed, Common is '
      'absent and Add your own still shows',
      (tester) async {
        final seeds = [
          for (final (name, _) in kCommonGoals)
            Goal(
              name: name,
              goalTypeIndex: GoalType.timeTarget.index,
              color: '#4CAF50',
            ),
        ];
        await _pumpGoals(tester, seed: seeds);
        await _openPicker(tester);

        expect(find.text('Common'), findsNothing);
        expect(
          find.byWidgetPredicate((w) => w is FilterChip),
          findsNothing,
        );
        expect(find.text('Add your own'), findsOneWidget);
      },
    );

    testWidgets(
      'Done closes the sheet, leaving goals created this visit on the '
      'Goals screen',
      (tester) async {
        final h = await _pumpGoals(tester);
        await _openPicker(tester);

        await tester.tap(_chip('Reading'));
        await tester.pumpAndSettle();

        final doneButton = find.widgetWithText(FilledButton, 'Done');
        await tester.ensureVisible(doneButton);
        await tester.tap(doneButton);
        await tester.pumpAndSettle();

        expect(find.byType(GoalPresetPickerSheet), findsNothing);
        expect(h.goals.goals.single.name, 'Reading');
      },
    );
  });
}
