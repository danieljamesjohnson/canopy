// Widget tests for the imported-commitment glyph on the Today timeline —
// Phase 35 Plan 06 Task 2 (D-35-11, 35-UI-SPEC.md §4).
//
// Two CLAUDE.md-documented traps checked against every assertion below:
//   1. find.byType(X) compares runtimeType exactly and does not match
//      subclasses — role assertions here use find.byWidgetPredicate/
//      find.byIcon instead.
//   2. A tight-constrained harness (SizedBox(height: N) directly around
//      ChunkCard) reports the right number for the wrong reason. The
//      compact-density height assertion below pumps through
//      TimelineRowTile — production's own `Row(crossAxisAlignment: start) +
//      Expanded(child)` — matching today_row_widgets_test.dart's
//      established "the card fills its allocated slot" harness, not a bare
//      SizedBox wrapping ChunkCard directly.

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:canopy/screens/schedule/widgets/chunk_detail_sheet.dart';
import 'package:canopy/screens/today/timeline_geometry.dart';
import 'package:canopy/screens/today/widgets/timeline_row_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

/// A commitment-anchored work chunk — `commitmentId` non-null is what makes
/// `isCommitment` true in `chunk_card.dart` (`isImportedCommitment` itself
/// is resolved by the CALLER via `today_screen._lookupIsImportedCommitment`,
/// not derived here; this file pumps `ChunkCard` directly and passes the
/// flag straight in, exactly as `SwipeableChunkCard` forwards it).
ScheduledChunk _commitmentChunk({int durationMinutes = 30}) => ScheduledChunk(
  id: 'c1',
  chunkTypeIndex: ChunkType.work.index,
  commitmentId: 'commitment-1',
  durationMinutes: durationMinutes,
  anchoredStartMinutes: 540,
  rationale: 'Team standup',
);

/// A goal-anchored work chunk — `commitmentId` null, exactly what
/// `today_screen._lookupIsImportedCommitment` short-circuits to false for
/// without ever touching the notifier (behavior: "no lookup crash when the
/// block list is empty").
ScheduledChunk _goalChunk({int durationMinutes = 30}) => ScheduledChunk(
  id: 'g1',
  chunkTypeIndex: ChunkType.work.index,
  goalId: 'goal-1',
  durationMinutes: durationMinutes,
  syntheticStartMinutes: 540,
  rationale: 'Deep work',
);

/// Minimal fake — chunk_card_hover_test.dart's established shape. ChunkCard
/// itself never reads ScheduleNotifier directly at build time except via
/// the action row's `context.read<ScheduleNotifier>()` inside its button
/// callbacks, which these tests never tap.
class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}
}

Future<void> _pumpCard(
  WidgetTester tester,
  ScheduledChunk chunk, {
  required ChunkCardDensity density,
  required bool isImportedCommitment,
}) async {
  await pumpWithMood(
    tester,
    ChunkCard(
      chunk: chunk,
      density: density,
      isImportedCommitment: isImportedCommitment,
    ),
    extraProviders: [
      ChangeNotifierProvider<ScheduleNotifier>.value(
        value: _FakeScheduleNotifier(),
      ),
    ],
  );
}

/// Pumps [chunk] at [ChunkCardDensity.compact] through [TimelineRowTile] —
/// production's own wrapper, per today_row_widgets_test.dart's established
/// "the card fills its allocated slot" harness (CLAUDE.md trap 2). Returns
/// the measured [Card] height.
Future<double> _pumpCompactHeightThroughProduction(
  WidgetTester tester,
  ScheduledChunk chunk, {
  required bool isImportedCommitment,
}) async {
  await pumpWithMood(
    tester,
    SizedBox(
      height: chunk.durationMinutes * kPixelsPerMinute,
      child: TimelineRowTile(
        child: ChunkCard(
          chunk: chunk,
          density: ChunkCardDensity.compact,
          isImportedCommitment: isImportedCommitment,
        ),
      ),
    ),
    extraProviders: [
      ChangeNotifierProvider<ScheduleNotifier>.value(
        value: _FakeScheduleNotifier(),
      ),
    ],
  );
  return tester.getSize(find.byType(Card)).height;
}

bool _hasImportedGlyph() => find
    .byWidgetPredicate(
      (w) => w is Icon && w.icon == Icons.calendar_today_outlined,
    )
    .evaluate()
    .isNotEmpty;

void main() {
  group('Imported commitment glyph — detailed/full densities (D-35-11)', () {
    testWidgets(
      'a commitment chunk whose block is imported, pumped at detailed '
      'density: the glyph renders with its semantics label',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpCard(
          tester,
          _commitmentChunk(),
          density: ChunkCardDensity.detailed,
          isImportedCommitment: true,
        );
        expect(_hasImportedGlyph(), isTrue);
        expect(
          find.bySemanticsLabel(RegExp('Imported from your calendar')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'the same chunk at full density: the glyph renders',
      (tester) async {
        await _pumpCard(
          tester,
          _commitmentChunk(),
          density: ChunkCardDensity.full,
          isImportedCommitment: true,
        );
        expect(_hasImportedGlyph(), isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a commitment chunk whose block is hand-entered: no glyph at detailed '
      'or full density',
      (tester) async {
        await _pumpCard(
          tester,
          _commitmentChunk(),
          density: ChunkCardDensity.detailed,
          isImportedCommitment: false,
        );
        expect(_hasImportedGlyph(), isFalse);

        await _pumpCard(
          tester,
          _commitmentChunk(),
          density: ChunkCardDensity.full,
          isImportedCommitment: false,
        );
        expect(_hasImportedGlyph(), isFalse);
      },
    );

    testWidgets(
      'a work chunk with no commitmentId: no glyph, no crash, at any '
      'density',
      (tester) async {
        for (final density in ChunkCardDensity.values) {
          await _pumpCard(
            tester,
            _goalChunk(),
            density: density,
            // The caller (today_screen) would resolve this to false via
            // _lookupIsImportedCommitment without ever reaching the
            // notifier for a null commitmentId — this test asserts the
            // card itself is equally inert when handed false directly.
            isImportedCommitment: false,
          );
          expect(_hasImportedGlyph(), isFalse);
          expect(tester.takeException(), isNull);
        }
      },
    );
  });

  group('Imported commitment glyph — compact density omission (D-35-11)', () {
    testWidgets(
      'the same chunk at compact density: the glyph does not render',
      (tester) async {
        await _pumpCard(
          tester,
          _commitmentChunk(),
          density: ChunkCardDensity.compact,
          isImportedCommitment: true,
        );
        expect(
          _hasImportedGlyph(),
          isFalse,
          reason:
              'compact omits the glyph unconditionally — the content '
              'degrades by tier, never the box (this file\'s own rule)',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      "the card's measured compact height is identical with and without "
      'isImportedCommitment — the box never grows to fit the glyph',
      (tester) async {
        final withGlyphFlag = await _pumpCompactHeightThroughProduction(
          tester,
          _commitmentChunk(),
          isImportedCommitment: true,
        );
        final withoutGlyphFlag = await _pumpCompactHeightThroughProduction(
          tester,
          _commitmentChunk(),
          isImportedCommitment: false,
        );
        expect(withGlyphFlag, withoutGlyphFlag);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ChunkDetailSheet header (D-35-11, UI-SPEC §4)', () {
    testWidgets(
      'for an imported commitment: glyph plus the visible label',
      (tester) async {
        final notifier = _FakeScheduleNotifier();
        await pumpWithMood(
          tester,
          ChunkDetailSheet(
            chunk: _commitmentChunk(),
            notifier: notifier,
            displayRationale: 'Team standup',
            isImportedCommitment: true,
          ),
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier),
          ],
        );
        expect(_hasImportedGlyph(), isTrue);
        expect(find.text('Imported from your calendar'), findsOneWidget);
      },
    );

    testWidgets(
      'for a hand-entered commitment: no glyph, no label',
      (tester) async {
        final notifier = _FakeScheduleNotifier();
        await pumpWithMood(
          tester,
          ChunkDetailSheet(
            chunk: _commitmentChunk(),
            notifier: notifier,
            displayRationale: 'Team standup',
            isImportedCommitment: false,
          ),
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier),
          ],
        );
        expect(_hasImportedGlyph(), isFalse);
        expect(find.text('Imported from your calendar'), findsNothing);
      },
    );
  });
}
