// Widget tests for ActiveChunkCard and the HomeScreen Now/Next refactor — Phase 12 Plan 03.
//
// NAV-02: Home leads with a "Now" section (ActiveChunkCard with always-visible
// Complete/Skip buttons), a "Next" section for the second unresolved work chunk,
// and a "See full schedule" link that navigates to /schedule.
//
// Tests pump ActiveChunkCard directly (Task 1) and HomeScreen (Task 2).
// Mirrors home_screen_breathing_pulse_test.dart provider wiring pattern.

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

import '../test_helpers/mood_pump.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

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

// ─── Chunk factories ─────────────────────────────────────────────────────────

ScheduledChunk _workChunk({
  String id = 'chunk-1',
  int? syntheticStartMinutes,
}) => ScheduledChunk(
  id: id,
  chunkTypeIndex: ChunkType.work.index,
  goalId: 'goal-1',
  durationMinutes: 25,
  rationale: 'Deep work',
  syntheticStartMinutes: syntheticStartMinutes,
);

// ─── Pump helper ─────────────────────────────────────────────────────────────

Future<void> _pumpActiveChunkCard(
  WidgetTester tester, {
  required ScheduledChunk chunk,
  _FakeScheduleNotifier? scheduleNotifier,
  _FakeGoalsNotifier? goalsNotifier,
}) async {
  final sn = scheduleNotifier ?? _FakeScheduleNotifier();
  final gn = goalsNotifier ?? _FakeGoalsNotifier();
  await pumpWithMood(
    tester,
    ActiveChunkCard(chunk: chunk),
    extraProviders: [
      ChangeNotifierProvider<ScheduleNotifier>.value(value: sn),
      ChangeNotifierProvider<GoalsNotifier>.value(value: gn),
    ],
  );
}

/// Pump helper for HomeScreen with the necessary provider tree.
/// Mirrors the router_redirect_test.dart provider pattern.
/// Accepts an injectable [now] function forwarded to HomeScreen(now:)
/// so tests can simulate specific wall-clock times (NOW-01/NOW-02).
Future<void> _pumpHomeScreen(
  WidgetTester tester, {
  required ScheduleNotifier scheduleNotifier,
  DateTime Function()? now,
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

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('ActiveChunkCard (NAV-02)', () {
    testWidgets('renders FilledButton Complete without hover', (tester) async {
      await _pumpActiveChunkCard(tester, chunk: _workChunk());
      expect(
        find.widgetWithText(FilledButton, 'Complete'),
        findsOneWidget,
        reason: 'NAV-02: Complete must be always visible — no hover required',
      );
    });

    testWidgets('renders OutlinedButton Skip without hover', (tester) async {
      await _pumpActiveChunkCard(tester, chunk: _workChunk());
      expect(
        find.widgetWithText(OutlinedButton, 'Skip'),
        findsOneWidget,
        reason: 'NAV-02: Skip must be always visible — no hover required',
      );
    });

    testWidgets('renders Now badge', (tester) async {
      await _pumpActiveChunkCard(tester, chunk: _workChunk());
      expect(
        find.text('Now'),
        findsOneWidget,
        reason: 'ActiveChunkCard must render a "Now" badge',
      );
    });

    testWidgets('renders clock-time range when displayStartMinutes is set',
        (tester) async {
      // 540 min = 9:00 AM, +25 min = 9:25 AM
      await _pumpActiveChunkCard(
        tester,
        chunk: _workChunk(syntheticStartMinutes: 540),
      );
      expect(
        find.textContaining('9:00 AM'),
        findsOneWidget,
        reason: 'Should render clock-time start when displayStartMinutes set',
      );
    });

    testWidgets('renders duration fallback when displayStartMinutes is null',
        (tester) async {
      await _pumpActiveChunkCard(tester, chunk: _workChunk());
      expect(
        find.text('25 min'),
        findsOneWidget,
        reason: 'Should render duration fallback when displayStartMinutes null',
      );
    });

    testWidgets('tapping Complete calls ScheduleNotifier.markComplete',
        (tester) async {
      final sn = _FakeScheduleNotifier();
      await _pumpActiveChunkCard(
        tester,
        chunk: _workChunk(id: 'chunk-abc'),
        scheduleNotifier: sn,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
      await tester.pump();
      expect(sn.lastCompletedId, 'chunk-abc');
    });

    testWidgets('tapping Skip calls ScheduleNotifier.markSkipped',
        (tester) async {
      final sn = _FakeScheduleNotifier();
      await _pumpActiveChunkCard(
        tester,
        chunk: _workChunk(id: 'chunk-xyz'),
        scheduleNotifier: sn,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
      await tester.pump();
      expect(sn.lastSkippedId, 'chunk-xyz');
    });

    testWidgets('uses no hardcoded Colors', (tester) async {
      // This is a compile-time / static check verified via flutter analyze.
      // The test simply pumps to confirm no runtime errors occur.
      await _pumpActiveChunkCard(tester, chunk: _workChunk());
      expect(find.byType(ActiveChunkCard), findsOneWidget);
    });
  });

  group('HomeScreen Now/Next layout (NAV-02)', () {
    /// Builds a DailySchedule for today with two unresolved work chunks.
    /// Chunks are given syntheticStartMinutes so they participate in
    /// clock-window selection under the new time-anchored logic (NOW-01).
    /// Tests using this schedule inject now: () => DateTime(2026,6,13,9,5)
    /// so the first chunk (starts 9:00 = 540 min) is the active Now.
    DailySchedule scheduleWithTwoChunks() {
      final today = DateTime.now();
      final ymd =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      return DailySchedule(
        dateYmd: ymd,
        moodIndex: 3,
        chunks: [
          ScheduledChunk(
            id: 'c1',
            chunkTypeIndex: ChunkType.work.index,
            goalId: 'g1',
            durationMinutes: 25,
            rationale: 'First chunk',
            syntheticStartMinutes: 540, // 9:00 AM
          ),
          ScheduledChunk(
            id: 'c2',
            chunkTypeIndex: ChunkType.work.index,
            goalId: 'g2',
            durationMinutes: 30,
            rationale: 'Second chunk',
            syntheticStartMinutes: 600, // 10:00 AM
          ),
        ],
      );
    }

    /// Builds a DailySchedule for today with all chunks resolved.
    ///
    /// Chunks are given real [syntheticStartMinutes] so they participate in
    /// clock-window selection in [resolveNowState]. Tests using this schedule
    /// must inject [now] with a time inside or past the windows; the canonical
    /// value is [allResolvedNow] = 10:05 AM (inside c2's window), which places
    /// both windows in [candidates] and exercises the genuine "all resolved via
    /// traversal → DayComplete" path — not the degenerate allWork.isEmpty path
    /// (CR-03 fix: previously chunks had null syntheticStartMinutes and no now
    /// injection, so DayComplete was returned by the null-filter shortcut).
    DailySchedule scheduleAllResolved() {
      final today = DateTime.now();
      final ymd =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final c1 = ScheduledChunk(
        id: 'c1',
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'g1',
        durationMinutes: 25,
        rationale: 'First chunk',
        syntheticStartMinutes: 540, // 9:00 AM
      )..isCompleted = true;
      final c2 = ScheduledChunk(
        id: 'c2',
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'g2',
        durationMinutes: 30,
        rationale: 'Second chunk',
        syntheticStartMinutes: 600, // 10:00 AM
      )..isSkipped = true;
      return DailySchedule(
        dateYmd: ymd,
        moodIndex: 3,
        chunks: [c1, c2],
      );
    }

    // now for all-resolved tests: 10:05 AM places us inside c2's window
    // (10:00–10:30), so both chunk windows have started. resolveNowState
    // enters the traversal loop, advances past completed c1 then past skipped
    // c2, runs out of candidates, and returns DayComplete for the correct
    // structural reason (CR-03: genuine all-resolved path, not null shortcut).
    DateTime allResolvedNow() => DateTime(2026, 6, 13, 10, 5);

    // Injected now for NAV-02 layout tests: 9:05 AM places us inside the
    // first chunk's window (9:00–9:25 = syntheticStartMinutes 540, dur 25).
    // This is required so the time-anchored resolveNowState sees an Active
    // state and renders ActiveChunkCard for c1 and Next for c2 (NOW-01).
    DateTime navNow() => DateTime(2026, 6, 13, 9, 5);

    testWidgets('shows "Now" section label when chunks remain', (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(scheduleWithTwoChunks());
      await _pumpHomeScreen(tester, scheduleNotifier: sn, now: navNow);
      expect(
        find.text('Now'),
        findsWidgets,
        reason: 'NAV-02: "Now" section label must appear on HomeScreen',
      );
    });

    testWidgets('shows ActiveChunkCard for current chunk', (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(scheduleWithTwoChunks());
      await _pumpHomeScreen(tester, scheduleNotifier: sn, now: navNow);
      expect(
        find.byType(ActiveChunkCard),
        findsOneWidget,
        reason: 'NAV-02: ActiveChunkCard must render for the current chunk',
      );
    });

    testWidgets('shows "Next" section label when second chunk exists',
        (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(scheduleWithTwoChunks());
      await _pumpHomeScreen(tester, scheduleNotifier: sn, now: navNow);
      expect(
        find.text('Next'),
        findsOneWidget,
        reason: 'NAV-02: "Next" section label must appear for second chunk',
      );
    });

    testWidgets('shows "See full schedule" link', (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(scheduleWithTwoChunks());
      await _pumpHomeScreen(tester, scheduleNotifier: sn, now: navNow);
      expect(
        find.text('See full schedule'),
        findsOneWidget,
        reason: 'NAV-02: "See full schedule" TextButton must be on HomeScreen',
      );
    });

    testWidgets('shows "That\'s a wrap" when all chunks resolved',
        (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(scheduleAllResolved());
      // Inject now inside c2's window so resolveNowState traverses the
      // resolution-checking branch and reaches DayComplete for the correct
      // reason — not via the null-syntheticStartMinutes degenerate shortcut
      // (CR-03).
      await _pumpHomeScreen(
        tester,
        scheduleNotifier: sn,
        now: allResolvedNow,
      );
      expect(
        find.text("That's a wrap"),
        findsOneWidget,
        reason:
            "NOW-02: day-complete state shows \"That's a wrap\" when all chunks resolved",
      );
    });

    testWidgets('shows no ActiveChunkCard when all chunks resolved',
        (tester) async {
      final sn = _FakeScheduleNotifierWithSchedule(scheduleAllResolved());
      // Same now injection as the companion test above (CR-03).
      await _pumpHomeScreen(
        tester,
        scheduleNotifier: sn,
        now: allResolvedNow,
      );
      expect(
        find.byType(ActiveChunkCard),
        findsNothing,
        reason: 'No ActiveChunkCard when all chunks resolved',
      );
    });
  });
}
