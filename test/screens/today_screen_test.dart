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
import 'package:canopy/screens/schedule/widgets/swipeable_chunk_card.dart';
import 'package:canopy/screens/today/timeline_geometry.dart';
import 'package:canopy/screens/today/today_screen.dart';
import 'package:canopy/screens/today/widgets/breathing_pulse_cta.dart';
import 'package:canopy/screens/today/widgets/end_of_day_card.dart';
import 'package:canopy/screens/today/widgets/hour_axis.dart';
import 'package:canopy/screens/today/widgets/live_row_card.dart';
import 'package:canopy/screens/today/widgets/now_line.dart';
import 'package:canopy/screens/today/widgets/timeline_row_tile.dart';
import 'package:canopy/utils/time_format.dart';
import 'package:canopy/widgets/break_skip_button.dart';
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

/// The now-line's terminus dot: the only circular-decorated Container in the
/// overlay. Matched by shape rather than by size so the assertions that use it
/// keep testing the *clearance* invariant if kNowDotDiameter is ever retuned.
Finder _nowDotFinder() => find.descendant(
  of: find.byType(NowLineOverlay),
  matching: find.byWidgetPredicate((widget) {
    if (widget is! Container) return false;
    final decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.shape == BoxShape.circle;
  }),
);

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

        // Exact match, for stability rather than ambiguity: the live row's
        // line naming the upcoming chunk — the reason an exact match used to
        // be required here — was deleted along with the rest of the live
        // row's inline "next" copy (Phase 27, GRID-02); nothing else in this
        // fixture renders 'Reading' as a substring today. Scroll it into
        // view first — the default test viewport is shorter than the whole
        // day's row list.
        await tester.ensureVisible(find.text('Reading'));

        // Phase 27 (GRID-01) intermediate state, now resolved: plan 27-01
        // temporarily left the live row (c3, directly above this one)
        // unbounded, so it painted over the rows beneath it and a geometric
        // tap on 'Reading' landed on the overlapping live card instead —
        // hence the direct `onTap!()` invocation this test used to carry.
        // Plan 27-02 (commit be64721) put the live row through the same
        // `Positioned(height: slot)` path every other row uses, so c3 and
        // c4 no longer overlap; this test now does a real geometric tap
        // again, which is what actually proves the row is tappable (2026-08-18).
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
      // nothing is live. (Phase 27, GRID-01: every slot is now
      // unconditionally duration-exact, live row included — this fixture
      // choice is no longer load-bearing for that, just for keeping these
      // particular assertions simple.)
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
        'a 25-minute work chunk slot measures exactly 25 * kPixelsPerMinute',
        (tester) async {
          await pumpDayComplete(tester);

          // c4: 10:50-11:15, 25 minutes, renders as "Reading".
          final c4ClipRect = find
              .ancestor(
                of: find.text('Reading'),
                matching: find.byType(ClipRect),
              )
              .first;
          expect(tester.getSize(c4ClipRect).height, 25 * kPixelsPerMinute);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'a 105-minute gap renders at 105 * kPixelsPerMinute — not compressed, '
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
          expect(tester.getSize(gapTile).height, 105 * kPixelsPerMinute);
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
        '* kPixelsPerMinute plus 2 * kTimelineEdgePadding (G-04/G-05, '
        '26-10-PLAN.md) when no live row is swelling it',
        (tester) async {
          await pumpDayComplete(tester);

          // firstStart 8:00 (480), lastEnd 14:00 (840), now 18:00 (1080) —
          // rangeStart = floorToHour(480) = 480, rangeEnd =
          // ceilToHour(1080) = 1080, both already hour-aligned, so the
          // arithmetic here is trivially checkable: nothing is live in this
          // fixture (Phase 27, GRID-01: there is no longer a live-row term
          // to account for either way, but this fixture predates that fix
          // and the hour-alignment is still what keeps the numbers clean).
          final expectedTotalHeight =
              (1080 - 480) * kPixelsPerMinute + 2 * kTimelineEdgePadding;
          final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
          expect(
            sizedBoxes.any((box) => box.height == expectedTotalHeight),
            isTrue,
            reason: 'Expected a SizedBox of height $expectedTotalHeight',
          );
          expect(tester.takeException(), isNull);
        },
      );

      // GRID-01 (Phase 27, PD-27-07): the live-row swell test that used to
      // live here ("renders taller than its duration-implied slot, capped
      // at a fixed reserved height") was deleted, not rewritten — that
      // behaviour is exactly the defect this phase removes. Its positive
      // replacement lands here, now that `_buildLiveRow`/`LiveRowCard`
      // actually have a `slotHeight` to render duration-exact against.

      testWidgets(
        "GRID-02: the live row's rendered slot is duration-exact, not "
        'swelled (single-line tier)',
        (tester) async {
          await pumpDay(tester);

          // c3 (10:45-10:50, live at 10:47 in this fixture) is a 5-minute
          // chunk — 20dp, below kCompactLiveMinHeight, so it renders the
          // single-line tier (no kicker text).
          //
          // Measure the ClipRect, NOT the LiveRowCard itself: OverflowBox
          // deliberately lets the card lay out at its natural height, so
          // getSize(find.byType(LiveRowCard)) would report the card's
          // content height, not its slot — asserting on that would be
          // measuring the placeholder font and would be worthless
          // (27-VALIDATION.md). The ClipRect is the slot, following the same
          // find.ancestor shape the other slot-measurement tests in this
          // group already use.
          final liveClipRect = find
              .ancestor(
                of: find.byType(LiveRowCard),
                matching: find.byType(ClipRect),
              )
              .first;
          expect(tester.getSize(liveClipRect).height, 5 * kPixelsPerMinute);
          expect(
            find.descendant(
              of: find.byType(LiveRowCard),
              matching: find.textContaining('RIGHT NOW'),
            ),
            findsNothing,
            reason:
                'below kCompactLiveMinHeight the single-line tier has no '
                'kicker',
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        "GRID-02: the live row's rendered slot is duration-exact, not "
        'swelled (compact tier)',
        (tester) async {
          // Mirrors CAL-02's twoChunkFixture (w1: 9:00-9:25, 25 minutes)
          // inline — that fixture is scoped to the sibling CAL-02 group
          // below and not reachable from here.
          final schedule = DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 540, // 9:00
                durationMinutes: 25,
                rationale: 'Deep work',
              ),
              _workChunk(
                id: 'w2',
                syntheticStartMinutes: 600, // 10:00
                durationMinutes: 25,
                rationale: 'Reading',
              ),
            ],
          );
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
            now: () => DateTime(2026, 8, 7, 9, 12), // inside w1's window
          );

          // w1 is a 25-minute chunk, live at 9:12 — 100dp, at/above
          // kCompactLiveMinHeight, so it renders the compact tier (kicker
          // text present). Together with the single-line case above, this is
          // the screen-level proof that tier selection is driven by real
          // geometry rather than a widget-test-only slotHeight argument —
          // the unit tests in plan 27-02 pass slotHeight directly and
          // therefore cannot prove the wiring.
          final liveClipRect = find
              .ancestor(
                of: find.byType(LiveRowCard),
                matching: find.byType(ClipRect),
              )
              .first;
          expect(tester.getSize(liveClipRect).height, 25 * kPixelsPerMinute);
          expect(
            find.descendant(
              of: find.byType(LiveRowCard),
              matching: find.textContaining('RIGHT NOW'),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'a 5-minute short break slot measures exactly 5 * kPixelsPerMinute',
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
          expect(tester.getSize(breakClipRect).height, 5 * kPixelsPerMinute);
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

      testWidgets("mid-chunk truth — the line sits at TimelineGeometry's own "
          "computed offset, strictly inside the live chunk's rendered span", (
        tester,
      ) async {
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
      });

      testWidgets('motion — a one-minute tick advances the line by exactly '
          'kPixelsPerMinute', (tester) async {
        await pumpAt(tester, DateTime(2026, 8, 7, 9, 12));
        final lineTopAt912 = tester.getTopLeft(find.byType(NowLineOverlay)).dy;

        // Full unmount between clocks (Pitfall 8) — see the no-suppression
        // test's comment above for why this is load-bearing, not optional.
        await tester.pumpWidget(const SizedBox.shrink());

        await pumpAt(tester, DateTime(2026, 8, 7, 9, 13));
        final lineTopAt913 = tester.getTopLeft(find.byType(NowLineOverlay)).dy;

        expect(lineTopAt913 - lineTopAt912, kPixelsPerMinute);
        expect(tester.takeException(), isNull);
      });

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

      // Replaces 'chip copy — renders exactly "9:30a" in a non-live state'.
      // The time chip was retired 2026-08-17 so kGutterWidth could drop
      // 52 → 40 (it, not the hour labels, was holding the gutter wide) and
      // give that width back to every chunk card. 9:30 with w1 completed is
      // GapBeforeNext — no live row — i.e. the exact state where the chip
      // used to be guaranteed to show, so it is the strongest place to assert
      // it is really gone rather than merely suppressed.
      testWidgets('no chip text in a non-live state — the chip is retired, not '
          'suppressed', (tester) async {
        await pumpAt(
          tester,
          DateTime(2026, 8, 7, 9, 30),
          chunks: twoChunkFixture(firstResolved: true),
        );

        expect(find.byType(LiveRowCard), findsNothing);
        expect(find.text('9:30a'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(NowLineOverlay),
            matching: find.byType(Text),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });

      // The successor to G-01's gutter-confinement assertion. G-01 guarded a
      // chip that no longer exists, but the underlying question — where the
      // overlay sits relative to a card — is what five rounds of UAT were
      // about, so it stays pinned at screen level.
      //
      // The dot is CENTRED on the card's left edge (Google Calendar's
      // treatment). It deliberately overlaps the card by half its width: the
      // alternative, holding the cards clear of it, left a blank strip down
      // the timeline that read as dead space. Geometric, not a text
      // measurement, so it is trustworthy in the harness's placeholder font.
      testWidgets(
        'the now-line dot is centred on the ChunkCard left edge, straddling '
        'the gutter boundary',
        (tester) async {
          await pumpAt(
            tester,
            DateTime(2026, 8, 7, 9, 30),
            chunks: twoChunkFixture(firstResolved: true),
          );

          final dotRect = tester.getRect(_nowDotFinder());
          final cardRect = tester.getRect(find.byType(ChunkCard).first);

          expect(dotRect.center.dx, cardRect.left);
          expect(tester.takeException(), isNull);
        },
      );

      // The live row is the case that actually shipped broken, three times: it
      // is positioned left:0/right:0 with no TimelineRowTile, so it inherits
      // no inset and every offset must be restated in LiveRowCard. It ran to
      // the raw viewport edge, then started left of the dot (putting the dot
      // on its title), then sat behind a clearance strip. It is now FLUSH with
      // an ordinary row, so assert that by name — a regression here is a
      // regression in the thing UAT kept catching.
      testWidgets(
        'the LIVE row is flush with an ordinary card on both edges, and the '
        'dot is centred on that shared edge',
        (tester) async {
          await pumpAt(tester, DateTime(2026, 8, 7, 9, 12));

          expect(find.byType(LiveRowCard), findsOneWidget);
          final dotRect = tester.getRect(_nowDotFinder());
          // The painted Material, not the LiveRowCard widget and not its Card:
          // the widget's rect spans the full positioned width, and Card
          // implements `margin` as padding INSIDE its own render box, so both
          // report the inset as zero. Measuring either would let this
          // assertion pass while the dot sat on the card's title — the very
          // defect it exists to catch. The Material is the first thing whose
          // rect is the card's actual painted edge.
          final liveRect = tester.getRect(
            find
                .descendant(
                  of: find.byType(LiveRowCard),
                  matching: find.byType(Material),
                )
                .first,
          );
          final cardRect = tester.getRect(find.byType(ChunkCard).first);

          expect(liveRect.left, cardRect.left);
          expect(liveRect.right, cardRect.right);
          expect(dotRect.center.dx, liveRect.left);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('G-03: no time chip over the live row — the full-bleed card '
          'leaves no gutter', (tester) async {
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
      });

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
          //
          // byTooltip, not widgetWithText(FilledButton, ...): the live row's
          // compact tier renders Complete/Skip as bare IconButtons with a
          // Tooltip, not the shipped card's labelled FilledButton (GRID-02).
          // w1 is 25 minutes, so at 100dp the compact tier renders and the
          // icon button exists — this finder now silently depends on the
          // fixture clearing kCompactLiveMinHeight.
          final completeButton = find.descendant(
            of: find.byType(LiveRowCard),
            matching: find.byTooltip('Complete'),
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

      // G-04/G-05 (26-UI-REVIEW.md Top Fix #1/#2, closed 26-10-PLAN.md):
      // rect assertions against the Stack's OWN painted bounds, not widget
      // count or label text — the "hour axis coverage" test above only
      // asserts the latter and went green against a real shear (26-UAT.md's
      // G-03 postmortem's generalised lesson, applied here). Both tests
      // below were proven RED against the unfixed geometry (kTimelineEdgePadding
      // temporarily reverted to 0-equivalent pre-fix code, both failed) and
      // GREEN after restoring the fix — see 26-10-SUMMARY.md for the
      // recorded observations.
      testWidgets('G-04: the first and last hour-axis labels stay inside the '
          "Stack's own painted bounds", (tester) async {
        await pumpAt(tester, DateTime(2026, 8, 7, 9, 12));

        final stackRect = tester.getRect(
          find
              .ancestor(
                of: find.byType(HourAxisLine).first,
                matching: find.byType(Stack),
              )
              .first,
        );
        final firstLabelRect = tester.getRect(find.byType(HourAxisLine).first);
        final lastLabelRect = tester.getRect(find.byType(HourAxisLine).last);

        expect(
          firstLabelRect.top,
          greaterThanOrEqualTo(stackRect.top),
          reason:
              'G-04: the FIRST hour-axis label must not be sheared above '
              'the Stack',
        );
        expect(
          lastLabelRect.bottom,
          lessThanOrEqualTo(stackRect.bottom),
          reason:
              'G-04: the LAST hour-axis label must not be sheared below '
              'the Stack',
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'G-05: the now-line stays inside the Stack at the EXACT boundary '
        'minute — PreStart (nowMinutes == rangeStart) and DayComplete '
        '(nowMinutes == rangeEnd), not merely "near" the edge',
        (tester) async {
          // PreStart: 8:00 AM — before w1's 9:00 start and already
          // hour-aligned, so rangeStart = floorToHour(480) = 480 ==
          // nowMinutes exactly (twoChunkFixture: firstStart 540, lastEnd
          // 625).
          await pumpAt(tester, DateTime(2026, 8, 7, 8, 0));
          var stackRect = tester.getRect(
            find
                .ancestor(
                  of: find.byType(NowLineOverlay),
                  matching: find.byType(Stack),
                )
                .first,
          );
          var lineRect = tester.getRect(find.byType(NowLineOverlay));
          expect(
            lineRect.top,
            greaterThanOrEqualTo(stackRect.top),
            reason:
                'G-05: the now-line must not be sheared above the Stack at '
                'PreStart (nowMinutes == rangeStart == 480)',
          );
          expect(lineRect.bottom, lessThanOrEqualTo(stackRect.bottom));

          // Full unmount before the next clock (_nowFn is late final —
          // Pitfall 8, see the no-suppression test's comment above).
          await tester.pumpWidget(const SizedBox.shrink());

          // DayComplete: 11:00 AM — after w2's 10:25 end and already
          // hour-aligned, so rangeEnd = ceilToHour(660) = 660 == nowMinutes
          // exactly.
          await pumpAt(tester, DateTime(2026, 8, 7, 11, 0));
          stackRect = tester.getRect(
            find
                .ancestor(
                  of: find.byType(NowLineOverlay),
                  matching: find.byType(Stack),
                )
                .first,
          );
          lineRect = tester.getRect(find.byType(NowLineOverlay));
          expect(lineRect.top, greaterThanOrEqualTo(stackRect.top));
          expect(
            lineRect.bottom,
            lessThanOrEqualTo(stackRect.bottom),
            reason:
                'G-05: the now-line must not be sheared below the Stack at '
                'DayComplete (nowMinutes == rangeEnd == 660)',
          );

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

      testWidgets('centres on open in every NowState, including DayComplete '
          '(closes the Phase 24 UAT gap by construction)', (tester) async {
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
              reason:
                  '${entry.key}: the computed target is > 0 here, so '
                  'the settled offset must be too',
            );
          } else {
            expect(
              scrollable.position.pixels,
              0.0,
              reason:
                  '${entry.key}: now IS the top of the rendered '
                  'range here, so the clamped target is legitimately 0',
            );
          }
          expect(tester.takeException(), isNull);

          // Full unmount before the next clock (Pitfall 8) — _nowFn is
          // late final, set once in initState.
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });

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
            scheduleNotifier: _FakeScheduleNotifierWithSchedule(freshSchedule),
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

    // **D-33-01 (owner's verdict 2026-09-02) inverts this test.** It used to
    // require both banner lines; he struck both out on a screenshot — *"i
    // crossed out the text, i don't think it should be there"* — so the same
    // two strings are now required to be ABSENT. Kept as a standing guard
    // rather than deleted, because the copy it removes was LOCKED by D-03 and
    // a future agent reading 23-UI-SPEC.md alone would put it back.
    testWidgets('pre-start: the banner is gone, the free block names the day', (
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

      expect(find.text('Nothing until 8:00 AM'), findsNothing);
      expect(
        find.text(
          'The day starts with Deep work. Until then the time is yours.',
        ),
        findsNothing,
      );
      expect(find.byType(LiveRowCard), findsNothing);
      // The day list is still rendered — and it, not a banner, is now the
      // only thing that names the pre-start stretch.
      expect(find.text('Free until 8:00 AM'), findsOneWidget);
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
        // The `Nothing until` findsNothing check that stood here is DELETED,
        // not kept: after D-33-01 that string renders in no state at all, so
        // it would pass without discriminating DayComplete from anything
        // else. The DayComplete assertions above this line are what carry
        // the test.
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

  group('Phase 29 — SEEBREAK: breaks you can see', () {
    // Fixture shape mirrors the CAL-01 group's day-complete pattern above: a
    // completed 8:00 work chunk, a short break at 8:25 whose duration is the
    // parameter under test, and a following unresolved work chunk — pumped
    // at 18:00 (DayComplete) so nothing is live and the break renders
    // through ChunkCard, not LiveRowCard.
    DailySchedule breakBoundaryFixture(int breakDurationMinutes) {
      return DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [
          _workChunk(id: 'w1', syntheticStartMinutes: 480, isCompleted: true),
          _breakChunk(
            id: 'b1',
            syntheticStartMinutes: 505,
            durationMinutes: breakDurationMinutes,
          ),
          _workChunk(
            id: 'w2',
            syntheticStartMinutes: 505 + breakDurationMinutes,
          ),
        ],
      );
    }

    testWidgets('SEEBREAK-01 tier boundary (Phase 32, TAPBREAK-03 rewrite): a '
        '5-minute break renders one Card and no Divider; a 30-minute break '
        'renders the full tier', (tester) async {
      // Phase 32 (D-32-02) retires the sub-compact tier's reachability
      // through TodayScreen entirely — the screen's own density ternary
      // (today_screen.dart) is now a two-way split, matching the work
      // ternary immediately below it. This test used to derive a
      // three-way boundary against kSubCompactBreakMinHeight; that
      // premise no longer holds, so the test is rewritten against the
      // new two-way split rather than merely re-deriving its old
      // boundary math. `ChunkCardDensity.subCompact` itself still exists
      // (retired outright by 32-02, not this plan) and is still directly
      // constructible in `today_row_widgets_test.dart`'s own unit tests —
      // only its reachability THROUGH the screen is gone, which is
      // exactly what this test now proves.
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(
          breakBoundaryFixture(5),
        ),
        now: () => DateTime(2026, 8, 7, 18, 0), // DayComplete
      );
      // Scoped to the break's own confined ClipRect, not "any ChunkCard"
      // — the fixture's two work chunks (w1/w2) are ChunkCards too, and
      // each renders its own Card.
      final shortBreakClipRect = find
          .ancestor(
            of: find.text('Short break'),
            matching: find.byType(ClipRect),
          )
          .first;
      expect(
        find.descendant(of: shortBreakClipRect, matching: find.byType(Divider)),
        findsNothing,
        reason:
            'a 5-minute break must never render the retired sub-compact '
            "tier's Dividers through the screen any more",
      );
      expect(
        find.descendant(of: shortBreakClipRect, matching: find.byType(Card)),
        findsOneWidget,
        reason:
            'a 5-minute break must render the new compact tier\'s '
            'bordered Card',
      );

      // TodayScreenState._nowFn is late final, set once in initState — a
      // second pumpWidget with a different clock is silently ignored
      // without a full unmount first.
      await tester.pumpWidget(const SizedBox.shrink());

      await _pumpTodayScreen(
        tester,
        scheduleNotifier: _FakeScheduleNotifierWithSchedule(
          breakBoundaryFixture(30),
        ),
        now: () => DateTime(2026, 8, 7, 18, 0),
      );
      // breakBoundaryFixture builds a shortBreak-typed chunk regardless
      // of duration — its title stays 'Short break' even at 30 minutes
      // (title is keyed to chunk TYPE, tier is keyed to slot HEIGHT).
      // At 30 min (180dp @ 6.0), the slot clears kFullBreakMinHeight
      // (88.0), so this proves the full tier specifically, not a
      // long-break title.
      expect(
        find.text('Short break'),
        findsOneWidget,
        reason: 'a 30-minute break must still render its title',
      );
      final fullTierClipRect = find
          .ancestor(
            of: find.text('Short break'),
            matching: find.byType(ClipRect),
          )
          .first;
      expect(
        find.descendant(of: fullTierClipRect, matching: find.byType(Divider)),
        findsNothing,
        reason: 'the full tier has never rendered a Divider',
      );
    });

    testWidgets(
      'SEEBREAK-02: a 5-minute break occupies exactly 30.0dp of slot at '
      'compact density (Phase 32 rewrite — was sub-compact at 20.0dp)',
      (tester) async {
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(
            breakBoundaryFixture(5),
          ),
          now: () => DateTime(2026, 8, 7, 18, 0), // DayComplete
        );

        // D-05 in its most direct form: five minutes is thirty pixels at
        // kPixelsPerMinute = 6.0. A deliberate bare literal, NOT
        // `5 * kPixelsPerMinute` re-derived — this is one of the suite's
        // canaries against kPixelsPerMinute itself silently drifting (see
        // the identical discipline in today_timeline_model_test.dart's
        // ground-truth test).
        final breakClipRect = find
            .ancestor(
              of: find.text('Short break'),
              matching: find.byType(ClipRect),
            )
            .first;
        expect(tester.getSize(breakClipRect).height, 30.0);
      },
    );
  });

  group('Phase 31 — SKIPBREAK: breaks you can skip', () {
    // Fixture shape mirrors the Phase 29 group's breakBoundaryFixture above:
    // a 25-minute work chunk, a 5-minute short break at 8:25, and a
    // following 25-minute work chunk — pumped at 18:00 (DayComplete) so
    // nothing is live and the break renders through ChunkCard, not
    // LiveRowCard (PD-31-06).
    //
    // Plan 31-03 DEVIATION (Rule 1, auto-fixed, test-file-only): w1/w2 gain
    // distinct `rationale` strings ('Preceding work'/'Following work') —
    // the factory default ('Deep work') left both work chunks with
    // identical title text, which plan 31-01's original single-case tracer
    // never needed to disambiguate but this plan's negative/adjacency cases
    // do (they anchor a `find.text(...)` on each neighbour's own painted
    // title to get its rect). Neither string is read by any existing
    // assertion in this group.
    DailySchedule skipTracerFixture() {
      return DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [
          _workChunk(
            id: 'w1',
            syntheticStartMinutes: 480,
            durationMinutes: 25,
            rationale: 'Preceding work',
          ),
          _breakChunk(id: 'b1', syntheticStartMinutes: 505, durationMinutes: 5),
          _workChunk(
            id: 'w2',
            syntheticStartMinutes: 510,
            durationMinutes: 25,
            rationale: 'Following work',
          ),
        ],
      );
    }

    // Phase 32 (D-32-02, Task 2 — Kind A, retired-mechanism deletion):
    // every test that used to live here drove a synthetic horizontal drag
    // against a break row's `Dismissible` — the SKIPBREAK-01 tracer, its
    // vacuity guard, the bottom-slop-band case, the negative case, the
    // below-threshold case, and both cases of the `D-31-06 — a bigger,
    // findable acquisition band` subgroup (acquisition-band Case A/B).
    // Breaks no longer have a `Dismissible` at all (button-only, D-32-02),
    // so a drag against a break row resolves nothing — these tests would
    // not merely need their literals updated, they assert a mechanism that
    // no longer exists. Deleted outright, per this task's own instruction
    // not to migrate a Kind A test. Phase 32's replacement coverage for
    // "tap the Skip rail" lives in the 'Phase 32 — TAPBREAK' group below,
    // and the button-vs-Dismissible companion invariant is asserted
    // directly in that group's own tracer test.

    group('SKIPBREAK-02 — the grid is unchanged', () {
      // 2026-08-26 (plan 31-06, D-31-06 part 2). Phase 32 (D-32-02) note:
      // this group's own historical mechanism ("the confined ClipRect
      // that SwipeableChunkCard's `visualHeight` produces, BY
      // CONSTRUCTION") no longer applies to a non-live break — the
      // restored early return (`swipeable_chunk_card.dart`) sends a
      // break straight to `ChunkCard`, never through `SwipeableRowShell`/
      // `_confineContent`/`visualHeight` at all. The ClipRect these
      // assertions measure now comes directly from `today_screen.dart`'s
      // own `Positioned`/`ClipRect`/`OverflowBox` chain — the identical,
      // unconfined mechanism a work chunk has always used. The
      // assertions below are unaffected by this and needed no changes:
      // they only ever measured the ClipRect's own painted size, never
      // the confinement mechanism producing it. It is therefore
      // structurally incapable of detecting an inflated CHILD, such as an
      // oversized grip glyph inside `_SubCompactRow` — a glyph 10dp too
      // tall would still measure exactly the row's own slot here and this
      // group would stay green. The grip's own zero-extent proof lives in
      // test/screens/today_row_widgets_test.dart's "D-31-06 — the
      // sub-compact grip glyph" group (Case C), which measures the
      // unresolved and skipped rows' natural, UNCLIPPED height directly. A
      // future reader must not mistake this group's continued green for
      // proof about that glyph.
      //
      // Same shape as the Phase 29 group's breakBoundaryFixture above (a
      // completed 25-minute preceding work chunk, a break of the
      // parameterised duration/resolution, a following 25-minute work
      // chunk) — this task's own read_first names that test as the
      // template.
      // Excludes end_of_day_card.dart's own Dismissible (a DayComplete-only
      // dismiss-the-card affordance, unrelated to any chunk row) — without
      // this, the zero-breaks/mixed-day cases below over-count by one
      // whenever the fixture is DayComplete-eligible for that card.
      Finder chunkDismissibles() => find.byWidgetPredicate(
        (widget) =>
            widget is Dismissible && widget.key != const Key('end_of_day_card'),
      );

      DailySchedule gridFixture(int durationMinutes, {bool isSkipped = false}) {
        return DailySchedule(
          dateYmd: _todayYmd(),
          moodIndex: 3,
          chunks: [
            _workChunk(id: 'w1', syntheticStartMinutes: 480, isCompleted: true),
            _breakChunk(
              id: 'b1',
              syntheticStartMinutes: 505,
              durationMinutes: durationMinutes,
              isSkipped: isSkipped,
            ),
            _workChunk(id: 'w2', syntheticStartMinutes: 505 + durationMinutes),
          ],
        );
      }

      testWidgets(
        'painted extent is exactly duration x kPixelsPerMinute in every '
        'resolved state, at every density',
        (tester) async {
          const cases = [
            (durationMinutes: 5, isSkipped: false), // compact, unresolved
            (durationMinutes: 5, isSkipped: true), // compact, skipped
            (durationMinutes: 30, isSkipped: false), // full tier, unresolved
            (durationMinutes: 30, isSkipped: true), // full tier, skipped
          ];

          for (var i = 0; i < cases.length; i++) {
            final c = cases[i];
            if (i > 0) {
              // TodayScreenState._nowFn is late final — a second
              // pumpWidget with a different fixture/clock is silently
              // ignored without a full unmount first (Phase 26/29
              // precedent, also noted in this task's own read_first).
              await tester.pumpWidget(const SizedBox.shrink());
            }
            await _pumpTodayScreen(
              tester,
              scheduleNotifier: _FakeScheduleNotifierWithSchedule(
                gridFixture(c.durationMinutes, isSkipped: c.isSkipped),
              ),
              now: () => DateTime(2026, 8, 7, 18, 0), // DayComplete
            );

            // Phase 32 (D-32-02): a non-live break's outer ClipRect now
            // comes directly from `today_screen.dart`'s own
            // `Positioned`/`ClipRect`/`OverflowBox` chain — the same
            // unconfined mechanism a work chunk has always used — since
            // the restored early return sends a break straight to
            // `ChunkCard`, never through `SwipeableChunkCard`'s
            // `visualHeight`/confinement machinery at all. The finder
            // below still resolves correctly (it only ever located the
            // ClipRect by type, not by which mechanism produced it), and
            // the assertion's CLAIM is unaffected: a break's painted
            // extent must still be exactly duration-exact.
            final breakClipRect = find
                .ancestor(
                  of: find.text('Short break'),
                  matching: find.byType(ClipRect),
                )
                .first;
            expect(
              tester.getSize(breakClipRect).height,
              c.durationMinutes * kPixelsPerMinute,
              reason:
                  'duration=${c.durationMinutes} isSkipped=${c.isSkipped}: '
                  'painted height must stay exactly duration-exact',
            );
          }
        },
      );

      testWidgets(
        'painted rows stay exactly adjacent — zero gap, zero overlap',
        (tester) async {
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: _FakeScheduleNotifierWithSchedule(
              skipTracerFixture(),
            ),
            now: () => DateTime(2026, 8, 7, 18, 0), // DayComplete
          );

          Rect paintedRectFor(String text) => tester.getRect(
            find
                .ancestor(of: find.text(text), matching: find.byType(ClipRect))
                .first,
          );

          final precedingRect = paintedRectFor('Preceding work');
          final breakRect = paintedRectFor('Short break');
          final followingRect = paintedRectFor('Following work');

          // Phase 32 (D-32-02): a non-live break no longer has any
          // hit-test envelope at all (button-only, no slop, no confined
          // paint vs. grown hit-test distinction) — a break's Positioned
          // is now structurally identical to a work chunk's. These
          // adjacency assertions predate that mechanism and are
          // unaffected by its removal: they only ever measured painted
          // rects, never the (now-gone) slop band.
          expect(
            breakRect.top,
            closeTo(precedingRect.bottom, 0.5),
            reason: 'a non-zero gap here means the rows are not truly adjacent',
          );
          expect(
            followingRect.top,
            closeTo(breakRect.bottom, 0.5),
            reason: 'a non-zero gap here means the rows are not truly adjacent',
          );

          // Independent authority check: the break's own painted top must
          // sit at the same offset from geometry.yFor(505) that the
          // preceding row's own painted top sits from geometry.yFor(480) —
          // i.e. both rows agree on ONE consistent geometry-to-screen
          // mapping. Derived from TimelineGeometry, the app's one
          // minute-to-pixel authority, built from the same fixture
          // today_screen.dart's own build() would use — not a literal, and
          // not just a re-check of the adjacency assertions above (which
          // would stay green even if the break and both neighbours drifted
          // together by the same amount).
          final geometry = TimelineGeometry.forDay(
            nowMinutes: 18 * 60,
            firstStartMinutes: 480,
            lastEndMinutes: 535,
          );
          final globalOffset = precedingRect.top - geometry.yFor(480);
          expect(
            breakRect.top,
            closeTo(geometry.yFor(505) + globalOffset, 0.5),
            reason:
                "the break's painted top must match geometry.yFor(505) "
                'under the same mapping the preceding row uses',
          );
        },
      );

      testWidgets(
        'the timeline\'s total painted extent is unchanged by this phase',
        (tester) async {
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: _FakeScheduleNotifierWithSchedule(
              skipTracerFixture(),
            ),
            now: () => DateTime(2026, 8, 7, 18, 0), // DayComplete
          );

          final geometry = TimelineGeometry.forDay(
            nowMinutes: 18 * 60,
            firstStartMinutes: 480,
            lastEndMinutes: 535,
          );

          // Phase 32 (D-32-02): no break has any hit-test envelope any
          // more, so there is nothing left that could grow the Stack's
          // own size beyond geometry.totalHeight. Located by the derived
          // height value itself, not a GlobalKey — today_screen.dart's
          // own `_timelineStackKey` is private to that library and
          // unreachable from this test file — this is the only SizedBox
          // in this tree configured with exactly `height:
          // geometry.totalHeight`.
          final timelineStack = find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox && widget.height == geometry.totalHeight,
          );
          expect(
            timelineStack,
            findsOneWidget,
            reason:
                'if the Stack grew for any reason, no SizedBox in this '
                'tree would carry exactly geometry.totalHeight any more',
          );
          expect(tester.getSize(timelineStack).height, geometry.totalHeight);
        },
      );

      testWidgets(
        'a day with zero breaks introduces no new copy and no new row '
        '(UI-SPEC E3 empty)',
        (tester) async {
          final schedule = DailySchedule(
            dateYmd: _todayYmd(),
            moodIndex: 3,
            chunks: [
              _workChunk(
                id: 'w1',
                syntheticStartMinutes: 480,
                durationMinutes: 25,
              ),
              _workChunk(
                id: 'w2',
                syntheticStartMinutes: 505,
                durationMinutes: 25,
              ),
            ],
          );
          await _pumpTodayScreen(
            tester,
            scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
            now: () => DateTime(2026, 8, 7, 18, 0), // DayComplete
          );

          expect(
            find.textContaining('break'),
            findsNothing,
            reason:
                'a break-free day must introduce no break copy anywhere on '
                'the screen — UI-SPEC E3 empty',
          );
          expect(chunkDismissibles(), findsNWidgets(2));
        },
      );

      testWidgets('a mixed day renders every row independently (UI-SPEC E3 '
          'populated / zero-one-many)', (tester) async {
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
            _workChunk(
              id: 'w2',
              syntheticStartMinutes: 505,
              durationMinutes: 25,
              isSkipped: true,
            ),
            _breakChunk(
              id: 'b1',
              syntheticStartMinutes: 530,
              durationMinutes: 5,
              isSkipped: true,
            ),
            _breakChunk(
              id: 'b2',
              chunkTypeIndex: ChunkType.longBreak.index,
              syntheticStartMinutes: 535,
              durationMinutes: 30,
            ),
            _workChunk(
              id: 'w3',
              syntheticStartMinutes: 565,
              durationMinutes: 25,
            ),
          ],
        );
        await _pumpTodayScreen(
          tester,
          scheduleNotifier: _FakeScheduleNotifierWithSchedule(schedule),
          now: () => DateTime(2026, 8, 7, 18, 0), // DayComplete
        );

        // Phase 32 (D-32-02, Task 2 — Kind C rewrite): the gesture used
        // to be attached per-row by chunk.id regardless of chunk type,
        // so break count had no bearing on the Dismissible count. Now
        // breaks never reach `Dismissible` at all (button-only) — only
        // the 3 work chunks (w1, w2, w3) have one; b1/b2 have none.
        expect(chunkDismissibles(), findsNWidgets(3));

        final shortBreakRect = tester.getSize(
          find
              .ancestor(
                of: find.text('Short break'),
                matching: find.byType(ClipRect),
              )
              .first,
        );
        expect(shortBreakRect.height, 5 * kPixelsPerMinute);

        final longBreakRect = tester.getSize(
          find
              .ancestor(
                of: find.text('Long break'),
                matching: find.byType(ClipRect),
              )
              .first,
        );
        expect(longBreakRect.height, 30 * kPixelsPerMinute);

        // Phase 32 (Kind C rewrite): the compact tier (the skipped
        // short break, b1) no longer renders an Opacity(0.5) mute — the
        // UI-SPEC's redesigned compact tier signals "resolved" via the
        // title's strikethrough plus the rail swapping from
        // BreakSkipButton to BreakSkippedIndicator's 'skipped' text,
        // not via a dimmed whole-row Opacity. The full tier (the
        // unresolved long break, b2) is unchanged and still uses
        // Opacity — asserted below, unchanged from before this phase.
        final shortBreakTitle = tester.widget<Text>(find.text('Short break'));
        expect(
          shortBreakTitle.style?.decoration,
          TextDecoration.lineThrough,
          reason: 'the skipped short break must still render struck through',
        );
        expect(
          find.descendant(
            of: find.byType(ChunkCard),
            matching: find.byType(BreakSkippedIndicator),
          ),
          findsOneWidget,
          reason:
              'the skipped short break\'s rail must show the resolved '
              'indicator, not the Skip button',
        );

        final longBreakOpacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: find.text('Long break'),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(
          longBreakOpacity.opacity,
          1.0,
          reason:
              'the unresolved long break must not render the resolved '
              'treatment',
        );
      });
    });
  });

  group('Phase 32 — TAPBREAK: breaks you can tap', () {
    // Fixture shape mirrors the Phase 31 group's own skipTracerFixture
    // above (an unresolved 25-minute work chunk, a 5-minute short break,
    // and a following 25-minute work chunk) — duplicated here rather than
    // shared across groups because Dart closures scope a group's own
    // helper functions to that group's testWidgets callback. Pumped
    // shortly after the fixture's own end (9:00 AM, not 18:00) for the
    // identical reason the Phase 31 group documents at its own first test:
    // CAL-03's scroll-on-open centres on `now`, and centring nine hours
    // past this tiny fixture would scroll the break entirely off the
    // default test viewport, making a synthetic tap land on nothing.
    DailySchedule tapBreakTracerFixture() {
      return DailySchedule(
        dateYmd: _todayYmd(),
        moodIndex: 3,
        chunks: [
          _workChunk(
            id: 'w1',
            syntheticStartMinutes: 480,
            durationMinutes: 25,
            rationale: 'Preceding work',
          ),
          _breakChunk(id: 'b1', syntheticStartMinutes: 505, durationMinutes: 5),
          _workChunk(
            id: 'w2',
            syntheticStartMinutes: 510,
            durationMinutes: 25,
            rationale: 'Following work',
          ),
        ],
      );
    }

    testWidgets('TAPBREAK-01 tracer: a tap on the Skip rail skips exactly that '
        'break, end to end, with no swipe anywhere in its tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final fake = _FakeScheduleNotifierWithSchedule(tapBreakTracerFixture());
      await _pumpTodayScreen(
        tester,
        scheduleNotifier: fake,
        now: () => DateTime(2026, 8, 7, 9, 0), // DayComplete
      );
      // Let CAL-03's scroll-to-now-on-open animation fully settle before
      // computing rects or tapping. Without this, a synthetic tap's
      // down/up pair can straddle an in-flight scroll frame: the row
      // shifts between them, the gesture arena reads that as movement,
      // and the InkWell's tap never resolves — silently, with no thrown
      // exception. Discovered empirically while building this test.
      await tester.pumpAndSettle();

      // The break row's own confined paint boundary — the same finder
      // pattern every prior phase's geometry assertions in this file use.
      final breakClipRect = find
          .ancestor(
            of: find.text('Short break'),
            matching: find.byType(ClipRect),
          )
          .first;

      // TAPBREAK-02: the break's painted extent is still exactly its
      // duration, derived symbolically from the scale constant — this is
      // not one of the suite's deliberate bare-literal canaries.
      expect(
        tester.getSize(breakClipRect).height,
        5 * kPixelsPerMinute,
        reason:
            'a break row must still occupy exactly duration x '
            'kPixelsPerMinute of slot after this phase',
      );

      // TAPBREAK-01/D-32-03: the Skip rail measures exactly
      // kBreakSkipButtonWidth wide by the row's own full height, and is
      // exactly one InkWell — one tappable unit, not two zones.
      final skipButton = find.descendant(
        of: breakClipRect,
        matching: find.byType(BreakSkipButton),
      );
      expect(skipButton, findsOneWidget);
      final skipButtonSize = tester.getSize(skipButton);
      expect(skipButtonSize.width, kBreakSkipButtonWidth);
      expect(skipButtonSize.height, 5 * kPixelsPerMinute);
      expect(
        find.descendant(of: breakClipRect, matching: find.byType(InkWell)),
        findsOneWidget,
      );

      // TAPBREAK-03: the compact tier renders a real bordered Card, not
      // the retired hairline treatment.
      expect(
        find.descendant(of: breakClipRect, matching: find.byType(Card)),
        findsOneWidget,
      );

      // Companion invariant (assumption-delta decision, 32-01-PLAN.md): a
      // break never reaches SwipeableRowShell, and no Dismissible exists
      // anywhere in its tree. This assertion goes red the instant a
      // future phase reintroduces the singular gesture-vocabulary
      // assumption D-32-02 just retired.
      expect(
        find.descendant(
          of: breakClipRect,
          matching: find.byType(SwipeableRowShell),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: breakClipRect, matching: find.byType(Dismissible)),
        findsNothing,
      );

      // The Skip button carries its own reachable Semantics(button: true,
      // ...) node — proof that no outer excludeSemantics wrapper swallows
      // it, the single easiest accessibility regression a straight
      // copy-paste of the retired tier's pattern would have introduced.
      expect(find.bySemanticsLabel('Skip Short break'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      expect(
        fake.lastSkippedId,
        'b1',
        reason:
            'a tap on the Skip rail must call markSkipped for the '
            'break\'s own chunk id',
      );
      expect(
        fake.lastCompletedId,
        isNull,
        reason: 'the Skip rail must never call markComplete',
      );

      handle.dispose();
    });
  });
}
