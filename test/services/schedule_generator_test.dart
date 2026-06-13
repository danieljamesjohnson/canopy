import 'package:flutter_test/flutter_test.dart';
import 'package:canopy/data/models/completion_log.dart';
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

  Goal makeHabit({String name = 'Habit goal', double? priorityWeight}) => Goal(
    name: name,
    goalTypeIndex: GoalType.habit.index,
    priorityWeight: priorityWeight,
  );

  Goal makeOutcome({
    String name = 'Outcome goal',
    DateTime? deadline,
    double? priorityWeight,
  }) => Goal(
    name: name,
    goalTypeIndex: GoalType.outcome.index,
    deadline: deadline,
    priorityWeight: priorityWeight,
  );

  CommitmentBlock makeBlock({
    String name = 'Block',
    List<int> daysOfWeek = const [1, 2, 3, 4, 5],
    int startMinutes = 540, // 09:00
    int endMinutes = 600, // 10:00 — 60-min window → 2 slots
  }) => CommitmentBlock(
    name: name,
    daysOfWeek: daysOfWeek,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
  );

  Goal makeTimeTarget({
    String name = 'Time-target goal',
    double? weeklyHourBudget,
    double? priorityWeight,
  }) => Goal(
    name: name,
    goalTypeIndex: GoalType.timeTarget.index,
    weeklyHourBudget: weeklyHourBudget,
    priorityWeight: priorityWeight,
  );

  CompletionLog makeLog({
    required String goalId,
    required String dateYmd,
    CompletionEvent event = CompletionEvent.completed,
  }) => CompletionLog(
    chunkId: 'chunk-$dateYmd',
    goalId: goalId,
    dateYmd: dateYmd,
    eventIndex: event.index,
  );

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
      completionLogs: [],
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
      completionLogs: [],
    );
    final workChunks = result
        .where((c) => c.chunkType == ChunkType.work)
        .toList();
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
      completionLogs: [],
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
      completionLogs: [],
    );
    final works = result.where((c) => c.chunkType == ChunkType.work).toList();
    expect(works.length, 1);
    expect(works.first.rationale, 'Daily habit');
  });

  // ---------------------------------------------------------------------------
  // Test 4: habit + outcome with deadline=today, mood=1 → both chunks appear
  // ---------------------------------------------------------------------------
  test('Test 4: mood=1 includes outcome when deadline==today', () {
    final result = sut.generate(
      goals: [
        makeHabit(),
        makeOutcome(deadline: monday),
      ],
      blocks: [],
      moodIndex: 1,
      date: monday,
      completionLogs: [],
    );
    final works = result.where((c) => c.chunkType == ChunkType.work).toList();
    expect(works.length, 2);
    expect(works.map((c) => c.rationale), containsAll(['Daily habit']));
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
      completionLogs: [],
    );
    expect(workChunksOf(result), lessThanOrEqualTo(11));
  });

  // ---------------------------------------------------------------------------
  // Test 6: 4 work chunks, mood=3 → shortBreak after 1,2,3; trailing break trimmed
  // READ-02: no dangling trailing break on the final work chunk.
  // ---------------------------------------------------------------------------
  test(
    'Test 6: mood=3 break pattern with 4 work chunks (trailing break trimmed)',
    () {
      // Use 4 habits to generate exactly 4 work chunks
      final goals = List.generate(4, (i) => makeHabit(name: 'Habit $i'));
      final result = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
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
    },
  );

  // ---------------------------------------------------------------------------
  // Test 7: 3 work chunks, mood=1 → shortBreak after 1,2; trailing break trimmed
  // READ-02: no dangling trailing break on the final work chunk.
  // ---------------------------------------------------------------------------
  test(
    'Test 7: mood=1 break pattern with 3 work chunks (trailing break trimmed)',
    () {
      final goals = List.generate(3, (i) => makeHabit(name: 'Habit $i'));
      final result = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 1,
        date: monday,
        completionLogs: [],
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
    },
  );

  // ---------------------------------------------------------------------------
  // Test 8: outcome goal with deadline=today → daysRemaining floors at 1
  // ---------------------------------------------------------------------------
  test('Test 8: deadline==today floors daysRemaining at 1 (no exception)', () {
    final result = sut.generate(
      goals: [makeOutcome(deadline: monday)],
      blocks: [],
      moodIndex: 3,
      date: monday,
      completionLogs: [],
    );
    // Should produce 1 work chunk without throwing
    expect(workChunksOf(result), 1);
  });

  // ---------------------------------------------------------------------------
  // Test 9: outcome goal with null deadline → still scheduled (low urgency)
  // ---------------------------------------------------------------------------
  test(
    'Test 9: outcome goal with null deadline is scheduled at low urgency',
    () {
      final result = sut.generate(
        goals: [makeOutcome(deadline: null)],
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
      );
      expect(workChunksOf(result), 1);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 10: commitment block + discretionary habits → no breaks between
  //          consecutive commitment chunks (READ-02 Pitfall 2)
  // ---------------------------------------------------------------------------
  test(
    'Test 10: commitment block + discretionary — no breaks between commitment chunks',
    () {
      // makeBlock() is Mon-Fri 540-600 → 2 anchored chunks at 540, 565
      final block = makeBlock();
      final result = sut.generate(
        goals: [makeHabit()],
        blocks: [block],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
      );
      final idx540 = result.indexWhere((c) => c.anchoredStartMinutes == 540);
      final idx565 = result.indexWhere((c) => c.anchoredStartMinutes == 565);
      expect(
        idx540,
        greaterThanOrEqualTo(0),
        reason: 'chunk at 540 must be present',
      );
      expect(
        idx565,
        greaterThanOrEqualTo(0),
        reason: 'chunk at 565 must be present',
      );
      expect(
        idx565,
        idx540 + 1,
        reason: 'No break between consecutive commitment chunks (READ-02)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Test 11: 2 habits only → last element is work (trailing break trimmed)
  // ---------------------------------------------------------------------------
  test(
    'Test 11: 2 habits only → trailing break trimmed (last chunk is work)',
    () {
      final result = sut.generate(
        goals: [
          makeHabit(name: 'A'),
          makeHabit(name: 'B'),
        ],
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
      );
      expect(result, isNotEmpty);
      expect(
        hasTrailingBreak(result),
        isFalse,
        reason: 'Last element must be a work chunk, not a break (READ-02)',
      );
      expect(result.last.chunkType, ChunkType.work);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 12: commitment block + 1 habit → discretionary chunk gets a
  //          syntheticStartMinutes outside the commitment window; result
  //          is sorted by effective start time
  // ---------------------------------------------------------------------------
  test(
    'Test 12: commitment block + 1 habit → discretionary gets synthetic time; sorted',
    () {
      // makeBlock() is 540-600 → commitment window occupies 540-600.
      // The discretionary habit chunk must be placed in a free slot (≠ 540-600).
      final block = makeBlock();
      final result = sut.generate(
        goals: [makeHabit()],
        blocks: [block],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
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
      expect(
        discretionary,
        isNotEmpty,
        reason: 'Discretionary habit chunk must be present',
      );
      expect(
        discretionary.first.syntheticStartMinutes,
        isNotNull,
        reason: 'Discretionary chunk must have syntheticStartMinutes assigned',
      );
      // Verify the result is sorted by effective start time.
      final starts = result
          .map((c) => c.anchoredStartMinutes ?? c.syntheticStartMinutes ?? 9999)
          .toList();
      final sorted = [...starts]..sort();
      expect(
        starts,
        equals(sorted),
        reason: 'Result must be sorted by effective start time',
      );
    },
  );

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
      completionLogs: [],
    );
    // Result contains only work chunks — no breaks.
    final hasAnyBreak = result.any(
      (c) =>
          c.chunkType == ChunkType.shortBreak ||
          c.chunkType == ChunkType.longBreak,
    );
    expect(
      hasAnyBreak,
      isFalse,
      reason: 'All-commitment day must not contain any break chunks (READ-02)',
    );
    expect(workChunksOf(result), equals(2));
  });

  // ---------------------------------------------------------------------------
  // Test WR-02: two OVERLAPPING same-day commitment blocks must merge into one
  // window so no discretionary chunk is placed at a time that overlaps a
  // commitment window (no negative-width free slot / no backward cursor).
  // ---------------------------------------------------------------------------
  test(
    'WR-02: overlapping commitment blocks merge — no discretionary overlaps window',
    () {
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
        completionLogs: [],
      );

      // Compute the actual occupied range from the anchored commitment chunks.
      final anchored = result
          .where(
            (c) =>
                c.chunkType == ChunkType.work && c.anchoredStartMinutes != null,
          )
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
      expect(
        discretionary,
        isNotEmpty,
        reason: 'discretionary habits should still be placed',
      );
      for (final c in discretionary) {
        final start = c.syntheticStartMinutes!;
        final overlaps = start < windowEnd && (start + 25) > windowStart;
        expect(
          overlaps,
          isFalse,
          reason:
              'discretionary chunk at $start must not overlap merged '
              'commitment window [$windowStart, $windowEnd)',
        );
      }

      // Result must remain sorted by effective start time (no backward cursor /
      // no negative-width slot).
      final starts = result
          .map((c) => c.anchoredStartMinutes ?? c.syntheticStartMinutes ?? 9999)
          .toList();
      final sorted = [...starts]..sort();
      expect(
        starts,
        equals(sorted),
        reason:
            'overlapping-block merge must keep the result monotonically sorted',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Test WR-01: the break duration reserved during packing must match the
  // break duration emitted. With longBreakEvery=4 (mood 3-5), the 4th
  // discretionary break is a long (25-min) break; the synthetic times must
  // leave 25 minutes of room before the next chunk so no two chunks overlap
  // after the sort (the packing/emit cadence counters cannot diverge).
  // ---------------------------------------------------------------------------
  test(
    'WR-01: emitted long break matches reserved slot — no overlapping synthetic times',
    () {
      // 6 habits at mood 3 (longBreakEvery=4). The break after chunk 4 is long.
      final goals = List.generate(6, (i) => makeHabit(name: 'Habit $i'));
      final result = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
      );

      // No chunk's [start, start+duration) may overlap the next chunk's start.
      for (int i = 0; i + 1 < result.length; i++) {
        final a = result[i];
        final b = result[i + 1];
        final aStart =
            a.anchoredStartMinutes ?? a.syntheticStartMinutes ?? 9999;
        final bStart =
            b.anchoredStartMinutes ?? b.syntheticStartMinutes ?? 9999;
        expect(
          aStart + a.durationMinutes,
          lessThanOrEqualTo(bStart),
          reason:
              'chunk $i (${a.chunkType}, dur ${a.durationMinutes}) at '
              '$aStart must not overlap chunk ${i + 1} at $bStart — reserved '
              'slot must match emitted break duration (WR-01)',
        );
      }

      // A long break (25 min) must actually be emitted, confirming the cadence
      // is exercised and the emitted duration equals the reserved duration.
      final longBreaks = result
          .where((c) => c.chunkType == ChunkType.longBreak)
          .toList();
      expect(
        longBreaks,
        isNotEmpty,
        reason:
            'longBreakEvery=4 with 6 chunks must emit at least one long break',
      );
      expect(longBreaks.first.durationMinutes, 25);
    },
  );

  // ---------------------------------------------------------------------------
  // Test WR-03: a discretionary chunk packed into a narrow pre-commitment gap
  // must not cause a break to sort between two contiguous commitment chunks,
  // and no break may sort into a position that splits the commitment window
  // (READ-02 at slot boundaries).
  // ---------------------------------------------------------------------------
  test(
    'WR-03: break never sorts between contiguous commitment chunks (narrow pre-gap)',
    () {
      // Commitment block 540-590 (2 chunks: 540, 565). A free gap exists before
      // it (480-540) into which discretionary chunks are packed; the trailing
      // break footprint at the slot boundary must NOT be emitted so it cannot
      // sort into the commitment window or between the contiguous 540/565 chunks.
      final block = makeBlock(
        name: 'Morning',
        startMinutes: 540,
        endMinutes: 590,
      );
      final result = sut.generate(
        goals: List.generate(2, (i) => makeHabit(name: 'Pre $i')),
        blocks: [block],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
      );

      // The two commitment chunks (anchored 540 and 565) must be adjacent in the
      // final list — no break between them (READ-02).
      final idx540 = result.indexWhere((c) => c.anchoredStartMinutes == 540);
      final idx565 = result.indexWhere((c) => c.anchoredStartMinutes == 565);
      expect(idx540, greaterThanOrEqualTo(0));
      expect(idx565, greaterThanOrEqualTo(0));
      expect(
        idx565,
        idx540 + 1,
        reason:
            'no break may sort between contiguous commitment chunks (WR-03)',
      );

      // No break chunk may sit inside the commitment window [540, 590).
      for (final c in result) {
        if (c.chunkType == ChunkType.work) continue;
        final start = c.syntheticStartMinutes ?? 9999;
        final insideWindow = start >= 540 && start < 590;
        expect(
          insideWindow,
          isFalse,
          reason:
              'break at $start must not fall inside commitment window (WR-03)',
        );
      }
    },
  );

  // ---------------------------------------------------------------------------
  // T-09-01: ENGINE-01 — mood 4, 3 time-target goals → more than 3 chunks
  // ---------------------------------------------------------------------------
  test(
    'T-09-01: mood 4, 3 time-target goals → more than 3 discretionary chunks',
    () {
      // 3 goals, each 10hr/week budget, Monday (daysLeft=7), 0 completions
      // demand = ceil(10*60/25/7) = ceil(3.43) = 4 per goal → total 12, capped at 9
      final goals = [
        makeTimeTarget(name: 'G1', weeklyHourBudget: 10),
        makeTimeTarget(name: 'G2', weeklyHourBudget: 10),
        makeTimeTarget(name: 'G3', weeklyHourBudget: 10),
      ];
      final result = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 4,
        date: monday,
        completionLogs: [],
      );
      expect(workChunksOf(result), greaterThan(3));
    },
  );

  // ---------------------------------------------------------------------------
  // T-09-02: ENGINE-02 — most-behind time-target goal gets more chunks
  // ---------------------------------------------------------------------------
  test(
    'T-09-02: most-behind time-target goal gets >= ahead goal chunk count',
    () {
      // Goal A: 5hr budget, 2 completed chunks this week (completedHrs=~0.83h) → remaining ~4.17h
      // Goal B: 5hr budget, 0 completed chunks → remaining 5h (most behind)
      // Expected: B gets >= A's chunks and strictly more in this setup
      final goalA = makeTimeTarget(name: 'A', weeklyHourBudget: 5);
      final goalB = makeTimeTarget(name: 'B', weeklyHourBudget: 5);
      // Monday = start of week; log 2 completions for goal A this week
      final logs = [
        makeLog(goalId: goalA.id, dateYmd: '2026-03-23'), // today, Monday
        makeLog(goalId: goalA.id, dateYmd: '2026-03-23'),
      ];
      final result = sut.generate(
        goals: [goalA, goalB],
        blocks: [],
        moodIndex: 5,
        date: monday,
        completionLogs: logs,
      );
      final aChunks = result
          .where((c) => c.chunkType == ChunkType.work && c.goalId == goalA.id)
          .length;
      final bChunks = result
          .where((c) => c.chunkType == ChunkType.work && c.goalId == goalB.id)
          .length;
      expect(
        bChunks,
        greaterThanOrEqualTo(aChunks),
        reason: 'Goal B (most behind) must get >= chunks than Goal A (ahead)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T-09-03a: ENGINE-03 — 3x/week habit NOT on non-due weekday (Tuesday)
  // ---------------------------------------------------------------------------
  test(
    'T-09-03a: 3x/week habit absent on non-due weekday (Tuesday), present on due day',
    () {
      // freq=3 → due weekdays = {1,3,5} = Mon/Wed/Fri
      // Tuesday = weekday 2 → NOT due → 0 chunks
      final tuesday = DateTime(2026, 3, 24); // weekday 2
      final habit = Goal(
        name: 'Habit 3x',
        goalTypeIndex: GoalType.habit.index,
        frequencyPerWeek: 3,
      );
      final resultTuesday = sut.generate(
        goals: [habit],
        blocks: [],
        moodIndex: 4,
        date: tuesday,
        completionLogs: [],
      );
      expect(
        resultTuesday
            .where((c) => c.chunkType == ChunkType.work && c.goalId == habit.id)
            .length,
        0,
        reason: 'Habit must not appear on Tuesday (not a due day for freq=3)',
      );
      // Monday = weekday 1 → IS due → 1 chunk
      final resultMonday = sut.generate(
        goals: [habit],
        blocks: [],
        moodIndex: 4,
        date: monday,
        completionLogs: [],
      );
      expect(
        resultMonday
            .where((c) => c.chunkType == ChunkType.work && c.goalId == habit.id)
            .length,
        1,
        reason: 'Habit must appear on Monday (due day for freq=3)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T-09-04: ENGINE-04 — near-deadline outcome precedes far-deadline outcome
  // ---------------------------------------------------------------------------
  test(
    'T-09-04: near-deadline outcome chunk precedes far-deadline outcome chunk',
    () {
      final nearDeadline = monday.add(const Duration(days: 3));
      final farDeadline = monday.add(const Duration(days: 90));
      final nearGoal = makeOutcome(
        name: 'Near',
        deadline: nearDeadline,
        priorityWeight: 0.5,
      );
      final farGoal = makeOutcome(
        name: 'Far',
        deadline: farDeadline,
        priorityWeight: 0.5,
      );
      final result = sut.generate(
        goals: [farGoal, nearGoal], // intentionally reversed in input
        blocks: [],
        moodIndex: 4,
        date: monday,
        completionLogs: [],
      );
      final works = result.where((c) => c.chunkType == ChunkType.work).toList();
      final nearIdx = works.indexWhere((c) => c.goalId == nearGoal.id);
      final farIdx = works.indexWhere((c) => c.goalId == farGoal.id);
      expect(
        nearIdx,
        greaterThanOrEqualTo(0),
        reason: 'near-deadline goal must be scheduled',
      );
      expect(
        farIdx,
        greaterThanOrEqualTo(0),
        reason: 'far-deadline goal must be scheduled',
      );
      expect(
        nearIdx,
        lessThan(farIdx),
        reason: 'near-deadline outcome must precede far-deadline outcome',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T-09-05: ENGINE-05 — lighter-day reduces discretionary chunk count
  // ---------------------------------------------------------------------------
  test(
    'T-09-05: lighterDay=true yields strictly fewer chunks than lighterDay=false at mood 5',
    () {
      // At mood 5: lighterDay=false → cap=11; lighterDay=true → cap drops to mood 4 → cap=9
      final goals = List.generate(12, (i) => makeHabit(name: 'Habit $i'));
      final resultHeavier = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 5,
        date: monday,
        completionLogs: [],
        lighterDay: false,
      );
      final resultLighter = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 5,
        date: monday,
        completionLogs: [],
        lighterDay: true,
      );
      expect(
        workChunksOf(resultLighter),
        lessThan(workChunksOf(resultHeavier)),
        reason: 'lighter day must reduce discretionary chunk count',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T-09-06: ENGINE-06 — high-priority goal wins 1-slot competition
  // ---------------------------------------------------------------------------
  test(
    'T-09-06: high-priority time-target goal wins 1-slot competition over low-priority',
    () {
      // mood=1, lighterDay=false: cap=6, no outcome goals → only habits and time-targets NOT included
      // Use mood=3 and set up exactly 1 remaining capacity slot.
      // mood=3 cap with lighterDay=true → uses mood=2 cap=6.
      // Fill 5 slots with habits, leave 1 remaining slot for time-targets.
      // High-priority goal (0.75) vs low-priority goal (0.25) — high must win the slot.
      final habits = List.generate(5, (i) => makeHabit(name: 'Habit $i'));
      final highPriGoal = makeTimeTarget(
        name: 'High',
        weeklyHourBudget: 10,
        priorityWeight: 0.75,
      );
      final lowPriGoal = makeTimeTarget(
        name: 'Low',
        weeklyHourBudget: 10,
        priorityWeight: 0.25,
      );
      final result = sut.generate(
        goals: [...habits, highPriGoal, lowPriGoal],
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
        lighterDay: true, // cap=6, habits fill 5 → 1 slot left
      );
      final highChunks = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == highPriGoal.id,
          )
          .length;
      final lowChunks = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == lowPriGoal.id,
          )
          .length;
      expect(
        highChunks,
        greaterThan(0),
        reason: 'high-priority goal must win the capacity slot',
      );
      expect(
        lowChunks,
        0,
        reason:
            'low-priority goal must be excluded when capacity is filled by high-priority',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T-09-WR02: computeStreak — missed due day (no log entry) breaks streak
  //
  // Locks the spec decision: "A due day that is skipped or missed resets the
  // streak to 0" (09-CONTEXT.md). A truly missed day has no log entry at all;
  // the old log-walk was blind to it. The new calendar-walk detects the gap.
  // ---------------------------------------------------------------------------
  test('T-09-WR02: missed due day (no log entry) breaks streak to 0', () {
    // 3x/week habit: due Mon(1)/Wed(3)/Fri(5).
    // Scenario: user completes Monday and Wednesday of one week, then misses
    // Friday entirely (no log entry), then completes the following Monday.
    // Expected streak from the following Monday: 1 (Friday gap resets it).
    // Without the calendar-walk fix, the old impl would return 3 (invisible gap).
    final habit = Goal(
      id: 'streak-gap-goal',
      name: 'Run',
      goalTypeIndex: GoalType.habit.index,
      frequencyPerWeek: 3, // Mon/Wed/Fri
    );

    // Week 1: complete Mon 2026-03-23 and Wed 2026-03-25; miss Fri 2026-03-27.
    // Week 2: complete Mon 2026-03-30 (today).
    final logs = [
      makeLog(goalId: habit.id, dateYmd: '2026-03-23'), // Mon week 1
      makeLog(goalId: habit.id, dateYmd: '2026-03-25'), // Wed week 1
      // Fri 2026-03-27 intentionally absent — truly missed
      makeLog(goalId: habit.id, dateYmd: '2026-03-30'), // Mon week 2 (today)
    ];

    final dueWeekdays = ScheduleGeneratorService.computeDueWeekdays(3);
    // today = Mon 2026-03-30
    final today = DateTime(2026, 3, 30);
    final streak = ScheduleGeneratorService.computeStreak(
      habit.id,
      dueWeekdays,
      logs,
      today: today,
    );

    // Walk from today (Mon 30, completed=1) → Fri 27 (no entry → break).
    // Streak must be 1, not 3.
    expect(
      streak,
      1,
      reason:
          'A missed Friday (no log) must break the streak; '
          'only the Monday completion after the gap should count',
    );
  });

  // ---------------------------------------------------------------------------
  // REVIEW-02: higher priorityWeight goal appears before lower in generated chunks
  // ---------------------------------------------------------------------------
  test(
    'higher priorityWeight goal appears before lower priorityWeight goal in generated chunks',
    () {
      final highPriorityGoal = makeOutcome(name: 'High', priorityWeight: 0.75);
      final lowPriorityGoal = makeOutcome(name: 'Low', priorityWeight: 0.25);
      // Pass low-priority first to confirm ordering is by weight, not input order
      final result = sut.generate(
        goals: [lowPriorityGoal, highPriorityGoal],
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
      );
      final goalChunks = result.where((c) => c.goalId != null).toList();
      final highIdx = goalChunks.indexWhere(
        (c) => c.goalId == highPriorityGoal.id,
      );
      final lowIdx = goalChunks.indexWhere(
        (c) => c.goalId == lowPriorityGoal.id,
      );
      expect(
        highIdx,
        greaterThanOrEqualTo(0),
        reason: 'high-priority goal must be scheduled',
      );
      expect(
        lowIdx,
        greaterThanOrEqualTo(0),
        reason: 'low-priority goal must be scheduled',
      );
      expect(
        highIdx,
        lessThan(lowIdx),
        reason:
            'high-priority goal (0.75) must appear before low-priority goal (0.25)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Phase 14 — PRIORITY-01 engine behavioral tests (criteria 3 & 4)
  // ---------------------------------------------------------------------------

  test(
    'Step 2: high-priority habit is scheduled before low-priority habit',
    () {
      final highHabit = makeHabit(name: 'High Habit', priorityWeight: 0.75)
        ..frequencyPerWeek = 7; // due every day
      final lowHabit = makeHabit(name: 'Low Habit', priorityWeight: 0.25)
        ..frequencyPerWeek = 7; // due every day

      final result = sut.generate(
        goals: [lowHabit, highHabit], // intentionally low first in input order
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
        lighterDay: false,
      );
      final workChunks = result
          .where((c) => c.chunkType == ChunkType.work)
          .toList();
      expect(workChunks, isNotEmpty);
      expect(
        workChunks.first.goalId,
        equals(highHabit.id),
        reason:
            'High-priority habit must be scheduled before low-priority habit',
      );
    },
  );

  test(
    'Step 4: high-priority time-target goal with equal remaining hours gets chunk before low-priority',
    () {
      // Both goals have same weeklyHourBudget=2h and no completions → equal remaining hours.
      // High-priority goal should score higher and fill cap first.
      final highTT = makeTimeTarget(
        name: 'High TT',
        weeklyHourBudget: 2.0,
        priorityWeight: 0.75,
      );
      final lowTT = makeTimeTarget(
        name: 'Low TT',
        weeklyHourBudget: 2.0,
        priorityWeight: 0.25,
      );

      final result = sut.generate(
        goals: [lowTT, highTT], // intentionally low first
        blocks: [],
        moodIndex: 3, // cap=8; both goals get chunks, so check order of first
        date: monday,
        completionLogs: [],
        lighterDay: false,
      );
      final workGoalIds = result
          .where((c) => c.chunkType == ChunkType.work && c.goalId != null)
          .map((c) => c.goalId!)
          .toList();
      expect(workGoalIds, isNotEmpty);
      // First chunk must belong to highTT (composite score: 2.0 * 0.75 = 1.5 > 2.0 * 0.25 = 0.5)
      expect(
        workGoalIds.first,
        equals(highTT.id),
        reason:
            'High-priority time-target goal must receive chunks before low-priority goal',
      );
    },
  );

  test(
    'Step 4: high-priority goal gets at least as many chunks as low-priority under shared cap',
    () {
      // weeklyHourBudget=12h → demand = min(ceil(12*60/25/7), 4) = min(5, 4) = 4 chunks each.
      // (The per-goal daily cap in _demandForTimeTarget is 4.)
      // moodIndex=3 + lighterDay=true → effective cap = moodCap[2] = 6 (one tier lower).
      // Two goals × 4 demand = 8 > cap 6, so cap is genuinely binding.
      // High TT composite score = 12.0 * 0.75 = 9.0 → sorted first → gets 4 chunks (6-4=2 left).
      // Low TT composite score  = 12.0 * 0.25 = 3.0 → sorted second → gets 2 chunks.
      // If priority ordering were removed, low would go first and high would get 2.
      // The greaterThan assertion below would fail (2 > 4 is false) — genuinely non-trivial.
      final highTT = makeTimeTarget(
        name: 'High TT',
        weeklyHourBudget: 12.0,
        priorityWeight: 0.75,
      );
      final lowTT = makeTimeTarget(
        name: 'Low TT',
        weeklyHourBudget: 12.0,
        priorityWeight: 0.25,
      );

      final result = sut.generate(
        goals: [
          lowTT,
          highTT,
        ], // intentionally low first — engine must reorder by score
        blocks: [],
        moodIndex: 3, // mood 3+ required — Step 4 is disabled at mood 1-2
        date: monday,
        completionLogs: [],
        lighterDay:
            true, // drops cap to tier-2 (6), making combined demand (8) binding
      );
      final highCount = result
          .where((c) => c.chunkType == ChunkType.work && c.goalId == highTT.id)
          .length;
      final lowCount = result
          .where((c) => c.chunkType == ChunkType.work && c.goalId == lowTT.id)
          .length;
      // With effective cap=6 and demand=4 each: high gets 4, low gets 2.
      // greaterThan (not greaterThanOrEqualTo) ensures the test is not trivially
      // satisfied when both counts are equal (i.e., when Step 4 never ran or
      // priority ordering had no effect).
      expect(
        highCount,
        greaterThan(lowCount),
        reason:
            'High-priority goal (score 9.0) must win more cap slots than '
            'low-priority goal (score 3.0) when total demand exceeds the effective cap',
      );
    },
  );

  test(
    'T-09-WR02b: no missed days — consecutive completions count correctly',
    () {
      // 3x/week habit: Mon/Wed/Fri. All three due days completed in order.
      // Today = the Friday. Streak must be 3.
      final habit = Goal(
        id: 'streak-full-goal',
        name: 'Run',
        goalTypeIndex: GoalType.habit.index,
        frequencyPerWeek: 3,
      );

      final logs = [
        makeLog(goalId: habit.id, dateYmd: '2026-03-23'), // Mon
        makeLog(goalId: habit.id, dateYmd: '2026-03-25'), // Wed
        makeLog(goalId: habit.id, dateYmd: '2026-03-27'), // Fri (today)
      ];

      final dueWeekdays = ScheduleGeneratorService.computeDueWeekdays(3);
      final today = DateTime(2026, 3, 27); // Friday
      final streak = ScheduleGeneratorService.computeStreak(
        habit.id,
        dueWeekdays,
        logs,
        today: today,
      );

      expect(
        streak,
        3,
        reason: 'Three consecutive due-day completions must yield streak = 3',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Weekday-biased frequency → due-weekday mapping.
  // freq ≤ 5 stays on Mon–Fri (never weekends); 6 adds Sat; 7 is daily.
  // ---------------------------------------------------------------------------
  group('computeDueWeekdays is weekday-biased', () {
    test('freq=5 is Mon–Fri (no weekend) — the reported bug', () {
      expect(
        ScheduleGeneratorService.computeDueWeekdays(5),
        {1, 2, 3, 4, 5},
        reason: '5x/week must mean weekdays, not include Saturday',
      );
    });

    test('lower frequencies spread within the work week', () {
      expect(ScheduleGeneratorService.computeDueWeekdays(1), {1});
      expect(ScheduleGeneratorService.computeDueWeekdays(2), {1, 4});
      expect(ScheduleGeneratorService.computeDueWeekdays(3), {1, 3, 5});
      expect(ScheduleGeneratorService.computeDueWeekdays(4), {1, 2, 4, 5});
    });

    test('freq=6 adds Saturday; freq=7 is daily', () {
      expect(ScheduleGeneratorService.computeDueWeekdays(6), {
        1,
        2,
        3,
        4,
        5,
        6,
      });
      expect(ScheduleGeneratorService.computeDueWeekdays(7), {
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      });
    });

    test(
      'a 5x/week habit is NOT scheduled on Saturday but IS on a weekday',
      () {
        final habit = Goal(
          name: 'Weekday habit',
          goalTypeIndex: GoalType.habit.index,
          frequencyPerWeek: 5,
        );
        final onSaturday = sut.generate(
          goals: [habit],
          blocks: [],
          moodIndex: 3,
          date: saturday,
        );
        expect(
          onSaturday.where((c) => c.chunkType == ChunkType.work),
          isEmpty,
          reason: 'Weekday (5x/week) habit must not fire on Saturday',
        );
        final onMonday = sut.generate(
          goals: [habit],
          blocks: [],
          moodIndex: 3,
          date: monday,
        );
        expect(
          onMonday.where((c) => c.chunkType == ChunkType.work).length,
          1,
          reason: 'Weekday habit must fire on Monday',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Start-time floor: a mid-day generation packs from "now", not 8:00 AM.
  // ---------------------------------------------------------------------------
  group('startFloorMinutes places discretionary work near "now"', () {
    final habit = Goal(name: 'Daily', goalTypeIndex: GoalType.habit.index);

    test('null floor keeps the 8:00 AM (480) default start', () {
      final chunks = sut.generate(
        goals: [habit],
        blocks: [],
        moodIndex: 3,
        date: monday,
      );
      final work = chunks.firstWhere((c) => c.chunkType == ChunkType.work);
      expect(work.syntheticStartMinutes, 480);
    });

    test(
      'a 15:42 floor starts the chunk at 15:45 (rounded up to 5), not 8 AM',
      () {
        final chunks = sut.generate(
          goals: [habit],
          blocks: [],
          moodIndex: 3,
          date: monday,
          startFloorMinutes: 942, // 15:42
        );
        final work = chunks.firstWhere((c) => c.chunkType == ChunkType.work);
        expect(work.syntheticStartMinutes, 945); // 15:45
      },
    );

    test('a floor earlier than 8:00 AM is clamped up to 480', () {
      final chunks = sut.generate(
        goals: [habit],
        blocks: [],
        moodIndex: 3,
        date: monday,
        startFloorMinutes: 360, // 06:00 — before the day start
      );
      final work = chunks.firstWhere((c) => c.chunkType == ChunkType.work);
      expect(work.syntheticStartMinutes, 480);
    });
  });
}
