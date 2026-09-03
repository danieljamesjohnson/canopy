import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

ScheduledChunk _stubWorkChunk({String? goalId}) => ScheduledChunk(
  chunkTypeIndex: ChunkType.work.index,
  goalId: goalId,
  durationMinutes: 25,
  rationale: 'test',
);

void main() {
  group('ChunkCard priority badge', () {
    testWidgets('shows High badge when goalPriorityWeight is 0.75', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(goalId: 'g1'),
          goalPriorityWeight: 0.75,
        ),
      );
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('shows Low badge when goalPriorityWeight is 0.25', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _stubWorkChunk(goalId: 'g1'),
          goalPriorityWeight: 0.25,
        ),
      );
      expect(find.text('Low'), findsOneWidget);
    });

    testWidgets('shows no badge when goalPriorityWeight is null', (
      tester,
    ) async {
      await pumpWithMood(tester, ChunkCard(chunk: _stubWorkChunk()));
      expect(find.text('High'), findsNothing);
      expect(find.text('Low'), findsNothing);
    });

    testWidgets('shows no badge when goalPriorityWeight is 0.5 (Normal)', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(chunk: _stubWorkChunk(goalId: 'g1'), goalPriorityWeight: 0.5),
      );
      expect(find.text('High'), findsNothing);
      expect(find.text('Low'), findsNothing);
    });
  });
}
