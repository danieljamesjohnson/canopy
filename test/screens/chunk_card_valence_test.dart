// Widget tests for valence chip and emoji tag on ChunkCard — Phase 19 Plan 01.
//
// Covers ENERGY-04b: valence chip and emoji visible on ChunkCard when goal
// has valence/emoji set; absent when neutral or null.
//
// RED: This file fails to compile because EnergyValence / ChunkCard.goalEmojiTag
// / ChunkCard.goalValence constructor params do not exist yet.

import 'package:canopy/data/models/energy_valence.dart'; // does not exist yet — RED
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ScheduledChunk _stubWorkChunk({String? goalId}) => ScheduledChunk(
  chunkTypeIndex: ChunkType.work.index,
  goalId: goalId ?? 'g1',
  durationMinutes: 25,
  rationale: 'test chunk',
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ChunkCard valence chip (ENERGY-04b)', () {
    testWidgets('shows "Gives" chip when goalValence == gives', (tester) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(goalId: 'g1'),
          goalValence: EnergyValence.gives, // param does not exist yet — RED
        ),
      );

      expect(
        find.text('Gives'),
        findsOneWidget,
        reason: 'Valence chip must show "Gives" for gives valence — ENERGY-04b',
      );
      expect(
        find.byIcon(Icons.bolt),
        findsOneWidget,
        reason:
            'Valence chip must show bolt icon for gives valence — ENERGY-04b',
      );
    });

    testWidgets('shows "Costs" chip when goalValence == costs', (tester) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(goalId: 'g1'),
          goalValence: EnergyValence.costs, // param does not exist yet — RED
        ),
      );

      expect(
        find.text('Costs'),
        findsOneWidget,
        reason: 'Valence chip must show "Costs" for costs valence — ENERGY-04b',
      );
      expect(
        find.byIcon(Icons.hourglass_empty),
        findsOneWidget,
        reason:
            'Valence chip must show hourglass icon for costs valence — ENERGY-04b',
      );
    });

    testWidgets('shows NO valence chip when goalValence == neutral', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(goalId: 'g1'),
          goalValence: EnergyValence.neutral, // param does not exist yet — RED
        ),
      );

      expect(
        find.text('Gives'),
        findsNothing,
        reason: 'No valence chip for neutral — ENERGY-04b',
      );
      expect(
        find.text('Costs'),
        findsNothing,
        reason: 'No valence chip for neutral — ENERGY-04b',
      );
    });

    testWidgets('shows NO valence chip when goalValence is null', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(),
          // goalValence: intentionally omitted — null
        ),
      );

      expect(find.text('Gives'), findsNothing);
      expect(find.text('Costs'), findsNothing);
    });
  });

  group('ChunkCard emoji prefix (ENERGY-04b)', () {
    testWidgets('emoji appears prefixed to goal name when goalEmojiTag is set', (
      tester,
    ) async {
      const knownEmoji = '⚡';
      const goalName = 'Morning Run';
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(goalId: 'g1'),
          goalName: goalName,
          goalEmojiTag: knownEmoji, // param does not exist yet — RED
        ),
      );

      // The ChunkCard should render the emoji prefixed to the goal name.
      // Implementation will produce a single Text widget containing "$emoji $goalName".
      expect(
        find.textContaining(knownEmoji),
        findsOneWidget,
        reason: 'Emoji must appear prefixed to the goal name — ENERGY-04b',
      );
      expect(
        find.textContaining(goalName),
        findsOneWidget,
        reason: 'Goal name must still appear alongside the emoji — ENERGY-04b',
      );
    });

    testWidgets('no emoji prefix when goalEmojiTag is null', (tester) async {
      const goalName = 'No Emoji Goal';
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(goalId: 'g1'),
          goalName: goalName,
          // goalEmojiTag: intentionally omitted — null
        ),
      );

      expect(find.text(goalName), findsOneWidget);
      expect(find.text('⚡'), findsNothing);
    });

    testWidgets('emoji + gives chip render together', (tester) async {
      const knownEmoji = '🌟';
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(goalId: 'g1'),
          goalName: 'Energizing Goal',
          goalEmojiTag: knownEmoji, // param does not exist yet — RED
          goalValence: EnergyValence.gives, // param does not exist yet — RED
        ),
      );

      expect(find.textContaining(knownEmoji), findsOneWidget);
      expect(find.text('Gives'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });
  });
}
