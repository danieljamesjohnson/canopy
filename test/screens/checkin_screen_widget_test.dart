// Widget tests for the _CheckinScreenState mood → acknowledgment flow.
//
// The intermediate "light or full day" decision screen was removed — check-in
// now goes straight from mood selection + "Let's go" to the acknowledgment
// body, committing to the full plan (lighterDay:false).
// Mirrors test/screens/cold_launch_morning_loop_test.dart structure: fake
// ScheduleNotifier, MultiProvider pump, tap+pump sequence.

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/data/repositories/in_memory_app_settings_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/theme_notifier.dart';
import 'package:canopy/screens/schedule/checkin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// In-memory GoalRepository — no Hive. Empty store (test uses no real goals).
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

// ---------------------------------------------------------------------------
// In-memory CommitmentBlockRepository — returns empty lists; no Hive.
// ---------------------------------------------------------------------------
class _InMemoryCommitmentBlockRepository implements CommitmentBlockRepository {
  @override
  Future<List<CommitmentBlock>> getAll() async => [];

  @override
  Future<CommitmentBlock?> getById(String id) async => null;

  @override
  Future<void> save(CommitmentBlock block) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async => [];
}

// ---------------------------------------------------------------------------
// _FakeScheduleNotifier — records call count and last lighterDay value.
// Populates a minimal DailySchedule so _buildAcknowledgmentBody doesn't crash.
// ---------------------------------------------------------------------------
class _FakeScheduleNotifier extends ScheduleNotifier {
  int generateTodayCallCount = 0;
  bool? lastLighterDay;

  @override
  Future<void> init() async {
    // No Hive I/O — start clean.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<void> generateToday({
    required int moodIndex,
    required List<Goal> goals,
    required List<CommitmentBlock> blocks,
    bool lighterDay = true,
    int? startFloorMinutes,
  }) async {
    generateTodayCallCount++;
    lastLighterDay = lighterDay;
    // Minimal schedule so todaySchedule is non-null for acknowledgment body.
    _schedule = DailySchedule(
      dateYmd: '2026-06-13',
      moodIndex: moodIndex,
      chunks: [],
    );
    notifyListeners();
  }

  DailySchedule? _schedule;

  @override
  DailySchedule? get todaySchedule => _schedule;

  @override
  bool get hasScheduleToday => _schedule != null;
}

// ---------------------------------------------------------------------------
// _pumpCheckin — builds the full provider tree and pumps CheckinScreen.
// Returns the fake ScheduleNotifier for test assertions.
// ---------------------------------------------------------------------------
Future<_FakeScheduleNotifier> _pumpCheckin(WidgetTester tester) async {
  final scheduleNotifier = _FakeScheduleNotifier();
  await scheduleNotifier.init();

  final goalsNotifier = GoalsNotifier(repository: _InMemoryGoalRepository());

  final commitmentsNotifier = CommitmentsNotifier(
    repository: _InMemoryCommitmentBlockRepository(),
  );

  final themeNotifier = ThemeNotifier(
    repository: InMemoryAppSettingsRepository(),
    timeModulationEnabled: false,
  );
  await themeNotifier.init();

  addTearDown(() {
    scheduleNotifier.dispose();
    themeNotifier.dispose();
  });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GoalsNotifier>.value(value: goalsNotifier),
        ChangeNotifierProvider<CommitmentsNotifier>.value(
          value: commitmentsNotifier,
        ),
        ChangeNotifierProvider<ScheduleNotifier>.value(value: scheduleNotifier),
        ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),
      ],
      child: const MaterialApp(home: CheckinScreen()),
    ),
  );
  await tester.pump();
  return scheduleNotifier;
}

// ---------------------------------------------------------------------------
// Helper: tap mood and "Let's go", then wait for generation + AnimatedSwitcher.
// Advances from mood-selected → generating → acknowledgment body.
// ---------------------------------------------------------------------------
Future<void> _tapMoodAndGenerate(WidgetTester tester) async {
  // Tap mood 3 (⛅) — stable test fixture per UI-SPEC §Widget Test Mood-Pinning.
  await tester.tap(find.text('⛅'));
  await tester.pump(); // setState: _selectedMood = 3, shows "Let's go"

  await tester.tap(find.text("Let's go"));
  // WR-03: Use pump() + pump(500ms) instead of two bare pump() calls so that
  // any number of microtask turns in _generate() (and its fake) are drained
  // before the AnimatedSwitcher 300ms transition completes.
  await tester.pump(); // kick off the async _generate()
  await tester.pump(const Duration(milliseconds: 500)); // drain async + animate
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CheckinScreen mood → acknowledgment flow', () {
    testWidgets(
      'Test 1: "Let\'s go" goes straight to the acknowledgment (no pace prompt)',
      (tester) async {
        final notifier = await _pumpCheckin(tester);

        await _tapMoodAndGenerate(tester);

        // The intermediate "light or full day" decision screen was removed —
        // check-in jumps straight to the acknowledgment body.
        expect(
          find.text('Tap or swipe up to begin'),
          findsOneWidget,
          reason: 'Acknowledgment must appear directly after "Let\'s go"',
        );
        // None of the old decision-screen affordances may be present.
        expect(find.text('Ready to start?'), findsNothing);
        expect(find.text('Full day'), findsNothing);
        expect(find.text('Lighter day'), findsNothing);

        // Exactly one generation, using the full plan (lighterDay:false).
        expect(
          notifier.generateTodayCallCount,
          1,
          reason: 'Check-in must generate exactly once (no second pace call)',
        );
        expect(
          notifier.lastLighterDay,
          isFalse,
          reason: 'Removing the prompt commits to the full plan',
        );
      },
    );
  });
}
