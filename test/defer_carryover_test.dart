// CLOSE-02: Defer-to-tomorrow carryover regression tests.
//
// Task 1 behaviors (deferred event + non-breaking streak + deferredGoalIds):
//   1. markDeferred logs CompletionEvent.deferred (not skipped).
//   2. computeStreak does NOT reset on a deferred due-day — continues the walk.
//   3. computeStreak DOES reset on a skipped due-day (skip ≠ defer).
//   4. generate() with deferredGoalIds injects one slot per carried goal without
//      duplicating if the goal is already scheduled.
//
// Task 2 behaviors (single-hop carry-in in generateToday):
//   5. Prior-day deferred unresolved discretionary chunk re-appears in today's schedule.
//   6. Prior-day deferred but completed chunk is NOT carried.
//   7. Prior-day deferred commitment chunk is NOT carried.
//   8. Two-days-ago deferral does NOT carry (single-hop only).

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

/// Schedule repository that can store multiple schedules by date.
class _InMemoryScheduleRepository implements DailyScheduleRepository {
  final Map<String, DailySchedule> _byDate = {};
  final Map<String, DailySchedule> _byId = {};

  @override
  Future<List<DailySchedule>> getAll() async => _byDate.values.toList();

  @override
  Future<DailySchedule?> getById(String id) async => _byId[id];

  @override
  Future<void> save(DailySchedule schedule) async {
    _byDate[schedule.dateYmd] = schedule;
    _byId[schedule.id] = schedule;
  }

  @override
  Future<void> delete(String id) async {
    final s = _byId.remove(id);
    if (s != null) _byDate.remove(s.dateYmd);
  }

  @override
  Future<DailySchedule?> getByDate(String dateYmd) async => _byDate[dateYmd];

  @override
  Future<DailySchedule?> getTodaysSchedule() async {
    // Return the most recently saved schedule (tests control the date).
    return _byDate.values.lastOrNull;
  }
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
// Shared test fixtures
// ---------------------------------------------------------------------------

/// Monday 2026-06-08 = weekday 1
final _monday = DateTime(2026, 6, 8);
/// Tuesday 2026-06-09 = weekday 2
final _tuesday = DateTime(2026, 6, 9);
/// Wednesday 2026-06-10 = weekday 3
final _wednesday = DateTime(2026, 6, 10);

Goal _makeHabitGoal({String id = 'habit-goal-1', int freq = 7}) => Goal(
      id: id,
      name: 'Run',
      goalTypeIndex: GoalType.habit.index,
      frequencyPerWeek: freq,
    );

Goal _makeOutcomeGoal({String id = 'outcome-goal-1'}) => Goal(
      id: id,
      name: 'Write book',
      goalTypeIndex: GoalType.outcome.index,
    );

// ---------------------------------------------------------------------------
// Task 1 tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // markDeferred logs CompletionEvent.deferred
  // -------------------------------------------------------------------------
  group('CLOSE-02 markDeferred: logs deferred event (not skipped)', () {
    test('markDeferred logs eventIndex == CompletionEvent.deferred.index', () async {
      final logRepo = InMemoryCompletionLogRepository();
      final scheduleRepo = _InMemoryScheduleRepository();
      final goalRepo = _InMemoryGoalRepository([]);

      // A discretionary deferred chunk
      final chunk = ScheduledChunk(
        id: 'disc-chunk-defer',
        chunkTypeIndex: ChunkType.work.index,
        goalId: 'goal-abc',
        durationMinutes: 25,
        rationale: 'Daily habit',
      );

      final schedule = DailySchedule(
        id: 'sched-defer',
        dateYmd: '2026-06-08',
        moodIndex: 3,
        chunks: [chunk],
      );
      await scheduleRepo.save(schedule);

      final notifier = ScheduleNotifier(
        now: () => _monday,
        repo: scheduleRepo,
        logRepo: logRepo,
        goalRepo: goalRepo,
      );
      await notifier.init();

      await notifier.markDeferred(chunk.id);

      final logs = await logRepo.getAll();
      expect(logs, hasLength(1));
      expect(
        logs.first.eventIndex,
        equals(CompletionEvent.deferred.index),
        reason: 'markDeferred must log CompletionEvent.deferred (not skipped)',
      );
      expect(
        logs.first.goalId,
        equals('goal-abc'),
        reason: 'goalId must be the chunk goalId for discretionary chunk',
      );
    });

    test('markDeferred on a commitment chunk logs commitmentId as goalId', () async {
      final logRepo = InMemoryCompletionLogRepository();
      final scheduleRepo = _InMemoryScheduleRepository();
      final goalRepo = _InMemoryGoalRepository([]);

      const blockId = 'block-test-id';
      final chunk = ScheduledChunk(
        id: 'commit-chunk-defer',
        chunkTypeIndex: ChunkType.work.index,
        goalId: null,
        commitmentId: blockId,
        durationMinutes: 25,
        anchoredStartMinutes: 540,
        rationale: 'Job',
      );

      final schedule = DailySchedule(
        id: 'sched-commit-defer',
        dateYmd: '2026-06-08',
        moodIndex: 3,
        chunks: [chunk],
      );
      await scheduleRepo.save(schedule);

      final notifier = ScheduleNotifier(
        now: () => _monday,
        repo: scheduleRepo,
        logRepo: logRepo,
        goalRepo: goalRepo,
      );
      await notifier.init();

      await notifier.markDeferred(chunk.id);

      final logs = await logRepo.getAll();
      expect(logs, hasLength(1));
      expect(
        logs.first.eventIndex,
        equals(CompletionEvent.deferred.index),
        reason: 'markDeferred must log CompletionEvent.deferred',
      );
      expect(
        logs.first.goalId,
        equals(blockId),
        reason: 'Commitment chunk deferred log must use commitmentId as goalId',
      );
    });
  });

  // -------------------------------------------------------------------------
  // computeStreak: deferred is non-breaking; skip is still a reset
  // -------------------------------------------------------------------------
  group('CLOSE-02 computeStreak: deferred = non-breaking; skip = reset', () {
    test('streak survives a deferred due-day', () {
      // Goal: daily habit (freq=7, every day due)
      // Log: completed Mon, deferred Tue, completed Wed → today is Wed
      // Walk backward: Wed completed → streak=1, Tue deferred → continue (no
      // increment, no reset), Mon completed → streak=2, Sun no log → break.
      // Expected streak: 2 (deferred day is non-breaking but does NOT increment).
      final goalId = 'habit-streak-1';
      final dueWeekdays = ScheduleGeneratorService.computeDueWeekdays(7);

      final logs = [
        CompletionLog(
          chunkId: 'c1',
          goalId: goalId,
          dateYmd: '2026-06-08', // Monday: completed
          eventIndex: CompletionEvent.completed.index,
        ),
        CompletionLog(
          chunkId: 'c2',
          goalId: goalId,
          dateYmd: '2026-06-09', // Tuesday: deferred
          eventIndex: CompletionEvent.deferred.index,
        ),
        CompletionLog(
          chunkId: 'c3',
          goalId: goalId,
          dateYmd: '2026-06-10', // Wednesday: completed
          eventIndex: CompletionEvent.completed.index,
        ),
      ];

      final streak = ScheduleGeneratorService.computeStreak(
        goalId,
        dueWeekdays,
        logs,
        today: _wednesday,
      );

      // Deferred Tue is non-breaking (walk continues), but does not increment.
      // Mon completed → streak=2. Sun has no log → walk breaks.
      expect(
        streak,
        equals(2),
        reason: 'Streak survives a deferred day (non-breaking; Tue does not increment)',
      );
    });

    test('streak resets on a skipped due-day (skip != defer)', () {
      // Goal: daily habit
      // Log: completed Mon, SKIPPED Tue → today is Tue
      // Expected streak: 0 (Tue is a skip → reset)
      final goalId = 'habit-streak-2';
      final dueWeekdays = ScheduleGeneratorService.computeDueWeekdays(7);

      final logs = [
        CompletionLog(
          chunkId: 'c1',
          goalId: goalId,
          dateYmd: '2026-06-08', // Monday: completed
          eventIndex: CompletionEvent.completed.index,
        ),
        CompletionLog(
          chunkId: 'c2',
          goalId: goalId,
          dateYmd: '2026-06-09', // Tuesday: skipped
          eventIndex: CompletionEvent.skipped.index,
        ),
      ];

      final streak = ScheduleGeneratorService.computeStreak(
        goalId,
        dueWeekdays,
        logs,
        today: _tuesday,
      );

      expect(
        streak,
        equals(0),
        reason: 'A skipped due-day must reset the streak to 0',
      );
    });

    test('streak survives multiple consecutive deferred due-days', () {
      // Goal: daily habit
      // Log: completed Mon, deferred Tue, deferred Wed → today is Wed
      // Expected streak: 3 (Mon completed + Tue deferred + Wed deferred, all non-breaking)
      // Wait — deferred days do NOT increment the streak, just continue the walk.
      // So: Wed = deferred (walk continues without increment), Tue = deferred (walk continues),
      // Mon = completed (increment: 1). Final streak = 1? No:
      // The streak walk increments for completions and continues (no increment, no reset) for deferrals.
      // Walking backward: Wed deferred → continue, Tue deferred → continue, Mon completed → streak=1
      // Final = 1.
      final goalId = 'habit-streak-3';
      final dueWeekdays = ScheduleGeneratorService.computeDueWeekdays(7);

      final logs = [
        CompletionLog(
          chunkId: 'c1',
          goalId: goalId,
          dateYmd: '2026-06-08', // Monday: completed
          eventIndex: CompletionEvent.completed.index,
        ),
        CompletionLog(
          chunkId: 'c2',
          goalId: goalId,
          dateYmd: '2026-06-09', // Tuesday: deferred
          eventIndex: CompletionEvent.deferred.index,
        ),
        CompletionLog(
          chunkId: 'c3',
          goalId: goalId,
          dateYmd: '2026-06-10', // Wednesday: deferred
          eventIndex: CompletionEvent.deferred.index,
        ),
      ];

      final streak = ScheduleGeneratorService.computeStreak(
        goalId,
        dueWeekdays,
        logs,
        today: _wednesday,
      );

      // Walk: Wed deferred → no-op, Tue deferred → no-op, Mon completed → streak+1=1
      expect(
        streak,
        equals(1),
        reason: 'Deferred days continue the streak walk without incrementing',
      );
    });
  });

  // -------------------------------------------------------------------------
  // generate() with deferredGoalIds injects extra slots
  // -------------------------------------------------------------------------
  group('CLOSE-02 generate: deferredGoalIds injects one slot per carried goal', () {
    test('a carried goal not already scheduled gets one injected slot', () {
      // The carried goal is NOT a daily habit due today on Monday — freq=5 (M-F
      // but we'll use a goal that generates a slot via deferredGoalIds only).
      // We pass it only in deferredGoalIds; it should appear in the output.
      final carriedGoal = _makeOutcomeGoal(id: 'carried-outcome-1');
      final sut = ScheduleGeneratorService();

      final chunks = sut.generate(
        goals: [carriedGoal],
        blocks: [],
        moodIndex: 3,
        date: _monday,
        completionLogs: [],
        deferredGoalIds: {carriedGoal.id},
      );

      final workChunks = chunks.where((c) => c.chunkType == ChunkType.work).toList();
      final carriedChunks = workChunks.where((c) => c.goalId == carriedGoal.id).toList();
      expect(
        carriedChunks,
        isNotEmpty,
        reason: 'A deferred goal passed via deferredGoalIds must appear in generated schedule',
      );
    });

    test('a carried goal already scheduled via normal generation is not duplicated', () {
      // A daily habit is scheduled normally on Monday (freq=7, due every day).
      // Also passed in deferredGoalIds — must NOT get a duplicate slot.
      final habitGoal = _makeHabitGoal(id: 'daily-habit-1', freq: 7);
      final sut = ScheduleGeneratorService();

      final chunks = sut.generate(
        goals: [habitGoal],
        blocks: [],
        moodIndex: 3,
        date: _monday,
        completionLogs: [],
        deferredGoalIds: {habitGoal.id},
      );

      final workChunks = chunks.where((c) => c.chunkType == ChunkType.work).toList();
      final habitChunks = workChunks.where((c) => c.goalId == habitGoal.id).toList();
      expect(
        habitChunks.length,
        equals(1),
        reason: 'A goal already scheduled must not be duplicated by deferredGoalIds injection',
      );
    });

    test('injection does not exceed mood cap', () {
      // Mood 1 cap = 4 chunks; fill 4 via normal goals + pass 2 more via deferredGoalIds.
      // Result must not exceed 4.
      final goals = List.generate(
        4,
        (i) => Goal(
          id: 'outcome-$i',
          name: 'Goal $i',
          goalTypeIndex: GoalType.outcome.index,
        ),
      );
      final extraGoals = [
        Goal(id: 'extra-1', name: 'Extra 1', goalTypeIndex: GoalType.outcome.index),
        Goal(id: 'extra-2', name: 'Extra 2', goalTypeIndex: GoalType.outcome.index),
      ];
      final sut = ScheduleGeneratorService();

      final chunks = sut.generate(
        goals: [...goals, ...extraGoals],
        blocks: [],
        moodIndex: 1,
        date: _monday,
        completionLogs: [],
        lighterDay: false, // cap = 4 exactly
        deferredGoalIds: {extraGoals[0].id, extraGoals[1].id},
      );

      final workChunks = chunks.where((c) => c.chunkType == ChunkType.work).toList();
      expect(
        workChunks.length,
        lessThanOrEqualTo(4),
        reason: 'deferredGoalIds injection must not exceed the mood cap',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Task 2: single-hop carry-in in generateToday
  // -------------------------------------------------------------------------
  group('CLOSE-02 generateToday: single-hop deferred carry-in', () {
    // Helper to build a notifier with seeded prior-day schedule.
    Future<({ScheduleNotifier notifier, _InMemoryScheduleRepository scheduleRepo})>
        buildNotifierWithPriorDay({
      List<ScheduledChunk> priorChunks = const [],
      List<Goal> goals = const [],
      String todayYmd = '2026-06-09', // Tuesday
      String priorYmd = '2026-06-08', // Monday
    }) async {
      final logRepo = InMemoryCompletionLogRepository();
      final scheduleRepo = _InMemoryScheduleRepository();
      final goalRepo = _InMemoryGoalRepository(List.of(goals));

      if (priorChunks.isNotEmpty) {
        final priorSchedule = DailySchedule(
          id: 'sched-prior',
          dateYmd: priorYmd,
          moodIndex: 3,
          chunks: List.of(priorChunks),
        );
        await scheduleRepo.save(priorSchedule);
      }

      final today = DateTime.parse(todayYmd);
      final notifier = ScheduleNotifier(
        now: () => today,
        repo: scheduleRepo,
        logRepo: logRepo,
        goalRepo: goalRepo,
      );
      await notifier.init();

      return (notifier: notifier, scheduleRepo: scheduleRepo);
    }

    test('deferred discretionary chunk re-appears in next morning schedule', () async {
      final goalId = 'disc-goal-carry';
      final goal = _makeOutcomeGoal(id: goalId);

      // Prior day: one deferred, unresolved, discretionary chunk
      final priorChunk = ScheduledChunk(
        id: 'prior-chunk-1',
        chunkTypeIndex: ChunkType.work.index,
        goalId: goalId,
        durationMinutes: 25,
        rationale: 'Working toward your goal',
      );
      priorChunk.isDeferred = true;
      priorChunk.isSkipped = true; // markDeferred sets both

      final ctx = await buildNotifierWithPriorDay(
        priorChunks: [priorChunk],
        goals: [goal],
      );

      // Generate today's schedule (Tuesday = _tuesday)
      await ctx.notifier.generateToday(
        moodIndex: 3,
        goals: [goal],
        blocks: [],
        lighterDay: false,
      );

      final todaySchedule = ctx.notifier.todaySchedule;
      expect(todaySchedule, isNotNull);
      final todayChunks = todaySchedule!.chunks
          .where((c) => c.chunkType == ChunkType.work && c.goalId == goalId)
          .toList();

      expect(
        todayChunks,
        isNotEmpty,
        reason: 'A deferred unresolved discretionary chunk must re-appear in the next day schedule',
      );
    });

    test('completed-deferred chunk of archived goal is NOT carried', () async {
      // Use an archived goal so it won't be scheduled via normal generation.
      // If carry-in incorrectly carries completed chunks, it would appear.
      final goalId = 'archived-goal-completed-defer';
      final goal = Goal(
        id: goalId,
        name: 'Old Goal',
        goalTypeIndex: GoalType.outcome.index,
      )..isArchived = true;

      final priorChunk = ScheduledChunk(
        id: 'prior-archived-completed',
        chunkTypeIndex: ChunkType.work.index,
        goalId: goalId,
        durationMinutes: 25,
        rationale: 'Old goal',
      );
      priorChunk.isDeferred = true;
      priorChunk.isCompleted = true; // completed — MUST NOT carry

      final ctx = await buildNotifierWithPriorDay(
        priorChunks: [priorChunk],
        goals: [goal],
      );

      await ctx.notifier.generateToday(
        moodIndex: 3,
        goals: [goal],
        blocks: [],
        lighterDay: false,
      );

      final todaySchedule = ctx.notifier.todaySchedule;
      expect(todaySchedule, isNotNull);
      final carriedChunks = todaySchedule!.chunks
          .where((c) => c.chunkType == ChunkType.work && c.goalId == goalId)
          .toList();

      expect(
        carriedChunks,
        isEmpty,
        reason: 'Completed-deferred chunk must NOT be carried over',
      );
    });

    test('deferred commitment chunk (goalId == null) is NOT carried', () async {
      // Commitment chunks have goalId == null → carry-in filter excludes them.
      final priorChunk = ScheduledChunk(
        id: 'prior-commitment-chunk',
        chunkTypeIndex: ChunkType.work.index,
        goalId: null,
        commitmentId: 'block-1',
        durationMinutes: 25,
        anchoredStartMinutes: 540,
        rationale: 'Job',
      );
      priorChunk.isDeferred = true;
      priorChunk.isSkipped = true;

      final ctx = await buildNotifierWithPriorDay(
        priorChunks: [priorChunk],
        goals: [],
      );

      await ctx.notifier.generateToday(
        moodIndex: 3,
        goals: [],
        blocks: [],
        lighterDay: false,
      );

      final todaySchedule = ctx.notifier.todaySchedule;
      // With no goals or blocks on Tuesday, result should be empty.
      expect(todaySchedule, isNotNull);
      final workChunks = todaySchedule!.chunks
          .where((c) => c.chunkType == ChunkType.work)
          .toList();
      expect(
        workChunks,
        isEmpty,
        reason: 'Commitment chunks (goalId == null) must NOT be carried over',
      );
    });

    test('two-days-ago deferred chunk does NOT carry (single-hop only)', () async {
      final goalId = 'goal-two-days-ago';
      final goal = Goal(
        id: goalId,
        name: 'Old deferred',
        goalTypeIndex: GoalType.outcome.index,
      )..isArchived = true; // archived so normal gen won't pick it up

      // Seed a schedule for two days ago (Sunday 2026-06-07), not yesterday.
      final twoDaysAgoChunk = ScheduledChunk(
        id: 'chunk-two-days-ago',
        chunkTypeIndex: ChunkType.work.index,
        goalId: goalId,
        durationMinutes: 25,
        rationale: 'Two days ago',
      );
      twoDaysAgoChunk.isDeferred = true;
      twoDaysAgoChunk.isSkipped = true;

      final logRepo = InMemoryCompletionLogRepository();
      final scheduleRepo = _InMemoryScheduleRepository();
      final goalRepo = _InMemoryGoalRepository([goal]);

      // Save schedule for two days ago (Sunday = 2026-06-07), NOT yesterday
      final twoDaysAgoSchedule = DailySchedule(
        id: 'sched-two-days-ago',
        dateYmd: '2026-06-07', // Sunday (two days before Tuesday)
        moodIndex: 3,
        chunks: [twoDaysAgoChunk],
      );
      await scheduleRepo.save(twoDaysAgoSchedule);
      // No schedule for yesterday (Monday 2026-06-08)

      final today = DateTime.parse('2026-06-09'); // Tuesday
      final notifier = ScheduleNotifier(
        now: () => today,
        repo: scheduleRepo,
        logRepo: logRepo,
        goalRepo: goalRepo,
      );
      await notifier.init();

      await notifier.generateToday(
        moodIndex: 3,
        goals: [goal],
        blocks: [],
        lighterDay: false,
      );

      final todaySchedule = notifier.todaySchedule;
      expect(todaySchedule, isNotNull);
      final carriedChunks = todaySchedule!.chunks
          .where((c) => c.chunkType == ChunkType.work && c.goalId == goalId)
          .toList();

      expect(
        carriedChunks,
        isEmpty,
        reason: 'Two-days-ago deferred chunk must NOT carry (single-hop only scans yesterday)',
      );
    });
  });
}
