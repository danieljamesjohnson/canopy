// Widget tests for the redesigned onboarding — "let the app get to know you"
// in four beats: goals → energy → restoratives → job.
//
// Verifies the full walk-through: a goal entered on beat 1 flows to the energy
// beat, an energy choice persists, a restorative is captured, and finishing
// marks onboarding complete (with the optional job saved).

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/energy_valence.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/restorative_item.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/data/repositories/restorative_item_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:canopy/providers/settings_notifier.dart';
import 'package:canopy/screens/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/viewport.dart';

// --- In-memory repositories -------------------------------------------------

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

class _InMemoryRestorativeRepository implements RestorativeItemRepository {
  final Map<String, RestorativeItem> _store = {};
  @override
  Future<List<RestorativeItem>> getAll() async {
    final all = _store.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return all;
  }

  @override
  Future<RestorativeItem?> getById(String id) async => _store[id];
  @override
  Future<void> save(RestorativeItem item) async => _store[item.id] = item;
  @override
  Future<void> delete(String id) async => _store.remove(id);
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

/// Settings double — records completion, no Hive, notifications off so the
/// finish path doesn't reach the platform NotificationService.
class _FakeSettingsNotifier extends SettingsNotifier {
  bool completed = false;

  /// When true, the NEXT setOnboardingComplete throws (then clears), to
  /// simulate a Hive write failure on the final onboarding step.
  bool failNextComplete = false;

  @override
  bool get onboardingComplete => completed;
  @override
  bool get morningNotificationEnabled => false;
  @override
  Future<void> setOnboardingComplete(bool value) async {
    if (failNextComplete) {
      failNextComplete = false;
      throw StateError('simulated write failure');
    }
    completed = value;
    notifyListeners();
  }
}

void main() {
  late _InMemoryGoalRepository goalRepo;
  late _InMemoryRestorativeRepository restRepo;
  late _InMemoryCommitmentRepository commitRepo;
  late GoalsNotifier goals;
  late RestorativesNotifier restoratives;
  late CommitmentsNotifier commitments;
  late _FakeSettingsNotifier settings;

  setUp(() {
    goalRepo = _InMemoryGoalRepository();
    restRepo = _InMemoryRestorativeRepository();
    commitRepo = _InMemoryCommitmentRepository();
    goals = GoalsNotifier(repository: goalRepo);
    restoratives = RestorativesNotifier(repository: restRepo);
    commitments = CommitmentsNotifier(repository: commitRepo);
    settings = _FakeSettingsNotifier();
  });

  Future<void> pump(WidgetTester tester) async {
    setViewport(tester, const Size(900, 1400));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GoalsNotifier>.value(value: goals),
          ChangeNotifierProvider<RestorativesNotifier>.value(value: restoratives),
          ChangeNotifierProvider<CommitmentsNotifier>.value(value: commitments),
          ChangeNotifierProvider<SettingsNotifier>.value(value: settings),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder quickAddField() => find.byType(TextField).first;

  testWidgets('beat 1 requires a goal, then reveals it', (tester) async {
    await pump(tester);

    expect(find.text('What do you want to make time for?'), findsOneWidget);
    // Continue is disabled until at least one goal exists.
    final continueBtn = find.widgetWithText(ElevatedButton, 'Continue');
    expect(tester.widget<ElevatedButton>(continueBtn).onPressed, isNull);

    await tester.enterText(quickAddField(), 'Exercise\n');
    await tester.pumpAndSettle();

    expect(goals.goals.map((g) => g.name), contains('Exercise'));
    expect(tester.widget<ElevatedButton>(continueBtn).onPressed, isNotNull);
  });

  testWidgets('full walk-through: goals → energy → restore → finish', (
    tester,
  ) async {
    await pump(tester);

    // Beat 1 — goals.
    await tester.enterText(quickAddField(), 'Exercise\n');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    // Beat 2 — energy. The goal is shown and can be marked as draining.
    expect(find.text('Which of these lift you up?'), findsOneWidget);
    expect(find.text('Exercise'), findsOneWidget);
    await tester.tap(find.text('Drains'));
    await tester.pumpAndSettle();
    expect(goals.goals.single.energyValence, EnergyValence.costs);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    // Beat 3 — restoratives.
    expect(find.text('What helps you recharge?'), findsOneWidget);
    await tester.enterText(quickAddField(), 'Listen to music\n');
    await tester.pumpAndSettle();
    expect(restoratives.items.map((i) => i.name), contains('Listen to music'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    // Beat 4 — job. Fill it, finish.
    expect(find.text('Do you have a job or fixed commitment?'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Work',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add & finish'));
    await tester.pumpAndSettle();

    // Onboarding is marked complete, and the job was saved.
    expect(settings.completed, isTrue);
    expect(commitments.blocks.map((b) => b.name), contains('Work'));
  });

  testWidgets(
    'tapping Continue without pressing Enter still saves the typed goal',
    (tester) async {
      await pump(tester);

      // Establish one saved goal so Continue is enabled, then type a SECOND
      // goal but do NOT press Enter before continuing.
      await tester.enterText(quickAddField(), 'Exercise\n');
      await tester.pumpAndSettle();
      await tester.enterText(quickAddField(), 'Meditation');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Both goals persisted — the in-progress one was flushed, not dropped.
      expect(
        goals.goals.map((g) => g.name).toSet(),
        {'Exercise', 'Meditation'},
      );
    },
  );

  testWidgets(
    'tapping Continue without Enter still saves the typed restorative',
    (tester) async {
      await pump(tester);

      // Advance to the restoratives beat.
      await tester.enterText(quickAddField(), 'Read\n');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Type a restorative, then leave via Skip WITHOUT pressing Enter.
      await tester.enterText(quickAddField(), 'Hot bath');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Skip'));
      await tester.pumpAndSettle();

      expect(restoratives.items.map((i) => i.name), contains('Hot bath'));
    },
  );

  testWidgets(
    'a named job with no days cannot be saved, but can be skipped',
    (tester) async {
      await pump(tester);

      // Advance to the Job beat.
      await tester.enterText(quickAddField(), 'Read\n');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Skip'));
      await tester.pumpAndSettle();

      // Name a job, then clear every day chip → the job is not schedulable.
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Work');
      await tester.pumpAndSettle();
      for (final label in const ['M', 'T', 'W', 'T', 'F']) {
        // Only the selected weekday chips are present; tapping toggles them off.
        final chip = find.widgetWithText(FilterChip, label);
        if (chip.evaluate().isNotEmpty) {
          // Tap each matching chip that is currently selected.
          for (final e in chip.evaluate()) {
            final w = e.widget as FilterChip;
            if (w.selected) {
              await tester.tap(find.byWidget(w));
              await tester.pumpAndSettle();
            }
          }
        }
      }

      // Finish is blocked and a warning is shown.
      final finish = find.widgetWithText(ElevatedButton, 'Add & finish');
      expect(tester.widget<ElevatedButton>(finish).onPressed, isNull);
      expect(
        find.text('Pick at least one day for this commitment.'),
        findsOneWidget,
      );

      // The escape hatch finishes onboarding without saving a broken job.
      await tester.tap(find.text('Skip the job and finish'));
      await tester.pumpAndSettle();
      expect(settings.completed, isTrue);
      expect(commitments.blocks, isEmpty);
    },
  );

  testWidgets(
    'a failure on the final step is recoverable, not a dead end',
    (tester) async {
      await pump(tester);

      // Walk to the job beat with no commitment.
      await tester.enterText(quickAddField(), 'Read\n');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Skip'));
      await tester.pumpAndSettle();

      // First finish tap fails the write.
      settings.failNextComplete = true;
      final finish = find.widgetWithText(ElevatedButton, "Finish — I'm ready");
      await tester.tap(finish);
      await tester.pumpAndSettle();

      // Not stuck: still on onboarding, error surfaced, button re-enabled.
      expect(settings.completed, isFalse);
      expect(
        find.text("Couldn't finish setup. Please try again."),
        findsOneWidget,
      );
      expect(tester.widget<ElevatedButton>(finish).onPressed, isNotNull);

      // Let the error SnackBar auto-dismiss so it isn't covering the button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Retry succeeds.
      await tester.tap(finish);
      await tester.pumpAndSettle();
      expect(settings.completed, isTrue);
    },
  );

  testWidgets('job beat can finish with no commitment', (tester) async {
    await pump(tester);

    // Beat 1.
    await tester.enterText(quickAddField(), 'Read\n');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();
    // Beat 2 → 3 → 4 without touching anything.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Skip'));
    await tester.pumpAndSettle();

    // Beat 4: no name entered → the CTA offers a clean finish.
    await tester.tap(find.widgetWithText(ElevatedButton, "Finish — I'm ready"));
    await tester.pumpAndSettle();

    expect(settings.completed, isTrue);
    expect(commitments.blocks, isEmpty);
  });
}
