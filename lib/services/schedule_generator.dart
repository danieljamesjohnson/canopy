import 'dart:math';

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/energy_valence.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:intl/intl.dart';

/// Pure Dart service — no Flutter imports, no async, no side effects.
///
/// Generates an ordered flat list of [ScheduledChunk]s for a given day,
/// mood level, goal list, and commitment blocks.
///
/// Allocation order:
///   1. Commitment blocks (anchored work chunks, not counted against cap)
///   2. Habits (frequency-aware; scheduled on due weekdays only)
///   3. Outcome goals (mood 3-5 only, or deadline pressure; sorted by urgency)
///   4. Time-target goals (mood 3-5 only; multi-chunk demand, most-behind first)
///
/// After allocation, a break insertion pass interleaves shortBreak / longBreak
/// chunks between every work chunk. longBreakEvery = 3 for mood 1-2, 4 for 3-5.
class ScheduleGeneratorService {
  /// Capacity table: maps moodIndex → max discretionary work chunks at 80%.
  ///
  /// Raw max:  mood 1=6, 2=8, 3=10, 4=12, 5=14
  /// 80% cap:  mood 1=4, 2=6, 3=8,  4=9,  5=11
  static const Map<int, int> _moodCap = {1: 4, 2: 6, 3: 8, 4: 9, 5: 11};

  /// Effective cap after applying lighter-day reduction.
  ///
  /// When [lighterDay] is true, drops one mood tier (next-lower cap).
  /// mood=1 lighter has no lower tier — same cap.
  int _effectiveCap(int moodIndex, bool lighterDay) {
    if (!lighterDay) return _moodCap[moodIndex] ?? 8;
    final lowerMood = (moodIndex - 1).clamp(1, 5);
    return _moodCap[lowerMood] ?? _moodCap[moodIndex]!;
  }

  // ---------------------------------------------------------------------------
  // Public static helpers — exposed for Plan 03 (ScheduleNotifier streak write-back).
  // ---------------------------------------------------------------------------

  /// Returns the set of due weekdays (Monday=1 through Sunday=7) for a habit
  /// with the given [freq] sessions per week.
  ///
  /// Weekday-biased: frequencies of 5 or fewer fill the work week (Mon–Fri)
  /// first and never land on a weekend; freq 6 adds Saturday; freq 7 is daily.
  /// This matches the user's mental model — "5x/week" means weekdays, not a
  /// mathematically even spread that put a session on Saturday and skipped
  /// Thursday (the old `i*7~/freq+1` formula gave freq=5 → {Mon,Tue,Wed,Fri,Sat}).
  ///
  /// Lower frequencies are spaced out within the work week:
  ///   1 → Mon | 2 → Mon,Thu | 3 → Mon,Wed,Fri | 4 → Mon,Tue,Thu,Fri | 5 → Mon–Fri
  static const Map<int, Set<int>> _dueWeekdaysByFreq = {
    1: {1},
    2: {1, 4},
    3: {1, 3, 5},
    4: {1, 2, 4, 5},
    5: {1, 2, 3, 4, 5},
    6: {1, 2, 3, 4, 5, 6},
    7: {1, 2, 3, 4, 5, 6, 7},
  };

  static Set<int> computeDueWeekdays(int freq) {
    assert(freq >= 1 && freq <= 7);
    return _dueWeekdaysByFreq[freq.clamp(1, 7)] ?? _dueWeekdaysByFreq[7]!;
  }

  /// Computes the habit streak by walking backward through the calendar from
  /// [today], checking each due weekday for a completed log entry.
  ///
  /// A due weekday with no log entry (truly missed — user never opened the app)
  /// breaks the streak, per the spec: "A due day that is skipped or missed
  /// resets the streak to 0" (09-CONTEXT.md). The previous log-walk
  /// implementation was blind to missing entries (WR-02).
  ///
  /// The walk is bounded at 365 days to keep execution O(1) in the worst case.
  static int computeStreak(
    String goalId,
    Set<int> dueWeekdays,
    List<CompletionLog> allLogs, {
    required DateTime today,
  }) {
    // Index all completed dates for O(1) lookup.
    final completedDates = <String>{
      for (final l in allLogs)
        if (l.goalId == goalId && l.event == CompletionEvent.completed)
          l.dateYmd,
    };
    // CLOSE-02: deferred days do not break the streak — treated as "moved, not missed".
    final deferredDates = <String>{
      for (final l in allLogs)
        if (l.goalId == goalId && l.event == CompletionEvent.deferred)
          l.dateYmd,
    };

    final fmt = DateFormat('yyyy-MM-dd');
    int streak = 0;
    var day = DateTime(today.year, today.month, today.day);
    for (int i = 0; i < 365; i++) {
      if (dueWeekdays.contains(day.weekday)) {
        final ymd = fmt.format(day);
        if (completedDates.contains(ymd)) {
          streak++;
        } else if (deferredDates.contains(ymd)) {
          // CLOSE-02: deferred — count as continuing (move, not miss); do not increment.
        } else {
          break; // missed or skipped — reset
        }
      }
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ---------------------------------------------------------------------------
  // Private budget helpers.
  // ---------------------------------------------------------------------------

  /// Returns the Monday of the week containing [date].
  DateTime _weekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  /// Counts completed (not skipped) time-target chunks this week for [goalId].
  int _completedChunksThisWeek(
    String goalId,
    List<CompletionLog> logs,
    DateTime today,
  ) {
    final weekStart = _weekStart(today);
    return logs.where((l) {
      if (l.goalId != goalId) return false;
      if (l.event != CompletionEvent.completed) return false;
      final logDate = DateTime.parse(l.dateYmd);
      return !logDate.isBefore(weekStart) && !logDate.isAfter(today);
    }).length;
  }

  /// Remaining weekly hours for [goal], clamped to [0, weeklyHourBudget].
  double _remainingHours(Goal goal, List<CompletionLog> logs, DateTime date) {
    if (goal.weeklyHourBudget == null) return 0;
    final completedHrs =
        _completedChunksThisWeek(goal.id, logs, date) * 25.0 / 60.0;
    return (goal.weeklyHourBudget! - completedHrs).clamp(
      0.0,
      goal.weeklyHourBudget!,
    );
  }

  /// Demand chunks for a time-target goal today: ceil(remaining×60/25/daysLeft).
  /// Capped at 4 per day. [daysLeft] is clamped to [1,7] — never zero.
  int _demandForTimeTarget(Goal goal, List<CompletionLog> logs, DateTime date) {
    final remaining = _remainingHours(goal, logs, date);
    if (remaining <= 0) return 0;
    final daysLeft = (7 - date.weekday + 1).clamp(1, 7);
    return (remaining * 60.0 / 25.0 / daysLeft).ceil().clamp(0, 4);
  }

  // ---------------------------------------------------------------------------
  // Private rationale helpers.
  // ---------------------------------------------------------------------------

  String _habitRationale(Goal goal, int streak) {
    if (streak > 0) return 'Streak: $streak day${streak == 1 ? "" : "s"}';
    final freq = goal.frequencyPerWeek ?? 7;
    return freq == 7 ? 'Daily habit' : '${freq}x/week';
  }

  String _outcomeRationale(Goal goal, DateTime date) {
    if (goal.deadline == null) return 'Working toward your goal';
    final days = goal.deadline!.difference(date).inDays.clamp(0, 9999);
    if (days == 0) return 'Deadline today';
    if (days == 1) return 'Deadline tomorrow';
    return 'Deadline in $days day${days == 1 ? "" : "s"}';
  }

  String _timeTargetRationale(
    Goal goal,
    List<CompletionLog> logs,
    DateTime date,
  ) {
    final completed = _completedChunksThisWeek(goal.id, logs, date);
    final completedHrs = completed * 25.0 / 60.0;
    final remaining = ((goal.weeklyHourBudget ?? 0.0) - completedHrs).clamp(
      0.0,
      double.infinity,
    );
    if (remaining < 0.1) return 'On track this week';
    return '${remaining.toStringAsFixed(1)}h behind this week';
  }

  // ---------------------------------------------------------------------------
  // Main generation method.
  // ---------------------------------------------------------------------------

  /// Generate a schedule for [date] given [moodIndex] (1-5), active [goals],
  /// and recurring [blocks].
  ///
  /// [deferredGoalIds] — CLOSE-02 carry-in: goal IDs whose chunks were deferred
  /// on the previous day but not completed. For each ID not already represented
  /// in the generated discretionary work chunks, one additional slot is injected
  /// (re-materialized as fresh demand for the same goal). Commitment goal IDs
  /// are excluded by the caller (they have null goalId). Injection respects the
  /// mood cap so it does not exceed capacity.
  List<ScheduledChunk> generate({
    required List<Goal> goals,
    required List<CommitmentBlock> blocks,
    required int moodIndex,
    required DateTime date,
    List<CompletionLog> completionLogs = const [],
    bool lighterDay = true,
    Set<String> deferredGoalIds = const {}, // CLOSE-02 carry-in
    int? startFloorMinutes, // earliest minutes-since-midnight for discretionary
    // chunks; when the day is generated mid-day, packing starts near "now"
    // instead of 8:00 AM. Null → use the default 8:00 AM day start.
  }) {
    final int cap = _effectiveCap(moodIndex, lighterDay);
    final bool isLowMood = moodIndex <= 2;
    final int longBreakEvery = isLowMood ? 3 : 4;

    // Collect work chunks in allocation order.
    final List<ScheduledChunk> workChunks = [];
    int discretionaryCount = 0;

    // -------------------------------------------------------------------------
    // Step 1: Commitment block chunks (anchored; not counted against cap).
    // -------------------------------------------------------------------------
    for (final block in blocks) {
      if (!block.daysOfWeek.contains(date.weekday)) continue;
      int cursor = block.startMinutes;
      while (cursor + 25 <= block.endMinutes) {
        workChunks.add(
          ScheduledChunk(
            chunkTypeIndex: ChunkType.work.index,
            goalId: null,
            commitmentId: block.id, // CLOSE-03: real block id for attribution
            durationMinutes: 25,
            anchoredStartMinutes: cursor,
            rationale: block.name,
          ),
        );
        cursor += 25;
      }
    }

    // -------------------------------------------------------------------------
    // Step 2: Habits — scheduled on due weekdays only; streak from logs.
    // Priority-sorted so high-priority habits fill cap before low-priority.
    // CAP-01: habits may not consume more than ceil(cap/2) slots so outcomes
    // and time-targets always receive capacity on low-mood days.
    // PRIORITY-02: high-priority habits get 2 chunks on good-mood days.
    // -------------------------------------------------------------------------
    final activeGoals = goals.where((g) => !g.isArchived).toList();

    final habitGoals =
        activeGoals.where((g) => g.goalType == GoalType.habit).toList()..sort(
          (a, b) =>
              (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5),
        );

    // CAP-01: ceiling on habit slots ensures outcomes and time-targets get capacity.
    final int habitCeiling = (cap / 2).ceil();
    int habitCount = 0;

    // PRIORITY-02: high-priority habits get 2 chunks on good-mood days.
    // On low-mood days all habits get 1 chunk regardless of priority.
    int habitDemand(Goal g) =>
        (!isLowMood && (g.priorityWeight ?? 0.5) >= 0.75) ? 2 : 1;

    for (final goal in habitGoals) {
      if (discretionaryCount >= cap) break;
      if (habitCount >= habitCeiling) break; // CAP-01 type ceiling
      final effectiveFreq = goal.frequencyPerWeek ?? 7;
      final dueWeekdays = computeDueWeekdays(effectiveFreq);
      if (!dueWeekdays.contains(date.weekday)) continue; // not due today
      final streak = computeStreak(
        goal.id,
        dueWeekdays,
        completionLogs,
        today: date,
      );
      final demand = habitDemand(goal);
      for (int i = 0; i < demand; i++) {
        if (discretionaryCount >= cap) break;
        if (habitCount >= habitCeiling) break;
        workChunks.add(
          ScheduledChunk(
            chunkTypeIndex: ChunkType.work.index,
            goalId: goal.id,
            durationMinutes: 25,
            rationale: _habitRationale(goal, streak),
          ),
        );
        discretionaryCount++;
        habitCount++;
      }
    }

    // -------------------------------------------------------------------------
    // Step 3: Outcome goals.
    // Mood 3–5: all outcomes sorted by urgency.
    // Mood 1–2 + lighterDay OFF: outcomes with deadlines, urgency sorted.
    // Mood 1–2 + lighterDay ON: only deadline==today.
    // -------------------------------------------------------------------------
    final outcomeGoals = activeGoals
        .where((g) => g.goalType == GoalType.outcome)
        .toList();

    double urgencyScore(Goal g) {
      if (g.deadline == null) return (g.priorityWeight ?? 0.5) * 0.1;
      final daysRemaining = max(1, g.deadline!.difference(date).inDays);
      return (g.priorityWeight ?? 0.5) / daysRemaining.toDouble();
    }

    outcomeGoals.sort((a, b) => urgencyScore(b).compareTo(urgencyScore(a)));

    for (final goal in outcomeGoals) {
      if (discretionaryCount >= cap) break;
      final deadlineToday =
          goal.deadline != null &&
          goal.deadline!.year == date.year &&
          goal.deadline!.month == date.month &&
          goal.deadline!.day == date.day;
      final bool include;
      if (!isLowMood) {
        include = true; // mood 3–5: all outcomes
      } else if (lighterDay) {
        // VSCHED-01: energy-giving outcomes always eligible on low-mood days.
        include = deadlineToday || goal.energyValence == EnergyValence.gives;
      } else {
        include = goal.deadline != null ||
            goal.energyValence == EnergyValence.gives;
      }
      if (!include) continue;
      // PRIORITY-02: high-priority outcomes get 2 chunks on good-mood days.
      final outcomeDemand = (!isLowMood && (goal.priorityWeight ?? 0.5) >= 0.75)
          ? 2
          : 1;
      for (int i = 0; i < outcomeDemand; i++) {
        if (discretionaryCount >= cap) break;
        workChunks.add(
          ScheduledChunk(
            chunkTypeIndex: ChunkType.work.index,
            goalId: goal.id,
            durationMinutes: 25,
            rationale: _outcomeRationale(goal, date),
          ),
        );
        discretionaryCount++;
      }
    }

    // -------------------------------------------------------------------------
    // Step 4: Time-target goals.
    // FILL-01: runs always (not gated on !isLowMood); on low-mood days demand
    //          is capped at 1 chunk per goal so the day stays light. This is
    //          open-capacity filling, not a restorative floor (Pitfall 4).
    // FILL-02: round-robin across sorted goals so no single goal monopolizes
    //          the remaining open capacity.
    // Sort stability: equal-score goals tiebreak on goal.id (Pitfall 2).
    // -------------------------------------------------------------------------
    double score(Goal g) =>
        _remainingHours(g, completionLogs, date) * (g.priorityWeight ?? 0.5);
    final timeTargetGoals =
        activeGoals.where((g) => g.goalType == GoalType.timeTarget).toList()
          ..sort((a, b) {
            final cmp = score(b).compareTo(score(a));
            return cmp != 0
                ? cmp
                : a.id.compareTo(b.id); // stable secondary key
          });

    // Shared tracker: hoisted here so all three sub-passes (restorative floor,
    // PRIORITY-03 surplus, VSCHED-03 reservation) and FILL-02 round-robin share
    // one map and no goal is double-placed.
    final placedCountPerGoal = <String, int>{};

    // VSCHED-01/02: Restorative floor — on low-mood days, guarantee at least
    // 1 chunk goes to an energy-giving time-target goal (if one has demand)
    // before the PRIORITY-03/FILL-02 passes run.
    // VSCHED-02 bound: restorativeFloor = 1 keeps low days light.
    const int restorativeFloor = 1;
    int restorativeCount = 0;
    if (isLowMood) {
      for (final goal in timeTargetGoals) {
        if (discretionaryCount >= cap) break;
        if (restorativeCount >= restorativeFloor) break;
        if (goal.energyValence != EnergyValence.gives) continue;
        final rawDemand = _demandForTimeTarget(goal, completionLogs, date);
        if (rawDemand <= 0) continue;
        workChunks.add(
          ScheduledChunk(
            chunkTypeIndex: ChunkType.work.index,
            goalId: goal.id,
            durationMinutes: 25,
            rationale: _timeTargetRationale(goal, completionLogs, date),
          ),
        );
        discretionaryCount++;
        placedCountPerGoal[goal.id] = 1; // CRITICAL: prevents FILL-02 double-place
        restorativeCount++;
      }
    }

    // PRIORITY-03: high-priority time-target goals (priorityWeight >= 0.75) receive
    // one surplus chunk ahead of the round-robin so they end up with strictly more
    // chunks than lower-priority goals when capacity is binding. The surplus is
    // capped by both the goal's own demand and the remaining discretionary cap.
    // NOTE: when three or more high-priority goals are present, the surplus pass
    // can consume enough capacity that lower-priority goals receive zero chunks
    // even if they have demand. This is accepted behavior; the round-robin that
    // follows only guarantees proportional distribution among goals that reach it.
    for (final goal in timeTargetGoals) {
      if (discretionaryCount >= cap) break;
      if ((goal.priorityWeight ?? 0.5) < 0.75) continue;
      final rawDemand = _demandForTimeTarget(goal, completionLogs, date);
      final demand = isLowMood ? rawDemand.clamp(0, 1) : rawDemand;
      if (demand <= 0) continue;
      workChunks.add(
        ScheduledChunk(
          chunkTypeIndex: ChunkType.work.index,
          goalId: goal.id,
          durationMinutes: 25,
          rationale: _timeTargetRationale(goal, completionLogs, date),
        ),
      );
      discretionaryCount++;
      placedCountPerGoal[goal.id] = 1;
    }

    // FILL-02: one chunk per goal per pass until cap is full or all demands satisfied.
    bool anyPlaced = true;
    while (anyPlaced && discretionaryCount < cap) {
      anyPlaced = false;
      for (final goal in timeTargetGoals) {
        if (discretionaryCount >= cap) break;
        final placed = placedCountPerGoal[goal.id] ?? 0;
        // FILL-01: cap actual demand at 1 per goal on low-mood days so goals
        // with no remaining budget (rawDemand == 0) are correctly skipped.
        final rawDemand = _demandForTimeTarget(goal, completionLogs, date);
        final demand = isLowMood ? rawDemand.clamp(0, 1) : rawDemand;
        if (demand <= 0 || placed >= demand) continue;
        workChunks.add(
          ScheduledChunk(
            chunkTypeIndex: ChunkType.work.index,
            goalId: goal.id,
            durationMinutes: 25,
            rationale: _timeTargetRationale(goal, completionLogs, date),
          ),
        );
        discretionaryCount++;
        placedCountPerGoal[goal.id] = placed + 1;
        anyPlaced = true;
      }
    }

    // -------------------------------------------------------------------------
    // CLOSE-02: Deferred carry-in injection.
    // For each goalId in deferredGoalIds not already present in the generated
    // discretionary work chunks, inject one additional slot as fresh demand,
    // provided the goal is a real non-archived discretionary goal and the mood
    // cap has not been reached. Commitment goals are excluded at the call site
    // (they have null goalId and are not in deferredGoalIds).
    // -------------------------------------------------------------------------
    if (deferredGoalIds.isNotEmpty) {
      // Build a set of goalIds already scheduled by Steps 2-4.
      final scheduledGoalIds = workChunks
          .where((c) => c.goalId != null)
          .map((c) => c.goalId!)
          .toSet();

      // CLOSE-02: deferred injection bypasses the habitCeiling guard intentionally.
      // A goal deferred from yesterday has already been counted against yesterday's
      // cap. Re-materializing it today should not be blocked by today's ceiling —
      // the goal was already "paid for" and the user explicitly asked to defer it.
      for (final gid in deferredGoalIds) {
        if (discretionaryCount >= cap) break;
        if (scheduledGoalIds.contains(gid)) continue; // already scheduled
        // Find the goal in the active goals list.
        final goal = activeGoals.where((g) => g.id == gid).firstOrNull;
        if (goal == null) continue; // goal not found or archived
        // Inject one fresh-demand slot for this goal.
        workChunks.add(
          ScheduledChunk(
            chunkTypeIndex: ChunkType.work.index,
            goalId: gid,
            durationMinutes: 25,
            rationale: 'Carried over from yesterday',
          ),
        );
        discretionaryCount++;
        scheduledGoalIds.add(
          gid,
        ); // prevent duplicate if same id appears twice in set
      }
    }

    // -------------------------------------------------------------------------
    // Ordering + break insertion pass (READ-02).
    // -------------------------------------------------------------------------
    if (workChunks.isEmpty) return [];

    // STEP A: Split into commitment (anchored) and discretionary streams.
    final List<ScheduledChunk> commitmentChunks =
        workChunks.where((c) => c.anchoredStartMinutes != null).toList()..sort(
          (a, b) => a.anchoredStartMinutes!.compareTo(b.anchoredStartMinutes!),
        );
    final List<ScheduledChunk> discretionaryChunks = workChunks
        .where((c) => c.anchoredStartMinutes == null)
        .toList();

    // STEP B: Assign synthetic start times to discretionary chunks.
    _assignSyntheticStartTimes(
      discretionaryChunks: discretionaryChunks,
      commitmentChunks: commitmentChunks,
      longBreakEvery: longBreakEvery,
      startFloorMinutes: startFloorMinutes,
    );

    // STEP C: Build result — commitment chunks (no breaks between them),
    // then interleave breaks for discretionary chunks only.
    //
    // WR-01: the break for each discretionary chunk is driven entirely by the
    // reservedBreakMinutes recorded during packing — the single source of truth
    // for the cadence. We do NOT recompute the long-break cadence here with an
    // independent counter (which could diverge from the reserved slot and emit
    // a 25-min long break where only 5 minutes were reserved, overlapping the
    // next chunk after the sort). A null reservation means the packing pass
    // reserved no break room after this chunk, so no break is emitted.
    final List<ScheduledChunk> result = [...commitmentChunks];
    for (final chunk in discretionaryChunks) {
      result.add(chunk);
      final reserved = chunk.reservedBreakMinutes;
      if (reserved == null) continue; // no break room was reserved
      final isLong = reserved >= 25;
      final breakChunk = ScheduledChunk(
        chunkTypeIndex: isLong
            ? ChunkType.longBreak.index
            : ChunkType.shortBreak.index,
        goalId: null,
        durationMinutes: reserved,
        rationale: '',
      );
      // Position the break immediately after its preceding work chunk so the
      // Step D sort keeps it adjacent (and within the reserved footprint).
      if (chunk.syntheticStartMinutes != null) {
        breakChunk.syntheticStartMinutes =
            chunk.syntheticStartMinutes! + chunk.durationMinutes;
      }
      result.add(breakChunk);
    }

    // STEP D: Sort flat list by effective start time.
    result.sort((a, b) {
      final aStart = a.anchoredStartMinutes ?? a.syntheticStartMinutes ?? 9999;
      final bStart = b.anchoredStartMinutes ?? b.syntheticStartMinutes ?? 9999;
      return aStart.compareTo(bStart);
    });

    // STEP E: Trim trailing non-work chunks (no dangling break at end).
    while (result.isNotEmpty && result.last.chunkType != ChunkType.work) {
      result.removeLast();
    }

    return result;
  }

  /// Assigns [syntheticStartMinutes] to each discretionary chunk by filling
  /// the free time slots around anchored commitment windows.
  ///
  /// Day runs from [dayStart] (480 = 8:00 AM) to 1320 (22:00 / 10:00 PM).
  /// Each discretionary work chunk is 25 minutes; breaks (short 5 min,
  /// long 25 min) are accounted for when deciding whether a slot has room.
  void _assignSyntheticStartTimes({
    required List<ScheduledChunk> discretionaryChunks,
    required List<ScheduledChunk> commitmentChunks,
    required int longBreakEvery,
    int? startFloorMinutes,
  }) {
    const int defaultDayStart = 480; // 8:00 AM
    const int dayEnd = 1320; // 10:00 PM
    // Start packing at "now" when generating mid-day so the plan doesn't lay
    // chunks down in already-passed morning hours. Never earlier than 8:00 AM,
    // and round up to the next 5-minute boundary for tidy start times.
    final int dayStart = startFloorMinutes == null
        ? defaultDayStart
        : (((startFloorMinutes + 4) ~/ 5) * 5).clamp(defaultDayStart, dayEnd);

    // Build merged commitment windows.
    //
    // WR-02: a proper interval merge. Sort the raw windows by start, then merge
    // any window that overlaps OR touches the running window
    // (next.start <= current.end), taking end = max(prev.end, next.end). The
    // previous adjacency-only merge (windows.last.end == s) left two
    // overlapping same-day commitment blocks unmerged, which let the cursor
    // move backward and produced a negative-width free slot.
    final rawWindows = <({int start, int end})>[
      for (final c in commitmentChunks)
        (
          start: c.anchoredStartMinutes!,
          end: c.anchoredStartMinutes! + c.durationMinutes,
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final windows = <({int start, int end})>[];
    for (final w in rawWindows) {
      if (windows.isNotEmpty && w.start <= windows.last.end) {
        final prev = windows.removeLast();
        windows.add((
          start: prev.start,
          end: w.end > prev.end ? w.end : prev.end,
        ));
      } else {
        windows.add((start: w.start, end: w.end));
      }
    }

    // Derive free slots from dayStart to dayEnd around commitment windows.
    // Clamp the cursor so it never moves backward (WR-02): with merged windows
    // this is already monotonic, but the clamp is defensive against any future
    // window source and guarantees no negative-width slot is ever emitted.
    final slots = <({int start, int end})>[];
    int cursor = dayStart;
    for (final w in windows) {
      if (cursor < w.start) {
        slots.add((start: cursor, end: w.start));
      }
      cursor = cursor > w.end ? cursor : w.end;
    }
    slots.add((start: cursor, end: dayEnd));

    // Greedily pack discretionary chunks into free slots.
    //
    // WR-01: this packing pass is the SINGLE source of truth for the long-break
    // cadence. For each placed chunk we record, on the chunk itself, the exact
    // break duration reserved after it (reservedBreakMinutes) so STEP C emits
    // that same break instead of recomputing the cadence with an independent
    // counter that could diverge.
    int discIdx = 0;
    int breakCount = 0;
    for (final slot in slots) {
      cursor = slot.start;
      while (cursor + 25 <= slot.end && discIdx < discretionaryChunks.length) {
        discretionaryChunks[discIdx].syntheticStartMinutes = cursor;
        cursor += 25;
        breakCount++;
        final isLong = breakCount % longBreakEvery == 0;
        final breakDur = isLong ? 25 : 5;
        // Reserve the break footprint only when it fits AND more discretionary
        // chunks remain to be placed. Record the reserved duration so STEP C
        // emits the matching break; leaving it null means STEP C emits none.
        if (cursor + breakDur <= slot.end &&
            discIdx + 1 < discretionaryChunks.length) {
          discretionaryChunks[discIdx].reservedBreakMinutes = breakDur;
          cursor += breakDur;
        }
        discIdx++;
      }
    }
    // Discretionary chunks that didn't fit retain syntheticStartMinutes == null
    // and will be sorted to the end (9999) then trimmed is not needed here —
    // they are simply omitted because the STEP C loop uses discretionaryChunks
    // as-is; chunks with no slot assigned still get added but sort last.
    // Per Open Question 1 (resolved): drop overflow by only iterating chunks
    // with syntheticStartMinutes set. Filter in-place after packing.
    discretionaryChunks.removeWhere((c) => c.syntheticStartMinutes == null);
  }
}
