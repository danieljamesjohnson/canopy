import 'package:flutter_test/flutter_test.dart';
import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/energy_valence.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/services/schedule_generator.dart';
import 'package:canopy/services/weekly_progress_service.dart';

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
    EnergyValence valence = EnergyValence.neutral,
  }) => Goal(
    name: name,
    goalTypeIndex: GoalType.outcome.index,
    deadline: deadline,
    priorityWeight: priorityWeight,
    energyValenceIndex: valence.index,
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
    EnergyValence valence = EnergyValence.neutral,
  }) => Goal(
    name: name,
    goalTypeIndex: GoalType.timeTarget.index,
    weeklyHourBudget: weeklyHourBudget,
    priorityWeight: priorityWeight,
    energyValenceIndex: valence.index,
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
  // correct anchoredStartMinutes, with a 5-minute break between them
  // (COMMITBREAK-01, Phase 30); NOT generated on Saturday.
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
    expect(workChunks[1].anchoredStartMinutes, 570); // 540 + 25 + 5 (break)
    expect(workChunks[0].goalId, isNull);
    expect(workChunks[1].goalId, isNull);

    final shortBreaks = result
        .where((c) => c.chunkType == ChunkType.shortBreak)
        .toList();
    expect(shortBreaks.length, 2);
    expect(shortBreaks[0].anchoredStartMinutes, 565);
    expect(shortBreaks[0].durationMinutes, 5);
    expect(shortBreaks[1].anchoredStartMinutes, 595);
    expect(shortBreaks[1].durationMinutes, 5);
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
  // Test 6: 4 work chunks, mood=3 → shortBreak after every chunk, plus a
  // surviving trailing long break at the cadence boundary (D-05/LATTICE-02:
  // never silently suppressed, even when the boundary chunk is the day's
  // last chunk).
  // ---------------------------------------------------------------------------
  test(
    'Test 6: mood=3 break pattern with 4 work chunks (boundary chunk is the last chunk)',
    () {
      // Use 4 habits to generate exactly 4 work chunks.
      // lighterDay: false → cap=8, habitCeiling=4 (CAP-01), so all 4 habits fit.
      // N=4 (mood 3): chunk 4 is the cadence boundary AND the day's last
      // chunk — under the lattice each cell starts on a 30-min boundary:
      // W@480(25) SB@505(5) W@510(25) SB@535(5) W@540(25) SB@565(5)
      // W@570(25) SB@595(5) LB@600(30).
      final goals = List.generate(4, (i) => makeHabit(name: 'Habit $i'));
      final result = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
        lighterDay: false,
      );
      // Verify chunk order: W SB W SB W SB W SB LB (trailing long break survives)
      expect(result.length, 9);
      expect(result[0].chunkType, ChunkType.work);
      expect(result[1].chunkType, ChunkType.shortBreak);
      expect(result[2].chunkType, ChunkType.work);
      expect(result[3].chunkType, ChunkType.shortBreak);
      expect(result[4].chunkType, ChunkType.work);
      expect(result[5].chunkType, ChunkType.shortBreak);
      expect(result[6].chunkType, ChunkType.work);
      expect(result[7].chunkType, ChunkType.shortBreak);
      expect(result[8].chunkType, ChunkType.longBreak);
      expect(result[7].durationMinutes, 5);
      expect(result[8].durationMinutes, 30);
      // Trailing long break survives (D-05) — no longer trimmed.
      expect(result.last.chunkType, ChunkType.longBreak);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 7: 2 work chunks, mood=1 → shortBreak after chunk 1, plus a
  // surviving trailing long break at the cadence boundary (D-05).
  // ---------------------------------------------------------------------------
  test(
    'Test 7: mood=1 break pattern with 2 work chunks (boundary chunk is the last chunk)',
    () {
      // At mood=1, habitCeiling=ceil(4/2)=2 (CAP-01), so 3 habits produces 2 chunks.
      // N=2 (mood 1): chunk 2 is the cadence boundary AND the day's last
      // chunk: W@480(25) SB@505(5) W@510(25) SB@535(5) LB@540(30).
      final goals = List.generate(3, (i) => makeHabit(name: 'Habit $i'));
      final result = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 1,
        date: monday,
        completionLogs: [],
      );
      // With CAP-01 ceiling=2: only 2 habit chunks placed. Pattern: W SB W SB LB.
      expect(result.length, 5);
      expect(result[0].chunkType, ChunkType.work);
      expect(result[1].chunkType, ChunkType.shortBreak);
      expect(result[2].chunkType, ChunkType.work);
      expect(result[3].chunkType, ChunkType.shortBreak);
      expect(result[4].chunkType, ChunkType.longBreak);
      expect(result[3].durationMinutes, 5);
      expect(result[4].durationMinutes, 30);
      // Trailing long break survives (D-05) — no longer trimmed.
      expect(result.last.chunkType, ChunkType.longBreak);
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
  // Test 10: commitment block + discretionary habits → a break DOES sit
  //          between consecutive commitment work chunks (COMMITBREAK-01,
  //          Phase 30 — this reverses the pre-Phase-30 READ-02 assertion).
  // ---------------------------------------------------------------------------
  test(
    'Test 10: commitment block + discretionary — a break sits between consecutive commitment work chunks',
    () {
      // makeBlock() is Mon-Fri 540-600 → 2 anchored work chunks at 540, 570,
      // with a 5-minute break at 565 closing the first cell (COMMITBREAK-01).
      final block = makeBlock();
      final result = sut.generate(
        goals: [makeHabit()],
        blocks: [block],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
      );
      final idx540 = result.indexWhere((c) => c.anchoredStartMinutes == 540);
      expect(
        idx540,
        greaterThanOrEqualTo(0),
        reason: 'chunk at 540 must be present',
      );
      expect(
        result[idx540 + 1].chunkType,
        ChunkType.shortBreak,
        reason:
            'a 5-minute break must close the commitment work chunk\'s own '
            'cell (COMMITBREAK-01)',
      );
      final nextWork = result
          .skip(idx540 + 1)
          .firstWhere((c) => c.chunkType == ChunkType.work);
      expect(
        nextWork.anchoredStartMinutes,
        570,
        reason: 'the next commitment work chunk starts after the break',
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
  // Test 13: all-commitment day (no discretionary) → 2 work chunks + 2 short
  // breaks; the cadence boundary (N=4 at mood 3) is never reached
  // (COMMITBREAK-01, Phase 30 — this reverses the pre-Phase-30 "no breaks"
  // assertion).
  // ---------------------------------------------------------------------------
  test(
    'Test 13: all-commitment day → commitment work chunks with breaks between them, no long break at N=4',
    () {
      // makeBlock() generates 2 work chunks + 2 short breaks; no
      // discretionary goals. Mood 3 -> N=4, and only 2 work chunks are ever
      // produced by this 60-min window, so the cadence boundary (every 4th
      // chunk) is never reached — zero long breaks.
      final block = makeBlock();
      final result = sut.generate(
        goals: [],
        blocks: [block],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
      );
      final shortBreaks = result
          .where((c) => c.chunkType == ChunkType.shortBreak)
          .toList();
      final longBreaks = result
          .where((c) => c.chunkType == ChunkType.longBreak)
          .toList();
      expect(workChunksOf(result), equals(2));
      expect(
        shortBreaks.length,
        equals(2),
        reason: 'a break closes every commitment work cell (COMMITBREAK-01)',
      );
      expect(
        longBreaks,
        isEmpty,
        reason: 'only 2 work chunks are produced; N=4 is never reached',
      );
    },
  );

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
  // discretionary chunk's own 5-min short break is followed by a separate
  // 30-min long break (D-06); the synthetic times must leave that footprint's
  // full room before the next chunk so no two chunks overlap after the sort
  // (the packing/emit cadence counters cannot diverge).
  // ---------------------------------------------------------------------------
  test(
    'WR-01: emitted long break matches reserved slot — no overlapping synthetic times',
    () {
      // 4 habits + 1 time-target goal at mood=3, lighterDay=false (cap=8, ceiling=4).
      // Habits fill the ceiling (4 chunks), then the time-target adds 1+ chunks.
      // With 5+ chunks and longBreakEvery=4, the break after chunk 4 is long (25 min).
      final goals = [
        ...List.generate(4, (i) => makeHabit(name: 'Habit $i')),
        makeTimeTarget(name: 'Regular', weeklyHourBudget: 5),
      ];
      final result = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
        lighterDay: false,
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
      expect(longBreaks.first.durationMinutes, 30);
    },
  );

  // ---------------------------------------------------------------------------
  // Test WR-03: a discretionary chunk packed into a narrow pre-commitment gap
  // must not cause a DISCRETIONARY break to sort inside the commitment
  // window; the commitment's OWN internal break (COMMITBREAK-01, Phase 30)
  // legitimately sits inside that window and is asserted separately below —
  // this test passes unchanged pre- and post-fix (capacity-driven omission
  // pre-fix produces the same 540/565 adjacency this test already asserted,
  // for a different underlying reason than its old comment stated), so its
  // comment is corrected here rather than its behavior.
  // ---------------------------------------------------------------------------
  test(
    'WR-03: no discretionary break sorts inside the commitment window (narrow pre-gap)',
    () {
      // Commitment block 540-590 (a 50-minute window — exactly 2x25 with no
      // slack for a full break-and-cell). Post COMMITBREAK-01: one work
      // chunk (540-565) and its own short break, footprint-checked at
      // 565+5=570<=590 (fits), then tail-stretched by the remaining 20
      // minutes to close the window: 565-590, 25 minutes total. A free gap
      // exists before the block (480-540) into which discretionary chunks
      // are packed.
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

      final idx565 = result.indexWhere((c) => c.anchoredStartMinutes == 565);
      expect(idx565, greaterThanOrEqualTo(0));
      expect(result[idx565].chunkType, ChunkType.shortBreak);
      expect(result[idx565].durationMinutes, 25);

      // No DISCRETIONARY break chunk may sit inside the commitment window
      // [540, 590) — re-scoped to commitmentId == null (WR-03) and to
      // displayStartMinutes so a legitimate anchored commitment break
      // (commitmentId == block.id) is never mistaken for a violation.
      for (final c in result) {
        if (c.chunkType == ChunkType.work) continue;
        if (c.commitmentId != null) continue;
        final start = c.displayStartMinutes ?? 9999;
        final insideWindow = start >= 540 && start < 590;
        expect(
          insideWindow,
          isFalse,
          reason:
              'discretionary break at $start must not fall inside the '
              'commitment window (WR-03)',
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
      // mood=3, lighterDay=true → cap=6, habitCeiling=3 (CAP-01).
      // 3 habits fill the ceiling (3 slots). 2 normal-priority outcomes fill 2 more.
      // 1 slot remains for time-targets. High-priority TT must win that slot.
      final habits = List.generate(3, (i) => makeHabit(name: 'Habit $i'));
      final outcomes = List.generate(2, (i) => makeOutcome(name: 'Outcome $i'));
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
        goals: [...habits, ...outcomes, highPriGoal, lowPriGoal],
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
        lighterDay: true, // cap=6: 3 habits + 2 outcomes = 5, 1 slot left
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
    'Step 4: high-priority time-target goal gets strictly more chunks than low-priority under shared cap',
    () {
      // weeklyHourBudget=12h → demand = min(ceil(12*60/25/7), 4) = min(5, 4) = 4 chunks each.
      // (The per-goal daily cap in _demandForTimeTarget is 4.)
      // moodIndex=3 + lighterDay=true → effective cap = moodCap[2] = 6 (one tier lower).
      // Two goals × 4 demand = 8 > cap 6, so cap is genuinely binding.
      // PRIORITY-03 surplus: high (0.75) gets +1 chunk before the round-robin → disc=1.
      // Round-robin fills remaining 5 slots alternating high/low:
      //   pass 1: high (placed→2, disc=2), low (placed→1, disc=3)
      //   pass 2: high (placed→3, disc=4), low (placed→2, disc=5)
      //   pass 3: high (placed→4, disc=6=cap) → stops
      // Final: high=4, low=2 → high > low (success criterion 5 satisfied).
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
        moodIndex: 3,
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
      // PRIORITY-03: priority surplus ensures high-priority gets strictly more
      // chunks than low-priority (success criterion 5: "higher-priority goals
      // receive more chunks and no single goal claims the entire open day").
      expect(
        highCount,
        greaterThan(lowCount),
        reason:
            'High-priority goal (score 9.0) must get strictly more cap slots than '
            'low-priority goal (score 3.0) — PRIORITY-03 surplus awards the extra '
            'chunk before the round-robin',
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
  // CAP-01: habit ceiling prevents monopolization on low-mood days
  // ---------------------------------------------------------------------------
  test(
    'CAP-01: mood=1, 4 daily habits + 1 outcome → outcome receives ≥1 chunk',
    () {
      final habits = List.generate(4, (i) => makeHabit(name: 'Habit $i'));
      final outcome = makeOutcome(
        name: 'Outcome',
        deadline: monday.add(const Duration(days: 7)),
      );
      final result = sut.generate(
        goals: [...habits, outcome],
        blocks: [],
        moodIndex: 1,
        date: monday,
        completionLogs: [],
        lighterDay: false,
      );
      final outcomeChunks = result
          .where((c) => c.chunkType == ChunkType.work && c.goalId == outcome.id)
          .length;
      expect(
        outcomeChunks,
        greaterThanOrEqualTo(1),
        reason:
            'CAP-01: outcome must receive capacity even when 4 habits compete',
      );
    },
  );

  test('CAP-01: mood=1 total work chunks do not exceed cap', () {
    final goals = List.generate(4, (i) => makeHabit(name: 'Habit $i'))
      ..add(makeOutcome(deadline: monday.add(const Duration(days: 7))));
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 1,
      date: monday,
      completionLogs: [],
      lighterDay: false,
    );
    expect(
      workChunksOf(result),
      lessThanOrEqualTo(4),
      reason: 'CAP-01: mood=1 cap=4; total work chunks must not exceed cap',
    );
  });

  // ---------------------------------------------------------------------------
  // PRIORITY-02: priority changes chunk count, not just sort order
  // ---------------------------------------------------------------------------
  test(
    'PRIORITY-02: high-priority habit (0.75) gets more chunks than normal (0.5) at mood=3',
    () {
      final highHabit = makeHabit(name: 'High', priorityWeight: 0.75)
        ..frequencyPerWeek = 7;
      final normalHabit = makeHabit(name: 'Normal', priorityWeight: 0.5)
        ..frequencyPerWeek = 7;
      final result = sut.generate(
        goals: [normalHabit, highHabit],
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
        lighterDay: false,
      );
      final highCount = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == highHabit.id,
          )
          .length;
      final normalCount = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == normalHabit.id,
          )
          .length;
      expect(
        highCount,
        greaterThan(normalCount),
        reason:
            'PRIORITY-02: high-priority habit must receive more chunks than normal-priority habit',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // PRIORITY-02 (outcome): priority changes outcome chunk count at mood=3
  // ---------------------------------------------------------------------------
  test(
    'PRIORITY-02: high-priority outcome (0.75) gets more chunks than normal (0.5) at mood=3',
    () {
      final deadline = monday.add(const Duration(days: 7));
      final highOutcome = makeOutcome(
        name: 'High outcome',
        deadline: deadline,
        priorityWeight: 0.75,
      );
      final normalOutcome = makeOutcome(
        name: 'Normal outcome',
        deadline: deadline,
        priorityWeight: 0.5,
      );
      final result = sut.generate(
        goals: [normalOutcome, highOutcome],
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
        lighterDay: false,
      );
      final highCount = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == highOutcome.id,
          )
          .length;
      final normalCount = result
          .where(
            (c) =>
                c.chunkType == ChunkType.work && c.goalId == normalOutcome.id,
          )
          .length;
      expect(
        highCount,
        greaterThan(normalCount),
        reason:
            'PRIORITY-02: high-priority outcome must receive more chunks than normal-priority outcome at mood=3',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // FILL-01: time-target goals appear on low-mood days with open capacity
  // ---------------------------------------------------------------------------
  test(
    'FILL-01: mood=1, open capacity after habits → time-target goal appears in schedule',
    () {
      // With CAP-01 fix: 2 daily habits fill ceil(4/2)=2 slots; 2 slots remain.
      // A time-target goal must fill those remaining slots.
      final habits = List.generate(2, (i) => makeHabit(name: 'Habit $i'));
      final tt = makeTimeTarget(name: 'Regular-time', weeklyHourBudget: 5);
      final result = sut.generate(
        goals: [...habits, tt],
        blocks: [],
        moodIndex: 1,
        date: monday,
        completionLogs: [],
      );
      final ttChunks = result
          .where((c) => c.chunkType == ChunkType.work && c.goalId == tt.id)
          .length;
      expect(
        ttChunks,
        greaterThanOrEqualTo(1),
        reason:
            'FILL-01: regular-time goal must appear on a low-mood day with open capacity',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // FILL-02: open capacity distributed across multiple time-target goals
  // ---------------------------------------------------------------------------
  test(
    'FILL-02: 3 time-target goals with limited cap — no single goal swallows all open slots',
    () {
      // mood=3, lighterDay=false → cap=8. No habits.
      // weeklyHourBudget=10 → demand=ceil(10*60/25/7)=4 per goal (total 12, binding at 8).
      // With round-robin: each goal gets ~2-3 chunks. Without: goal 1 gets 4, goal 3 gets 0.
      final goals = [
        makeTimeTarget(name: 'G1', weeklyHourBudget: 10, priorityWeight: 0.5),
        makeTimeTarget(name: 'G2', weeklyHourBudget: 10, priorityWeight: 0.5),
        makeTimeTarget(name: 'G3', weeklyHourBudget: 10, priorityWeight: 0.5),
      ];
      final result = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
        lighterDay: false,
      );
      final g1 = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == goals[0].id,
          )
          .length;
      final g3 = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == goals[2].id,
          )
          .length;
      expect(
        g3,
        greaterThanOrEqualTo(1),
        reason:
            'FILL-02: last goal in priority list must receive at least 1 chunk (no monopoly)',
      );
      expect(
        g1,
        lessThanOrEqualTo(workChunksOf(result) - 1),
        reason: 'FILL-02: first goal must not swallow all capacity',
      );
    },
  );

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
      'a 15:42 floor starts the chunk at 16:00 (rounded up to 30), not 8 AM',
      () {
        final chunks = sut.generate(
          goals: [habit],
          blocks: [],
          moodIndex: 3,
          date: monday,
          startFloorMinutes: 942, // 15:42
        );
        final work = chunks.firstWhere((c) => c.chunkType == ChunkType.work);
        // D-03: round up to the next 30-minute boundary, not 5.
        expect(work.syntheticStartMinutes, 960); // 16:00
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

  // ---------------------------------------------------------------------------
  // Phase 20 RED tests: VSCHED-01/02/03 + determinism
  // These tests FAIL against the unmodified engine (RED state).
  // Plan 20-02 will implement the engine changes that make them GREEN.
  // ---------------------------------------------------------------------------

  // VSCHED-01 (time-target): low/stormy day → gives-valence time-target appears
  test(
    'VSCHED-01 time-target: low/stormy day → gives-valence time-target appears',
    () {
      final givesGoal = makeTimeTarget(
        name: 'Yoga',
        weeklyHourBudget: 3,
        valence: EnergyValence.gives,
      );
      final habitGoal = makeHabit(name: 'Meditation');
      final result = sut.generate(
        goals: [givesGoal, habitGoal],
        blocks: [],
        moodIndex: 1,
        date: monday,
        lighterDay: true,
        completionLogs: [],
      );
      final givesChunks = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == givesGoal.id,
          )
          .length;
      expect(
        givesChunks,
        greaterThanOrEqualTo(1),
        reason:
            'VSCHED-01: energy-giving time-target must appear on a low-mood day',
      );
    },
  );

  // VSCHED-01-outcome: low day → gives-valence outcome with no deadline appears
  test(
    'VSCHED-01-outcome: low day → gives-valence outcome with no deadline appears',
    () {
      final givesOutcome = makeOutcome(
        name: 'Read',
        deadline: null,
        valence: EnergyValence.gives,
      );
      final result = sut.generate(
        goals: [givesOutcome],
        blocks: [],
        moodIndex: 1,
        date: monday,
        lighterDay: true,
        completionLogs: [],
      );
      final chunks = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == givesOutcome.id,
          )
          .length;
      expect(
        chunks,
        greaterThanOrEqualTo(1),
        reason:
            'VSCHED-01: gives-valence outcome with no deadline must appear on low day',
      );
    },
  );

  // VSCHED-02: low day discretionary count < medium day count
  test('VSCHED-02: low day discretionary count < medium day count', () {
    final givesGoal = makeTimeTarget(
      name: 'Yoga',
      weeklyHourBudget: 10,
      valence: EnergyValence.gives,
    );
    final neutralGoal = makeTimeTarget(
      name: 'Work',
      weeklyHourBudget: 10,
      valence: EnergyValence.neutral,
    );
    final lowResult = sut.generate(
      goals: [givesGoal, neutralGoal],
      blocks: [],
      moodIndex: 1,
      date: monday,
      lighterDay: true,
      completionLogs: [],
    );
    final medResult = sut.generate(
      goals: [givesGoal, neutralGoal],
      blocks: [],
      moodIndex: 3,
      date: monday,
      lighterDay: true,
      completionLogs: [],
    );
    final lowCount = lowResult
        .where((c) => c.chunkType == ChunkType.work)
        .length;
    final medCount = medResult
        .where((c) => c.chunkType == ChunkType.work)
        .length;
    expect(
      lowCount,
      lessThan(medCount),
      reason:
          'VSCHED-02: low day must have fewer discretionary chunks than medium day',
    );
  });

  // VSCHED-02-neutral-excluded: neutral/costs time-target gets no restorative floor on low day
  test(
    'VSCHED-02-neutral-excluded: neutral/costs time-target gets no restorative floor on low day',
    () {
      // A SINGLE neutral time-target on a low day — the restorative floor must
      // not apply (it is gives-only). The neutral goal may still appear via
      // FILL-01, but only up to the normal FILL-01 cap of 1 on low mood.
      // Encoding: with only a neutral goal on a low day, the restorative floor
      // adds nothing extra — chunk count equals the FILL-01 cap of 1 (not 2).
      final neutralGoal = makeTimeTarget(
        name: 'Work',
        weeklyHourBudget: 10,
        valence: EnergyValence.neutral,
      );
      final result = sut.generate(
        goals: [neutralGoal],
        blocks: [],
        moodIndex: 1,
        date: monday,
        lighterDay: true,
        completionLogs: [],
      );
      final neutralChunks = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == neutralGoal.id,
          )
          .length;
      // The restorative floor is gives-only, so a neutral goal must NOT receive
      // a floor-boosted slot. The FILL-01 demand cap on low mood is 1, so the
      // neutral goal gets at most 1 chunk — exactly 1, not 2.
      expect(
        neutralChunks,
        equals(1),
        reason:
            'VSCHED-02-neutral-excluded: restorative floor must not boost a neutral goal; '
            'neutral goal gets exactly the FILL-01 cap of 1 chunk on a low day',
      );
    },
  );

  // VSCHED-03: high day under heavy backlog reserves a gives-valence slot
  test(
    'VSCHED-03: high day under heavy backlog reserves a gives-valence slot',
    () {
      final givesGoal = makeTimeTarget(
        name: 'Yoga',
        weeklyHourBudget: 10,
        valence: EnergyValence.gives,
      );
      final neutralGoals = List.generate(
        5,
        (i) => makeTimeTarget(
          name: 'Backlog $i',
          weeklyHourBudget: 10,
          valence: EnergyValence.neutral,
        ),
      );
      final result = sut.generate(
        goals: [givesGoal, ...neutralGoals],
        blocks: [],
        moodIndex: 4,
        date: monday,
        lighterDay: true,
        completionLogs: [],
      );
      final givesChunks = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == givesGoal.id,
          )
          .length;
      expect(
        givesChunks,
        greaterThanOrEqualTo(1),
        reason:
            'VSCHED-03: energy-giving goal must be reserved even under heavy backlog',
      );
    },
  );

  // VSCHED-03-highpri-fallback: high day, no gives goal → high-priority goal reserved
  test(
    'VSCHED-03-highpri-fallback: high day, no gives goal → high-priority goal reserved',
    () {
      // No gives-valence goals. One high-priority neutral goal among several
      // low-priority neutral backlog goals. The VSCHED-03 reservation pass must
      // select the high-priority goal (priorityWeight >= 0.75 qualifies).
      final highPriGoal = makeTimeTarget(
        name: 'High Priority',
        weeklyHourBudget: 10,
        priorityWeight: 0.9,
        valence: EnergyValence.neutral,
      );
      final lowPriGoals = List.generate(
        5,
        (i) => makeTimeTarget(
          name: 'Backlog $i',
          weeklyHourBudget: 10,
          priorityWeight: 0.3,
          valence: EnergyValence.neutral,
        ),
      );
      final result = sut.generate(
        goals: [highPriGoal, ...lowPriGoals],
        blocks: [],
        moodIndex: 4,
        date: monday,
        lighterDay: true,
        completionLogs: [],
      );
      final highPriChunks = result
          .where(
            (c) => c.chunkType == ChunkType.work && c.goalId == highPriGoal.id,
          )
          .length;
      expect(
        highPriChunks,
        greaterThanOrEqualTo(1),
        reason:
            'VSCHED-03-highpri-fallback: high-priority goal must be reserved when no gives-valence goal is present',
      );
    },
  );

  // determinism: same inputs produce same schedule
  test('determinism: same inputs produce same schedule', () {
    final goals = [
      makeTimeTarget(
        name: 'T',
        weeklyHourBudget: 5,
        valence: EnergyValence.gives,
      ),
    ];
    final r1 = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 3,
      date: monday,
      completionLogs: [],
    );
    final r2 = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 3,
      date: monday,
      completionLogs: [],
    );
    expect(
      r1.map((c) => c.goalId).toList(),
      equals(r2.map((c) => c.goalId).toList()),
      reason: 'determinism: same inputs must produce same schedule',
    );
  });

  // ---------------------------------------------------------------------------
  // CR-01 regression: gives-valence + high-priority time-target on a low-mood
  // day must NOT be double-placed. The restorative floor places exactly 1 chunk;
  // PRIORITY-03 must detect the prior placement and skip, yielding exactly the
  // floor count (1), not 2.
  // ---------------------------------------------------------------------------
  test(
    'CR-01 regression: gives+high-priority time-target on low-mood day gets exactly 1 chunk (no double-place)',
    () {
      // A gives-valence time-target with priorityWeight >= 0.75 and real demand
      // (3h budget, Monday = 7 days left → demand = ceil(3*60/25/7) = 1).
      // On moodIndex=1, lighterDay=true:
      //   - Restorative floor fires (gives valence, demand=1) → places 1 chunk,
      //     writes placedCountPerGoal[id]=1.
      //   - PRIORITY-03 fires (priorityWeight=0.9 >= 0.75); pre-fix it would
      //     place a 2nd chunk and overwrite the map to 1. Post-fix it reads
      //     alreadyPlaced=1, demand=clamp(1,0,1)=1, alreadyPlaced >= demand →
      //     skips. Result: exactly 1 chunk.
      final givesHighPriGoal = makeTimeTarget(
        name: 'Yoga (high pri)',
        weeklyHourBudget: 3,
        priorityWeight: 0.9,
        valence: EnergyValence.gives,
      );
      final result = sut.generate(
        goals: [givesHighPriGoal],
        blocks: [],
        moodIndex: 1,
        date: monday,
        lighterDay: true,
        completionLogs: [],
      );
      final chunks = result
          .where(
            (c) =>
                c.chunkType == ChunkType.work &&
                c.goalId == givesHighPriGoal.id,
          )
          .length;
      expect(
        chunks,
        equals(1),
        reason:
            'CR-01: gives-valence+high-priority goal must receive exactly 1 chunk '
            'on a low-mood day (restorative floor fills demand; PRIORITY-03 must '
            'not double-place when alreadyPlaced >= demand)',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // One-off (dated) commitments — a human entering a real event on a specific
  // day. A dated block anchors ONLY on its date, ignoring weekdays.
  // ---------------------------------------------------------------------------
  group('one-off dated commitments', () {
    // A one-off block on Monday 2026-03-23, 09:00–10:00 (60-min → 2 slots).
    CommitmentBlock oneOffOnMonday() => CommitmentBlock(
      name: 'Dentist',
      daysOfWeek: const [], // one-off carries no recurring weekdays
      startMinutes: 540,
      endMinutes: 600,
      date: DateTime(2026, 3, 23),
    );

    test('anchors on its specific date', () {
      final result = sut.generate(
        goals: [],
        blocks: [oneOffOnMonday()],
        moodIndex: 3,
        date: monday, // 2026-03-23
        completionLogs: [],
      );
      final workChunks = result
          .where((c) => c.chunkType == ChunkType.work)
          .toList();
      expect(workChunks.length, 2);
      expect(workChunks[0].anchoredStartMinutes, 540);
      expect(workChunks[0].rationale, 'Dentist');
    });

    test('does NOT anchor on a different date (even same weekday)', () {
      // Monday 2026-03-30 — same weekday as the block's date but a week later.
      final nextMonday = DateTime(2026, 3, 30);
      final result = sut.generate(
        goals: [],
        blocks: [oneOffOnMonday()],
        moodIndex: 3,
        date: nextMonday,
        completionLogs: [],
      );
      expect(result, isEmpty);
    });

    test('date-only equality ignores any time component on the date', () {
      final block = CommitmentBlock(
        name: 'Appt',
        daysOfWeek: const [],
        startMinutes: 540,
        endMinutes: 600,
        date: DateTime(2026, 3, 23, 14, 30), // 2:30pm component
      );
      final result = sut.generate(
        goals: [],
        blocks: [block],
        moodIndex: 3,
        date: monday, // midnight 2026-03-23
        completionLogs: [],
      );
      expect(
        result.where((c) => c.chunkType == ChunkType.work).length,
        2,
        reason: 'day-equality must match regardless of time-of-day component',
      );
    });

    test('recurring and one-off blocks coexist on a matching day', () {
      final recurring = makeBlock(
        name: 'Work',
        daysOfWeek: const [1], // Monday
        startMinutes: 600,
        endMinutes: 650,
      );
      final result = sut.generate(
        goals: [],
        blocks: [recurring, oneOffOnMonday()],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
      );
      final names = result
          .where((c) => c.chunkType == ChunkType.work)
          .map((c) => c.rationale)
          .toSet();
      expect(names, containsAll(<String>['Work', 'Dentist']));
    });
  });

  // ---------------------------------------------------------------------------
  // Mood-indexed break cadence (requirement BREAK-01). Each test below pins
  // the full chunk sequence (not just the long-break index) for one mood, so
  // the cadence is a verified behavior instead of an unconstrained constant.
  // Goal counts and the capacity arithmetic that justifies them are recorded
  // per test — see Test 6's comment for the convention this follows.
  // ---------------------------------------------------------------------------

  test('BREAK-01: mood=1 places a long break after every 2 work chunks', () {
    // lighterDay: false -> cap=4, habitCeiling=ceil(4/2)=2 (CAP-01).
    // 2 habits fill the habitCeiling exactly (2 chunks). mood=1 is low-mood,
    // so FILL-01 clamps each time-target to 1 chunk: 2 time-targets -> 2
    // chunks. Total discretionary = 2 + 2 = 4 work chunks (== cap).
    // N=2: chunks 2 and 4 are both cadence boundaries (floor(4/2)=2 long
    // breaks). Each boundary chunk keeps its own 5-min short break AND is
    // followed by a separate 30-min long break (D-06), not replaced by it:
    // W@480(25) SB@505(5) W@510(25) SB@535(5) LB@540(30)
    // W@570(25) SB@595(5) W@600(25) SB@625(5) LB@630(30)
    final goals = [
      ...List.generate(2, (i) => makeHabit(name: 'Habit $i')),
      ...List.generate(
        2,
        (i) => makeTimeTarget(name: 'Regular $i', weeklyHourBudget: 5),
      ),
    ];
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 1,
      date: monday,
      completionLogs: [],
      lighterDay: false,
    );
    expect(result.length, 10);
    expect(result[0].chunkType, ChunkType.work);
    expect(result[1].chunkType, ChunkType.shortBreak);
    expect(result[2].chunkType, ChunkType.work);
    expect(result[3].chunkType, ChunkType.shortBreak);
    expect(result[4].chunkType, ChunkType.longBreak);
    expect(result[5].chunkType, ChunkType.work);
    expect(result[6].chunkType, ChunkType.shortBreak);
    expect(result[7].chunkType, ChunkType.work);
    expect(result[8].chunkType, ChunkType.shortBreak);
    expect(result[9].chunkType, ChunkType.longBreak);
    expect(
      result[4].durationMinutes,
      30,
      reason: 'mood=1 must reach a long break after 2 work chunks (BREAK-01)',
    );
    expect(
      result[3].chunkType,
      ChunkType.shortBreak,
      reason: 'the boundary chunk keeps its own short break (D-06)',
    );
    expect(result[3].durationMinutes, 5);
    expect(result[1].durationMinutes, 5);
    expect(result[9].durationMinutes, 30);
  });

  test('BREAK-01: mood=2 places a long break after every 3 work chunks '
      '(regression lock — also true under the pre-BREAK-01 formula, does '
      'not by itself prove the new table is wired up)', () {
    // lighterDay: false -> cap=6, habitCeiling=ceil(6/2)=3 (CAP-01).
    // 3 habits fill the habitCeiling exactly (3 chunks). mood=2 is still
    // low-mood, so FILL-01 clamps each time-target to 1 chunk: 2
    // time-targets -> 2 chunks. Total discretionary = 3 + 2 = 5 work chunks
    // (cap=6 is not reached — that's expected, not a bug).
    // N=3: chunk 3 is the only cadence boundary (floor(5/3)=1 long break);
    // it keeps its own short break AND is followed by a separate 30-min
    // long break (D-06): W@480(25) SB@505(5) W@510(25) SB@535(5) W@540(25)
    // SB@565(5) LB@570(30) W@600(25) SB@625(5) W@630(25). Chunk 5 (ordinary,
    // last) gets its own trailing short break trimmed by STEP E (D-05
    // trims only trailing short breaks, so this is unaffected by the fix).
    final goals = [
      ...List.generate(3, (i) => makeHabit(name: 'Habit $i')),
      ...List.generate(
        2,
        (i) => makeTimeTarget(name: 'Regular $i', weeklyHourBudget: 5),
      ),
    ];
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 2,
      date: monday,
      completionLogs: [],
      lighterDay: false,
    );
    expect(result.length, 10);
    expect(result[0].chunkType, ChunkType.work);
    expect(result[1].chunkType, ChunkType.shortBreak);
    expect(result[2].chunkType, ChunkType.work);
    expect(result[3].chunkType, ChunkType.shortBreak);
    expect(result[4].chunkType, ChunkType.work);
    expect(result[5].chunkType, ChunkType.shortBreak);
    expect(result[6].chunkType, ChunkType.longBreak);
    expect(result[7].chunkType, ChunkType.work);
    expect(result[8].chunkType, ChunkType.shortBreak);
    expect(result[9].chunkType, ChunkType.work);
    expect(
      result[6].durationMinutes,
      30,
      reason: 'mood=2 must reach a long break after 3 work chunks (BREAK-01)',
    );
    expect(
      result[5].chunkType,
      ChunkType.shortBreak,
      reason: 'the boundary chunk keeps its own short break (D-06)',
    );
    expect(result[5].durationMinutes, 5);
    expect(result[1].durationMinutes, 5);
  });

  test(
    'BREAK-01: mood=3 places a long break after every 4 work chunks (baseline unchanged)',
    () {
      // lighterDay: false -> cap=8, habitCeiling=ceil(8/2)=4 (CAP-01).
      // 4 habits fill the habitCeiling exactly (4 chunks). mood=3 is not
      // low-mood, so a weeklyHourBudget: 5 time-target has demand 2 (not
      // clamped to 1): 1 time-target -> 2 chunks. Total discretionary =
      // 4 + 2 = 6 work chunks (cap=8 is not reached).
      // N=4: chunk 4 is the only cadence boundary (floor(6/4)=1 long break);
      // it keeps its own short break AND is followed by a separate 30-min
      // long break (D-06): W@480(25) SB@505(5) W@510(25) SB@535(5) W@540(25)
      // SB@565(5) W@570(25) SB@595(5) LB@600(30) W@630(25) SB@655(5)
      // W@660(25). Chunk 6's trailing short break is trimmed by STEP E.
      final goals = [
        ...List.generate(4, (i) => makeHabit(name: 'Habit $i')),
        makeTimeTarget(name: 'Regular', weeklyHourBudget: 5),
      ];
      final result = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
        lighterDay: false,
      );
      expect(result.length, 12);
      expect(result[0].chunkType, ChunkType.work);
      expect(result[1].chunkType, ChunkType.shortBreak);
      expect(result[2].chunkType, ChunkType.work);
      expect(result[3].chunkType, ChunkType.shortBreak);
      expect(result[4].chunkType, ChunkType.work);
      expect(result[5].chunkType, ChunkType.shortBreak);
      expect(result[6].chunkType, ChunkType.work);
      expect(result[7].chunkType, ChunkType.shortBreak);
      expect(result[8].chunkType, ChunkType.longBreak);
      expect(result[9].chunkType, ChunkType.work);
      expect(result[10].chunkType, ChunkType.shortBreak);
      expect(result[11].chunkType, ChunkType.work);
      expect(
        result[8].durationMinutes,
        30,
        reason:
            'mood=3 must reach a long break after 4 work chunks (BREAK-01 baseline)',
      );
      expect(
        result[7].chunkType,
        ChunkType.shortBreak,
        reason: 'the boundary chunk keeps its own short break (D-06)',
      );
      expect(result[7].durationMinutes, 5);
      expect(result[1].durationMinutes, 5);
    },
  );

  test('BREAK-01: mood=4 places a long break after every 4 work chunks '
      '(regression lock — also true under the pre-BREAK-01 formula, does '
      'not by itself prove the new table is wired up)', () {
    // lighterDay: false -> cap=9, habitCeiling=ceil(9/2)=5 (CAP-01).
    // 5 habits fill the habitCeiling exactly (5 chunks, no time-targets
    // needed). Total discretionary = 5 work chunks (cap=9 is not reached).
    // N=4: chunk 4 is the only cadence boundary (floor(5/4)=1 long break);
    // it keeps its own short break AND is followed by a separate 30-min
    // long break (D-06): W@480(25) SB@505(5) W@510(25) SB@535(5) W@540(25)
    // SB@565(5) W@570(25) SB@595(5) LB@600(30) W@630(25). Chunk 5's
    // trailing short break is trimmed by STEP E.
    final goals = List.generate(5, (i) => makeHabit(name: 'Habit $i'));
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 4,
      date: monday,
      completionLogs: [],
      lighterDay: false,
    );
    expect(result.length, 10);
    expect(result[0].chunkType, ChunkType.work);
    expect(result[1].chunkType, ChunkType.shortBreak);
    expect(result[2].chunkType, ChunkType.work);
    expect(result[3].chunkType, ChunkType.shortBreak);
    expect(result[4].chunkType, ChunkType.work);
    expect(result[5].chunkType, ChunkType.shortBreak);
    expect(result[6].chunkType, ChunkType.work);
    expect(result[7].chunkType, ChunkType.shortBreak);
    expect(result[8].chunkType, ChunkType.longBreak);
    expect(result[9].chunkType, ChunkType.work);
    expect(
      result[8].durationMinutes,
      30,
      reason: 'mood=4 must reach a long break after 4 work chunks (BREAK-01)',
    );
    expect(
      result[7].chunkType,
      ChunkType.shortBreak,
      reason: 'the boundary chunk keeps its own short break (D-06)',
    );
    expect(result[7].durationMinutes, 5);
    expect(result[1].durationMinutes, 5);
  });

  test('BREAK-01: mood=5 places a long break after every 5 work chunks', () {
    // lighterDay: false -> cap=11, habitCeiling=ceil(11/2)=6 (CAP-01).
    // 6 habits fill the habitCeiling exactly (6 chunks, no time-targets
    // needed). Total discretionary = 6 work chunks (cap=11 is not reached).
    // N=5: chunk 5 is the only cadence boundary (floor(6/5)=1 long break);
    // it keeps its own short break AND is followed by a separate 30-min
    // long break (D-06): W@480(25) SB@505(5) W@510(25) SB@535(5) W@540(25)
    // SB@565(5) W@570(25) SB@595(5) W@600(25) SB@625(5) LB@630(30)
    // W@660(25). Chunk 6's trailing short break is trimmed by STEP E.
    final goals = List.generate(6, (i) => makeHabit(name: 'Habit $i'));
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 5,
      date: monday,
      completionLogs: [],
      lighterDay: false,
    );
    expect(result.length, 12);
    expect(result[0].chunkType, ChunkType.work);
    expect(result[1].chunkType, ChunkType.shortBreak);
    expect(result[2].chunkType, ChunkType.work);
    expect(result[3].chunkType, ChunkType.shortBreak);
    expect(result[4].chunkType, ChunkType.work);
    expect(result[5].chunkType, ChunkType.shortBreak);
    expect(result[6].chunkType, ChunkType.work);
    expect(result[7].chunkType, ChunkType.shortBreak);
    expect(result[8].chunkType, ChunkType.work);
    expect(result[9].chunkType, ChunkType.shortBreak);
    expect(result[10].chunkType, ChunkType.longBreak);
    expect(result[11].chunkType, ChunkType.work);
    expect(
      result[10].durationMinutes,
      30,
      reason: 'mood=5 must reach a long break after 5 work chunks (BREAK-01)',
    );
    expect(
      result[9].chunkType,
      ChunkType.shortBreak,
      reason: 'the boundary chunk keeps its own short break (D-06)',
    );
    expect(result[9].durationMinutes, 5);
    expect(result[1].durationMinutes, 5);
  });

  // ---------------------------------------------------------------------------
  // Break-structure preservation (requirement BREAK-02): the 25-min work /
  // 5-min short-break / 30-min long-break structure must survive the cadence
  // change at every mood. Cadence-independent — does not assert lengths or
  // long-break positions. Per D-06, a cadence-boundary chunk now emits BOTH
  // its own short break and a separate long break, so exactly one adjacent
  // non-work pair (shortBreak -> longBreak) is legal; every other adjacent
  // non-work pair remains forbidden.
  // ---------------------------------------------------------------------------

  test(
    'BREAK-02: only 5-min short breaks and 30-min long breaks are ever emitted, at every mood',
    () {
      final goals = [
        ...List.generate(6, (i) => makeHabit(name: 'Habit $i')),
        ...List.generate(
          2,
          (i) => makeTimeTarget(name: 'Regular $i', weeklyHourBudget: 5),
        ),
      ];
      for (int mood = 1; mood <= 5; mood++) {
        final result = sut.generate(
          goals: goals,
          blocks: [],
          moodIndex: mood,
          date: monday,
          completionLogs: [],
          lighterDay: false,
        );

        for (final chunk in result) {
          expect(
            [ChunkType.work, ChunkType.shortBreak, ChunkType.longBreak],
            contains(chunk.chunkType),
            reason: 'mood=$mood: unexpected chunkType ${chunk.chunkType}',
          );
          if (chunk.chunkType == ChunkType.shortBreak) {
            expect(
              chunk.durationMinutes,
              5,
              reason: 'mood=$mood: short break must always be 5 minutes',
            );
          }
          if (chunk.chunkType == ChunkType.longBreak) {
            expect(
              chunk.durationMinutes,
              30,
              reason: 'mood=$mood: long break must always be 30 minutes',
            );
          }
        }

        // D-06: the only legal adjacent non-work pair is shortBreak ->
        // longBreak (a cadence-boundary chunk's own break, followed by the
        // separate long-break cell). shortBreak->shortBreak,
        // longBreak->longBreak and longBreak->shortBreak all remain
        // forbidden — this loop still fails on any of those.
        for (int i = 0; i + 1 < result.length; i++) {
          final aType = result[i].chunkType;
          final bType = result[i + 1].chunkType;
          final aIsBreak = aType != ChunkType.work;
          final bIsBreak = bType != ChunkType.work;
          final isCadenceBoundaryPair =
              aType == ChunkType.shortBreak && bType == ChunkType.longBreak;
          expect(
            aIsBreak && bIsBreak && !isCadenceBoundaryPair,
            isFalse,
            reason:
                'mood=$mood: unexpected adjacent non-work chunks at index '
                '$i/${i + 1} ($aType -> $bType) — only a shortBreak '
                'immediately followed by a longBreak is permitted (D-06)',
          );
        }

        // D-05: a trailing long break may now survive (never silently
        // suppressed); only a dangling trailing short break is trimmed.
        expect(
          result.last.chunkType,
          isNot(ChunkType.shortBreak),
          reason: 'mood=$mood: schedule must never end on a short break',
        );
      }
    },
  );

  // ---------------------------------------------------------------------------
  // Time-target rationale copy (requirement TONE-01): the deficit-framed
  // "Xh behind this week" string must become "Working toward Xh this week";
  // the on-track sibling branch is a regression guard and must not move.
  // ---------------------------------------------------------------------------

  // Test A arithmetic: budget 5.0h, zero completion logs -> completedHrs =
  // 0.0, remaining = (5.0 - 0.0).clamp(0.0, inf) = 5.0 ->
  // toStringAsFixed(1) = '5.0'. Demand = ceil(5.0*60/25/7) = 2 chunks (Monday
  // -> daysLeft = 7), so generate() emits exactly 3 chunks: work, shortBreak,
  // work; both work chunks carry the time-target rationale.
  test(
    'TONE-01: under-pace time-target rationale reads as working toward, not behind',
    () {
      final goals = [makeTimeTarget(name: 'Reading', weeklyHourBudget: 5)];
      final result = sut.generate(
        goals: goals,
        blocks: [],
        moodIndex: 3,
        date: monday,
        completionLogs: [],
        lighterDay: false,
      );

      expect(result.length, 3);
      expect(result[0].rationale, 'Working toward 5.0h this week');
      expect(result[2].rationale, 'Working toward 5.0h this week');

      for (final chunk in result) {
        expect(
          chunk.rationale.toLowerCase(),
          isNot(contains('behind')),
          reason:
              'TONE-01 requires that no rationale text ever read "behind" — '
              'chunk ${chunk.chunkType} had rationale "${chunk.rationale}"',
        );
      }
    },
  );

  // Test B arithmetic: budget 0.45h, one completed 25-minute chunk ->
  // completedHrs = 25/60 = 0.4167, remaining = (0.45 - 0.4167).clamp(0.0,
  // inf) = 0.033 -- above zero (so demand is still 1 and a chunk is
  // generated) but below the 0.1 on-track threshold, so the unchanged
  // 'On track this week' branch fires.
  test('TONE-01: on-track branch is unchanged', () {
    final goal = makeTimeTarget(name: 'Almost', weeklyHourBudget: 0.45);
    final logs = [makeLog(goalId: goal.id, dateYmd: '2026-03-23')];
    final result = sut.generate(
      goals: [goal],
      blocks: [],
      moodIndex: 3,
      date: monday,
      completionLogs: logs,
      lighterDay: false,
    );

    expect(result.length, 1);
    expect(result[0].rationale, 'On track this week');
  });

  // ---------------------------------------------------------------------------
  // LATTICE-01 / LATTICE-02 (Phase 28: The Day Is a Lattice). Every cell
  // starts on a 30-minute boundary: 25 minutes of work, 5 minutes of break,
  // and after every N work chunks (N from the morning mood) a separate
  // 30-minute long break follows the boundary chunk's own short break —
  // never replaces it (D-06). Every assertion below runs the real
  // sut.generate(...); none hand-builds a ScheduledChunk fixture. Each test
  // is labeled RED-PROOF (must fail against the unfixed engine) or GUARD
  // (must pass now AND after the fix) so 28-RED-unit.txt reads unambiguously.
  // ---------------------------------------------------------------------------
  group('LATTICE — the day is a 30-minute lattice', () {
    // RED-PROOF 1
    test(
      'LATTICE-01: every cell starts on a 30-minute boundary, at every mood',
      () {
        final goals = [
          ...List.generate(6, (i) => makeHabit(name: 'Habit $i')),
          ...List.generate(
            2,
            (i) => makeTimeTarget(name: 'Regular $i', weeklyHourBudget: 5),
          ),
        ];
        for (int mood = 1; mood <= 5; mood++) {
          final result = sut.generate(
            goals: goals,
            blocks: [],
            moodIndex: mood,
            date: monday,
            completionLogs: [],
            lighterDay: false,
          );
          for (final chunk in result) {
            // D-01 exemption: commitment-anchored chunks are never rounded —
            // LATTICE-01 governs generated (discretionary) chunks only.
            if (chunk.anchoredStartMinutes != null) continue;
            final start = chunk.syntheticStartMinutes;
            if (start == null) continue;
            switch (chunk.chunkType) {
              case ChunkType.work:
                expect(
                  start % 30,
                  0,
                  reason: 'mood=$mood: work chunk at $start is off-lattice',
                );
                expect(
                  chunk.durationMinutes,
                  25,
                  reason:
                      'mood=$mood: work chunk at $start has the wrong duration',
                );
                break;
              case ChunkType.shortBreak:
                expect(
                  start % 30,
                  25,
                  reason:
                      'mood=$mood: shortBreak at $start is off-lattice (a '
                      'short break is the tail of its cell, not a new one)',
                );
                expect(
                  chunk.durationMinutes,
                  5,
                  reason:
                      'mood=$mood: shortBreak at $start has the wrong duration',
                );
                break;
              case ChunkType.longBreak:
                expect(
                  start % 30,
                  0,
                  reason: 'mood=$mood: longBreak at $start is off-lattice',
                );
                expect(
                  chunk.durationMinutes,
                  30,
                  reason:
                      'mood=$mood: longBreak at $start has the wrong duration',
                );
                break;
            }
          }
        }
      },
    );

    // RED-PROOF 2
    test(
      'LATTICE-01/D-02: work resumes on the lattice after an off-boundary commitment',
      () {
        // Commitment 9:30-10:15 (570-615, a 45-min window) produces one
        // anchored chunk stretched to cover the whole window: the
        // block-chunking loop only starts a new 25-min chunk when a full 25
        // minutes remains before the window's end, so a 45-min window yields
        // exactly one chunk, not two (verified against the actual
        // algorithm, not assumed).
        // Free slot 1 is [480, 570) and holds exactly 3 ordinary cells
        // (480/510/540); the merged window ends at 615. D-02 rounds the
        // post-commitment free-slot start up to the next 30-minute boundary:
        // 630 (10:30), not the commitment's raw, off-lattice end minute.
        final goals = List.generate(4, (i) => makeHabit(name: 'Habit $i'));
        final result = sut.generate(
          goals: goals,
          blocks: [makeBlock(startMinutes: 570, endMinutes: 615)],
          moodIndex: 3,
          date: monday,
          completionLogs: [],
          lighterDay: false,
        );

        final discretionaryWork =
            result
                .where(
                  (c) =>
                      c.chunkType == ChunkType.work &&
                      c.anchoredStartMinutes == null,
                )
                .toList()
              ..sort(
                (a, b) => a.syntheticStartMinutes!.compareTo(
                  b.syntheticStartMinutes!,
                ),
              );

        for (final chunk in discretionaryWork) {
          expect(
            chunk.syntheticStartMinutes! % 30,
            0,
            reason:
                'discretionary work chunk at ${chunk.syntheticStartMinutes} '
                'is off-lattice',
          );
        }

        final afterCommitment = discretionaryWork.where(
          (c) => c.syntheticStartMinutes! >= 615,
        );
        expect(
          afterCommitment.isNotEmpty,
          isTrue,
          reason:
              'expected at least one discretionary chunk after the commitment',
        );
        expect(
          afterCommitment.first.syntheticStartMinutes,
          630,
          reason:
              'the free slot after a 570-615 commitment must resume at 630 '
              '(10:30), not the commitment\'s raw end minute (615)',
        );
      },
    );

    // RED-PROOF 3
    test(
      'LATTICE-02: exactly floor(workChunks / N) long breaks of exactly 30 minutes, at every mood',
      () {
        const cadence = {1: 2, 2: 3, 3: 4, 4: 4, 5: 5};
        final goals = [
          ...List.generate(6, (i) => makeHabit(name: 'Habit $i')),
          ...List.generate(
            2,
            (i) => makeTimeTarget(name: 'Regular $i', weeklyHourBudget: 5),
          ),
        ];
        for (int mood = 1; mood <= 5; mood++) {
          final result = sut.generate(
            goals: goals,
            blocks: [],
            moodIndex: mood,
            date: monday,
            completionLogs: [],
            lighterDay: false,
          );
          final workCount = workChunksOf(result);
          final longBreaks = result
              .where((c) => c.chunkType == ChunkType.longBreak)
              .toList();
          final n = cadence[mood]!;
          expect(
            longBreaks.length,
            workCount ~/ n,
            reason:
                'mood=$mood: expected ${workCount ~/ n} long breaks for '
                '$workCount work chunks at N=$n',
          );
          for (final lb in longBreaks) {
            expect(
              lb.durationMinutes,
              30,
              reason: 'mood=$mood: long break must be exactly 30 minutes',
            );
          }
        }
      },
    );

    // RED-PROOF 4 — the single most important test in the phase: it
    // reproduces the exact day the owner was looking at when he said the
    // schedule "isn't functioning right".
    test(
      "LATTICE-02/D-05: the owner's day — mood 3, N=4, 4 work chunks — still gets its long break",
      () {
        // 4 habits, mood 3, blocks: [], lighterDay: false. The pre-fix
        // engine returns 7 chunks ending in work with zero long breaks
        // anywhere; the guard that caused it was
        // `discIdx + 1 < discretionaryChunks.length` (defect 3).
        // Fixed: W@480(25) SB@505(5) W@510(25) SB@535(5) W@540(25) SB@565(5)
        // W@570(25) SB@595(5) LB@600(30).
        final goals = List.generate(4, (i) => makeHabit(name: 'Habit $i'));
        final result = sut.generate(
          goals: goals,
          blocks: [],
          moodIndex: 3,
          date: monday,
          completionLogs: [],
          lighterDay: false,
        );

        expect(result.length, 9);
        expect(result[0].chunkType, ChunkType.work);
        expect(result[0].syntheticStartMinutes, 480);
        expect(result[0].durationMinutes, 25);
        expect(result[1].chunkType, ChunkType.shortBreak);
        expect(result[1].syntheticStartMinutes, 505);
        expect(result[1].durationMinutes, 5);
        expect(result[2].chunkType, ChunkType.work);
        expect(result[2].syntheticStartMinutes, 510);
        expect(result[2].durationMinutes, 25);
        expect(result[3].chunkType, ChunkType.shortBreak);
        expect(result[3].syntheticStartMinutes, 535);
        expect(result[3].durationMinutes, 5);
        expect(result[4].chunkType, ChunkType.work);
        expect(result[4].syntheticStartMinutes, 540);
        expect(result[4].durationMinutes, 25);
        expect(result[5].chunkType, ChunkType.shortBreak);
        expect(result[5].syntheticStartMinutes, 565);
        expect(result[5].durationMinutes, 5);
        expect(result[6].chunkType, ChunkType.work);
        expect(result[6].syntheticStartMinutes, 570);
        expect(result[6].durationMinutes, 25);
        expect(result[7].chunkType, ChunkType.shortBreak);
        expect(result[7].syntheticStartMinutes, 595);
        expect(result[7].durationMinutes, 5);
        expect(result[8].chunkType, ChunkType.longBreak);
        expect(result[8].syntheticStartMinutes, 600);
        expect(result[8].durationMinutes, 30);
        expect(result.last.chunkType, ChunkType.longBreak);
      },
    );

    // RED-PROOF 5
    test(
      'LATTICE-02: the Nth chunk closes its own cell AND is followed by a separate 30-minute cell',
      () {
        final goals = [
          ...List.generate(6, (i) => makeHabit(name: 'Habit $i')),
          ...List.generate(
            2,
            (i) => makeTimeTarget(name: 'Regular $i', weeklyHourBudget: 5),
          ),
        ];
        for (int mood = 1; mood <= 5; mood++) {
          final result = sut.generate(
            goals: goals,
            blocks: [],
            moodIndex: mood,
            date: monday,
            completionLogs: [],
            lighterDay: false,
          );
          for (int i = 0; i < result.length; i++) {
            if (result[i].chunkType != ChunkType.longBreak) continue;
            expect(
              i >= 2,
              isTrue,
              reason:
                  'mood=$mood: longBreak at index $i has no room for its '
                  'preceding work+shortBreak pair',
            );
            final shortBreak = result[i - 1];
            final work = result[i - 2];
            expect(
              shortBreak.chunkType,
              ChunkType.shortBreak,
              reason:
                  'mood=$mood: the chunk before a longBreak must be its own '
                  'shortBreak (D-06)',
            );
            expect(shortBreak.durationMinutes, 5);
            expect(
              work.chunkType,
              ChunkType.work,
              reason:
                  'mood=$mood: the chunk two before a longBreak must be the '
                  'boundary work chunk',
            );
            expect(
              shortBreak.syntheticStartMinutes,
              work.syntheticStartMinutes! + 25,
              reason:
                  'mood=$mood: the short break must start exactly 25 minutes '
                  'after its work chunk',
            );
            expect(
              result[i].syntheticStartMinutes,
              work.syntheticStartMinutes! + 30,
              reason:
                  'mood=$mood: the long break must start exactly 30 minutes '
                  'after its work chunk',
            );
          }
        }
      },
    );

    // RED-PROOF 6 — this is the partial-reservation fallback that 28-03
    // Task 1 introduces, held to the same standard as the defect it
    // replaces: proven by fixture, never defended by a code comment alone.
    test(
      'LATTICE-02/D-05: a slot too narrow for the boundary footprint reserves the short break only — capacity-driven, and it does not fire on a nominal day',
      () {
        // (a) NARROW — mood 1 (N=2; cap 4, habitCeiling=ceil(4/2)=2, so 3
        // habits produce exactly 2 discretionary chunks and chunk 2 is the
        // cadence boundary). lighterDay: false — mood 1 has no lower tier,
        // so lighterDay cannot change the cap; passed for parity with the
        // other lattice fixtures, not for effect. blocks: [09:15-10:00]
        // (555-600, a 45-min window). Post COMMITBREAK-01 (Phase 30), the
        // block itself now also runs the break-insertion loop on its OWN
        // mood-1 cadence (N=2): W@555/25, cursor 580, blockBreakCount=1 (not
        // boundary at N=2) -> footprint 5, 580+5=585<=600 fits -> SB@580/5,
        // cursor 585, tail-stretched by the remaining 15 to 20 minutes
        // (580-600) since no further 25-min cell fits. Free slot 1 (before
        // the block) is unaffected — [480, 555). Chunk 1 is ordinary —
        // W@480(25), cursor 505, footprint 5 fits (510 <= 555) -> SB@505(5),
        // cursor 510. Chunk 2 is the boundary — W@510(25), cursor 535: the
        // full 35-min footprint needs 570 > 555 so it does NOT fit, but the
        // 5-min short break alone does (540 <= 555) -> the fallback reserves
        // only the short break; no long break is emitted after chunk 2.
        final narrowGoals = List.generate(
          3,
          (i) => makeHabit(name: 'Habit $i'),
        );
        final narrow = sut.generate(
          goals: narrowGoals,
          blocks: [makeBlock(startMinutes: 555, endMinutes: 600)],
          moodIndex: 1,
          date: monday,
          completionLogs: [],
          lighterDay: false,
        );

        expect(narrow.length, 6);
        expect(narrow[0].chunkType, ChunkType.work);
        expect(narrow[0].syntheticStartMinutes, 480);
        expect(narrow[0].durationMinutes, 25);
        expect(narrow[1].chunkType, ChunkType.shortBreak);
        expect(narrow[1].syntheticStartMinutes, 505);
        expect(narrow[1].durationMinutes, 5);
        expect(narrow[2].chunkType, ChunkType.work);
        expect(narrow[2].syntheticStartMinutes, 510);
        expect(narrow[2].durationMinutes, 25);
        expect(narrow[3].chunkType, ChunkType.shortBreak);
        expect(narrow[3].syntheticStartMinutes, 535);
        expect(narrow[3].durationMinutes, 5);
        expect(narrow[4].chunkType, ChunkType.work);
        expect(narrow[4].anchoredStartMinutes, 555);
        expect(narrow[4].durationMinutes, 25);
        expect(narrow[5].chunkType, ChunkType.shortBreak);
        expect(narrow[5].anchoredStartMinutes, 580);
        expect(narrow[5].durationMinutes, 20);
        expect(
          narrow.where((c) => c.chunkType == ChunkType.longBreak),
          isEmpty,
          reason:
              'the narrow slot must never fabricate room for a long break '
              'it does not have',
        );

        // (b) CONTROL, one cell wider — the identical fixture with the block
        // moved 30 minutes later (585-630), so slot 1 is [480, 585) and the
        // same boundary chunk's 35-min footprint now fits (535 + 35 = 570
        // <= 585). The only difference between (a) and (b) is 30 minutes of
        // slot width — that is what makes the fallback capacity-driven
        // rather than a suppression rule, and asserting it is what makes
        // the claim falsifiable. The commitment block itself (585-630, still
        // a 45-min window) produces the same shape as NARROW's block, just
        // shifted: W@585/25, SB@610/5 tail-stretched to 20 (610-630).
        final controlGoals = List.generate(
          3,
          (i) => makeHabit(name: 'Habit $i'),
        );
        final control = sut.generate(
          goals: controlGoals,
          blocks: [makeBlock(startMinutes: 585, endMinutes: 630)],
          moodIndex: 1,
          date: monday,
          completionLogs: [],
          lighterDay: false,
        );

        expect(control.length, 7);
        expect(control[0].chunkType, ChunkType.work);
        expect(control[0].syntheticStartMinutes, 480);
        expect(control[0].durationMinutes, 25);
        expect(control[1].chunkType, ChunkType.shortBreak);
        expect(control[1].syntheticStartMinutes, 505);
        expect(control[1].durationMinutes, 5);
        expect(control[2].chunkType, ChunkType.work);
        expect(control[2].syntheticStartMinutes, 510);
        expect(control[2].durationMinutes, 25);
        expect(control[3].chunkType, ChunkType.shortBreak);
        expect(control[3].syntheticStartMinutes, 535);
        expect(control[3].durationMinutes, 5);
        expect(control[4].chunkType, ChunkType.longBreak);
        expect(control[4].syntheticStartMinutes, 540);
        expect(control[4].durationMinutes, 30);
        expect(control[5].chunkType, ChunkType.work);
        expect(control[5].anchoredStartMinutes, 585);
        expect(control[5].durationMinutes, 25);
        expect(control[6].chunkType, ChunkType.shortBreak);
        expect(control[6].anchoredStartMinutes, 610);
        expect(control[6].durationMinutes, 20);
        final controlLongBreaks = control
            .where((c) => c.chunkType == ChunkType.longBreak)
            .toList();
        expect(controlLongBreaks.length, 1);
        expect(controlLongBreaks.first.durationMinutes, 30);
        expect(controlLongBreaks.first.syntheticStartMinutes, 540);

        // (c) BOUNDED — the fallback must not fire on any day that has
        // room: comment that defect 3 was also a plausible-looking guard —
        // if the fallback ever starts firing on a day that has room, this
        // half is what catches it. Re-run the 4-habit mood-3 fixture (the
        // RED-PROOF 4 regression, blocks: [], lighterDay: false) and confirm
        // it still ends in a 30-minute long break, and a mood loop 1-5 over
        // the BREAK-02 fixture (blocks: []) still emits exactly
        // floor(discretionaryWorkChunks / N) long breaks, each 30 minutes,
        // at every mood.
        final ownersDayGoals = List.generate(
          4,
          (i) => makeHabit(name: 'Habit $i'),
        );
        final ownersDay = sut.generate(
          goals: ownersDayGoals,
          blocks: [],
          moodIndex: 3,
          date: monday,
          completionLogs: [],
          lighterDay: false,
        );
        expect(ownersDay.last.chunkType, ChunkType.longBreak);
        expect(ownersDay.last.durationMinutes, 30);

        const cadence = {1: 2, 2: 3, 3: 4, 4: 4, 5: 5};
        final nominalGoals = [
          ...List.generate(6, (i) => makeHabit(name: 'Habit $i')),
          ...List.generate(
            2,
            (i) => makeTimeTarget(name: 'Regular $i', weeklyHourBudget: 5),
          ),
        ];
        for (int mood = 1; mood <= 5; mood++) {
          final nominal = sut.generate(
            goals: nominalGoals,
            blocks: [],
            moodIndex: mood,
            date: monday,
            completionLogs: [],
            lighterDay: false,
          );
          final workCount = workChunksOf(nominal);
          final longBreaks = nominal
              .where((c) => c.chunkType == ChunkType.longBreak)
              .toList();
          final n = cadence[mood]!;
          expect(
            longBreaks.length,
            workCount ~/ n,
            reason:
                'mood=$mood: the narrow-slot fallback must not change the '
                'nominal long-break count ($workCount work chunks at N=$n)',
          );
          for (final lb in longBreaks) {
            expect(lb.durationMinutes, 30);
          }
        }
      },
    );

    // GUARD 7 — the "540 stays 540, unrounded" half is green now AND after
    // the fix (D-01); the chunk-count/composition half is RE-POINTED by
    // Phase 30 (COMMITBREAK-01) and now fails pre-fix.
    test(
      'LATTICE-01/D-01: a fixed commitment keeps its own wall-clock start, unrounded',
      () {
        // 4 habits fill habitCeiling=4 at mood 3 (cap=8); blocks:
        // [makeBlock()] — the house default 540-600, a 60-min window. D-01
        // governs the window's OWN boundaries — block.startMinutes/
        // endMinutes are never rounded, so the window's start stays the
        // user's real 540 (09:00) and its true end stays 600 (10:00). The
        // chunk COMPOSITION inside that window is exactly what
        // COMMITBREAK-01 (Phase 30) changes: the old "2 bare work chunks,
        // one stretched" shape is now 2 work chunks with a 5-minute break
        // closing each cell — W@540/25, SB@565/5, W@570/25, SB@595/5. 565 is
        // deliberately off-lattice (565 % 30 == 25) — rounding a commitment
        // would move the user's actual appointment, which is the opposite
        // of the product's purpose.
        final goals = List.generate(4, (i) => makeHabit(name: 'Habit $i'));
        final block = makeBlock();
        final result = sut.generate(
          goals: goals,
          blocks: [block],
          moodIndex: 3,
          date: monday,
          completionLogs: [],
          lighterDay: false,
        );

        final anchored =
            result.where((c) => c.anchoredStartMinutes != null).toList()..sort(
              (a, b) =>
                  a.anchoredStartMinutes!.compareTo(b.anchoredStartMinutes!),
            );

        expect(anchored.length, 4);
        expect(anchored[0].chunkType, ChunkType.work);
        expect(anchored[0].anchoredStartMinutes, 540);
        expect(anchored[0].durationMinutes, 25);
        expect(anchored[1].chunkType, ChunkType.shortBreak);
        expect(anchored[1].anchoredStartMinutes, 565);
        expect(anchored[1].durationMinutes, 5);
        expect(anchored[2].chunkType, ChunkType.work);
        expect(anchored[2].anchoredStartMinutes, 570);
        expect(anchored[2].durationMinutes, 25);
        expect(anchored[3].chunkType, ChunkType.shortBreak);
        expect(anchored[3].anchoredStartMinutes, 595);
        expect(anchored[3].durationMinutes, 5);

        // The window's own boundaries (D-01) are read back off the block
        // object after generate() — unchanged.
        expect(block.startMinutes, 540);
        expect(block.endMinutes, 600);
      },
    );

    // GUARD 8 — must be green now AND after the fix.
    test(
      'D-04: neither _moodCap nor the day end moves — per-mood work-chunk counts are unchanged',
      () {
        // Pins the current engine's per-mood work-chunk count for the
        // BREAK-02 fixture (6 habits + 2 time-targets, blocks: [],
        // lighterDay: false) as the deliberate non-change from D-04, backed
        // by 28-RESEARCH.md's capacity simulation (455-695 minutes of slack
        // at every mood under the nominal 480-1320 window). A failure here
        // after the fix means the lattice cost capacity and the plan's
        // premise was wrong.
        const expectedWorkCount = {1: 4, 2: 5, 3: 8, 4: 9, 5: 10};
        final goals = [
          ...List.generate(6, (i) => makeHabit(name: 'Habit $i')),
          ...List.generate(
            2,
            (i) => makeTimeTarget(name: 'Regular $i', weeklyHourBudget: 5),
          ),
        ];
        for (int mood = 1; mood <= 5; mood++) {
          final result = sut.generate(
            goals: goals,
            blocks: [],
            moodIndex: mood,
            date: monday,
            completionLogs: [],
            lighterDay: false,
          );
          expect(
            workChunksOf(result),
            expectedWorkCount[mood],
            reason: 'mood=$mood: work-chunk count must not change (D-04)',
          );
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // COMMITBREAK — Phase 30: breaks inside a committed block. Every test here
  // calls the real sut.generate() (never a hand-built ScheduledChunk list —
  // lattice_break_pair_test.dart's stated convention) and is built from a
  // COMMITMENT BLOCK, not a goal (the test gap the ROADMAP names as the
  // actual defect behind the defect). Each test's leading comment states (a)
  // which requirement it proves, (b) the arithmetic derivation of its
  // expected sequence, and (c) whether it is a RED regression test (must
  // fail against the unfixed engine, must pass after 30-03) or a GUARD (must
  // pass now AND after the fix).
  // ---------------------------------------------------------------------------
  group('COMMITBREAK — breaks inside a committed block', () {
    // RED — COMMITBREAK-01/PRIMARY
    test(
      'COMMITBREAK-01/PRIMARY: the ROADMAP repro (Work 09:00-11:40, mood 3) puts a break between every pair of commitment work chunks',
      () {
        // (a) Proves COMMITBREAK-01. (b) Derivation: block 540-700 (160
        // min), mood 3 (N=4, own counter per D-30-01). Cell 1: W@540/25,
        // cursor 565, blockBreakCount=1 (not boundary) -> SB@565/5, cursor
        // 570. Cell 2: W@570/25, cursor 595, count=2 -> SB@595/5, cursor
        // 600. Cell 3: W@600/25, cursor 625, count=3 -> SB@625/5, cursor
        // 630. Cell 4: W@630/25, cursor 655, count=4 -- boundary: footprint
        // 5+30=35, 655+35=690<=700 fits -> SB@655/5 + LB@660/30, cursor 690.
        // Loop ends (690+25=715>700). Tail: cursor 690 < 700, stretch the
        // LAST unit placed (the long break) by 10 -> LB@660 becomes 40 min,
        // reaching 700 exactly. This is the exact fixture 30-RESEARCH.md
        // captured from the real prototype this phase is built from. (c)
        // RED — the unfixed engine emits 6 bare 25-min work chunks with a
        // single 35-min stretched tail and zero breaks.
        final block = makeBlock(
          name: 'Work',
          startMinutes: 540,
          endMinutes: 700,
        );
        final result = sut.generate(
          goals: [makeHabit()],
          blocks: [block],
          moodIndex: 3,
          date: monday,
          completionLogs: [],
        );
        final anchored =
            result.where((c) => c.anchoredStartMinutes != null).toList()..sort(
              (a, b) =>
                  a.anchoredStartMinutes!.compareTo(b.anchoredStartMinutes!),
            );

        expect(anchored.length, 9);
        expect(anchored[0].chunkType, ChunkType.work);
        expect(anchored[0].anchoredStartMinutes, 540);
        expect(anchored[0].durationMinutes, 25);
        expect(anchored[1].chunkType, ChunkType.shortBreak);
        expect(anchored[1].anchoredStartMinutes, 565);
        expect(anchored[1].durationMinutes, 5);
        expect(anchored[2].chunkType, ChunkType.work);
        expect(anchored[2].anchoredStartMinutes, 570);
        expect(anchored[2].durationMinutes, 25);
        expect(anchored[3].chunkType, ChunkType.shortBreak);
        expect(anchored[3].anchoredStartMinutes, 595);
        expect(anchored[3].durationMinutes, 5);
        expect(anchored[4].chunkType, ChunkType.work);
        expect(anchored[4].anchoredStartMinutes, 600);
        expect(anchored[4].durationMinutes, 25);
        expect(anchored[5].chunkType, ChunkType.shortBreak);
        expect(anchored[5].anchoredStartMinutes, 625);
        expect(anchored[5].durationMinutes, 5);
        expect(anchored[6].chunkType, ChunkType.work);
        expect(anchored[6].anchoredStartMinutes, 630);
        expect(anchored[6].durationMinutes, 25);
        expect(anchored[7].chunkType, ChunkType.shortBreak);
        expect(anchored[7].anchoredStartMinutes, 655);
        expect(anchored[7].durationMinutes, 5);
        expect(anchored[8].chunkType, ChunkType.longBreak);
        expect(anchored[8].anchoredStartMinutes, 660);
        expect(anchored[8].durationMinutes, 40);
        for (final c in anchored) {
          expect(
            c.commitmentId,
            block.id,
            reason:
                'every commitment-window chunk carries the block id (D-30-04)',
          );
        }
      },
    );

    // RED — COMMITBREAK-02/D-01
    test(
      "COMMITBREAK-02/D-01: an off-lattice 09:10 block gets cells at 09:10/09:40/10:10 and its own window never moves",
      () {
        // (a) Proves COMMITBREAK-02 (D-01 preserved). (b) block 550-700
        // (150 min, no goals), mood 3 (N=4). Cell 1: W@550/25, cursor 575,
        // count=1 -> SB@575/5, cursor 580. Cell 2: W@580/25, cursor 605,
        // count=2 -> SB@605/5, cursor 610. Cell 3: W@610/25, cursor 635,
        // count=3 -> SB@635/5, cursor 640. Cell 4: W@640/25, cursor 665,
        // count=4 -- boundary: footprint 35, 665+35=700<=700 fits ->
        // SB@665/5 + LB@670/30, cursor 700 == endMinutes, no stretch. Work
        // starts land at 550/580/610/640 -- the window's own off-lattice
        // 550 start is never rounded onto the global :00/:30 grid. (c) RED
        // — the unfixed engine emits 6 bare 25-min work chunks at
        // 550/575/600/625/650/675.
        final block = makeBlock(
          name: 'Work',
          startMinutes: 550,
          endMinutes: 700,
        );
        final result = sut.generate(
          goals: [],
          blocks: [block],
          moodIndex: 3,
          date: monday,
          completionLogs: [],
        );
        final anchored =
            result.where((c) => c.anchoredStartMinutes != null).toList()..sort(
              (a, b) =>
                  a.anchoredStartMinutes!.compareTo(b.anchoredStartMinutes!),
            );
        final workStarts = anchored
            .where((c) => c.chunkType == ChunkType.work)
            .map((c) => c.anchoredStartMinutes)
            .toList();

        expect(workStarts, [550, 580, 610, 640]);
        expect(
          550 % 30,
          10,
          reason: 'the block start is genuinely off-lattice, not rounded',
        );
        final last = anchored.last;
        expect(
          last.anchoredStartMinutes! + last.durationMinutes,
          700,
          reason: 'the window is fully covered through its true end',
        );
        // GUARD half — block-object immutability, green now and after.
        expect(block.startMinutes, 550);
        expect(block.endMinutes, 700);
      },
    );

    // RED — COMMITBREAK-01/CADENCE
    test(
      'COMMITBREAK-01/CADENCE: a 6-hour block at mood 3 accrues exactly 2 long breaks, on its own counter (D-30-01)',
      () {
        // (a) Proves D-30-01 -- a commitment block runs its own cadence
        // counter, not the discretionary loop's shared breakCount. (b)
        // block 540-900 (360 min, no goals), mood 3 (N=4). Simulated in
        // 30-RESEARCH.md's Cadence Decision section against the real
        // prototype: 10 work + 10 short + 2 long = 360 minutes exactly,
        // long breaks at the 4th and 8th work chunk's boundary (660, 810).
        // Two long breaks for a 6-hour meeting is neither the
        // shared-counter over-accrual (four) nor the shipped defect (zero).
        // (c) RED — the unfixed engine emits 14 bare 25-min work chunks,
        // zero breaks.
        final block = makeBlock(
          name: 'Work',
          startMinutes: 540,
          endMinutes: 900,
        );
        final result = sut.generate(
          goals: [],
          blocks: [block],
          moodIndex: 3,
          date: monday,
          completionLogs: [],
        );
        final anchored =
            result.where((c) => c.anchoredStartMinutes != null).toList()..sort(
              (a, b) =>
                  a.anchoredStartMinutes!.compareTo(b.anchoredStartMinutes!),
            );

        final workChunks = anchored
            .where((c) => c.chunkType == ChunkType.work)
            .toList();
        final shortBreaks = anchored
            .where((c) => c.chunkType == ChunkType.shortBreak)
            .toList();
        final longBreaks = anchored
            .where((c) => c.chunkType == ChunkType.longBreak)
            .toList();

        expect(workChunks.length, 10);
        expect(shortBreaks.length, 10);
        expect(longBreaks.length, 2);
        expect(longBreaks.map((c) => c.anchoredStartMinutes).toList(), [
          660,
          810,
        ]);
        for (final lb in longBreaks) {
          expect(lb.durationMinutes, 30);
        }
        final totalDuration = anchored.fold<int>(
          0,
          (sum, c) => sum + c.durationMinutes,
        );
        expect(totalDuration, 360);

        for (int i = 1; i < anchored.length; i++) {
          expect(
            anchored[i].anchoredStartMinutes,
            anchored[i - 1].anchoredStartMinutes! +
                anchored[i - 1].durationMinutes,
            reason:
                'chunk $i must start exactly where the previous one ends '
                '-- no gap inside the committed window',
          );
        }
      },
    );

    // RED — COMMITBREAK-01/TAIL
    test(
      "COMMITBREAK-01/TAIL: the last unit -- work or break -- stretches to the block's end and never swallows an emitted break",
      () {
        // (a) Proves the tail-stretch always extends whichever chunk was
        // genuinely last for the block, never retroactively grows a work
        // chunk backward over a break that was already reserved. (b) all
        // four sub-fixtures are the worked-examples table from
        // 30-RESEARCH.md's Pitfall 3, verified against the real prototype.
        // No goals, mood 3 (N=4) in every sub-fixture. (c) RED for the
        // three non-empty sub-fixtures (the unfixed engine stretches a bare
        // work chunk instead); the 540-560 sub-fixture is a GUARD
        // (unchanged -- a window under one 25-min cell has always emitted
        // nothing).
        List<ScheduledChunk> anchoredOf(int start, int end) {
          final block = makeBlock(
            name: 'Work',
            startMinutes: start,
            endMinutes: end,
          );
          final result = sut.generate(
            goals: [],
            blocks: [block],
            moodIndex: 3,
            date: monday,
            completionLogs: [],
          );
          return result.where((c) => c.anchoredStartMinutes != null).toList()
            ..sort(
              (a, b) =>
                  a.anchoredStartMinutes!.compareTo(b.anchoredStartMinutes!),
            );
        }

        // 540-600: divides evenly on the 30-min lattice -- no remainder, no
        // stretch needed.
        final evenSplit = anchoredOf(540, 600);
        expect(evenSplit.length, 4);
        expect(evenSplit[0].chunkType, ChunkType.work);
        expect(evenSplit[0].anchoredStartMinutes, 540);
        expect(evenSplit[0].durationMinutes, 25);
        expect(evenSplit[1].chunkType, ChunkType.shortBreak);
        expect(evenSplit[1].anchoredStartMinutes, 565);
        expect(evenSplit[1].durationMinutes, 5);
        expect(evenSplit[2].chunkType, ChunkType.work);
        expect(evenSplit[2].anchoredStartMinutes, 570);
        expect(evenSplit[2].durationMinutes, 25);
        expect(evenSplit[3].chunkType, ChunkType.shortBreak);
        expect(evenSplit[3].anchoredStartMinutes, 595);
        expect(evenSplit[3].durationMinutes, 5);

        // 540-610: a 10-minute remainder. The last unit placed is the short
        // break just reserved -- stretch IT, 5 -> 15.
        final tenMinRemainder = anchoredOf(540, 610);
        expect(tenMinRemainder.length, 4);
        expect(tenMinRemainder[3].chunkType, ChunkType.shortBreak);
        expect(tenMinRemainder[3].anchoredStartMinutes, 595);
        expect(tenMinRemainder[3].durationMinutes, 15);

        // 540-627: a 27-minute remainder. No break fits after the 3rd work
        // chunk (625+5=630 > 627), so the last unit placed is that WORK
        // chunk -- stretch IT, 25 -> 27.
        final twentySevenMinRemainder = anchoredOf(540, 627);
        expect(twentySevenMinRemainder.length, 5);
        expect(twentySevenMinRemainder[4].chunkType, ChunkType.work);
        expect(twentySevenMinRemainder[4].anchoredStartMinutes, 600);
        expect(twentySevenMinRemainder[4].durationMinutes, 27);

        // 540-560: shorter than one 25-min cell -- the while loop body
        // never executes once. Zero chunks for this block, and with no
        // other goals/blocks, generate() returns an empty list outright
        // (GUARD -- unchanged by this phase).
        final tooNarrow = sut.generate(
          goals: [],
          blocks: [makeBlock(name: 'Work', startMinutes: 540, endMinutes: 560)],
          moodIndex: 3,
          date: monday,
          completionLogs: [],
        );
        expect(tooNarrow, isEmpty);
      },
    );

    // RED — COMMITBREAK-01/STEP-E
    test(
      'COMMITBREAK-01/STEP-E: a tail-stretched commitment break survives the trailing trim (D-30-02)',
      () {
        // (a) Proves D-30-02 -- STEP E's trailing-short-break trim narrows
        // to commitmentId == null. (b) block 540-610 (no goals, mood 3):
        // the last chunk placed is the short break at 595, tail-stretched
        // to 15 minutes (595-610) -- see TAIL's identical sub-fixture.
        // Without the narrowed trim, STEP E deletes it because its own trim
        // condition only checks chunkType, not origin. (c) RED -- the
        // unfixed engine's last chunk is a bare stretched work chunk with
        // no break to delete, so the reason string below documents what the
        // fix must prevent from regressing.
        final block = makeBlock(
          name: 'Work',
          startMinutes: 540,
          endMinutes: 610,
        );
        final result = sut.generate(
          goals: [],
          blocks: [block],
          moodIndex: 3,
          date: monday,
          completionLogs: [],
        );

        expect(result.last.chunkType, ChunkType.shortBreak);
        expect(result.last.anchoredStartMinutes, 595);
        expect(result.last.durationMinutes, 15);
        expect(result.last.commitmentId, block.id);
        expect(
          result.last.anchoredStartMinutes! + result.last.durationMinutes,
          610,
          reason:
              "STEP E's trailing trim must never delete a stretched "
              'commitment break -- doing so silently erases 15 real '
              'committed minutes (D-30-02)',
        );
      },
    );

    // GUARD — COMMITBREAK-01/NO-DOUBLE-BOOK
    test(
      "COMMITBREAK-01/NO-DOUBLE-BOOK: no discretionary chunk lands inside a commitment's internal break gap",
      () {
        // (a) Proves Pitfall 2's window-merge dependency -- every chunk
        // Step 1 emits (work AND break) must be anchored and contiguous so
        // STEP B's free-slot merge sees one solid occupied span, never a
        // false gap a discretionary chunk could be packed into. (b) block
        // 540-900 saturated with 10 habits at mood 5 (heaviest packing
        // pressure). (c) GUARD -- green now (the pre-fix window is already
        // one contiguous span, just without internal breaks) AND after the
        // fix (the internal break gaps are covered by anchored break
        // chunks, so the merged span is still solid).
        final block = makeBlock(
          name: 'Work',
          startMinutes: 540,
          endMinutes: 900,
        );
        final goals = List.generate(10, (i) => makeHabit(name: 'Habit $i'));
        final result = sut.generate(
          goals: goals,
          blocks: [block],
          moodIndex: 5,
          date: monday,
          completionLogs: [],
          lighterDay: false,
        );

        final discretionary = result
            .where((c) => c.anchoredStartMinutes == null)
            .toList();
        expect(discretionary, isNotEmpty);
        for (final c in discretionary) {
          expect(
            c.syntheticStartMinutes,
            isNotNull,
            reason: 'every discretionary chunk must have a synthetic start',
          );
          final s = c.syntheticStartMinutes!;
          final e = s + c.durationMinutes;
          final intersects = s < 900 && e > 540;
          expect(
            intersects,
            isFalse,
            reason:
                'discretionary chunk [$s, $e) must not intersect the '
                'commitment window [540, 900), including its internal '
                'break gaps',
          );
        }
      },
    );
  });
  // ---------------------------------------------------------------------------
  // SEED-006 — a chunk completed on a Monday never counted toward that week
  // ---------------------------------------------------------------------------
  //
  // `_weekStart` subtracted `weekday - 1` days WITHOUT normalising the time of
  // day, so it returned Monday at *today's clock time*. A CompletionLog stores
  // `dateYmd` as `YYYY-MM-DD`, so `DateTime.parse` always yields midnight —
  // and Monday-00:00 `isBefore` Monday-14:30. The Monday log was dropped, on
  // every day of the week, at every time except exactly 00:00:00.
  //
  // **Why 3248 lines of green tests never caught it, which is the real
  // lesson:** every fixture in this file builds its date with
  // `DateTime(2026, 3, 23)` — midnight. That is the ONE input where the defect
  // cannot fire, and `DateTime.now()` never produces it. The suite tested the
  // single unreachable case exclusively. These tests use wall-clock times a
  // real user actually has.
  group('SEED-006: week start must be date-only', () {
    test('weekStart normalises the time of day', () {
      // Monday 2026-03-23 at 14:30 must yield Monday 2026-03-23 at midnight,
      // not Monday at 14:30. Asserted directly: this is the defect itself,
      // one call deep, with no scheduling arithmetic in between to muddy it.
      expect(
        ScheduleGeneratorService.weekStart(DateTime(2026, 3, 23, 14, 30)),
        DateTime(2026, 3, 23),
      );
      // Mid-week, at a time of day that is not midnight, still walks back to
      // the same Monday midnight.
      expect(
        ScheduleGeneratorService.weekStart(DateTime(2026, 3, 25, 9, 0)),
        DateTime(2026, 3, 23),
      );
      // Sunday is the END of the week here (weekday 7), not the start.
      expect(
        ScheduleGeneratorService.weekStart(DateTime(2026, 3, 29, 23, 59)),
        DateTime(2026, 3, 23),
      );
    });

    test('the generator and the Goals screen agree about Monday', () {
      // The divergence SEED-006 called "the strongest argument for fixing this
      // soon": WeeklyProgressService.weekStart was correct while the
      // generator's was not, so the progress line and the scheduler could
      // legitimately disagree about the same Monday.
      for (final at in [
        DateTime(2026, 3, 23, 0, 0),
        DateTime(2026, 3, 23, 14, 30),
        DateTime(2026, 3, 27, 9, 0),
      ]) {
        expect(
          ScheduleGeneratorService.weekStart(at),
          WeeklyProgressService.weekStart(at),
          reason: 'the two week-start helpers disagree at $at',
        );
      }
    });

    test('a Monday completion reduces Monday-afternoon demand', () {
      // End-to-end through generate(), because the unit assertion above would
      // stay green if the helper were fixed and its caller left alone.
      //
      // 6.25h budget = 15 chunks remaining; on Monday daysLeft is 7, so
      // demand is ceil(15/7) = 3. One completed chunk takes it to 14 →
      // ceil(14/7) = 2. The budget is chosen to sit exactly on that boundary:
      // at most other budgets a single 25-minute chunk does not move the
      // ceiling at all, and the test would pass with the bug intact.
      final goal = makeTimeTarget(name: 'Deep work', weeklyHourBudget: 6.25);
      final mondayAfternoon = DateTime(2026, 3, 23, 14, 30);

      List<ScheduledChunk> runWith(List<CompletionLog> logs) => sut.generate(
        goals: [goal],
        blocks: [],
        moodIndex: 5,
        date: mondayAfternoon,
        completionLogs: logs,
      );

      final withoutLog = workChunksOf(runWith([]));
      final withMondayLog = workChunksOf(
        runWith([makeLog(goalId: goal.id, dateYmd: '2026-03-23')]),
      );

      expect(
        withoutLog,
        3,
        reason: 'baseline: 15 chunks over 7 days is 3 a day',
      );
      expect(
        withMondayLog,
        2,
        reason:
            "a chunk completed this Monday must count against this week's "
            'budget — with SEED-006 live this reads 3, identical to having '
            'done nothing at all',
      );
    });

    test("Monday's completion stays counted for the rest of the week", () {
      // The seed's sharpest finding: because the week start stayed pinned to
      // Monday-at-today's-clock-time, Monday's work was invisible on Tuesday,
      // Wednesday and every day through Sunday — not just on Monday itself.
      final goal = makeTimeTarget(name: 'Deep work', weeklyHourBudget: 6.25);
      // Wednesday 2026-03-25, 09:00. daysLeft = 7 - 3 + 1 = 5.
      // 15 chunks / 5 = 3; 14 / 5 = ceil(2.8) = 3 — the ceiling does not move
      // here, so assert the arithmetic that DOES: the Monday log is inside
      // the week window at all.
      final wednesday = DateTime(2026, 3, 25, 9, 0);
      expect(
        DateTime.parse(
          '2026-03-23',
        ).isBefore(ScheduleGeneratorService.weekStart(wednesday)),
        isFalse,
        reason: "Monday's log must not fall before Wednesday's week start",
      );
      // And it is genuinely reachable through generate(): a full week of
      // completions must starve the goal rather than leaving it at full
      // budget. 15 logged chunks against a 15-chunk budget is zero remaining.
      final spent = List.generate(
        15,
        (i) => makeLog(goalId: goal.id, dateYmd: '2026-03-23'),
      );
      final result = sut.generate(
        goals: [goal],
        blocks: [],
        moodIndex: 5,
        date: wednesday,
        completionLogs: spent,
      );
      expect(
        workChunksOf(result),
        0,
        reason:
            'a fully-spent weekly budget must schedule nothing on Wednesday; '
            'with SEED-006 live every one of those Monday logs is dropped '
            'and the goal reads as untouched',
      );
    });
  });
}
