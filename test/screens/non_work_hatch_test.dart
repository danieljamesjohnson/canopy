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

import 'dart:math' as math;

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

/// Euclidean distance between two colours in 0-255 RGB. Crude on purpose —
/// see the comment at its call site for why "which channel carries the
/// difference" is the wrong question to ask here.
double _rgbDistance(Color a, Color b) {
  final dr = (a.r - b.r) * 255, dg = (a.g - b.g) * 255, db = (a.b - b.b) * 255;
  return math.sqrt(dr * dr + dg * dg + db * db);
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

    // Tests 7 and 8 are INVERTED from what they asserted on 2026-09-02, and
    // that inversion is the third pass: "i still feel like free time and
    // break look too similar." A break was hatched too (first in the same
    // neutral tone, then in its own hue); it is now a tinted card carrying no
    // hatch at all, which is what he asked for in the first place — "the
    // hatch should only be during free time."
    testWidgets('7. a short break does NOT carry it (compact tier)', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        ChunkCard(
          chunk: _chunk(ChunkType.shortBreak, 5),
          density: ChunkCardDensity.compact,
        ),
      );
      expect(find.byType(HatchFill), findsNothing);
    });

    testWidgets('8. a long break does NOT carry it (full tier)', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        ChunkCard(
          chunk: _chunk(ChunkType.longBreak, 30),
          density: ChunkCardDensity.full,
        ),
      );
      expect(find.byType(HatchFill), findsNothing);
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

  group('free time and a break do not look alike (the third pass)', () {
    // 2026-09-03: "i still feel like free time and break look too similar."
    //
    // The two earlier passes both spent the difference on TEXTURE — same
    // fill, different stripes — and both were judged too similar by the only
    // instrument that counts. These assertions moved to the FILL with them,
    // and they are deliberately about what a person perceives (hue distance,
    // lightness gap) rather than "the two tokens are not identical", which is
    // what the previous version proved while the screen still looked wrong.
    testWidgets('12. the two fills differ by hue AND by lightness', (
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
        final freeFill = _cardColor(tester)!;

        await _pumpCard(
          tester,
          ChunkCard(
            chunk: _chunk(ChunkType.longBreak, 30),
            density: ChunkCardDensity.full,
          ),
          moodIndex: mood,
        );
        final breakFill = _cardColor(tester)!;

        // **Distance, not hue.** A hue-only threshold was written here first
        // and it FAILED at mood 1 — where the two tokens sit 9.3° apart yet
        // are plainly different on screen: rgb(235,238,243), a near-white
        // grey, against rgb(211,229,245), a pale blue. The difference an eye
        // gets there is carried by saturation (0.25 → 0.63) and lightness,
        // not by hue rotation. Asserting hue would have rejected a pair that
        // works and pushed the design toward a number instead of a look.
        //
        // Crude Euclidean RGB distance is the honest measure for this claim:
        // it is blind to WHICH channel carries the difference, which is the
        // point. The two rejected passes both scored 0 here — identical
        // fills, the whole complaint.
        expect(
          _rgbDistance(freeFill, breakFill),
          greaterThan(20),
          reason:
              'mood $mood: free time and a break are the same colour '
              '($freeFill vs $breakFill)',
        );
        expect(
          HSLColor.fromColor(freeFill).lightness -
              HSLColor.fromColor(breakFill).lightness,
          greaterThan(0.02),
          reason: 'mood $mood: the break fill must also be visibly darker',
        );
      }
    });

    testWidgets('13. only free time is hatched — his original instruction', (
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
      // Its tone is the neutral one, and there is now no other.
      expect(
        _hatchColor(tester),
        HatchFill.freeTimeLines(
          ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4A8C7A),
            ),
          ).colorScheme,
        ),
      );
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
      '11. the three kinds of time take three different container tokens',
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
        expect(_cardColor(tester), scheme.secondaryContainer);

        await _pumpCard(
          tester,
          const SizedBox(
            height: 300,
            child: FreeTimeRow.until(untilMinutes: 480),
          ),
        );
        expect(_cardColor(tester), scheme.surfaceContainer);
      },
    );

    testWidgets('14. a break tier does not change its fill between tiers', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        ChunkCard(
          chunk: _chunk(ChunkType.shortBreak, 5),
          density: ChunkCardDensity.compact,
        ),
      );
      final shortFill = _cardColor(tester);

      await _pumpCard(
        tester,
        ChunkCard(
          chunk: _chunk(ChunkType.longBreak, 30),
          density: ChunkCardDensity.full,
        ),
      );
      expect(_cardColor(tester), shortFill);
    });
  });
}
