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

  test('returns false for an event on a different day (does not touch today)', () async {
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
  });

  test('creates a minimal today schedule when none exists (empty-state add)', () async {
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
  });
}
