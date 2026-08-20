// Widget tests for the Phase 22 Plan 02 Today-screen row vocabulary:
// TimelineRowTile (46dp time gutter), FreeTimeRow (named free time),
// ChunkCard's extended row treatments, and LiveRowCard (the swelled
// in-place current-activity card).
//
// Pure widget work — nothing here knows what time it is; the screen
// (plan 22-03) decides what's live and passes it in.

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

ScheduledChunk _breakChunk({required ChunkType type, bool completed = false}) =>
    ScheduledChunk(
      id: 'b1',
      chunkTypeIndex: type.index,
      durationMinutes: type == ChunkType.shortBreak ? 5 : 25,
    )..isCompleted = completed;

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

/// Phase 29 (SEEBREAK-01). Pumps [ChunkCard] wrapped in an unbounded-height
/// `OverflowBox`, mirroring `today_screen.dart`'s production wrapper (lines
/// ~807-811: `ClipRect` -> `OverflowBox(minHeight: 0, maxHeight:
/// double.infinity, alignment: topCenter)` -> `TimelineRowTile`).
///
/// Required for any height COMPARISON between densities: `pumpWithMood`
/// alone puts the card in `Scaffold(body:)`, which hands it a **bounded**
/// maxHeight — the compact tier's `Center` then expands to fill the whole
/// viewport, so `tester.getSize(find.byType(ChunkCard))` returns the screen
/// height at every density and any height comparison is silently
/// meaningless. Unbounded vertical constraints are also what production
/// actually gives the card, so this helper is the faithful harness, not a
/// workaround.
Future<void> _pumpBreakCardUnbounded(
  WidgetTester tester, {
  required ChunkCardDensity density,
  ChunkType type = ChunkType.shortBreak,
}) async {
  await pumpWithMood(
    tester,
    OverflowBox(
      minHeight: 0,
      maxHeight: double.infinity,
      alignment: Alignment.topCenter,
      child: ChunkCard(chunk: _breakChunk(type: type), density: density),
    ),
  );
}

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

    testWidgets('neither form renders a Card', (tester) async {
      await pumpWithMood(tester, const FreeTimeRow.until(untilMinutes: 480));
      expect(find.byType(Card), findsNothing);

      await pumpWithMood(tester, const FreeTimeRow.gap(durationMinutes: 100));
      expect(find.byType(Card), findsNothing);
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
    testWidgets('completed work chunk: struck through + primary check icon', (
      tester,
    ) async {
      await _pumpChunkCard(tester, _workChunk(completed: true));
      final titleText = tester.widget<Text>(find.text('Deep work'));
      expect(titleText.style?.decoration, TextDecoration.lineThrough);

      final context = tester.element(find.byType(ChunkCard));
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.color, Theme.of(context).colorScheme.primary);
    });

    testWidgets('skipped work chunk: struck through + literal "skipped" text', (
      tester,
    ) async {
      await _pumpChunkCard(tester, _workChunk(skipped: true));
      final titleText = tester.widget<Text>(find.text('Deep work'));
      expect(titleText.style?.decoration, TextDecoration.lineThrough);
      expect(find.text('skipped'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets(
      'unresolved work chunk: no strikethrough, unchecked icon, Complete/Skip present',
      (tester) async {
        await _pumpChunkCard(tester, _workChunk());
        final titleText = tester.widget<Text>(find.text('Deep work'));
        expect(titleText.style?.decoration, isNot(TextDecoration.lineThrough));
        expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
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

    testWidgets('short break: "Short break" label, no Card, dashed outline', (
      tester,
    ) async {
      await _pumpChunkCard(tester, _breakChunk(type: ChunkType.shortBreak));
      expect(find.text('Short break'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
      'long break: "Long break" label, same dashed vocabulary at greater weight (G-02)',
      (tester) async {
        await _pumpChunkCard(tester, _breakChunk(type: ChunkType.longBreak));
        expect(find.text('Long break'), findsOneWidget);
        expect(find.byType(Card), findsNothing);
        expect(find.byType(CustomPaint), findsWidgets);
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
      'no new interaction is added to the break row (G-02 prohibition)',
      (tester) async {
        await _pumpChunkCard(tester, _breakChunk(type: ChunkType.longBreak));
        expect(find.byType(GestureDetector), findsNothing);
        expect(find.byType(ExpansionTile), findsNothing);
        final customPaints = tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        );
        // None of the break row's CustomPaint ancestors carry a GestureDetector
        // — the row remains a plain, non-interactive Container + CustomPaint.
        expect(customPaints, isNotEmpty);
      },
    );

    testWidgets('completed break also renders the check icon', (tester) async {
      await _pumpChunkCard(
        tester,
        _breakChunk(type: ChunkType.shortBreak, completed: true),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

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
        'full short break renders both the label and its duration text',
        (tester) async {
          await pumpWithMood(
            tester,
            ChunkCard(
              chunk: _breakChunk(type: ChunkType.shortBreak),
              density: ChunkCardDensity.full,
            ),
          );
          expect(find.text('Short break'), findsOneWidget);
          expect(find.text('5 min'), findsOneWidget);
        },
      );

      testWidgets(
        'SEEBREAK-01: sub-compact short break renders two Dividers and the '
        'label, no dashed border, no duration text',
        (tester) async {
          await pumpWithMood(
            tester,
            ChunkCard(
              chunk: _breakChunk(type: ChunkType.shortBreak),
              density: ChunkCardDensity.subCompact,
            ),
          );
          expect(find.text('Short break'), findsOneWidget);
          expect(find.text('5 min'), findsNothing);
          expect(
            find.descendant(
              of: find.byType(ChunkCard),
              matching: find.byType(Divider),
            ),
            findsNWidgets(2),
          );
          // PD-29-08: do NOT also assert find.byType(Card), findsNothing —
          // breaks never build a Card at any density, so that assertion
          // could not fail (STATE.md's "assertion that could not fail"
          // class).
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
        'SEEBREAK-01: sub-compact short break restates the duration in its '
        'semantics label',
        (tester) async {
          final handle = tester.ensureSemantics();
          await pumpWithMood(
            tester,
            ChunkCard(
              chunk: _breakChunk(type: ChunkType.shortBreak),
              density: ChunkCardDensity.subCompact,
            ),
          );
          expect(
            find.bySemanticsLabel('Short break, 5 min'),
            findsOneWidget,
          );
          handle.dispose();
        },
      );

      testWidgets(
        'SEEBREAK-01: sub-compact renders shorter than compact for the same '
        'break',
        (tester) async {
          // Relative claim, deliberately (PD-29-06): both numbers come from
          // the same placeholder-font harness so the bias cancels, whereas
          // an absolute "fits in 20dp" assertion here would be optimistic —
          // the harness's line box is fontSize-tall with no real Roboto
          // ascent/descent, so it would pass while a real device clips.
          // Absolute fit is 29-04's real-browser job.
          await _pumpBreakCardUnbounded(
            tester,
            density: ChunkCardDensity.compact,
          );
          final compactHeight = tester
              .getSize(find.byType(ChunkCard))
              .height;

          await _pumpBreakCardUnbounded(
            tester,
            density: ChunkCardDensity.subCompact,
          );
          final subCompactHeight = tester
              .getSize(find.byType(ChunkCard))
              .height;

          expect(
            subCompactHeight,
            lessThan(compactHeight),
            reason:
                'harness bounds (placeholder font, NOT a device requirement): '
                'compact=$compactHeight subCompact=$subCompactHeight',
          );
        },
      );

      testWidgets(
        'SEEBREAK-01 non-vacuity: compact short break still renders the '
        'dashed painter and no Divider',
        (tester) async {
          // GUARD — proves Test 1's finders are not vacuous (a predicate
          // that matches nothing anywhere would make that test pass for the
          // wrong reason). Must stay GREEN before and after the wiring.
          await pumpWithMood(
            tester,
            ChunkCard(
              chunk: _breakChunk(type: ChunkType.shortBreak),
              density: ChunkCardDensity.compact,
            ),
          );
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is CustomPaint &&
                  w.painter != null &&
                  w.painter.runtimeType.toString().contains('DashedBorder'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byType(ChunkCard),
              matching: find.byType(Divider),
            ),
            findsNothing,
          );
        },
      );
    });

    testWidgets(
      'SwipeableChunkCard forwards density on the break early-return path '
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

    testWidgets(
      'SEEBREAK-01: SwipeableChunkCard forwards subCompact on the break '
      'early-return path',
      (tester) async {
        // RESEARCH assumption A2 (full-file re-grep, not targeted): `grep -n
        // "ChunkCardDensity\|density"
        // lib/screens/schedule/widgets/swipeable_chunk_card.dart` over the
        // WHOLE file shows two forwarding sites (the break early-return at
        // ~line 79-81, and the Dismissible's `child: ChunkCard(...)` at
        // ~line 123-132) — neither branches on a specific density value,
        // both just forward the `density:` parameter through unmodified.
        // Confirmed: no source change is needed in that file.
        await pumpWithMood(
          tester,
          SwipeableChunkCard(
            chunk: _breakChunk(type: ChunkType.shortBreak),
            density: ChunkCardDensity.subCompact,
          ),
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>.value(
              value: _FakeScheduleNotifier(),
            ),
          ],
        );
        expect(find.text('Short break'), findsOneWidget);
        expect(find.text('5 min'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(SwipeableChunkCard),
            matching: find.byType(Divider),
          ),
          findsNWidgets(2),
        );
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
      VoidCallback? onTap,
      _FakeScheduleNotifier? scheduleNotifier,
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

    testWidgets('single-line tier has no InkWell when onTap is null', (
      tester,
    ) async {
      await pumpLiveRowCard(tester, slotHeight: 20.0, onTap: null);
      expect(find.byType(InkWell), findsNothing);
    });

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
  });
}
