// Widget tests for onboarding Screen 4 ("What gives you energy?") — Phase 19 Plan 01.
//
// Covers ONBOARD-01:
//   1. Screen 4 headline "What gives you energy?" renders.
//   2. Marking a goal "Energizing" and tapping "Let's go" persists
//      energyValence == EnergyValence.gives on that goal.
//   3. Tapping "Skip" on Screen 4 leaves goals as EnergyValence.neutral.
//
// Strategy: pump OnboardingScreen with full provider scaffolding (in-memory
// GoalRepository + fake SettingsNotifier to avoid Hive), navigate through
// Screens 1–3 to reach Screen 4, then assert Screen 4 behavior.
//
// RED: This file fails to compile / run because:
//   - EnergyValence (from energy_valence.dart) does not exist
//   - Screen 4 does not exist in onboarding_screen.dart
//   - goal.energyValence getter does not exist on Goal

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/energy_valence.dart'; // does not exist yet — RED
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/settings_notifier.dart';
import 'package:canopy/screens/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// Test doubles — no Hive I/O
// ---------------------------------------------------------------------------

class _InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};

  @override
  Future<List<Goal>> getAll() async => _store.values.toList();

  @override
  Future<Goal?> getById(String id) async => _store[id];

  @override
  Future<void> save(Goal goal) async {
    _store[goal.id] = goal;
  }

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}

class _InMemoryCommitmentBlockRepository implements CommitmentBlockRepository {
  final List<CommitmentBlock> _store = [];

  @override
  Future<List<CommitmentBlock>> getAll() async => List.unmodifiable(_store);

  @override
  Future<CommitmentBlock?> getById(String id) async =>
      _store.where((b) => b.id == id).firstOrNull;

  @override
  Future<void> save(CommitmentBlock block) async {
    _store.removeWhere((b) => b.id == block.id);
    _store.add(block);
  }

  @override
  Future<void> delete(String id) async {
    _store.removeWhere((b) => b.id == id);
  }

  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async =>
      _store.where((b) => b.daysOfWeek.contains(day)).toList();
}

/// FakeSettingsNotifier avoids Hive I/O and records setOnboardingComplete calls.
class _FakeSettingsNotifier extends SettingsNotifier {
  bool _completed = false;

  @override
  bool get onboardingComplete => _completed;

  @override
  Future<void> setOnboardingComplete(bool value) async {
    _completed = value;
    notifyListeners();
  }

  // Stub out the Hive-dependent load path.
  @override
  Future<void> init() async {}
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

/// Pumps OnboardingScreen with in-memory providers and returns the stores
/// for inspection after test actions complete.
Future<({_InMemoryGoalRepository goalRepo, _FakeSettingsNotifier settings})>
    _pumpOnboarding(WidgetTester tester) async {
  final goalRepo = _InMemoryGoalRepository();
  final commitmentRepo = _InMemoryCommitmentBlockRepository();
  final goalsNotifier = GoalsNotifier(repository: goalRepo);
  await goalsNotifier.loadGoals();
  final commitmentsNotifier = CommitmentsNotifier(repository: commitmentRepo);
  final settings = _FakeSettingsNotifier();

  await pumpWithMood(
    tester,
    const OnboardingScreen(),
    extraProviders: [
      ChangeNotifierProvider<GoalsNotifier>.value(value: goalsNotifier),
      ChangeNotifierProvider<CommitmentsNotifier>.value(value: commitmentsNotifier),
      ChangeNotifierProvider<SettingsNotifier>.value(value: settings),
    ],
  );

  return (goalRepo: goalRepo, settings: settings);
}

/// Navigates from Screen 1 through Screen 3 to reach Screen 4.
/// Skips Screens 1–3 with minimal interaction (no goal name → skip patterns).
Future<void> _navigateToScreen4(WidgetTester tester) async {
  // Screen 1: tap "Next" without filling in a goal name (skip-equivalent).
  // Screen 1 has a "Next ->" button visible; tap it to advance.
  final nextBtn = find.text('Next');
  if (nextBtn.evaluate().isNotEmpty) {
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();
  }

  // Screen 2: tap "Skip" to skip commitment block.
  final skipS2 = find.text('Skip');
  if (skipS2.evaluate().isNotEmpty) {
    await tester.tap(skipS2.first);
    await tester.pumpAndSettle();
  }

  // Screen 3: tap "Skip" to skip morning habit.
  // In the Phase 19 implementation, Screen 3's onSkip → _nextPage() → Screen 4.
  // (Currently Screen 3's onSkip calls _completeOnboarding directly — Screen 4
  // is added in Plan 02. This test will fail RED until Screen 4 exists.)
  final skipS3 = find.text('Skip');
  if (skipS3.evaluate().isNotEmpty) {
    await tester.tap(skipS3.first);
    await tester.pumpAndSettle();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Onboarding Screen 4 — "What gives you energy?" (ONBOARD-01)', () {
    testWidgets(
      'Screen 4 headline "What gives you energy?" renders after navigating from Screen 3',
      (tester) async {
        await _pumpOnboarding(tester);
        await _navigateToScreen4(tester);

        // Screen 4 headline — does not exist yet (RED)
        expect(
          find.text('What gives you energy?'),
          findsOneWidget,
          reason:
              'Screen 4 must show the headline "What gives you energy?" — ONBOARD-01',
        );
      },
    );

    testWidgets(
      'tapping "Let\'s go" on Screen 4 after marking a goal saves '
      'energyValence == gives for that goal (ONBOARD-01)',
      (tester) async {
        final stores = await _pumpOnboarding(tester);

        // Navigate to Screen 1, enter a goal name so there's a goal to mark.
        await tester.tap(find.text('I want to spend regular time on something'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Morning Run');
        await tester.pumpAndSettle();

        // Advance past Screen 1.
        final nextBtn = find.text('Next');
        if (nextBtn.evaluate().isNotEmpty) {
          await tester.tap(nextBtn);
          await tester.pumpAndSettle();
        }

        // Skip Screen 2.
        final skipS2 = find.text('Skip');
        if (skipS2.evaluate().isNotEmpty) {
          await tester.tap(skipS2.first);
          await tester.pumpAndSettle();
        }

        // Skip Screen 3 → navigates to Screen 4 (Phase 19 implementation)
        final skipS3 = find.text('Skip');
        if (skipS3.evaluate().isNotEmpty) {
          await tester.tap(skipS3.first);
          await tester.pumpAndSettle();
        }

        // Screen 4: "What gives you energy?" headline must be visible.
        expect(
          find.text('What gives you energy?'),
          findsOneWidget,
          reason: 'Must be on Screen 4 — ONBOARD-01',
        );

        // Mark "Morning Run" as energizing (UI label TBD by implementation;
        // test will be updated once Screen 4 UI is locked in Plan 02).
        // For now, assert the goal name appears on Screen 4's list.
        expect(
          find.text('Morning Run'),
          findsOneWidget,
          reason: 'Pending goal from Screen 1 must appear on Screen 4 list',
        );

        // Tap "Let's go" to complete onboarding.
        await tester.tap(find.text("Let's go"));
        await tester.pumpAndSettle();

        // Verify onboarding completed.
        expect(
          stores.settings.onboardingComplete,
          isTrue,
          reason: 'Onboarding must complete after tapping "Let\'s go" on Screen 4',
        );

        // Verify the goal that was marked energizing has valence == gives.
        // (Assertion references EnergyValence — fails RED.)
        final savedGoals = await stores.goalRepo.getAll();
        final morningRun = savedGoals.where((g) => g.name == 'Morning Run').firstOrNull;
        expect(
          morningRun,
          isNotNull,
          reason: '"Morning Run" must be saved when completing onboarding',
        );
        expect(
          morningRun!.energyValence, // getter does not exist yet — RED
          equals(EnergyValence.gives),
          reason:
              'Goal marked energizing on Screen 4 must have '
              'energyValence == EnergyValence.gives — ONBOARD-01',
        );
      },
    );

    testWidgets(
      'tapping "Skip" on Screen 4 completes onboarding without changing valence',
      (tester) async {
        final stores = await _pumpOnboarding(tester);
        await _navigateToScreen4(tester);

        // Should be on Screen 4 now.
        expect(find.text('What gives you energy?'), findsOneWidget);

        // Tap Skip — goes straight to completion.
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(
          stores.settings.onboardingComplete,
          isTrue,
          reason: 'Onboarding must complete after skipping Screen 4',
        );

        // Goals saved (if any) should remain neutral.
        final savedGoals = await stores.goalRepo.getAll();
        for (final goal in savedGoals) {
          expect(
            goal.energyValence, // getter does not exist yet — RED
            equals(EnergyValence.neutral),
            reason:
                'Goals not explicitly marked must remain EnergyValence.neutral '
                'when Screen 4 is skipped — ONBOARD-01',
          );
        }
      },
    );
  });
}
