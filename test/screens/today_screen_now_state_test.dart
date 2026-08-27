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
import 'package:canopy/screens/today/timeline_geometry.dart';
import 'package:canopy/screens/today/today_screen.dart';
import 'package:canopy/screens/today/widgets/live_row_card.dart';
import 'package:canopy/screens/today/widgets/now_line.dart';
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

/// Creates a break chunk (short by default) with injectable time/resolution
/// parameters. Modelled on `today_timeline_model_test.dart`'s `_breakChunk`,
/// with `chunkTypeIndex`/`isCompleted`/`isSkipped` added so long breaks and
/// break-resolution edge cases are buildable here too (LIVE-01, Task 1).
/// `goalId` stays unset (null) and `rationale` stays `''` — that is what the
/// generator emits for breaks (`schedule_generator.dart:634`).
///
/// [chunkTypeIndex] defaults to `ChunkType.shortBreak.index` at call time —
/// it cannot be a literal default-parameter value because Dart does not
/// treat enum `.index` access as a compile-time constant expression.
ScheduledChunk _breakChunk({
  String id = 'break-1',
  int? chunkTypeIndex,
  int? syntheticStartMinutes,
  int durationMinutes = 5,
  bool isCompleted = false,
  bool isSkipped = false,
}) {
  final c = ScheduledChunk(
    id: id,
    chunkTypeIndex: chunkTypeIndex ?? ChunkType.shortBreak.index,
    durationMinutes: durationMinutes,
    rationale: '',
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

/// Jumps the day's scroll offset to exactly 0 and settles.
///
/// D-31-07 Case B needs to compare `tester.getRect` screen coordinates
/// across two separate pumps with different `NowState` classifications
/// (Active vs GapBeforeNext). CAL-03 ("elapsed time recedes") auto-centres
/// the scroll offset on open, and it centres DIFFERENTLY per `NowState` —
/// left unpinned, the two pumps' screen coordinates differ by the scroll
/// delta between the two auto-centre targets, not by any real geometry
/// change, which would make a same-position assertion fail for the wrong
/// reason (or, worse, pass for the wrong reason). Pinning both pumps to the
/// same offset isolates the actual claim under test.
Future<void> _pinScrollToTop(WidgetTester tester) async {
  final scrollable = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  scrollable.position.jumpTo(0);
  await tester.pump();
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

    // ── LIVE-01: breaks now participate in resolveNowState ─────────────────

    test('active: a running short break is the current activity', () {
      final chunks = [
        _breakChunk(id: 'b1', syntheticStartMinutes: 505, durationMinutes: 5),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 8, 27),
      );
      expect(state, isA<Active>());
      expect((state as Active).current.id, 'b1');
    });

    test('active: a running long break is the current activity', () {
      final chunks = [
        _breakChunk(
          id: 'lb',
          chunkTypeIndex: ChunkType.longBreak.index,
          syntheticStartMinutes: 505,
          durationMinutes: 25,
        ),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 8, 30),
      );
      expect(state, isA<Active>());
      final active = state as Active;
      expect(active.current.id, 'lb');
      expect(active.current.chunkType, ChunkType.longBreak);
    });

    test('active work chunk\'s next is the contiguous break', () {
      final chunks = [
        _workChunk(id: 'w1', syntheticStartMinutes: 480, durationMinutes: 25),
        _breakChunk(id: 'b1', syntheticStartMinutes: 505, durationMinutes: 5),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 8, 10),
      );
      expect(state, isA<Active>());
      final active = state as Active;
      expect(active.current.id, 'w1');
      expect(active.next?.id, 'b1');
    });

    test('gap-before-next can target a break (KEY INVARIANT: an unopened '
        'break window is never promoted to Active)', () {
      final chunks = [
        _workChunk(
          id: 'w1',
          syntheticStartMinutes: 480,
          durationMinutes: 25,
          isCompleted: true,
        ),
        _breakChunk(id: 'b1', syntheticStartMinutes: 505, durationMinutes: 5),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 8, 10),
      );
      expect(state, isA<GapBeforeNext>());
      expect((state as GapBeforeNext).next.id, 'b1');
    });

    test(
      'overdue: a break window has passed and the next window has not opened',
      () {
        final chunks = [
          _breakChunk(id: 'b1', syntheticStartMinutes: 505, durationMinutes: 5),
          _workChunk(id: 'w2', syntheticStartMinutes: 540, durationMinutes: 25),
        ];
        final state = resolveNowState(
          chunks: chunks,
          now: () => DateTime(2026, 6, 13, 8, 35),
        );
        expect(state, isA<Overdue>());
        final overdue = state as Overdue;
        expect(overdue.overdue.id, 'b1');
        expect(overdue.next?.id, 'w2');
      },
    );

    test('day-complete still fires past the last window on a work+break day '
        '(STEP E keeps the last chunk work-typed)', () {
      final chunks = [
        _workChunk(id: 'w1', syntheticStartMinutes: 480, durationMinutes: 25),
        _breakChunk(id: 'b1', syntheticStartMinutes: 505, durationMinutes: 5),
        _workChunk(id: 'w2', syntheticStartMinutes: 510, durationMinutes: 25),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 18, 0),
      );
      expect(state, isA<DayComplete>());
    });

    test('CR-01: a trailing break past its own window resolves to '
        'DayComplete truthfully instead of throwing', () {
      // This exact chunk shape (a break as the chronologically-last
      // scheduled item) is what Phase 23 review iteration 2 (CR-01) proved
      // reachable through ScheduleNotifier.addEventToday's stale-chunk-
      // removal branch (see schedule_notifier_add_event_test.dart's
      // matching CR-01 test for the write-side repro) — this is no longer
      // "deliberately malformed" input the way the retired WR-02 assert
      // treated it. Once `currentMinutes` is past this trailing break's own
      // window end, nothing else is scheduled today regardless of its
      // type, so DayComplete is the correct, truthful answer — and,
      // per CR-01, resolveNowState must reach it without throwing.
      final chunks = [
        _workChunk(id: 'w1', syntheticStartMinutes: 480, durationMinutes: 25),
        _breakChunk(id: 'b1', syntheticStartMinutes: 505, durationMinutes: 5),
      ];
      final state = resolveNowState(
        chunks: chunks,
        now: () => DateTime(2026, 6, 13, 18, 0), // well past b1's window
      );
      expect(state, isA<DayComplete>());
    });

    test(
      'CR-01: the same trailing-break fixture still resolves Active '
      'while its own window is current (unaffected by the assert removal)',
      () {
        // Companion to the DayComplete test above: confirms the trailing
        // boundary check only ever fires once `currentMinutes` is past the
        // trailing chunk's own window — a legitimate in-progress state (the
        // break itself is the live activity) must keep resolving normally,
        // exactly as the pre-existing "a running break gets the same
        // countdown treatment" widget test already relies on. This behavior
        // is unchanged by CR-01's fix (removing the WR-02 assert did not
        // touch this code path at all).
        final chunks = [
          _workChunk(id: 'w1', syntheticStartMinutes: 480, durationMinutes: 25),
          _breakChunk(id: 'b1', syntheticStartMinutes: 505, durationMinutes: 5),
        ];
        final state = resolveNowState(
          chunks: chunks,
          now: () => DateTime(2026, 6, 13, 8, 27), // inside b1's window
        );
        expect(state, isA<Active>());
        expect((state as Active).current.id, 'b1');
      },
    );
  });

  // ── Widget tests: TodayScreen time-anchored Now (NOW-01/NOW-02) ──────────

  group('TodayScreen time-anchored Now (NOW-01/NOW-02)', () {
    testWidgets('pre-start: 6am before 8am chunk → shows "Nothing until"', (
      tester,
    ) async {
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
        now: () => DateTime(2026, 6, 13, 6, 0), // 6:00 AM
      );
      expect(
        find.text('Nothing until 8:00 AM'),
        findsOneWidget,
        reason: 'NOW-02: pre-start heading must appear before first chunk',
      );
      expect(
        find.byType(LiveRowCard),
        findsNothing,
        reason: 'NOW-02: no LiveRowCard in pre-start state',
      );
    });

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
        find.textContaining('Nothing until'),
        findsNothing,
        reason: 'NOW-01: no pre-start heading when chunk is active',
      );
      expect(
        find.text("That's the day."),
        findsNothing,
        reason: 'NOW-01: no day-complete heading when chunk is active',
      );
    });

    testWidgets(
      'between-chunks (overdue): 10am, c1 8:30–9:30, c2 10:30–11:30 → LiveRowCard (c1)',
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
        //
        // findsWidgets, not findsOneWidget: since the live row left the time
        // gutter its kicker also carries the start time ("RIGHT NOW · 8:30 AM"),
        // so c1's start legitimately appears twice. The identity check below is
        // the load-bearing half — c2's start must be absent entirely.
        expect(
          find.descendant(
            of: find.byType(LiveRowCard),
            matching: find.textContaining('8:30 AM'),
          ),
          findsWidgets,
          reason:
              'WR-02: LiveRowCard must display c1 (8:30 AM start), '
              'not c2 (10:30 AM start)',
        );
        // The kicker names which chunk is Now, so it is the precise identity
        // check. c1 is 60 minutes, so at 240dp it renders the compact tier
        // and the kicker survives (GRID-02).
        expect(
          find.descendant(
            of: find.byType(LiveRowCard),
            matching: find.textContaining('RIGHT NOW · 8:30 AM'),
          ),
          findsOneWidget,
          reason:
              'WR-02: the live row kicker must identify c1 (8:30 AM) as Now',
        );
        // Phase 27 (GRID-02) deleted the live row's line naming the upcoming
        // chunk — the card's only remaining time-identity claim is the
        // kicker above. With that line gone, the identity check the old
        // comment here said it "could not make" (a blanket "10:30 AM must
        // not appear") is now available and is the stronger assertion: c2's
        // start must not leak into c1's card at all.
        expect(
          find.descendant(
            of: find.byType(LiveRowCard),
            matching: find.textContaining('10:30 AM'),
          ),
          findsNothing,
          reason:
              'GRID-02: c1\'s LiveRowCard must not name c2 (10:30 AM) — the '
              'line that used to legitimately do so is gone',
        );
      },
    );

    testWidgets(
      'day-complete (6pm, all windows passed) → shows "That\'s the day."',
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
          find.text("That's the day."),
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

    testWidgets('all-resolved → shows "That\'s the day." regardless of time', (
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
        find.text("That's the day."),
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
        'shows "Up next" and NOT "That\'s the day."', (tester) async {
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
            'CR-01: GapBeforeNext must render "Up next", not "That\'s the '
            'day."',
      );
      expect(
        find.text("That's the day."),
        findsNothing,
        reason: 'CR-01: "That\'s the day." must not appear in gap state',
      );
      // Must not show a card — this is an inline state, not an active chunk.
      expect(
        find.byType(LiveRowCard),
        findsNothing,
        reason: 'CR-01: no LiveRowCard in gap state',
      );
      // Must show the upcoming time in the body. Phase 26 (26-03-PLAN.md):
      // scoped to the edge-state banner itself. showStartTime flipped
      // false -> true for every non-live chunk row (CAL-01, "the time
      // gutter becomes an hour axis") means c2's own row NOW also renders
      // "10:00 AM – 10:25 AM" inside its ChunkCard, so an unscoped
      // find.textContaining('10:00 AM') is ambiguous between the banner
      // and the row beneath it. The original intent — the gap banner names
      // the next chunk's start time — is unchanged; only the finder is
      // narrowed to the banner's own subtree, mirroring the identical
      // ancestor-scoping pattern in today_screen_test.dart's "gap-before-next
      // targeting a break names the break" test.
      final upNextHeader = find
          .ancestor(of: find.text('Up next'), matching: find.byType(Padding))
          .first;
      expect(
        find.descendant(
          of: upNextHeader,
          matching: find.textContaining('10:00 AM'),
        ),
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
        find.textContaining('Nothing until'),
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
      // (unlike the old, pre-merge time-anchored Home screen) reads _nowFn()
      // from more than one call site per build (the date header,
      // resolveNowState, and the live row's remaining-time calc), so a single
      // legitimate timer tick is NOT guaranteed to be exactly 1 call — it
      // must merely be STABLE across ticks. A double-timer bug doubles
      // whatever this baseline is.
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

    // ── LIVE-01: a running break is a first-class current activity ─────────

    testWidgets(
      'live short break, single-line tier: a running break still announces '
      'itself as rest (PD-27-09)',
      (tester) async {
        final sn = _FakeScheduleNotifierWithSchedule(
          DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 480,
                durationMinutes: 25,
              ),
              _breakChunk(
                id: 'b1',
                syntheticStartMinutes: 505,
                durationMinutes: 5,
              ),
            ],
          ),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: sn,
          now: () => DateTime(2026, 6, 13, 8, 27),
        );
        // b1 is a 5-minute break — 20dp, below kCompactLiveMinHeight, so it
        // renders the single-line tier, which drops the visible RESTING
        // kicker entirely (27-UI-SPEC.md "Single-line tier": no room for a
        // third piece of information on one line). The "this is current,
        // and it is rest" framing the kicker used to carry now lives in the
        // row's Semantics label instead (`LiveRowCard`'s
        // `Semantics(label: 'Right now: $title, $remainingLabel', ...)`).
        final handle = tester.ensureSemantics();
        expect(
          find.bySemanticsLabel(RegExp(r'^Right now: Taking a break,')),
          findsOneWidget,
          reason:
              'a running break in the single-line tier must still announce '
              'itself as rest, via its semantics label',
        );
        handle.dispose();
        expect(find.text('Taking a break'), findsOneWidget);
      },
    );

    testWidgets(
      'live long break, compact tier: the visible RESTING kicker still '
      'names the rest (PD-27-09)',
      (tester) async {
        // Copies '`live long break: title says long`'s fixture (a 25-minute
        // long break, live at 8:27) rather than inventing a new one — at
        // 100dp this clears kCompactLiveMinHeight and renders the compact
        // tier, the one tier that still shows the visible kicker.
        final sn = _FakeScheduleNotifierWithSchedule(
          DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 480,
                durationMinutes: 25,
              ),
              _breakChunk(
                id: 'b1',
                chunkTypeIndex: ChunkType.longBreak.index,
                syntheticStartMinutes: 505,
                durationMinutes: 25,
              ),
            ],
          ),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: sn,
          now: () => DateTime(2026, 6, 13, 8, 27),
        );
        expect(
          find.textContaining('RIGHT NOW — RESTING'),
          findsOneWidget,
          reason:
              'a running long break in the compact tier must still show the '
              'visible RESTING kicker',
        );
      },
    );

    testWidgets('live long break: title says long', (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 25,
            ),
            _breakChunk(
              id: 'b1',
              chunkTypeIndex: ChunkType.longBreak.index,
              syntheticStartMinutes: 505,
              durationMinutes: 25,
            ),
          ],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 8, 27),
      );
      expect(find.text('Taking a long break'), findsOneWidget);
    });

    // The old D-02 case (a live break renders no action icons at all) was
    // SUPERSEDED 2026-08-26 by D-31-07, for the Skip direction only. D-02's
    // blanket exclusion is no longer true: the owner ruled
    // (31-CONTEXT.md "Gap-closure decisions") that a live break must show
    // Skip. Complete stays excluded — D-31-01: a break can never be
    // isCompleted, so a Complete button would advertise a state the data
    // model cannot reach. The one sweeping case that used to assert here is
    // replaced by the two precise ones below: a live long break shows Skip
    // and never Complete, and a live WORK chunk at the identical slot height
    // keeps both (the PD-31-07-03 regression guard this file's own comment
    // above already promises).
    testWidgets('D-31-07: a live long break shows Skip and never Complete', (
      tester,
    ) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 25,
              isCompleted: true,
            ),
            _breakChunk(
              id: 'b1',
              chunkTypeIndex: ChunkType.longBreak.index,
              syntheticStartMinutes: 505,
              durationMinutes: 30,
            ),
          ],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        // Inside b1's 505-535 window; b1's 120dp slot clears
        // kCompactLiveMinHeight (88.0) so the compact tier — the one with
        // icon actions — renders.
        now: () => DateTime(2026, 6, 13, 8, 27),
      );
      expect(
        find.descendant(
          of: find.byType(LiveRowCard),
          matching: find.byTooltip('Skip'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(LiveRowCard),
          matching: find.byTooltip('Complete'),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'D-31-07: a live WORK chunk at the identical slot height keeps both '
      'Complete and Skip (PD-31-07-03 regression guard)',
      (tester) async {
        final sn = _FakeScheduleNotifierWithSchedule(
          DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 505,
                // Same 120dp slot as the break case above — the point of
                // this guard is that D-31-07 changed nothing for work.
                durationMinutes: 30,
              ),
            ],
          ),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: sn,
          now: () => DateTime(2026, 6, 13, 8, 27),
        );
        expect(
          find.descendant(
            of: find.byType(LiveRowCard),
            matching: find.byTooltip('Skip'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(LiveRowCard),
            matching: find.byTooltip('Complete'),
          ),
          findsOneWidget,
        );
      },
    );

    // 'live break still shows a progress bar (D-04)' — DELETED (Phase 27,
    // GRID-02). The bar is gone from both live-row tiers by design: once the
    // card is duration-exact, the now-line's position within the card's
    // vertical span IS the fraction elapsed (27-UI-SPEC.md "Compact tier",
    // point 4). Do not restore a progress-bar widget here.

    group('D-31-07 — a live break can be skipped', () {
      // Fixture shape mirrors today_screen_test.dart's skipTracerFixture():
      // a completed 25-minute work chunk, a 5-minute short break, and a
      // following 25-minute work chunk. [breakSkipped] selects which of the
      // two fixtures Case B's composition proof needs.
      DailySchedule liveSkipFixture({bool breakSkipped = false}) {
        return DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 25,
              isCompleted: true,
            ),
            _breakChunk(
              id: 'b1',
              syntheticStartMinutes: 505,
              durationMinutes: 5,
              isSkipped: breakSkipped,
            ),
            _workChunk(id: 'w2', syntheticStartMinutes: 510, durationMinutes: 25),
          ],
        );
      }

      // 8:27 AM = minute 507 — inside b1's 505-510 window.
      DateTime liveSkipNow() => DateTime(2026, 6, 13, 8, 27);

      testWidgets('Case A — a live short break can be swiped', (
        tester,
      ) async {
        final fake = _FakeScheduleNotifierWithSchedule(liveSkipFixture());
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: fake,
          now: liveSkipNow,
        );
        await tester.pumpAndSettle();
        // b1 renders at the single-line tier (20dp < kCompactLiveMinHeight):
        // its title is the live present-continuous form, not "Short break".
        final liveClipRect = find
            .ancestor(
              of: find.text('Taking a break'),
              matching: find.byType(ClipRect),
            )
            .first;
        final paintedRect = tester.getRect(liveClipRect);
        final origin = Offset(
          paintedRect.center.dx,
          paintedRect.top - kBreakHitSlop + 2,
        );
        await tester.dragFrom(origin, const Offset(-400, 0));
        await tester.pumpAndSettle();

        expect(
          fake.lastSkippedId,
          'b1',
          reason:
              'D-31-07: a drag started inside a LIVE short break\'s grown '
              'hit-test envelope must still resolve to that break\'s '
              'SwipeableRowShell and call markSkipped.',
        );
        expect(
          fake.lastCompletedId,
          isNull,
          reason: 'D-31-07: a break must never call markComplete.',
        );
        expect(
          fake.lastSkippedId,
          isNot('w2'),
          reason:
              'a failure here must name the thief (the following work '
              'chunk), not merely report a wrong id.',
        );
      });

      // Case B — truth #14's composition, proven.
      //
      // CORRECTED FROM THE PLAN'S LITERAL TEXT (documented per this
      // project's deviation-tracking convention, twice over — see both
      // notes below):
      //
      // Correction 1. The plan's Case B describes pumping "the break
      // skipped" at a clock still inside its OWN window and expecting
      // `resolveNowState` to still report it `Active` (i.e. still live).
      // That premise is false, and is false for ANY chunk type, not just
      // breaks: `resolveNowState`'s "advance past resolved chunks" loop
      // (now_state.dart) unconditionally treats an `isCompleted ||
      // isSkipped` candidate as no longer current, even while its own
      // window is still open — this is a pre-existing, DELIBERATE, and
      // already-tested invariant (see this same file's "near-gap: c1
      // resolved 9:00-9:25, c2 starts 9:25, now=9:10 -> GapBeforeNext" case
      // above, which resolves a chunk mid-window and asserts GapBeforeNext,
      // not Active). Verified directly with a probe against
      // `resolveNowState` before writing this test: the fixture below, with
      // b1 pre-skipped and the clock unchanged, returns `GapBeforeNext(w2)`,
      // not `Active(b1)` — so b1 renders through the NON-live break arm,
      // not `LiveRowCard`, in the second pump.
      //
      // Correction 2. `_buildEdgeStateLine` renders NOTHING for
      // Active/Overdue but renders a real "Up next" banner (heading +
      // title + "Starts at ...") for GapBeforeNext — a genuine, expected
      // content difference between the two pumps that pushes the ENTIRE
      // timeline Stack down the page in pump 2. Comparing raw
      // `tester.getRect` screen coordinates across the two pumps therefore
      // compares two different page layouts, not two states of the same
      // layout (confirmed empirically: the raw absolute-Y comparison failed
      // by exactly the banner's height). Both measured rects below are
      // instead expressed RELATIVE TO the timeline Stack's own top, which
      // cancels this outer-page shift (and any scroll-offset difference)
      // and isolates the actual claim: has this chunk's position WITHIN the
      // timeline changed.
      //
      // Neither correction weakens truth #14 — together they let this test
      // prove the claim that is actually true and actually load-bearing:
      // the SAME chunk's confined paint band survives the
      // live-to-resolved-and-delisted transition at the IDENTICAL height
      // and the IDENTICAL position within the timeline, and the now-line
      // (which reads `nowMinutes` directly, never `nowState`) stays at the
      // identical position relative to that same timeline. Both arms route
      // through the same extracted `SwipeableRowShell._confineContent`
      // (Task 2), which is exactly why this composition holds structurally,
      // not by coincidence.
      testWidgets("Case B — truth #14's composition, proven", (tester) async {
        // Pump 1: b1 unresolved, live.
        final fakeLive = _FakeScheduleNotifierWithSchedule(liveSkipFixture());
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: fakeLive,
          now: liveSkipNow,
        );
        await _pinScrollToTop(tester);
        expect(
          find.byType(LiveRowCard),
          findsOneWidget,
          reason: 'b1 must be the live row while unresolved.',
        );
        final stackRectLive = tester.getRect(find.byType(Stack).first);
        final liveClipRect = find
            .ancestor(
              of: find.text('Taking a break'),
              matching: find.byType(ClipRect),
            )
            .first;
        final liveRect = tester.getRect(liveClipRect);
        expect(
          liveRect.height,
          5 * kPixelsPerMinute,
          reason: "truth #14 claim 1: keeps its slot height (live pump).",
        );
        // Relative to the Stack's own top — see Correction 2 above.
        final liveTopInStack = liveRect.top - stackRectLive.top;
        final nowLineTopInStackBefore =
            tester.getRect(find.byType(NowLineOverlay)).top -
            stackRectLive.top;

        // TodayScreenState._nowFn is late final — a second pump with a
        // different fixture must fully unmount first, or the second clock
        // is silently ignored and both measurements come from the same
        // tree (carried from the sibling file's identical SKIPBREAK-02
        // comment).
        await tester.pumpWidget(const SizedBox.shrink());

        // Pump 2: b1 pre-skipped, SAME clock. Per Correction 1 above, this
        // is GapBeforeNext(w2) — b1 renders through the non-live break arm
        // (title reverts to "Short break").
        final fakeSkipped = _FakeScheduleNotifierWithSchedule(
          liveSkipFixture(breakSkipped: true),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: fakeSkipped,
          now: liveSkipNow,
        );
        await _pinScrollToTop(tester);
        expect(
          find.byType(LiveRowCard),
          findsNothing,
          reason:
              'b1 is no longer "current" once resolved — resolveNowState '
              'delists it, exactly as the pre-existing near-gap invariant '
              'above already establishes for work chunks. This is the '
              'corrected, evidence-based half of truth #14\'s "stays on '
              'the timeline" claim: the SAME slot, not the SAME widget '
              'type.',
        );
        final stackRectResolved = tester.getRect(find.byType(Stack).first);
        final resolvedClipRect = find
            .ancestor(
              of: find.text('Short break'),
              matching: find.byType(ClipRect),
            )
            .first;
        final resolvedRect = tester.getRect(resolvedClipRect);
        expect(
          resolvedRect.height,
          5 * kPixelsPerMinute,
          reason: "truth #14 claim 1: keeps its slot height (resolved pump).",
        );
        final resolvedTopInStack = resolvedRect.top - stackRectResolved.top;
        expect(
          resolvedTopInStack,
          liveTopInStack,
          reason:
              "truth #14 claim 2: stays on the timeline — the confined "
              "band's top edge, measured relative to the timeline Stack's "
              "own top (so the GapBeforeNext-only 'Up next' banner above "
              "the Stack cannot confound the comparison), is at the "
              "identical position before and after resolution, because "
              "both arms route through the same "
              "SwipeableRowShell._confineContent geometry.",
        );
        final nowLineTopInStackAfter =
            tester.getRect(find.byType(NowLineOverlay)).top -
            stackRectResolved.top;
        expect(
          nowLineTopInStackAfter,
          nowLineTopInStackBefore,
          reason:
              "truth #14 claim 3: does not move the now-line — asserted by "
              "direct equality of the now-line's position relative to the "
              "Stack (not by re-deriving the expected y from geometry, "
              "which the vacuity class 27-01's liveExtraPx defect is the "
              "standing example against), and not by raw screen "
              "coordinates, which Correction 2 above shows would conflate "
              "a real geometry change with the GapBeforeNext banner's "
              "unrelated page shift.",
        );
      });

      testWidgets(
        'Case C — a break that was live and is now resolved-and-delisted '
        'offers no Skip affordance and cannot be re-swiped',
        (tester) async {
          // Same correction as Case B: an "already-skipped LIVE break" is
          // unreachable through resolveNowState (see Case B's comment) — the
          // reachable state is a break that WAS live and, once skipped, is
          // delisted from live status and rendered by the non-live arm.
          // This proves non-negotiable #5 ("a resolved chunk must not
          // advertise a gesture it no longer accepts") against exactly that
          // reachable state, at the geometric position the live row
          // previously occupied.
          final fake = _FakeScheduleNotifierWithSchedule(
            liveSkipFixture(breakSkipped: true),
          );
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: fake,
            now: liveSkipNow,
          );
          expect(find.byType(LiveRowCard), findsNothing);
          final resolvedClipRect = find
              .ancestor(
                of: find.text('Short break'),
                matching: find.byType(ClipRect),
              )
              .first;
          final resolvedRect = tester.getRect(resolvedClipRect);
          final origin = Offset(
            resolvedRect.center.dx,
            resolvedRect.top - kBreakHitSlop + 2,
          );
          await tester.dragFrom(origin, const Offset(-400, 0));
          await tester.pumpAndSettle();
          expect(
            fake.lastSkippedId,
            isNull,
            reason:
                'an already-skipped break has DismissDirection.none — a '
                'drag inside its grown envelope must resolve nothing.',
          );
        },
      );

      testWidgets(
        'Case D — a live, UNRESOLVED break carries no strikethrough '
        '(pairs with the isSkipped:true case already proven at the widget '
        'level in today_row_widgets_test.dart, since an isSkipped:true LIVE '
        'break is unreachable through resolveNowState — see Case B)',
        (tester) async {
          final fake = _FakeScheduleNotifierWithSchedule(liveSkipFixture());
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: fake,
            now: liveSkipNow,
          );
          final titleText = tester.widget<Text>(find.text('Taking a break'));
          expect(titleText.style?.decoration, isNot(TextDecoration.lineThrough));
        },
      );
    });

    testWidgets(
      'GapBeforeNext "Up next" banner names the reference title, not '
      '"Work block" (PD-27-10)',
      (tester) async {
        // PD-27-10: this test's real subject is `_chunkTitle`'s
        // break-awareness, not the live row's now-deleted line naming the
        // upcoming chunk.
        // `_chunkTitle` survives with two callers (today_screen.dart ~460
        // PreStart, ~507 GapBeforeNext), and today_screen.dart's own comment
        // at ~494-498 explicitly names break-awareness at the GapBeforeNext
        // site as load-bearing ("do NOT add a `chunkType` check in this
        // case; the shared helper already handles it") — repointed here so
        // that guard can still fail.
        //
        // w1 is marked completed (resolved); `now` sits inside w1's own
        // window but before b1's window opens. resolveNowState's
        // GapBeforeNext branch fires once the current window's chunk is
        // resolved and the next chunk's window has not yet opened
        // (now_state.dart) — b1 has not opened yet (505 > 490 at 8:10),
        // producing GapBeforeNext(b1), matching the identical fixture shape
        // in `today_screen_test.dart`'s sibling "gap-before-next targeting a
        // break names the break" test.
        final sn = _FakeScheduleNotifierWithSchedule(
          DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 480,
                durationMinutes: 25,
                isCompleted: true,
              ),
              _breakChunk(
                id: 'b1',
                syntheticStartMinutes: 505,
                durationMinutes: 5,
              ),
            ],
          ),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: sn,
          now: () => DateTime(2026, 6, 13, 8, 10),
        );
        expect(find.text('Up next'), findsOneWidget);
        // 'Short break' legitimately renders twice — once in the edge-state
        // banner under test, once in b1's own (unresolved, upcoming) row
        // further down the day list — scope to the banner itself, mirroring
        // today_screen_test.dart's identical ancestor-scoping pattern.
        final upNextHeader = find
            .ancestor(of: find.text('Up next'), matching: find.byType(Padding))
            .first;
        expect(
          find.descendant(of: upNextHeader, matching: find.text('Short break')),
          findsOneWidget,
        );
        expect(find.text('Work block'), findsNothing);
      },
    );

    testWidgets('live work chunk keeps the plain kicker', (tester) async {
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
        now: () => DateTime(2026, 6, 13, 9, 0),
      );
      // Prefix match: the kicker now also carries the start time (see the
      // amended live-row spec). The load-bearing assertion is the negative
      // one — a work chunk must NOT be announced as rest.
      expect(find.textContaining('RIGHT NOW'), findsOneWidget);
      expect(find.textContaining('RESTING'), findsNothing);
    });

    testWidgets('live work chunk still shows Complete/Skip', (tester) async {
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
        now: () => DateTime(2026, 6, 13, 9, 0),
      );
      // The 60-minute chunk renders the compact tier (240dp), whose
      // Complete/Skip are bare IconButtons with a Tooltip, not the shipped
      // card's labelled FilledButton/OutlinedButton (GRID-02). Scoped to
      // LiveRowCard: a lone unresolved work chunk also renders its own
      // non-live ChunkCard row elsewhere in other fixtures, and an unscoped
      // finder invites a future false pass.
      expect(
        find.descendant(
          of: find.byType(LiveRowCard),
          matching: find.byTooltip('Complete'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(LiveRowCard),
          matching: find.byTooltip('Skip'),
        ),
        findsOneWidget,
      );
    });

    // ── LIVE-02: second-precision countdown label (D-01, D-04, P-5) ────────

    testWidgets('15 minutes remaining reads whole minutes', (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 30,
            ),
          ],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 8, 15, 0),
      );
      expect(find.text('15 min left · until 8:30 AM'), findsOneWidget);
    });

    testWidgets('sub-minute remainders round UP, never down (D-01)', (
      tester,
    ) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 30,
            ),
          ],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 8, 15, 30),
      );
      expect(find.text('15 min left · until 8:30 AM'), findsOneWidget);
      expect(find.textContaining('14 min left'), findsNothing);
    });

    testWidgets('61 seconds remaining is still the minutes branch', (
      tester,
    ) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 30,
            ),
          ],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 8, 28, 59),
      );
      expect(find.text('2 min left · until 8:30 AM'), findsOneWidget);
    });

    testWidgets('exactly 60 seconds remaining is the minutes branch boundary', (
      tester,
    ) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 30,
            ),
          ],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 8, 29, 0),
      );
      expect(find.text('1 min left · until 8:30 AM'), findsOneWidget);
    });

    testWidgets('59 seconds remaining switches to seconds', (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 30,
            ),
          ],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 8, 29, 1),
      );
      expect(find.text('59s left · until 8:30 AM'), findsOneWidget);
    });

    testWidgets('1 second remaining still reads seconds, never 0 min', (
      tester,
    ) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 30,
            ),
          ],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 8, 29, 59),
      );
      expect(find.text('1s left · until 8:30 AM'), findsOneWidget);
      expect(find.textContaining('0 min left'), findsNothing);
    });

    testWidgets('a running break gets the same countdown treatment', (
      tester,
    ) async {
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 25,
            ),
            _breakChunk(
              id: 'b1',
              syntheticStartMinutes: 505,
              durationMinutes: 5,
            ),
          ],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        now: () => DateTime(2026, 6, 13, 8, 29, 30),
      );
      // b1 is a 5-minute break — the single-line tier (20dp), whose locked
      // Row/Expanded split (27-UI-SPEC.md "Single-line tier") renders the
      // countdown as its OWN Text carrying a leading ' · ' prefix
      // (`' · $remainingLabel'`), never as the bare label alone in a single
      // Text. This is the same class of fallout as this file's other
      // now-deleted-concept failures, not a defect — 27-02-SUMMARY.md
      // investigated this exact failure and confirmed it matches
      // 27-UI-SPEC.md's locked contract. Repointed to textContaining,
      // scoped to LiveRowCard so it can't accidentally match elsewhere.
      expect(
        find.descendant(
          of: find.byType(LiveRowCard),
          matching: find.textContaining('30s left · until 8:30 AM'),
        ),
        findsOneWidget,
      );
    });

    // ── WR-01 regression: one clock sample per build, threaded not re-read ──
    //
    // resolveNowState's own doc comment explains why it samples `now()`
    // exactly once — a second, independent read in the same render pass
    // can straddle a boundary and disagree with the first. Before the
    // WR-01 fix, `_liveSecondsRemaining` called `_nowFn()` a second time
    // instead of reusing the sample `resolveNowState` had already taken.
    // This test drives an injected clock that returns a DIFFERENT value on
    // each successive call within the same build and asserts the rendered
    // countdown matches the FIRST (classifying) sample, not a later one —
    // it fails against the pre-fix re-read and passes against the fix,
    // which threads a single `nowDt` into both consumers.
    testWidgets(
      'the countdown matches the sample that classified the state, not a '
      'later clock read (WR-01)',
      (tester) async {
        // TodayScreen.build() makes exactly two `_nowFn()` calls per build
        // in the fixed code: one shared sample for resolveNowState AND
        // _liveSecondsRemaining, and a second, independent one later for
        // the header's date text. The pre-fix code made three: a first for
        // resolveNowState, a second (independent) one for
        // _liveSecondsRemaining, and a third for the header. Supplying
        // distinct values for the first two calls means the fixed code
        // renders using only callValues[0], while the pre-fix code would
        // have rendered its countdown using callValues[1] instead.
        final callValues = [
          DateTime(2026, 6, 13, 8, 29, 15), // 45s remaining
          DateTime(2026, 6, 13, 8, 29, 25), // 35s remaining — must not leak in
        ];
        var callIndex = 0;
        DateTime nowFn() {
          final value =
              callValues[callIndex < callValues.length
                  ? callIndex
                  : callValues.length - 1];
          callIndex++;
          return value;
        }

        final sn = _FakeScheduleNotifierWithSchedule(
          DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 480,
                durationMinutes: 30,
              ),
            ],
          ),
        );
        await _pumpTodayScreen(tester, scheduleNotifier: sn, now: nowFn);

        expect(find.text('45s left · until 8:30 AM'), findsOneWidget);
        expect(find.textContaining('35s left'), findsNothing);
      },
    );

    // 'the progress bar tracks the same value as the label' — DELETED
    // (Phase 27, GRID-02). Its stated purpose (23-02's D-04: the bar and the
    // label can never disagree) is now satisfied by construction — the
    // progress bar is gone, and there is only one renderer of
    // secondsRemaining left (the label), so nothing remains for it to
    // disagree with. The surrounding LIVE-02 countdown tests above already
    // assert the label itself.
  });

  // ── LIVE-02: the dual-cadence tick (D-01, P-5a, T-23-04) ─────────────────

  group('LIVE-02 fast tick', () {
    testWidgets('the label advances every second inside the final minute', (
      tester,
    ) async {
      DateTime injectedNow = DateTime(2026, 6, 13, 8, 29, 1);
      int nowCallCount = 0;
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 30,
            ),
          ],
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

      expect(find.text('59s left · until 8:30 AM'), findsOneWidget);

      injectedNow = DateTime(2026, 6, 13, 8, 29, 2);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('58s left · until 8:30 AM'), findsOneWidget);
    });

    testWidgets('no timer fires on a one-second pump outside the final '
        'minute', (tester) async {
      DateTime injectedNow = DateTime(2026, 6, 13, 8, 15, 0);
      int nowCallCount = 0;
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 30,
            ),
          ],
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

      nowCallCount = 0;
      await tester.pump(const Duration(seconds: 1));

      expect(
        nowCallCount,
        0,
        reason: 'D-01: no 1-second timer runs outside the final minute',
      );
    });

    testWidgets(
      'a fast timer starts when the chunk crosses into its final minute '
      'and stops when it leaves',
      (tester) async {
        DateTime injectedNow = DateTime(2026, 6, 13, 8, 28, 30);
        int nowCallCount = 0;
        final sn = _FakeScheduleNotifierWithSchedule(
          DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 480,
                durationMinutes: 30,
              ),
            ],
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

        nowCallCount = 0;
        await tester.pump(const Duration(seconds: 1));
        expect(
          nowCallCount,
          0,
          reason: 'still outside the final minute, no fast timer yet',
        );

        // Cross into the final minute and let the 1-minute coarse tick
        // re-evaluate _syncFastTimer against the fresh clock.
        injectedNow = DateTime(2026, 6, 13, 8, 29, 10);
        await tester.pump(const Duration(minutes: 1));
        nowCallCount = 0;
        await tester.pump(const Duration(seconds: 1));
        expect(
          nowCallCount,
          greaterThan(0),
          reason: 'the fast timer is now running inside the final minute',
        );

        // Move past the window entirely (re-resolves to DayComplete) and
        // let the coarse tick re-evaluate again.
        injectedNow = DateTime(2026, 6, 13, 8, 31, 0);
        await tester.pump(const Duration(minutes: 1));
        nowCallCount = 0;
        await tester.pump(const Duration(seconds: 1));
        expect(
          nowCallCount,
          0,
          reason: 'the fast timer was cancelled once it was no longer needed',
        );
      },
    );

    testWidgets(
      'the fast timer is not duplicated across a paused/resumed cycle',
      (tester) async {
        DateTime injectedNow = DateTime(2026, 6, 13, 8, 29, 10);
        int nowCallCount = 0;
        final sn = _FakeScheduleNotifierWithSchedule(
          DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 480,
                durationMinutes: 30,
              ),
            ],
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

        nowCallCount = 0;
        await tester.pump(const Duration(seconds: 1));
        final baseline = nowCallCount;
        expect(
          baseline,
          greaterThan(0),
          reason:
              'sanity: the single-fast-timer baseline tick must call '
              'now() at all',
        );

        for (var i = 0; i < 2; i++) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
        }

        nowCallCount = 0;
        await tester.pump(const Duration(seconds: 1));
        expect(
          nowCallCount,
          baseline,
          reason:
              'a leaked duplicate fast timer would double the baseline tick '
              'count, regardless of its magnitude',
        );
      },
    );

    testWidgets('no timer is pending after the widget tree is disposed', (
      tester,
    ) async {
      final injectedNow = DateTime(2026, 6, 13, 8, 29, 10);
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 30,
            ),
          ],
        ),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: sn,
        now: () => injectedNow,
      );

      expect(find.byType(LiveRowCard), findsOneWidget);

      await tester.pumpWidget(const SizedBox());

      expect(find.byType(LiveRowCard), findsNothing);
    });

    testWidgets('the fast timer does not survive the schedule disappearing', (
      tester,
    ) async {
      DateTime injectedNow = DateTime(2026, 6, 13, 8, 29, 10);
      int nowCallCount = 0;
      final sn = _FakeScheduleNotifierWithSchedule(
        DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'w1',
              syntheticStartMinutes: 480,
              durationMinutes: 30,
            ),
          ],
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

      expect(find.byType(LiveRowCard), findsOneWidget);

      final noSchedule = _FakeScheduleNotifier();
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: noSchedule,
        now: () {
          nowCallCount = nowCallCount + 1;
          return injectedNow;
        },
      );

      nowCallCount = 0;
      await tester.pump(const Duration(seconds: 1));
      expect(
        nowCallCount,
        0,
        reason: 'the empty-state early return must call _syncFastTimer(false)',
      );
    });
  });

  // ── G-03: paused-without-resume must not strand the live row ────────────
  //
  // UAT gap: Dan opened the app at 9:13 with a chunk starting 9:15; the live
  // row never appeared until a manual browser refresh. The happy-path minute
  // tick across PreStart→Active was already proven correct by NOW-01 above
  // (and by a deleted scratch test in 23-GAP-ANALYSIS.md) — these two tests
  // do NOT re-test that. They pin the falsified-then-confirmed root cause:
  // `didChangeAppLifecycleState`'s `paused` branch cancelled BOTH timers and
  // `resumed` was the ONLY revival path anywhere in the file, so a paused
  // event with no matching resumed stranded the screen permanently.
  //
  // A note on why these tests route through AppLifecycleState.inactive
  // rather than only paused: `SchedulerBinding.handleAppLifecycleStateChanged`
  // (package:flutter/src/scheduler/binding.dart) disables ALL frame
  // scheduling while the app is `hidden`/`paused`/`detached`, and only
  // re-enables it on `resumed`/`inactive` — this is engine-level behaviour,
  // true in production exactly as in tests, and independent of anything this
  // plan changes. A `Timer.periodic` still fires while frames are disabled
  // (timers are a Zone/event-loop concern, not a rendering concern) and
  // still calls `setState`, but `WidgetTester.pump()` cannot observe that via
  // a rendered widget until frame scheduling is re-enabled — with genuine
  // `paused` + zero further events, `find.byType(...)` can never resolve
  // either way, which would prove nothing about this fix. `inactive` is the
  // engine-level "frames may draw again" signal that is NOT `resumed`: this
  // file's `didChangeAppLifecycleState` has no special case for `inactive`
  // (it only branches on `resumed`/`paused`), so delivering it exercises
  // "a frame is drawable, but the app's own resumed handler never ran" —
  // precisely the scenario this fix targets — without smuggling in the
  // resumed branch's own explicit `_startNowTimer()` + `setState()`, which
  // would trivially pass regardless of whether `paused` had cancelled
  // `_nowTimer`.
  group('G-03 timer resilience', () {
    testWidgets(
      'G-03: the minute tick still fires after a paused with no matching '
      'resumed',
      (tester) async {
        // 9:15 AM = 555 minutes. Clock starts at 9:13, inside PreStart.
        DateTime injectedNow = DateTime(2026, 6, 13, 9, 13);
        final sn = _FakeScheduleNotifierWithSchedule(
          DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 555,
                durationMinutes: 60,
              ),
            ],
          ),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: sn,
          now: () => injectedNow,
        );

        expect(
          find.textContaining('Nothing until'),
          findsOneWidget,
          reason: 'G-03: should be in pre-start state at 9:13 AM',
        );

        // Background the app — and deliberately never deliver `resumed`.
        // That missing callback is the whole bug.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        // The chunk's window opens at 9:15.
        injectedNow = DateTime(2026, 6, 13, 9, 15);

        // Re-enable frame drawing at the engine level WITHOUT ever calling
        // this file's `resumed` branch (see the group-level comment above).
        // `_isBackgrounded` (and the cancelled `_fastTimer`) stay exactly as
        // `paused` left them — only Flutter's own frame gate changes.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();

        // The still-running minute tick (never cancelled by the fix) fires
        // here and, with frames now drawable, finally paints the caught-up
        // state — with no resumed callback ever having been delivered.
        await tester.pump(const Duration(minutes: 1));

        expect(
          find.byType(LiveRowCard),
          findsOneWidget,
          reason:
              'G-03: a paused-without-resume must not permanently strand '
              'the screen — the minute tick must still carry pre-start '
              'into active on its own, with no manual refresh required',
        );
      },
    );

    testWidgets(
      'G-03: the fast timer stays off while backgrounded but the minute '
      'tick survives',
      (tester) async {
        // 8:29:10 — inside the final minute of an 8:00-8:30 chunk, so the
        // fast timer is running from the very first build.
        final injectedNow = DateTime(2026, 6, 13, 8, 29, 10);
        int nowCallCount = 0;
        final sn = _FakeScheduleNotifierWithSchedule(
          DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 480,
                durationMinutes: 30,
              ),
            ],
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

        // Baseline: fast timer alive in the foreground (frames are already
        // enabled here — paused has not been delivered yet).
        nowCallCount = 0;
        await tester.pump(const Duration(seconds: 1));
        expect(
          nowCallCount,
          greaterThan(0),
          reason:
              'G-03: sanity — the fast timer must be running before '
              'backgrounding',
        );

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();

        // Re-enable frame drawing (see the group-level comment) so the
        // counts below are actually observable, WITHOUT calling this file's
        // `resumed` branch — `_isBackgrounded` stays true throughout this
        // block, exactly as a genuinely un-resumed pause would leave it.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();

        // The 1/second ticker must be dead while backgrounded — the
        // battery contract this whole fix must not regress. (Both the
        // pre-fix and post-fix code cancel _fastTimer on `paused`; this
        // assertion is a no-regression check, not the discriminator below.)
        nowCallCount = 0;
        await tester.pump(const Duration(seconds: 1));
        expect(
          nowCallCount,
          0,
          reason: 'G-03: the fast timer must not tick while backgrounded',
        );

        // The 1/minute tick is still alive while backgrounded, with no
        // resumed callback ever delivered — this is the fix itself, and the
        // one assertion that only passes post-fix.
        nowCallCount = 0;
        await tester.pump(const Duration(minutes: 1));
        expect(
          nowCallCount,
          greaterThan(0),
          reason:
              'G-03: the coarse minute tick must survive a pause with no '
              'matching resume',
        );

        // Now deliver the real `resumed` callback: the fast timer must come
        // back because the clock is still inside the final minute.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        nowCallCount = 0;
        await tester.pump(const Duration(seconds: 1));
        expect(
          nowCallCount,
          greaterThan(0),
          reason: 'G-03: the fast timer resumes once foregrounded again',
        );
      },
    );
  });
}
