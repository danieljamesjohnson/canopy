import 'package:flutter_test/flutter_test.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/services/schedule_generator.dart';

void main() {
  late ScheduleGeneratorService sut;

  // Monday 2026-03-23 — weekday == 1
  final monday = DateTime(2026, 3, 23);
  // Saturday 2026-03-28 — weekday == 6
  final saturday = DateTime(2026, 3, 28);

  setUp(() {
    sut = ScheduleGeneratorService();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Goal makeHabit({String name = 'Habit goal', double? priorityWeight}) =>
      Goal(
        name: name,
        goalTypeIndex: GoalType.habit.index,
        priorityWeight: priorityWeight,
      );

  Goal makeOutcome({
    String name = 'Outcome goal',
    DateTime? deadline,
    double? priorityWeight,
  }) =>
      Goal(
        name: name,
        goalTypeIndex: GoalType.outcome.index,
        deadline: deadline,
        priorityWeight: priorityWeight,
      );

  CommitmentBlock makeBlock({
    String name = 'Block',
    List<int> daysOfWeek = const [1, 2, 3, 4, 5],
    int startMinutes = 540, // 09:00
    int endMinutes = 600,   // 10:00 — 60-min window → 2 slots
  }) =>
      CommitmentBlock(
        name: name,
        daysOfWeek: daysOfWeek,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
      );

  int workCount(List<ScheduledChunk> chunks) =>
      chunks.where((c) => c.chunkType == ChunkType.work).length;

  int workChunksOf(List<ScheduledChunk> result) =>
      result.where((c) => c.chunkType == ChunkType.work).length;

  bool hasTrailingBreak(List<ScheduledChunk> result) =>
      result.isNotEmpty && result.last.chunkType != ChunkType.work;

  // ---------------------------------------------------------------------------
  // Test 1: mood=3, 0 goals, 0 blocks → empty list
  // ---------------------------------------------------------------------------
  test('Test 1: no goals, no blocks → empty list', () {
    final result = sut.generate(
      goals: [],
      blocks: [],
      moodIndex: 3,
      date: monday,
    );
    expect(result, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // Test 2: commitment block Mon–Fri, 60-min window → 2 work chunks with
  // correct anchoredStartMinutes; NOT generated on Saturday.
  // ---------------------------------------------------------------------------
  test('Test 2: commitment block on Monday generates 2 anchored chunks', () {
    final block = makeBlock(); // Mon-Fri, 540-600
    final result = sut.generate(
      goals: [],
      blocks: [block],
      moodIndex: 3,
      date: monday,
    );
    final workChunks = result.where((c) => c.chunkType == ChunkType.work).toList();
    expect(workChunks.length, 2);
    expect(workChunks[0].anchoredStartMinutes, 540);
    expect(workChunks[1].anchoredStartMinutes, 565); // 540 + 25
    expect(workChunks[0].goalId, isNull);
    expect(workChunks[1].goalId, isNull);
  });

  test('Test 2b: commitment block NOT generated on Saturday', () {
    final block = makeBlock(); // Mon-Fri only
    final result = sut.generate(
      goals: [],
      blocks: [block],
      moodIndex: 3,
      date: saturday,
    );
    expect(result, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // Test 3: habit + outcome, mood=1 → only habit chunk (no outcome)
  // ---------------------------------------------------------------------------
  test('Test 3: mood=1 excludes outcome goals', () {
    final result = sut.generate(
      goals: [makeHabit(), makeOutcome()],
      blocks: [],
      moodIndex: 1,
      date: monday,
    );
    final works = result.where((c) => c.chunkType == ChunkType.work).toList();
    expect(works.length, 1);
    expect(works.first.rationale, 'Habit');
  });

  // ---------------------------------------------------------------------------
  // Test 4: habit + outcome with deadline=today, mood=1 → both chunks appear
  // ---------------------------------------------------------------------------
  test('Test 4: mood=1 includes outcome when deadline==today', () {
    final result = sut.generate(
      goals: [makeHabit(), makeOutcome(deadline: monday)],
      blocks: [],
      moodIndex: 1,
      date: monday,
    );
    final works = result.where((c) => c.chunkType == ChunkType.work).toList();
    expect(works.length, 2);
    expect(works.map((c) => c.rationale), containsAll(['Habit']));
  });

  // ---------------------------------------------------------------------------
  // Test 5: mood=5, enough goals → work chunk count ≤ 11
  // ---------------------------------------------------------------------------
  test('Test 5: mood=5 caps discretionary work chunks at 11', () {
    // 20 habits to saturate capacity
    final goals = List.generate(20, (i) => makeHabit(name: 'Habit $i'));
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 5,
      date: monday,
    );
    expect(workCount(result), lessThanOrEqualTo(11));
  });

  // ---------------------------------------------------------------------------
  // Test 6: 4 work chunks, mood=3 → shortBreak after 1,2,3; trailing break trimmed
  // READ-02: no dangling trailing break on the final work chunk.
  // ---------------------------------------------------------------------------
  test('Test 6: mood=3 break pattern with 4 work chunks (trailing break trimmed)', () {
    // Use 4 habits to generate exactly 4 work chunks
    final goals = List.generate(4, (i) => makeHabit(name: 'Habit $i'));
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 3,
      date: monday,
    );
    // Verify chunk order: W SB W SB W SB W (trailing long break trimmed)
    expect(result.length, 7);
    expect(result[0].chunkType, ChunkType.work);
    expect(result[1].chunkType, ChunkType.shortBreak);
    expect(result[2].chunkType, ChunkType.work);
    expect(result[3].chunkType, ChunkType.shortBreak);
    expect(result[4].chunkType, ChunkType.work);
    expect(result[5].chunkType, ChunkType.shortBreak);
    expect(result[6].chunkType, ChunkType.work);
    // Trailing break was trimmed (READ-02)
    expect(result.last.chunkType, ChunkType.work);
  });

  // ---------------------------------------------------------------------------
  // Test 7: 3 work chunks, mood=1 → shortBreak after 1,2; trailing break trimmed
  // READ-02: no dangling trailing break on the final work chunk.
  // ---------------------------------------------------------------------------
  test('Test 7: mood=1 break pattern with 3 work chunks (trailing break trimmed)', () {
    final goals = List.generate(3, (i) => makeHabit(name: 'Habit $i'));
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 1,
      date: monday,
    );
    // Verify chunk order: W SB W SB W (trailing long break trimmed — READ-02)
    expect(result.length, 5);
    expect(result[0].chunkType, ChunkType.work);
    expect(result[1].chunkType, ChunkType.shortBreak);
    expect(result[2].chunkType, ChunkType.work);
    expect(result[3].chunkType, ChunkType.shortBreak);
    expect(result[4].chunkType, ChunkType.work);
    // Trailing break was trimmed (READ-02)
    expect(result.last.chunkType, ChunkType.work);
  });

  // ---------------------------------------------------------------------------
  // Test 8: outcome goal with deadline=today → daysRemaining floors at 1
  // ---------------------------------------------------------------------------
  test('Test 8: deadline==today floors daysRemaining at 1 (no exception)', () {
    final result = sut.generate(
      goals: [makeOutcome(deadline: monday)],
      blocks: [],
      moodIndex: 3,
      date: monday,
    );
    // Should produce 1 work chunk without throwing
    expect(workCount(result), 1);
  });

  // ---------------------------------------------------------------------------
  // Test 9: outcome goal with null deadline → still scheduled (low urgency)
  // ---------------------------------------------------------------------------
  test('Test 9: outcome goal with null deadline is scheduled at low urgency', () {
    final result = sut.generate(
      goals: [makeOutcome(deadline: null)],
      blocks: [],
      moodIndex: 3,
      date: monday,
    );
    expect(workCount(result), 1);
  });

  // ---------------------------------------------------------------------------
  // Test 10: commitment block + discretionary habits → no breaks between
  //          consecutive commitment chunks (READ-02 Pitfall 2)
  // ---------------------------------------------------------------------------
  test('Test 10: commitment block + discretionary — no breaks between commitment chunks', () {
    // makeBlock() is Mon-Fri 540-600 → 2 anchored chunks at 540, 565
    final block = makeBlock();
    final result = sut.generate(
      goals: [makeHabit()],
      blocks: [block],
      moodIndex: 3,
      date: monday,
    );
    final idx540 = result.indexWhere((c) => c.anchoredStartMinutes == 540);
    final idx565 = result.indexWhere((c) => c.anchoredStartMinutes == 565);
    expect(idx540, greaterThanOrEqualTo(0), reason: 'chunk at 540 must be present');
    expect(idx565, greaterThanOrEqualTo(0), reason: 'chunk at 565 must be present');
    expect(idx565, idx540 + 1,
        reason: 'No break between consecutive commitment chunks (READ-02)');
  });

  // ---------------------------------------------------------------------------
  // Test 11: 2 habits only → last element is work (trailing break trimmed)
  // ---------------------------------------------------------------------------
  test('Test 11: 2 habits only → trailing break trimmed (last chunk is work)', () {
    final result = sut.generate(
      goals: [makeHabit(name: 'A'), makeHabit(name: 'B')],
      blocks: [],
      moodIndex: 3,
      date: monday,
    );
    expect(result, isNotEmpty);
    expect(hasTrailingBreak(result), isFalse,
        reason: 'Last element must be a work chunk, not a break (READ-02)');
    expect(result.last.chunkType, ChunkType.work);
  });

  // ---------------------------------------------------------------------------
  // Test 12: commitment block + 1 habit → discretionary chunk gets a
  //          syntheticStartMinutes outside the commitment window; result
  //          is sorted by effective start time
  // ---------------------------------------------------------------------------
  test('Test 12: commitment block + 1 habit → discretionary gets synthetic time; sorted', () {
    // makeBlock() is 540-600 → commitment window occupies 540-600.
    // The discretionary habit chunk must be placed in a free slot (≠ 540-600).
    final block = makeBlock();
    final result = sut.generate(
      goals: [makeHabit()],
      blocks: [block],
      moodIndex: 3,
      date: monday,
    );
    final workChunkList = result
        .where((c) => c.chunkType == ChunkType.work)
        .toList();
    // At least the 2 commitment chunks + 1 discretionary habit.
    expect(workChunkList.length, greaterThanOrEqualTo(3));
    // The discretionary chunk (has goalId) must have syntheticStartMinutes set.
    final discretionary = workChunkList
        .where((c) => c.goalId != null)
        .toList();
    expect(discretionary, isNotEmpty, reason: 'Discretionary habit chunk must be present');
    expect(discretionary.first.syntheticStartMinutes, isNotNull,
        reason: 'Discretionary chunk must have syntheticStartMinutes assigned');
    // Verify the result is sorted by effective start time.
    final starts = result.map((c) =>
        c.anchoredStartMinutes ?? c.syntheticStartMinutes ?? 9999).toList();
    final sorted = [...starts]..sort();
    expect(starts, equals(sorted), reason: 'Result must be sorted by effective start time');
  });

  // ---------------------------------------------------------------------------
  // Test 13: all-commitment day (no discretionary) → only work chunks; no breaks
  // ---------------------------------------------------------------------------
  test('Test 13: all-commitment day → commitment chunks only, no breaks', () {
    // makeBlock() generates 2 commitment chunks; no discretionary goals.
    final block = makeBlock();
    final result = sut.generate(
      goals: [],
      blocks: [block],
      moodIndex: 3,
      date: monday,
    );
    // Result contains only work chunks — no breaks.
    final hasAnyBreak = result.any((c) =>
        c.chunkType == ChunkType.shortBreak ||
        c.chunkType == ChunkType.longBreak);
    expect(hasAnyBreak, isFalse,
        reason: 'All-commitment day must not contain any break chunks (READ-02)');
    expect(workChunksOf(result), equals(2));
  });

  // ---------------------------------------------------------------------------
  // Test WR-02: two OVERLAPPING same-day commitment blocks must merge into one
  // window so no discretionary chunk is placed at a time that overlaps a
  // commitment window (no negative-width free slot / no backward cursor).
  // ---------------------------------------------------------------------------
  test('WR-02: overlapping commitment blocks merge — no discretionary overlaps window', () {
    // Block A 540-620 → anchored chunks at 540,565,590 (footprint 540-615).
    // Block B 600-660 → anchored chunks at 600,625 (footprint 600-650).
    // The windows overlap (600 < 615) so they merge into the occupied range
    // [540, 650). Without a proper interval merge the unmerged windows let the
    // free-slot cursor move backward and a discretionary chunk could be placed
    // inside the commitment range.
    final blockA = makeBlock(name: 'A', startMinutes: 540, endMinutes: 620);
    final blockB = makeBlock(name: 'B', startMinutes: 600, endMinutes: 660);
    final result = sut.generate(
      goals: List.generate(3, (i) => makeHabit(name: 'Habit $i')),
      blocks: [blockA, blockB],
      moodIndex: 3,
      date: monday,
    );

    // Compute the actual occupied range from the anchored commitment chunks.
    final anchored = result
        .where((c) => c.chunkType == ChunkType.work && c.anchoredStartMinutes != null)
        .toList();
    final windowStart = anchored
        .map((c) => c.anchoredStartMinutes!)
        .reduce((a, b) => a < b ? a : b);
    final windowEnd = anchored
        .map((c) => c.anchoredStartMinutes! + c.durationMinutes)
        .reduce((a, b) => a > b ? a : b);

    // No discretionary (goalId != null) work chunk may overlap that range.
    final discretionary = result
        .where((c) => c.chunkType == ChunkType.work && c.goalId != null)
        .toList();
    expect(discretionary, isNotEmpty,
        reason: 'discretionary habits should still be placed');
    for (final c in discretionary) {
      final start = c.syntheticStartMinutes!;
      final overlaps = start < windowEnd && (start + 25) > windowStart;
      expect(overlaps, isFalse,
          reason: 'discretionary chunk at $start must not overlap merged '
              'commitment window [$windowStart, $windowEnd)');
    }

    // Result must remain sorted by effective start time (no backward cursor /
    // no negative-width slot).
    final starts = result
        .map((c) => c.anchoredStartMinutes ?? c.syntheticStartMinutes ?? 9999)
        .toList();
    final sorted = [...starts]..sort();
    expect(starts, equals(sorted),
        reason: 'overlapping-block merge must keep the result monotonically sorted');
  });

  // ---------------------------------------------------------------------------
  // Test WR-01: the break duration reserved during packing must match the
  // break duration emitted. With longBreakEvery=4 (mood 3-5), the 4th
  // discretionary break is a long (25-min) break; the synthetic times must
  // leave 25 minutes of room before the next chunk so no two chunks overlap
  // after the sort (the packing/emit cadence counters cannot diverge).
  // ---------------------------------------------------------------------------
  test('WR-01: emitted long break matches reserved slot — no overlapping synthetic times', () {
    // 6 habits at mood 3 (longBreakEvery=4). The break after chunk 4 is long.
    final goals = List.generate(6, (i) => makeHabit(name: 'Habit $i'));
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 3,
      date: monday,
    );

    // No chunk's [start, start+duration) may overlap the next chunk's start.
    for (int i = 0; i + 1 < result.length; i++) {
      final a = result[i];
      final b = result[i + 1];
      final aStart = a.anchoredStartMinutes ?? a.syntheticStartMinutes ?? 9999;
      final bStart = b.anchoredStartMinutes ?? b.syntheticStartMinutes ?? 9999;
      expect(aStart + a.durationMinutes, lessThanOrEqualTo(bStart),
          reason: 'chunk $i (${a.chunkType}, dur ${a.durationMinutes}) at '
              '$aStart must not overlap chunk ${i + 1} at $bStart — reserved '
              'slot must match emitted break duration (WR-01)');
    }

    // A long break (25 min) must actually be emitted, confirming the cadence
    // is exercised and the emitted duration equals the reserved duration.
    final longBreaks =
        result.where((c) => c.chunkType == ChunkType.longBreak).toList();
    expect(longBreaks, isNotEmpty,
        reason: 'longBreakEvery=4 with 6 chunks must emit at least one long break');
    expect(longBreaks.first.durationMinutes, 25);
  });

  // ---------------------------------------------------------------------------
  // Test WR-03: a discretionary chunk packed into a narrow pre-commitment gap
  // must not cause a break to sort between two contiguous commitment chunks,
  // and no break may sort into a position that splits the commitment window
  // (READ-02 at slot boundaries).
  // ---------------------------------------------------------------------------
  test('WR-03: break never sorts between contiguous commitment chunks (narrow pre-gap)', () {
    // Commitment block 540-590 (2 chunks: 540, 565). A free gap exists before
    // it (480-540) into which discretionary chunks are packed; the trailing
    // break footprint at the slot boundary must NOT be emitted so it cannot
    // sort into the commitment window or between the contiguous 540/565 chunks.
    final block = makeBlock(name: 'Morning', startMinutes: 540, endMinutes: 590);
    final result = sut.generate(
      goals: List.generate(2, (i) => makeHabit(name: 'Pre $i')),
      blocks: [block],
      moodIndex: 3,
      date: monday,
    );

    // The two commitment chunks (anchored 540 and 565) must be adjacent in the
    // final list — no break between them (READ-02).
    final idx540 = result.indexWhere((c) => c.anchoredStartMinutes == 540);
    final idx565 = result.indexWhere((c) => c.anchoredStartMinutes == 565);
    expect(idx540, greaterThanOrEqualTo(0));
    expect(idx565, greaterThanOrEqualTo(0));
    expect(idx565, idx540 + 1,
        reason: 'no break may sort between contiguous commitment chunks (WR-03)');

    // No break chunk may sit inside the commitment window [540, 590).
    for (final c in result) {
      if (c.chunkType == ChunkType.work) continue;
      final start = c.syntheticStartMinutes ?? 9999;
      final insideWindow = start >= 540 && start < 590;
      expect(insideWindow, isFalse,
          reason: 'break at $start must not fall inside commitment window (WR-03)');
    }
  });
}
