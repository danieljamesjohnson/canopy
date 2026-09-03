import '../data/models/completion_log.dart';
import '../data/models/goal.dart';
import 'schedule_generator.dart';

/// Pure Dart service — no Flutter imports, no async, no side effects.
///
/// Answers one question for the Goals screen: *how far into this week's target
/// is this goal?* The answer is **read** from the append-only [CompletionLog],
/// never stored and never computed anew from a second source of truth
/// (UI-SPEC item 19).
///
/// The chunks-to-hours conversion is the engine's own: this class sources the
/// chunk length from [ScheduleGeneratorService.workChunkMinutes] rather than
/// re-typing it. That constant was already made public with a live external
/// consumer (`ScheduleNotifier._reflowDiscretionaryWork`) for exactly this
/// reason, so sharing it here needs no change to the generator — which the
/// ROADMAP fences off from modification (UI-SPEC items 20-21). WR-03's
/// 25-vs-30 long-break drift is what two independent declarations of one value
/// cost last time.
///
/// Returns `null`, not `0.0`, wherever the model has nothing to measure
/// against. The distinction is load-bearing for the UI: `0.0` is a real "just
/// started" (a red line), while `null` is "this goal has no weekly target" (an
/// empty grey track). Collapsing them would make the screen assert something
/// the data cannot support.
class WeeklyProgressService {
  const WeeklyProgressService();

  /// Returns the **date-only** Monday of the week containing [date].
  ///
  /// **Now a delegation, and that is the point — SEED-006 closed 2026-09-03.**
  /// This method used to carry its own (correct) implementation alongside a
  /// long doc comment explaining that `ScheduleGeneratorService._weekStart`
  /// was *not* correct and must not be aligned to. That divergence is gone:
  /// the generator's helper is fixed and public, and this one forwards to it,
  /// so the Goals screen's progress line and the scheduler's budget
  /// arithmetic now share one definition of where a week starts.
  ///
  /// **Kept as a named method rather than deleted** so this service's callers
  /// and tests keep reading a week boundary from the service they already
  /// depend on. The dependency direction is unchanged — this file already
  /// imports the generator for [ScheduleGeneratorService.workChunkMinutes],
  /// which is the same IN-01 "share the source of truth" precedent.
  static DateTime weekStart(DateTime date) =>
      ScheduleGeneratorService.weekStart(date);

  /// Completed logs for [goalId] within Monday..[today], both ends inclusive.
  ///
  /// The filter matches the generator's shape, including filtering on
  /// `goalId` rather than `CompletionLog.attributionId` — commitment logs
  /// carry `goalId == ''` and so fall out naturally, and cannot leak into a
  /// goal's progress line (T-33-05).
  ///
  /// [CompletionLog.dateYmd] is parsed unguarded, the same trust assumption
  /// the generator and `QuarterlyAggregationService` already make of this
  /// in-app-written field (T-33-04).
  Iterable<CompletionLog> _completedThisWeek(
    String goalId,
    List<CompletionLog> logs,
    DateTime today,
  ) {
    final start = weekStart(today);
    final end = DateTime(today.year, today.month, today.day);
    return logs.where((l) {
      if (l.goalId != goalId) return false;
      if (l.event != CompletionEvent.completed) return false;
      final logDate = DateTime.parse(l.dateYmd);
      return !logDate.isBefore(start) && !logDate.isAfter(end);
    });
  }

  /// Number of completed chunks this week for [goalId].
  int completedChunksThisWeek(
    String goalId,
    List<CompletionLog> logs,
    DateTime today,
  ) => _completedThisWeek(goalId, logs, today).length;

  /// Number of **distinct days** this week on which [goalId] was completed.
  ///
  /// Habits are measured in days, not chunks, so two completions on one day
  /// are one day.
  int completedDaysThisWeek(
    String goalId,
    List<CompletionLog> logs,
    DateTime today,
  ) => _completedThisWeek(
    goalId,
    logs,
    today,
  ).map((l) => l.dateYmd).toSet().length;

  /// Completed hours this week for [goalId].
  ///
  /// The only chunks-to-hours conversion in this file, and the chunk length
  /// comes from the generator's constant.
  double completedHoursThisWeek(
    String goalId,
    List<CompletionLog> logs,
    DateTime today,
  ) =>
      completedChunksThisWeek(goalId, logs, today) *
      ScheduleGeneratorService.workChunkMinutes /
      60.0;

  /// Progress through this week's target for [goal], in `0.0..1.0`, or `null`
  /// when the model carries no target to measure against.
  ///
  /// - `outcome` → always `null`. The model holds only `deadline` and
  ///   `outcomeDescription` for outcomes, so any fraction would be invented
  ///   state (UI-SPEC item 16).
  /// - `timeTarget` → completed hours over `weeklyHourBudget`, or `null` when
  ///   that budget is absent or non-positive.
  /// - `habit` → distinct done-days over `frequencyPerWeek`, which defaults to
  ///   7 (daily) exactly as the model documents.
  double? weekFractionFor(Goal goal, List<CompletionLog> logs, DateTime today) {
    switch (goal.goalType) {
      case GoalType.outcome:
        return null;
      case GoalType.timeTarget:
        final budget = goal.weeklyHourBudget;
        if (budget == null || budget <= 0) return null;
        return (completedHoursThisWeek(goal.id, logs, today) / budget).clamp(
          0.0,
          1.0,
        );
      case GoalType.habit:
        final freq = goal.frequencyPerWeek ?? 7;
        if (freq <= 0) return null;
        return (completedDaysThisWeek(goal.id, logs, today) / freq).clamp(
          0.0,
          1.0,
        );
    }
  }
}
