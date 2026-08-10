// Widget tests for the unified TodayScreen — Phase 22 Plan 03.
//
// Task 1: screen scaffold, reconciled AppBar, and the merged empty state
// that keeps every affordance from both the old Home landing screen and the
// old Schedule plan-view screen.
// Task 2 (added later in this file): the day as a single scrollable list,
// live row placement, named free time.
// Task 3 (added later in this file): centre-on-open + edge-state copy.

import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/dev/dev_clock.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/theme_notifier.dart';
import 'package:canopy/screens/commitments/commitment_form_sheet.dart';
import 'package:canopy/screens/schedule/widgets/chunk_detail_sheet.dart';
import 'package:canopy/screens/today/today_screen.dart';
import 'package:canopy/screens/today/widgets/breathing_pulse_cta.dart';
import 'package:canopy/screens/today/widgets/end_of_day_card.dart';
import 'package:canopy/screens/today/widgets/live_row_card.dart';
import 'package:canopy/screens/today/widgets/now_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

/// Creates a break chunk (short by default) with injectable time/resolution
/// parameters. Same signature/shape as the `_breakChunk` factory in
/// today_screen_now_state_test.dart (LIVE-01, Task 1/3).
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

    testWidgets(
      'the leading "Free until" row precedes the first activity while that '
      'window is still open',
      (tester) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: buildDayFixture(),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => DateTime(2026, 8, 7, 6, 0),
        );

        expect(find.textContaining('Free until 8:00 AM'), findsOneWidget);
      },
    );

    testWidgets(
      'the leading "Free until" row is gone once its window has closed '
      '(NOW-02)',
      (tester) async {
        await pumpDay(tester);

        // At 10:47 with this fixture, c3's 10:45–10:50 window is open, so
        // resolveNowState is Active — the correct marker assertion here is
        // absence, not presence (D-02's Active suppression).
        expect(find.textContaining('Free until 8:00 AM'), findsNothing);
        expect(find.byType(NowMarker), findsNothing);
      },
    );

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

    testWidgets(
      'gutter label shares a left edge with the "Today" heading (G-04)',
      (tester) async {
        await pumpDay(tester);

        // "8:00" is the c1 row's exact gutter text (distinct from "Free
        // until 8:00 AM", which never renders as an exact "8:00" match).
        // TimelineRowTile now owns the row's 16dp horizontal inset, so the
        // gutter text should start at the same x as the header's "Today".
        final gutterDx = tester.getTopLeft(find.text('8:00')).dx;
        final headingDx = tester.getTopLeft(find.text('Today')).dx;
        expect(gutterDx, headingDx);
      },
    );

    testWidgets(
      'the chunk count appears once, in the progress row, not in the mood chip (G-06)',
      (tester) async {
        await pumpDay(tester);

        // buildDayFixture(): 5 work chunks total (c1-c5, the commitment
        // chunk c5 is also ChunkType.work), c1 completed — so the progress
        // row reads "1 of 5 Chunks".
        expect(find.text('1 of 5 Chunks'), findsOneWidget);
        // moodIndex 3 → '⛅' / 'Steady day' — the chip carries no count.
        expect(find.text('⛅ Steady day'), findsOneWidget);
        expect(find.textContaining('5 chunks'), findsNothing);
      },
    );

    testWidgets(
      'the end-of-day card follows the INJECTED clock, not the wall clock '
      '(D-01 regression)',
      (tester) async {
        // Regression guard for a latent D-01 violation found by phase 24's
        // own gate: _shouldShowEodCard used to call shouldShowEodCard WITHOUT
        // forwarding the screen's injected _nowFn, so the card's `hour >= 18`
        // branch read its own DateTime.now. Every widget test that pumped
        // this screen therefore changed behaviour at 6pm local time — the
        // suite was green all morning and red all evening, with no code
        // change in between.
        //
        // This test pins an evening wall-clock scenario the ONLY honest way:
        // by injecting a MORNING time and asserting the card stays hidden.
        // Run before 18:00 it would pass even with the bug present, so it is
        // deliberately paired with the fixture below (<50% resolved) to keep
        // the ratio branch from firing and masking the clock branch.
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(id: 'c1', syntheticStartMinutes: 540),
            _workChunk(id: 'c2', syntheticStartMinutes: 600),
            _workChunk(id: 'c3', syntheticStartMinutes: 660),
          ],
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          // 10:00 — well below the hour >= 18 trigger. 0 of 3 resolved keeps
          // the 50%-ratio branch from firing independently.
          now: () => DateTime(2026, 8, 7, 10, 0),
        );

        expect(find.byType(EndOfDayCard), findsNothing);
        expect(find.textContaining('chunks done'), findsNothing);
      },
    );

    group('Phase 24 — now-marker (NOW-01)', () {
      testWidgets(
        'the marker announces once, not twice — the gutter time is inside '
        'the excluded subtree (24-REVIEW.md WR-01)',
        (tester) async {
          // WR-01 shipped against a fully green 503-test suite because
          // nothing anywhere asserted the marker's Semantics wiring. The
          // Semantics node was passed as TimelineRowTile's `child`, but the
          // tile lays its gutter Text out as a SIBLING of `child`, so
          // excludeSemantics never covered it — a screen reader read the row
          // twice, in two different time formats. 24-UI-SPEC.md introduced
          // this node specifically to give "one clean announcement".
          final handle = tester.ensureSemantics();
          final schedule = DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(syntheticStartMinutes: 480, durationMinutes: 60),
            ],
          );
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
            now: () => DateTime(2026, 8, 7, 6, 0),
          );

          // The merged node the spec asks for.
          expect(find.bySemanticsLabel('Now — 6:00 AM'), findsOneWidget);
          // The gutter's compact rendering must NOT survive as its own
          // semantics node. formatMinutesCompact(360) is exactly '6:00'
          // (no suffix before noon), and the only row with that gutter value
          // is the marker itself — the 8:00 chunk renders '8:00'. With the
          // Semantics wrapper in the wrong place this resolved to a second,
          // separate node and the row was announced twice.
          //
          // Note the visible Text still exists and is still asserted by the
          // 'PreStart shows the marker' test below via find.text('6:00');
          // what must not exist is a SEPARATE semantics node for it.
          expect(find.bySemanticsLabel('6:00'), findsNothing);

          handle.dispose();
        },
      );

      testWidgets('PreStart shows the marker', (tester) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [_workChunk(syntheticStartMinutes: 480, durationMinutes: 60)],
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => DateTime(2026, 8, 7, 6, 0),
        );

        expect(find.byType(NowMarker), findsOneWidget);
        expect(find.text('Now'), findsOneWidget);
        expect(find.text('6:00'), findsOneWidget);
      });

      testWidgets('GapBeforeNext shows the marker', (tester) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'c1',
              syntheticStartMinutes: 540, // 9:00
              durationMinutes: 25,
              isCompleted: true,
              rationale: 'Morning routine',
            ),
            _workChunk(
              id: 'c2',
              syntheticStartMinutes: 600, // 10:00
              durationMinutes: 25,
              rationale: 'Reading',
            ),
          ],
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => DateTime(2026, 8, 7, 9, 30),
        );

        expect(find.byType(NowMarker), findsOneWidget);
        expect(find.text('9:30'), findsOneWidget);
      });

      testWidgets('DayComplete shows the marker, last', (tester) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              syntheticStartMinutes: 480,
              durationMinutes: 60,
              rationale: 'Morning routine',
            ),
          ],
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => DateTime(2026, 8, 7, 18, 0),
        );

        expect(find.byType(NowMarker), findsOneWidget);
        expect(find.text('6:00p'), findsOneWidget);
      });

      testWidgets('Active suppresses the marker', (tester) async {
        // c3's 10:45-10:50 window is open at pumpDay's 10:47, so
        // resolveNowState is Active — "the loud card answers it, so the
        // quiet marker stands down" (D-02).
        await pumpDay(tester);

        expect(find.byType(NowMarker), findsNothing);
        expect(find.byType(LiveRowCard), findsOneWidget);
      });

      testWidgets(
        'Single-sample agreement (D-01): the header and the marker read the '
        'same clock sample',
        (tester) async {
          final schedule = DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'c1',
                syntheticStartMinutes: 540, // 9:00
                durationMinutes: 25,
                isCompleted: true,
                rationale: 'Morning routine',
              ),
              _workChunk(
                id: 'c2',
                syntheticStartMinutes: 600, // 10:00
                durationMinutes: 25,
                rationale: 'Reading',
              ),
            ],
          );
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
            now: () => DateTime(2026, 8, 7, 9, 30),
          );

          expect(find.text('Up next'), findsOneWidget);
          expect(find.text('9:30'), findsOneWidget);
        },
      );
    });
  });

  group('Task 3 — centre the live row on open + edge-state copy', () {
    /// A long day: 10 work chunks 40 minutes apart (8:00 through 13:20),
    /// the first 7 completed, chunk index 7 unresolved (the live one under
    /// a frozen clock 5 minutes into its window), and 2 more unresolved
    /// chunks after it — enough rows to push the live row below the fold
    /// at the default 800x600 test viewport, so centring is observable.
    List<ScheduledChunk> longDayFixture() => [
      for (var i = 0; i < 10; i++)
        _workChunk(
          id: 'chunk-$i',
          syntheticStartMinutes: 480 + i * 40,
          durationMinutes: 25,
          isCompleted: i < 7,
          rationale: 'Chunk $i',
        ),
    ];

    testWidgets('centres the live row on open (offset moves off zero)', (
      tester,
    ) async {
      final schedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: longDayFixture(),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
        now: () => DateTime(2026, 8, 7, 12, 45), // 5 min into chunk 7's window
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.pixels, greaterThan(0));
    });

    testWidgets(
      'centres once — a later 1-minute tick does not move the offset again',
      (tester) async {
        DateTime injectedNow = DateTime(2026, 8, 7, 12, 45);
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: longDayFixture(),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => injectedNow,
        );
        await tester.pumpAndSettle();

        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final offsetAfterFirstSettle = scrollable.position.pixels;
        expect(offsetAfterFirstSettle, greaterThan(0));

        injectedNow = injectedNow.add(const Duration(minutes: 1));
        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();

        expect(scrollable.position.pixels, offsetAfterFirstSettle);
      },
    );

    testWidgets(
      'centres the now-marker on open when there is no live row to centre '
      'on instead (DayComplete overflow, 24-04)',
      (tester) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: longDayFixture(),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          // 18:00 — well past longDayFixture's last chunk (ends 14:25), so
          // resolveNowState returns DayComplete and hasLiveRow is false.
          now: () => DateTime(2026, 8, 7, 18, 0),
        );
        await tester.pumpAndSettle();

        expect(find.byType(NowMarker), findsOneWidget);

        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        // This assertion would have FAILED before the 24-04 fix: hasLiveRow
        // is false for DayComplete, so the old code never scheduled any
        // ensureVisible call at all and the list stayed at pixels == 0.
        expect(scrollable.position.pixels, greaterThan(0));
        // The marker is the very last row buildTimeline emits for
        // DayComplete, so ensureVisible clamps at the bottom — the literal
        // encoding of Dan's "things in the past should have to be scrolled
        // to" (24-03-SUMMARY.md).
        expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
      },
    );

    testWidgets('a debug clock jump re-arms centre-on-open within the same day '
        '(Phase 25 DEV-01 integration)', (tester) async {
      // The one-shots reset only on a dateYmd change. Time-travelling from
      // morning to 9pm on the SAME day leaves dateYmd untouched, so without
      // the DevClock.offset check in build() the list would stay wherever
      // the user left it — making "jump to 9pm and check DayComplete", the
      // exact workflow the Phase 25 harness exists to enable, report a
      // false negative against a fix that works.
      DevClock.resetForTest();
      addTearDown(DevClock.resetForTest);

      final schedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: longDayFixture(),
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
        now: () => DateTime(2026, 8, 7, 18, 0),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);

      // Drag the list away from the marker, as a user reading their
      // morning would. The one-shot has already fired, so nothing should
      // pull it back...
      scrollable.position.jumpTo(0);
      await tester.pump();
      expect(scrollable.position.pixels, 0);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(
        scrollable.position.pixels,
        0,
        reason:
            'a plain minute tick must NOT drag the list back — that is the '
            'T-22-08 behaviour the one-shot exists to protect',
      );

      // ...until the debug clock moves, which re-arms it. The re-arm check
      // lives in build(), so it needs a rebuild to run — in the app that
      // comes from ScheduleNotifier.reloadToday() (Settings calls it after
      // every DevClock mutation) and from the 1-minute ticker. Here the
      // ticker supplies it, which also sharpens the contrast: the identical
      // minute tick that must NOT move the list above MUST move it once the
      // clock has jumped.
      DevClock.setOffsetForTest(const Duration(hours: 3));
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      expect(
        scrollable.position.pixels,
        scrollable.position.maxScrollExtent,
        reason:
            'a DevClock jump must re-centre on the marker, otherwise the '
            'time-travel UAT shows a stale scroll position',
      );
    });

    testWidgets(
      'opening in PreStart then transitioning to Active still centres the '
      'live row (two-flag regression, 24-04)',
      (tester) async {
        DateTime injectedNow = DateTime(2026, 8, 7, 7, 0); // before 8:00
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: longDayFixture(),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => injectedNow,
        );
        await tester.pumpAndSettle();
        // PreStart: no live row, so the marker-fallback fires and sets
        // _didCentreMarker — not _didCentreLiveRow.

        // Deliberately no unmount here (unlike 24-02-PLAN.md's general
        // "prefer one clock, unmount otherwise" guidance): unmounting would
        // destroy and recreate TodayScreenState, resetting both flags to
        // false again, which would make it impossible to observe whether
        // the first flag firing suppresses the second. Keeping the same
        // mounted instance across the clock change is the entire point of
        // this test.
        injectedNow = DateTime(2026, 8, 7, 12, 45); // 5 min into chunk 7
        await tester.pump(const Duration(minutes: 345));
        await tester.pumpAndSettle();

        // Confirms Active was actually reached for chunk index 7 — the
        // state transition genuinely happened, this isn't a no-op.
        expect(find.byType(LiveRowCard), findsOneWidget);

        // Load-bearing assertion: under a design that reused ONE shared
        // flag for both centrings, the marker's earlier fire in the
        // PreStart phase would have consumed that single flag, and the
        // `if (!_didCentreLiveRow && hasLiveRow)` check on the Active
        // transition would then be permanently false for the rest of this
        // schedule's day — the live row would never get centred. This test
        // fails under that design and passes under the two-flag design.
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scrollable.position.pixels, greaterThan(0));
      },
    );

    testWidgets('pre-start: "Nothing until" is present, no LiveRowCard', (
      tester,
    ) async {
      final schedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [_workChunk(syntheticStartMinutes: 480, durationMinutes: 60)],
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
        now: () => DateTime(2026, 8, 7, 6, 0),
      );

      expect(find.text('Nothing until 8:00 AM'), findsOneWidget);
      expect(
        find.text(
          'The day starts with Deep work. Until then the time is yours.',
        ),
        findsOneWidget,
      );
      expect(find.byType(LiveRowCard), findsNothing);
      // The day list is still rendered below — never a bare message.
      expect(find.textContaining('Free until'), findsOneWidget);
    });

    testWidgets('gap-before-next: "Up next" is present, no LiveRowCard', (
      tester,
    ) async {
      final schedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [
          _workChunk(
            id: 'c1',
            syntheticStartMinutes: 540, // 9:00
            durationMinutes: 25,
            isCompleted: true,
            rationale: 'Morning routine',
          ),
          _workChunk(
            id: 'c2',
            syntheticStartMinutes: 600, // 10:00
            durationMinutes: 25,
            rationale: 'Reading',
          ),
        ],
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
        now: () => DateTime(2026, 8, 7, 9, 30),
      );

      expect(find.text('Up next'), findsOneWidget);
      expect(find.byType(LiveRowCard), findsNothing);
      expect(find.text('Morning routine'), findsOneWidget);
    });

    testWidgets('day-complete: "That\'s the day." is present, no LiveRowCard', (
      tester,
    ) async {
      final schedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [
          _workChunk(
            syntheticStartMinutes: 480,
            durationMinutes: 60,
            rationale: 'Morning routine',
          ),
        ],
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
        now: () => DateTime(2026, 8, 7, 18, 0),
      );

      expect(find.text("That's the day."), findsOneWidget);
      expect(find.text('Everything scheduled is behind you.'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.byType(LiveRowCard), findsNothing);
      expect(find.text('Morning routine'), findsOneWidget);
    });

    testWidgets(
      'no floating recall pill — "Jump to now" appears nowhere (D-03)',
      (tester) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: longDayFixture(),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => DateTime(2026, 8, 7, 12, 45),
        );
        await tester.pumpAndSettle();

        expect(find.text('Jump to now'), findsNothing);
      },
    );

    testWidgets(
      'gap-before-next targeting a break names the break, not "Work block"',
      (tester) async {
        final schedule = DailySchedule(
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
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => DateTime(2026, 6, 13, 8, 10),
        );

        expect(find.text('Up next'), findsOneWidget);
        // 'Short break' legitimately renders twice: once in the edge-state
        // line under test, once in b1's own (unresolved, upcoming) row
        // further down the day list — scope to the edge-state line itself.
        final upNextHeader = find
            .ancestor(of: find.text('Up next'), matching: find.byType(Padding))
            .first;
        expect(
          find.descendant(of: upNextHeader, matching: find.text('Short break')),
          findsOneWidget,
        );
        expect(find.text('Work block'), findsNothing);
        expect(find.textContaining('Starts at 8:25 AM'), findsOneWidget);
        expect(find.byType(LiveRowCard), findsNothing);
      },
    );

    testWidgets(
      'edge states are distinct — no state satisfies another state\'s copy',
      (tester) async {
        // PreStart: must not contain the DayComplete string.
        final preStartSchedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [_workChunk(syntheticStartMinutes: 480, durationMinutes: 60)],
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(preStartSchedule),
          now: () => DateTime(2026, 8, 7, 6, 0),
        );
        expect(find.textContaining("That's the day"), findsNothing);

        // Force a full remount — TodayScreenState's `_nowFn` is `late
        // final`, captured once in initState, so re-pumping the same
        // widget subtree in place would silently keep the OLD clock.
        await tester.pumpWidget(const SizedBox.shrink());

        // DayComplete: must not contain the PreStart string.
        final dayCompleteSchedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [_workChunk(syntheticStartMinutes: 480, durationMinutes: 60)],
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(
            dayCompleteSchedule,
          ),
          now: () => DateTime(2026, 8, 7, 18, 0),
        );
        expect(find.textContaining('Nothing until'), findsNothing);
      },
    );

    testWidgets('copywriting guard: "behind" appears only in the DayComplete '
        '"behind you" phrase, never in PreStart or GapBeforeNext', (
      tester,
    ) async {
      // PreStart
      final preStartSchedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [_workChunk(syntheticStartMinutes: 480, durationMinutes: 60)],
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(preStartSchedule),
        now: () => DateTime(2026, 8, 7, 6, 0),
      );
      expect(find.textContaining('behind'), findsNothing);

      // Force a full remount between states — see the distinctness-guard
      // test's comment for why (`_nowFn` is `late final`).
      await tester.pumpWidget(const SizedBox.shrink());

      // GapBeforeNext
      final gapSchedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [
          _workChunk(
            id: 'c1',
            syntheticStartMinutes: 540,
            durationMinutes: 25,
            isCompleted: true,
            rationale: 'Morning routine',
          ),
          _workChunk(
            id: 'c2',
            syntheticStartMinutes: 600,
            durationMinutes: 25,
            rationale: 'Reading',
          ),
        ],
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(gapSchedule),
        now: () => DateTime(2026, 8, 7, 9, 30),
      );
      expect(find.textContaining('behind'), findsNothing);

      // Force a full remount between states — see the distinctness-guard
      // test's comment for why (`_nowFn` is `late final`).
      await tester.pumpWidget(const SizedBox.shrink());

      // DayComplete — "behind you" is the ONLY permitted occurrence.
      final dayCompleteSchedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [_workChunk(syntheticStartMinutes: 480, durationMinutes: 60)],
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(
          dayCompleteSchedule,
        ),
        now: () => DateTime(2026, 8, 7, 18, 0),
      );
      expect(find.textContaining('behind you'), findsOneWidget);
    });
  });

  group('WR-01 — Start focus follows nowState, not a list-order scan', () {
    // Regression fixture for the exact scenario WR-01 (22-REVIEW.md)
    // describes: an EARLIER work chunk (8:00) is left unresolved — the user
    // forgot to mark it complete/skipped — while a LATER chunk's window
    // (10:45) is the one `resolveNowState` currently classifies as Active,
    // which is what the live row visually presents as "now". The old
    // AppBar behavior scanned `chunks.where(!completed && !skipped)
    // .firstOrNull` in list order, which would pick the stale 8:00 chunk.
    // The fix sources the target from `nowState` instead, so it must match
    // the 10:45 chunk the rest of the screen treats as current.
    List<ScheduledChunk> divergentFixture() => [
      _workChunk(
        id: 'stale',
        syntheticStartMinutes: 480, // 8:00, window long closed, unresolved
        durationMinutes: 25,
        rationale: 'Forgotten morning chunk',
      ),
      _workChunk(
        id: 'current',
        syntheticStartMinutes: 645, // 10:45 — Active at 10:47
        durationMinutes: 5,
        rationale: 'Now',
      ),
    ];

    /// Pumps TodayScreen inside a real GoRouter (needed because the AppBar's
    /// focus action calls `context.push`, which requires an ancestor
    /// GoRouter — the plain-MaterialApp `_pumpTodayScreen` helper above
    /// cannot exercise it). The `/focus` route renders the pushed `extra`
    /// as text so the test can assert on it without a NavigatorObserver.
    Future<String?> pumpAndTapFocus(
      WidgetTester tester,
      ScheduleNotifier scheduleNotifier,
      DateTime Function() now,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => TodayScreen(now: now),
          ),
          GoRoute(
            path: '/focus',
            builder: (context, state) => Text('focus-target:${state.extra}'),
          ),
        ],
      );
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
            ChangeNotifierProvider<RestorativesNotifier>.value(
              value: _FakeRestorativesNotifier(),
            ),
          ],
          child: MaterialApp.router(theme: theme, routerConfig: router),
        ),
      );

      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.center_focus_strong_outlined),
      );
      await tester.pumpAndSettle();

      final textFinder = find.textContaining('focus-target:');
      if (textFinder.evaluate().isEmpty) return null;
      return tester.widget<Text>(textFinder).data;
    }

    testWidgets(
      'Start focus pushes the Active chunk from nowState, not the stale '
      'earlier unresolved chunk',
      (tester) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: divergentFixture(),
        );
        final result = await pumpAndTapFocus(
          tester,
          _FakeScheduleNotifierWithSchedule(schedule),
          () => DateTime(2026, 8, 7, 10, 47), // inside the 10:45 window
        );

        expect(result, 'focus-target:current');
      },
    );

    testWidgets(
      'Start focus is disabled when nowState is DayComplete (no meaningful '
      'target to guess at)',
      (tester) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'done',
              syntheticStartMinutes: 480,
              durationMinutes: 60,
              isCompleted: true,
              rationale: 'Morning routine',
            ),
          ],
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => DateTime(2026, 8, 7, 18, 0), // day complete
        );

        final button = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.center_focus_strong_outlined),
        );
        expect(button.onPressed, isNull);
      },
    );

    // ── T-23-01: a break must never become the "Start focus" target ────────

    testWidgets('Start focus is disabled while a break is the Active chunk', (
      tester,
    ) async {
      final schedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [
          _workChunk(id: 'w1', syntheticStartMinutes: 480, durationMinutes: 25),
          _breakChunk(id: 'b1', syntheticStartMinutes: 505, durationMinutes: 5),
        ],
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
        now: () => DateTime(2026, 6, 13, 8, 27),
      );
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.center_focus_strong_outlined),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
      'Start focus is disabled while a break is the GapBeforeNext target',
      (tester) async {
        final schedule = DailySchedule(
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
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => DateTime(2026, 6, 13, 8, 10),
        );
        final button = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.center_focus_strong_outlined),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('Start focus is disabled while a break is Overdue', (
      tester,
    ) async {
      final schedule = DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [
          _breakChunk(id: 'b1', syntheticStartMinutes: 505, durationMinutes: 5),
          _workChunk(id: 'w2', syntheticStartMinutes: 540, durationMinutes: 25),
        ],
      );
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
        now: () => DateTime(2026, 6, 13, 8, 35),
      );
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.center_focus_strong_outlined),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
      'Start focus still targets the Active work chunk when a break follows '
      'it',
      (tester) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(
              id: 'current',
              syntheticStartMinutes: 480,
              durationMinutes: 25,
            ),
            _breakChunk(
              id: 'b1',
              syntheticStartMinutes: 505,
              durationMinutes: 5,
            ),
          ],
        );
        final result = await pumpAndTapFocus(
          tester,
          _FakeScheduleNotifierWithSchedule(schedule),
          () => DateTime(2026, 6, 13, 8, 10),
        );

        expect(result, 'focus-target:current');
      },
    );
  });
}
