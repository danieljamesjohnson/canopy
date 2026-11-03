// WINDOWS entry 16: ScheduleNotifier.applyCalendarSync.

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

  // WINDOWS entry 16 (2026-11-03): a sync from Settings -> Calendars must
  // reach TODAY's already-built timeline without a Re-check-in.
  const today = '2026-03-23'; // Monday
  final todayDate = DateTime(2026, 3, 23);

  ScheduledChunk work(String id, int startMinutes) => ScheduledChunk(
    id: id,
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'goal-1',
    durationMinutes: 25,
    syntheticStartMinutes: startMinutes,
    rationale: 'Habit',
  );

  Future<(ScheduleNotifier, _InMemoryScheduleRepository)> make({
    List<ScheduledChunk>? chunks,
  }) async {
    final repo = _InMemoryScheduleRepository();
    if (chunks != null) {
      await repo.save(
        DailySchedule(id: 's', dateYmd: today, moodIndex: 3, chunks: chunks),
      );
    }
    final notifier = ScheduleNotifier(
      now: () => DateTime(2026, 3, 23, 8),
      repo: repo,
      logRepo: _InMemoryLogRepository(),
      goalRepo: _InMemoryGoalRepository(),
    );
    await notifier.init();
    return (notifier, repo);
  }

  CommitmentBlock calendarBlock(String id, int start, int end) =>
      CommitmentBlock(
        id: id,
        name: 'From calendar $id',
        daysOfWeek: const [],
        startMinutes: start,
        endMinutes: end,
        date: todayDate,
        externalEventId: 'ics:x:$id:',
        isFromCalendar: true,
      );

  bool overlaps(ScheduledChunk c, int start, int end) {
    final s = c.displayStartMinutes!;
    return s < end && s + c.durationMinutes > start;
  }

  test('a synced event for today lands on the timeline and work that '
      'overlapped it moves out of its way', () async {
    final (notifier, _) = await make(chunks: [work('w1', 14 * 60)]);

    await notifier.applyCalendarSync([calendarBlock('cal', 14 * 60, 15 * 60)]);

    final chunks = notifier.todaySchedule!.chunks;
    expect(chunks.where((c) => c.commitmentId == 'cal'), isNotEmpty);
    final w1 = chunks.singleWhere((c) => c.id == 'w1');
    expect(overlaps(w1, 14 * 60, 15 * 60), isFalse);
  });

  test('a hand-entered commitment is NOT placed by a calendar sync', () async {
    final (notifier, _) = await make(chunks: [work('w1', 9 * 60)]);
    final manual = CommitmentBlock(
      id: 'manual',
      name: 'Gym',
      daysOfWeek: const [],
      startMinutes: 14 * 60,
      endMinutes: 15 * 60,
      date: todayDate,
    );

    await notifier.applyCalendarSync([manual]);

    expect(
      notifier.todaySchedule!.chunks.where((c) => c.commitmentId == 'manual'),
      isEmpty,
    );
  });

  test('a second sync with nothing changed leaves the timeline untouched '
      '(same chunk ids — not torn down and rebuilt)', () async {
    final (notifier, _) = await make(chunks: [work('w1', 9 * 60)]);
    final block = calendarBlock('cal', 14 * 60, 15 * 60);
    await notifier.applyCalendarSync([block]);
    final first = notifier.todaySchedule!.chunks.map((c) => c.id).toList();

    await notifier.applyCalendarSync([block]);

    expect(notifier.todaySchedule!.chunks.map((c) => c.id).toList(), first);
  });

  test('a synced event whose time changed is re-anchored at the new time',
      () async {
    final (notifier, _) = await make(chunks: [work('w1', 9 * 60)]);
    await notifier.applyCalendarSync([calendarBlock('cal', 14 * 60, 15 * 60)]);

    await notifier.applyCalendarSync([calendarBlock('cal', 16 * 60, 17 * 60)]);

    final starts = notifier.todaySchedule!.chunks
        .where((c) => c.commitmentId == 'cal')
        .map((c) => c.anchoredStartMinutes!)
        .toList();
    expect(starts.reduce((a, b) => a < b ? a : b), 16 * 60);
  });

  test('an event the sync removed leaves today, a manual one stays', () async {
    final (notifier, _) = await make(chunks: [work('w1', 9 * 60)]);
    final manual = CommitmentBlock(
      id: 'manual',
      name: 'Gym',
      daysOfWeek: const [],
      startMinutes: 11 * 60,
      endMinutes: 12 * 60,
      date: todayDate,
    );
    await notifier.addEventToday(manual);
    await notifier.applyCalendarSync([calendarBlock('cal', 14 * 60, 15 * 60)]);
    expect(
      notifier.todaySchedule!.chunks.where((c) => c.commitmentId == 'cal'),
      isNotEmpty,
    );

    await notifier.applyCalendarSync([manual], removedCalendarBlockIds: {'cal'});

    final chunks = notifier.todaySchedule!.chunks;
    expect(chunks.where((c) => c.commitmentId == 'cal'), isEmpty);
    expect(chunks.where((c) => c.commitmentId == 'manual'), isNotEmpty);
  });

  test('no schedule today yet: the sync does not create one (check-in will)',
      () async {
    final (notifier, repo) = await make();

    await notifier.applyCalendarSync([calendarBlock('cal', 14 * 60, 15 * 60)]);

    expect(notifier.hasScheduleToday, isFalse);
    expect(await repo.getAll(), isEmpty);
  });
}
