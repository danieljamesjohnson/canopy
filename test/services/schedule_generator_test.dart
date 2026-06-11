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
}
