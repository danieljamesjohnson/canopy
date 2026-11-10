// Phase 40 — the native outbox, as Dart sees it through canopy/watch.

import 'dart:convert';

import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/data/repositories/completion_log_repository.dart';
import 'package:canopy/data/repositories/daily_schedule_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/services/wrist/wrist_outbox.dart';
import 'package:canopy/services/wrist/wrist_outbox_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

const _channel = MethodChannel('canopy/watch');

/// Stands in for WatchBridge.swift's outbox directory.
class _NativeOutbox {
  final Map<String, String> files = {};

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          switch (call.method) {
            case 'outboxPending':
              return files.values.toList();
            case 'outboxRemove':
              files.remove(call.arguments as String);
              return null;
          }
          return null;
        });
  }

  void tap(String id, String chunkId, String kind, DateTime at) =>
      files[id] = jsonEncode({
        'id': id,
        'chunkId': chunkId,
        'kind': kind,
        'tappedAt': at.millisecondsSinceEpoch,
        'dateYmd': '2026-11-10',
      });
}

/// Delivers a call from "Swift" to Dart's handler on canopy/watch.
Future<void> _fromSwift(String method) async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    _channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _NativeOutbox native;
  late ScheduleNotifier schedule;
  late _Logs logs;
  late WristOutboxCoordinator coordinator;

  setUp(() async {
    native = _NativeOutbox()..install();
    logs = _Logs();
    final repo = _Repo()
      ..stored = DailySchedule(
        id: 's',
        dateYmd: '2026-11-10',
        moodIndex: 3,
        chunks: [
          for (final (id, start) in [('w1', 540), ('w2', 600)])
            ScheduledChunk(
              id: id,
              chunkTypeIndex: ChunkType.work.index,
              goalId: 'g',
              durationMinutes: 30,
              syntheticStartMinutes: start,
            ),
        ],
      );
    schedule = ScheduleNotifier(
      now: () => DateTime(2026, 11, 10, 9, 40),
      repo: repo,
      logRepo: logs,
      goalRepo: _Goals(),
    );
    await schedule.init();
    coordinator = WristOutboxCoordinator(
      replayer: WristOutboxReplayer(
        store: MethodChannelWristOutboxStore(),
        schedule: schedule,
      ),
    );
  });

  tearDown(() {
    coordinator.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  ScheduledChunk chunk(String id) =>
      schedule.todaySchedule!.chunks.firstWhere((c) => c.id == id);

  test('taps queued while the app was not running are applied at start and '
      'their files deleted', () async {
    native.tap('a1', 'w1', 'complete', DateTime(2026, 11, 10, 9, 20));
    coordinator.start();
    await pumpEventQueue();
    expect(chunk('w1').isCompleted, isTrue);
    expect(native.files, isEmpty);
  });

  test('a tap arriving while the engine is alive is applied when Swift says '
      'outboxChanged', () async {
    coordinator.start();
    await pumpEventQueue();
    native.tap('a2', 'w2', 'skip', DateTime(2026, 11, 10, 9, 41));
    await _fromSwift('outboxChanged');
    await pumpEventQueue();
    expect(chunk('w2').isSkipped, isTrue);
    expect(native.files, isEmpty);
  });

  test('a tap waiting when the app resumes is applied on resume', () async {
    coordinator.start();
    await pumpEventQueue();
    native.tap('a3', 'w2', 'skip', DateTime(2026, 11, 10, 9, 41));
    coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(chunk('w2').isSkipped, isTrue);
  });

  test('a corrupt file is ignored instead of wedging the queue', () async {
    native.files['bad'] = '{not json';
    native.files['worse'] = jsonEncode({'id': 'worse'});
    native.tap('ok', 'w1', 'complete', DateTime(2026, 11, 10, 9, 20));
    coordinator.start();
    await pumpEventQueue();
    expect(chunk('w1').isCompleted, isTrue);
    expect(logs.logs, hasLength(1));
  });

  test(
    'with no bridge (web, Android, desktop) the store is simply empty',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
      final store = MethodChannelWristOutboxStore();
      expect(await store.pending(), isEmpty);
      await store.remove('x');
    },
  );
}
