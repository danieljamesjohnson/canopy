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
        ChunkCard(
          chunk: _stubWorkChunk(),
          density: ChunkCardDensity.compact,
        ),
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

    testWidgets(
      '6. no second completion affordance — one Complete, one Skip',
      (tester) async {
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
      },
    );

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

        // The chip is flex 0 0 auto, so it must stay a small fraction of the
        // 220dp row rather than growing to eat it.
        //
        // **This ceiling is a harness bound, not a device requirement.**
        // `flutter test` renders with a placeholder font that draws every
        // glyph as a fixed `fontSize`-wide box, so 'To do' measures far wider
        // here than in real Roboto (the same trap `kGutterWidth`'s doc comment
        // documents). Keep it generous — it exists to catch a chip that grew
        // to fill the row, not to pin a pixel-exact width.
        expect(tester.getSize(_chipBox('To do')).width, lessThan(80.0));
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
