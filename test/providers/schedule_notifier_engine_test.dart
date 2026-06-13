// ENGINE-03b (streak write-back) and ENGINE-05 (lighterDay plumbing) tests.
//
// TDD Wave — RED phase for Plan 09-03 Task 1.
// These tests will fail until ScheduleNotifier:
//   - accepts GoalRepository? goalRepo in its constructor
//   - accepts bool lighterDay in generateToday()
//   - fetches completion logs per goal and passes them + lighterDay into generate()
//   - recomputes and persists streakCount on markComplete/markSkipped

import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/data/repositories/daily_schedule_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/data/repositories/in_memory_completion_log_repository.dart';
import 'package:canopy/providers/schedule_notifier.dart';
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
  final List<Goal> _saved = [];

  _InMemoryGoalRepository(this._goals);

  List<Goal> get saved => List.unmodifiable(_saved);

  @override
  Future<List<Goal>> getAll() async => List.unmodifiable(_goals);

  @override
  Future<Goal?> getById(String id) async =>
      _goals.where((g) => g.id == id).firstOrNull;

  @override
  Future<void> save(Goal goal) async {
    _saved.add(goal);
    // Update the in-memory list so getById reflects the new streakCount.
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
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Monday 2026-06-08 used as a consistent test date (weekday = 1 = Monday).
  // This is a Monday so habits with Mon/Wed/Fri spread (3x/week) are due.
  // Verified: DateTime(2026, 6, 8).weekday == 1 (Monday).
  final testDate = DateTime(2026, 6, 8); // Monday

  // ---------------------------------------------------------------------------
  // ENGINE-05: lighterDay plumbing
  // ---------------------------------------------------------------------------

  group('ENGINE-05: lighterDay plumbing', () {
    test(
      'lighterDay=true produces strictly fewer work chunks than lighterDay=false at mood 5',
      () async {
        // 3 time-target goals with 10hr/week budget — Monday means 7 daysLeft,
        // demand = ceil(10*60/25/7) = 3 each. Cap at mood 5 = 11;
        // lighter cap at mood 5 → drops to mood 4 cap = 9.
        // lighterDay=false (mood 5, cap=11): 3*3=9 chunks scheduled
        // lighterDay=true  (mood 5, cap=9):  9 chunks scheduled (same due to cap being 9)
        // Use mood 4 (cap=9) vs lighter (cap=8): lighter=8, heavier=9, so we get 1 fewer.
        final goals = [
          Goal(
            id: 'g1',
            name: 'Goal 1',
            goalTypeIndex: GoalType.timeTarget.index,
            weeklyHourBudget: 10,
          ),
          Goal(
            id: 'g2',
            name: 'Goal 2',
            goalTypeIndex: GoalType.timeTarget.index,
            weeklyHourBudget: 10,
          ),
          Goal(
            id: 'g3',
            name: 'Goal 3',
            goalTypeIndex: GoalType.timeTarget.index,
            weeklyHourBudget: 10,
          ),
          Goal(
            id: 'g4',
            name: 'Goal 4',
            goalTypeIndex: GoalType.timeTarget.index,
            weeklyHourBudget: 10,
          ),
        ];

        final scheduleRepoHeavier = _InMemoryScheduleRepository();
        final scheduleRepoLighter = _InMemoryScheduleRepository();
        final goalRepo = _InMemoryGoalRepository(List.from(goals));
        final logRepo = InMemoryCompletionLogRepository();

        // Build notifier with lighterDay=false (heavier: mood=4, cap=9)
        final notifierHeavier = ScheduleNotifier(
          now: () => testDate,
          repo: scheduleRepoHeavier,
          logRepo: logRepo,
          goalRepo: goalRepo,
        );

        // Build notifier with lighterDay=true (lighter: mood=4, cap→mood3=8)
        final notifierLighter = ScheduleNotifier(
          now: () => testDate,
          repo: scheduleRepoLighter,
          logRepo: logRepo,
          goalRepo: goalRepo,
        );

        await notifierHeavier.generateToday(
          moodIndex: 4,
          goals: goals,
          blocks: [],
          lighterDay: false,
        );

        await notifierLighter.generateToday(
          moodIndex: 4,
          goals: goals,
          blocks: [],
          lighterDay: true,
        );

        final heavierWorkChunks = notifierHeavier.todaySchedule!.chunks
            .where((c) => c.chunkType == ChunkType.work)
            .length;
        final lighterWorkChunks = notifierLighter.todaySchedule!.chunks
            .where((c) => c.chunkType == ChunkType.work)
            .length;

        expect(
          lighterWorkChunks,
          lessThan(heavierWorkChunks),
          reason: 'lighterDay=true must produce strictly fewer work chunks than lighterDay=false',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // ENGINE-03b: streak write-back
  // ---------------------------------------------------------------------------

  group('ENGINE-03b: streak write-back', () {
    test(
      'markComplete on a due day increments streakCount and persists via GoalRepository',
      () async {
        // Habit 3x/week (Mon/Wed/Fri). Prior completed logs for the past two
        // due days (Wed 2026-06-03 and Fri 2026-06-05). Today = Mon 2026-06-08
        // (a due day). After markComplete, streakCount should be 3
        // (prior two + today).
        final goal = Goal(
          id: 'habit-g1',
          name: 'Run',
          goalTypeIndex: GoalType.habit.index,
          frequencyPerWeek: 3,
        );

        // Seed prior completed logs for the prior Mon and Wed due days.
        // Week of 2026-06-01: Mon=06-01 (weekday 1), Wed=06-03 (weekday 3),
        // Fri=06-05 (weekday 5). Today is Mon 2026-06-08 (weekday 1, the next
        // Monday). After completing today the streak walks: Mon 06-08 (just
        // appended, completed=1), Fri 06-05 (completed=2), Wed 06-03
        // (completed=3), Mon 06-01 (completed=4) → but we only seed Fri+Wed
        // so the walk finds: 06-08 (today, just appended) → 06-05 (Fri, ✓) →
        // 06-03 (Wed, ✓) → no more logs → streak=3.
        final logRepo = InMemoryCompletionLogRepository();
        await logRepo.append(CompletionLog(
          chunkId: 'c-wed',
          goalId: goal.id,
          dateYmd: '2026-06-03', // Wednesday (weekday 3, due day for 3x/week)
          eventIndex: CompletionEvent.completed.index,
        ));
        await logRepo.append(CompletionLog(
          chunkId: 'c-fri',
          goalId: goal.id,
          dateYmd: '2026-06-05', // Friday (weekday 5, due day for 3x/week)
          eventIndex: CompletionEvent.completed.index,
        ));

        final goalRepo = _InMemoryGoalRepository([goal]);
        final scheduleRepo = _InMemoryScheduleRepository();

        // Pre-seed a schedule with a habit chunk for this goal.
        final chunk = ScheduledChunk(
          id: 'chunk-habit-1',
          chunkTypeIndex: ChunkType.work.index,
          goalId: goal.id,
          durationMinutes: 25,
          rationale: '3x/week',
        );
        final schedule = DailySchedule(
          id: 'sched-1',
          dateYmd: '2026-06-08',
          moodIndex: 4,
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

        await notifier.markComplete('chunk-habit-1');

        // Should have saved the goal with the updated streakCount.
        expect(
          goalRepo.saved,
          isNotEmpty,
          reason: 'GoalRepository.save must be called for habit goals after markComplete',
        );
        final savedGoal = goalRepo.saved.last;
        expect(
          savedGoal.id,
          equals(goal.id),
          reason: 'The saved goal must be the habit goal',
        );
        // streak: prior 2 due-day logs + today's log = 3
        expect(
          savedGoal.streakCount,
          equals(3),
          reason: 'streakCount must be 3 after two prior completions and today',
        );
      },
    );

    test(
      'markSkipped on a due day resets streakCount to 0 and persists via GoalRepository',
      () async {
        // Same 3x/week habit. Prior two completed logs, then skip today.
        final goal = Goal(
          id: 'habit-g2',
          name: 'Meditate',
          goalTypeIndex: GoalType.habit.index,
          frequencyPerWeek: 3,
          streakCount: 2,
        );

        final logRepo = InMemoryCompletionLogRepository();
        await logRepo.append(CompletionLog(
          chunkId: 'c-wed-2',
          goalId: goal.id,
          dateYmd: '2026-06-03', // Wednesday (weekday 3, due day)
          eventIndex: CompletionEvent.completed.index,
        ));
        await logRepo.append(CompletionLog(
          chunkId: 'c-fri-2',
          goalId: goal.id,
          dateYmd: '2026-06-05', // Friday (weekday 5, due day)
          eventIndex: CompletionEvent.completed.index,
        ));

        final goalRepo = _InMemoryGoalRepository([goal]);
        final scheduleRepo = _InMemoryScheduleRepository();

        final chunk = ScheduledChunk(
          id: 'chunk-habit-2',
          chunkTypeIndex: ChunkType.work.index,
          goalId: goal.id,
          durationMinutes: 25,
          rationale: '3x/week',
        );
        final schedule = DailySchedule(
          id: 'sched-2',
          dateYmd: '2026-06-08',
          moodIndex: 4,
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

        await notifier.markSkipped('chunk-habit-2');

        expect(
          goalRepo.saved,
          isNotEmpty,
          reason: 'GoalRepository.save must be called for habit goals after markSkipped',
        );
        final savedGoal = goalRepo.saved.last;
        // After skip on a due day, the streak resets to 0.
        expect(
          savedGoal.streakCount,
          equals(0),
          reason: 'streakCount must be 0 after a skipped due day (streak reset)',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // STREAK-01: generation-time streak sync
  // ---------------------------------------------------------------------------

  group('STREAK-01: generateToday() syncs goal.streakCount', () {
    test(
      'After generateToday(), habit streakCount matches computeStreak — not stale default',
      () async {
        // Habit with 2 prior completed due-days. goal.streakCount starts at 0 (default).
        // After generateToday(), goal.streakCount must equal 2 (the computed value),
        // not remain at 0. This exercises the generation-time write-back path,
        // not the mark-time path.
        //
        // streak01TestDate is Sunday 2026-06-07 (weekday=7, not a due day for 3x/week).
        // computeStreak walks backward: Sun 06-07 (skip, not due), Fri 06-05
        // (due, completed → streak=1), Thu 06-04 (skip), Wed 06-03 (due,
        // completed → streak=2), Tue 06-02 (skip), Mon 06-01 (due, no log →
        // break) → returns 2.
        //
        // Using Monday 2026-06-08 as testDate would not work here: Monday IS a
        // due weekday, has no completion log yet (generateToday does not log the
        // current day), so computeStreak breaks immediately and returns 0 —
        // matching the stale stored value, and the no-op guard prevents any save.
        // Sunday is the correct anchor for proving the write-back fires and
        // persists a non-zero computed value (STREAK-01 divergence fix).
        final streak01TestDate = DateTime(2026, 6, 7); // Sunday, weekday=7

        final goal = Goal(
          id: 'streak-sync-goal',
          name: 'Run',
          goalTypeIndex: GoalType.habit.index,
          frequencyPerWeek: 3, // due Mon/Wed/Fri (weekdays 1, 3, 5)
          streakCount: 0, // stale default — must be updated at generation
        );

        final logRepo = InMemoryCompletionLogRepository();
        // Two consecutive prior due-day completions before streak01TestDate.
        await logRepo.append(CompletionLog(
          chunkId: 'c-wed',
          goalId: goal.id,
          dateYmd: '2026-06-03', // Wed (weekday 3, due day)
          eventIndex: CompletionEvent.completed.index,
        ));
        await logRepo.append(CompletionLog(
          chunkId: 'c-fri',
          goalId: goal.id,
          dateYmd: '2026-06-05', // Fri (weekday 5, due day)
          eventIndex: CompletionEvent.completed.index,
        ));

        final goalRepo = _InMemoryGoalRepository([goal]);
        final scheduleRepo = _InMemoryScheduleRepository();

        final notifier = ScheduleNotifier(
          now: () => streak01TestDate,
          repo: scheduleRepo,
          logRepo: logRepo,
          goalRepo: goalRepo,
        );

        await notifier.generateToday(
          moodIndex: 3,
          goals: [goal],
          blocks: [],
        );

        // goalRepo.saved must contain the goal with streakCount == 2.
        expect(
          goalRepo.saved,
          isNotEmpty,
          reason:
              'STREAK-01: GoalRepository.save must be called during generateToday for habit goals',
        );
        final savedGoal = goalRepo.saved.last;
        expect(
          savedGoal.streakCount,
          equals(2),
          reason:
              'STREAK-01: streakCount must equal 2 (two prior due-day completions on Fri+Wed) after generateToday on a non-due-day, not the stale 0 default',
        );
      },
    );
  });
}
