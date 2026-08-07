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
      endMinutes: 15 * 60, // 3:00pm → 2 chunks
      date: DateTime(2026, 3, 23),
    );
    final inserted = await notifier.addEventToday(block);

    expect(inserted, isTrue);
    final chunks = notifier.todaySchedule!.chunks;
    // Original completed chunk still present and still completed.
    final orig = chunks.where((c) => c.id == 'chunk-done');
    expect(orig.length, 1);
    expect(orig.first.isCompleted, isTrue);
    // Two new anchored "Dentist" chunks were added at 2pm/2:25pm.
    final dentist = chunks.where((c) => c.rationale == 'Dentist').toList();
    expect(dentist.length, 2);
    expect(dentist.every((c) => c.commitmentId == block.id), isTrue);
    expect(dentist.first.anchoredStartMinutes, 14 * 60);
    // Sorted: the 8am completed chunk precedes the 2pm event.
    expect(chunks.first.id, 'chunk-done');
  });

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
      // Exactly the new placement — no stale 10:00 copy left behind.
      expect(callChunks.length, 2);
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
      expect(chunks.length, 2);
      expect(chunks.every((c) => c.rationale == 'Dentist'), isTrue);
      // Persisted, so it survives a reload.
      expect(await repo.getByDate('2026-03-23'), isNotNull);
    },
  );
}
