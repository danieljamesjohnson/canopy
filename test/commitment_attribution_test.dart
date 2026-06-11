// CLOSE-03: Commitment-time attribution regression tests.
//
// Verifies that:
//   1. Generating a schedule with a CommitmentBlock produces work chunks whose
//      commitmentId equals the block's id and whose goalId is null.
//   2. markComplete on a commitment chunk appends a CompletionLog whose goalId
//      equals the CommitmentBlock.id (non-empty).
//   3. markSkipped on a commitment chunk appends a CompletionLog whose goalId
//      equals the CommitmentBlock.id (non-empty).
//   4. A discretionary (goal) chunk still logs its own goalId unchanged
//      (commitmentId null → falls through to goalId).
//
// Uses the in-memory log-repo test seam established in Phase 9 tests.
// No Hive bootstrap required.

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/data/repositories/daily_schedule_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/data/repositories/in_memory_completion_log_repository.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/services/schedule_generator.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// In-memory fakes (no Hive bootstrap required)
// ---------------------------------------------------------------------------

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
  final List<Goal> _goals;

  _InMemoryGoalRepository(this._goals);

  @override
  Future<List<Goal>> getAll() async => List.unmodifiable(_goals);

  @override
  Future<Goal?> getById(String id) async =>
      _goals.where((g) => g.id == id).firstOrNull;

  @override
  Future<void> save(Goal goal) async {
    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx >= 0) _goals[idx] = goal;
  }

  @override
  Future<void> delete(String id) async {
    _goals.removeWhere((g) => g.id == id);
  }

  @override
  Future<List<Goal>> getActive() async =>
      _goals.where((g) => !g.isArchived).toList();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CommitmentBlock _makeBlock({
  String name = 'Job',
  List<int> daysOfWeek = const [1, 2, 3, 4, 5],
  int startMinutes = 540, // 09:00
  int endMinutes = 600,   // 10:00 — 60-min window → 2 × 25-min slots
}) =>
    CommitmentBlock(
      id: 'block-test-id',
      name: name,
      daysOfWeek: daysOfWeek,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Monday 2026-06-08 is used as the test date (weekday == 1).
  final testDate = DateTime(2026, 6, 8); // Monday

  // ---------------------------------------------------------------------------
  // Generator-level: commitmentId set on Step 1 chunks
  // ---------------------------------------------------------------------------

  group('CLOSE-03 generator: commitmentId set on commitment chunks', () {
    test(
      'commitment chunk carries commitmentId == block.id and goalId == null',
      () {
        final block = _makeBlock();
        final sut = ScheduleGeneratorService();

        final chunks = sut.generate(
          goals: [],
          blocks: [block],
          moodIndex: 3,
          date: testDate,
          completionLogs: [],
        );

        final workChunks = chunks.where((c) => c.chunkType == ChunkType.work).toList();
        expect(workChunks, isNotEmpty, reason: 'Should generate at least one work chunk');

        for (final chunk in workChunks) {
          expect(
            chunk.commitmentId,
            equals(block.id),
            reason: 'Each commitment work chunk must carry commitmentId == block.id',
          );
          expect(
            chunk.goalId,
            isNull,
            reason: 'Commitment chunks must not set goalId (preserves goalId == Goal-id invariant)',
          );
        }
      },
    );

    test(
      'discretionary (goal) chunk has null commitmentId and non-null goalId',
      () {
        final goal = Goal(
          id: 'goal-disc-1',
          name: 'Run',
          goalTypeIndex: GoalType.habit.index,
          frequencyPerWeek: 7, // daily
        );
        final sut = ScheduleGeneratorService();

        final chunks = sut.generate(
          goals: [goal],
          blocks: [], // no commitment blocks
          moodIndex: 3,
          date: testDate,
          completionLogs: [],
        );

        final workChunks = chunks.where((c) => c.chunkType == ChunkType.work).toList();
        expect(workChunks, isNotEmpty);

        for (final chunk in workChunks) {
          expect(
            chunk.commitmentId,
            isNull,
            reason: 'Discretionary chunks must have null commitmentId',
          );
          expect(
            chunk.goalId,
            equals(goal.id),
            reason: 'Discretionary chunks must carry the goal id',
          );
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Notifier-level: markComplete / markSkipped log the right goalId
  // ---------------------------------------------------------------------------

  group('CLOSE-03 notifier: commitment chunk logs non-empty CommitmentBlock.id', () {
    // Helper that sets up a notifier pre-seeded with one commitment chunk.
    Future<({ScheduleNotifier notifier, InMemoryCompletionLogRepository logRepo, ScheduledChunk chunk})>
        buildNotifier({required String blockId}) async {
      final logRepo = InMemoryCompletionLogRepository();
      final scheduleRepo = _InMemoryScheduleRepository();
      final goalRepo = _InMemoryGoalRepository([]);

      // Build a commitment chunk — mirrors what the generator produces after this plan.
      final chunk = ScheduledChunk(
        id: 'commit-chunk-1',
        chunkTypeIndex: ChunkType.work.index,
        goalId: null,
        commitmentId: blockId,
        durationMinutes: 25,
        anchoredStartMinutes: 540,
        rationale: 'Job',
      );

      final schedule = DailySchedule(
        id: 'sched-commit',
        dateYmd: '2026-06-08',
        moodIndex: 3,
        chunks: [chunk],
      );
      await scheduleRepo.save(schedule);

      final notifier = ScheduleNotifier(
        now: () => testDate,
        repo: scheduleRepo,
        logRepo: logRepo,
        goalRepo: goalRepo,
      );
      await notifier.init();

      return (notifier: notifier, logRepo: logRepo, chunk: chunk);
    }

    test(
      'markComplete on a commitment chunk logs CompletionLog.goalId == block.id (non-empty)',
      () async {
        const blockId = 'block-test-id';
        final ctx = await buildNotifier(blockId: blockId);

        await ctx.notifier.markComplete(ctx.chunk.id);

        final logs = await ctx.logRepo.getAll();
        expect(logs, hasLength(1));

        final log = logs.first;
        expect(
          log.goalId,
          equals(blockId),
          reason: 'markComplete must log the CommitmentBlock.id as goalId (not empty)',
        );
        expect(
          log.goalId,
          isNotEmpty,
          reason: 'goalId must be non-empty for commitment chunks',
        );
        expect(
          log.eventIndex,
          equals(CompletionEvent.completed.index),
          reason: 'Event must be CompletionEvent.completed',
        );
      },
    );

    test(
      'markSkipped on a commitment chunk logs CompletionLog.goalId == block.id (non-empty)',
      () async {
        const blockId = 'block-test-id';
        final ctx = await buildNotifier(blockId: blockId);

        await ctx.notifier.markSkipped(ctx.chunk.id);

        final logs = await ctx.logRepo.getAll();
        expect(logs, hasLength(1));

        final log = logs.first;
        expect(
          log.goalId,
          equals(blockId),
          reason: 'markSkipped must log the CommitmentBlock.id as goalId (not empty)',
        );
        expect(
          log.goalId,
          isNotEmpty,
          reason: 'goalId must be non-empty for commitment chunks',
        );
      },
    );

    test(
      'markComplete on a discretionary (goal) chunk still logs the goalId unchanged',
      () async {
        const goalId = 'goal-disc-123';
        final logRepo = InMemoryCompletionLogRepository();
        final scheduleRepo = _InMemoryScheduleRepository();
        final goalRepo = _InMemoryGoalRepository([]);

        // A discretionary chunk has null commitmentId and non-null goalId.
        final chunk = ScheduledChunk(
          id: 'disc-chunk-1',
          chunkTypeIndex: ChunkType.work.index,
          goalId: goalId,
          durationMinutes: 25,
          rationale: 'Working toward your goal',
        );

        final schedule = DailySchedule(
          id: 'sched-disc',
          dateYmd: '2026-06-08',
          moodIndex: 3,
          chunks: [chunk],
        );
        await scheduleRepo.save(schedule);

        final notifier = ScheduleNotifier(
          now: () => testDate,
          repo: scheduleRepo,
          logRepo: logRepo,
          goalRepo: goalRepo,
        );
        await notifier.init();

        await notifier.markComplete(chunk.id);

        final logs = await logRepo.getAll();
        expect(logs, hasLength(1));

        final log = logs.first;
        expect(
          log.goalId,
          equals(goalId),
          reason: 'Discretionary chunk must still log its own goalId (commitmentId is null → falls through)',
        );
      },
    );
  });
}
