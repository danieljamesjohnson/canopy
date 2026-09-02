// Phase 33 gap closure — the owner's verdict of 2026-09-02 (`33-UAT.md`).
//
// Two sentences, one rule:
//
//   "i wanted the breaks to have the diagonal lines in them like the sketch"
//   "i think side project should have a color not the same as a break"
//
// Diagonals mean **not work**; work is the solid, brighter card. Before this
// closure the work card, the break card and the free-time card all rendered
// `surfaceContainer` with the same border and radius, and none of them had a
// hatch — sketch 003's `repeating-linear-gradient(135deg, …)` was dropped when
// `FreeTimeRow` copied the break card's surface verbatim.
//
// **On what these tests are worth.** `find.byType` compares `runtimeType`
// exactly (CLAUDE.md, "assertions that cannot fail"), which is what makes the
// presence checks below honest for `HatchFill` — it is a concrete leaf widget
// with no subclasses, so a match is the real thing. Each assertion here was
// mutation-checked against the pre-closure code and observed RED; the colour
// pair in particular is the one that pins the owner's actual complaint, since
// a hatch could ship while all three fills stayed identical.

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:canopy/screens/today/widgets/free_time_row.dart';
import 'package:canopy/widgets/hatch_fill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

/// Stubs `init()` to avoid Hive I/O — the break card reads a
/// `ScheduleNotifier` from context for its Skip control (per-file fake
/// convention, `lattice_break_pair_test.dart:39`).
class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}
}

ScheduledChunk _chunk(ChunkType type, int minutes) => ScheduledChunk(
  chunkTypeIndex: type.index,
  goalId: type == ChunkType.work ? 'g1' : null,
  durationMinutes: minutes,
  rationale: 'test',
);

Future<void> _pumpCard(
  WidgetTester tester,
  Widget card, {
  int moodIndex = 3,
}) async {
  await pumpWithMood(
    tester,
    card,
    moodIndex: moodIndex,
    extraProviders: [
      ChangeNotifierProvider<ScheduleNotifier>.value(
        value: _FakeScheduleNotifier(),
      ),
    ],
  );
  await tester.pump();
}

/// The card's own `Card`, which owns the fill under test.
Color? _cardColor(WidgetTester tester) =>
    tester.widgetList<Card>(find.byType(Card)).first.color;

/// The colour the hatch is actually PAINTED in — read off the live
/// [HatchPainter] rather than off `HatchFill.lineColor`, which is null at the
/// free-time call site (it resolves its default inside `build`). Reading the
/// painter is what makes the two-tone assertions below true of the screen
/// instead of true of the constructor arguments.
Color _hatchColor(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(HatchFill),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  return (paint.painter! as HatchPainter).color;
}

/// Shortest angular distance between two hues, in degrees. Wraparound is the
/// point: 350° and 10° are 20° apart, not 340°.
double _hueDistance(Color a, Color b) {
  final d = (HSLColor.fromColor(a).hue - HSLColor.fromColor(b).hue).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  group('hatchSegments — geometry, asserted directly', () {
    test(
      '1. neighbouring lines sit exactly `spacing` apart, perpendicular',
      () {
        const spacing = 12.0;
        final segments = hatchSegments(const Size(200, 150), spacing);
        expect(segments.length, greaterThan(3));

        // Each line satisfies x - y = c, so c is the segment's start x. The
        // perpendicular gap between two such lines is |dc| / sqrt(2) — the
        // reason `hatchSegments` steps c by `spacing * sqrt(2)` rather than by
        // `spacing`. Stepping by `spacing` would draw them ~1.41x too close,
        // which no "is it hatched" assertion could ever catch.
        for (var i = 1; i < segments.length; i++) {
          final dc = segments[i].$1.dx - segments[i - 1].$1.dx;
          expect(dc / 1.4142135623730951, closeTo(spacing, 0.001));
        }
      },
    );

    test('2. lines run top-left to bottom-right at 45 degrees', () {
      for (final (start, end) in hatchSegments(const Size(200, 150), 12)) {
        expect(end.dx - start.dx, closeTo(end.dy - start.dy, 0.001));
        expect(end.dy, greaterThan(start.dy));
      }
    });

    test('3. the band spans the whole box — both corners are covered', () {
      const size = Size(200, 150);
      final segments = hatchSegments(size, 12);
      // A line through the bottom-left corner has c = -height; one through
      // the top-right has c = width. Anything narrower leaves a bare
      // triangle in a corner of the card.
      expect(segments.first.$1.dx, lessThanOrEqualTo(-size.height));
      expect(segments.last.$1.dx, greaterThan(size.width - 12 * 1.415));
    });

    test('4. degenerate inputs draw nothing rather than looping forever', () {
      expect(hatchSegments(Size.zero, 12), isEmpty);
      expect(hatchSegments(const Size(200, 150), 0), isEmpty);
      expect(hatchSegments(const Size(200, 150), -4), isEmpty);
    });

    test('5. the painter repaints when its inputs change', () {
      const a = HatchPainter(color: Color(0xFF000000));
      expect(
        a.shouldRepaint(const HatchPainter(color: Color(0xFF000000))),
        isFalse,
      );
      expect(
        a.shouldRepaint(const HatchPainter(color: Color(0xFFFF0000))),
        isTrue,
      );
      expect(
        a.shouldRepaint(
          const HatchPainter(color: Color(0xFF000000), spacing: 20),
        ),
        isTrue,
      );
    });
  });

  group('the hatch is on every non-work block, and only those', () {
    testWidgets('6. free time carries it (the sketch\'s own treatment)', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        const SizedBox(
          height: 300,
          child: FreeTimeRow.until(untilMinutes: 480),
        ),
      );
      expect(find.byType(HatchFill), findsOneWidget);
    });

    testWidgets('7. a short break carries it (compact tier, 30dp slot)', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        ChunkCard(
          chunk: _chunk(ChunkType.shortBreak, 5),
          density: ChunkCardDensity.compact,
        ),
      );
      expect(find.byType(HatchFill), findsOneWidget);
    });

    testWidgets('8. a long break carries it (full tier, 180dp slot)', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        ChunkCard(
          chunk: _chunk(ChunkType.longBreak, 30),
          density: ChunkCardDensity.full,
        ),
      );
      expect(find.byType(HatchFill), findsOneWidget);
    });

    testWidgets('9. a work chunk does NOT — that is what the hatch means', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        ChunkCard(
          chunk: _chunk(ChunkType.work, 25),
          density: ChunkCardDensity.full,
        ),
      );
      expect(find.byType(HatchFill), findsNothing);
    });
  });

  group('free time and a break hatch in DIFFERENT tones', () {
    // His follow-up ruling, 2026-09-02: "the hatch should only be during free
    // time. breaks and short breaks should be something different. can use a
    // hatch maybe? but a different color." The first pass gave both the same
    // neutral lines, which made the pair LESS separable than before — the
    // question 33-UAT.md item 2 asks out loud.
    testWidgets('12. the two hatch tones differ, at three mood seeds', (
      tester,
    ) async {
      for (final mood in [1, 3, 5]) {
        await _pumpCard(
          tester,
          const SizedBox(
            height: 300,
            child: FreeTimeRow.until(untilMinutes: 480),
          ),
          moodIndex: mood,
        );
        final freeTone = _hatchColor(tester);

        await _pumpCard(
          tester,
          ChunkCard(
            chunk: _chunk(ChunkType.longBreak, 30),
            density: ChunkCardDensity.full,
          ),
          moodIndex: mood,
        );
        final breakTone = _hatchColor(tester);

        expect(
          freeTone,
          isNot(equals(breakTone)),
          reason: 'mood $mood: free time and a break hatch identically',
        );
        // Not merely "different values": a different HUE, by a distance an
        // eye can see. This is the assertion that did real work — it caught
        // `secondary`, the first choice, which is the neutral-VARIANT hue and
        // lands within 2-4 degrees of `onSurfaceVariant` at every seed. That
        // would have been two colours in the source and one grey on the
        // screen, and `isNot(equals)` above would have passed it happily.
        expect(
          _hueDistance(freeTone, breakTone),
          greaterThan(25),
          reason:
              'mood $mood: the break tone is the same hue as free time — '
              'it will read as the same grey however it is written',
        );
      }
    });

    testWidgets('13. short and long breaks share the one break tone', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        ChunkCard(
          chunk: _chunk(ChunkType.shortBreak, 5),
          density: ChunkCardDensity.compact,
        ),
      );
      final shortTone = _hatchColor(tester);

      await _pumpCard(
        tester,
        ChunkCard(
          chunk: _chunk(ChunkType.longBreak, 30),
          density: ChunkCardDensity.full,
        ),
      );
      expect(_hatchColor(tester), shortTone);
    });
  });

  group('work and break do not share a fill (the second sentence)', () {
    testWidgets('10. the two fills differ, at three separate mood seeds', (
      tester,
    ) async {
      // Swept across seeds because the whole palette is re-derived from the
      // day's mood (`ThemeNotifier.currentTheme`): a difference that held at
      // one seed and collapsed at another would be a fill that is "the same
      // as a break" on some days, which is the reported defect.
      for (final mood in [1, 3, 5]) {
        await _pumpCard(
          tester,
          ChunkCard(
            chunk: _chunk(ChunkType.work, 25),
            density: ChunkCardDensity.full,
          ),
          moodIndex: mood,
        );
        final workFill = _cardColor(tester);

        await _pumpCard(
          tester,
          ChunkCard(
            chunk: _chunk(ChunkType.longBreak, 30),
            density: ChunkCardDensity.full,
          ),
          moodIndex: mood,
        );
        final breakFill = _cardColor(tester);

        expect(
          workFill,
          isNot(equals(breakFill)),
          reason: 'mood $mood: work and break render the same fill',
        );
      }
    });

    testWidgets(
      '11. work takes surfaceContainerLowest, break stays surfaceContainer',
      (tester) async {
        final scheme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A8C7A)),
        ).colorScheme;

        await _pumpCard(
          tester,
          ChunkCard(
            chunk: _chunk(ChunkType.work, 25),
            density: ChunkCardDensity.full,
          ),
        );
        expect(_cardColor(tester), scheme.surfaceContainerLowest);

        await _pumpCard(
          tester,
          ChunkCard(
            chunk: _chunk(ChunkType.longBreak, 30),
            density: ChunkCardDensity.full,
          ),
        );
        expect(_cardColor(tester), scheme.surfaceContainer);
      },
    );
  });
}
