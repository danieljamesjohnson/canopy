// Unit tests for resolveNowState() and TodayScreen time-anchored widget tests.
// Phase 17 Plan 01 — NOW-01, NOW-02. Relocated in Phase 22 Plan 04 (UNIFY-02)
// when home_screen.dart was deleted and its now-state widget coverage
// repointed at the merged TodayScreen / LiveRowCard.
//
// The resolveNowState unit-test group below is byte-identical to the
// original home_screen_now_state_test.dart — it is the strongest existing
// asset in this phase and is not rewritten, only relocated.

import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/theme_notifier.dart';
import 'package:canopy/screens/today/now_state.dart';
import 'package:canopy/screens/today/today_screen.dart';
import 'package:canopy/screens/today/widgets/live_row_card.dart';
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

/// TodayScreen reads RestorativesNotifier for the mood-gated restoratives
/// card; no-op loadItems so the widget-pump tests never touch Hive.
class _FakeRestorativesNotifier extends RestorativesNotifier {
  @override
  Future<void> loadItems() async {}
}

/// ScheduleNotifier fake that exposes a pre-built schedule for TodayScreen tests.
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

/// Pumps TodayScreen with the necessary provider tree.
/// Accepts an injectable [now] function forwarded to TodayScreen(now:)
/// so widget tests can simulate specific wall-clock times without sleeping.
Future<void> _pumpTodayScreen(
  WidgetTester tester, {
  required ScheduleNotifier scheduleNotifier,
  required DateTime Function() now,
}) async {
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: ThemeNotifier.moodSeeds[3]!),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleNotifier>.value(value: scheduleNotifier),
        ChangeNotifierProvider<GoalsNotifier>.value(
          value: _FakeGoalsNotifier(),
        ),
        ChangeNotifierProvider<ThemeNotifier>.value(
          value: _FakeThemeNotifier(),
        ),
        ChangeNotifierProvider<RestorativesNotifier>.value(
          value: _FakeRestorativesNotifier(),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        home: TodayScreen(now: now),
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
    test(
      'pre-start: now before first chunk window (6am, chunk starts 8am)',
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
      },
    );

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
      },
    );

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
      },
    );

    test('active advances past resolved chunk: c1 completed, c2 unresolved, '
        'both windows started → Active(c2)', () {
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

    test('gap: c1 resolved 9:00–9:25, c2 starts 10:00, now=9:30 → '
        'GapBeforeNext(c2) — NOT DayComplete or Active', () {
      // CR-01 fix: the advance-loop used to return DayComplete here, which is
      // wrong because c2 is an unresolved pending chunk opening at 10:00.
      // The day is not complete; the user is in a between-windows gap.
      // WR-01 regression: c2 must NOT be promoted to Active (window unopened).
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
      // Must NOT be Active(c2): window hasn't opened yet (10:00 AM).
      expect(
        state,
        isNot(isA<Active>()),
        reason:
            'WR-01: future chunk must not be promoted to Active before '
            'its window opens',
      );
      // Must NOT be DayComplete: c2 is an unresolved future chunk — day not done.
      expect(
        state,
        isNot(isA<DayComplete>()),
        reason:
            'CR-01: gap with pending future work must NOT return DayComplete',
      );
      // Must be GapBeforeNext pointing at c2.
      expect(
        state,
        isA<GapBeforeNext>(),
        reason:
            'Gap after resolved chunk with future unresolved work must '
            'surface the upcoming chunk, not DayComplete',
      );
      expect(
        (state as GapBeforeNext).next.id,
        'c2',
        reason: 'GapBeforeNext.next must be c2 (the upcoming unresolved chunk)',
      );
    });

    test('near-gap: c1 resolved 9:00–9:25, c2 starts 9:25, now=9:10 → '
        'GapBeforeNext(c2) — day not complete when next window imminent', () {
      // Companion test: even when the gap is tiny (next window opens in 15 min),
      // the state must be GapBeforeNext, not DayComplete.
      final chunks = [
        _workChunk(
          id: 'c1',
          syntheticStartMinutes: 540, // 9:00 AM
          durationMinutes: 25,
          isCompleted: true,
        ),
        _workChunk(
          id: 'c2',
          syntheticStartMinutes: 565, // 9:25 AM — opens in 15 min from now
          durationMinutes: 25,
        ),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 9, 10), // 9:10 AM — inside gap
      );
      expect(
        state,
        isA<GapBeforeNext>(),
        reason:
            'Near-gap (15 min before c2) must be GapBeforeNext, not DayComplete',
      );
      expect(
        (state as GapBeforeNext).next.id,
        'c2',
        reason: 'GapBeforeNext.next must be c2',
      );
    });

    test('gap with all-resolved future: c1 done, c2 also done, now=9:30 → '
        'DayComplete (no unresolved future work)', () {
      // DayComplete is correct when the gap candidate chain is fully resolved.
      final chunks = [
        _workChunk(
          id: 'c1',
          syntheticStartMinutes: 540, // 9:00 AM
          durationMinutes: 25,
          isCompleted: true,
        ),
        _workChunk(
          id: 'c2',
          syntheticStartMinutes: 600, // 10:00 AM — not yet open, but also done
          durationMinutes: 25,
          isSkipped: true,
        ),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 9, 30), // 9:30 AM
      );
      expect(
        state,
        isA<DayComplete>(),
        reason: 'Gap where all future chunks are also resolved → DayComplete',
      );
    });

    test(
      'degenerate all-null windows: all displayStartMinutes null → DayComplete (documented departure)',
      () {
        final chunks = [
          _workChunk(
            id: 'c1',
          ), // no syntheticStartMinutes → displayStartMinutes null
          _workChunk(id: 'c2'),
        ];
        final state = resolveNowState(
          chunks: chunks,
          now: () => DateTime(2026, 6, 13, 9, 0),
        );
        // Documented departure from UI-SPEC §State Boundary Handling:
        // allWork.isEmpty (after null filter) → DayComplete, not "first unresolved".
        expect(state, isA<DayComplete>());
      },
    );
  });

  // ── Widget tests: TodayScreen time-anchored Now (NOW-01/NOW-02) ──────────

  group('TodayScreen time-anchored Now (NOW-01/NOW-02)', () {
    testWidgets(
      'pre-start: 6am before 8am chunk → shows "Your day starts at"',
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
        await _pumpTodayScreen(
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
          find.byType(LiveRowCard),
          findsNothing,
          reason: 'NOW-02: no LiveRowCard in pre-start state',
        );
      },
    );

    testWidgets('active: 9am with chunk 8:30–9:30 → shows LiveRowCard', (
      tester,
    ) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [_workChunk(syntheticStartMinutes: 510, durationMinutes: 60)],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 9, 0), // 9:00 AM
      );
      expect(
        find.byType(LiveRowCard),
        findsOneWidget,
        reason: 'NOW-01: LiveRowCard must appear for active chunk',
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
      'between-chunks (overdue): 10am, c1 8:30–9:30, c2 10:30–11:30 → LiveRowCard (c1) + Next (c2)',
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
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: sn,
          now: () => DateTime(2026, 6, 13, 10, 0), // 10:00 AM
        );
        expect(
          find.byType(LiveRowCard),
          findsOneWidget,
          reason: 'NOW-01: overdue chunk shown as Now (LiveRowCard)',
        );
        // WR-02: pin the identity of the "Now" chunk. The LiveRowCard must
        // show c1 (overdue, window 8:30–9:30), NOT c2 (upcoming, 10:30–11:30).
        // c1's time range "8:30 AM" must appear inside the card; if logic were
        // reversed and c2 were promoted, "10:30 AM" would appear instead.
        expect(
          find.descendant(
            of: find.byType(LiveRowCard),
            matching: find.textContaining('8:30 AM'),
          ),
          findsOneWidget,
          reason:
              'WR-02: LiveRowCard must display c1 (8:30 AM start), '
              'not c2 (10:30 AM start)',
        );
        expect(
          find.descendant(
            of: find.byType(LiveRowCard),
            matching: find.textContaining('Next ·'),
          ),
          findsOneWidget,
          reason:
              'NOW-01: the live row\'s "Next · <title> at <time>" line '
              'shows the upcoming chunk (no separate Next section since '
              'the merge — UI-SPEC\'s live row carries this inline)',
        );
      },
    );

    testWidgets(
      'day-complete (6pm, all windows passed) → shows "That\'s a wrap"',
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
        await _pumpTodayScreen(
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
          find.byType(LiveRowCard),
          findsNothing,
          reason: 'NOW-02: no LiveRowCard in day-complete state',
        );
      },
    );

    testWidgets('all-resolved → shows "That\'s a wrap" regardless of time', (
      tester,
    ) async {
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
        DailySchedule(dateYmd: _todayYmd(), moodIndex: 3, chunks: [c1, c2]),
      );
      await _pumpTodayScreen(
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
        find.byType(LiveRowCard),
        findsNothing,
        reason: 'NOW-02: no LiveRowCard when all resolved',
      );
    });

    testWidgets('gap state: c1 resolved 9:00–9:25, c2 at 10:00, now=9:30 → '
        'shows "Up next" and NOT "That\'s a wrap"', (tester) async {
      // CR-01: GapBeforeNext renders honest "Up next" copy, not day-complete.
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'c1',
              syntheticStartMinutes: 540, // 9:00 AM
              durationMinutes: 25,
              isCompleted: true,
            ),
            _workChunk(
              id: 'c2',
              syntheticStartMinutes: 600, // 10:00 AM
              durationMinutes: 25,
            ),
          ],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 9, 30), // gap
      );
      // Must show the gap heading, not the day-complete heading.
      expect(
        find.text('Up next'),
        findsOneWidget,
        reason:
            'CR-01: GapBeforeNext must render "Up next", not "That\'s a wrap"',
      );
      expect(
        find.text("That's a wrap"),
        findsNothing,
        reason: 'CR-01: "That\'s a wrap" must not appear in gap state',
      );
      // Must not show a card — this is an inline state, not an active chunk.
      expect(
        find.byType(LiveRowCard),
        findsNothing,
        reason: 'CR-01: no LiveRowCard in gap state',
      );
      // Must show the upcoming time in the body.
      expect(
        find.textContaining('10:00 AM'),
        findsOneWidget,
        reason: 'CR-01: gap body must mention the next chunk start time',
      );
    });

    testWidgets('timer/lifecycle: 1-min tick transitions pre-start → active', (
      tester,
    ) async {
      // Start at 7:59 — just before the 8:00 chunk window (480 min).
      DateTime injectedNow = DateTime(2026, 6, 13, 7, 59);
      // WR-03: count now() calls from the very first pump so the _nowFn
      // installed in TodayScreen's State is the counting lambda (late final
      // means it is assigned only once in initState and never replaced via
      // didUpdateWidget — so the counter must be embedded from the start).
      int nowCallCount = 0;
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [_workChunk(syntheticStartMinutes: 480, durationMinutes: 60)],
        ),
      );
      await _pumpTodayScreen(
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
        find.byType(LiveRowCard),
        findsOneWidget,
        reason:
            'Timer tick at 8:01 must transition from pre-start to active (NOW-01)',
      );

      // Capture the per-tick call-count baseline for THIS screen. TodayScreen
      // (unlike the old HomeScreen) reads _nowFn() from more than one call
      // site per build (the date header, resolveNowState, and the live row's
      // remaining-time calc), so a single legitimate timer tick is NOT
      // guaranteed to be exactly 1 call — it must merely be STABLE across
      // ticks. A double-timer bug doubles whatever this baseline is.
      injectedNow = DateTime(2026, 6, 13, 8, 15); // still inside active window
      nowCallCount = 0;
      await tester.pump(const Duration(minutes: 1));
      final perTickCallCount = nowCallCount;
      expect(
        perTickCallCount,
        greaterThan(0),
        reason: 'sanity: the single-timer baseline tick must call now() at all',
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
      // Detection: count now() calls across exactly one 1-minute pump() and
      // compare against perTickCallCount (captured above from a single known-
      // good timer, NOT hardcoded to 1 — TodayScreen legitimately calls
      // _nowFn() more than once per build). A double-timer bug would double
      // this count regardless of its baseline value.
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

      // If _startNowTimer is idempotent, exactly one timer fired → the same
      // per-build now() call count as the known-good baseline tick.
      // If a double-timer leaked, nowCallCount would be double that (or more).
      expect(
        nowCallCount,
        perTickCallCount,
        reason:
            'WR-03: _startNowTimer must be idempotent — exactly one timer '
            'after two paused→resumed cycles, so now() is called the same '
            'number of times per tick as the known-good baseline',
      );
      // Sanity: the Now zone shows one (not duplicated) LiveRowCard.
      expect(
        find.byType(LiveRowCard),
        findsOneWidget,
        reason: 'WR-03: single rebuild per tick — no duplicate widget',
      );
    });
  });
}
