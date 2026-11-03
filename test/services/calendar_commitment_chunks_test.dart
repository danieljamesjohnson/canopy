// D-36-06 (owner, 2026-11-03): a meeting imported from a calendar is placed
// exactly as the calendar says — one block, no breaks inside it.
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/services/schedule_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CommitmentBlock block(int start, int end, {required bool fromCalendar}) =>
      CommitmentBlock(
        id: 'b',
        name: 'Meeting',
        daysOfWeek: const [],
        startMinutes: start,
        endMinutes: end,
        date: DateTime(2026, 11, 3),
        isFromCalendar: fromCalendar,
      );

  test('a 60-minute calendar meeting is ONE work chunk at its exact times, '
      'with no break', () {
    final chunks = ScheduleGeneratorService.buildCommitmentChunks(
      block(14 * 60, 15 * 60, fromCalendar: true),
      longBreakEvery: 4,
    );
    expect(chunks, hasLength(1));
    final c = chunks.single;
    expect(c.chunkType, ChunkType.work);
    expect(c.commitmentId, 'b');
    expect(c.anchoredStartMinutes, 14 * 60);
    expect(c.durationMinutes, 60);
    expect(c.rationale, 'Meeting');
  });

  test('a calendar meeting shorter than one 25-minute cell is still placed '
      '(the lattice would have dropped it)', () {
    final chunks = ScheduleGeneratorService.buildCommitmentChunks(
      block(14 * 60, 14 * 60 + 15, fromCalendar: true),
      longBreakEvery: 4,
    );
    expect(chunks, hasLength(1));
    expect(chunks.single.durationMinutes, 15);
  });

  test('a long calendar meeting gets no long break either', () {
    final chunks = ScheduleGeneratorService.buildCommitmentChunks(
      block(9 * 60, 13 * 60, fromCalendar: true),
      longBreakEvery: 2,
    );
    expect(chunks, hasLength(1));
    expect(chunks.single.durationMinutes, 240);
  });

  test('a HAND-ENTERED commitment keeps its breaks (COMMITBREAK-01 '
      'unchanged)', () {
    final chunks = ScheduleGeneratorService.buildCommitmentChunks(
      block(14 * 60, 15 * 60, fromCalendar: false),
      longBreakEvery: 4,
    );
    expect(chunks.length, greaterThan(1));
    expect(chunks.any((c) => c.chunkType == ChunkType.shortBreak), isTrue);
  });
}
