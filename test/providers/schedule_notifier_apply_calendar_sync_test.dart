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
import 'package:canopy/services/schedule_generator.dart';
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
    // D-36-06: exactly as the calendar says — one block, no break inside.
    final cal = chunks.where((c) => c.commitmentId == 'cal').toList();
    expect(cal, hasLength(1));
    expect(cal.single.anchoredStartMinutes, 14 * 60);
    expect(cal.single.durationMinutes, 60);
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

  test(
    'a synced event whose time changed is re-anchored at the new time',
    () async {
      final (notifier, _) = await make(chunks: [work('w1', 9 * 60)]);
      await notifier.applyCalendarSync([
        calendarBlock('cal', 14 * 60, 15 * 60),
      ]);

      await notifier.applyCalendarSync([
        calendarBlock('cal', 16 * 60, 17 * 60),
      ]);

      final starts = notifier.todaySchedule!.chunks
          .where((c) => c.commitmentId == 'cal')
          .map((c) => c.anchoredStartMinutes!)
          .toList();
      expect(starts.reduce((a, b) => a < b ? a : b), 16 * 60);
    },
  );

  test('a meeting already on today in the OLD 25+5 lattice (before D-36-06) '
      'is rebuilt as one block', () async {
    ScheduledChunk part(String id, ChunkType type, int start, int len) =>
        ScheduledChunk(
          id: id,
          chunkTypeIndex: type.index,
          commitmentId: 'cal',
          durationMinutes: len,
          anchoredStartMinutes: start,
          rationale: '',
        );
    final (notifier, _) = await make(
      chunks: [
        work('w1', 9 * 60),
        part('a', ChunkType.work, 14 * 60, 25),
        part('b', ChunkType.shortBreak, 14 * 60 + 25, 5),
        part('c', ChunkType.work, 14 * 60 + 30, 25),
        part('d', ChunkType.shortBreak, 14 * 60 + 55, 5),
      ],
    );

    await notifier.applyCalendarSync([calendarBlock('cal', 14 * 60, 15 * 60)]);

    final cal = notifier.todaySchedule!.chunks
        .where((c) => c.commitmentId == 'cal')
        .toList();
    expect(cal, hasLength(1));
    expect(cal.single.durationMinutes, 60);
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

    await notifier.applyCalendarSync(
      [manual],
      removedCalendarBlockIds: {'cal'},
    );

    final chunks = notifier.todaySchedule!.chunks;
    expect(chunks.where((c) => c.commitmentId == 'cal'), isEmpty);
    expect(chunks.where((c) => c.commitmentId == 'manual'), isNotEmpty);
  });

  test(
    'no schedule today yet: the sync does not create one (check-in will)',
    () async {
      final (notifier, repo) = await make();

      await notifier.applyCalendarSync([
        calendarBlock('cal', 14 * 60, 15 * 60),
      ]);

      expect(notifier.hasScheduleToday, isFalse);
      expect(await repo.getAll(), isEmpty);
    },
  );

  // WINDOWS entry 19 (owner on the iPhone, 2026-11-05): a synced 11:00-12:00
  // meeting was drawn on top of his hand-entered Work block's short and long
  // breaks. The meeting takes that time; Work keeps the rest.
  group('a hand-entered commitment yields to a meeting (entry 19)', () {
    CommitmentBlock workBlock() => CommitmentBlock(
      id: 'workblock',
      name: 'Work',
      daysOfWeek: const [1, 2, 3, 4, 5],
      startMinutes: 9 * 60,
      endMinutes: 17 * 60,
    );

    List<ScheduledChunk> intruders(List<ScheduledChunk> chunks, int s, int e) =>
        [
          for (final c in chunks)
            if (c.commitmentId != 'cal' &&
                c.displayStartMinutes != null &&
                overlaps(c, s, e))
              c,
        ];

    test('sync onto a day already built with Work: nothing of Work is left '
        'under the meeting, and Work still runs before and after it', () async {
      final (notifier, _) = await make(chunks: [work('w1', 18 * 60)]);
      final w = workBlock();
      await notifier.addEventToday(w);
      expect(
        intruders(notifier.todaySchedule!.chunks, 11 * 60, 12 * 60),
        isNotEmpty,
        reason: 'precondition: Work fills 11-12 before the meeting arrives',
      );

      await notifier.applyCalendarSync([
        w,
        calendarBlock('cal', 11 * 60, 12 * 60),
      ]);

      final chunks = notifier.todaySchedule!.chunks;
      expect(intruders(chunks, 11 * 60, 12 * 60), isEmpty);
      final workStarts = chunks
          .where((c) => c.commitmentId == 'workblock')
          .map((c) => c.anchoredStartMinutes!)
          .toList();
      expect(workStarts.any((s) => s < 11 * 60), isTrue);
      expect(workStarts.any((s) => s >= 12 * 60), isTrue);
      expect(chunks.where((c) => c.commitmentId == 'cal'), hasLength(1));
    });

    test('the meeting going away gives Work its time back', () async {
      final (notifier, _) = await make(chunks: [work('w1', 18 * 60)]);
      final w = workBlock();
      await notifier.addEventToday(w);
      await notifier.applyCalendarSync([
        w,
        calendarBlock('cal', 11 * 60, 12 * 60),
      ]);

      await notifier.applyCalendarSync([w], removedCalendarBlockIds: {'cal'});

      final back = notifier.todaySchedule!.chunks.where(
        (c) => c.commitmentId == 'workblock' && overlaps(c, 11 * 60, 12 * 60),
      );
      expect(back, isNotEmpty);
    });

    test('a completed Work chunk survives the rebuild untouched', () async {
      final (notifier, _) = await make(chunks: [work('w1', 18 * 60)]);
      final w = workBlock();
      await notifier.addEventToday(w);
      final first = notifier.todaySchedule!.chunks.firstWhere(
        (c) => c.commitmentId == 'workblock' && c.anchoredStartMinutes == 540,
      );
      await notifier.markComplete(first.id);

      await notifier.applyCalendarSync([
        w,
        calendarBlock('cal', 11 * 60, 12 * 60),
      ]);

      final chunks = notifier.todaySchedule!.chunks;
      final kept = chunks.where((c) => c.id == first.id).toList();
      expect(kept, hasLength(1));
      expect(kept.single.isCompleted, isTrue);
      final atNine = chunks.where(
        (c) => c.commitmentId == 'workblock' && overlaps(c, 540, 565),
      );
      expect(atNine, hasLength(1), reason: 'no second chunk stacked on it');
    });

    test('check-in builds Work around the meeting too', () {
      final chunks = ScheduleGeneratorService().generate(
        goals: const [],
        blocks: [workBlock(), calendarBlock('cal', 11 * 60, 12 * 60)],
        moodIndex: 3,
        date: todayDate,
      );
      expect(intruders(chunks, 11 * 60, 12 * 60), isEmpty);
      expect(
        chunks.where(
          (c) => c.commitmentId == 'workblock' && overlaps(c, 540, 660),
        ),
        isNotEmpty,
      );
      expect(
        chunks.where(
          (c) => c.commitmentId == 'workblock' && overlaps(c, 720, 1020),
        ),
        isNotEmpty,
      );
    });
  });

  // Phase 37 (D-37-01): a meeting that arrives by sync AFTER check-in carves
  // today's meal exactly as check-in would have, and Work keeps yielding to
  // the meal as well as to the meeting.
  group('a synced meeting carves a meal; Work yields to both (Phase 37)', () {
    final work9to5 = CommitmentBlock(
      id: 'workblock',
      name: 'Work',
      daysOfWeek: const [1, 2, 3, 4, 5],
      startMinutes: 9 * 60,
      endMinutes: 17 * 60,
    );
    final lunch = CommitmentBlock(
      id: 'lunch',
      name: 'Lunch',
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      startMinutes: 12 * 60,
      endMinutes: 13 * 60,
      kind: CommitmentBlock.kindLunch,
    );

    Future<ScheduleNotifier> checkedIn() async {
      final generated = ScheduleGeneratorService().generate(
        goals: const [],
        blocks: [work9to5, lunch],
        moodIndex: 3,
        date: todayDate,
      );
      final (notifier, _) = await make(chunks: generated);
      return notifier;
    }

    test('a 12:30-13:30 meeting leaves lunch 12:00-12:30 and Work under '
        'neither', () async {
      final notifier = await checkedIn();
      await notifier.applyCalendarSync([
        work9to5,
        lunch,
        calendarBlock('cal', 750, 810),
      ]);
      final chunks = notifier.todaySchedule!.chunks;
      final meal = chunks.where((c) => c.commitmentId == 'lunch').toList();
      expect(meal, hasLength(1));
      expect(meal.single.chunkType, ChunkType.meal);
      expect(meal.single.anchoredStartMinutes, 720);
      expect(meal.single.durationMinutes, 30);
      expect(
        chunks.where(
          (c) => c.commitmentId == 'workblock' && overlaps(c, 720, 810),
        ),
        isEmpty,
      );
    });

    test('the meeting going away gives lunch its whole hour back', () async {
      final notifier = await checkedIn();
      await notifier.applyCalendarSync([
        work9to5,
        lunch,
        calendarBlock('cal', 750, 810),
      ]);
      await notifier.applyCalendarSync(
        [work9to5, lunch],
        removedCalendarBlockIds: {'cal'},
      );
      final chunks = notifier.todaySchedule!.chunks;
      final meal = chunks.where((c) => c.commitmentId == 'lunch').toList();
      expect(meal, hasLength(1));
      expect(meal.single.durationMinutes, 60);
      expect(
        chunks.where(
          (c) => c.commitmentId == 'workblock' && overlaps(c, 720, 780),
        ),
        isEmpty,
        reason: 'Work regains 13:00-13:30, not lunch',
      );
    });
  });
}
