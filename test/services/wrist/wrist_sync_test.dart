// Phase 39 — the phone keeps the watch's copy of today in step.

import 'dart:convert';

import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/data/repositories/completion_log_repository.dart';
import 'package:canopy/data/repositories/daily_schedule_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/services/wrist/wrist_sync.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements DailyScheduleRepository {
  DailySchedule? stored;
  @override
  Future<List<DailySchedule>> getAll() async => stored == null ? [] : [stored!];
  @override
  Future<DailySchedule?> getById(String id) async => stored;
  @override
  Future<void> save(DailySchedule schedule) async => stored = schedule;
  @override
  Future<void> delete(String id) async => stored = null;
  @override
  Future<DailySchedule?> getByDate(String dateYmd) async => stored;
  @override
  Future<DailySchedule?> getTodaysSchedule() async => stored;
}

class _Goals implements GoalRepository {
  final Map<String, Goal> goals = {};
  @override
  Future<List<Goal>> getAll() async => goals.values.toList();
  @override
  Future<Goal?> getById(String id) async => goals[id];
  @override
  Future<void> save(Goal goal) async => goals[goal.id] = goal;
  @override
  Future<void> delete(String id) async => goals.remove(id);
  @override
  Future<List<Goal>> getActive() async => goals.values.toList();
}

class _Logs implements CompletionLogRepository {
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

class _Transport implements WristTransport {
  final List<Map<String, Object?>> sent = [];
  @override
  Future<void> sendTimeline(String json) async =>
      sent.add(jsonDecode(json) as Map<String, Object?>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var clock = DateTime(2026, 11, 10, 9, 10);

  late _Repo repo;
  late _Goals goalRepo;
  late ScheduleNotifier schedule;
  late GoalsNotifier goals;
  late _Transport transport;
  late WristSync sync;

  setUp(() async {
    clock = DateTime(2026, 11, 10, 9, 10);
    repo = _Repo()
      ..stored = DailySchedule(
        id: 's',
        dateYmd: '2026-11-10',
        moodIndex: 3,
        chunks: [
          ScheduledChunk(
            id: 'w1',
            chunkTypeIndex: ChunkType.work.index,
            goalId: 'g1',
            durationMinutes: 30,
            syntheticStartMinutes: 540,
          ),
        ],
      );
    goalRepo = _Goals()
      ..goals['g1'] = Goal(
        id: 'g1',
        name: 'Deep work',
        goalTypeIndex: GoalType.timeTarget.index,
      );
    schedule = ScheduleNotifier(
      now: () => clock,
      repo: repo,
      logRepo: _Logs(),
      goalRepo: goalRepo,
    );
    goals = GoalsNotifier(repository: goalRepo);
    await schedule.init();
    await goals.loadGoals();
    transport = _Transport();
    sync = WristSync(
      schedule: schedule,
      goals: goals,
      transport: transport,
      now: () => clock,
      debounce: const Duration(milliseconds: 10),
    );
  });

  tearDown(() => sync.dispose());

  Map<String, Object?> activeChunk(Map<String, Object?> timeline) {
    final entries = (timeline['entries']! as List).cast<Map>();
    return entries.firstWhere((e) => e['state'] == 'active')['current']
        as Map<String, Object?>;
  }

  test('start sends today once, with real titles', () async {
    sync.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.sent, hasLength(1));
    expect(activeChunk(transport.sent.single)['title'], 'Deep work');
  });

  test('a Complete on the phone sends a timeline in which the chunk is no '
      'longer actionable', () async {
    sync.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await schedule.markComplete('w1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.sent, hasLength(2));
    final states = (transport.sent.last['entries']! as List)
        .cast<Map>()
        .map((e) => e['state'])
        .toList();
    expect(states, isNot(contains('active')));
  });

  test('renaming a goal re-sends with the new title', () async {
    sync.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final g = goalRepo.goals['g1']!..name = 'Writing';
    await goals.saveGoal(g);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.sent, hasLength(2));
    expect(activeChunk(transport.sent.last)['title'], 'Writing');
  });

  test('notifications that change nothing send nothing', () async {
    sync.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // A minute later: generatedAt differs, nothing the watch shows does.
    clock = clock.add(const Duration(minutes: 1));
    await schedule.reloadToday();
    await goals.loadGoals();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.sent, hasLength(1));
  });

  test('a burst of changes is debounced into one send', () async {
    sync.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final g = goalRepo.goals['g1']!;
    for (final name in ['A', 'B', 'C']) {
      g.name = name;
      await goals.saveGoal(g);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(transport.sent, hasLength(2));
    expect(activeChunk(transport.sent.last)['title'], 'C');
  });

  test('the production transport is silent where no bridge exists', () async {
    // No handler registered for canopy/watch in the test binding →
    // MissingPluginException, which must not escape.
    await const MethodChannelWristTransport().sendTimeline('{}');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelWristTransport.channel, (
          call,
        ) async {
          throw PlatformException(code: 'boom');
        });
    await const MethodChannelWristTransport().sendTimeline('{}');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelWristTransport.channel, null);
  });
}
