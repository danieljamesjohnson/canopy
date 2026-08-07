// Unit tests for buildTimeline() — the pure Today-screen row model.
// Phase 22 Plan 01 (UNIFY-01) — Task 2.
//
// Pure test() cases — no widget pump, no providers, no Hive. Written before
// lib/screens/today/timeline.dart exists (RED state): a compile failure is
// the expected RED here.

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/screens/today/now_state.dart';
import 'package:canopy/screens/today/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Chunk factories (modelled on home_screen_now_state_test.dart) ──────────

/// Creates a work chunk with injectable time/resolution parameters.
ScheduledChunk _workChunk({
  String id = 'chunk-1',
  int? syntheticStartMinutes,
  int durationMinutes = 25,
  bool isCompleted = false,
  bool isSkipped = false,
}) {
  final c = ScheduledChunk(
    id: id,
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'goal-1',
    durationMinutes: durationMinutes,
    rationale: 'Deep work',
    syntheticStartMinutes: syntheticStartMinutes,
  );
  if (isCompleted) c.isCompleted = true;
  if (isSkipped) c.isSkipped = true;
  return c;
}

/// Creates a short-break chunk with injectable time parameters.
ScheduledChunk _breakChunk({
  String id = 'break-1',
  int? syntheticStartMinutes,
  int durationMinutes = 5,
}) {
  return ScheduledChunk(
    id: id,
    chunkTypeIndex: ChunkType.shortBreak.index,
    durationMinutes: durationMinutes,
    rationale: '',
    syntheticStartMinutes: syntheticStartMinutes,
  );
}

void main() {
  group('buildTimeline — structural cases', () {
    test('empty chunks returns an empty list', () {
      final rows = buildTimeline(chunks: [], nowState: DayComplete());
      expect(rows, isEmpty);
    });

    test('first chunk starts at minute 480: LeadingFreeRow(480) then its '
        'ChunkRow', () {
      final chunk = _workChunk(syntheticStartMinutes: 480);
      final rows = buildTimeline(chunks: [chunk], nowState: PreStart(chunk));
      expect(rows, hasLength(2));
      expect(rows[0], isA<LeadingFreeRow>());
      expect((rows[0] as LeadingFreeRow).untilMinutes, 480);
      expect(rows[1], isA<ChunkRow>());
      expect((rows[1] as ChunkRow).chunk.id, chunk.id);
    });

    test('first chunk starts at minute 0: no LeadingFreeRow', () {
      final chunk = _workChunk(syntheticStartMinutes: 0);
      final rows = buildTimeline(
        chunks: [chunk],
        nowState: Active(chunk, null),
      );
      expect(rows, hasLength(1));
      expect(rows[0], isA<ChunkRow>());
    });

    test('all chunks untimed: no LeadingFreeRow, one ChunkRow each, order '
        'preserved', () {
      final a = _workChunk(id: 'a');
      final b = _workChunk(id: 'b');
      final c = _workChunk(id: 'c');
      final rows = buildTimeline(chunks: [a, b, c], nowState: DayComplete());
      expect(rows, hasLength(3));
      expect(rows.every((r) => r is ChunkRow), isTrue);
      expect((rows[0] as ChunkRow).chunk.id, 'a');
      expect((rows[1] as ChunkRow).chunk.id, 'b');
      expect((rows[2] as ChunkRow).chunk.id, 'c');
    });
  });

  group('buildTimeline — gap arithmetic (D-05)', () {
    test('chunk A at 8:00 for 25min, chunk B at 10:45: GapFreeRow(505, 140) '
        'between them', () {
      final a = _workChunk(
        id: 'a',
        syntheticStartMinutes: 480,
        durationMinutes: 25,
      );
      final b = _workChunk(id: 'b', syntheticStartMinutes: 645);
      final rows = buildTimeline(chunks: [a, b], nowState: DayComplete());

      // LeadingFreeRow(480), ChunkRow(a), GapFreeRow(505, 140), ChunkRow(b)
      expect(rows, hasLength(4));
      expect(rows[0], isA<LeadingFreeRow>());
      expect(rows[1], isA<ChunkRow>());
      expect(rows[2], isA<GapFreeRow>());
      final gap = rows[2] as GapFreeRow;
      expect(gap.startMinutes, 505);
      expect(gap.durationMinutes, 140);
      expect(rows[3], isA<ChunkRow>());
    });

    test('gap of exactly 10 minutes: a GapFreeRow IS emitted (inclusive '
        'threshold)', () {
      final a = _workChunk(
        id: 'a',
        syntheticStartMinutes: 480,
        durationMinutes: 25,
      );
      final b = _workChunk(id: 'b', syntheticStartMinutes: 515); // 480+25+10
      final rows = buildTimeline(chunks: [a, b], nowState: DayComplete());
      expect(rows.whereType<GapFreeRow>(), hasLength(1));
    });

    test('gap of 9 minutes: suppressed (no free row)', () {
      final a = _workChunk(
        id: 'a',
        syntheticStartMinutes: 480,
        durationMinutes: 25,
      );
      final b = _workChunk(id: 'b', syntheticStartMinutes: 514); // 480+25+9
      final rows = buildTimeline(chunks: [a, b], nowState: DayComplete());
      expect(rows.whereType<GapFreeRow>(), isEmpty);
    });

    test('gap of 0 (back-to-back): no free row', () {
      final a = _workChunk(
        id: 'a',
        syntheticStartMinutes: 480,
        durationMinutes: 25,
      );
      final b = _workChunk(id: 'b', syntheticStartMinutes: 505); // 480+25
      final rows = buildTimeline(chunks: [a, b], nowState: DayComplete());
      expect(rows.whereType<GapFreeRow>(), isEmpty);
    });

    test('an untimed chunk between two timed chunks neither opens nor '
        'closes a gap and keeps its position in the output order', () {
      final a = _workChunk(
        id: 'a',
        syntheticStartMinutes: 480,
        durationMinutes: 25,
      );
      final untimed = _workChunk(id: 'untimed');
      // a ends at 505; c starts at 510 — a 5-minute gap, below threshold.
      final c = _workChunk(id: 'c', syntheticStartMinutes: 510);
      final rows = buildTimeline(
        chunks: [a, untimed, c],
        nowState: DayComplete(),
      );
      expect(rows.whereType<GapFreeRow>(), isEmpty);
      final chunkRows = rows.whereType<ChunkRow>().toList();
      expect(chunkRows, hasLength(3));
      expect(chunkRows[0].chunk.id, 'a');
      expect(chunkRows[1].chunk.id, 'untimed');
      expect(chunkRows[2].chunk.id, 'c');
    });
  });

  group('buildTimeline — isLive derivation (single-detector guarantee)', () {
    test('nowState Active(c2, ...): exactly one ChunkRow has isLive true, '
        'and it is c2\'s', () {
      final c1 = _workChunk(id: 'c1', syntheticStartMinutes: 480);
      final c2 = _workChunk(id: 'c2', syntheticStartMinutes: 600);
      final rows = buildTimeline(chunks: [c1, c2], nowState: Active(c2, null));
      final live = rows.whereType<ChunkRow>().where((r) => r.isLive).toList();
      expect(live, hasLength(1));
      expect(live.single.chunk.id, 'c2');
    });

    test('nowState Overdue(c1, ...): exactly one ChunkRow has isLive true, '
        'and it is c1\'s', () {
      final c1 = _workChunk(id: 'c1', syntheticStartMinutes: 480);
      final c2 = _workChunk(id: 'c2', syntheticStartMinutes: 600);
      final rows = buildTimeline(chunks: [c1, c2], nowState: Overdue(c1, c2));
      final live = rows.whereType<ChunkRow>().where((r) => r.isLive).toList();
      expect(live, hasLength(1));
      expect(live.single.chunk.id, 'c1');
    });

    test('nowState PreStart, GapBeforeNext, or DayComplete: no row has '
        'isLive true', () {
      final c1 = _workChunk(id: 'c1', syntheticStartMinutes: 480);
      final c2 = _workChunk(id: 'c2', syntheticStartMinutes: 600);
      for (final nowState in [PreStart(c1), GapBeforeNext(c2), DayComplete()]) {
        final rows = buildTimeline(chunks: [c1, c2], nowState: nowState);
        expect(
          rows.whereType<ChunkRow>().where((r) => r.isLive),
          isEmpty,
          reason: '$nowState must not mark any row live',
        );
      }
    });

    test('Phase 17 regression guard: 8am unresolved chunk + in-window 5:30pm '
        'chunk, clock frozen around 18:00 — live row is the 5:30pm chunk, '
        'NOT the 8am one', () {
      final morning = _workChunk(
        id: 'morning-8am',
        syntheticStartMinutes: 480, // 8:00 AM
        durationMinutes: 30,
      );
      final evening = _workChunk(
        id: 'evening-530pm',
        syntheticStartMinutes: 1050, // 5:30 PM
        durationMinutes: 45, // window 5:30–6:15 PM
      );
      final nowState = resolveNowState(
        chunks: [morning, evening],
        now: () => DateTime(2026, 6, 13, 18, 0), // 6:00 PM — inside evening
      );
      // Sanity: this must resolve to Active(evening), matching the Phase 17
      // fix (NOW-01) — if this assertion fails the fixture itself is wrong,
      // not buildTimeline.
      expect(nowState, isA<Active>());
      expect((nowState as Active).current.id, 'evening-530pm');

      final rows = buildTimeline(
        chunks: [morning, evening],
        nowState: nowState,
      );
      final live = rows.whereType<ChunkRow>().where((r) => r.isLive).toList();
      expect(live, hasLength(1));
      expect(
        live.single.chunk.id,
        'evening-530pm',
        reason:
            'The old _buildActiveChunkItems scan would have marked the '
            '8am chunk instead — this is the bug Phase 17 fixed.',
      );
    });
  });

  group(
    'buildTimeline — completed/skipped rows never filtered (D-01/D-06)',
    () {
      test('completed and skipped chunks still appear as ChunkRows in clock '
          'order', () {
        final completed = _workChunk(
          id: 'done',
          syntheticStartMinutes: 480,
          isCompleted: true,
        );
        final skippedBreak = _breakChunk(
          id: 'skipped-break',
          syntheticStartMinutes: 520,
        );
        final upcoming = _workChunk(id: 'upcoming', syntheticStartMinutes: 600);
        final rows = buildTimeline(
          chunks: [completed, skippedBreak, upcoming],
          nowState: PreStart(upcoming),
        );
        final chunkRows = rows.whereType<ChunkRow>().toList();
        expect(chunkRows, hasLength(3));
        expect(chunkRows[0].chunk.id, 'done');
        expect(chunkRows[1].chunk.id, 'skipped-break');
        expect(chunkRows[2].chunk.id, 'upcoming');
      });
    },
  );

  group('buildTimeline — live break (LIVE-01)', () {
    test('a live break renders as a ChunkRow with isLive true', () {
      final work = _workChunk(id: 'w1', syntheticStartMinutes: 480);
      final brk = _breakChunk(id: 'b1', syntheticStartMinutes: 505);
      final rows = buildTimeline(
        chunks: [work, brk],
        nowState: Active(brk, null),
      );
      final chunkRows = rows.whereType<ChunkRow>().toList();
      final breakRow = chunkRows.firstWhere((r) => r.chunk.id == 'b1');
      final workRow = chunkRows.firstWhere((r) => r.chunk.id == 'w1');
      expect(breakRow.isLive, isTrue);
      expect(workRow.isLive, isFalse);
    });
  });
}
