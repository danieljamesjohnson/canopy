// Wave 0 stub for READ-01 — turns green when Plan 08-02 adds goalName and
// displayRationale parameters to ChunkCard and wires goal-name display.
//
// Status: RED until Plan 08-02.

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
    // ignore: unused_element
    testWidgets(
      'goalName appears as primary text and displayRationale as secondary text',
      (tester) async {
        // Plan 08-02 will add goalName and displayRationale params to ChunkCard.
        // This test pumps the current ChunkCard without those params and asserts
        // the FUTURE behavior — it is RED until Plan 08-02 lands.
        //
        // When Plan 02 adds `goalName` and `displayRationale` params, update
        // this call to:
        //   ChunkCard(chunk: _workChunk(), goalName: 'Morning Run', displayRationale: 'Daily habit')
        await pumpWithMood(
          tester,
          ChunkCard(chunk: _workChunk()),
        );
        // Asserts the goal name and rationale labels that Plan 02 must surface.
        // Currently fails RED because ChunkCard shows chunk.rationale ('Habit'),
        // not 'Morning Run' or 'Daily habit'.
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
  });
}
