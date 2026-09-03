// Widget tests for ChunkCard goal name display and clock-time range display.
//
// READ-01: goalName + displayRationale secondary text (Phase 8 Plan 02).
// SCHED-01: Clock-time range "START – END" secondary text (Phase 12 Plan 02).

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

ScheduledChunk _workChunk() => ScheduledChunk(
  id: 'c1',
  chunkTypeIndex: ChunkType.work.index,
  goalId: 'g1',
  durationMinutes: 25,
  rationale: 'Habit',
);

ScheduledChunk _workChunkWithStartTime({required int startMinutes}) =>
    ScheduledChunk(
      id: 'c2',
      chunkTypeIndex: ChunkType.work.index,
      goalId: 'g1',
      durationMinutes: 25,
      rationale: 'Habit',
      syntheticStartMinutes: startMinutes,
    );

/// Fake ScheduleNotifier — stubs init to avoid Hive (needed for button onPressed).
class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}
}

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
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>(
              create: (_) => _FakeScheduleNotifier(),
            ),
          ],
        );
        expect(
          find.text('Morning Run'),
          findsOneWidget,
          reason:
              'READ-01: ChunkCard must display the goal name as primary text',
        );
        expect(
          find.text('Daily habit'),
          findsOneWidget,
          reason:
              'READ-01: ChunkCard must display the human-readable rationale as secondary text',
        );
      },
    );

    testWidgets('falls back to chunk.rationale when goalName is null', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _workChunk(),
          // No goalName — should fall back to 'Habit'
        ),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>(
            create: (_) => _FakeScheduleNotifier(),
          ),
        ],
      );
      expect(
        find.text('Habit'),
        findsOneWidget,
        reason: 'READ-01: When goalName is null, falls back to chunk.rationale',
      );
    });
  });

  group('ChunkCard clock-time range display (SCHED-01)', () {
    testWidgets(
      'shows START–END range string when displayStartMinutes is set',
      (tester) async {
        // 9:25 AM = 565 min; duration 25 min → end 9:50 AM = 590 min
        await pumpWithMood(
          tester,
          ChunkCard(chunk: _workChunkWithStartTime(startMinutes: 565)),
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>(
              create: (_) => _FakeScheduleNotifier(),
            ),
          ],
        );
        expect(
          find.text('9:25 AM – 9:50 AM'),
          findsOneWidget,
          reason: 'SCHED-01: Clock-time range must show "START – END" format',
        );
      },
    );

    testWidgets('shows duration fallback when displayStartMinutes is null', (
      tester,
    ) async {
      // No syntheticStartMinutes set → displayStartMinutes is null
      await pumpWithMood(
        tester,
        ChunkCard(
          chunk: _workChunk(), // durationMinutes = 25, no start time
        ),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>(
            create: (_) => _FakeScheduleNotifier(),
          ),
        ],
      );
      expect(
        find.text('25 min'),
        findsOneWidget,
        reason:
            'SCHED-01: Duration fallback "N min" shown when displayStartMinutes is null',
      );
    });
  });
}
