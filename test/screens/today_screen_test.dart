// Widget tests for the unified TodayScreen — Phase 22 Plan 03.
//
// Task 1: screen scaffold, reconciled AppBar, and the merged empty state
// that keeps every affordance from both the old Home landing screen and the
// old Schedule plan-view screen.
// Task 2 (added later in this file): the day as a single scrollable list,
// live row placement, named free time.
// Task 3 (added later in this file): scroll-on-open + edge-state copy.
// Phase 26 (26-05-PLAN.md) added a nested 'CAL-03 elapsed time recedes'
// group inside Task 3, replacing Phase 24's two-flag centre-on-open tests
// with assertions against the new one-flag arithmetic animateTo path.

import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/dev/dev_clock.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/theme_notifier.dart';
import 'package:canopy/screens/commitments/commitment_form_sheet.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:canopy/screens/schedule/widgets/chunk_detail_sheet.dart';
import 'package:canopy/screens/today/timeline_geometry.dart';
import 'package:canopy/screens/today/today_screen.dart';
import 'package:canopy/screens/today/widgets/breathing_pulse_cta.dart';
import 'package:canopy/screens/today/widgets/end_of_day_card.dart';
import 'package:canopy/screens/today/widgets/hour_axis.dart';
import 'package:canopy/screens/today/widgets/live_row_card.dart';
import 'package:canopy/screens/today/widgets/now_line.dart';
import 'package:canopy/screens/today/widgets/timeline_row_tile.dart';
import 'package:canopy/utils/time_format.dart';
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
        // resolveNowState is Active.
        expect(find.textContaining('Free until 8:00 AM'), findsNothing);
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
      'gutter column shares a left edge with the "Today" heading (G-04)',
      (tester) async {
        await pumpDay(tester);

        // Phase 26 (PD-5): the gutter no longer renders per-row text, but
        // it still reserves a kGutterWidth-wide column — TimelineRowTile
        // owns the row's 16dp horizontal inset, so that reserved column
        // should still start at the same x as the header's "Today".
        final gutterColumn = find
            .byWidgetPredicate(
              (widget) => widget is SizedBox && widget.width == kGutterWidth,
            )
            .first;
        final gutterDx = tester.getTopLeft(gutterColumn).dx;
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

    group('Phase 26 — CAL-01 the day has a shape', () {
      // Reuses buildDayFixture() (the group's own fixture, above) at 18:00
      // — past every chunk, DayComplete — rather than pumpDay's 10:47, so
      // nothing is live and every slot height is duration-exact with no
      // liveExtraPx shift muddying the arithmetic these assertions check.
      Future<void> pumpDayComplete(WidgetTester tester) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: buildDayFixture(),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => DateTime(2026, 8, 7, 18, 0),
        );
      }

      testWidgets(
        'a 25-minute work chunk slot measures exactly 137.5px tall',
        (tester) async {
          await pumpDayComplete(tester);

          // c4: 10:50-11:15, 25 minutes, renders as "Reading".
          final c4ClipRect = find
              .ancestor(
                of: find.text('Reading'),
                matching: find.byType(ClipRect),
              )
              .first;
          expect(tester.getSize(c4ClipRect).height, 137.5);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'a 105-minute gap renders as a 577.5px GapFreeRow — not compressed, '
        'not clamped (D-02)',
        (tester) async {
          await pumpDayComplete(tester);

          // The 11:15-13:00 gap between c4 and c5 is 105 minutes.
          final gapTile = find
              .ancestor(
                of: find.text('Free · 1h 45m'),
                matching: find.byType(TimelineRowTile),
              )
              .first;
          expect(tester.getSize(gapTile).height, 577.5);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'two clock-contiguous chunks: the second slot top equals the first '
        'slot top plus the first slot height',
        (tester) async {
          await pumpDayComplete(tester);

          // c3 (10:45-10:50, "Taking a break") and c4 (10:50-11:15,
          // "Reading") are clock-contiguous. At DayComplete c3 is a normal
          // Compact-tier row (not the live row), so its slot participates
          // in this offset comparison.
          final c3ClipRect = find
              .ancestor(
                of: find.text('Taking a break'),
                matching: find.byType(ClipRect),
              )
              .first;
          final c4ClipRect = find
              .ancestor(
                of: find.text('Reading'),
                matching: find.byType(ClipRect),
              )
              .first;
          final c3Top = tester.getTopLeft(c3ClipRect).dy;
          final c4Top = tester.getTopLeft(c4ClipRect).dy;
          final c3Height = tester.getSize(c3ClipRect).height;

          expect(c4Top, c3Top + c3Height);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        "the timeline Stack's SizedBox height equals (rangeEnd - rangeStart) "
        '* kPixelsPerMinute when no live row is swelling it',
        (tester) async {
          await pumpDayComplete(tester);

          // firstStart 8:00 (480), lastEnd 14:00 (840), now 18:00 (1080) —
          // rangeStart = floorToHour(480) = 480, rangeEnd =
          // ceilToHour(1080) = 1080, both already hour-aligned, so this is
          // a clean check with no liveExtraPx term to account for.
          final expectedTotalHeight = (1080 - 480) * kPixelsPerMinute;
          final sizedBoxes = tester.widgetList<SizedBox>(
            find.byType(SizedBox),
          );
          expect(
            sizedBoxes.any((box) => box.height == expectedTotalHeight),
            isTrue,
            reason: 'Expected a SizedBox of height $expectedTotalHeight',
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'the live row renders taller than its duration-implied slot, '
        'capped at kLiveRowReservedHeight',
        (tester) async {
          await pumpDay(tester); // 10:47 — c3 (10:45-10:50, 5min) is live

          final liveSize = tester.getSize(find.byType(LiveRowCard));
          expect(liveSize.height, greaterThan(5 * kPixelsPerMinute));
          expect(liveSize.height, lessThanOrEqualTo(kLiveRowReservedHeight));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'a 5-minute short break slot measures exactly 27.5px tall',
        (tester) async {
          final schedule = DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 480, // 8:00
                durationMinutes: 25,
                isCompleted: true,
              ),
              _breakChunk(
                id: 'b1',
                syntheticStartMinutes: 505, // 8:25
                durationMinutes: 5,
              ),
              _workChunk(
                id: 'w2',
                syntheticStartMinutes: 510, // 8:30
                durationMinutes: 25,
              ),
            ],
          );
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
            now: () => DateTime(2026, 8, 7, 18, 0), // DayComplete
          );

          final breakClipRect = find
              .ancestor(
                of: find.text('Short break'),
                matching: find.byType(ClipRect),
              )
              .first;
          expect(tester.getSize(breakClipRect).height, 27.5);
          expect(tester.takeException(), isNull);
        },
      );
    });

    group('Phase 26 — CAL-02 the now-line', () {
      // Dedicated fixture, deliberately NOT buildDayFixture() above: two
      // unresolved 25-minute work chunks (9:00-9:25, 10:00-10:25) hit every
      // NowState cleanly by clock alone, and match this task's own worked
      // example verbatim (a 25-minute chunk starting at 9:00, clock 9:12).
      // [firstResolved]/[secondResolved] let a caller reach GapBeforeNext
      // without a third chunk.
      List<ScheduledChunk> twoChunkFixture({
        bool firstResolved = false,
        bool secondResolved = false,
      }) => [
        _workChunk(
          id: 'w1',
          syntheticStartMinutes: 540, // 9:00
          durationMinutes: 25,
          isCompleted: firstResolved,
          rationale: 'Deep work',
        ),
        _workChunk(
          id: 'w2',
          syntheticStartMinutes: 600, // 10:00
          durationMinutes: 25,
          isCompleted: secondResolved,
          rationale: 'Reading',
        ),
      ];

      Future<void> pumpAt(
        WidgetTester tester,
        DateTime clock, {
        List<ScheduledChunk>? chunks,
        ScheduleNotifier? scheduleNotifier,
      }) async {
        final schedule = DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: chunks ?? twoChunkFixture(),
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier:
              scheduleNotifier ?? _FakeScheduleNotifierWithSchedule(schedule),
          now: () => clock,
        );
      }

      testWidgets(
        'no suppression — exactly one NowLineOverlay in every NowState '
        '(the Active row is the one that used to assert findsNothing)',
        (tester) async {
          // Table-driven (26-04-PLAN.md task 2, item 1) so a future added
          // NowState is obviously missing from this list.
          final table = <String, (DateTime, List<ScheduledChunk>)>{
            'PreStart': (DateTime(2026, 8, 7, 8, 0), twoChunkFixture()),
            'Active (mid-chunk)': (
              DateTime(2026, 8, 7, 9, 12),
              twoChunkFixture(),
            ),
            'Overdue': (DateTime(2026, 8, 7, 9, 30), twoChunkFixture()),
            'GapBeforeNext': (
              DateTime(2026, 8, 7, 9, 30),
              twoChunkFixture(firstResolved: true),
            ),
            'DayComplete': (DateTime(2026, 8, 7, 11, 0), twoChunkFixture()),
          };

          for (final entry in table.entries) {
            final (clock, chunks) = entry.value;
            await pumpAt(tester, clock, chunks: chunks);
            expect(
              find.byType(NowLineOverlay),
              findsOneWidget,
              reason: '${entry.key}: the now-line must render unconditionally',
            );
            expect(tester.takeException(), isNull);
            // Full unmount before the next clock — _nowFn is late final,
            // set once in initState; without this the next clock's closure
            // is silently ignored and the assertion would re-check the
            // FIRST clock's state while appearing to pass (Pitfall 8,
            // bit the codebase once already in 23-03).
            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );

      testWidgets(
        "mid-chunk truth — the line sits at TimelineGeometry's own "
        "computed offset, strictly inside the live chunk's rendered span",
        (tester) async {
          await pumpAt(tester, DateTime(2026, 8, 7, 9, 12));

          // Recomputed from the fixture's own numbers, never a hard-coded
          // pixel constant — mirrors the CAL-01 group's own discipline.
          final geometry = TimelineGeometry.forDay(
            nowMinutes: 552, // 9:12
            firstStartMinutes: 540, // w1 starts 9:00
            lastEndMinutes: 625, // w2 ends 10:25
            liveStartMinutes: 540,
            liveEndMinutes: 565, // w1 ends 9:25
          );

          final liveRowTop = tester.getTopLeft(find.byType(LiveRowCard)).dy;
          final liveRowBottom =
              liveRowTop + tester.getSize(find.byType(LiveRowCard)).height;
          final lineTop = tester.getTopLeft(find.byType(NowLineOverlay)).dy;

          // The live row starts exactly at the Stack's own top here
          // (rangeStart == firstStartMinutes == liveStartMinutes == 540),
          // so liveRowTop doubles as the Stack's top in the same global
          // coordinate frame — the delta below is directly comparable to
          // geometry's own arithmetic.
          expect(
            lineTop - liveRowTop,
            geometry.yFor(552) - kNowLineHeight / 2 - geometry.yFor(540),
          );
          expect(lineTop, greaterThan(liveRowTop));
          expect(lineTop, lessThan(liveRowBottom));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'motion — a one-minute tick advances the line by exactly '
        'kPixelsPerMinute',
        (tester) async {
          await pumpAt(tester, DateTime(2026, 8, 7, 9, 12));
          final lineTopAt912 = tester.getTopLeft(find.byType(NowLineOverlay)).dy;

          // Full unmount between clocks (Pitfall 8) — see the no-suppression
          // test's comment above for why this is load-bearing, not optional.
          await tester.pumpWidget(const SizedBox.shrink());

          await pumpAt(tester, DateTime(2026, 8, 7, 9, 13));
          final lineTopAt913 = tester.getTopLeft(find.byType(NowLineOverlay)).dy;

          expect(lineTopAt913 - lineTopAt912, kPixelsPerMinute);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'PreStart is representable — the line never renders above the top '
        'of the rendered range',
        (tester) async {
          await pumpAt(tester, DateTime(2026, 8, 7, 8, 0)); // before 9:00

          final geometry = TimelineGeometry.forDay(
            nowMinutes: 480,
            firstStartMinutes: 540,
            lastEndMinutes: 625,
          );

          expect(geometry.yFor(480), greaterThanOrEqualTo(0));
          expect(geometry.yFor(480), lessThanOrEqualTo(geometry.yFor(540)));
          expect(find.byType(NowLineOverlay), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'DayComplete is representable — the line never renders below the '
        'bottom of the rendered range',
        (tester) async {
          await pumpAt(tester, DateTime(2026, 8, 7, 11, 0)); // after 10:25

          final geometry = TimelineGeometry.forDay(
            nowMinutes: 660,
            firstStartMinutes: 540,
            lastEndMinutes: 625,
          );

          expect(geometry.yFor(660), lessThanOrEqualTo(geometry.totalHeight));
          expect(geometry.yFor(660), greaterThanOrEqualTo(geometry.yFor(625)));
          expect(find.byType(NowLineOverlay), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      // G-01 (26-UAT.md, fixed 26-07-PLAN.md): the chip's copy is
      // formatMinutesCompact, not the longer "Now · <time>" string that
      // could not fit kGutterWidth and shipped the occlusion bug. The full
      // time survives in the screen-reader semantics label, asserted below.
      //
      // G-03 (26-09-PLAN.md) moved this test's clock off 9:12 — at 9:12 w1
      // is live by this fixture's own construction, and the chip is now
      // suppressed there (see the G-03 test below). This test's job is
      // "the chip renders correctly when it renders at all", so it uses a
      // non-live moment instead: 9:30 with w1 already completed puts the
      // day in GapBeforeNext (w2's 10:00 window hasn't opened yet), so
      // there is no live row and the chip is expected to show.
      testWidgets('chip copy — renders exactly "9:30" in a non-live state', (
        tester,
      ) async {
        await pumpAt(
          tester,
          DateTime(2026, 8, 7, 9, 30),
          chunks: twoChunkFixture(firstResolved: true),
        );

        expect(find.byType(LiveRowCard), findsNothing);
        expect(find.text('9:30'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'G-01: the now chip stays inside the time gutter and never '
        'overlaps a (non-live) ChunkCard',
        (tester) async {
          // Geometric assertion (26-VALIDATION.md) — a comparison of two
          // laid-out rects' x-coordinates, not a text-fit measurement, so
          // it is trustworthy in the widget-test harness's placeholder
          // font.
          //
          // G-03 (26-09-PLAN.md): this fixture is deliberately a non-live
          // moment (9:30, w1 already completed — GapBeforeNext, no
          // LiveRowCard at all) so the chip renders and this test can keep
          // proving the ORIGINAL G-01 claim — gutter confinement against an
          // ordinary ChunkCard. The live-row case (where the chip must be
          // ABSENT, not merely confined) is the separate G-03 test below;
          // LiveRowCard is named there, closing the exact gap 26-07's
          // ChunkCard-only assertion left open.
          await pumpAt(
            tester,
            DateTime(2026, 8, 7, 9, 30),
            chunks: twoChunkFixture(firstResolved: true),
          );

          final chipRect = tester.getRect(
            find.descendant(
              of: find.byType(NowLineOverlay),
              matching: find.byWidgetPredicate(
                (widget) => widget is SizedBox && widget.width == kGutterWidth,
              ),
            ),
          );
          final cardRect = tester.getRect(find.byType(ChunkCard).first);

          expect(chipRect.right, lessThanOrEqualTo(cardRect.left));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'G-03: no time chip over the live row — the full-bleed card '
        'leaves no gutter',
        (tester) async {
          // Work chunk (not break) live, clock mid-chunk — the tall
          // variant with the Complete/Skip action row, per the plan's own
          // instruction: the break variant is shorter and its extra
          // headroom is exactly what masked this defect through two prior
          // rounds of checking (26-UAT.md G-03).
          await pumpAt(tester, DateTime(2026, 8, 7, 9, 12));

          // The live row is genuinely present and is the WORK variant —
          // otherwise this test would prove nothing.
          expect(find.byType(LiveRowCard), findsOneWidget);

          // No chip: no Text descendant of the overlay at all.
          expect(
            find.descendant(
              of: find.byType(NowLineOverlay),
              matching: find.byType(Text),
            ),
            findsNothing,
          );

          // The rule survives — a future "fix" cannot satisfy this test by
          // deleting the whole overlay, only the chip. Exactly one coloured
          // Container remains (the rule); with the chip's own Container
          // gone too, "the rule is still there" and "the chip really is
          // gone" are both provable from the same finder.
          expect(
            find.descendant(
              of: find.byType(NowLineOverlay),
              matching: find.byWidgetPredicate(
                (widget) => widget is Container && widget.color != null,
              ),
            ),
            findsOneWidget,
          );

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'semantics — exactly one "Now — 9:12 AM" node; the chip\'s own '
        'visible text is excluded from the tree',
        (tester) async {
          final handle = tester.ensureSemantics();
          await pumpAt(tester, DateTime(2026, 8, 7, 9, 12));

          expect(
            find.bySemanticsLabel(RegExp(r'^Now — 9:12 AM$')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          handle.dispose();
        },
      );

      testWidgets(
        'hit-testing — a Complete tap still lands through the now-line '
        '(IgnorePointer proof)',
        (tester) async {
          final schedule = DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: twoChunkFixture(),
          );
          final fakeNotifier = _FakeScheduleNotifierWithSchedule(schedule);
          // 9:12 — mid w1's window. The now-line necessarily crosses w1's
          // own (live) card here: nowMinutes inside an unresolved chunk's
          // window makes that chunk Active by construction
          // (resolveNowState), so there is no fixture that puts the line
          // over a genuinely non-live unresolved ChunkCard's Complete
          // button — the live row IS the unresolved work chunk's card the
          // line is guaranteed to cross.
          await pumpAt(
            tester,
            DateTime(2026, 8, 7, 9, 12),
            scheduleNotifier: fakeNotifier,
          );

          // Confirm the line genuinely overlaps the card first — otherwise
          // this test would prove nothing (task 2's own instruction).
          final lineTop = tester.getTopLeft(find.byType(NowLineOverlay)).dy;
          final cardRect = tester.getRect(find.byType(LiveRowCard));
          expect(lineTop, greaterThanOrEqualTo(cardRect.top));
          expect(lineTop, lessThanOrEqualTo(cardRect.bottom));

          // Scoped to the live row specifically: w2 (unresolved, Full-tier,
          // non-live) also renders its own Complete button in its own
          // ChunkCard further down the day — an unscoped finder would match
          // both.
          final completeButton = find.descendant(
            of: find.byType(LiveRowCard),
            matching: find.widgetWithText(FilledButton, 'Complete'),
          );
          await tester.ensureVisible(completeButton);
          await tester.tap(completeButton);
          await tester.pump();

          expect(fakeNotifier.lastCompletedId, 'w1');
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'colour — the now-line rule uses colorScheme.primary and the hour '
        'hairline uses colorScheme.outlineVariant',
        (tester) async {
          await pumpAt(tester, DateTime(2026, 8, 7, 9, 12));

          final scheme = Theme.of(
            tester.element(find.byType(NowLineOverlay).first),
          ).colorScheme;

          final ruleContainer = tester.widget<Container>(
            find
                .descendant(
                  of: find.byType(NowLineOverlay).first,
                  matching: find.byWidgetPredicate(
                    (widget) => widget is Container && widget.color != null,
                  ),
                )
                .first,
          );
          expect(ruleContainer.color, scheme.primary);

          final hairlineContainer = tester.widget<Container>(
            find
                .descendant(
                  of: find.byType(HourAxisLine).first,
                  matching: find.byWidgetPredicate(
                    (widget) => widget is Container && widget.color != null,
                  ),
                )
                .first,
          );
          expect(hairlineContainer.color, scheme.outlineVariant);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'hour axis coverage — one HourAxisLine per hour boundary, first '
        'labelled from rangeStart',
        (tester) async {
          await pumpAt(tester, DateTime(2026, 8, 7, 9, 12));

          final geometry = TimelineGeometry.forDay(
            nowMinutes: 552,
            firstStartMinutes: 540,
            lastEndMinutes: 625,
            liveStartMinutes: 540,
            liveEndMinutes: 565,
          );

          expect(
            find.byType(HourAxisLine),
            findsNWidgets(geometry.hourBoundaries.length),
          );
          final firstAxisLine = tester.widget<HourAxisLine>(
            find.byType(HourAxisLine).first,
          );
          expect(firstAxisLine.hourMinutes, geometry.rangeStart);
          expect(find.text(formatHourLabel(geometry.rangeStart)), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    });
  });

  group('Task 3 — scroll-on-open + edge-state copy', () {
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

    group('Phase 26 — CAL-03 elapsed time recedes', () {
      // Restore any DevClock offset a test in this group sets, so it can
      // never leak into a neighbouring test (the field is a static, shared
      // across every test in the file).
      tearDown(DevClock.resetForTest);

      testWidgets(
        'centres on open in every NowState, including DayComplete '
        '(closes the Phase 24 UAT gap by construction)',
        (tester) async {
          // Table-driven (mirrors the CAL-01/CAL-02 groups' own
          // convention) so a future added NowState is obviously missing
          // from this list. Every clock below is reached on the SAME
          // longDayFixture() — no per-row resolution changes needed,
          // since resolveNowState's classification is clock-driven alone
          // for this fixture's fully-fixed completion pattern.
          //
          // expectPositive is false ONLY for PreStart: nowMinutes ==
          // rangeStart by construction there (the rendered range starts
          // AT "now" when now precedes the first chunk), so the clamped
          // target is exactly 0 — there is nothing before "now" to
          // scroll past yet, which is the correct, not a degenerate,
          // outcome.
          final table = <String, (DateTime, bool expectPositive)>{
            'PreStart': (DateTime(2026, 8, 7, 7, 0), false),
            'Active': (DateTime(2026, 8, 7, 12, 45), true),
            'Overdue': (DateTime(2026, 8, 7, 13, 10), true),
            'GapBeforeNext': (DateTime(2026, 8, 7, 12, 30), true),
            // The exact state Dan's Phase 24 UAT found un-scrolled — this
            // row is the literal regression guard, not a formality.
            'DayComplete': (DateTime(2026, 8, 7, 14, 30), true),
          };

          for (final entry in table.entries) {
            final (clock, expectPositive) = entry.value;
            final schedule = DailySchedule(
              dateYmd: _todayYmd(),
              moodIndex: 3,
              chunks: longDayFixture(),
            );
            await _pumpTodayScreen(
              tester,
              scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
              now: () => clock,
            );
            await tester.pumpAndSettle();

            final scrollable = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );
            if (expectPositive) {
              expect(
                scrollable.position.pixels,
                greaterThan(0),
                reason: '${entry.key}: the computed target is > 0 here, so '
                    'the settled offset must be too',
              );
            } else {
              expect(
                scrollable.position.pixels,
                0.0,
                reason: '${entry.key}: now IS the top of the rendered '
                    'range here, so the clamped target is legitimately 0',
              );
            }
            expect(tester.takeException(), isNull);

            // Full unmount before the next clock (Pitfall 8) — _nowFn is
            // late final, set once in initState.
            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );

      testWidgets('the target is the clamped centred-on-now value', (
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
          now: () => DateTime(2026, 8, 7, 12, 45), // 5 min into chunk 7
        );
        await tester.pumpAndSettle();

        // Recomputed from the fixture's own numbers, never a hard-coded
        // pixel constant — mirrors the CAL-01/CAL-02 groups' discipline.
        final geometry = TimelineGeometry.forDay(
          nowMinutes: 765, // 12:45
          firstStartMinutes: 480, // chunk-0 starts 8:00
          lastEndMinutes: 865, // chunk-9 ends 14:25
          liveStartMinutes: 760, // chunk-7 starts 12:40
          liveEndMinutes: 785, // chunk-7 ends 13:05
        );

        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final viewportHeight = scrollable.position.viewportDimension;
        // stackTop == 0: a mood-3 fixture renders no restoratives card, so
        // the timeline Stack is the scroll content's very first child.
        const stackTop = 0.0;
        final raw = stackTop + geometry.yFor(765) - viewportHeight / 2;
        final expectedTarget = raw.clamp(
          0.0,
          scrollable.position.maxScrollExtent,
        );

        expect(scrollable.position.pixels, closeTo(expectedTarget, 0.5));
      });

      testWidgets(
        'the past is off-screen — the 8am chunk is not visible without '
        'scrolling up',
        (tester) async {
          final schedule = DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: longDayFixture(),
          );
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
            now: () => DateTime(2026, 8, 7, 12, 45), // Active, mid-afternoon
          );
          await tester.pumpAndSettle();

          // CAL-03's literal statement, not just "we scrolled a bit": the
          // day starts at 8am, but at 12:45 chunk-0's row is scrolled
          // above the viewport's own top edge.
          final viewportTop = tester
              .getTopLeft(find.byType(Scrollable).first)
              .dy;
          final firstChunkTop = tester.getTopLeft(find.text('Chunk 0')).dy;
          expect(firstChunkTop, lessThan(viewportTop));
        },
      );

      testWidgets(
        'centres once — a later 1-minute tick does not move the offset '
        'again',
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

      testWidgets('a DevClock jump re-arms it exactly once', (tester) async {
        DateTime injectedNow = DateTime(2026, 8, 7, 12, 45); // Active
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
        final offsetBeforeJump = scrollable.position.pixels;
        expect(offsetBeforeJump, greaterThan(0));

        // Simulate a debug time-travel jump (Phase 25) on the SAME day:
        // build() detects the jump by reading DevClock.offset, independent
        // of which `now` closure is actually injected — exactly like the
        // real debug settings screen, which mutates DevClock rather than
        // this test harness's `now:` seam.
        injectedNow = DateTime(2026, 8, 7, 14, 30); // now DayComplete
        DevClock.setOffsetForTest(const Duration(hours: 2));
        await tester.pump(const Duration(minutes: 1)); // the 1-min ticker
        await tester.pumpAndSettle();

        final offsetAfterJump = scrollable.position.pixels;
        expect(offsetAfterJump, isNot(offsetBeforeJump));

        // A later tick at the SAME (now-stable) DevClock offset must not
        // re-trigger a second scroll.
        injectedNow = injectedNow.add(const Duration(minutes: 1));
        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();
        expect(scrollable.position.pixels, offsetAfterJump);
      });

      testWidgets(
        'a state transition does NOT re-centre on a mounted tree (PD-19) '
        '— a fresh open still does',
        (tester) async {
          // Rewrite of the 24-04 two-flag regression test this group
          // replaces (previously left as `// REWRITTEN IN 26-05`). That
          // test proved a SECOND flag let a live-row centring survive a
          // marker flag firing first. That premise is gone: there is only
          // one flag, and PD-19 says a transition on an ALREADY-MOUNTED
          // tree deliberately does not re-centre (re-centring on every
          // transition would be exactly the "dragging the list out from
          // under a reading user" the one-shot exists to prevent). What
          // this test proves instead: a genuinely FRESH open (a new
          // mount, e.g. app restart on the same day) still centres
          // correctly regardless of which NowState it opens into, and a
          // tick on that fresh mount does not re-trigger.
          final schedule = DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: longDayFixture(),
          );
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
            now: () => DateTime(2026, 8, 7, 7, 0), // PreStart
          );
          await tester.pumpAndSettle();
          final preStartScrollable = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          // PreStart: now == rangeStart by construction (see the
          // five-state table test above), so the clamped target is 0.
          expect(preStartScrollable.position.pixels, 0.0);

          // Full unmount + fresh mount — proving a state transition
          // doesn't need a live re-centre requires a genuinely new open,
          // not an in-place rebuild.
          await tester.pumpWidget(const SizedBox.shrink());

          DateTime injectedNow = DateTime(2026, 8, 7, 12, 45); // Active
          final freshSchedule = DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: longDayFixture(),
          );
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: _FakeScheduleNotifierWithSchedule(
              freshSchedule,
            ),
            now: () => injectedNow,
          );
          await tester.pumpAndSettle();

          expect(find.byType(LiveRowCard), findsOneWidget);
          final activeScrollable = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          final activeOffset = activeScrollable.position.pixels;
          expect(activeOffset, greaterThan(0));

          // On THIS mounted Active tree, a tick must not re-centre.
          injectedNow = injectedNow.add(const Duration(minutes: 1));
          await tester.pump(const Duration(minutes: 1));
          await tester.pumpAndSettle();
          expect(activeScrollable.position.pixels, activeOffset);
        },
      );

      testWidgets('empty state does not throw (hasClients guard)', (
        tester,
      ) async {
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifier(),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    });

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
