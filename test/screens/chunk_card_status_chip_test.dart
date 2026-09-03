// Phase 33 (OBVIOUS-01, UI-SPEC items 1-6, sketch 003 variant B).
//
// The Today timeline's chunk row must say its own state in words. Before this
// phase an unresolved work chunk carried `Icons.radio_button_unchecked` — an
// unlabelled circle the owner complained about on 2026-06-12 and which
// survived 2.5 months because no phase ever aimed at it. It now carries a
// labelled `To do` / `Done` / `Skipped` chip: one vocabulary, three words,
// display-only.
//
// These tests are the standing guard on that. They pin the words, the fact
// that the chip is NOT a control, and the fact that no second completion
// affordance was introduced alongside it.

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

/// File-local stub, modelled on `chunk_card_priority_badge_test.dart:7-12`.
/// 25 minutes so `full`/`compact` get a realistic duration-proportional slot
/// (`durationMinutes * kPixelsPerMinute` = 150dp).
ScheduledChunk _stubWorkChunk({bool completed = false, bool skipped = false}) =>
    ScheduledChunk(
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'g1',
        durationMinutes: 25,
        rationale: 'test',
      )
      ..isCompleted = completed
      ..isSkipped = skipped;

/// The chip's own `Container` — the nearest `Container` ancestor of its label.
/// `find.ancestor` yields ancestors nearest-first, so `.first` is the chip's
/// own box rather than any card-level wrapper.
Finder _chipBox(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first;

void main() {
  group('ChunkCard status chip (OBVIOUS-01, UI-SPEC items 1-6)', () {
    testWidgets('1. unresolved chunk at compact tier reads "To do"', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _stubWorkChunk(), density: ChunkCardDensity.compact),
      );
      expect(find.text('To do'), findsOneWidget);
      // Item 2: the glyph this phase exists to delete must not come back
      // alongside the word.
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    });

    testWidgets('2. unresolved chunk at full tier reads "To do"', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _stubWorkChunk(), density: ChunkCardDensity.full),
      );
      expect(find.text('To do'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    });

    testWidgets('3. completed chunk reads "Done", never "To do"', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(completed: true),
          density: ChunkCardDensity.compact,
        ),
      );
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('To do'), findsNothing);
    });

    testWidgets('4. skipped chunk reads "Skipped", never "To do"', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(skipped: true),
          density: ChunkCardDensity.compact,
        ),
      );
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('To do'), findsNothing);
      // The retired lowercase string is replaced, not kept alongside.
      expect(find.text('skipped'), findsNothing);
    });

    testWidgets('5. the chip is display-only — nothing about it is tappable', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _stubWorkChunk(), density: ChunkCardDensity.full),
      );
      // UI-SPEC item 3. Nothing above the label inks, and nothing below the
      // chip's own box recognises a gesture.
      expect(
        find.ancestor(of: find.text('To do'), matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(of: _chipBox('To do'), matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _chipBox('To do'),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _chipBox('To do'),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
    });

    testWidgets('6. no second completion affordance — one Complete, one Skip', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _stubWorkChunk(), density: ChunkCardDensity.full),
      );
      // UI-SPEC item 4: variant C (a real checkbox in the trailing slot) was
      // rejected precisely for adding a second way to complete a chunk.
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Complete'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Skip'), findsOneWidget);
    });

    testWidgets(
      '7. backstop (UI-SPEC item 6): the title yields, the chip does not',
      (tester) async {
        const longTitle =
            'A deliberately very long goal title that cannot possibly fit';
        await pumpWithMood(
          tester,
          const SizedBox(
            width: 220,
            child: _NarrowCompactChunk(title: longTitle),
          ),
        );

        // The chip survives the squeeze at its natural width...
        expect(find.text('To do'), findsOneWidget);
        // ...and the title is the thing that gives.
        expect(
          tester.widget<Text>(find.text(longTitle)).overflow,
          TextOverflow.ellipsis,
        );

        // **`flex: 0 0 auto` is asserted structurally, not only by width.**
        // The chip must have no flex ancestor. Note the predicate rather than
        // `find.byType(Flexible)`: `find.byType` compares `runtimeType`
        // exactly and so does NOT match the `Expanded` subclass — a
        // `byType(Flexible)` version of this assertion stayed green against
        // the very `Expanded` mutation described below, which is precisely
        // the un-failable assertion this project has shipped defects behind
        // five times. `w is Flexible` covers both.
        //
        // The width bound below cannot carry this on its own, and that is a
        // measured fact rather than a caution: wrapping the chip in
        // `Expanded` at the compact call site makes the Row's two flex
        // children split the band evenly at **92.0dp each** — barely above
        // the chip's own natural 91.5dp, and under any ceiling loose enough
        // to survive the harness font. A width-only backstop would have
        // passed straight over that regression. This finder fails on it.
        expect(
          find.ancestor(
            of: find.text('To do'),
            matching: find.byWidgetPredicate((w) => w is Flexible),
          ),
          findsNothing,
        );

        // The coarse companion: the chip must stay a small part of the row
        // rather than growing to fill it. The content band inside a 220dp
        // card is 192dp (220 less the 4dp accent-bar inset and the compact
        // tier's 12dp horizontal padding either side), so a chip given a
        // fixed oversize width lands near that and trips this.
        //
        // **This ceiling is a harness bound, not a device requirement, and
        // 110 is deliberately not the plan's original 80.** `flutter test`
        // renders with a placeholder font that draws every glyph as a fixed
        // `fontSize`-wide box (the trap `kGutterWidth`'s doc comment
        // documents at length), so the five glyphs of 'To do' measure far
        // wider here than in real Roboto. Measured 2026-09-01 with the chip
        // built to spec: **91.5dp** = 16 padding + 12 icon + 4 gap + 59.5 of
        // placeholder-font text. The plan's 80 was a pre-measurement estimate
        // of that same harness number and was simply too low to be met by a
        // correct implementation. Raising it is not weakening it: the
        // structural finder above is what actually pins item 6.
        // Verified able to fail: a chip wrapped in `SizedBox(width: 150)`
        // measures 150.0 and trips this bound.
        expect(tester.getSize(_chipBox('To do')).width, lessThan(110.0));
      },
    );
  });
}

/// A compact-tier chunk row carrying a long title — declared as a widget so
/// the test above can stay `const` at the pump site.
class _NarrowCompactChunk extends StatelessWidget {
  const _NarrowCompactChunk({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ChunkCard(
      chunk: _stubWorkChunk(),
      goalName: title,
      density: ChunkCardDensity.compact,
    );
  }
}
