// G-05 — "extend the break to fill" (Dan, 23-UAT.md sign-off gate).
//
// Completing a work chunk early moves the immediately-following break's
// start to now while keeping its original end, so the reclaimed time is
// absorbed into rest rather than dropping the user into a neutral gap.
// Nothing downstream shifts.
//
// This is a write-side-only test of ScheduleNotifier._absorbReclaimedTimeIntoNextBreak
// (called from markComplete). lib/screens/today/now_state.dart and
// lib/screens/today/today_screen.dart receive zero changes for G-05 — Test 3
// below proves resolveNowState reaches Active(break) through its existing,
// unmodified path once the break's window genuinely opens at "now".

import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/data/repositories/completion_log_repository.dart';
import 'package:canopy/data/repositories/daily_schedule_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/screens/today/now_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryScheduleRepository implements DailyScheduleRepository {
  DailySchedule? stored;

  @override
  Future<List<DailySchedule>> getAll() async => stored == null ? [] : [stored!];

  @override
  Future<DailySchedule?> getById(String id) async =>
      stored?.id == id ? stored : null;

  @override
  Future<void> save(DailySchedule schedule) async => stored = schedule;

  @override
  Future<void> delete(String id) async {
    if (stored?.id == id) stored = null;
  }

  @override
  Future<DailySchedule?> getByDate(String dateYmd) async =>
      stored?.dateYmd == dateYmd ? stored : null;

  @override
  Future<DailySchedule?> getTodaysSchedule() async => stored;
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
  final List<CompletionLog> logs = [];
  @override
  Future<List<CompletionLog>> getAll() async => logs;
  @override
  Future<CompletionLog?> getById(String id) async => null;
  @override
  Future<void> append(CompletionLog entry) async => logs.add(entry);
  @override
  Future<List<CompletionLog>> getByDate(String dateYmd) async => logs;
  @override
  Future<List<CompletionLog>> getByGoalId(String goalId) async => logs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testDateYmd = '2026-06-13';

  ScheduleNotifier makeNotifier({
    required _InMemoryScheduleRepository repo,
    required DateTime Function() now,
    required List<ScheduledChunk> chunks,
  }) {
    repo.stored = DailySchedule(
      id: 'sched-g05',
      dateYmd: testDateYmd,
      moodIndex: 3,
      chunks: chunks,
    );
    return ScheduleNotifier(
      now: now,
      repo: repo,
      logRepo: _InMemoryLogRepository(),
      goalRepo: _InMemoryGoalRepository(),
    );
  }

  group('G-05 happy path', () {
    late _InMemoryScheduleRepository repo;
    late ScheduleNotifier notifier;
    late ScheduledChunk w1;
    late ScheduledChunk b1;
    late ScheduledChunk w2;

    setUp(() async {
      repo = _InMemoryScheduleRepository();
      w1 = ScheduledChunk(
        id: 'w1',
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'goal-1',
        durationMinutes: 25,
        syntheticStartMinutes: 600, // 10:00
        rationale: 'Cleaning',
      );
      b1 = ScheduledChunk(
        id: 'b1',
        chunkTypeIndex: ChunkType.shortBreak.index,
        durationMinutes: 5,
        syntheticStartMinutes: 625, // 10:25
        rationale: '',
      );
      w2 = ScheduledChunk(
        id: 'w2',
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'goal-1',
        durationMinutes: 25,
        syntheticStartMinutes: 630, // 10:30
        rationale: 'Cleaning',
      );
      notifier = makeNotifier(
        repo: repo,
        now: () => DateTime(2026, 6, 13, 10, 10),
        chunks: [w1, b1, w2],
      );
      await notifier.init();
      await notifier.markComplete('w1');
    });

    test('G-05: the following break absorbs the reclaimed time', () {
      expect(b1.displayStartMinutes, 610);
      expect(b1.durationMinutes, 20);
      expect(b1.displayStartMinutes! + b1.durationMinutes, 630);
    });

    test('G-05: nothing downstream shifts', () {
      expect(w2.displayStartMinutes, 630);
      expect(w2.durationMinutes, 25);
      expect(w1.displayStartMinutes, 600);
      expect(w1.durationMinutes, 25);
      expect(w1.isCompleted, isTrue);
    });

    test('G-05: resolveNowState returns Active(break) through the existing '
        'unmodified path', () {
      final state = resolveNowState(
        chunks: repo.stored!.chunks,
        now: () => DateTime(2026, 6, 13, 10, 12),
      );
      expect(state, isA<Active>());
      expect((state as Active).current.id, 'b1');
    });

    test('G-05: persisted — one save carries both the completion flag and '
        'the moved break', () {
      final reread = repo.stored!.chunks.firstWhere((c) => c.id == 'b1');
      expect(reread.displayStartMinutes, 610);
      expect(reread.durationMinutes, 20);
    });
  });

  test('G-05: long break variant', () async {
    final repo = _InMemoryScheduleRepository();
    final w1 = ScheduledChunk(
      id: 'w1',
      chunkTypeIndex: ChunkType.work.index,
      goalId: 'goal-1',
      durationMinutes: 25,
      syntheticStartMinutes: 600, // 10:00
      rationale: 'Cleaning',
    );
    final b1 = ScheduledChunk(
      id: 'b1',
      chunkTypeIndex: ChunkType.longBreak.index,
      durationMinutes: 25,
      syntheticStartMinutes: 625, // 10:25, ends 10:50
      rationale: '',
    );
    final notifier = makeNotifier(
      repo: repo,
      now: () => DateTime(2026, 6, 13, 10, 5),
      chunks: [w1, b1],
    );
    await notifier.init();
    await notifier.markComplete('w1');

    expect(b1.displayStartMinutes, 605);
    expect(b1.durationMinutes, 45);
  });

  group('G-05 no-op guards', () {
    test(
      'completed at the scheduled end leaves the break untouched',
      () async {
        final repo = _InMemoryScheduleRepository();
        final w1 = ScheduledChunk(
          id: 'w1',
          chunkTypeIndex: ChunkType.work.index,
          goalId: 'goal-1',
          durationMinutes: 25,
          syntheticStartMinutes: 600,
          rationale: 'Cleaning',
        );
        final b1 = ScheduledChunk(
          id: 'b1',
          chunkTypeIndex: ChunkType.shortBreak.index,
          durationMinutes: 5,
          syntheticStartMinutes: 625,
          rationale: '',
        );
        final notifier = makeNotifier(
          repo: repo,
          now: () => DateTime(2026, 6, 13, 10, 25), // exactly the sched. end
          chunks: [w1, b1],
        );
        await notifier.init();
        await notifier.markComplete('w1');

        expect(
          b1.displayStartMinutes,
          625,
          reason: 'Guard 4: completing at the scheduled end reclaims nothing',
        );
        expect(b1.durationMinutes, 5, reason: 'Guard 4');
      },
    );

    test(
      'completed after the scheduled end leaves the break untouched',
      () async {
        final repo = _InMemoryScheduleRepository();
        final w1 = ScheduledChunk(
          id: 'w1',
          chunkTypeIndex: ChunkType.work.index,
          goalId: 'goal-1',
          durationMinutes: 25,
          syntheticStartMinutes: 600,
          rationale: 'Cleaning',
        );
        final b1 = ScheduledChunk(
          id: 'b1',
          chunkTypeIndex: ChunkType.shortBreak.index,
          durationMinutes: 5,
          syntheticStartMinutes: 625,
          rationale: '',
        );
        final notifier = makeNotifier(
          repo: repo,
          now: () => DateTime(2026, 6, 13, 10, 30), // past the sched. end
          chunks: [w1, b1],
        );
        await notifier.init();
        await notifier.markComplete('w1');

        expect(
          b1.displayStartMinutes,
          625,
          reason:
              'Guard 4: completing after the scheduled end reclaims nothing',
        );
        expect(b1.durationMinutes, 5, reason: 'Guard 4');
      },
    );

    test('the following chunk is work, not a break — nothing moves', () async {
      final repo = _InMemoryScheduleRepository();
      final w1 = ScheduledChunk(
        id: 'w1',
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'goal-1',
        durationMinutes: 25,
        syntheticStartMinutes: 600,
        rationale: 'Cleaning',
      );
      final w2 = ScheduledChunk(
        id: 'w2',
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'goal-1',
        durationMinutes: 25,
        syntheticStartMinutes: 625,
        rationale: 'Cleaning',
      );
      final notifier = makeNotifier(
        repo: repo,
        now: () => DateTime(2026, 6, 13, 10, 10),
        chunks: [w1, w2],
      );
      await notifier.init();
      await notifier.markComplete('w1');

      expect(
        w2.displayStartMinutes,
        625,
        reason: 'Guard 5: the following chunk must be a break',
      );
      expect(w2.durationMinutes, 25, reason: 'Guard 5');
    });

    test(
      'no following chunk — markComplete completes without throwing',
      () async {
        final repo = _InMemoryScheduleRepository();
        final w1 = ScheduledChunk(
          id: 'w1',
          chunkTypeIndex: ChunkType.work.index,
          goalId: 'goal-1',
          durationMinutes: 25,
          syntheticStartMinutes: 600,
          rationale: 'Cleaning',
        );
        final notifier = makeNotifier(
          repo: repo,
          now: () => DateTime(2026, 6, 13, 10, 10),
          chunks: [w1],
        );
        await notifier.init();
        await notifier.markComplete('w1');

        expect(
          w1.isCompleted,
          isTrue,
          reason: 'Guard 5: no following chunk is a clean no-op, not a throw',
        );
      },
    );

    test(
      "the break's window has already opened — guard 7, nothing to move",
      () async {
        final repo = _InMemoryScheduleRepository();
        final w1 = ScheduledChunk(
          id: 'w1',
          chunkTypeIndex: ChunkType.work.index,
          goalId: 'goal-1',
          durationMinutes: 60, // 10:00-11:00
          syntheticStartMinutes: 600,
          rationale: 'Cleaning',
        );
        final b1 = ScheduledChunk(
          id: 'b1',
          chunkTypeIndex: ChunkType.shortBreak.index,
          durationMinutes: 5,
          syntheticStartMinutes: 625,
          rationale: '',
        );
        final notifier = makeNotifier(
          repo: repo,
          now: () => DateTime(2026, 6, 13, 10, 30), // 630, break already open
          chunks: [w1, b1],
        );
        await notifier.init();
        await notifier.markComplete('w1');

        expect(
          b1.displayStartMinutes,
          625,
          reason:
              "Guard 7: the break's window already opened — nothing to move",
        );
        expect(b1.durationMinutes, 5, reason: 'Guard 7');
      },
    );
  });

  test('G-05 revert on failure — the break, the completion flag and the '
      'store never diverge (WR-05)', () async {
    final w1 = ScheduledChunk(
      id: 'w1',
      chunkTypeIndex: ChunkType.work.index,
      goalId: 'goal-1',
      durationMinutes: 25,
      syntheticStartMinutes: 600,
      rationale: 'Cleaning',
    );
    final b1 = ScheduledChunk(
      id: 'b1',
      chunkTypeIndex: ChunkType.shortBreak.index,
      durationMinutes: 5,
      syntheticStartMinutes: 625,
      rationale: '',
    );
    final schedule = DailySchedule(
      id: 'sched-g05-throw',
      dateYmd: testDateYmd,
      moodIndex: 3,
      chunks: [w1, b1],
    );
    // Seed the throwing repo's getTodaysSchedule indirectly isn't possible
    // (it always returns null), so drive _todaySchedule via addEventToday's
    // sibling path is unavailable too. Instead construct the notifier with a
    // repo whose getTodaysSchedule returns the seeded schedule but whose
    // save() throws, isolating exactly the WR-05 failure mode under test.
    final repo = _SeededThrowingScheduleRepository(schedule);
    final notifier = ScheduleNotifier(
      now: () => DateTime(2026, 6, 13, 10, 10),
      repo: repo,
      logRepo: _InMemoryLogRepository(),
      goalRepo: _InMemoryGoalRepository(),
    );
    await notifier.init();

    await expectLater(() => notifier.markComplete('w1'), throwsException);

    expect(b1.displayStartMinutes, 625, reason: 'WR-05 revert (break start)');
    expect(b1.durationMinutes, 5, reason: 'WR-05 revert (break duration)');
    expect(w1.isCompleted, isFalse, reason: 'WR-05 revert (completion flag)');
  });

  test(
    'G-05 preserves the Phase 17 invariant — an unmoved, unopened break '
    'still reads as a gap (today_screen_now_state_test.dart:470-487)',
    () {
      // The invariant's own fixture, reproduced directly: a completed work
      // chunk at 480/25 (8:00-8:25) and an unopened break at 505/5
      // (8:25-8:30). No markComplete ran here — this is the case where the
      // break was NOT moved — so resolveNowState must still return
      // GapBeforeNext, exactly as the KEY INVARIANT test asserts.
      final w1 = ScheduledChunk(
        id: 'w1',
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'goal-1',
        durationMinutes: 25,
        syntheticStartMinutes: 480,
        rationale: 'Cleaning',
      )..isCompleted = true;
      final b1 = ScheduledChunk(
        id: 'b1',
        chunkTypeIndex: ChunkType.shortBreak.index,
        durationMinutes: 5,
        syntheticStartMinutes: 505,
        rationale: '',
      );

      final state = resolveNowState(
        chunks: [w1, b1],
        now: () => DateTime(2026, 6, 13, 8, 10),
      );
      expect(state, isA<GapBeforeNext>());
      expect((state as GapBeforeNext).next.id, 'b1');
    },
  );
}

/// A schedule repository whose [getTodaysSchedule] returns a fixed, seeded
/// schedule but whose [save] always throws — isolates the WR-05 revert path
/// (persistence failure) without needing generateToday's own persistence.
class _SeededThrowingScheduleRepository implements DailyScheduleRepository {
  _SeededThrowingScheduleRepository(this._schedule);
  final DailySchedule _schedule;

  @override
  Future<List<DailySchedule>> getAll() async => [_schedule];
  @override
  Future<DailySchedule?> getById(String id) async =>
      id == _schedule.id ? _schedule : null;
  @override
  Future<void> save(DailySchedule schedule) async {
    throw Exception('simulated save failure');
  }

  @override
  Future<void> delete(String id) async {}
  @override
  Future<DailySchedule?> getByDate(String dateYmd) async =>
      dateYmd == _schedule.dateYmd ? _schedule : null;
  @override
  Future<DailySchedule?> getTodaysSchedule() async => _schedule;
}
