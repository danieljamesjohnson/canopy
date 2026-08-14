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
      expect(kGutterWidth, 52.0);
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
    // G-01 (26-UAT.md, fixed 26-07-PLAN.md): the chip's copy is
    // formatMinutesCompact, not the longer "Now · <time>" string that
    // could not fit kGutterWidth and shipped the occlusion bug.
    testWidgets('renders the locked compact chip copy "2:47p"', (
      tester,
    ) async {
      await pumpWithMood(tester, const NowLineOverlay(nowMinutes: 887));
      expect(find.text('2:47p'), findsOneWidget);
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

    // The calendar terminus dot. Its left edge must land on the content
    // edge (16dp row inset + kGutterWidth) so it never overlaps the
    // gutter-confined chip — both are colorScheme.primary, so an overlap
    // would read as a lump on the chip rather than as a distinct dot.
    testWidgets('renders a circular primary-colored dot at the content edge', (
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
      expect(
        tester.getTopLeft(dotFinder).dx - overlayLeft,
        16 + kGutterWidth,
      );
    });

    // The dot is part of the rule, not the chip: it must survive the
    // live-row suppression that hides the chip (G-03).
    testWidgets('the dot still renders when showChip is false', (tester) async {
      await pumpWithMood(
        tester,
        const NowLineOverlay(nowMinutes: 887, showChip: false),
      );
      expect(find.text('2:47p'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(NowLineOverlay),
          matching: find.byWidgetPredicate((w) {
            if (w is! Container) return false;
            final d = w.decoration;
            return d is BoxDecoration && d.shape == BoxShape.circle;
          }),
        ),
        findsOneWidget,
      );
    });
  });

  group('HourAxisLine (CAL-01 hour axis)', () {
    testWidgets('renders "9 AM" for hourMinutes 540', (tester) async {
      await pumpWithMood(tester, const HourAxisLine(hourMinutes: 540));
      expect(find.text('9 AM'), findsOneWidget);
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
  });

  group('LiveRowCard (D-01, Phase 23 seam)', () {
    Future<void> pumpLiveRowCard(
      WidgetTester tester, {
      String chunkId = 'chunk-1',
      String kicker = 'RIGHT NOW',
      String title = 'Deep work',
      String remainingLabel = '12 min left · until 10:50',
      double progress = 0.4,
      String? nextLine = 'Next · Reading at 10:50am',
      bool showActions = true,
      _FakeScheduleNotifier? scheduleNotifier,
    }) async {
      await pumpWithMood(
        tester,
        LiveRowCard(
          chunkId: chunkId,
          kicker: kicker,
          title: title,
          remainingLabel: remainingLabel,
          progress: progress,
          nextLine: nextLine,
          showActions: showActions,
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

    testWidgets('renders title, remainingLabel and nextLine verbatim', (
      tester,
    ) async {
      await pumpLiveRowCard(
        tester,
        title: 'Deep work',
        remainingLabel: '12 min left · until 10:50',
        nextLine: 'Next · Reading at 10:50am',
      );
      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('12 min left · until 10:50'), findsOneWidget);
      expect(find.text('Next · Reading at 10:50am'), findsOneWidget);
    });

    testWidgets('renders no next-line text when nextLine is null', (
      tester,
    ) async {
      await pumpLiveRowCard(tester, nextLine: null);
      expect(find.textContaining('Next ·'), findsNothing);
    });

    testWidgets("card background colour equals colorScheme.primaryContainer", (
      tester,
    ) async {
      await pumpLiveRowCard(tester);
      final context = tester.element(find.byType(LiveRowCard));
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, Theme.of(context).colorScheme.primaryContainer);
    });

    testWidgets('shows Complete/Skip buttons when showActions is true', (
      tester,
    ) async {
      await pumpLiveRowCard(tester, showActions: true);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('hides Complete/Skip buttons when showActions is false', (
      tester,
    ) async {
      await pumpLiveRowCard(tester, showActions: false);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('tapping Complete calls ScheduleNotifier.markComplete', (
      tester,
    ) async {
      final sn = _FakeScheduleNotifier();
      await pumpLiveRowCard(tester, chunkId: 'chunk-abc', scheduleNotifier: sn);
      await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
      await tester.pump();
      expect(sn.lastCompletedId, 'chunk-abc');
    });

    testWidgets('tapping Skip calls ScheduleNotifier.markSkipped', (
      tester,
    ) async {
      final sn = _FakeScheduleNotifier();
      await pumpLiveRowCard(tester, chunkId: 'chunk-xyz', scheduleNotifier: sn);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
      await tester.pump();
      expect(sn.lastSkippedId, 'chunk-xyz');
    });

    testWidgets('LinearProgressIndicator value equals the passed progress', (
      tester,
    ) async {
      await pumpLiveRowCard(tester, progress: 0.4);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.4);
    });

    testWidgets('progress 1.5 is clamped to 1.0', (tester) async {
      await pumpLiveRowCard(tester, progress: 1.5);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 1.0);
    });

    testWidgets('progress -0.2 is clamped to 0.0', (tester) async {
      await pumpLiveRowCard(tester, progress: -0.2);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.0);
    });

    testWidgets('no arrow_forward icon and no "Now" pill badge', (
      tester,
    ) async {
      await pumpLiveRowCard(tester);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
      expect(find.text('Now'), findsNothing);
    });
  });
}
