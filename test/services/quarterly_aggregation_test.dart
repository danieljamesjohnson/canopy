import 'package:flutter_test/flutter_test.dart';
import 'package:canopy/services/quarterly_aggregation_service.dart';
import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/quarterly_snapshot.dart';

// Helper to create a CompletionLog without Hive
CompletionLog _log({
  required String goalId,
  required String dateYmd,
  required CompletionEvent event,
  String chunkId = 'chunk-1',
}) {
  return CompletionLog(
    chunkId: chunkId,
    goalId: goalId,
    dateYmd: dateYmd,
    eventIndex: event.index,
  );
}

// Helper to create a QuarterlySnapshot without Hive
QuarterlySnapshot _snapshot({
  required String periodStartYmd,
  required String periodEndYmd,
  required DateTime completedAt,
}) {
  return QuarterlySnapshot(
    periodStartYmd: periodStartYmd,
    periodEndYmd: periodEndYmd,
  )..completedAt = completedAt;
}

void main() {
  final service = QuarterlyAggregationService();

  group('completedByGoal', () {
    test('returns per-goal completed counts in range', () {
      final logs = [
        _log(goalId: 'goalA', dateYmd: '2026-01-01', event: CompletionEvent.completed),
        _log(goalId: 'goalA', dateYmd: '2026-01-02', event: CompletionEvent.completed),
        _log(goalId: 'goalA', dateYmd: '2026-01-03', event: CompletionEvent.completed),
        _log(goalId: 'goalB', dateYmd: '2026-01-04', event: CompletionEvent.completed),
        _log(goalId: 'goalA', dateYmd: '2026-01-05', event: CompletionEvent.skipped),
      ];

      final result = service.completedByGoal(logs, '2026-01-01', '2026-01-31');

      expect(result['goalA'], equals(3));
      expect(result['goalB'], equals(1));
    });

    test('excludes logs outside date range', () {
      final logs = [
        _log(goalId: 'goalA', dateYmd: '2025-12-31', event: CompletionEvent.completed),
        _log(goalId: 'goalA', dateYmd: '2026-01-01', event: CompletionEvent.completed),
        _log(goalId: 'goalA', dateYmd: '2026-01-31', event: CompletionEvent.completed),
        _log(goalId: 'goalA', dateYmd: '2026-02-01', event: CompletionEvent.completed),
      ];

      final result = service.completedByGoal(logs, '2026-01-01', '2026-01-31');

      expect(result['goalA'], equals(2));
    });

    test('returns empty map for empty logs', () {
      final result = service.completedByGoal([], '2026-01-01', '2026-01-31');
      expect(result, isEmpty);
    });
  });

  group('completedByWeek', () {
    test('returns per-week counts keyed by Monday ISO date', () {
      // Week 1: Mon 2026-01-05
      // Week 2: Mon 2026-01-12
      // Week 3: Mon 2026-01-19
      final logs = [
        _log(goalId: 'g1', dateYmd: '2026-01-06', event: CompletionEvent.completed), // Tue W1
        _log(goalId: 'g1', dateYmd: '2026-01-07', event: CompletionEvent.completed), // Wed W1
        _log(goalId: 'g1', dateYmd: '2026-01-12', event: CompletionEvent.completed), // Mon W2
        _log(goalId: 'g1', dateYmd: '2026-01-14', event: CompletionEvent.completed), // Wed W2
        _log(goalId: 'g1', dateYmd: '2026-01-19', event: CompletionEvent.completed), // Mon W3
      ];

      final result = service.completedByWeek(logs, '2026-01-01', '2026-01-31');

      expect(result['2026-01-05'], equals(2)); // W1
      expect(result['2026-01-12'], equals(2)); // W2
      expect(result['2026-01-19'], equals(1)); // W3
    });

    test('skipped and deferred logs are not counted in completedByWeek', () {
      final logs = [
        _log(goalId: 'g1', dateYmd: '2026-01-06', event: CompletionEvent.completed),
        _log(goalId: 'g1', dateYmd: '2026-01-06', event: CompletionEvent.skipped),
        _log(goalId: 'g1', dateYmd: '2026-01-06', event: CompletionEvent.deferred),
      ];

      final result = service.completedByWeek(logs, '2026-01-01', '2026-01-31');

      expect(result['2026-01-05'], equals(1));
    });
  });

  group('notSpentCount', () {
    test('counts skipped and deferred in range', () {
      final logs = [
        _log(goalId: 'g1', dateYmd: '2026-01-01', event: CompletionEvent.skipped),
        _log(goalId: 'g1', dateYmd: '2026-01-02', event: CompletionEvent.deferred),
        _log(goalId: 'g1', dateYmd: '2026-01-03', event: CompletionEvent.skipped),
        _log(goalId: 'g1', dateYmd: '2026-01-04', event: CompletionEvent.completed),
        _log(goalId: 'g1', dateYmd: '2026-01-05', event: CompletionEvent.completed),
        _log(goalId: 'g1', dateYmd: '2026-01-06', event: CompletionEvent.completed),
      ];

      final result = service.notSpentCount(logs, '2026-01-01', '2026-01-31');

      expect(result, equals(3));
    });

    test('excludes logs outside date range', () {
      final logs = [
        _log(goalId: 'g1', dateYmd: '2025-12-31', event: CompletionEvent.skipped),
        _log(goalId: 'g1', dateYmd: '2026-01-01', event: CompletionEvent.skipped),
        _log(goalId: 'g1', dateYmd: '2026-01-31', event: CompletionEvent.deferred),
        _log(goalId: 'g1', dateYmd: '2026-02-01', event: CompletionEvent.skipped),
      ];

      final result = service.notSpentCount(logs, '2026-01-01', '2026-01-31');

      expect(result, equals(2));
    });
  });

  group('totalCompleted', () {
    test('returns total completed count in range', () {
      final logs = [
        _log(goalId: 'g1', dateYmd: '2026-01-01', event: CompletionEvent.completed),
        _log(goalId: 'g2', dateYmd: '2026-01-02', event: CompletionEvent.completed),
        _log(goalId: 'g1', dateYmd: '2026-01-03', event: CompletionEvent.skipped),
        _log(goalId: 'g1', dateYmd: '2026-01-04', event: CompletionEvent.deferred),
      ];

      final result = service.totalCompleted(logs, '2026-01-01', '2026-01-31');

      expect(result, equals(2));
    });
  });

  group('isInReviewWindow', () {
    test('returns true when within 7 days before 90-day mark from last snapshot', () {
      final snapshot = _snapshot(
        periodStartYmd: '2025-10-01',
        periodEndYmd: '2025-12-31',
        completedAt: DateTime.utc(2026, 1, 1),
      );
      // 90 days after 2026-01-01 = 2026-04-01
      // Within 7 days before = 2026-03-25 to 2026-04-01
      final now = DateTime.utc(2026, 3, 27);

      final result = service.isInReviewWindow(
        latestSnapshot: snapshot,
        allLogs: [],
        now: now,
      );

      expect(result, isTrue);
    });

    test('returns false when outside the 7-day window before 90-day mark', () {
      final snapshot = _snapshot(
        periodStartYmd: '2025-10-01',
        periodEndYmd: '2025-12-31',
        completedAt: DateTime.utc(2026, 1, 1),
      );
      // 90 days after 2026-01-01 = 2026-04-01
      // Before 7-day window
      final now = DateTime.utc(2026, 3, 20);

      final result = service.isInReviewWindow(
        latestSnapshot: snapshot,
        allLogs: [],
        now: now,
      );

      expect(result, isFalse);
    });

    test('falls back to earliest CompletionLog date when no snapshot exists', () {
      final logs = [
        _log(goalId: 'g1', dateYmd: '2026-01-05', event: CompletionEvent.completed),
        _log(goalId: 'g1', dateYmd: '2026-01-01', event: CompletionEvent.completed),
        _log(goalId: 'g1', dateYmd: '2026-01-10', event: CompletionEvent.completed),
      ];
      // Earliest log: 2026-01-01, 90 days after = 2026-04-01
      // Within 7 days before = 2026-03-25 to 2026-04-01
      final now = DateTime.utc(2026, 3, 28);

      final result = service.isInReviewWindow(
        latestSnapshot: null,
        allLogs: logs,
        now: now,
      );

      expect(result, isTrue);
    });

    test('returns false when no logs and no snapshot exist', () {
      final result = service.isInReviewWindow(
        latestSnapshot: null,
        allLogs: [],
        now: DateTime.utc(2026, 3, 28),
      );

      expect(result, isFalse);
    });

    test('returns true within 30 days after the 90-day mark', () {
      final snapshot = _snapshot(
        periodStartYmd: '2025-10-01',
        periodEndYmd: '2025-12-31',
        completedAt: DateTime.utc(2026, 1, 1),
      );
      // 90 days after 2026-01-01 = 2026-04-01
      // 30 days after = 2026-05-01
      final now = DateTime.utc(2026, 4, 15); // 14 days after mark

      final result = service.isInReviewWindow(
        latestSnapshot: snapshot,
        allLogs: [],
        now: now,
      );

      expect(result, isTrue);
    });
  });

  group('completionRateByGoal', () {
    test('returns rate = completed / total events per goal', () {
      final logs = [
        _log(goalId: 'goalA', dateYmd: '2026-01-01', event: CompletionEvent.completed),
        _log(goalId: 'goalA', dateYmd: '2026-01-02', event: CompletionEvent.completed),
        _log(goalId: 'goalA', dateYmd: '2026-01-03', event: CompletionEvent.skipped),
        _log(goalId: 'goalA', dateYmd: '2026-01-04', event: CompletionEvent.deferred),
        _log(goalId: 'goalB', dateYmd: '2026-01-05', event: CompletionEvent.completed),
      ];

      final result = service.completionRateByGoal(logs, '2026-01-01', '2026-01-31');

      // goalA: 2 completed / 4 total = 0.5
      expect(result['goalA'], closeTo(0.5, 0.001));
      // goalB: 1 completed / 1 total = 1.0
      expect(result['goalB'], closeTo(1.0, 0.001));
    });

    test('returns empty map for empty logs', () {
      final result = service.completionRateByGoal([], '2026-01-01', '2026-01-31');
      expect(result, isEmpty);
    });
  });
}
