// Widget tests for _CheckinScreenState B→C→D→E state machine (CHECKIN-02).
//
// Covers the lighter-day post-commit decision screen and the Go-back D→B reset.
// Mirrors test/screens/cold_launch_morning_loop_test.dart structure: fake
// ScheduleNotifier, MultiProvider pump, tap+pump sequence.
//
// State machine under test:
//   B: mood selected, "Let's go" visible
//   C: generating (spinner)
//   D: _generationDone=true → decision screen with "Ready to start?"
//   E: _scheduleGenerated=true → acknowledgment body
//
// Test coverage (CHECKIN-02):
//   1. Decision screen appears after generation completes
//   2. "Lighter day" → second generateToday call with lighterDay:true → ack body
//   3. "Full day" → no second call, lighterDay stays false → ack body
//   4. "Go back" → resets to State B ("Let's go" visible, decision gone)

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
class _InMemoryCommitmentBlockRepository
    implements CommitmentBlockRepository {
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

  final goalsNotifier = GoalsNotifier(
    repository: _InMemoryGoalRepository(),
  );

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
        ChangeNotifierProvider<ScheduleNotifier>.value(
          value: scheduleNotifier,
        ),
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
// Advances from State B → State C → State D (decision screen).
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

  group('CheckinScreen state machine (CHECKIN-02)', () {
    testWidgets(
      'Test 1: decision screen appears after "Let\'s go" generation completes',
      (tester) async {
        await _pumpCheckin(tester);

        await _tapMoodAndGenerate(tester);

        // State D: decision screen must show all four expected elements.
        expect(
          find.text('Ready to start?'),
          findsOneWidget,
          reason: 'Decision screen heading must be visible',
        );
        expect(
          find.text('Full day'),
          findsOneWidget,
          reason: 'Full day card must be visible',
        );
        expect(
          find.text('Lighter day'),
          findsOneWidget,
          reason: 'Lighter day card must be visible',
        );
        expect(
          find.text('Go back'),
          findsOneWidget,
          reason: 'Go back affordance must be visible',
        );
      },
    );

    testWidgets(
      'Test 2: tapping "Lighter day" regenerates with lighterDay:true and advances to ack',
      (tester) async {
        final notifier = await _pumpCheckin(tester);

        await _tapMoodAndGenerate(tester);

        // State D: tap "Lighter day"
        await tester.tap(find.text('Lighter day'));
        await tester.pump(); // _commitAndProceed async
        await tester.pump(); // drains → _scheduleGenerated = true
        await tester.pumpAndSettle(); // AnimatedSwitcher transition

        // generateToday should have been called twice (once in _generate,
        // once in _commitAndProceed with lighterDay:true).
        expect(
          notifier.generateTodayCallCount,
          2,
          reason: '"Lighter day" must trigger a second generateToday call',
        );
        expect(
          notifier.lastLighterDay,
          isTrue,
          reason: 'Second generateToday call must use lighterDay:true',
        );

        // State E: acknowledgment body must be visible.
        expect(
          find.text('Swipe up to begin'),
          findsOneWidget,
          reason: 'Acknowledgment body must appear after "Lighter day" tap',
        );
      },
    );

    testWidgets(
      'Test 3: tapping "Full day" does NOT call generateToday again (keeps lighterDay:false)',
      (tester) async {
        final notifier = await _pumpCheckin(tester);

        await _tapMoodAndGenerate(tester);

        // Verify we're on the decision screen first.
        expect(find.text('Ready to start?'), findsOneWidget);

        // State D: tap "Full day"
        await tester.tap(find.text('Full day'));
        await tester.pump(); // _commitAndProceed (no async generateToday)
        await tester.pump(); // setState → _scheduleGenerated = true
        await tester.pumpAndSettle(); // AnimatedSwitcher transition

        // generateToday must NOT be called again (only 1 total — from _generate).
        expect(
          notifier.generateTodayCallCount,
          1,
          reason:
              '"Full day" must NOT trigger a second generateToday call — '
              'reuses the existing lighterDay:false schedule',
        );
        expect(
          notifier.lastLighterDay,
          isFalse,
          reason:
              'The only generateToday call must have used lighterDay:false',
        );

        // State E: acknowledgment body must be visible.
        expect(
          find.text('Swipe up to begin'),
          findsOneWidget,
          reason: 'Acknowledgment body must appear after "Full day" tap',
        );
      },
    );

    testWidgets(
      'Test 4: tapping "Go back" resets to State B — "Let\'s go" visible, decision gone',
      (tester) async {
        await _pumpCheckin(tester);

        await _tapMoodAndGenerate(tester);

        // Verify we're on the decision screen.
        expect(find.text('Ready to start?'), findsOneWidget);

        // Tap "Go back" — must reset _generationDone = false → State B.
        await tester.tap(find.text('Go back'));
        await tester.pumpAndSettle(); // AnimatedSwitcher transition

        // State B: "Let's go" must be visible (mood is still selected).
        expect(
          find.text("Let's go"),
          findsOneWidget,
          reason: 'After "Go back", the "Let\'s go" button must be visible again',
        );
        // Decision screen must be gone.
        expect(
          find.text('Ready to start?'),
          findsNothing,
          reason: '"Go back" must dismiss the decision screen',
        );
      },
    );
  });
}
