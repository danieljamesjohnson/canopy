// Tests for ScheduleNotifier.addEventToday — inserting a one-off dated event
// into TODAY's existing schedule in place (progress preserved), so a human can
// add an event from the Today screen and see it immediately without a
// re-check-in that would rebuild (and reset) the day.

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/data/repositories/completion_log_repository.dart';
import 'package:canopy/data/repositories/daily_schedule_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryScheduleRepository implements DailyScheduleRepository {
  DailySchedule? _stored;

  @override
  Future<List<DailySchedule>> getAll() async =>
      _stored == null ? [] : [_stored!];

  @override
  Future<DailySchedule?> getById(String id) async =>
      _stored?.id == id ? _stored : null;

  @override
  Future<void> save(DailySchedule schedule) async => _stored = schedule;

  @override
  Future<void> delete(String id) async {
    if (_stored?.id == id) _stored = null;
  }

  @override
  Future<DailySchedule?> getByDate(String dateYmd) async =>
      _stored?.dateYmd == dateYmd ? _stored : null;

  @override
  Future<DailySchedule?> getTodaysSchedule() async => _stored;
}

class _InMemoryGoalRepository implements GoalRepository {
  @override
  Future<List<Goal>> getAll() async => const [];
  @override
  Future<Goal?> getById(String id) async => null;
  @override
  Future<void> save(Goal goal) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<Goal>> getActive() async => const [];
}

class _InMemoryLogRepository implements CompletionLogRepository {
  final List<CompletionLog> _logs = [];
  @override
  Future<List<CompletionLog>> getAll() async => _logs;
  @override
  Future<CompletionLog?> getById(String id) async => null;
  @override
  Future<void> append(CompletionLog entry) async => _logs.add(entry);
  @override
  Future<List<CompletionLog>> getByDate(String dateYmd) async => _logs;
  @override
  Future<List<CompletionLog>> getByGoalId(String goalId) async => _logs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testDateYmd = '2026-03-23'; // Monday

  Future<ScheduleNotifier> makeNotifier(
    _InMemoryScheduleRepository repo,
  ) async {
    // Pre-seed today's schedule with one already-completed chunk to prove
    // progress survives the insert.
    final done = ScheduledChunk(
      id: 'chunk-done',
      chunkTypeIndex: ChunkType.work.index,
      goalId: 'goal-1',
      durationMinutes: 25,
      syntheticStartMinutes: 8 * 60,
      rationale: 'Habit',
    )..isCompleted = true;
    await repo.save(
      DailySchedule(
        id: 'sched-1',
        dateYmd: testDateYmd,
        moodIndex: 3,
        chunks: [done],
      ),
    );
    final notifier = ScheduleNotifier(
      now: () => DateTime(2026, 3, 23),
      repo: repo,
      logRepo: _InMemoryLogRepository(),
      goalRepo: _InMemoryGoalRepository(),
    );
    await notifier.init();
    return notifier;
  }

  test('inserts a same-day one-off, preserving existing progress', () async {
    final repo = _InMemoryScheduleRepository();
    final notifier = await makeNotifier(repo);

    final block = CommitmentBlock(
      name: 'Dentist',
      daysOfWeek: const [],
      startMinutes: 14 * 60, // 2:00pm
      endMinutes: 15 * 60, // 3:00pm → 60-min window: 2 work chunks +
      // the 25+5 lattice's short breaks between/after them (COMMITBREAK-01).
      date: DateTime(2026, 3, 23),
    );
    final inserted = await notifier.addEventToday(block);

    expect(inserted, isTrue);
    final chunks = notifier.todaySchedule!.chunks;
    // Original completed chunk still present and still completed.
    final orig = chunks.where((c) => c.id == 'chunk-done');
    expect(orig.length, 1);
    expect(orig.first.isCompleted, isTrue);
    // Two new anchored "Dentist" chunks were added at 2pm/2:25pm. Break
    // chunks carry rationale: '' (D-30-04), so this filter still isolates
    // exactly the two work chunks even once breaks exist between them.
    final dentist = chunks.where((c) => c.rationale == 'Dentist').toList();
    expect(dentist.length, 2);
    expect(dentist.every((c) => c.commitmentId == block.id), isTrue);
    expect(dentist.first.anchoredStartMinutes, 14 * 60);
    expect(
      dentist[1].anchoredStartMinutes,
      14 * 60 + 30,
      reason:
          'the second work chunk starts after the first work chunk PLUS '
          'its short break (25+5), not back-to-back at +25 (COMMITBREAK-01)',
    );
    // The short break the lattice inserts between the two work chunks.
    final midBreak = chunks.where(
      (c) =>
          c.chunkType == ChunkType.shortBreak &&
          c.anchoredStartMinutes == 14 * 60 + 25 &&
          c.durationMinutes == 5 &&
          c.commitmentId == block.id,
    );
    expect(
      midBreak.length,
      1,
      reason:
          'a commitment break added mid-day must exist on the lattice, same '
          'as a generated day (COMMITBREAK-01/ADD-EVENT)',
    );
    // Sorted: the 8am completed chunk precedes the 2pm event.
    expect(chunks.first.id, 'chunk-done');
  });

  test(
    'COMMITBREAK-01/ADD-EVENT: an event added mid-day gets the same 25+5 '
    'lattice as a generated day',
    () async {
      final repo = _InMemoryScheduleRepository();
      final notifier = await makeNotifier(repo);

      final block = CommitmentBlock(
        name: 'Meeting',
        daysOfWeek: const [],
        startMinutes: 840, // 14:00
        endMinutes: 900, // 15:00 — 60-min window, mood 3 (N=4): no
        // cadence boundary reached, short breaks only.
        date: DateTime(2026, 3, 23),
      );
      final inserted = await notifier.addEventToday(block);
      expect(inserted, isTrue);

      final blockChunks =
          notifier.todaySchedule!.chunks
              .where((c) => c.commitmentId == block.id)
              .toList()
            ..sort(
              (a, b) => a.anchoredStartMinutes!.compareTo(
                b.anchoredStartMinutes!,
              ),
            );

      expect(
        blockChunks.length,
        4,
        reason:
            'work@840/25, shortBreak@865/5, work@870/25, shortBreak@895/5 — '
            'the same 25+5 lattice a generated day gets inside a commitment '
            'window (COMMITBREAK-01), reached via the SECOND path '
            '(addEventToday), not generate()',
      );
      expect(blockChunks[0].chunkType, ChunkType.work);
      expect(blockChunks[0].anchoredStartMinutes, 840);
      expect(blockChunks[0].durationMinutes, 25);
      expect(blockChunks[1].chunkType, ChunkType.shortBreak);
      expect(blockChunks[1].anchoredStartMinutes, 865);
      expect(blockChunks[1].durationMinutes, 5);
      expect(blockChunks[2].chunkType, ChunkType.work);
      expect(blockChunks[2].anchoredStartMinutes, 870);
      expect(blockChunks[2].durationMinutes, 25);
      expect(blockChunks[3].chunkType, ChunkType.shortBreak);
      expect(blockChunks[3].anchoredStartMinutes, 895);
      expect(blockChunks[3].durationMinutes, 5);
      expect(
        blockChunks.every((c) => c.commitmentId == block.id),
        isTrue,
        reason: 'D-30-04: every anchored chunk (work AND break) carries '
            "the block's commitmentId",
      );
    },
  );

  test(
    "COMMITBREAK-02/ADD-EVENT: the added event's own window never moves",
    () async {
      final repo = _InMemoryScheduleRepository();
      final notifier = await makeNotifier(repo);

      final block = CommitmentBlock(
        name: 'Meeting',
        daysOfWeek: const [],
        startMinutes: 840,
        endMinutes: 900,
        date: DateTime(2026, 3, 23),
      );
      final inserted = await notifier.addEventToday(block);
      expect(inserted, isTrue);

      final blockChunks =
          notifier.todaySchedule!.chunks
              .where((c) => c.commitmentId == block.id)
              .toList()
            ..sort(
              (a, b) => a.anchoredStartMinutes!.compareTo(
                b.anchoredStartMinutes!,
              ),
            );
      expect(blockChunks, isNotEmpty);
      expect(blockChunks.first.anchoredStartMinutes, 840);
      expect(
        blockChunks.last.anchoredStartMinutes! +
            blockChunks.last.durationMinutes,
        900,
        reason:
            "the last chunk's end must reach the block's own endMinutes "
            'exactly — no lattice remainder left uncovered (D-01/COMMITBREAK-02)',
      );
      // The block object itself — read back after addEventToday returns —
      // must never have had its own start/end moved.
      expect(block.startMinutes, 840);
      expect(block.endMinutes, 900);
    },
  );

  test(
    'COMMITBREAK-01/ADD-EVENT-TRIM: the trailing trim must not delete a '
    'commitment break (D-30-02)',
    () async {
      final repo = _InMemoryScheduleRepository();
      // Seed today with: a completed discretionary work chunk, then another
      // block's anchored work+break pair as the chronologically LAST items —
      // exactly the shape _trimTrailingNonWork sees when a PREVIOUS
      // addEventToday call already anchored a commitment break onto today.
      final discretionary =
          ScheduledChunk(
            id: 'w0',
            chunkTypeIndex: ChunkType.work.index,
            goalId: 'goal-1',
            durationMinutes: 25,
            syntheticStartMinutes: 480,
            rationale: 'Deep work',
          )..isCompleted = true;
      final otherWork = ScheduledChunk(
        id: 'other-work',
        chunkTypeIndex: ChunkType.work.index,
        commitmentId: 'other-block',
        durationMinutes: 25,
        anchoredStartMinutes: 1170,
        rationale: 'Other meeting',
      );
      final otherBreak = ScheduledChunk(
        id: 'other-break',
        chunkTypeIndex: ChunkType.shortBreak.index,
        commitmentId: 'other-block',
        durationMinutes: 5,
        anchoredStartMinutes: 1195,
        rationale: '',
      );
      await repo.save(
        DailySchedule(
          id: 'sched-1',
          dateYmd: testDateYmd,
          moodIndex: 3,
          chunks: [discretionary, otherWork, otherBreak],
        ),
      );
      final notifier = ScheduleNotifier(
        now: () => DateTime(2026, 3, 23),
        repo: repo,
        logRepo: _InMemoryLogRepository(),
        goalRepo: _InMemoryGoalRepository(),
      );
      await notifier.init();

      // Add an event for a DIFFERENT day — this exercises the early-return
      // (!anchorsToday) branch, which still runs _trimTrailingNonWork()
      // against today's existing chunks before bailing out.
      final block = CommitmentBlock(
        name: 'Tomorrow',
        daysOfWeek: const [],
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
        date: DateTime(2026, 3, 24),
      );
      final placed = await notifier.addEventToday(block);

      expect(placed, isFalse);
      final survivingBreak = notifier.todaySchedule!.chunks.where(
        (c) =>
            c.anchoredStartMinutes == 1195 &&
            c.chunkType == ChunkType.shortBreak &&
            c.commitmentId == 'other-block',
      );
      expect(
        survivingBreak.length,
        1,
        reason:
            'D-30-02: _trimTrailingNonWork must not delete a commitment '
            "break just because it's the day's trailing chunk — only a "
            'discretionary (commitmentId == null) trailing short break may '
            'be trimmed. NOTE: the discretionary half of this trim is '
            'already covered by CR-01 below and is deliberately not '
            're-tested here.',
      );
    },
  );

  test(
    'returns false for an event on a different day (does not touch today)',
    () async {
      final repo = _InMemoryScheduleRepository();
      final notifier = await makeNotifier(repo);

      final future = CommitmentBlock(
        name: 'Future',
        daysOfWeek: const [],
        startMinutes: 14 * 60,
        endMinutes: 15 * 60,
        date: DateTime(2026, 3, 30), // a week later
      );
      final inserted = await notifier.addEventToday(future);

      expect(inserted, isFalse);
      expect(notifier.todaySchedule!.chunks.length, 1); // unchanged
    },
  );

  test(
    'adding an event reflows overlapping discretionary work (no double-book)',
    () async {
      final repo = _InMemoryScheduleRepository();
      // Seed a populated day: a discretionary work chunk placed at 2:00pm.
      final work = ScheduledChunk(
        id: 'work-1',
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'goal-1',
        durationMinutes: 25,
        syntheticStartMinutes:
            14 * 60, // 2:00pm — collides with the event below
        rationale: 'Deep work',
      );
      await repo.save(
        DailySchedule(
          id: 'sched-1',
          dateYmd: testDateYmd,
          moodIndex: 3,
          chunks: [work],
        ),
      );
      final notifier = ScheduleNotifier(
        now: () => DateTime(2026, 3, 23),
        repo: repo,
        logRepo: _InMemoryLogRepository(),
        goalRepo: _InMemoryGoalRepository(),
      );
      await notifier.init();

      // Add a fixed event 2:00–3:00pm — directly over the discretionary chunk.
      final event = CommitmentBlock(
        name: 'Doctor',
        daysOfWeek: const [],
        startMinutes: 14 * 60,
        endMinutes: 15 * 60,
        date: DateTime(2026, 3, 23),
      );
      final placed = await notifier.addEventToday(event);
      expect(placed, isTrue);

      // No two WORK chunks may share overlapping display windows.
      final workChunks = notifier.todaySchedule!.chunks
          .where((c) => c.chunkType == ChunkType.work)
          .toList();
      for (int i = 0; i < workChunks.length; i++) {
        for (int j = i + 1; j < workChunks.length; j++) {
          final a = workChunks[i], b = workChunks[j];
          final as = a.displayStartMinutes!, ae = as + a.durationMinutes;
          final bs = b.displayStartMinutes!, be = bs + b.durationMinutes;
          expect(
            as < be && bs < ae,
            isFalse,
            reason: 'work chunks must not overlap after adding an event',
          );
        }
      }
      // The discretionary chunk was moved off the event window.
      final moved = notifier.todaySchedule!.chunks.firstWhere(
        (c) => c.id == 'work-1',
      );
      expect(moved.displayStartMinutes, isNot(14 * 60));
    },
  );

  test(
    'adding an event leaves NO work-vs-break overlap (breaks re-emitted)',
    () async {
      final repo = _InMemoryScheduleRepository();
      // A normal generated morning: work/break/work/break/work interleaved.
      ScheduledChunk work(String id, int start) => ScheduledChunk(
        id: id,
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'goal-1',
        durationMinutes: 25,
        syntheticStartMinutes: start,
        rationale: 'Deep work',
      );
      ScheduledChunk brk(String id, int start) => ScheduledChunk(
        id: id,
        chunkTypeIndex: ChunkType.shortBreak.index,
        durationMinutes: 5,
        syntheticStartMinutes: start,
        rationale: '',
      );
      await repo.save(
        DailySchedule(
          id: 'sched-1',
          dateYmd: testDateYmd,
          moodIndex: 3,
          chunks: [
            work('w1', 480),
            brk('b1', 505),
            work('w2', 510),
            brk('b2', 535),
            work('w3', 540),
          ],
        ),
      );
      final notifier = ScheduleNotifier(
        now: () => DateTime(2026, 3, 23),
        repo: repo,
        logRepo: _InMemoryLogRepository(),
        goalRepo: _InMemoryGoalRepository(),
      );
      await notifier.init();

      // Add a noon meeting.
      await notifier.addEventToday(
        CommitmentBlock(
          name: 'Meeting',
          daysOfWeek: const [],
          startMinutes: 12 * 60,
          endMinutes: 13 * 60,
          date: DateTime(2026, 3, 23),
        ),
      );

      // No chunk of ANY type may overlap another (work-vs-work, work-vs-break).
      final timed = notifier.todaySchedule!.chunks
          .where((c) => c.displayStartMinutes != null)
          .toList();
      for (int i = 0; i < timed.length; i++) {
        for (int j = i + 1; j < timed.length; j++) {
          final a = timed[i], b = timed[j];
          final as = a.displayStartMinutes!, ae = as + a.durationMinutes;
          final bs = b.displayStartMinutes!, be = bs + b.durationMinutes;
          expect(
            as < be && bs < ae,
            isFalse,
            reason:
                'no two timed chunks may overlap after an add '
                '(${a.chunkType}@$as vs ${b.chunkType}@$bs)',
          );
        }
      }
    },
  );

  for (final windowMin in [30, 60, 45]) {
    test(
      'a $windowMin-min event protects its FULL window from discretionary work',
      () async {
        final repo = _InMemoryScheduleRepository();
        // A work-filled morning of discretionary chunks.
        final chunks = <ScheduledChunk>[
          for (int i = 0; i < 6; i++)
            ScheduledChunk(
              id: 'w$i',
              chunkTypeIndex: ChunkType.work.index,
              goalId: 'goal-1',
              durationMinutes: 25,
              syntheticStartMinutes: 8 * 60 + i * 30,
              rationale: 'Deep work',
            ),
        ];
        await repo.save(
          DailySchedule(
            id: 'sched-1',
            dateYmd: testDateYmd,
            moodIndex: 3,
            chunks: chunks,
          ),
        );
        final notifier = ScheduleNotifier(
          now: () => DateTime(2026, 3, 23),
          repo: repo,
          logRepo: _InMemoryLogRepository(),
          goalRepo: _InMemoryGoalRepository(),
        );
        await notifier.init();

        final start = 9 * 60; // 9:00
        final end = start + windowMin;
        await notifier.addEventToday(
          CommitmentBlock(
            name: 'Meeting',
            daysOfWeek: const [],
            startMinutes: start,
            endMinutes: end,
            date: DateTime(2026, 3, 23),
          ),
        );

        // No discretionary work chunk (goalId != null) may overlap the FULL
        // entered window [start, end) — not just the 25-min anchored slots.
        for (final c in notifier.todaySchedule!.chunks) {
          if (c.goalId == null) continue; // skip the anchored event + breaks
          final s = c.displayStartMinutes;
          if (s == null) continue; // untimed overflow is fine
          final e = s + c.durationMinutes;
          expect(
            s < end && start < e,
            isFalse,
            reason:
                'discretionary work @$s must not overlap the committed '
                'window [$start,$end) of a $windowMin-min event',
          );
        }
      },
    );
  }

  test(
    'editing an event re-anchors today (idempotent by commitmentId)',
    () async {
      final repo = _InMemoryScheduleRepository();
      final notifier = await makeNotifier(repo);

      final block = CommitmentBlock(
        name: 'Call',
        daysOfWeek: const [],
        startMinutes: 10 * 60,
        endMinutes: 11 * 60,
        date: DateTime(2026, 3, 23),
      );
      await notifier.addEventToday(block); // first placement at 10:00
      expect(
        notifier.todaySchedule!.chunks
            .where((c) => c.commitmentId == block.id)
            .isNotEmpty,
        isTrue,
      );

      // Edit the SAME block (same id) to a new time and re-anchor.
      block.startMinutes = 16 * 60;
      block.endMinutes = 17 * 60;
      await notifier.addEventToday(block);

      final callChunks = notifier.todaySchedule!.chunks
          .where((c) => c.commitmentId == block.id)
          .toList();
      // Exactly the new placement — no stale 10:00 copy left behind. A
      // 60-min window now yields 4 chunks (2 work + 2 short breaks on the
      // lattice, COMMITBREAK-01), not the pre-phase 2 bare work chunks.
      expect(callChunks.length, 4);
      expect(
        callChunks.every((c) => c.anchoredStartMinutes! >= 16 * 60),
        isTrue,
      );
    },
  );

  test('CR-01: moving a commitment off today trims the now-trailing break '
      '(no dangling break survives addEventToday)', () async {
    final repo = _InMemoryScheduleRepository();
    final block = CommitmentBlock(
      name: 'Evening call',
      daysOfWeek: const [],
      startMinutes: 19 * 60 + 30, // 7:30pm
      endMinutes: 20 * 60, // 8:00pm
      date: DateTime(2026, 3, 23), // today
    );
    // A wholly ordinary, generate()-shaped day: work, break, then the
    // commitment-anchored evening call as the true trailing (work-typed)
    // item — STEP E is satisfied at seed time.
    final w1 = ScheduledChunk(
      id: 'w1',
      chunkTypeIndex: ChunkType.work.index,
      goalId: 'goal-1',
      durationMinutes: 25,
      syntheticStartMinutes: 8 * 60,
      rationale: 'Deep work',
    );
    final b1 = ScheduledChunk(
      id: 'b1',
      chunkTypeIndex: ChunkType.shortBreak.index,
      durationMinutes: 5,
      syntheticStartMinutes: 8 * 60 + 25,
      rationale: '',
    );
    final c1 = ScheduledChunk(
      id: 'c1',
      chunkTypeIndex: ChunkType.work.index,
      commitmentId: block.id,
      durationMinutes: 25,
      anchoredStartMinutes: 19 * 60 + 30,
      rationale: 'Evening call',
    );
    await repo.save(
      DailySchedule(
        id: 'sched-1',
        dateYmd: testDateYmd,
        moodIndex: 3,
        chunks: [w1, b1, c1],
      ),
    );
    final notifier = ScheduleNotifier(
      now: () => DateTime(2026, 3, 23),
      repo: repo,
      logRepo: _InMemoryLogRepository(),
      goalRepo: _InMemoryGoalRepository(),
    );
    await notifier.init();

    // Move the commitment off today — e.g. rescheduled to tomorrow, an
    // ordinary Commitments-screen edit (commitments_screen.dart's onSaved
    // calls addEventToday for both add AND edit).
    block.date = DateTime(2026, 3, 24);
    final anchored = await notifier.addEventToday(block);

    expect(anchored, isFalse);
    final chunks = notifier.todaySchedule!.chunks;
    // c1 is correctly gone (no longer today's) — but the now-trailing
    // break b1 must be trimmed too, mirroring schedule_generator.dart's
    // STEP E, or resolveNowState can be handed a trailing break (CR-01).
    expect(chunks.map((c) => c.id), ['w1']);
    expect(chunks.last.chunkType, ChunkType.work);
  });

  test(
    'WR-02: a trailing discretionary long break (and its preceding short '
    'break) must survive addEventToday, not just a trailing short break',
    () async {
      final repo = _InMemoryScheduleRepository();
      // A day shaped like a legitimate cadence-boundary ending — work, then
      // the D-06 short-break/long-break pair STEP E deliberately preserves
      // (schedule_generator_test.dart Test 6: "[..., work, shortBreak,
      // longBreak]" is a real, generate()-producible shape). Both breaks are
      // discretionary (commitmentId: null) and synthetic (not anchored) —
      // exactly the shape CR-01 shows the unnarrowed trim deletes.
      final w1 = ScheduledChunk(
        id: 'w1',
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'goal-1',
        durationMinutes: 25,
        syntheticStartMinutes: 8 * 60,
        rationale: 'Deep work',
      );
      final b1 = ScheduledChunk(
        id: 'b1',
        chunkTypeIndex: ChunkType.shortBreak.index,
        durationMinutes: 5,
        syntheticStartMinutes: 8 * 60 + 25,
        rationale: '',
      );
      final l1 = ScheduledChunk(
        id: 'l1',
        chunkTypeIndex: ChunkType.longBreak.index,
        durationMinutes: 30,
        syntheticStartMinutes: 8 * 60 + 30,
        rationale: '',
      );
      await repo.save(
        DailySchedule(
          id: 'sched-1',
          dateYmd: testDateYmd,
          moodIndex: 3,
          chunks: [w1, b1, l1],
        ),
      );
      final notifier = ScheduleNotifier(
        now: () => DateTime(2026, 3, 23),
        repo: repo,
        logRepo: _InMemoryLogRepository(),
        goalRepo: _InMemoryGoalRepository(),
      );
      await notifier.init();

      // Add an event for a DIFFERENT day — exercises the early-return
      // (!anchorsToday) branch, which still runs _trimTrailingNonWork()
      // against today's existing chunks before bailing out (mirrors
      // COMMITBREAK-01/ADD-EVENT-TRIM and CR-01's own regression test
      // above, so this test isolates the trim itself rather than
      // _reflowDiscretionaryWork, which would drop-and-re-emit breaks on
      // the anchorsToday==true path and mask this specific bug).
      final block = CommitmentBlock(
        name: 'Tomorrow',
        daysOfWeek: const [],
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
        date: DateTime(2026, 3, 24),
      );
      final placed = await notifier.addEventToday(block);

      expect(placed, isFalse);
      final chunks = notifier.todaySchedule!.chunks;
      // Both the long break AND its preceding short break survive — CR-01's
      // bug deleted both via the cascading while (once the long break is
      // popped, the short break becomes the new trailing chunk and matches
      // the unnarrowed `!= ChunkType.work` condition too).
      expect(chunks.map((c) => c.id).toSet(), {'w1', 'b1', 'l1'});
      expect(chunks.last.chunkType, ChunkType.longBreak);
    },
  );

  test(
    'creates a minimal today schedule when none exists (empty-state add)',
    () async {
      // No schedule pre-seeded — the empty Today screen path.
      final repo = _InMemoryScheduleRepository();
      final notifier = ScheduleNotifier(
        now: () => DateTime(2026, 3, 23),
        repo: repo,
        logRepo: _InMemoryLogRepository(),
        goalRepo: _InMemoryGoalRepository(),
      );
      await notifier.init();
      expect(notifier.hasScheduleToday, isFalse);

      final block = CommitmentBlock(
        name: 'Dentist',
        daysOfWeek: const [],
        startMinutes: 14 * 60,
        endMinutes: 15 * 60,
        date: DateTime(2026, 3, 23),
      );
      final placed = await notifier.addEventToday(block);

      expect(placed, isTrue);
      expect(notifier.hasScheduleToday, isTrue);
      final chunks = notifier.todaySchedule!.chunks;
      // 60-min window -> 4 chunks (2 work + 2 short breaks on the lattice,
      // COMMITBREAK-01), not the pre-phase 2 bare work chunks.
      expect(chunks.length, 4);
      // Break chunks carry rationale: '' (D-30-04) — only the work chunks
      // are named for the event.
      expect(
        chunks
            .where((c) => c.chunkType == ChunkType.work)
            .every((c) => c.rationale == 'Dentist'),
        isTrue,
      );
      // Persisted, so it survives a reload.
      expect(await repo.getByDate('2026-03-23'), isNotNull);
    },
  );
}
