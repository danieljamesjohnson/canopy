// Unit tests for buildTimeline() — the pure Today-screen row model.
// Phase 22 Plan 01 (UNIFY-01) — Task 2.
//
// Pure test() cases — no widget pump, no providers, no Hive. Written before
// lib/screens/today/timeline.dart exists (RED state): a compile failure is
// the expected RED here.

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/screens/today/now_state.dart';
import 'package:canopy/screens/today/timeline.dart';
import 'package:canopy/screens/today/timeline_geometry.dart';
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

    test('NOW-02: nowMinutes before the first chunk start — LeadingFreeRow '
        'is present', () {
      final chunk = _workChunk(syntheticStartMinutes: 480);
      final rows = buildTimeline(
        chunks: [chunk],
        nowState: PreStart(chunk),
        nowMinutes: 400,
      );
      final leading = rows.whereType<LeadingFreeRow>();
      expect(leading, hasLength(1));
      expect(leading.single.untilMinutes, 480);
      expect(leading.single.windowPassed, isFalse);
    });

    // NOW-02 amended 2026-08-18: the row used to be suppressed here. It is now
    // built with windowPassed set, so the caller can swap "Free until <time>"
    // (untruthful once passed — the original concern, still honoured) for the
    // duration copy. Suppressing it did not reclaim the space: the layout is
    // duration-proportional, so the region stayed just as tall and went blank,
    // which is what UAT flagged as an unexplained stretch of background.
    test('NOW-02: nowMinutes past the first chunk start — LeadingFreeRow is '
        'still built, flagged windowPassed', () {
      final chunk = _workChunk(syntheticStartMinutes: 480);
      final rows = buildTimeline(
        chunks: [chunk],
        nowState: GapBeforeNext(chunk),
        nowMinutes: 600,
      );
      final leading = rows.whereType<LeadingFreeRow>();
      expect(leading, hasLength(1));
      expect(leading.single.untilMinutes, 480);
      expect(leading.single.windowPassed, isTrue);
    });

    test('NOW-02: nowMinutes omitted entirely — LeadingFreeRow is present '
        '(back-compat, null is a no-op)', () {
      final chunk = _workChunk(syntheticStartMinutes: 480);
      final rows = buildTimeline(chunks: [chunk], nowState: PreStart(chunk));
      expect(rows.whereType<LeadingFreeRow>(), hasLength(1));
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

  group('TimelineGeometry — CAL-01 minute→pixel mapping', () {
    test('Active: now inside [firstStart, lastEnd] reduces to the plain day '
        'span', () {
      final geometry = TimelineGeometry.forDay(
        nowMinutes: 555,
        firstStartMinutes: 540,
        lastEndMinutes: 1020,
      );
      expect(geometry.rangeStart, 540);
      expect(geometry.rangeEnd, 1020);
    });

    test('PreStart: now precedes firstStart extends rangeStart back to now',
        () {
      final geometry = TimelineGeometry.forDay(
        nowMinutes: 390,
        firstStartMinutes: 540,
        lastEndMinutes: 1020,
      );
      expect(geometry.rangeStart, 360);
    });

    test('DayComplete: now follows lastEnd extends rangeEnd forward to now',
        () {
      final geometry = TimelineGeometry.forDay(
        nowMinutes: 1265,
        firstStartMinutes: 540,
        lastEndMinutes: 1020,
      );
      expect(geometry.rangeEnd, 1320);
    });

    test(
        'yFor(rangeStart) is always kTimelineEdgePadding (G-04/G-05, '
        '26-10-PLAN.md)', () {
      final geometry = TimelineGeometry.forDay(
        nowMinutes: 555,
        firstStartMinutes: 540,
        lastEndMinutes: 1020,
      );
      expect(geometry.yFor(geometry.rangeStart), kTimelineEdgePadding);
    });

    test('a 25-minute chunk heightFor equals 25 * kPixelsPerMinute with no '
        'live row', () {
      final geometry = TimelineGeometry.forDay(
        nowMinutes: 555,
        firstStartMinutes: 540,
        lastEndMinutes: 1020,
      );
      expect(geometry.heightFor(540, 25), 25 * kPixelsPerMinute);
    });

    test('a 5-minute break heightFor equals 5 * kPixelsPerMinute', () {
      final geometry = TimelineGeometry.forDay(
        nowMinutes: 555,
        firstStartMinutes: 540,
        lastEndMinutes: 1020,
      );
      expect(geometry.heightFor(540, 5), 5 * kPixelsPerMinute);
    });

    test(
        'totalHeight equals (rangeEnd - rangeStart) * 5.5 plus '
        '2 * kTimelineEdgePadding with no live row (G-04/G-05, '
        '26-10-PLAN.md)', () {
      final geometry = TimelineGeometry.forDay(
        nowMinutes: 555,
        firstStartMinutes: 540,
        lastEndMinutes: 1020,
      );
      expect(
        geometry.totalHeight,
        (geometry.rangeEnd - geometry.rangeStart) * kPixelsPerMinute +
            2 * kTimelineEdgePadding,
      );
    });

    test("a row starting at liveEndMinutes has a duration-exact bottom edge "
        '(GRID-01: no more live-row swell)', () {
      final geometry = TimelineGeometry.forDay(
        nowMinutes: 550,
        firstStartMinutes: 540,
        lastEndMinutes: 1020,
        liveStartMinutes: 540,
        liveEndMinutes: 565,
      );
      expect(
        geometry.yFor(565),
        geometry.yFor(540) + geometry.heightFor(540, 25),
      );
      expect(geometry.heightFor(540, 25), 25 * kPixelsPerMinute);
    });

    test(
        'yFor clamps rather than returning a negative-before-padding '
        'offset for an out-of-range minute', () {
      final geometry = TimelineGeometry.forDay(
        nowMinutes: 555,
        firstStartMinutes: 540,
        lastEndMinutes: 1020,
      );
      expect(
        geometry.yFor(geometry.rangeStart - 120),
        kTimelineEdgePadding,
      );
    });

    test(
        'GRID-01: every hour boundary is equidistant, even with a live '
        'chunk present', () {
      // A 25-minute live chunk (540..565) whose end minute falls strictly
      // inside the 540..600 hour — the exact configuration the defect
      // corrupts. Ground truth is 60 * kPixelsPerMinute and nothing else:
      // this must NOT re-derive any implementation-internal quantity (the
      // per-minute-scale offset the live row used to add, or the fixed
      // height it used to add it toward), or it inherits the same
      // self-referential blindness the other tests in this group have
      // (27-VALIDATION.md "The load-bearing split").
      final geometry = TimelineGeometry.forDay(
        nowMinutes: 550,
        firstStartMinutes: 480,
        lastEndMinutes: 1020,
        liveStartMinutes: 540,
        liveEndMinutes: 565,
      );
      final boundaries = geometry.hourBoundaries;
      expect(
        boundaries.length,
        greaterThan(2),
        reason:
            'fixture must span multiple hours, or this loop is vacuously '
            'true and proves nothing',
      );
      for (var i = 0; i < boundaries.length - 1; i++) {
        expect(
          geometry.yFor(boundaries[i + 1]) - geometry.yFor(boundaries[i]),
          60 * kPixelsPerMinute,
          reason:
              'boundary $i (minute ${boundaries[i]}) -> boundary ${i + 1} '
              '(minute ${boundaries[i + 1]}) must be exactly one hour apart '
              'in pixels, including the 540->600 boundary the live chunk '
              'ends inside',
        );
      }
    });
  });
}
