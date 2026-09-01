// Phase 33 (OBVIOUS-02, UI-SPEC items 19-21) — weekly progress from CompletionLog
//
// Written RED first, before `WeeklyProgressService` existed, and observed failing.
// Pure-service test file: plain `test()`, no widget pump — same shape as
// test/services/quarterly_aggregation_test.dart.
//
// Every hours/fraction expectation is expressed through
// `ScheduleGeneratorService.workChunkMinutes` rather than as a bare literal. A
// hard-coded decimal for "six chunks in hours" could not distinguish a shared
// constant from a re-typed chunk length, which is what UI-SPEC item 21 forbids.

import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/services/schedule_generator.dart';
import 'package:canopy/services/weekly_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

CompletionLog _log(
  String goalId,
  DateTime date, {
  CompletionEvent event = CompletionEvent.completed,
  String? commitmentId,
}) => CompletionLog(
  chunkId: 'chunk-${_ymd(date)}-$goalId',
  goalId: goalId,
  commitmentId: commitmentId,
  dateYmd: _ymd(date),
  eventIndex: event.index,
);

Goal _goal({
  String id = 'g1',
  GoalType type = GoalType.timeTarget,
  double? budget,
  int? freq,
}) => Goal(
  id: id,
  name: 'goal $id',
  goalTypeIndex: type.index,
  weeklyHourBudget: budget,
  frequencyPerWeek: freq,
);

/// Hours for [chunks] chunks, derived from the engine's own constant so this
/// expectation cannot be satisfied by a re-typed 25 hiding in the service.
double _hours(int chunks) =>
    chunks * ScheduleGeneratorService.workChunkMinutes / 60.0;

void main() {
  const service = WeeklyProgressService();

  // Fixed calendar so nothing here is clock-dependent.
  // 2026-08-31 is a Monday; 2026-09-02 is a Wednesday.
  final monday = DateTime(2026, 8, 31);
  final today = DateTime(2026, 9, 2, 14, 30); // Wednesday afternoon
  // Every fixture date is derived from the one Monday anchor above.
  DateTime day(int offsetFromMonday) =>
      monday.add(Duration(days: offsetFromMonday));

  group('weekStart', () {
    test('normalises to the date-only Monday of a mid-week afternoon', () {
      expect(WeeklyProgressService.weekStart(today), equals(monday));
    });

    test('a Monday afternoon maps to that same Monday at midnight', () {
      expect(
        WeeklyProgressService.weekStart(day(0).add(const Duration(hours: 16))),
        equals(monday),
      );
    });

    test('a Sunday maps back to the Monday six days earlier', () {
      expect(
        WeeklyProgressService.weekStart(day(6).add(const Duration(hours: 23))),
        equals(monday),
      );
    });
  });

  group('completedChunksThisWeek', () {
    test('counts completed logs for the goal inside this week', () {
      final logs = [_log('g1', day(1)), _log('g1', day(1)), _log('g1', day(2))];

      expect(service.completedChunksThisWeek('g1', logs, today), equals(3));
    });

    test('skipped and deferred logs are not counted', () {
      final logs = [
        _log('g1', day(1)),
        _log('g1', day(1), event: CompletionEvent.skipped),
        _log('g1', day(2), event: CompletionEvent.deferred),
      ];

      expect(service.completedChunksThisWeek('g1', logs, today), equals(1));
    });

    test("another goal's completions are not counted toward this goal", () {
      final logs = [_log('g1', day(1)), _log('g2', day(1)), _log('g2', day(2))];

      expect(service.completedChunksThisWeek('g1', logs, today), equals(1));
    });

    test(
      'commitment logs fall out — the filter is goalId, not attributionId',
      () {
        // A commitment log carries goalId '' and the block id in commitmentId, so
        // its attributionId is 'c1'. Filtering on attributionId would count it
        // under 'c1'; filtering on goalId (what the generator does) cannot.
        final logs = [_log('', day(1), commitmentId: 'c1')];

        expect(service.completedChunksThisWeek('c1', logs, today), equals(0));
        expect(service.completedChunksThisWeek('g1', logs, today), equals(0));
      },
    );

    test('lower edge: the Sunday before this week is excluded', () {
      final logs = [_log('g1', day(-1)), _log('g1', day(0))];

      expect(service.completedChunksThisWeek('g1', logs, today), equals(1));
    });

    test(
      'Monday is inclusive even when today carries a non-midnight time-of-day',
      () {
        // The boundary this helper exists to get right. `today` is Wednesday
        // 14:30 and the log parses to Monday 00:00. The generator's un-normalised
        // _weekStart would drop this (see WeeklyProgressService.weekStart docs).
        final logs = [_log('g1', day(0))];

        expect(service.completedChunksThisWeek('g1', logs, today), equals(1));
      },
    );

    test('upper edge: a log dated tomorrow is excluded', () {
      final logs = [_log('g1', day(2)), _log('g1', day(3))];

      expect(service.completedChunksThisWeek('g1', logs, today), equals(1));
    });

    test('an empty log list is zero chunks', () {
      expect(service.completedChunksThisWeek('g1', const [], today), equals(0));
    });
  });

  group('completedDaysThisWeek', () {
    test('counts distinct dates, so two logs on one day are one day', () {
      final logs = [_log('g1', day(0)), _log('g1', day(0)), _log('g1', day(1))];

      expect(service.completedDaysThisWeek('g1', logs, today), equals(2));
    });
  });

  group('completedHoursThisWeek', () {
    test('converts chunks to hours with the engine\'s own chunk length', () {
      final logs = [for (var i = 0; i < 6; i++) _log('g1', day(i % 3))];

      expect(
        service.completedHoursThisWeek('g1', logs, today),
        closeTo(_hours(6), 1e-9),
      );
    });
  });

  group('weekFractionFor — timeTarget', () {
    test('is completed hours over the weekly budget', () {
      final goal = _goal(budget: 4.0);
      final logs = [for (var i = 0; i < 6; i++) _log(goal.id, day(i % 3))];

      // 0.625 at the current 25-minute chunk, but stated through the constant.
      expect(
        service.weekFractionFor(goal, logs, today),
        closeTo(_hours(6) / 4.0, 1e-9),
      );
    });

    test('clamps to 1.0 when the budget is exceeded', () {
      final goal = _goal(budget: 4.0);
      final logs = [for (var i = 0; i < 20; i++) _log(goal.id, day(i % 3))];

      expect(service.weekFractionFor(goal, logs, today), equals(1.0));
    });

    test('is null when weeklyHourBudget is null — no target to measure', () {
      final goal = _goal();
      final logs = [_log(goal.id, day(1))];

      expect(service.weekFractionFor(goal, logs, today), isNull);
    });

    test('is null when weeklyHourBudget is zero', () {
      final goal = _goal(budget: 0.0);

      expect(service.weekFractionFor(goal, const [], today), isNull);
    });

    test('is 0.0 (not null) with a real budget and no completions', () {
      // 0.0 is "just started" — a real red bar. null is "nothing to measure".
      final goal = _goal(budget: 4.0);

      expect(service.weekFractionFor(goal, const [], today), equals(0.0));
    });
  });

  group('weekFractionFor — outcome', () {
    test('is always null, even with completed logs (UI-SPEC item 16)', () {
      final goal = _goal(type: GoalType.outcome);
      final logs = [_log(goal.id, day(0)), _log(goal.id, day(1))];

      expect(service.weekFractionFor(goal, logs, today), isNull);
    });
  });

  group('weekFractionFor — habit', () {
    test('is distinct done-days over frequencyPerWeek', () {
      final goal = _goal(type: GoalType.habit, freq: 5);
      final logs = [
        _log(goal.id, day(0)),
        _log(goal.id, day(0)), // same day — must not count twice
        _log(goal.id, day(1)),
      ];

      expect(service.weekFractionFor(goal, logs, today), closeTo(2 / 5, 1e-9));
    });

    test('a null frequencyPerWeek defaults to 7, so seven days is 1.0', () {
      // Anchored on the Sunday of the same week so all seven days are in-window.
      final sunday = day(6).add(const Duration(hours: 20));
      final goal = _goal(type: GoalType.habit);
      final logs = [for (var i = 0; i < 7; i++) _log(goal.id, day(i))];

      expect(service.weekFractionFor(goal, logs, sunday), equals(1.0));
    });

    test('clamps to 1.0 when done-days exceed the frequency', () {
      final goal = _goal(type: GoalType.habit, freq: 2);
      final logs = [
        _log(goal.id, day(0)),
        _log(goal.id, day(1)),
        _log(goal.id, day(2)),
      ];

      expect(service.weekFractionFor(goal, logs, today), equals(1.0));
    });
  });
}
