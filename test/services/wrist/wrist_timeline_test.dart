// Phase 38 — the wrist timeline.
//
// The contract that matters: for EVERY minute of the day, the entry the watch
// would pick (the last one whose `at` has passed) says exactly what
// resolveNowState — the Today screen's own function — says at that minute.
// If that holds, the phone and the watch cannot disagree.

import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/screens/today/now_state.dart';
import 'package:canopy/services/wrist/wrist_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

const _ymd = '2026-11-10';
final _now = DateTime(2026, 11, 10, 7, 30);

ScheduledChunk _work(
  String id,
  int start,
  int dur, {
  String? goalId = 'g1',
  String rationale = 'Habit',
}) => ScheduledChunk(
  id: id,
  chunkTypeIndex: ChunkType.work.index,
  goalId: goalId,
  durationMinutes: dur,
  syntheticStartMinutes: start,
  rationale: rationale,
);

ScheduledChunk _break(String id, int start, int dur, {bool long = false}) =>
    ScheduledChunk(
      id: id,
      chunkTypeIndex: (long ? ChunkType.longBreak : ChunkType.shortBreak).index,
      durationMinutes: dur,
      syntheticStartMinutes: start,
    );

ScheduledChunk _meeting(String id, int start, int dur, String name) =>
    ScheduledChunk(
      id: id,
      chunkTypeIndex: ChunkType.work.index,
      durationMinutes: dur,
      anchoredStartMinutes: start,
      rationale: name,
      commitmentId: 'c-$id',
    );

/// 9:00 Deep work (50) · 9:50 break (10) · 10:00 Standup (60) · gap ·
/// 11:40 Deep work (30) · done at 12:10.
List<ScheduledChunk> _day() => [
  _work('w1', 540, 50),
  _break('b1', 590, 10),
  _meeting('m1', 600, 60, 'Standup'),
  _work('w2', 700, 30),
];

DailySchedule _schedule(List<ScheduledChunk> chunks, {String ymd = _ymd}) =>
    DailySchedule(id: 's', dateYmd: ymd, moodIndex: 3, chunks: chunks);

WristTimeline _build(List<ScheduledChunk> chunks, {DateTime? now}) =>
    buildWristTimeline(
      schedule: _schedule(chunks),
      goalName: (id) => id == 'g1' ? 'Deep work' : null,
      now: now ?? _now,
    );

WristEntry _pick(WristTimeline t, DateTime at) =>
    t.entries.lastWhere((e) => !e.at.isAfter(at));

/// (state, currentId, nextId) as resolveNowState reports it.
(WristStateKind, String?, String?) _phone(NowState s) => switch (s) {
  PreStart(:final firstChunk) => (WristStateKind.preStart, null, firstChunk.id),
  Active(:final current, :final next) => (
    WristStateKind.active,
    current.id,
    next?.id,
  ),
  Overdue(:final overdue, :final next) => (
    WristStateKind.overdue,
    overdue.id,
    next?.id,
  ),
  GapBeforeNext(:final next) => (WristStateKind.gap, null, next.id),
  DayComplete() => (WristStateKind.dayComplete, null, null),
};

(WristStateKind, String?, String?) _wrist(WristEntry e) =>
    (e.state, e.current?.id, e.next?.id);

void main() {
  test('the day reads as one entry per change, ending in Day complete and '
      'then "no schedule" at the next midnight', () {
    final t = _build(_day());
    expect(t.entries.map(_wrist).toList(), [
      (WristStateKind.preStart, null, 'w1'),
      (WristStateKind.active, 'w1', 'b1'),
      (WristStateKind.active, 'b1', 'm1'),
      (WristStateKind.active, 'm1', 'w2'),
      (WristStateKind.overdue, 'm1', 'w2'),
      (WristStateKind.active, 'w2', null),
      (WristStateKind.dayComplete, null, null),
      (WristStateKind.noSchedule, null, null),
    ]);
    expect(t.entries.map((e) => (e.at.day, e.at.hour, e.at.minute)).toList(), [
      (10, 0, 0),
      (10, 9, 0),
      (10, 9, 50),
      (10, 10, 0),
      (10, 11, 0),
      (10, 11, 40),
      (10, 12, 10),
      (11, 0, 0),
    ]);
  });

  test('for every minute of the day the watch shows what the Today screen '
      'shows (same state, same chunks)', () {
    // Some resolved chunks too, so GapBeforeNext and resolved-skipping paths
    // are exercised, not just the happy path.
    final chunks = _day();
    chunks[0].isCompleted = true; // w1 done early → gap until the break
    chunks[2].isSkipped = true; // standup skipped
    for (final variant in [_day(), chunks]) {
      final t = _build(variant);
      for (var m = 0; m < 24 * 60; m++) {
        final at = DateTime(2026, 11, 10, 0, m);
        final phone = _phone(resolveNowState(chunks: variant, now: () => at));
        expect(_wrist(_pick(t, at)), phone, reason: 'minute $m');
      }
    }
  });

  test('boundaries where nothing visible changes collapse into one entry', () {
    // w1 done, standup skipped: 10:00 (the break ends) and 11:00 (the skipped
    // standup's window ends) both read "gap, next w2", so only 10:00 stays.
    final chunks = _day();
    chunks[0].isCompleted = true;
    chunks[2].isSkipped = true;
    final t = _build(chunks);
    expect(t.entries.map(_wrist).toList(), [
      (WristStateKind.preStart, null, 'w1'),
      (WristStateKind.gap, null, 'b1'),
      (WristStateKind.active, 'b1', 'w2'),
      (WristStateKind.gap, null, 'w2'),
      (WristStateKind.active, 'w2', null),
      (WristStateKind.dayComplete, null, null),
      (WristStateKind.noSchedule, null, null),
    ]);
    expect(t.entries[3].at, DateTime(2026, 11, 10, 10, 0));
  });

  test('a resolved chunk opens a gap rather than showing as Now', () {
    final chunks = _day()..[0].isCompleted = true;
    final t = _build(chunks);
    expect(_wrist(_pick(t, DateTime(2026, 11, 10, 9, 5))), (
      WristStateKind.gap,
      null,
      'b1',
    ));
  });

  test('titles match the Today screen and actions match its gates', () {
    final t = _build(_day());
    final at9 = _pick(t, DateTime(2026, 11, 10, 9, 10));
    expect(at9.current!.title, 'Deep work');
    expect(at9.current!.kind, WristChunkKind.work);
    expect(at9.current!.canComplete, isTrue);
    expect(at9.current!.canSkip, isTrue);
    expect(at9.next!.title, 'Short break');
    expect(at9.next!.kind, WristChunkKind.shortBreak);
    // Breaks are skip-only, exactly like the live row (showComplete: !isBreak).
    expect(at9.next!.canComplete, isFalse);
    expect(at9.next!.canSkip, isTrue);

    final at10 = _pick(t, DateTime(2026, 11, 10, 10, 5));
    expect(at10.current!.title, 'Standup');
    expect(at10.current!.kind, WristChunkKind.commitment);
    expect(at10.current!.canComplete, isTrue);

    // A goal the phone no longer knows falls back to the rationale, as on
    // the phone.
    final orphan = _build([_work('w', 540, 30, goalId: 'gone')]);
    expect(orphan.entries[1].current!.title, 'Habit');
  });

  test('a resolved chunk offers no action', () {
    final chunks = _day()..[2].isSkipped = true;
    final t = _build(chunks);
    final m1 = t.entries
        .expand((e) => [e.current, e.next])
        .whereType<WristChunk>()
        .where((c) => c.id == 'm1');
    // Skipped m1 is never current or next any more; if it appears at all it
    // must be inert.
    for (final c in m1) {
      expect(c.canComplete || c.canSkip, isFalse);
    }
  });

  test('chunk instants are absolute and carry the local wall-clock time', () {
    final t = _build(_day());
    final w1 = t.entries[1].current!;
    expect(w1.startAt, DateTime(2026, 11, 10, 9, 0));
    expect(w1.endAt, DateTime(2026, 11, 10, 9, 50));
  });

  test('on a DST-change day a 9:00 chunk still starts at 9:00 local', () {
    // 2026-03-08 is the US spring-forward day. Under TZ=America/Chicago a
    // Duration-based add from midnight would land at 10:00.
    final t = buildWristTimeline(
      schedule: _schedule([_work('w', 540, 30)], ymd: '2026-03-08'),
      goalName: (_) => 'Deep work',
      now: DateTime(2026, 3, 8, 7),
    );
    final w = t.entries[1].current!;
    expect((w.startAt.hour, w.startAt.minute), (9, 0));
    expect(t.entries.last.at, DateTime(2026, 3, 9));
  });

  test('state is judged at the wall-clock minute even inside a DST gap', () {
    // Only discriminating under a US time zone (the suite is run with
    // TZ=America/Chicago for this): 2:30 does not exist on 2026-03-08, so a
    // LOCAL DateTime for it normalises to 3:30, past this chunk's end. The
    // wall-clock minute itself must still read "active".
    final t = buildWristTimeline(
      schedule: _schedule([_work('w', 150, 30)], ymd: '2026-03-08'),
      goalName: (_) => 'Deep work',
      now: DateTime(2026, 3, 8, 1),
    );
    expect(_wrist(t.entries[1]), (WristStateKind.active, 'w', null));
  });

  test('no schedule, or yesterday\'s, yields a single "no schedule" entry', () {
    for (final s in [null, _schedule(_day(), ymd: '2026-11-09')]) {
      final t = buildWristTimeline(
        schedule: s,
        goalName: (_) => null,
        now: _now,
      );
      expect(t.dateYmd, _ymd);
      expect(t.entries.map(_wrist).toList(), [
        (WristStateKind.noSchedule, null, null),
      ]);
      expect(t.entries.single.at, DateTime(2026, 11, 10));
    }
  });

  test('JSON is versioned and uses epoch milliseconds', () {
    final json = _build(_day()).toJson();
    expect(json['schemaVersion'], wristTimelineSchemaVersion);
    expect(json['dateYmd'], _ymd);
    expect(json['generatedAt'], _now.millisecondsSinceEpoch);
    final entries = json['entries']! as List;
    final second = entries[1] as Map;
    expect(second['state'], 'active');
    expect(second['at'], DateTime(2026, 11, 10, 9).millisecondsSinceEpoch);
    final current = second['current']! as Map;
    expect(current, {
      'id': 'w1',
      'kind': 'work',
      'title': 'Deep work',
      'startAt': DateTime(2026, 11, 10, 9).millisecondsSinceEpoch,
      'endAt': DateTime(2026, 11, 10, 9, 50).millisecondsSinceEpoch,
      'canComplete': true,
      'canSkip': true,
    });
  });
}
