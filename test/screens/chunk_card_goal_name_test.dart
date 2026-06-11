// Wave 0 stub for READ-01 — turns green when Plan 08-02 adds goalName and
// displayRationale parameters to ChunkCard and wires goal-name display.
//
// Status: GREEN after Plan 08-02.

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

ScheduledChunk _workChunk() => ScheduledChunk(
      id: 'c1',
      chunkTypeIndex: ChunkType.work.index,
      goalId: 'g1',
      durationMinutes: 25,
      rationale: 'Habit',
    );

void main() {
  group('ChunkCard goal name display (READ-01)', () {
    testWidgets(
      'goalName appears as primary text and displayRationale as secondary text',
      (tester) async {
        await pumpWithMood(
          tester,
          ChunkCard(
            chunk: _workChunk(),
            goalName: 'Morning Run',
            displayRationale: 'Daily habit',
          ),
        );
        expect(
          find.text('Morning Run'),
          findsOneWidget,
          reason: 'READ-01: ChunkCard must display the goal name as primary text',
        );
        expect(
          find.text('Daily habit'),
          findsOneWidget,
          reason: 'READ-01: ChunkCard must display the human-readable rationale as secondary text',
        );
      },
    );

    testWidgets(
      'falls back to chunk.rationale when goalName is null',
      (tester) async {
        await pumpWithMood(
          tester,
          ChunkCard(
            chunk: _workChunk(),
            // No goalName — should fall back to 'Habit'
          ),
        );
        expect(
          find.text('Habit'),
          findsOneWidget,
          reason: 'READ-01: When goalName is null, falls back to chunk.rationale',
        );
      },
    );
  });
}
