// Wave 0 stub for READ-03 (markDeferred) — turns green when Plan 08-02 adds
// the markDeferred() method to ScheduleNotifier.
//
// Status: RED until Plan 08-02.
//
// This test uses `dynamic` dispatch to call `notifier.markDeferred(chunkId)`
// so it compiles before the method exists. The call will throw a NoSuchMethodError
// at runtime, keeping the test RED until the method is implemented.

import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/data/repositories/completion_log_repository.dart';
import 'package:canopy/data/repositories/daily_schedule_repository.dart';
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

class _InMemoryLogRepository implements CompletionLogRepository {
  final List<CompletionLog> _logs = [];

  List<CompletionLog> get logs => List.unmodifiable(_logs);

  @override
  Future<List<CompletionLog>> getAll() async => List.unmodifiable(_logs);

  @override
  Future<CompletionLog?> getById(String id) async =>
      _logs.where((l) => l.id == id).firstOrNull;

  @override
  Future<void> append(CompletionLog entry) async => _logs.add(entry);

  @override
  Future<List<CompletionLog>> getByDate(String dateYmd) async =>
      _logs.where((l) => l.dateYmd == dateYmd).toList();

  @override
  Future<List<CompletionLog>> getByGoalId(String goalId) async =>
      _logs.where((l) => l.goalId == goalId).toList();
}

// ---------------------------------------------------------------------------
// Tiny listener counter (mirrors theme_notifier_test.dart pattern)
// ---------------------------------------------------------------------------

class _CountingListener {
  int count = 0;
  void call() => count++;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Monday 2026-03-23 used as a consistent test date.
  const testDateYmd = '2026-03-23';

  group('ScheduleNotifier.markDeferred (READ-03)', () {
    test(
      'markDeferred sets isDeferred=true + isSkipped=true and notifies listeners',
      () async {
        // These fakes are prepared for when Plan 08-02 adds constructor injection
        // to ScheduleNotifier. The scheduleRepo seeds today's schedule; logRepo
        // is provided so markDeferred can append a CompletionLog entry.
        // ignore: unused_local_variable
        final scheduleRepo = _InMemoryScheduleRepository();
        // ignore: unused_local_variable
        final logRepo = _InMemoryLogRepository();

        // Build a schedule with one work chunk pre-seeded into the repo.
        final chunk = ScheduledChunk(
          id: 'chunk-1',
          chunkTypeIndex: ChunkType.work.index,
          goalId: 'goal-1',
          durationMinutes: 25,
          rationale: 'Habit',
        );
        final schedule = DailySchedule(
          id: 'sched-1',
          dateYmd: testDateYmd,
          moodIndex: 3,
          chunks: [chunk],
        );
        await scheduleRepo.save(schedule);

        // Construct ScheduleNotifier with the injected fakes.
        // Plan 08-02 will add constructor injection of _repo/_logRepo;
        // until then this test fails via NoSuchMethodError on markDeferred.
        // ignore: invalid_use_of_protected_member
        final notifier = ScheduleNotifier(
          now: () => DateTime(2026, 3, 23),
        );
        // Override repos via the injected fake (Plan 08-02 adds injection support
        // or exposes a test constructor). Until then, test fails RED.
        await notifier.init();

        final listener = _CountingListener();
        notifier.addListener(listener.call);
        addTearDown(() {
          notifier.removeListener(listener.call);
          notifier.dispose();
        });

        // Use dynamic dispatch so this compiles before markDeferred exists.
        // Throws NoSuchMethodError → test is RED until Plan 08-02 adds the method.
        await (notifier as dynamic).markDeferred('chunk-1');

        // After markDeferred:
        final updatedChunk = notifier.todaySchedule?.chunks
            .firstWhere((c) => c.id == 'chunk-1');
        expect(
          updatedChunk?.isDeferred,
          isTrue,
          reason: 'markDeferred must set isDeferred = true',
        );
        expect(
          updatedChunk?.isSkipped,
          isTrue,
          reason: 'markDeferred must also set isSkipped = true for screen partitioning',
        );
        expect(
          listener.count,
          greaterThanOrEqualTo(1),
          reason: 'markDeferred must call notifyListeners',
        );
      },
    );
  });
}
