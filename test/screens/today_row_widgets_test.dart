// Widget tests for the Phase 22 Plan 02 Today-screen row vocabulary:
// TimelineRowTile (46dp time gutter), FreeTimeRow (named free time),
// ChunkCard's extended row treatments, and LiveRowCard (the swelled
// in-place current-activity card).
//
// Pure widget work — nothing here knows what time it is; the screen
// (plan 22-03) decides what's live and passes it in.

import 'dart:async';

import 'package:canopy/data/models/energy_valence.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/theme_notifier.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:canopy/screens/schedule/widgets/swipeable_chunk_card.dart';
import 'package:canopy/screens/today/timeline_geometry.dart';
import 'package:canopy/screens/today/widgets/free_time_row.dart';
import 'package:canopy/screens/today/widgets/hour_axis.dart';
import 'package:canopy/screens/today/widgets/live_row_card.dart';
import 'package:canopy/screens/today/widgets/now_line.dart';
import 'package:canopy/screens/today/widgets/timeline_row_tile.dart';
import 'package:canopy/widgets/break_skip_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ─── Fakes (per-file convention — see active_chunk_card_test.dart) ─────────

/// Records the last chunkId passed to markComplete/markSkipped, and stubs
/// init to avoid Hive I/O. Shared by the ChunkCard and LiveRowCard groups.
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

/// Phase 32 (TAPBREAK-01/E2 error). Simulates `markSkipped`'s WR-05
/// revert-and-rethrow path failing — `BreakSkipButton`/`LiveRowCard`'s
/// single-line tier do not await or catch this call (the tap fires it and
/// moves on, exactly like the work-chunk Skip button always has), so the
/// rejection surfaces as an async exception the test acknowledges via
/// `tester.takeException()` rather than a crash.
class _ThrowingScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}

  @override
  Future<void> markSkipped(String chunkId) async {
    throw Exception('simulated repository failure');
  }
}

// ─── Chunk factories ─────────────────────────────────────────────────────

ScheduledChunk _workChunk({
  String id = 'w1',
  bool completed = false,
  bool skipped = false,
  String? commitmentId,
  int? startMinutes,
}) =>
    ScheduledChunk(
        id: id,
        chunkTypeIndex: ChunkType.work.index,
        goalId: commitmentId == null ? 'goal-1' : null,
        durationMinutes: 25,
        rationale: 'Deep work',
        commitmentId: commitmentId,
        syntheticStartMinutes: startMinutes,
      )
      ..isCompleted = completed
      ..isSkipped = skipped;

ScheduledChunk _breakChunk({
  required ChunkType type,
  bool completed = false,
  bool skipped = false,
}) =>
    ScheduledChunk(
        id: 'b1',
        chunkTypeIndex: type.index,
        durationMinutes: type == ChunkType.shortBreak ? 5 : 25,
      )
      ..isCompleted = completed
      ..isSkipped = skipped;

/// A 25-minute work chunk carrying a goal name, a rationale, a non-default
/// priority weight and a non-neutral valence — used by the ChunkCardDensity
/// group to assert which of those fields each density suppresses.
ScheduledChunk _denseWorkChunk() => ScheduledChunk(
  id: 'w-dense',
  chunkTypeIndex: ChunkType.work.index,
  goalId: 'goal-1',
  durationMinutes: 25,
  rationale: 'Deep work',
  syntheticStartMinutes: 540,
);

Future<void> _pumpDenseChunkCard(
  WidgetTester tester,
  ChunkCardDensity density,
) async {
  await pumpWithMood(
    tester,
    ChunkCard(
      chunk: _denseWorkChunk(),
      goalName: 'Write the report',
      displayRationale: 'Deep work',
      goalPriorityWeight: 0.75,
      goalValence: EnergyValence.gives,
      density: density,
    ),
    extraProviders: [
      ChangeNotifierProvider<ScheduleNotifier>.value(
        value: _FakeScheduleNotifier(),
      ),
    ],
  );
}

Future<void> _pumpChunkCard(
  WidgetTester tester,
  ScheduledChunk chunk, {
  bool? showStartTime,
  _FakeScheduleNotifier? scheduleNotifier,
}) async {
  await pumpWithMood(
    tester,
    showStartTime == null
        ? ChunkCard(chunk: chunk)
        : ChunkCard(chunk: chunk, showStartTime: showStartTime),
    extraProviders: [
      ChangeNotifierProvider<ScheduleNotifier>.value(
        value: scheduleNotifier ?? _FakeScheduleNotifier(),
      ),
    ],
  );
}

// Phase 32 (D-32-02, Task 1): `_pumpBreakCardUnbounded` (Phase 29,
// SEEBREAK-01) is deleted — its only callers were the retired
// `ChunkCardDensity.subCompact` tests (the sub-compact-vs-compact height
// comparison and the D-31-06 grip-glyph group), all deleted with the tier.

void main() {
  group('TimelineRowTile (Phase 26 CAL-01, PD-5: pure inset wrapper)', () {
    testWidgets('still lays out the child', (tester) async {
      await pumpWithMood(
        tester,
        const TimelineRowTile(child: Text('Free until 8:00 AM')),
      );
      expect(find.text('Free until 8:00 AM'), findsOneWidget);
    });

    testWidgets('gutter SizedBox is exactly kGutterWidth wide', (tester) async {
      await pumpWithMood(
        tester,
        const TimelineRowTile(child: Text('Exercise')),
      );
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(
        sizedBoxes.any((box) => box.width == kGutterWidth),
        isTrue,
        reason: 'Expected a SizedBox of width kGutterWidth',
      );
      // G-04: the clip was caused by a MISSING 16dp inset, not by an
      // insufficient width. See kGutterWidth's doc comment before changing.
      //
      // 40, not the old 52: the 52 was sized for the now-line's time chip,
      // which has been retired. This column now holds only HourAxisLine's
      // labels ("12 PM" ~34dp measured in-browser). Restoring a chip means
      // restoring 52 — see now_line.dart.
      expect(kGutterWidth, 40.0);
    });

    testWidgets(
      'the reserved gutter column renders no Text for any row (PD-5)',
      (tester) async {
        await pumpWithMood(
          tester,
          const TimelineRowTile(child: Text('Reading')),
        );
        final gutterColumn = find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == kGutterWidth,
        );
        expect(gutterColumn, findsOneWidget);
        expect(
          find.descendant(of: gutterColumn, matching: find.byType(Text)),
          findsNothing,
        );
      },
    );
  });

  group('FreeTimeRow (D-05, LOCKED copy)', () {
    testWidgets('leading form renders exactly "Free until 8:00 AM"', (
      tester,
    ) async {
      await pumpWithMood(tester, const FreeTimeRow.until(untilMinutes: 480));
      expect(find.text('Free until 8:00 AM'), findsOneWidget);
    });

    testWidgets('gap form renders exactly "Free · 1h 40m"', (tester) async {
      await pumpWithMood(tester, const FreeTimeRow.gap(durationMinutes: 100));
      expect(find.text('Free · 1h 40m'), findsOneWidget);
    });

    // Phase 33 (OBVIOUS-01, UI-SPEC item 7, sketch 003 — Kind C rewrite).
    // This test was 'neither form renders a Card' and asserted exactly the
    // mechanism this phase retires. Its PREMISE inverted rather than its
    // expected value, so it is rewritten rather than deleted — the assertion
    // still has a subject, it just flipped. Same treatment, and same reason,
    // as the Phase 32 break-row inversion at lines ~501-506 of this file.
    //
    // Why it flipped: Phase 22 gave free time and breaks one visual language;
    // Phase 32 rebuilt breaks as filled bordered cards and left free time on
    // the dashed outline, silently breaking the match. An outline reads as
    // absence where a fill reads as "this is yours".
    testWidgets('both forms render a Card', (tester) async {
      await pumpWithMood(tester, const FreeTimeRow.until(untilMinutes: 480));
      expect(find.byType(Card), findsOneWidget);

      await pumpWithMood(tester, const FreeTimeRow.gap(durationMinutes: 100));
      expect(find.byType(Card), findsOneWidget);
    });

    // Phase 33 (OBVIOUS-01, UI-SPEC item 7). The non-collapse guard: a [Card]
    // sizes to its child, so swapping the old full-bleed `CustomPaint` for a
    // `Card` can silently collapse the row to label height and hand back the
    // "weird long stretch of white space" UAT 2026-08-18 rejected.
    //
    // **The harness pumps through [TimelineRowTile] deliberately, and a bare
    // `SizedBox(height: 240, child: FreeTimeRow.gap(...))` is forbidden
    // here.** A `SizedBox` imposes a TIGHT height; `FreeTimeRow`'s own
    // `Container` deflates it by its 4dp margins and passes tight 232 straight
    // down, so the `Card` would measure 232 whether its child is a `Center` or
    // a bare `Text` — the test would pass over the exact defect it exists to
    // catch. The production path is loose, and only a loose harness tells a
    // filling child from a collapsing one. The chain, verified:
    // `today_screen.dart:697` `Positioned(height: geometry.heightFor(...))` →
    // `TimelineRowTile` → `timeline_row_tile.dart:106-115`
    // `Row(crossAxisAlignment: CrossAxisAlignment.start)` → `Expanded(child:
    // child)`; `CrossAxisAlignment.start` is what makes the child's height
    // loose. Using `TimelineRowTile` itself means the harness cannot drift
    // from the production shape.
    //
    // **Observed, not asserted.** With the card's `Center` replaced by a bare
    // `Text` — i.e. the defect this test exists to catch, deliberately
    // introduced — the two harnesses were measured side by side on
    // 2026-09-01:
    //
    //   bare `SizedBox(height: 240, ...)`  → Card height 232.0  (PASSES)
    //   `TimelineRowTile` (this harness)   → Card height  20.0  (FAILS)
    //
    // The forbidden harness reports the correct number for the wrong reason
    // and sails straight over a collapsed row. That is this project's
    // fifth-time failure mode verbatim (STATE.md: "two defects behind green
    // tests, both assertions that could not fail"), so the shape above is not
    // a stylistic preference — it is the entire test.
    testWidgets('the card fills its allocated slot, it does not collapse to '
        'label height', (tester) async {
      await pumpWithMood(
        tester,
        const SizedBox(
          height: 240,
          child: TimelineRowTile(child: FreeTimeRow.gap(durationMinutes: 40)),
        ),
      );
      // 232 = 240 less the row's own 4dp top and 4dp bottom margin.
      expect(tester.getSize(find.byType(Card)).height, 232.0);
    });
  });

  group('NowLineOverlay (CAL-02, UI-SPEC locked)', () {
    // The time chip was retired (2026-08-17) so kGutterWidth could drop 52 →
    // 40 and hand that width back to every chunk card. The overlay is now
    // text-free: rule + dot only. This replaces the old test that asserted
    // the chip's locked "2:47p" copy — kept as an assertion rather than
    // deleted so a restored chip trips it and its author re-reads the
    // gutter-width consequence in now_line.dart.
    testWidgets('renders no text at all — the time chip is retired', (
      tester,
    ) async {
      await pumpWithMood(tester, const NowLineOverlay(nowMinutes: 887));
      expect(find.text('2:47p'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(NowLineOverlay),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('a 2dp-tall Container renders, colored colorScheme.primary '
        'from the pumped theme', (tester) async {
      await pumpWithMood(tester, const NowLineOverlay(nowMinutes: 887));
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(NowLineOverlay),
          matching: find.byType(Container),
        ),
      );
      final expectedColor = ColorScheme.fromSeed(
        seedColor: ThemeNotifier.moodSeeds[3]!,
      ).primary;
      final ruleContainer = containers.firstWhere(
        (c) => c.constraints?.maxHeight == 2,
      );
      expect(ruleContainer.color, expectedColor);
    });

    testWidgets('the widget\'s own rendered height equals kNowLineHeight', (
      tester,
    ) async {
      await pumpWithMood(tester, const NowLineOverlay(nowMinutes: 887));
      final size = tester.getSize(find.byType(NowLineOverlay));
      expect(size.height, kNowLineHeight);
    });

    // The calendar terminus dot straddles the content edge — CENTRED on it,
    // so half sits in the hour-label gutter and half over the card's left
    // edge, which is what Google Calendar does and what lets the cards sit
    // flush against the gutter with no blank clearance strip.
    testWidgets('renders a circular primary-colored dot centred on the '
        'content edge', (
      tester,
    ) async {
      await pumpWithMood(tester, const NowLineOverlay(nowMinutes: 887));
      final dotFinder = find.descendant(
        of: find.byType(NowLineOverlay),
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final d = w.decoration;
          return d is BoxDecoration && d.shape == BoxShape.circle;
        }),
      );
      expect(dotFinder, findsOneWidget);

      final expectedColor = ColorScheme.fromSeed(
        seedColor: ThemeNotifier.moodSeeds[3]!,
      ).primary;
      final dot = tester.widget<Container>(dotFinder);
      expect((dot.decoration as BoxDecoration).color, expectedColor);

      expect(tester.getSize(dotFinder).width, kNowDotDiameter);

      final overlayLeft = tester.getTopLeft(find.byType(NowLineOverlay)).dx;
      final dotRect = tester.getRect(dotFinder);
      expect(dotRect.center.dx - overlayLeft, kNowContentEdge);
      // and therefore overhangs into the gutter by half its width
      expect(dotRect.left - overlayLeft, kNowContentEdge - kNowDotDiameter / 2);
    });

    // The rule starts at the dot rather than running full-bleed back through
    // the gutter, so the dot caps it instead of sitting as a bead on a longer
    // stroke. Guards against a "simplification" that drops the inset.
    testWidgets('the 2dp rule starts at the content edge, not at x=0', (
      tester,
    ) async {
      await pumpWithMood(tester, const NowLineOverlay(nowMinutes: 887));
      final ruleFinder = find.descendant(
        of: find.byType(NowLineOverlay),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxHeight == 2,
        ),
      );
      expect(ruleFinder, findsOneWidget);

      final overlayLeft = tester.getTopLeft(find.byType(NowLineOverlay)).dx;
      expect(tester.getTopLeft(ruleFinder).dx - overlayLeft, kNowContentEdge);
    });

    // UAT edge case: the caller positions this overlay `right: 0`, so the rule
    // must reapply TimelineRowTile's inset on the RIGHT too. Without it the
    // rule outran every card and the hour axis by 16dp and bled off the
    // viewport edge — invisible on a wide desktop window, obvious on a phone.
    testWidgets('the 2dp rule stops at the row inset on the right, not the '
        'overlay edge', (tester) async {
      await pumpWithMood(tester, const NowLineOverlay(nowMinutes: 887));
      final ruleFinder = find.descendant(
        of: find.byType(NowLineOverlay),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxHeight == 2,
        ),
      );
      final overlayRight = tester.getTopRight(find.byType(NowLineOverlay)).dx;
      expect(
        overlayRight - tester.getTopRight(ruleFinder).dx,
        kTimelineRowInset,
      );
    });

    // Replaces 'the dot still renders when showChip is false'. That test
    // guarded the G-03 live-row chip suppression, which no longer exists —
    // there is no chip and so no suppression flag. What still needs guarding
    // is that the overlay takes no such flag: a future agent reaching for one
    // should read now_line.dart's note on why the chip went instead.
    testWidgets('the overlay renders from nowMinutes alone, with no '
        'suppression flag', (tester) async {
      await pumpWithMood(tester, const NowLineOverlay(nowMinutes: 887));
      expect(tester.takeException(), isNull);
      expect(find.byType(NowLineOverlay), findsOneWidget);
    });
  });

  group('HourAxisLine (CAL-01 hour axis)', () {
    testWidgets('renders "9 AM" for hourMinutes 540', (tester) async {
      await pumpWithMood(tester, const HourAxisLine(hourMinutes: 540));
      expect(find.text('9 AM'), findsOneWidget);
    });

    // The hour labels are the ONLY thing left in the gutter column, so they
    // are what now bounds kGutterWidth (40dp since the chip was retired).
    // "12 PM" and "10 AM"/"11 AM" are the widest HourAxisLine can produce.
    // Do not treat a pass here as a width measurement — this harness draws
    // every glyph as a fixed fontSize-wide box (see kGutterWidth's doc), so
    // it over-measures. It is an overflow guard; the real check is visual, in
    // the served debug build.
    testWidgets('the widest hour labels render without overflowing the '
        'gutter', (tester) async {
      for (final minutes in <int>[600, 660, 720]) {
        await pumpWithMood(tester, HourAxisLine(hourMinutes: minutes));
        expect(
          tester.takeException(),
          isNull,
          reason: 'HourAxisLine overflowed for hourMinutes $minutes',
        );
      }
    });

    testWidgets('renders "12 PM" for hourMinutes 720', (tester) async {
      await pumpWithMood(tester, const HourAxisLine(hourMinutes: 720));
      expect(find.text('12 PM'), findsOneWidget);
    });

    testWidgets('the label column is exactly kGutterWidth wide', (
      tester,
    ) async {
      await pumpWithMood(tester, const HourAxisLine(hourMinutes: 540));
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(
        sizedBoxes.any((box) => box.width == kGutterWidth),
        isTrue,
        reason: 'Expected a SizedBox of width kGutterWidth',
      );
    });

    testWidgets('the hairline Container is 1dp tall and colored '
        'outlineVariant', (tester) async {
      await pumpWithMood(tester, const HourAxisLine(hourMinutes: 540));
      final expectedColor = ColorScheme.fromSeed(
        seedColor: ThemeNotifier.moodSeeds[3]!,
      ).outlineVariant;
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(HourAxisLine),
          matching: find.byType(Container),
        ),
      );
      final hairline = containers.firstWhere(
        (c) => c.constraints?.maxHeight == 1,
      );
      expect(hairline.color, expectedColor);
    });
  });

  group('ChunkCard row vocabulary (D-06, D-07, P10)', () {
    // Phase 33 (OBVIOUS-01, UI-SPEC items 1-2, sketch 003 variant B — Kind C
    // repoints). The three tests below asserted the trailing status this
    // phase retires: a bare `Icons.check_circle`, the lowercase word
    // `skipped`, and `Icons.radio_button_unchecked`. All three now read the
    // labelled `_StatusChip` instead. Task 1 could not delete the unchecked
    // circle and leave this group green — one of the two had to move, and it
    // is the tests, because the phase exists to delete that icon. The
    // strikethrough and Complete/Skip assertions are untouched: they live in
    // the content builder and the action row, not in the trailing status, and
    // the Complete/Skip pair is the standing guard on UI-SPEC item 4.
    testWidgets('completed work chunk: struck through + Done chip', (
      tester,
    ) async {
      await _pumpChunkCard(tester, _workChunk(completed: true));
      final titleText = tester.widget<Text>(find.text('Deep work'));
      expect(titleText.style?.decoration, TextDecoration.lineThrough);

      // The completed branch is now a labelled chip whose glyph is
      // `Icons.check`, so the old `Icons.check_circle` finder cannot match and
      // its `colorScheme.primary` assertion was reading the wrong element.
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('skipped work chunk: struck through + Skipped chip', (
      tester,
    ) async {
      await _pumpChunkCard(tester, _workChunk(skipped: true));
      final titleText = tester.widget<Text>(find.text('Deep work'));
      expect(titleText.style?.decoration, TextDecoration.lineThrough);
      // Expected value AND casing both changed: UI-SPEC item 1 replaces the
      // bare lowercase word with the capitalised chip label.
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets(
      'unresolved work chunk: no strikethrough, To do chip, Complete/Skip present',
      (tester) async {
        await _pumpChunkCard(tester, _workChunk());
        final titleText = tester.widget<Text>(find.text('Deep work'));
        expect(titleText.style?.decoration, isNot(TextDecoration.lineThrough));
        // This line used to assert `Icons.radio_button_unchecked` — the exact
        // icon this phase exists to delete, and the owner's 2026-06-12
        // complaint. The row says its state in words now.
        expect(find.text('To do'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Complete'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Skip'), findsOneWidget);
      },
    );

    testWidgets(
      'showStartTime false renders duration, not the clock-time range',
      (tester) async {
        await _pumpChunkCard(
          tester,
          _workChunk(startMinutes: 565),
          showStartTime: false,
        );
        expect(find.text('25 min'), findsOneWidget);
        expect(find.textContaining('9:25 AM'), findsNothing);
      },
    );

    testWidgets('showStartTime omitted still renders the clock-time range', (
      tester,
    ) async {
      await _pumpChunkCard(tester, _workChunk(startMinutes: 565));
      expect(find.text('9:25 AM – 9:50 AM'), findsOneWidget);
    });

    testWidgets(
      'SwipeableChunkCard forwards showStartTime false and keeps swipe',
      (tester) async {
        await pumpWithMood(
          tester,
          SwipeableChunkCard(
            chunk: _workChunk(startMinutes: 565),
            showStartTime: false,
          ),
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>.value(
              value: _FakeScheduleNotifier(),
            ),
          ],
        );
        expect(find.text('25 min'), findsOneWidget);
        expect(find.byType(Dismissible), findsOneWidget);
      },
    );

    // Phase 32 (D-32-02, Task 1 — Kind C rewrite): both tests below used to
    // assert "no Card, dashed outline" — exactly the premise TAPBREAK-03
    // reverses (D-32-02: "make it look like a small section similar to
    // work"). Rewritten to assert the inverse: a bordered Card, no dashed
    // painter, rather than deleted — the assertion still has a subject, it
    // just flipped.
    testWidgets(
      'short break: "Short break" label, a bordered Card, no dashed painter',
      (tester) async {
        await _pumpChunkCard(tester, _breakChunk(type: ChunkType.shortBreak));
        expect(find.text('Short break'), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter != null &&
                w.painter.runtimeType.toString().contains('DashedBorder'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'long break: "Long break" label, the same bordered Card at greater '
      'weight (G-02)',
      (tester) async {
        await _pumpChunkCard(tester, _breakChunk(type: ChunkType.longBreak));
        expect(find.text('Long break'), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter != null &&
                w.painter.runtimeType.toString().contains('DashedBorder'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a long break reads substantially heavier than a short break (G-02)',
      (tester) async {
        // Height: long break's taller padding + titleMedium/w500 title +
        // leading icon should measure at least 16dp taller than a short
        // break's ChunkCard.
        await _pumpChunkCard(tester, _breakChunk(type: ChunkType.shortBreak));
        final shortHeight = tester.getSize(find.byType(ChunkCard)).height;

        await _pumpChunkCard(tester, _breakChunk(type: ChunkType.longBreak));
        final longHeight = tester.getSize(find.byType(ChunkCard)).height;

        expect(longHeight, greaterThanOrEqualTo(shortHeight + 16));

        // Icon: self_improvement present ONLY on the long break.
        expect(find.byIcon(Icons.self_improvement), findsOneWidget);

        await _pumpChunkCard(tester, _breakChunk(type: ChunkType.shortBreak));
        expect(find.byIcon(Icons.self_improvement), findsNothing);
      },
    );

    testWidgets(
      // Phase 32 (D-32-02, TAPBREAK-01) supersedes this test's original
      // premise for the button axis: the break row now DOES gain a real
      // interactive child (the Skip rail), by owner ruling. What survives
      // from the original G-02 prohibition is the narrower, still-true
      // claim it was actually guarding — no collapse/accordion affordance,
      // and no whole-row tap/expand behaviour was added alongside the Skip
      // rail. The retired dashed-painter assertion (`CustomPaint`
      // `isNotEmpty`) is dropped with the painter it described.
      'no collapse/accordion affordance is added to the break row — the '
      'Skip rail is its only interactive child (G-02 prohibition, narrowed)',
      (tester) async {
        await _pumpChunkCard(tester, _breakChunk(type: ChunkType.longBreak));
        expect(find.byType(ExpansionTile), findsNothing);
        expect(
          find.byType(InkWell),
          findsOneWidget,
          reason: 'the Skip rail is the row\'s only interactive child — no '
              'whole-row tap/expand affordance was added alongside it',
        );
      },
    );

    // Phase 32 (D-32-02, Task 1 — Kind A, retired-mechanism deletion):
    // 'completed break also renders the check icon' pumped an artificial
    // fixture (`_breakChunk(completed: true)`) that can never occur in
    // production — a break's `isCompleted` is permanently false (D-31-01).
    // The `Icons.check_circle` completed-branch it asserted was already
    // documented dead code in the pre-Phase-32 full tier, and this task's
    // rebuild does not carry it forward (the trailing content is now the
    // Skip rail, gated only on `isSkipped`). Deleted with the branch it
    // tested, not repointed at a state the app can never produce.

    testWidgets(
      'commitment work chunk uses tertiaryContainer, no outline, no left bar',
      (tester) async {
        await _pumpChunkCard(tester, _workChunk(commitmentId: 'commitment-1'));
        final context = tester.element(find.byType(ChunkCard));
        final card = tester.widget<Card>(find.byType(Card));
        expect(card.color, Theme.of(context).colorScheme.tertiaryContainer);
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.side, BorderSide.none);
        final positionedBars = tester
            .widgetList<Positioned>(find.byType(Positioned))
            .where((p) => p.width == 4);
        expect(positionedBars, isEmpty);
      },
    );

    testWidgets('no hardcoded Colors literal reaches the widget tree', (
      tester,
    ) async {
      // Static grep gate (flutter analyze + task verify) is the real check;
      // this just proves the mood-3 render path still completes cleanly
      // after the ColorScheme migration.
      await _pumpChunkCard(tester, _workChunk(completed: true));
      expect(find.byType(ChunkCard), findsOneWidget);
    });
  });

  group('ChunkCardDensity (CAL-01, 26-02-PLAN.md PD-4)', () {
    testWidgets(
      'detailed (default): rationale, priority chip and valence chip all render',
      (tester) async {
        await _pumpDenseChunkCard(tester, ChunkCardDensity.detailed);
        expect(find.text('Write the report'), findsOneWidget);
        expect(find.text('Deep work'), findsOneWidget); // rationale
        expect(find.text('High'), findsOneWidget); // _PriorityChip
        expect(find.text('Gives'), findsOneWidget); // _ValenceChip
      },
    );

    testWidgets(
      'full: title and time range render; rationale, priority chip, '
      'valence chip do not; Complete and Skip render',
      (tester) async {
        await _pumpDenseChunkCard(tester, ChunkCardDensity.full);
        expect(find.text('Write the report'), findsOneWidget);
        expect(find.text('9:00 AM – 9:25 AM'), findsOneWidget);
        expect(find.text('Deep work'), findsNothing); // rationale suppressed
        expect(find.text('High'), findsNothing); // _PriorityChip suppressed
        expect(find.text('Gives'), findsNothing); // _ValenceChip suppressed
        expect(find.widgetWithText(FilledButton, 'Complete'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Skip'), findsOneWidget);
      },
    );

    testWidgets('compact: only the title renders', (tester) async {
      await _pumpDenseChunkCard(tester, ChunkCardDensity.compact);
      expect(find.text('Write the report'), findsOneWidget);
      expect(find.text('9:00 AM – 9:25 AM'), findsNothing);
      expect(find.text('25 min'), findsNothing);
      expect(find.text('Deep work'), findsNothing);
      expect(find.text('High'), findsNothing);
      expect(find.text('Gives'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Complete'), findsNothing);
    });

    group('break densities', () {
      testWidgets(
        'compact short break renders the label but not its duration text',
        (tester) async {
          await pumpWithMood(
            tester,
            ChunkCard(
              chunk: _breakChunk(type: ChunkType.shortBreak),
              density: ChunkCardDensity.compact,
            ),
          );
          expect(find.text('Short break'), findsOneWidget);
          expect(find.text('5 min'), findsNothing);
        },
      );

      testWidgets(
        // Phase 32 (D-32-02, Task 1 — Kind C rewrite): the full tier used
        // to render a trailing "N min"/"skipped" duration text (the old
        // Spacer()-then-Text arrangement); that trailing content is now the
        // same Skip rail structure the compact tier uses, so the premise
        // ("renders its duration text") is exactly what this phase reverses.
        // Phase 32 gap closure (G-32-02): repointed twice over, and the
        // SECOND repoint is the one that matters.
        //
        // (1) The mechanism changed again — the full tier's Skip is now the
        //     shared `OutlinedButton.icon` a work chunk uses, not
        //     `BreakSkipButton`. The CLAIM ("a tappable Skip, and no duration
        //     text") is unchanged, so this is a Kind C rewrite.
        //
        // (2) **The fixture was wrong and is corrected here.** This pumped a
        //     5-minute break at `full` density — 30dp — a combination the app
        //     CANNOT produce: `today_screen.dart` picks `full` only at
        //     >= kFullBreakMinHeight (88dp), so a 5-minute break always lands
        //     on the compact tier. Testing the tall tier at its smallest
        //     *unreachable* size is precisely how "one shape fits both tiers"
        //     survived review — the assertion never met the 180dp row where
        //     the shape actually failed. Now uses a long break (reachable at
        //     this tier) and measures the thing the owner rejected.
        'full-tier break renders the label and a bounded Skip control, not '
        'duration text and not a full-height slab',
        (tester) async {
          await pumpWithMood(
            tester,
            ChunkCard(
              chunk: _breakChunk(type: ChunkType.longBreak),
              density: ChunkCardDensity.full,
            ),
          );
          expect(find.text('Long break'), findsOneWidget);
          expect(find.text('25 min'), findsNothing);
          final skip = find.descendant(
            of: find.byType(ChunkCard),
            matching: find.byType(OutlinedButton),
          );
          expect(skip, findsOneWidget);
          expect(find.text('Skip'), findsOneWidget);

          // G-32-02, the assertion the old test could never make. The
          // shipped rail took its height from `CrossAxisAlignment.stretch`,
          // so it was EXACTLY the card's height — this comparison goes RED
          // against that code and green only against a bounded control.
          final skipHeight = tester.getSize(skip).height;
          final cardHeight = tester.getSize(find.byType(Card)).height;
          expect(
            skipHeight,
            lessThan(cardHeight * 0.5),
            reason:
                'the tall break\'s Skip must be a bounded control, not a '
                'slab running the full height of the row (owner FAIL, '
                '2026-08-28). Card was ${cardHeight}dp, Skip ${skipHeight}dp.',
          );
        },
      );

      // Phase 32 (D-32-02, Task 1 — Kind A, retired-mechanism deletion):
      // three tests used to live here — 'SEEBREAK-01: sub-compact short
      // break renders two Dividers and the label...', '...restates the
      // duration in its semantics label', and '...renders shorter than
      // compact for the same break' — all three pumping
      // `ChunkCardDensity.subCompact`, the tier this task deletes outright
      // (not merely stops calling). There is no value to migrate: the
      // `_SubCompactRow` widget these tests asserted against no longer
      // exists, and the enum value itself is gone, so keeping any of them
      // would be asserting against a mechanism this phase's own charter
      // requires deleting, not weakening or repointing.

      // Phase 32 (D-32-02, Task 2 — Kind A, retired-mechanism deletion):
      // 'SEEBREAK-01 non-vacuity: compact short break still renders the
      // dashed painter and no Divider' asserted the OLD compact tier's
      // dashed-outline `CustomPaint` treatment, which this phase replaced
      // outright with a bordered Card + Skip rail (TAPBREAK-01/03). The
      // compact tier no longer renders any dashed painter at all — the
      // test's premise is gone, not merely its expected value. Deleted
      // rather than migrated, per this task's own instruction not to
      // repoint a Kind A test at a mechanism that no longer exists.

      // D-31-04 (Phase 31, SKIPBREAK-01): skipped-break rendering, reusing
      // _WorkChunkContent's existing resolved-state vocabulary
      // (Opacity(0.5) + TextDecoration.lineThrough) rather than inventing
      // a break-specific one. Phase 32 (D-32-02) note: this holds for the
      // full tier below, unchanged — the redesigned compact tier
      // (TAPBREAK-01/03) is the one exception, and carries its own updated
      // test further down documenting why. The sub-compact tier's own pair
      // of D-31-04 tests are retired along with the tier itself (Task 1,
      // Kind A) — see below.
      testWidgets(
        "D-31-04: a skipped full-tier break is muted, struck through, and "
        "reads 'skipped'",
        (tester) async {
          await pumpWithMood(
            tester,
            ChunkCard(
              chunk: _breakChunk(type: ChunkType.shortBreak, skipped: true),
              density: ChunkCardDensity.full,
            ),
          );
          final mutedOpacity = find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity == 0.5,
          );
          expect(
            find.descendant(
              of: find.byType(ChunkCard),
              matching: mutedOpacity,
            ),
            findsOneWidget,
          );
          final titleText = tester.widget<Text>(find.text('Short break'));
          expect(titleText.style?.decoration, TextDecoration.lineThrough);
          expect(find.text('skipped'), findsOneWidget);
          expect(find.text('5 min'), findsNothing);
        },
      );

      testWidgets(
        // Phase 32 (D-32-02, Task 1 — Kind C rewrite): "still reads its
        // duration" described the retired trailing-duration-text
        // arrangement. The full tier's own container/mute mechanism
        // (Opacity(0.5) + strikethrough) is unchanged by this phase — only
        // the trailing content changed, from duration/status text to the
        // same Skip rail the compact tier uses.
        // Phase 32 gap closure (G-32-02): same two repoints as the test
        // above — mechanism `BreakSkipButton` -> the shared
        // `OutlinedButton.icon`, and fixture corrected from the unreachable
        // 5-min-at-full-tier to a reachable long break. D-31-04's own claim
        // (an UNRESOLVED break carries no mute and no strikethrough) is
        // untouched and still the point of this test.
        'D-31-04: an unresolved full-tier break is unchanged — no muting, '
        'no strikethrough, and a tappable Skip instead of duration text',
        (tester) async {
          await pumpWithMood(
            tester,
            ChunkCard(
              chunk: _breakChunk(type: ChunkType.longBreak),
              density: ChunkCardDensity.full,
            ),
          );
          final mutedOpacity = find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity == 0.5,
          );
          expect(
            find.descendant(
              of: find.byType(ChunkCard),
              matching: mutedOpacity,
            ),
            findsNothing,
          );
          final titleText = tester.widget<Text>(find.text('Long break'));
          expect(titleText.style?.decoration, isNot(TextDecoration.lineThrough));
          expect(find.text('25 min'), findsNothing);
          expect(find.text('skipped'), findsNothing);
          expect(
            find.descendant(
              of: find.byType(ChunkCard),
              matching: find.byType(OutlinedButton),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        // Phase 32 (D-32-02, Task 2 — Kind C rewrite). The old assertions
        // (a whole-row Opacity(0.5) mute, and a single combined
        // Semantics(excludeSemantics: true) label restating title +
        // duration + ", skipped") both described the retired dashed-tier
        // treatment. The redesigned compact tier (TAPBREAK-01/03) signals
        // "resolved" differently: the title keeps its strikethrough, but
        // there is no whole-row mute, and the rail swaps from
        // BreakSkipButton to BreakSkippedIndicator's 'skipped' text
        // instead of carrying an extra combined semantics string — this
        // rewrite asserts the new signal, not a weakened version of the
        // old one.
        'D-31-04: a skipped compact break is struck through and its rail '
        'shows the resolved indicator, not the Skip button',
        (tester) async {
          await pumpWithMood(
            tester,
            ChunkCard(
              chunk: _breakChunk(type: ChunkType.shortBreak, skipped: true),
              density: ChunkCardDensity.compact,
            ),
          );
          final titleText = tester.widget<Text>(find.text('Short break'));
          expect(titleText.style?.decoration, TextDecoration.lineThrough);
          expect(
            find.descendant(
              of: find.byType(ChunkCard),
              matching: find.byType(BreakSkippedIndicator),
            ),
            findsOneWidget,
            reason: 'a skipped compact break must show the resolved '
                'indicator in its rail',
          );
          expect(
            find.descendant(
              of: find.byType(ChunkCard),
              matching: find.byType(BreakSkipButton),
            ),
            findsNothing,
            reason: 'a skipped break must never still show a tappable '
                'Skip button',
          );
        },
      );

      // Phase 32 (D-32-02, Task 1 — Kind A, retired-mechanism deletion):
      // 'D-31-04: a skipped sub-compact break...' and '...an unresolved
      // sub-compact break is byte-for-byte Phase 29's treatment' — both
      // pumped `ChunkCardDensity.subCompact`, the tier this task deletes.
      // Deleted with the tier, not repointed at the compact tier's own
      // already-covered assertions.
      //
      // The whole 'D-31-06 — the sub-compact grip glyph' group (3 cases)
      // is deleted for the same reason: `Icons.drag_indicator` inside
      // `_SubCompactRow` is gone with the class it lived in. Case C's own
      // load-bearing claim (the grip changes the row's height by exactly
      // zero pixels) has no subject left to prove once the grip and the
      // row it decorated are both retired.
    });

    testWidgets(
      'SwipeableChunkCard forwards density for a break '
      '(regression guard for the forgotten-forward failure mode)',
      (tester) async {
        await pumpWithMood(
          tester,
          SwipeableChunkCard(
            chunk: _breakChunk(type: ChunkType.shortBreak),
            density: ChunkCardDensity.compact,
          ),
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>.value(
              value: _FakeScheduleNotifier(),
            ),
          ],
        );
        expect(find.text('Short break'), findsOneWidget);
        expect(find.text('5 min'), findsNothing);
      },
    );

    // Phase 32 (D-32-02, Task 1 — Kind A, retired-mechanism deletion):
    // 'SEEBREAK-01: SwipeableChunkCard forwards subCompact for a break'
    // pumped `ChunkCardDensity.subCompact` and asserted the retired
    // `_SubCompactRow`'s two Dividers. Deleted with the tier.
  });

  group('Phase 31 — what a break still is not', () {
    // D-31-01 (locked, 31-UI-SPEC.md): a break is never tappable, never
    // completable, and never re-swipeable once skipped — the owner's
    // 2026-08-21 instruction, made checkable here rather than assumed.
    // Phase 32 (D-32-02, Task 1): `ChunkCardDensity.subCompact` dropped from
    // this list — the tier is retired, and this loop's own subject (a
    // break's onTap stays null regardless of density) is still fully
    // covered by the two remaining tiers.
    for (final density in [ChunkCardDensity.full, ChunkCardDensity.compact]) {
      testWidgets(
        "a break's ChunkCard receives a null onTap even when the caller "
        'supplies one (density: $density)',
        (tester) async {
          await pumpWithMood(
            tester,
            SwipeableChunkCard(
              chunk: _breakChunk(type: ChunkType.shortBreak),
              density: density,
              onTap: () {},
            ),
            extraProviders: [
              ChangeNotifierProvider<ScheduleNotifier>.value(
                value: _FakeScheduleNotifier(),
              ),
            ],
          );
          final chunkCard = tester.widget<ChunkCard>(find.byType(ChunkCard));
          expect(
            chunkCard.onTap,
            isNull,
            reason:
                "the owner's 2026-08-21 instruction: a break never becomes "
                'tappable at any density, even when the caller supplies a '
                'non-null onTap — the isWork gate in SwipeableChunkCard is '
                'the only thing enforcing this.',
          );
        },
      );
    }

    // Phase 32 (D-32-02, Task 2 — Kind A, retired-mechanism deletion):
    // three tests used to live here — "a break's Dismissible offers only
    // the skip direction", "a skipped break cannot be re-swiped", and "a
    // break never reaches markComplete" — all three constructing or
    // dragging a break's `Dismissible`. A break's `SwipeableChunkCard` no
    // longer builds a `Dismissible` at all (the restored early return
    // sends it straight to `ChunkCard`), so `find.byType(Dismissible)`
    // finds nothing for any of them — not a value change, a vanished
    // widget. Deleted outright, per this task's own instruction not to
    // migrate a Kind A test. The work-chunk-only invariants immediately
    // below (which use a WORK chunk, unaffected by this phase) are kept
    // unchanged, and the "never tappable" loop above them is also kept —
    // neither depends on the retired mechanism.
    testWidgets(
      "an unresolved WORK chunk's Dismissible still offers the full "
      "horizontal direction (paired guard — the break case above cannot "
      'pass by this widget silently losing the complete direction for '
      'everyone)',
      (tester) async {
        await pumpWithMood(
          tester,
          SwipeableChunkCard(chunk: _workChunk()),
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>.value(
              value: _FakeScheduleNotifier(),
            ),
          ],
        );
        final dismissible = tester.widget<Dismissible>(
          find.byType(Dismissible),
        );
        expect(dismissible.direction, DismissDirection.horizontal);
      },
    );
  });

  group('LiveRowCard — two density tiers (GRID-02)', () {
    Future<void> pumpLiveRowCard(
      WidgetTester tester, {
      String chunkId = 'chunk-1',
      String kicker = 'RIGHT NOW',
      String title = 'Deep work',
      String remainingLabel = '12 min left · until 10:50',
      double slotHeight = 100.0,
      bool showActions = true,
      bool showComplete = true,
      bool isSkipped = false,
      VoidCallback? onTap,
      // ScheduleNotifier, not _FakeScheduleNotifier: Phase 32's
      // throwing-repository test (`_ThrowingScheduleNotifier`) needs to
      // pass through this same helper.
      ScheduleNotifier? scheduleNotifier,
    }) async {
      await pumpWithMood(
        tester,
        LiveRowCard(
          chunkId: chunkId,
          kicker: kicker,
          title: title,
          remainingLabel: remainingLabel,
          slotHeight: slotHeight,
          showActions: showActions,
          showComplete: showComplete,
          isSkipped: isSkipped,
          onTap: onTap,
        ),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>.value(
            value: scheduleNotifier ?? _FakeScheduleNotifier(),
          ),
        ],
      );
    }

    testWidgets('renders the kicker "RIGHT NOW" when passed it', (
      tester,
    ) async {
      await pumpLiveRowCard(tester, kicker: 'RIGHT NOW');
      expect(find.text('RIGHT NOW'), findsOneWidget);
    });

    testWidgets("card background colour equals colorScheme.primaryContainer", (
      tester,
    ) async {
      await pumpLiveRowCard(tester);
      final context = tester.element(find.byType(LiveRowCard));
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, Theme.of(context).colorScheme.primaryContainer);
    });

    testWidgets('no arrow_forward icon and no "Now" pill badge', (
      tester,
    ) async {
      await pumpLiveRowCard(tester);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
      expect(find.text('Now'), findsNothing);
    });

    testWidgets(
      'compact tier renders title and remainingLabel verbatim, no '
      'LinearProgressIndicator',
      (tester) async {
        await pumpLiveRowCard(
          tester,
          slotHeight: 100.0,
          title: 'Deep work',
          remainingLabel: '12 min left · until 10:50',
        );
        expect(find.text('Deep work'), findsOneWidget);
        expect(find.text('12 min left · until 10:50'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'compact tier icon buttons carry the right icons and are at least the '
      '44dp WCAG touch target',
      (tester) async {
        await pumpLiveRowCard(tester, slotHeight: 100.0, showActions: true);
        final completeIcon = find.byIcon(Icons.check_circle_outline);
        final skipIcon = find.byIcon(Icons.skip_next_outlined);
        expect(completeIcon, findsOneWidget);
        expect(skipIcon, findsOneWidget);
        final completeButton = find.ancestor(
          of: completeIcon,
          matching: find.byType(IconButton),
        );
        final skipButton = find.ancestor(
          of: skipIcon,
          matching: find.byType(IconButton),
        );
        // Asserted against the named constant, not a literal, so the button
        // and the slot-height measurement derived from it cannot drift apart.
        expect(
          tester.getSize(completeButton),
          const Size(kLiveActionTouchTarget, kLiveActionTouchTarget),
        );
        expect(
          tester.getSize(skipButton),
          const Size(kLiveActionTouchTarget, kLiveActionTouchTarget),
        );
        // The floor is what actually matters to a thumb, and it is why these
        // grew from 36dp after UAT (2026-08-19) — this half of the assertion
        // stays meaningful even if the constant is retuned upward later.
        expect(kLiveActionTouchTarget, greaterThanOrEqualTo(44.0));
      },
    );

    testWidgets(
      'tier boundary: kCompactLiveMinHeight is compact, one dp below is '
      'single-line',
      (tester) async {
        await pumpLiveRowCard(tester, slotHeight: kCompactLiveMinHeight);
        expect(find.text('RIGHT NOW'), findsOneWidget);

        await pumpLiveRowCard(
          tester,
          slotHeight: kCompactLiveMinHeight - 1,
        );
        expect(find.text('RIGHT NOW'), findsNothing);
      },
    );

    testWidgets(
      'single-line tier renders title and remaining time, no kicker, no '
      'icon buttons, no progress bar',
      (tester) async {
        await pumpLiveRowCard(
          tester,
          slotHeight: 20.0,
          title: 'Deep work',
          remainingLabel: '12 min left · until 10:50',
        );
        expect(find.text('Deep work'), findsOneWidget);
        expect(find.text(' · 12 min left · until 10:50'), findsOneWidget);
        expect(find.textContaining('RIGHT NOW'), findsNothing);
        expect(find.byType(IconButton), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'single-line tier exposes the locked "Right now: ..." semantics label',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpLiveRowCard(
          tester,
          slotHeight: 20.0,
          title: 'Deep work',
          remainingLabel: '12 min left · until 10:50',
        );
        expect(
          find.bySemanticsLabel(
            'Right now: Deep work, 12 min left · until 10:50',
          ),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets('single-line tap fires onTap exactly once', (tester) async {
      var tapCount = 0;
      await pumpLiveRowCard(
        tester,
        slotHeight: 20.0,
        onTap: () => tapCount++,
      );
      await tester.tap(find.byType(Card));
      await tester.pump();
      expect(tapCount, 1);
    });

    testWidgets(
      // Phase 32 (D-32-02, Task 2 — Kind C rewrite, scoped not deleted):
      // this test's own subject ("the row itself is not tappable") is
      // still true and still worth asserting, but `pumpLiveRowCard`'s
      // `showActions` defaults to `true`, and the new Skip rail (gated on
      // `showActions`) renders its own `InkWell` regardless of `onTap` —
      // the old bare assertion would now find that rail InkWell and fail.
      // Scoped by pumping with actions disabled, so the row truly has no
      // interactive child of any kind.
      'single-line tier has no InkWell when onTap is null and no Skip rail '
      'is showing',
      (tester) async {
        await pumpLiveRowCard(
          tester,
          slotHeight: 20.0,
          onTap: null,
          showActions: false,
        );
        expect(find.byType(InkWell), findsNothing);
      },
    );

    testWidgets(
      'both tiers restate kCardLeftInset/kTimelineRowInset as Card margin',
      (tester) async {
        await pumpLiveRowCard(tester, slotHeight: 100.0);
        var card = tester.widget<Card>(find.byType(Card));
        var margin = card.margin! as EdgeInsets;
        expect(margin.left, kCardLeftInset);
        expect(margin.right, kTimelineRowInset);
        expect(
          card.shape,
          const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        );
        expect(card.elevation, 6);

        await pumpLiveRowCard(tester, slotHeight: 20.0);
        card = tester.widget<Card>(find.byType(Card));
        margin = card.margin! as EdgeInsets;
        expect(margin.left, kCardLeftInset);
        expect(margin.right, kTimelineRowInset);
        expect(
          card.shape,
          const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        );
        expect(card.elevation, 4);
      },
    );

    testWidgets('shows Complete/Skip buttons when showActions is true', (
      tester,
    ) async {
      await pumpLiveRowCard(tester, showActions: true);
      expect(find.byTooltip('Complete'), findsOneWidget);
      expect(find.byTooltip('Skip'), findsOneWidget);
    });

    testWidgets('hides Complete/Skip buttons when showActions is false', (
      tester,
    ) async {
      await pumpLiveRowCard(tester, showActions: false);
      expect(find.byTooltip('Complete'), findsNothing);
      expect(find.byTooltip('Skip'), findsNothing);
    });

    testWidgets('tapping Complete calls ScheduleNotifier.markComplete', (
      tester,
    ) async {
      final sn = _FakeScheduleNotifier();
      await pumpLiveRowCard(tester, chunkId: 'chunk-abc', scheduleNotifier: sn);
      await tester.tap(find.byTooltip('Complete'));
      await tester.pump();
      expect(sn.lastCompletedId, 'chunk-abc');
    });

    testWidgets('tapping Skip calls ScheduleNotifier.markSkipped', (
      tester,
    ) async {
      final sn = _FakeScheduleNotifier();
      await pumpLiveRowCard(tester, chunkId: 'chunk-xyz', scheduleNotifier: sn);
      await tester.tap(find.byTooltip('Skip'));
      await tester.pump();
      expect(sn.lastSkippedId, 'chunk-xyz');
    });

    group('D-31-07 — LiveRowCard Skip without Complete', () {
      testWidgets(
        'showComplete: false shows exactly one Skip tooltip and no Complete '
        'tooltip, as a descendant of LiveRowCard',
        (tester) async {
          await pumpLiveRowCard(
            tester,
            slotHeight: 100.0,
            showActions: true,
            showComplete: false,
          );
          final liveCard = find.byType(LiveRowCard);
          expect(
            find.descendant(
              of: liveCard,
              matching: find.byTooltip('Skip'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: liveCard,
              matching: find.byTooltip('Complete'),
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'showComplete: true (default) shows both tooltips — the regression '
        'guard for the live WORK chunk, which must stay green through every '
        'later D-31-07 edit',
        (tester) async {
          await pumpLiveRowCard(
            tester,
            slotHeight: 100.0,
            showActions: true,
            showComplete: true,
          );
          final liveCard = find.byType(LiveRowCard);
          expect(
            find.descendant(of: liveCard, matching: find.byTooltip('Skip')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: liveCard,
              matching: find.byTooltip('Complete'),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'showActions: false hides both tooltips and renders no IconButton at '
        'all — the pre-existing behaviour, unchanged',
        (tester) async {
          await pumpLiveRowCard(tester, slotHeight: 100.0, showActions: false);
          expect(find.byTooltip('Skip'), findsNothing);
          expect(find.byTooltip('Complete'), findsNothing);
          expect(find.byType(IconButton), findsNothing);
        },
      );

      testWidgets(
        'isSkipped strikes the title through with TextDecoration.lineThrough '
        'at BOTH density tiers, since each tier builds its own title Text',
        (tester) async {
          // Compact tier (slotHeight 100.0).
          await pumpLiveRowCard(
            tester,
            slotHeight: 100.0,
            title: 'Short break',
            isSkipped: true,
          );
          var titleText = tester.widget<Text>(find.text('Short break'));
          expect(titleText.style?.decoration, TextDecoration.lineThrough);

          await pumpLiveRowCard(
            tester,
            slotHeight: 100.0,
            title: 'Short break',
            isSkipped: false,
          );
          titleText = tester.widget<Text>(find.text('Short break'));
          expect(titleText.style?.decoration, isNot(TextDecoration.lineThrough));

          // Single-line tier (slotHeight 20.0).
          await pumpLiveRowCard(
            tester,
            slotHeight: 20.0,
            title: 'Short break',
            isSkipped: true,
          );
          titleText = tester.widget<Text>(find.text('Short break'));
          expect(titleText.style?.decoration, TextDecoration.lineThrough);

          await pumpLiveRowCard(
            tester,
            slotHeight: 20.0,
            title: 'Short break',
            isSkipped: false,
          );
          titleText = tester.widget<Text>(find.text('Short break'));
          expect(titleText.style?.decoration, isNot(TextDecoration.lineThrough));
        },
      );
    });

    group('Phase 32 (TAPBREAK-01) — the live single-line tier gains a Skip '
        'rail', () {
      testWidgets(
        // This is the regression this whole section of the phase exists
        // to prevent: without it, a running 5-minute break would ship with
        // ZERO way to skip it (D-32-02 deletes the swipe with no
        // substitute unless this tier gains one). The same test also
        // proves the excluding-Semantics-wrapper fix: the button's own
        // accessibility label must resolve independently, not be
        // swallowed by the title/countdown's excluding wrapper.
        'a live 5-minute break renders a tappable, screen-reader-reachable '
        'Skip rail — this row is NOT skip-less',
        (tester) async {
          final sn = _FakeScheduleNotifier();
          final handle = tester.ensureSemantics();
          await pumpLiveRowCard(
            tester,
            chunkId: 'break-1',
            title: 'Short break',
            slotHeight: 30.0,
            showActions: true,
            showComplete: false,
            scheduleNotifier: sn,
          );
          expect(
            find.descendant(
              of: find.byType(LiveRowCard),
              matching: find.byType(BreakSkipButton),
            ),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Skip Short break'),
            findsOneWidget,
            reason: 'the title/countdown excluding Semantics wrapper must '
                'not swallow the Skip button\'s own semantics node',
          );
          await tester.tap(find.byType(BreakSkipButton));
          await tester.pump();
          expect(sn.lastSkippedId, 'break-1');
          handle.dispose();
        },
      );

      testWidgets(
        'with a throwing repository the live break stays unresolved and '
        'its Skip rail stays visible and tappable (UI-SPEC E2 error)',
        (tester) async {
          final sn = _ThrowingScheduleNotifier();
          await pumpLiveRowCard(
            tester,
            chunkId: 'break-err',
            title: 'Short break',
            slotHeight: 30.0,
            showActions: true,
            showComplete: false,
            isSkipped: false,
            scheduleNotifier: sn,
          );
          // markSkipped's own WR-05 revert-and-rethrow is a pre-existing,
          // documented gap (32-RESEARCH.md): the button's onTap does not
          // await the call, so the rejection is a genuinely unhandled
          // async Future error, exactly as it would be in the running
          // app. `runZonedGuarded` captures it at the zone boundary
          // (rather than letting flutter_test's own zone report it as an
          // immediate hard test failure) so the test can acknowledge it
          // was thrown — proving the tap path was actually exercised —
          // without treating a known, documented gap as a fresh defect.
          Object? caught;
          await runZonedGuarded(() async {
            await tester.tap(find.byType(BreakSkipButton));
            await tester.pump();
          }, (error, stack) => caught = error);
          expect(caught, isNotNull);
          // LiveRowCard has no local state of its own — a real failure
          // leaves the chunk's isSkipped false upstream, so the next
          // build still passes isSkipped: false and the rail keeps
          // rendering the tappable Skip button, never the resolved
          // indicator.
          expect(
            find.descendant(
              of: find.byType(LiveRowCard),
              matching: find.byType(BreakSkipButton),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'at a realistic (430dp) row width the title still ellipses and the '
        'countdown still renders in full beside the 64dp Skip rail '
        '(UI-SPEC E2 overflow)',
        (tester) async {
          // 430dp matches this project's own established real-device
          // viewport convention (`timeline_geometry.dart`'s measurement
          // recipes: "viewport 430x930 at DPR 1").
          await tester.binding.setSurfaceSize(const Size(430, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          // Deliberately app-realistic lengths (matching the app's own
          // `_buildLiveRow` format, `today_screen.dart`), NOT an
          // artificially long stress string — `flutter test`'s placeholder
          // font already inflates glyph width well beyond real Roboto
          // metrics (this project's carried-forward invariant), so an
          // unrealistically long fixture would overflow for a harness
          // reason unrelated to the rail's own narrowing of the Expanded
          // region, which is what this test exists to isolate.
          const longTitle = 'Short break';
          const countdown = '4 min left';
          await pumpLiveRowCard(
            tester,
            title: longTitle,
            remainingLabel: countdown,
            slotHeight: 30.0,
            showActions: true,
            showComplete: false,
          );
          expect(tester.takeException(), isNull);
          final titleWidget = tester.widget<Text>(find.text(longTitle));
          expect(titleWidget.maxLines, 1);
          expect(titleWidget.overflow, TextOverflow.ellipsis);
          expect(
            find.text(' · $countdown'),
            findsOneWidget,
            reason: 'the countdown never truncates, even under the rail\'s '
                'narrower Expanded region',
          );
        },
      );
    });
  });
}
