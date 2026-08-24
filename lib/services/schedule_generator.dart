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
/// Every work chunk — commitment AND discretionary alike — gets breaks on
/// the same 30-minute lattice (COMMITBREAK-01, Phase 30): every work chunk
/// *tries to close* its own cell with a 5-minute short break, and every
/// longBreakEvery-th chunk's cell is *normally* followed by a separate
/// 30-minute long break cell — except when the enclosing window is too
/// narrow to hold that footprint (bounded by an off-lattice commitment start,
/// the block's own end, or the 10:00 PM day end), in which case the break is
/// genuinely omitted rather than silently suppressed by a position-based
/// guard. A commitment block's window runs this insertion pass through
/// [buildCommitmentChunks], on the block's OWN independent cadence counter
/// (D-30-01); discretionary chunks run it through
/// [_assignSyntheticStartTimes] — see either for its exact fallback rules.
/// longBreakEvery is mood-scaled: 2 / 3 / 4 / 4 / 5 for moods 1 through 5 —
/// see the break-cadence table below.
class ScheduleGeneratorService {
  /// Capacity table: maps moodIndex → max discretionary work chunks at 80%.
  ///
  /// Raw max:  mood 1=6, 2=8, 3=10, 4=12, 5=14
  /// 80% cap:  mood 1=4, 2=6, 3=8,  4=9,  5=11
  static const Map<int, int> _moodCap = {1: 4, 2: 6, 3: 8, 4: 9, 5: 11};

  /// Break-cadence table: maps moodIndex → work chunks between long breaks.
  ///
  /// mood 1 Stormy = 2 (BREAK-01 low endpoint), mood 2 Overcast = 3,
  /// mood 3 Partly cloudy = 4 (unchanged from the pre-BREAK-01 baseline),
  /// mood 4 Clearing up = 4, mood 5 Clear skies = 5 (BREAK-01 sunny
  /// endpoint). Moods 3 and 4 deliberately plateau at 4 rather than
  /// inventing a strictly increasing curve the success criteria never
  /// asked for.
  static const Map<int, int> _moodBreakCadence = {1: 2, 2: 3, 3: 4, 4: 4, 5: 5};

  /// Effective cap after applying lighter-day reduction.
  ///
  /// When [lighterDay] is true, drops one mood tier (next-lower cap).
  /// mood=1 lighter has no lower tier — same cap.
  int _effectiveCap(int moodIndex, bool lighterDay) {
    if (!lighterDay) return _moodCap[moodIndex] ?? 8;
    final lowerMood = (moodIndex - 1).clamp(1, 5);
    return _moodCap[lowerMood] ?? _moodCap[moodIndex]!;
  }

  /// The size, in minutes, of one lattice cell. Every discretionary chunk's
  /// start (and every free slot's start) is realigned to a multiple of this.
  static const int _latticeMinutes = 30;

  /// The short break that closes every discretionary work chunk's own cell.
  static const int _shortBreakMinutes = 5;

  /// The separate cell reserved after every longBreakEvery-th chunk, in
  /// addition to (never replacing) that chunk's own short break.
  static const int _longBreakMinutes = 30;

  /// Public aliases for the lattice constants above (IN-01), so
  /// `ScheduleNotifier._reflowDiscretionaryWork` — the notifier's own
  /// discretionary-repacking pass — reads its minute values from here
  /// instead of re-declaring its own literals. This is exactly how WR-03's
  /// 25-vs-30 long-break duration drifted unnoticed: two independent
  /// declarations of the same value, one of them wrong. Same "delete the
  /// duplicate, share the source of truth" pattern as D-30-03.
  static const int shortBreakMinutes = _shortBreakMinutes;
  static const int longBreakMinutes = _longBreakMinutes;

  /// The duration, in minutes, of one discretionary or commitment work
  /// chunk — matches the literal `25` used throughout this file's own
  /// packing passes (Step 1, `_assignSyntheticStartTimes`). Exposed for the
  /// same IN-01 reason as the break constants above.
  static const int workChunkMinutes = 25;

  /// The day's packing window — matches `_assignSyntheticStartTimes`'s own
  /// `defaultDayStart`/`dayEnd` locals. Exposed for the same IN-01 reason.
  static const int dayStartMinutes = 480; // 8:00 AM
  static const int dayEndMinutes = 1320; // 10:00 PM

  /// Rounds [minutes] up to the next multiple of [_latticeMinutes] — the
  /// file's existing round-up-to-N idiom, generalized from the old 5-minute
  /// version. Used at three call sites: the packing-loop realignment, the
  /// mid-day dayStart derivation (D-03), and the post-commitment free-slot
  /// start (D-02).
  int _roundUpToLattice(int minutes) =>
      ((minutes + _latticeMinutes - 1) ~/ _latticeMinutes) * _latticeMinutes;

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

  /// Returns the long-break cadence (work chunks between long breaks) for
  /// [moodIndex] — the single external reader of the `_moodBreakCadence`
  /// table, replacing the inline `_moodBreakCadence[moodIndex] ?? 4` lookup
  /// that used to live at the `generate()` call site. Falls back to 4 for an
  /// out-of-range value, matching that inline fallback exactly.
  static int breakCadenceForMood(int moodIndex) =>
      _moodBreakCadence[moodIndex] ?? 4;

  /// Builds the ordered list of anchored chunks — work AND break alike — for
  /// one commitment [block]'s own window (COMMITBREAK-01), mirroring
  /// [_assignSyntheticStartTimes]'s footprint-reservation pattern instead of
  /// a second, independently invented algorithm (30-RESEARCH.md "Recommended
  /// approach — mirror, don't reinvent"). This helper owns the whole window
  /// walk and nothing else: it does not decide whether [block] anchors
  /// today — callers keep their own anchoring check (`generate()`'s
  /// `anchoredToday`; `addEventToday` keeps its own equivalent).
  ///
  /// D-30-01: [longBreakEvery] drives a cadence counter that is LOCAL to
  /// this call — fresh for every block instance, never shared with
  /// [_assignSyntheticStartTimes]'s discretionary `breakCount`. A shared
  /// counter would count in code-execution order (this loop runs, and
  /// finishes, before Steps 2-4 collect discretionary demand) rather than
  /// wall-clock order (a discretionary chunk can land chronologically
  /// *before* a 09:00 commitment) — breaking the "Nth chunk of your day"
  /// cadence model unpredictably, which directly contradicts CLAUDE.md's
  /// product position that a schedule the user can't predict is one they
  /// won't trust. Settled by simulation, not estimate: a 6-hour block at
  /// mood 3 yields exactly 2 long breaks — the same density 6 hours of
  /// discretionary work already gets at that mood (30-RESEARCH.md "Cadence
  /// Decision", captured RED as COMMITBREAK-01/CADENCE).
  ///
  /// [block.startMinutes]/[block.endMinutes] are read-only throughout (Phase
  /// 28 D-01) — only the chunk *composition* inside the window changes.
  static List<ScheduledChunk> buildCommitmentChunks(
    CommitmentBlock block, {
    required int longBreakEvery,
  }) {
    final List<ScheduledChunk> chunks = [];
    int cursor = block.startMinutes;
    // Last chunk actually added for THIS block — work or break — tracked as
    // a single mutable reference so the tail-stretch below always extends
    // whichever unit is genuinely last, never re-deriving it from position
    // (30-RESEARCH.md Pitfall 3: that is the defect path where the stretch
    // grows a work chunk backward over a break already placed).
    ScheduledChunk? lastForBlock;
    int blockBreakCount = 0; // D-30-01 — own counter, fresh per block instance
    while (cursor + 25 <= block.endMinutes) {
      final work = ScheduledChunk(
        chunkTypeIndex: ChunkType.work.index,
        goalId: null,
        commitmentId: block.id,
        durationMinutes: 25,
        anchoredStartMinutes: cursor,
        rationale: block.name,
      );
      chunks.add(work);
      lastForBlock = work;
      cursor += 25;
      blockBreakCount++;

      // isBoundary selects a footprint, never a duration: a cadence-boundary
      // cell reserves the ordinary short break PLUS a separate 30-minute
      // long-break cell after it — the long break never replaces the short
      // break (Phase 28 D-06), mirroring _assignSyntheticStartTimes's
      // isBoundary/breakFootprint shape rather than a second,
      // differently-shaped rule for the same cadence rule.
      final isBoundary = blockBreakCount % longBreakEvery == 0;
      final breakFootprint =
          _shortBreakMinutes + (isBoundary ? _longBreakMinutes : 0);
      if (cursor + breakFootprint <= block.endMinutes) {
        final sb = ScheduledChunk(
          chunkTypeIndex: ChunkType.shortBreak.index,
          goalId: null,
          // D-30-04: commitment breaks carry commitmentId too — the exact
          // discriminator D-30-02's narrowed STEP E trim depends on, and
          // visually inert on a break (ChunkCard routes on chunkType before
          // ever reading isCommitment — COMMITBREAK-01/RENDER, 30-02).
          commitmentId: block.id,
          durationMinutes: _shortBreakMinutes,
          anchoredStartMinutes: cursor,
          rationale: '',
        );
        chunks.add(sb);
        lastForBlock = sb;
        cursor += _shortBreakMinutes;
        if (isBoundary) {
          final lb = ScheduledChunk(
            chunkTypeIndex: ChunkType.longBreak.index,
            goalId: null,
            commitmentId: block.id,
            durationMinutes: _longBreakMinutes,
            anchoredStartMinutes: cursor,
            rationale: '',
          );
          chunks.add(lb);
          lastForBlock = lb;
          cursor += _longBreakMinutes;
        }
      } else if (cursor + _shortBreakMinutes <= block.endMinutes) {
        // Partial-reservation fallback: the full footprint doesn't fit, but
        // the chunk's own short break does — mirrors Phase 28 D-05's
        // capacity-driven fallback for the discretionary loop; the Nth
        // chunk still closes its own cell even when the window has no room
        // left for a separate long-break cell. Not a suppression rule.
        final sb = ScheduledChunk(
          chunkTypeIndex: ChunkType.shortBreak.index,
          goalId: null,
          commitmentId: block.id,
          durationMinutes: _shortBreakMinutes,
          anchoredStartMinutes: cursor,
          rationale: '',
        );
        chunks.add(sb);
        lastForBlock = sb;
        cursor += _shortBreakMinutes;
      }
      // else: no break reserved at all — a genuine capacity-driven omission
      // (Phase 28 D-05's shape), never a position-based suppression rule.
    }
    // Honor the full committed window: stretch whichever chunk was
    // genuinely last (work OR break) to reach block.endMinutes, so a
    // sub-lattice remainder is covered without ever growing a work chunk
    // backward over a break that was already reserved.
    if (lastForBlock != null && cursor < block.endMinutes) {
      lastForBlock.durationMinutes =
          lastForBlock.durationMinutes + (block.endMinutes - cursor);
    }
    return chunks;
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
    return 'Deadline in $days days'; // days is always >= 2 here
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
    return 'Working toward ${remaining.toStringAsFixed(1)}h this week';
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
    // WR-02: moodIndex is expected to be 1-5 (see DailySchedule.moodIndex);
    // this is a debug-only guard against a corrupt/legacy Hive value, matching
    // the existing assert(freq >= 1 && freq <= 7) pattern in
    // computeDueWeekdays. Release builds keep the ?? fallback below as the
    // actual runtime safety net.
    assert(moodIndex >= 1 && moodIndex <= 5);
    final int cap = _effectiveCap(moodIndex, lighterDay);
    final bool isLowMood = moodIndex <= 2;
    final int longBreakEvery = breakCadenceForMood(moodIndex);

    // Collect work chunks in allocation order.
    final List<ScheduledChunk> workChunks = [];
    int discretionaryCount = 0;

    // -------------------------------------------------------------------------
    // Step 1: Commitment block chunks (anchored; not counted against cap).
    // -------------------------------------------------------------------------
    for (final block in blocks) {
      // A one-off (dated) commitment anchors only on its specific calendar day;
      // a recurring commitment anchors on its weekly [daysOfWeek]. This is what
      // lets a human enter an actual dated event ("dentist this Thursday") and
      // see it land on that day only.
      final bool anchoredToday;
      if (block.date != null) {
        final d = block.date!;
        anchoredToday =
            d.year == date.year && d.month == date.month && d.day == date.day;
      } else {
        anchoredToday = block.daysOfWeek.contains(date.weekday);
      }
      if (!anchoredToday) continue;
      // COMMITBREAK-01: the block's own window gets breaks on the same
      // 25+5(+30) lattice as discretionary time, via buildCommitmentChunks —
      // CLOSE-03's real block-id attribution now flows through that helper.
      workChunks.addAll(
        buildCommitmentChunks(block, longBreakEvery: longBreakEvery),
      );
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
        // low-mood, lighterDay=false: user explicitly opted out of a reduced
        // day, so deadline pressure (any horizon) or restorative valence both
        // qualify. This is intentionally fuller than the lighterDay=true branch
        // (deadline-today-or-gives only): "non-lighter low days are harder
        // days — include anything with deadline pressure, not just imminent
        // ones." The asymmetry is by design; the gives addition here (Phase 20)
        // mirrors the lighterDay branch so gives goals are always protected.
        include =
            goal.deadline != null || goal.energyValence == EnergyValence.gives;
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
        placedCountPerGoal[goal.id] =
            1; // CRITICAL: prevents FILL-02 double-place
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
      // VSCHED-02 guard: if the restorative floor already placed this goal,
      // skip PRIORITY-03 for it so we never double-place on a low-mood day.
      final alreadyPlaced = placedCountPerGoal[goal.id] ?? 0;
      final rawDemand = _demandForTimeTarget(goal, completionLogs, date);
      final demand = isLowMood ? rawDemand.clamp(0, 1) : rawDemand;
      if (demand <= 0 || alreadyPlaced >= demand) continue;
      workChunks.add(
        ScheduledChunk(
          chunkTypeIndex: ChunkType.work.index,
          goalId: goal.id,
          durationMinutes: 25,
          rationale: _timeTargetRationale(goal, completionLogs, date),
        ),
      );
      discretionaryCount++;
      placedCountPerGoal[goal.id] =
          alreadyPlaced + 1; // increment, not overwrite
    }

    // VSCHED-03: On good-mood days, reserve 1 slot for an energy-giving /
    // high-priority time-target goal before the backlog round-robin runs.
    // Prevents high-backlog days from becoming pure throughput with zero
    // restorative chunks. Guard: !isLowMood (mood 3–5).
    if (!isLowMood) {
      final reserveCandidates =
          timeTargetGoals
              .where(
                (g) =>
                    g.energyValence == EnergyValence.gives ||
                    (g.priorityWeight ?? 0.5) >= 0.75,
              )
              .toList()
            ..sort((a, b) {
              // gives-valence first; tie → composite score descending; tie → id (SC-4 stable)
              final aGives = a.energyValence == EnergyValence.gives ? 0 : 1;
              final bGives = b.energyValence == EnergyValence.gives ? 0 : 1;
              if (aGives != bGives) return aGives.compareTo(bGives);
              final scoreCmp = score(b).compareTo(score(a));
              if (scoreCmp != 0) return scoreCmp;
              return a.id.compareTo(b.id); // stable final key — SC-4
            });

      for (final goal in reserveCandidates) {
        if (discretionaryCount >= cap) break;
        final placed = placedCountPerGoal[goal.id] ?? 0;
        final rawDemand = _demandForTimeTarget(goal, completionLogs, date);
        if (rawDemand <= 0 || placed >= rawDemand) continue;
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
        break; // only 1 reserved slot
      }
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

    // STEP C: Build result — commitment chunks first (COMMITBREAK-01: these
    // now include the block's OWN internal breaks, fully formed by
    // buildCommitmentChunks at emission time), then interleave breaks for
    // discretionary chunks.
    //
    // WR-01: the break(s) for each discretionary chunk are driven entirely by
    // the reservedBreakMinutes footprint recorded during packing — the single
    // source of truth for the cadence. We do NOT recompute the long-break
    // cadence here with an independent counter (which could diverge from the
    // reserved slot and emit a break where only partial room was reserved,
    // overlapping the next chunk after the sort). A null reservation means
    // the packing pass reserved no break room after this chunk, so no break
    // is emitted.
    final List<ScheduledChunk> result = [...commitmentChunks];
    for (final chunk in discretionaryChunks) {
      result.add(chunk);
      final reserved = chunk.reservedBreakMinutes;
      if (reserved == null) continue; // no break room was reserved
      // Decode the footprint: an ordinary cell reserves only the chunk's own
      // short break (5); a cadence-boundary cell reserves that same short
      // break PLUS a separate 30-minute long-break cell after it (35 total).
      // Never treat `reserved` itself as a single break duration — see
      // RESEARCH.md Pitfall 4.
      if (reserved > _shortBreakMinutes) {
        result.add(_shortBreakChunk(chunk));

        final longBreak = ScheduledChunk(
          chunkTypeIndex: ChunkType.longBreak.index,
          goalId: null,
          durationMinutes: reserved - _shortBreakMinutes,
          rationale: '',
        );
        if (chunk.syntheticStartMinutes != null) {
          longBreak.syntheticStartMinutes =
              chunk.syntheticStartMinutes! +
              chunk.durationMinutes +
              _shortBreakMinutes;
        }
        result.add(longBreak);
      } else {
        result.add(_shortBreakChunk(chunk));
      }
    }

    // STEP D: Sort flat list by effective start time.
    result.sort((a, b) {
      final aStart = a.anchoredStartMinutes ?? a.syntheticStartMinutes ?? 9999;
      final bStart = b.anchoredStartMinutes ?? b.syntheticStartMinutes ?? 9999;
      return aStart.compareTo(bStart);
    });

    // STEP E: Trim a trailing dangling SHORT break only (D-05), and only a
    // DISCRETIONARY one (D-30-02). A trailing long break deliberately
    // survives — LATTICE-02's "never silently suppressed" means a day can
    // now end with an explicit "take a 30-minute break" card with nothing
    // after it. Trimming any trailing non-work chunk here (the old
    // behavior) would re-create defect 3 by a second path even after the
    // packing loop no longer suppresses it.
    //
    // commitmentId == null narrows the trim to discretionary-origin breaks
    // only (D-30-02): a trailing discretionary short break is 5 idle
    // minutes and reads as noise, but a trailing COMMITMENT break
    // (COMMITBREAK-01) may have been tail-stretched by buildCommitmentChunks
    // to cover a sub-lattice remainder — trimming it would silently erase
    // however many real committed minutes the stretch absorbed from inside
    // the user's own committed window, not just drop 5 idle minutes.
    while (result.isNotEmpty &&
        result.last.chunkType == ChunkType.shortBreak &&
        result.last.commitmentId == null) {
      result.removeLast();
    }

    return result;
  }

  /// Builds the 5-minute short-break [ScheduledChunk] that closes
  /// [afterChunk]'s cell, positioned immediately after it. Shared by both
  /// STEP C branches (ordinary cell and cadence-boundary cell) so the break
  /// chunk's fields can't drift out of sync between them (WR-02).
  ScheduledChunk _shortBreakChunk(ScheduledChunk afterChunk) {
    final shortBreak = ScheduledChunk(
      chunkTypeIndex: ChunkType.shortBreak.index,
      goalId: null,
      durationMinutes: _shortBreakMinutes,
      rationale: '',
    );
    if (afterChunk.syntheticStartMinutes != null) {
      shortBreak.syntheticStartMinutes =
          afterChunk.syntheticStartMinutes! + afterChunk.durationMinutes;
    }
    return shortBreak;
  }

  /// Assigns [syntheticStartMinutes] to each discretionary chunk by filling
  /// the free time slots around anchored commitment windows.
  ///
  /// Day runs from [dayStart] (480 = 8:00 AM) to 1320 (22:00 / 10:00 PM).
  /// Each discretionary work chunk is 25 minutes; breaks are accounted for
  /// on a 30-minute lattice — every chunk reserves at least its own 5-minute
  /// short break, and every longBreakEvery-th chunk additionally reserves a
  /// separate 30-minute long-break cell — when deciding whether a slot has
  /// room.
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
    // and round up to the next 30-minute boundary (D-03) so a mid-day
    // regeneration lands its first discretionary chunk on the lattice, not
    // just at a "tidy" 5-minute mark.
    final int dayStart = startFloorMinutes == null
        ? defaultDayStart
        : _roundUpToLattice(startFloorMinutes).clamp(defaultDayStart, dayEnd);

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
    // D-02: round the post-window cursor up to the next 30-minute boundary —
    // a commitment's own anchoredStartMinutes/endMinutes are never rounded
    // (D-01), but the FREE SLOT it opens is, so the off-lattice offset does
    // not cascade through every discretionary chunk placed in that slot for
    // the rest of the day. Trade-off: up to 29 idle minutes can now sit
    // between a commitment's end and the next work chunk. This wrap is a
    // no-op on the defensive `cursor > w.end` clamp branch — that cursor is
    // already lattice-aligned.
    final slots = <({int start, int end})>[];
    int cursor = dayStart;
    for (final w in windows) {
      if (cursor < w.start) {
        slots.add((start: cursor, end: w.start));
      }
      cursor = _roundUpToLattice(cursor > w.end ? cursor : w.end);
    }
    slots.add((start: cursor, end: dayEnd));

    // Greedily pack discretionary chunks into free slots.
    //
    // WR-01: this packing pass is the SINGLE source of truth for the long-break
    // cadence. For each placed chunk we record, on the chunk itself, the exact
    // break footprint reserved after it (reservedBreakMinutes — 5 for an
    // ordinary cell, 35 for a cadence-boundary cell) so STEP C decodes that
    // same footprint into the matching break chunk(s) instead of recomputing
    // the cadence with an independent counter that could diverge.
    //
    // INVARIANT (LATTICE-01): every cursor a discretionary chunk is placed
    // from is ≡ 0 (mod 30). A full or partial footprint reservation already
    // lands the cursor on a 30-minute boundary (25 + 5, or 25 + 35), so the
    // realignment below is a no-op in those cases; it exists for the one
    // remaining case — the chunk's break didn't fit at all — which would
    // otherwise leave the cursor at S+25 and put the next chunk off-lattice.
    int discIdx = 0;
    int breakCount = 0;
    for (final slot in slots) {
      cursor = slot.start;
      while (cursor + 25 <= slot.end && discIdx < discretionaryChunks.length) {
        discretionaryChunks[discIdx].syntheticStartMinutes = cursor;
        cursor += 25;
        breakCount++;
        // isBoundary selects a footprint, not a duration: an ordinary chunk
        // reserves only its own 5-minute short break; a cadence-boundary
        // chunk additively reserves that same short break PLUS a separate
        // 30-minute long-break cell (never replacing the short break).
        final isBoundary = breakCount % longBreakEvery == 0;
        final breakFootprint =
            _shortBreakMinutes + (isBoundary ? _longBreakMinutes : 0);
        // Reserve the break footprint whenever it fits — reservation no
        // longer depends on whether more discretionary chunks remain (D-05):
        // the long break must never be silently suppressed just because it
        // would land last.
        if (cursor + breakFootprint <= slot.end) {
          discretionaryChunks[discIdx].reservedBreakMinutes = breakFootprint;
          cursor += breakFootprint;
        } else if (cursor + _shortBreakMinutes <= slot.end) {
          // IN-01: for a non-boundary chunk, breakFootprint already equals
          // _shortBreakMinutes, so this elif is unreachable there — it only
          // has effect when isBoundary is true and the full 35-minute
          // footprint didn't fit.
          // Partial-reservation fallback: the full footprint doesn't fit,
          // but the chunk's own short break does. The Nth chunk still
          // closes its own cell even when the slot has no room left for a
          // separate long-break cell. This is the one remaining,
          // capacity-driven case where a long break does not appear — a
          // genuine "no room before the slot ends", not a suppression rule.
          // Proven bounded by RED-PROOF 6 (NARROW vs CONTROL fixtures).
          discretionaryChunks[discIdx].reservedBreakMinutes =
              _shortBreakMinutes;
          cursor += _shortBreakMinutes;
        }
        cursor = _roundUpToLattice(cursor);
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
