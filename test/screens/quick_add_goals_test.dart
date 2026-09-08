// Widget tests for quick-add goal entry — frictionless slate entry.
//
// The critical case (regression guard): pasting a newline-separated list must
// explode into N goals, not collapse into one mashed goal. A single-line
// TextField strips newlines; the quick-add field must be multi-line.
//
// ---------------------------------------------------------------------------
// RETARGETED 2026-09-08 — from GoalsScreen to QuickAddField itself
// ---------------------------------------------------------------------------
// The Goals screen no longer has a quick-add field. The owner diagnosed the
// real defect as having TWO add-goal flows — "one on the top with text, one on
// the bottom with guiding" — where the text one silently created a goal with a
// 3.0 hrs/week budget he never chose. The guided path took its place and the
// FAB was deleted (see goals_add_fork_test.dart).
//
// These tests were NOT retired with it, because every behaviour they guard is
// still live: `QuickAddField` still ships and onboarding uses it for both goals
// and restoratives, where the guided alternative is the surrounding flow rather
// than a competing button. Deleting them would have dropped real coverage of
// working code — a paste that mashes 8 goals into 1, a rapid-entry race that
// drops names, a failed save that strands text — on the grounds that one of
// three call sites went away.
//
// They now pump the WIDGET plus the real notifier, which is where all of that
// behaviour actually lives. That also makes them immune to either screen's
// layout, so this cannot happen again.

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/widgets/quick_add_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

class _InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};

  /// Artificial per-save latency, to expose drop-on-busy races.
  final Duration saveDelay;

  _InMemoryGoalRepository({this.saveDelay = Duration.zero});

  @override
  Future<List<Goal>> getAll() async => _store.values.toList();

  @override
  Future<Goal?> getById(String id) async => _store[id];

  /// When > 0, the next [failNextSaves] save calls throw, then saves recover.
  int failNextSaves = 0;

  @override
  Future<void> save(Goal goal) async {
    if (saveDelay > Duration.zero) await Future<void>.delayed(saveDelay);
    if (failNextSaves > 0) {
      failNextSaves--;
      throw StateError('simulated save failure');
    }
    _store[goal.id] = goal;
  }

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}

void main() {
  group('quick-add goal entry (QuickAddField + GoalsNotifier)', () {
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
        // The exact wiring onboarding uses (onboarding_screen.dart:203-210):
        // the field delegates persistence to `quickAddGoals`, which returns how
        // many actually landed so a partial failure can be surfaced without
        // losing the user's input.
        QuickAddField(
          onSubmit: (names) => notifier.quickAddGoals(names),
          multiAddNoun: 'goals',
          addTooltip: 'Add goal',
          hintText: 'Add a goal',
        ),
        extraProviders: [
          ChangeNotifierProvider<GoalsNotifier>.value(value: notifier),
        ],
      );
      await tester.pump();
    }

    testWidgets('pasting a slate of 8 with NO trailing newline creates all 8', (
      tester,
    ) async {
      await pump(tester);

      // The normal shape when copying lines from notes: no trailing newline.
      final names = List.generate(8, (i) => 'Goal ${i + 1}');
      await tester.enterText(find.byType(TextField).first, names.join('\n'));
      await tester.pumpAndSettle();

      // No extra keystroke needed — the paste alone yields all 8.
      expect(notifier.goals, hasLength(8));
      expect(notifier.goals.map((g) => g.name).toSet(), names.toSet());
      // And the field is empty (nothing stranded).
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '',
      );
      // The confirmation reports the honest count.
      expect(find.text('Added 8 goals'), findsOneWidget);
    });

    testWidgets('pasting a slate WITH a trailing newline creates all 8', (
      tester,
    ) async {
      await pump(tester);
      final names = List.generate(8, (i) => 'Goal ${i + 1}');
      await tester.enterText(
        find.byType(TextField).first,
        '${names.join('\n')}\n',
      );
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

    testWidgets('rapid entry faster than saves drops nothing', (tester) async {
      // Slow saves: each Enter lands while the prior save is still in flight —
      // the exact condition that previously dropped goals via the busy guard.
      repo = _InMemoryGoalRepository(
        saveDelay: const Duration(milliseconds: 50),
      );
      notifier = GoalsNotifier(repository: repo);
      await notifier.loadGoals();
      await pump(tester);

      final field = find.byType(TextField).first;
      // Three goals entered ~5ms apart while each save takes 50ms.
      await tester.enterText(field, 'Alpha\n');
      await tester.pump(const Duration(milliseconds: 5));
      await tester.enterText(field, 'Beta\n');
      await tester.pump(const Duration(milliseconds: 5));
      await tester.enterText(field, 'Gamma\n');
      await tester.pumpAndSettle();

      expect(notifier.goals.map((g) => g.name).toSet(), {
        'Alpha',
        'Beta',
        'Gamma',
      });
    });

    testWidgets(
      'a failed save recovers the name and does not wedge the worker',
      (tester) async {
        await pump(tester);
        final field = find.byType(TextField).first;

        // First save fails: the goal must NOT vanish silently.
        repo.failNextSaves = 1;
        await tester.enterText(field, 'Meditate\n');
        await tester.pumpAndSettle();

        expect(notifier.goals, isEmpty); // nothing persisted
        // The unsaved name is restored to the field so the user can retry.
        expect(
          tester.widget<TextField>(field).controller!.text,
          contains('Meditate'),
        );

        // Worker is not wedged: retry (saves now succeed) actually persists,
        // and a further goal also lands — proving _draining was reset.
        await tester.enterText(field, 'Meditate\n');
        await tester.pumpAndSettle();
        await tester.enterText(field, 'Run\n');
        await tester.pumpAndSettle();

        expect(notifier.goals.map((g) => g.name).toSet(), {'Meditate', 'Run'});
      },
    );
  });
}
