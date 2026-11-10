import 'package:intl/intl.dart';

import '../../data/models/daily_schedule.dart';
import '../../data/models/scheduled_chunk.dart';
import '../../screens/today/now_state.dart';
import '../../utils/chunk_title.dart';

/// Bumped whenever the JSON shape below changes incompatibly. The watch
/// refuses a snapshot whose version it does not know and says "update
/// Canopy" instead of guessing.
const int wristTimelineSchemaVersion = 1;

/// What the wrist shows at one moment. Mirrors [NowState] one-to-one, plus
/// [noSchedule] for "no schedule for today — check in on your phone", which is
/// what the phone shows too (`hasScheduleToday == false`).
enum WristStateKind { noSchedule, preStart, active, overdue, gap, dayComplete }

/// The watch styles a chunk by kind. A commitment is a work-typed chunk that
/// came from a commitment block (a meeting), not from a goal. A meal
/// (Phase 37) is its own kind and is never actionable (D-37-03).
enum WristChunkKind { work, commitment, shortBreak, longBreak, meal }

/// One chunk as the watch sees it. Times are absolute instants, computed once
/// here, so Swift never re-derives a time from minutes-of-day (research
/// pitfall 3: DST and travel days).
class WristChunk {
  const WristChunk({
    required this.id,
    required this.kind,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.canComplete,
    required this.canSkip,
  });

  final String id;
  final WristChunkKind kind;
  final String title;
  final DateTime startAt;
  final DateTime endAt;

  /// Same gate as the Today screen's live row: work and commitments can be
  /// completed, breaks cannot (`showComplete: !isBreak`), and a meal offers
  /// nothing at all (D-37-03). Nothing resolved offers an action.
  final bool canComplete;
  final bool canSkip;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'startAt': startAt.millisecondsSinceEpoch,
    'endAt': endAt.millisecondsSinceEpoch,
    'canComplete': canComplete,
    'canSkip': canSkip,
  };
}

/// "From [at] on, show this." The watch picks the last entry whose [at] has
/// passed — that is the only logic it runs.
class WristEntry {
  const WristEntry({
    required this.at,
    required this.state,
    this.current,
    this.next,
  });

  final DateTime at;
  final WristStateKind state;

  /// The chunk the state is about: the running chunk for [active], the late
  /// one for [overdue]. Null for every other state.
  final WristChunk? current;

  /// What comes after. For [preStart] and [gap] this is the upcoming chunk.
  final WristChunk? next;

  Map<String, Object?> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'state': state.name,
    'current': current?.toJson(),
    'next': next?.toJson(),
  };
}

class WristTimeline {
  const WristTimeline({
    required this.dateYmd,
    required this.generatedAt,
    required this.utcOffsetMinutes,
    required this.entries,
  });

  final String dateYmd;
  final DateTime generatedAt;

  /// The phone's UTC offset when this was built. The watch compares it with
  /// its own and says "open Canopy" on a mismatch (a travel day).
  final int utcOffsetMinutes;
  final List<WristEntry> entries;

  Map<String, Object?> toJson() => {
    'schemaVersion': wristTimelineSchemaVersion,
    'dateYmd': dateYmd,
    'generatedAt': generatedAt.millisecondsSinceEpoch,
    'utcOffsetMinutes': utcOffsetMinutes,
    'entries': [for (final e in entries) e.toJson()],
  };
}

/// Builds the day's wrist timeline from [schedule].
///
/// The state at every entry comes from [resolveNowState] — the exact function
/// the Today screen renders from — so the phone and the watch cannot disagree
/// about what is happening now. [resolveNowState] only changes its answer
/// when the clock crosses a chunk's start or end, so sampling it at local
/// midnight and at every chunk boundary captures every change.
///
/// The timeline always:
/// - starts at local midnight of the schedule's day (so the watch always has
///   an entry in the past to show);
/// - reaches [WristStateKind.dayComplete] after the last chunk; and
/// - ends with [WristStateKind.noSchedule] at the next local midnight, which
///   is when the phone itself stops showing this schedule (LOOP-02,
///   `ScheduleNotifier._resetIfDayChanged`). The watch never holds
///   yesterday's last chunk overnight.
///
/// A null schedule, or one for another day, yields a single
/// [WristStateKind.noSchedule] entry at today's midnight.
///
/// [goalName] resolves a goal id to its name (the phone's goals list); the
/// title comes from [chunkReferenceTitle], shared with the Today screen.
WristTimeline buildWristTimeline({
  required DailySchedule? schedule,
  required String? Function(String goalId) goalName,
  required DateTime now,
}) {
  final todayYmd = DateFormat('yyyy-MM-dd').format(now);
  final offset = now.timeZoneOffset.inMinutes;

  if (schedule == null || schedule.dateYmd != todayYmd) {
    return WristTimeline(
      dateYmd: todayYmd,
      generatedAt: now,
      utcOffsetMinutes: offset,
      entries: [
        WristEntry(
          at: DateTime(now.year, now.month, now.day),
          state: WristStateKind.noSchedule,
        ),
      ],
    );
  }

  final day = DateTime.parse(schedule.dateYmd);
  // A LOCAL wall-clock instant for minutes-from-midnight. The DateTime
  // constructor normalises minutes past 59 by wall clock, so 9:00 is 9:00
  // local even on a DST-change day, which `.add(Duration)` would get wrong.
  DateTime instant(int minutes) =>
      DateTime(day.year, day.month, day.day, 0, minutes);

  WristChunk wrist(ScheduledChunk c) {
    final start = c.displayStartMinutes!;
    final isBreak = c.chunkType != ChunkType.work;
    final isMeal = c.chunkType == ChunkType.meal;
    final unresolved = !c.isCompleted && !c.isSkipped;
    final WristChunkKind kind;
    switch (c.chunkType) {
      case ChunkType.shortBreak:
        kind = WristChunkKind.shortBreak;
      case ChunkType.longBreak:
        kind = WristChunkKind.longBreak;
      case ChunkType.meal:
        kind = WristChunkKind.meal;
      case ChunkType.work:
        kind = c.commitmentId != null
            ? WristChunkKind.commitment
            : WristChunkKind.work;
    }
    final goal = c.goalId == null ? null : goalName(c.goalId!);
    return WristChunk(
      id: c.id,
      kind: kind,
      title: chunkReferenceTitle(c, goal),
      startAt: instant(start),
      endAt: instant(start + c.durationMinutes),
      canComplete: unresolved && !isBreak,
      canSkip: unresolved && !isMeal,
    );
  }

  // Every minute at which resolveNowState's answer can change. Boundaries at
  // or past midnight belong to the next day, when the schedule is no longer
  // shown at all (the trailing noSchedule entry covers them).
  final boundaries = <int>{0};
  for (final c in schedule.chunks) {
    final start = c.displayStartMinutes;
    if (start == null) continue;
    boundaries
      ..add(start)
      ..add(start + c.durationMinutes);
  }
  final sorted = boundaries.where((m) => m >= 0 && m < 24 * 60).toList()
    ..sort();

  final entries = <WristEntry>[];
  for (final m in sorted) {
    // resolveNowState reads only hour*60+minute of the DateTime it is given.
    // A UTC DateTime carries the wall-clock fields verbatim, so this is
    // minute [m] even inside a DST gap, where a local DateTime would be
    // normalised to a different hour.
    final state = resolveNowState(
      chunks: schedule.chunks,
      now: () => DateTime.utc(day.year, day.month, day.day, 0, m),
    );
    final entry = switch (state) {
      PreStart(:final firstChunk) => WristEntry(
        at: instant(m),
        state: WristStateKind.preStart,
        next: wrist(firstChunk),
      ),
      Active(:final current, :final next) => WristEntry(
        at: instant(m),
        state: WristStateKind.active,
        current: wrist(current),
        next: next == null ? null : wrist(next),
      ),
      Overdue(:final overdue, :final next) => WristEntry(
        at: instant(m),
        state: WristStateKind.overdue,
        current: wrist(overdue),
        next: next == null ? null : wrist(next),
      ),
      GapBeforeNext(:final next) => WristEntry(
        at: instant(m),
        state: WristStateKind.gap,
        next: wrist(next),
      ),
      DayComplete() => WristEntry(
        at: instant(m),
        state: WristStateKind.dayComplete,
      ),
    };
    if (entries.isNotEmpty && _sameDisplay(entries.last, entry)) continue;
    entries.add(entry);
  }

  entries.add(
    WristEntry(
      at: DateTime(day.year, day.month, day.day + 1),
      state: WristStateKind.noSchedule,
    ),
  );

  return WristTimeline(
    dateYmd: schedule.dateYmd,
    generatedAt: now,
    utcOffsetMinutes: offset,
    entries: entries,
  );
}

/// Two consecutive entries that would show the same thing collapse into the
/// first, so the watch's WidgetKit timeline only reloads on a real change.
bool _sameDisplay(WristEntry a, WristEntry b) =>
    a.state == b.state &&
    a.current?.id == b.current?.id &&
    a.next?.id == b.next?.id;
