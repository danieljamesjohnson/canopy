// Widget tests for the unified TodayScreen — Phase 22 Plan 03.
//
// Task 1: screen scaffold, reconciled AppBar, and the merged empty state
// that keeps every affordance from both HomeScreen and ScheduleScreen.
// Task 2 (added later in this file): the day as a single scrollable list,
// live row placement, named free time.
// Task 3 (added later in this file): centre-on-open + edge-state copy.

import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/theme_notifier.dart';
import 'package:canopy/screens/commitments/commitment_form_sheet.dart';
import 'package:canopy/screens/schedule/widgets/chunk_detail_sheet.dart';
import 'package:canopy/screens/schedule/widgets/now_marker.dart';
import 'package:canopy/screens/today/today_screen.dart';
import 'package:canopy/screens/today/widgets/breathing_pulse_cta.dart';
import 'package:canopy/screens/today/widgets/live_row_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/viewport.dart';

// ─── Fakes (per-file, no shared fakes file — P9) ──────────────────────────

class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}

  @override
  bool get hasScheduleToday => false;
}

/// ScheduleNotifier fake that exposes a pre-built schedule for TodayScreen
/// tests. Mirrors home_screen_now_state_test.dart's
/// _FakeScheduleNotifierWithSchedule.
class _FakeScheduleNotifierWithSchedule extends _FakeScheduleNotifier {
  _FakeScheduleNotifierWithSchedule(this._schedule);
  final DailySchedule _schedule;

  @override
  DailySchedule? get todaySchedule => _schedule;

  @override
  bool get hasScheduleToday => true;

  @override
  int? get moodIndex => _schedule.moodIndex;

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

class _FakeRestorativesNotifier extends RestorativesNotifier {
  @override
  Future<void> loadItems() async {}
}

// ─── Chunk factory ────────────────────────────────────────────────────────

/// Creates a work chunk with injectable time/resolution parameters.
ScheduledChunk _workChunk({
  String id = 'chunk-1',
  int? syntheticStartMinutes,
  int durationMinutes = 25,
  bool isCompleted = false,
  bool isSkipped = false,
  String rationale = 'Deep work',
}) {
  final c = ScheduledChunk(
    id: id,
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'goal-1',
    durationMinutes: durationMinutes,
    rationale: rationale,
    syntheticStartMinutes: syntheticStartMinutes,
  );
  if (isCompleted) c.isCompleted = true;
  if (isSkipped) c.isSkipped = true;
  return c;
}

/// Creates a commitment-anchored work chunk (goalId == null, commitmentId
/// set) with an anchored (not synthetic) start time.
ScheduledChunk _commitmentChunk({
  String id = 'commit-1',
  required int anchoredStartMinutes,
  int durationMinutes = 60,
  String rationale = 'Job',
}) {
  return ScheduledChunk(
    id: id,
    chunkTypeIndex: ChunkType.work.index,
    commitmentId: 'block-1',
    durationMinutes: durationMinutes,
    rationale: rationale,
    anchoredStartMinutes: anchoredStartMinutes,
  );
}

String _todayYmd() {
  final today = DateTime.now();
  return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
}

// ─── Pump helper ────────────────────────────────────────────────────────────

Future<void> _pumpTodayScreen(
  WidgetTester tester, {
  required ScheduleNotifier scheduleNotifier,
  DateTime Function()? now,
  RestorativesNotifier? restorativesNotifier,
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
          value: restorativesNotifier ?? _FakeRestorativesNotifier(),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        home: TodayScreen(now: now),
      ),
    ),
  );
}

void main() {
  group('Task 1 — scaffold, AppBar, reconciled empty state', () {
    testWidgets(
      'empty state renders without throwing when there is no schedule',
      (tester) async {
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifier(),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('empty state keeps every affordance from both old screens', (
      tester,
    ) async {
      await _pumpTodayScreen(tester, scheduleNotifier: _FakeScheduleNotifier());

      expect(
        find.byType(BreathingPulseCta),
        findsOneWidget,
        reason: 'the breathing-pulse Start-your-day CTA from Home must survive',
      );
      expect(find.text('Start your day'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Add an event'),
        findsOneWidget,
        reason: 'Add-an-event from Schedule must survive',
      );
      expect(find.text('Plan your day in 30 seconds.'), findsOneWidget);
    });

    testWidgets('tapping Add an event from the empty state opens a modal', (
      tester,
    ) async {
      await _pumpTodayScreen(tester, scheduleNotifier: _FakeScheduleNotifier());

      await tester.tap(find.widgetWithText(TextButton, 'Add an event'));
      await tester.pump();

      expect(find.byType(CommitmentFormSheet), findsOneWidget);
    });

    testWidgets('at 1024x768 the content is constrained to 720dp (POLISH-01)', (
      tester,
    ) async {
      setViewport(tester, const Size(1024, 768));
      await _pumpTodayScreen(tester, scheduleNotifier: _FakeScheduleNotifier());

      final boxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      expect(boxes.any((b) => b.constraints.maxWidth == 720.0), isTrue);
    });

    testWidgets(
      'AppBar exposes add-event, re-check-in, start-focus and exactly one refresh icon',
      (tester) async {
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifier(),
        );

        expect(find.widgetWithIcon(IconButton, Icons.add), findsOneWidget);
        expect(
          find.widgetWithIcon(IconButton, Icons.refresh),
          findsOneWidget,
          reason: 'exactly one refresh action, not two',
        );
        expect(
          find.widgetWithIcon(IconButton, Icons.center_focus_strong_outlined),
          findsOneWidget,
        );
      },
    );

    testWidgets('accepts an injectable now clock function', (tester) async {
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(
          DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [_workChunk(syntheticStartMinutes: 480)],
          ),
        ),
        now: () => DateTime(2026, 8, 7, 9, 0),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Task 2 — the day as one list, live row in place, named free time', () {
    // Fixture: 8:00 completed (25m), 9:00 skipped (25m), 10:45 live work
    // chunk (5m — short like a break, but a WORK chunk so resolveNowState
    // can classify it as Active without widening the work-only filter;
    // widening that filter to real breaks is Phase 23 / LIVE-01), 10:50
    // unresolved work chunk (25m, ends 11:15), and a 13:00 commitment chunk
    // (60m) — leaving a >10min gap from 11:15 to 13:00.
    List<ScheduledChunk> buildDayFixture() => [
      _workChunk(
        id: 'c1',
        syntheticStartMinutes: 480, // 8:00
        durationMinutes: 25,
        isCompleted: true,
        rationale: 'Morning routine',
      ),
      _workChunk(
        id: 'c2',
        syntheticStartMinutes: 540, // 9:00
        durationMinutes: 25,
        isSkipped: true,
        rationale: 'Side project',
      ),
      _workChunk(
        id: 'c3',
        syntheticStartMinutes: 645, // 10:45
        durationMinutes: 5,
        rationale: 'Taking a break',
      ),
      _workChunk(
        id: 'c4',
        syntheticStartMinutes: 650, // 10:50
        durationMinutes: 25,
        rationale: 'Reading',
      ),
      _commitmentChunk(
        id: 'c5',
        anchoredStartMinutes: 780, // 13:00
        durationMinutes: 60,
        rationale: 'Job',
      ),
    ];

    Future<void> pumpDay(
      WidgetTester tester, {
      RestorativesNotifier? restorativesNotifier,
      int moodIndex = 3,
    }) async {
      final schedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: moodIndex,
        chunks: buildDayFixture(),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
        now: () => DateTime(2026, 8, 7, 10, 47), // inside the 10:45 window
        restorativesNotifier: restorativesNotifier,
      );
    }

    testWidgets('exactly one LiveRowCard, for the 10:45 chunk', (tester) async {
      await pumpDay(tester);

      expect(find.byType(LiveRowCard), findsOneWidget);
      final liveCard = tester.widget<LiveRowCard>(find.byType(LiveRowCard));
      expect(liveCard.chunkId, 'c3');
    });

    testWidgets('completed and skipped chunks still render as rows, inline, no '
        '"Skipped today" text', (tester) async {
      await pumpDay(tester);

      expect(find.textContaining('Morning routine'), findsOneWidget);
      expect(find.textContaining('Side project'), findsOneWidget);
      expect(find.textContaining('Skipped today'), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
    });

    testWidgets('"Free until 8:00 AM" precedes the first activity', (
      tester,
    ) async {
      await pumpDay(tester);

      expect(find.textContaining('Free until 8:00 AM'), findsOneWidget);
    });

    testWidgets('a named "Free ·" row appears for the 11:15–13:00 gap', (
      tester,
    ) async {
      await pumpDay(tester);

      // The fixture also has two shorter mid-morning gaps (8:25–9:00,
      // 9:25–10:45) — all >= kMinGapMinutes, so all three surface as named
      // rows (D-05); this assertion pins the specific 11:15–13:00 one.
      expect(find.text('Free · 1h 45m'), findsOneWidget);
    });

    testWidgets('the gutter shows the compact start time for timed rows', (
      tester,
    ) async {
      await pumpDay(tester);

      expect(find.textContaining('8:00'), findsWidgets);
      expect(find.textContaining('1:00p'), findsOneWidget);
    });

    testWidgets('no NowMarker widget is in the tree', (tester) async {
      await pumpDay(tester);

      expect(find.byType(NowMarker), findsNothing);
    });

    testWidgets('"See full schedule" appears nowhere (D-08 / G4)', (
      tester,
    ) async {
      await pumpDay(tester);

      expect(find.text('See full schedule'), findsNothing);
    });

    testWidgets('a mood-2 schedule renders the restoratives card', (
      tester,
    ) async {
      await pumpDay(tester, moodIndex: 2);

      expect(find.text('Low on energy today?'), findsOneWidget);
    });

    testWidgets('a mood-4 schedule does not render the restoratives card', (
      tester,
    ) async {
      await pumpDay(tester, moodIndex: 4);

      expect(find.text('Low on energy today?'), findsNothing);
    });

    testWidgets('work chunks more than half resolved expose "View your day"', (
      tester,
    ) async {
      final schedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [
          _workChunk(id: 'a', syntheticStartMinutes: 480, isCompleted: true),
          _workChunk(id: 'b', syntheticStartMinutes: 540),
        ],
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
        now: () => DateTime(2026, 8, 7, 10, 0),
      );

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets(
      'work chunks below half resolved do NOT expose "View your day"',
      (tester) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(id: 'a', syntheticStartMinutes: 480, isCompleted: true),
            _workChunk(id: 'b', syntheticStartMinutes: 540),
            _workChunk(id: 'c', syntheticStartMinutes: 600),
            _workChunk(id: 'd', syntheticStartMinutes: 660),
          ],
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => DateTime(2026, 8, 7, 9, 0),
        );

        expect(find.byType(PopupMenuButton<String>), findsNothing);
      },
    );

    testWidgets(
      'tapping an unresolved non-live work row opens ChunkDetailSheet',
      (tester) async {
        await pumpDay(tester);

        // Exact match: 'Reading' is also a substring of the live row's
        // "Next · Reading at 10:50 AM" line, so a containing-text finder
        // would be ambiguous. Scroll it into view first — the default test
        // viewport is shorter than the whole day's row list.
        await tester.ensureVisible(find.text('Reading'));
        await tester.tap(find.text('Reading'));
        await tester.pump();

        expect(find.byType(ChunkDetailSheet), findsOneWidget);
      },
    );
  });
}
