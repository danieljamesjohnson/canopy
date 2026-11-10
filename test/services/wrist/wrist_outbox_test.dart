// Phase 38 — the wrist outbox and its replay.
//
// The spike: a Complete tapped on the wrist at 10:18 and replayed when the
// phone app next runs (here, 10:40) must leave the schedule exactly as a live
// phone tap at 10:18 would have — G-05 moves the following break using the
// tap time, not the replay time.

import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/data/repositories/completion_log_repository.dart';
import 'package:canopy/data/repositories/daily_schedule_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/services/wrist/wrist_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements DailyScheduleRepository {
  DailySchedule? stored;
  bool failSaves = false;
  @override
  Future<List<DailySchedule>> getAll() async => stored == null ? [] : [stored!];
  @override
  Future<DailySchedule?> getById(String id) async => stored;
  @override
  Future<void> save(DailySchedule schedule) async {
    if (failSaves) throw StateError('disk full');
    stored = schedule;
  }

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

const _ymd = '2026-11-10';

/// 10:00 work (60) · 11:00 break (10) · 11:10 work (30).
List<ScheduledChunk> _chunks() => [
  ScheduledChunk(
    id: 'w1',
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'g1',
    durationMinutes: 60,
    syntheticStartMinutes: 600,
  ),
  ScheduledChunk(
    id: 'b1',
    chunkTypeIndex: ChunkType.shortBreak.index,
    durationMinutes: 10,
    syntheticStartMinutes: 660,
  ),
  ScheduledChunk(
    id: 'w2',
    chunkTypeIndex: ChunkType.work.index,
    goalId: 'g1',
    durationMinutes: 30,
    syntheticStartMinutes: 670,
  ),
];

class _Rig {
  _Rig({required DateTime clock}) {
    repo.stored = DailySchedule(
      id: 's',
      dateYmd: _ymd,
      moodIndex: 3,
      chunks: _chunks(),
    );
    notifier = ScheduleNotifier(
      now: () => clock,
      repo: repo,
      logRepo: logs,
      goalRepo: _Goals(),
    );
  }

  final repo = _Repo();
  final logs = _Logs();
  late final ScheduleNotifier notifier;

  ScheduledChunk chunk(String id) =>
      notifier.todaySchedule!.chunks.firstWhere((c) => c.id == id);
}

WristAction _act(
  String id,
  String chunkId,
  WristActionKind kind,
  DateTime at, {
  String ymd = _ymd,
}) => WristAction(
  id: id,
  chunkId: chunkId,
  kind: kind,
  tappedAt: at,
  dateYmd: ymd,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tap = DateTime(2026, 11, 10, 10, 18);
  final replayClock = DateTime(2026, 11, 10, 10, 40);

  test('SPIKE: a replayed Complete moves the break exactly as a live tap at '
      'the same moment would', () async {
    final live = _Rig(clock: tap);
    await live.notifier.init();
    await live.notifier.markComplete('w1');

    final replayed = _Rig(clock: replayClock);
    await replayed.notifier.init();
    final store = InMemoryWristOutboxStore([
      _act('a1', 'w1', WristActionKind.complete, tap),
    ]);
    final result = await WristOutboxReplayer(
      store: store,
      schedule: replayed.notifier,
    ).drain();

    expect(result.applied.map((a) => a.id), ['a1']);
    // The live tap's G-05 result: the break starts at 10:18 and keeps its end.
    expect(live.chunk('b1').displayStartMinutes, 618);
    expect(live.chunk('b1').durationMinutes, 52);
    // The replay matches it field for field, not the 10:40 replay time
    // (which would give 640 / 30).
    expect(
      replayed.chunk('b1').displayStartMinutes,
      live.chunk('b1').displayStartMinutes,
    );
    expect(
      replayed.chunk('b1').durationMinutes,
      live.chunk('b1').durationMinutes,
    );
    expect(replayed.chunk('w1').isCompleted, isTrue);
    expect(replayed.logs.logs, hasLength(1));
    expect(await store.pending(), isEmpty);
  });

  test('a duplicate delivery logs once, and the duplicate is dropped as '
      'already resolved', () async {
    final rig = _Rig(clock: replayClock);
    await rig.notifier.init();
    final store = InMemoryWristOutboxStore([
      _act('a1', 'w1', WristActionKind.complete, tap),
      _act('a2', 'w1', WristActionKind.complete, tap),
    ]);
    final result = await WristOutboxReplayer(
      store: store,
      schedule: rig.notifier,
    ).drain();
    expect(rig.logs.logs, hasLength(1));
    expect(result.applied, hasLength(1));
    expect(result.dropped.values, [WristDropReason.alreadyResolved]);
    expect(await store.pending(), isEmpty);
  });

  test('two drains racing each other still apply an action once', () async {
    final rig = _Rig(clock: replayClock);
    await rig.notifier.init();
    final store = InMemoryWristOutboxStore([
      _act('a1', 'w1', WristActionKind.skip, tap),
    ]);
    final replayer = WristOutboxReplayer(store: store, schedule: rig.notifier);
    final results = await Future.wait([replayer.drain(), replayer.drain()]);
    expect(rig.logs.logs, hasLength(1));
    // Serialised: the second drain starts only after the first emptied the
    // store, so it sees nothing at all rather than re-judging the same action.
    expect(results[1].applied, isEmpty);
    expect(results[1].dropped, isEmpty);
  });

  test('a Skip after a Complete on the same chunk is dropped, oldest tap '
      'first regardless of queue order', () async {
    final rig = _Rig(clock: replayClock);
    await rig.notifier.init();
    final store = InMemoryWristOutboxStore([
      _act(
        'later',
        'w1',
        WristActionKind.skip,
        tap.add(const Duration(minutes: 1)),
      ),
      _act('first', 'w1', WristActionKind.complete, tap),
    ]);
    final result = await WristOutboxReplayer(
      store: store,
      schedule: rig.notifier,
    ).drain();
    expect(result.applied.map((a) => a.id), ['first']);
    expect(result.dropped, {'later': WristDropReason.alreadyResolved});
    expect(rig.chunk('w1').isCompleted, isTrue);
    expect(rig.chunk('w1').isSkipped, isFalse);
  });

  test('a break can be skipped from the wrist but never completed', () async {
    final rig = _Rig(clock: replayClock);
    await rig.notifier.init();
    final store = InMemoryWristOutboxStore([
      _act('c', 'b1', WristActionKind.complete, tap),
      _act(
        's',
        'b1',
        WristActionKind.skip,
        tap.add(const Duration(minutes: 1)),
      ),
    ]);
    final result = await WristOutboxReplayer(
      store: store,
      schedule: rig.notifier,
    ).drain();
    expect(result.dropped, {'c': WristDropReason.notAllowed});
    expect(result.applied.map((a) => a.id), ['s']);
    expect(rig.chunk('b1').isSkipped, isTrue);
    expect(rig.chunk('b1').isCompleted, isFalse);
  });

  test('taps against another day, or a chunk that no longer exists, are '
      'dropped and never touch today', () async {
    final rig = _Rig(clock: replayClock);
    await rig.notifier.init();
    final store = InMemoryWristOutboxStore([
      _act('old', 'w1', WristActionKind.complete, tap, ymd: '2026-11-09'),
      _act('gone', 'regenerated-away', WristActionKind.complete, tap),
    ]);
    final result = await WristOutboxReplayer(
      store: store,
      schedule: rig.notifier,
    ).drain();
    expect(result.dropped, {
      'old': WristDropReason.wrongDay,
      'gone': WristDropReason.chunkNotFound,
    });
    expect(rig.chunk('w1').isCompleted, isFalse);
    expect(rig.logs.logs, isEmpty);
    expect(await store.pending(), isEmpty);
  });

  test('with no schedule today every tap is dropped as wrong day', () async {
    final rig = _Rig(clock: DateTime(2026, 11, 11, 8));
    await rig.notifier.init(); // yesterday's schedule is cleared on load
    final store = InMemoryWristOutboxStore([
      _act('a', 'w1', WristActionKind.complete, tap),
    ]);
    final result = await WristOutboxReplayer(
      store: store,
      schedule: rig.notifier,
    ).drain();
    expect(result.dropped, {'a': WristDropReason.wrongDay});
  });

  test('an action whose apply fails stays queued for the next drain', () async {
    final rig = _Rig(clock: replayClock);
    await rig.notifier.init();
    rig.repo.failSaves = true;
    final store = InMemoryWristOutboxStore([
      _act('a', 'w1', WristActionKind.complete, tap),
    ]);
    final replayer = WristOutboxReplayer(store: store, schedule: rig.notifier);
    final first = await replayer.drain();
    expect(first.failed.map((a) => a.id), ['a']);
    expect(await store.pending(), hasLength(1));

    rig.repo.failSaves = false;
    final second = await replayer.drain();
    expect(second.applied.map((a) => a.id), ['a']);
    expect(rig.chunk('w1').isCompleted, isTrue);
    expect(await store.pending(), isEmpty);
  });

  group('WristAction JSON', () {
    test('round-trips', () {
      final a = _act('a', 'w1', WristActionKind.skip, tap);
      final back = WristAction.tryParse(a.toJson())!;
      expect(back.toJson(), a.toJson());
      expect(back.tappedAt, tap);
    });

    test('malformed input parses to null instead of throwing', () {
      final good = _act('a', 'w1', WristActionKind.skip, tap).toJson();
      for (final bad in <Object?>[
        null,
        'x',
        {...good, 'kind': 'defer'},
        {...good, 'id': ''},
        {...good, 'chunkId': null},
        {...good, 'tappedAt': '10:18'},
        {...good, 'dateYmd': 5},
      ]) {
        expect(WristAction.tryParse(bad), isNull, reason: '$bad');
      }
    });
  });
}
