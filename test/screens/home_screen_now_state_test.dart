// Unit tests for resolveNowState() and HomeScreen time-anchored widget tests.
// Phase 17 Plan 01 — NOW-01, NOW-02.
//
// Task 1 (Wave 0): Written before production symbols exist (RED state).
// Tests are expected to fail to compile until Task 2 lands NowState, PreStart,
// Active, Overdue, DayComplete, and resolveNowState in home_screen.dart.

import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/theme_notifier.dart';
import 'package:canopy/screens/home/home_screen.dart';
import 'package:canopy/screens/home/widgets/active_chunk_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// ─── Fakes (copied verbatim from active_chunk_card_test.dart) ────────────────

class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}

  String? lastCompletedId;
  String? lastSkippedId;

  @override
  Future<void> markComplete(String chunkId) async {
    lastCompletedId = chunkId;
  }

  @override
  Future<void> markSkipped(String chunkId) async {
    lastSkippedId = chunkId;
  }
}

class _FakeGoalsNotifier extends GoalsNotifier {
  @override
  Future<void> loadGoals() async {}
}

class _FakeThemeNotifier extends ThemeNotifier {
  @override
  Future<void> init() async {}

  @override
  bool get isPreCheckin => false;
}

/// ScheduleNotifier fake that exposes a pre-built schedule for HomeScreen tests.
class _FakeScheduleNotifierWithSchedule extends _FakeScheduleNotifier {
  _FakeScheduleNotifierWithSchedule(this._schedule);
  final DailySchedule _schedule;

  @override
  DailySchedule? get todaySchedule => _schedule;

  @override
  bool get hasScheduleToday => true;

  @override
  int? get moodIndex => _schedule.moodIndex;
}

// ─── Chunk factory ────────────────────────────────────────────────────────────

/// Creates a work chunk with injectable time/resolution parameters.
/// Uses [syntheticStartMinutes] for clock-window anchoring.
/// [durationMinutes] defaults to 25 min (a standard Pomodoro).
ScheduledChunk _workChunk({
  String id = 'chunk-1',
  int? syntheticStartMinutes,
  int durationMinutes = 25,
  bool isCompleted = false,
  bool isSkipped = false,
}) {
  final c = ScheduledChunk(
    id: id,
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'goal-1',
    durationMinutes: durationMinutes,
    rationale: 'Deep work',
    syntheticStartMinutes: syntheticStartMinutes,
  );
  if (isCompleted) c.isCompleted = true;
  if (isSkipped) c.isSkipped = true;
  return c;
}

// ─── Pump helper ─────────────────────────────────────────────────────────────

/// Pumps HomeScreen with the necessary provider tree.
/// Accepts an injectable [now] function forwarded to HomeScreen(now:)
/// so widget tests can simulate specific wall-clock times without sleeping.
Future<void> _pumpHomeScreen(
  WidgetTester tester, {
  required ScheduleNotifier scheduleNotifier,
  required DateTime Function() now,
}) async {
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ThemeNotifier.moodSeeds[3]!,
    ),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleNotifier>.value(
          value: scheduleNotifier,
        ),
        ChangeNotifierProvider<GoalsNotifier>.value(
          value: _FakeGoalsNotifier(),
        ),
        ChangeNotifierProvider<ThemeNotifier>.value(
          value: _FakeThemeNotifier(),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        home: HomeScreen(now: now),
      ),
    ),
  );
}

// ─── Helper: build DailySchedule for today ────────────────────────────────────

String _todayYmd() {
  final today = DateTime.now();
  return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  // ── Pure unit tests: resolveNowState (no widget pump) ────────────────────

  group('resolveNowState unit tests (NOW-01/NOW-02)', () {
    test('pre-start: now before first chunk window (6am, chunk starts 8am)',
        () {
      final chunks = [
        _workChunk(syntheticStartMinutes: 480, durationMinutes: 60),
      ]; // 8:00–9:00
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 6, 0), // 6:00 AM
      );
      expect(state, isA<PreStart>());
      expect((state as PreStart).firstChunk.displayStartMinutes, 480);
    });

    test('active: now within chunk window (9am, chunk 8:30–9:30)', () {
      final chunks = [
        _workChunk(syntheticStartMinutes: 510, durationMinutes: 60),
      ]; // 8:30–9:30
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 9, 0), // 9:00 AM
      );
      expect(state, isA<Active>());
      expect((state as Active).current.displayStartMinutes, 510);
    });

    test(
        'overdue (between-windows): c1 8:30–9:30, c2 10:30–11:30, now 10:00',
        () {
      final chunks = [
        _workChunk(id: 'c1', syntheticStartMinutes: 510, durationMinutes: 60),
        _workChunk(id: 'c2', syntheticStartMinutes: 630, durationMinutes: 60),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 10, 0), // 10:00 AM
      );
      expect(state, isA<Overdue>());
      final s = state as Overdue;
      expect(s.overdue.id, 'c1');
      expect(s.next?.id, 'c2');
    });

    test('day-complete (time past last window): chunk 8am–9am, now 6pm', () {
      final chunks = [
        _workChunk(syntheticStartMinutes: 480, durationMinutes: 60),
      ]; // 8:00–9:00
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 18, 0), // 6:00 PM
      );
      expect(state, isA<DayComplete>());
    });

    test(
        'day-complete (all resolved within active window): both completed/skipped',
        () {
      final chunks = [
        _workChunk(
          id: 'c1',
          syntheticStartMinutes: 510,
          durationMinutes: 60,
          isCompleted: true,
        ),
        _workChunk(
          id: 'c2',
          syntheticStartMinutes: 570,
          durationMinutes: 60,
          isSkipped: true,
        ),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 9, 0), // 9:00 AM — inside c1 window
      );
      expect(state, isA<DayComplete>());
    });

    test(
        'active advances past resolved chunk: c1 completed, c2 unresolved, '
        'both windows started → Active(c2)',
        () {
      // c1: 8:30–9:30 (completed), c2: 9:00–10:00 (unresolved).
      // At 9:15 both windows have started; c1 is resolved so c2 becomes active.
      final chunks = [
        _workChunk(
          id: 'c1',
          syntheticStartMinutes: 510, // 8:30 AM
          durationMinutes: 60,
          isCompleted: true,
        ),
        _workChunk(
          id: 'c2',
          syntheticStartMinutes: 540, // 9:00 AM — window opened before now
          durationMinutes: 60,
        ),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 9, 15), // 9:15 AM — both windows open
      );
      expect(state, isA<Active>());
      expect((state as Active).current.id, 'c2');
    });

    test(
        'gap (WR-01 regression): c1 resolved 9:00–9:25, c2 starts 10:00, '
        'now=9:30 → DayComplete (not Active(c2))',
        () {
      // Regression test for WR-01: before the fix, the advance-loop would
      // promote c2 into Active even though its window hasn't opened yet.
      final chunks = [
        _workChunk(
          id: 'c1',
          syntheticStartMinutes: 540, // 9:00 AM
          durationMinutes: 25,
          isCompleted: true,
        ),
        _workChunk(
          id: 'c2',
          syntheticStartMinutes: 600, // 10:00 AM — not yet open
          durationMinutes: 25,
        ),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 9, 30), // 9:30 AM — gap
      );
      // Must NOT be Active(c2): c2's window opens at 10:00, not now.
      expect(
        state,
        isNot(isA<Active>()),
        reason: 'WR-01: future chunk must not be promoted to Active before '
            'its window opens',
      );
      expect(
        state,
        isA<DayComplete>(),
        reason: 'WR-01: gap after resolved chunk → DayComplete (honest state)',
      );
    });

    test(
        'degenerate all-null windows: all displayStartMinutes null → DayComplete (documented departure)',
        () {
      final chunks = [
        _workChunk(id: 'c1'), // no syntheticStartMinutes → displayStartMinutes null
        _workChunk(id: 'c2'),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 9, 0),
      );
      // Documented departure from UI-SPEC §State Boundary Handling:
      // allWork.isEmpty (after null filter) → DayComplete, not "first unresolved".
      expect(state, isA<DayComplete>());
    });
  });

  // ── Widget tests: HomeScreen time-anchored Now (NOW-01/NOW-02) ───────────

  group('HomeScreen time-anchored Now (NOW-01/NOW-02)', () {
    testWidgets('pre-start: 6am before 8am chunk → shows "Your day starts at"',
        (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(syntheticStartMinutes: 480, durationMinutes: 60),
          ],
        ),
      );
      await _pumpHomeScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 6, 0), // 6:00 AM
      );
      expect(
        find.textContaining('Your day starts at'),
        findsOneWidget,
        reason: 'NOW-02: pre-start heading must appear before first chunk',
      );
      expect(
        find.byType(ActiveChunkCard),
        findsNothing,
        reason: 'NOW-02: no ActiveChunkCard in pre-start state',
      );
    });

    testWidgets('active: 9am with chunk 8:30–9:30 → shows ActiveChunkCard',
        (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(syntheticStartMinutes: 510, durationMinutes: 60),
          ],
        ),
      );
      await _pumpHomeScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 9, 0), // 9:00 AM
      );
      expect(
        find.byType(ActiveChunkCard),
        findsOneWidget,
        reason: 'NOW-01: ActiveChunkCard must appear for active chunk',
      );
      expect(
        find.textContaining('Your day starts at'),
        findsNothing,
        reason: 'NOW-01: no pre-start heading when chunk is active',
      );
      expect(
        find.text("That's a wrap"),
        findsNothing,
        reason: 'NOW-01: no day-complete heading when chunk is active',
      );
    });

    testWidgets(
        'between-chunks (overdue): 10am, c1 8:30–9:30, c2 10:30–11:30 → ActiveChunkCard (c1) + Next (c2)',
        (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'c1',
              syntheticStartMinutes: 510,
              durationMinutes: 60,
            ),
            _workChunk(
              id: 'c2',
              syntheticStartMinutes: 630,
              durationMinutes: 60,
            ),
          ],
        ),
      );
      await _pumpHomeScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 10, 0), // 10:00 AM
      );
      expect(
        find.byType(ActiveChunkCard),
        findsOneWidget,
        reason: 'NOW-01: overdue chunk shown as Now (ActiveChunkCard)',
      );
      // WR-02: pin the identity of the "Now" chunk. The ActiveChunkCard must
      // show c1 (overdue, window 8:30–9:30), NOT c2 (upcoming, 10:30–11:30).
      // c1's time range "8:30 AM" must appear inside the card; if logic were
      // reversed and c2 were promoted, "10:30 AM" would appear instead.
      expect(
        find.descendant(
          of: find.byType(ActiveChunkCard),
          matching: find.textContaining('8:30 AM'),
        ),
        findsOneWidget,
        reason: 'WR-02: ActiveChunkCard must display c1 (8:30 AM start), '
            'not c2 (10:30 AM start)',
      );
      expect(
        find.text('Next'),
        findsOneWidget,
        reason: 'NOW-01: Next section shows upcoming chunk',
      );
    });

    testWidgets('day-complete (6pm, all windows passed) → shows "That\'s a wrap"',
        (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(syntheticStartMinutes: 480, durationMinutes: 60),
          ], // 8:00–9:00
        ),
      );
      await _pumpHomeScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 18, 0), // 6:00 PM
      );
      expect(
        find.text("That's a wrap"),
        findsOneWidget,
        reason: 'NOW-02: day-complete heading at 6pm',
      );
      expect(
        find.byType(ActiveChunkCard),
        findsNothing,
        reason: 'NOW-02: no ActiveChunkCard in day-complete state',
      );
    });

    testWidgets(
        'all-resolved → shows "That\'s a wrap" regardless of time',
        (tester) async {
      final c1 = _workChunk(
        id: 'c1',
        syntheticStartMinutes: 510,
        durationMinutes: 60,
        isCompleted: true,
      );
      final c2 = _workChunk(
        id: 'c2',
        syntheticStartMinutes: 570,
        durationMinutes: 60,
        isSkipped: true,
      );
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [c1, c2],
        ),
      );
      await _pumpHomeScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 9, 0), // mid-day, but all resolved
      );
      expect(
        find.text("That's a wrap"),
        findsOneWidget,
        reason: 'NOW-02: day-complete when all chunks resolved',
      );
      expect(
        find.byType(ActiveChunkCard),
        findsNothing,
        reason: 'NOW-02: no ActiveChunkCard when all resolved',
      );
    });

    testWidgets(
        'timer/lifecycle: 1-min tick transitions pre-start → active',
        (tester) async {
      // Start at 7:59 — just before the 8:00 chunk window (480 min).
      DateTime injectedNow = DateTime(2026, 6, 13, 7, 59);
      // WR-03: count now() calls from the very first pump so the _nowFn
      // installed in _HomeScreenState is the counting lambda (late final
      // means it is assigned only once in initState and never replaced via
      // didUpdateWidget — so the counter must be embedded from the start).
      int nowCallCount = 0;
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(syntheticStartMinutes: 480, durationMinutes: 60),
          ],
        ),
      );
      await _pumpHomeScreen(
        tester,
        scheduleNotifier: sn,
        now: () {
          nowCallCount = nowCallCount + 1;
          return injectedNow;
        },
      );

      // At 7:59 → pre-start
      expect(
        find.textContaining('Your day starts at'),
        findsOneWidget,
        reason: 'Should be in pre-start state at 7:59 AM',
      );

      // Advance injected clock to 8:01 (inside the window) and let the
      // 1-minute timer fire.
      injectedNow = DateTime(2026, 6, 13, 8, 1);
      nowCallCount = 0;
      await tester.pump(const Duration(minutes: 1));

      // After timer tick → active
      expect(
        find.byType(ActiveChunkCard),
        findsOneWidget,
        reason:
            'Timer tick at 8:01 must transition from pre-start to active (NOW-01)',
      );

      // Background (paused) then foreground (resumed) must not throw.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // ── WR-03: no-double-timer invariant ────────────────────────────────
      // Cycle paused→resumed a SECOND time to simulate two consecutive resumes.
      // If _startNowTimer were not idempotent (i.e., appended a second
      // Timer.periodic without cancelling the first), we'd have two active
      // timers after this second resume.
      //
      // Detection: count now() calls across exactly one 1-minute pump().
      // One timer = one setState = one resolveNowState call = one now() call.
      // Two timers = two setState calls = two now() calls per tick.
      //
      // nowCallCount is captured in the original _nowFn closure (late final
      // _nowFn is set once in initState, so the counter is always live).
      injectedNow = DateTime(2026, 6, 13, 8, 30); // stable inside active window
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      nowCallCount = 0; // only count calls from the next timer tick

      // Advance exactly one timer period.
      await tester.pump(const Duration(minutes: 1));

      // If _startNowTimer is idempotent, exactly one timer fired → one
      // setState → one resolveNowState call → nowCallCount == 1.
      // If a double-timer leaked, nowCallCount would be 2 (or more).
      expect(
        nowCallCount,
        1,
        reason: 'WR-03: _startNowTimer must be idempotent — exactly one timer '
            'after two paused→resumed cycles, so now() is called once per tick',
      );
      // Sanity: the Now zone shows one (not duplicated) ActiveChunkCard.
      expect(
        find.byType(ActiveChunkCard),
        findsOneWidget,
        reason: 'WR-03: single rebuild per tick — no duplicate widget',
      );
    });
  });
}
