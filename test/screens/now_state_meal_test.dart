// Phase 37 — found on the emulator 2026-11-10: at 8:25, with breakfast
// 7:00-7:30 and the first chunk at 8:30, Today showed breakfast as "RIGHT
// NOW". resolveNowState keeps an UNRESOLVED chunk current (Overdue) until
// the next one opens, and a meal can never be resolved (D-37-03), so a past
// meal must count as settled once its window ends.

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/screens/today/now_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final breakfast = ScheduledChunk(
    id: 'b',
    chunkTypeIndex: ChunkType.meal.index,
    commitmentId: 'meal-b',
    durationMinutes: 30,
    anchoredStartMinutes: 420,
    rationale: 'Breakfast',
  );
  final exercise = ScheduledChunk(
    id: 'x',
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'g',
    durationMinutes: 25,
    syntheticStartMinutes: 510,
    rationale: 'Exercise',
  );

  NowState at(int h, int m) => resolveNowState(
    chunks: [breakfast, exercise],
    now: () => DateTime(2026, 11, 10, h, m),
  );

  test('during breakfast, breakfast is current', () {
    final s = at(7, 10);
    expect(s, isA<Active>());
    expect((s as Active).current.id, 'b');
  });

  test('after breakfast ends, it is not overdue: the day is waiting on the '
      'next chunk', () {
    final s = at(8, 25);
    expect(s, isA<GapBeforeNext>());
    expect((s as GapBeforeNext).next.id, 'x');
  });

  test('an unresolved WORK chunk past its window is still overdue '
      '(unchanged)', () {
    final s = resolveNowState(
      chunks: [
        ScheduledChunk(
          id: 'w',
          chunkTypeIndex: ChunkType.work.index,
          goalId: 'g',
          durationMinutes: 25,
          syntheticStartMinutes: 420,
          rationale: 'Read',
        ),
        exercise,
      ],
      now: () => DateTime(2026, 11, 10, 8, 25),
    );
    expect(s, isA<Overdue>());
  });
}
