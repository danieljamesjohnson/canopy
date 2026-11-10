import '../../data/models/scheduled_chunk.dart';
import '../../providers/schedule_notifier.dart';

/// What the user tapped on the wrist.
enum WristActionKind { complete, skip }

/// One queued wrist tap. It carries the tap's own time because G-05 (break
/// absorption) reads the clock: a Complete tapped at 10:18 and replayed at
/// 10:40 must move the next break as it would have at 10:18.
///
/// [dateYmd] is the day of the snapshot the watch was showing. A tap from
/// another day is dropped on replay, never applied to today's schedule.
class WristAction {
  const WristAction({
    required this.id,
    required this.chunkId,
    required this.kind,
    required this.tappedAt,
    required this.dateYmd,
  });

  final String id;
  final String chunkId;
  final WristActionKind kind;
  final DateTime tappedAt;
  final String dateYmd;

  Map<String, Object?> toJson() => {
    'id': id,
    'chunkId': chunkId,
    'kind': kind.name,
    'tappedAt': tappedAt.millisecondsSinceEpoch,
    'dateYmd': dateYmd,
  };

  /// Parses an action written by the watch or the native bridge. Returns null
  /// for anything malformed, so one bad file can never wedge the outbox.
  static WristAction? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final chunkId = json['chunkId'];
    final kindName = json['kind'];
    final tappedAt = json['tappedAt'];
    final dateYmd = json['dateYmd'];
    if (id is! String || id.isEmpty) return null;
    if (chunkId is! String || chunkId.isEmpty) return null;
    if (tappedAt is! num) return null;
    if (dateYmd is! String) return null;
    final kind = WristActionKind.values
        .where((k) => k.name == kindName)
        .firstOrNull;
    if (kind == null) return null;
    return WristAction(
      id: id,
      chunkId: chunkId,
      kind: kind,
      tappedAt: DateTime.fromMillisecondsSinceEpoch(tappedAt.toInt()),
      dateYmd: dateYmd,
    );
  }
}

/// Where queued taps wait. On iOS (Phase 40) this is a native directory the
/// Swift WCSession delegate writes into before Dart is even running; the
/// replay below never writes Hive off the main isolate.
abstract class WristOutboxStore {
  /// Every action still waiting, in any order.
  Future<List<WristAction>> pending();

  /// Removes an action once it has been applied or deliberately dropped.
  Future<void> remove(String id);
}

class InMemoryWristOutboxStore implements WristOutboxStore {
  InMemoryWristOutboxStore([Iterable<WristAction> actions = const []])
    : _actions = [...actions];

  final List<WristAction> _actions;

  void add(WristAction a) => _actions.add(a);

  @override
  Future<List<WristAction>> pending() async => List.of(_actions);

  @override
  Future<void> remove(String id) async =>
      _actions.removeWhere((a) => a.id == id);
}

/// Why an action was dropped instead of applied. Recorded so a replay is
/// explainable rather than silently lossy.
enum WristDropReason {
  /// No schedule for today, or the tap was made against another day's.
  wrongDay,

  /// The chunk is gone, e.g. the user re-checked-in on the phone after the
  /// tap, which regenerates every chunk id.
  chunkNotFound,

  /// The chunk is already completed or skipped (a duplicate, or the phone
  /// resolved it first).
  alreadyResolved,

  /// Complete on a break, or anything on a meal, which the Today screen never
  /// offers either.
  notAllowed,
}

class WristReplayResult {
  final List<WristAction> applied = [];
  final Map<String, WristDropReason> dropped = {};
  final List<WristAction> failed = [];
}

/// Replays queued wrist taps through the same `markComplete`/`markSkipped`
/// paths a phone tap takes, oldest tap first, on the main isolate.
///
/// Idempotent: an action is removed from the store once applied or dropped,
/// and a chunk that is already resolved is never resolved again, so a
/// duplicate delivery cannot log a second CompletionLog. An action whose
/// apply throws stays in the store for the next drain.
///
/// Calls are serialised: a drain requested while one is running waits for it
/// and then runs, so two lifecycle events cannot replay the same action twice.
class WristOutboxReplayer {
  WristOutboxReplayer({required this.store, required this.schedule});

  final WristOutboxStore store;
  final ScheduleNotifier schedule;

  Future<void> _tail = Future.value();

  Future<WristReplayResult> drain() {
    final run = _tail.then((_) => _drainOnce());
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<WristReplayResult> _drainOnce() async {
    final result = WristReplayResult();
    final actions = await store.pending()
      ..sort((a, b) => a.tappedAt.compareTo(b.tappedAt));

    for (final action in actions) {
      final reason = _whyNot(action);
      if (reason != null) {
        result.dropped[action.id] = reason;
        await store.remove(action.id);
        continue;
      }
      try {
        switch (action.kind) {
          case WristActionKind.complete:
            await schedule.markComplete(action.chunkId, at: action.tappedAt);
          case WristActionKind.skip:
            await schedule.markSkipped(action.chunkId);
        }
        result.applied.add(action);
        await store.remove(action.id);
      } catch (_) {
        result.failed.add(action);
      }
    }
    return result;
  }

  WristDropReason? _whyNot(WristAction action) {
    final today = schedule.todaySchedule;
    if (!schedule.hasScheduleToday ||
        today == null ||
        today.dateYmd != action.dateYmd) {
      return WristDropReason.wrongDay;
    }
    final chunk = today.chunks.where((c) => c.id == action.chunkId).firstOrNull;
    if (chunk == null) return WristDropReason.chunkNotFound;
    if (chunk.isCompleted || chunk.isSkipped) {
      return WristDropReason.alreadyResolved;
    }
    if (action.kind == WristActionKind.complete &&
        chunk.chunkType != ChunkType.work) {
      return WristDropReason.notAllowed;
    }
    // A meal is never tracked (Phase 37, D-37-03): not even Skip.
    if (chunk.chunkType == ChunkType.meal) return WristDropReason.notAllowed;
    return null;
  }
}
