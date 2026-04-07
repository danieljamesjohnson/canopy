import '../data/models/completion_log.dart';
import '../data/models/quarterly_snapshot.dart';

/// Pure-Dart aggregation logic for CompletionLog data.
///
/// No Flutter imports — fully unit-testable without widget test infrastructure.
class QuarterlyAggregationService {
  /// Returns completed chunk counts per goalId for logs within [startYmd]..[endYmd] (inclusive).
  Map<String, int> completedByGoal(
    List<CompletionLog> logs,
    String startYmd,
    String endYmd,
  ) {
    final result = <String, int>{};
    for (final log in _inRange(logs, startYmd, endYmd)) {
      if (log.event == CompletionEvent.completed) {
        result[log.goalId] = (result[log.goalId] ?? 0) + 1;
      }
    }
    return result;
  }

  /// Returns completed chunk counts per ISO Monday date key for logs within range.
  ///
  /// Each log is bucketed to the Monday of its week using: date - (weekday - 1) days.
  Map<String, int> completedByWeek(
    List<CompletionLog> logs,
    String startYmd,
    String endYmd,
  ) {
    final result = <String, int>{};
    for (final log in _inRange(logs, startYmd, endYmd)) {
      if (log.event != CompletionEvent.completed) continue;
      final date = DateTime.parse(log.dateYmd);
      final monday = date.subtract(Duration(days: date.weekday - 1));
      final key = _toYmd(monday);
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  /// Returns count of skipped + deferred logs within [startYmd]..[endYmd] (inclusive).
  int notSpentCount(
    List<CompletionLog> logs,
    String startYmd,
    String endYmd,
  ) {
    return _inRange(logs, startYmd, endYmd)
        .where((l) =>
            l.event == CompletionEvent.skipped ||
            l.event == CompletionEvent.deferred)
        .length;
  }

  /// Returns count of completed logs within [startYmd]..[endYmd] (inclusive).
  int totalCompleted(
    List<CompletionLog> logs,
    String startYmd,
    String endYmd,
  ) {
    return _inRange(logs, startYmd, endYmd)
        .where((l) => l.event == CompletionEvent.completed)
        .length;
  }

  /// Returns true when [now] is within the review window.
  ///
  /// Window: 7 days before the 90-day mark up to 30 days after.
  /// - If [latestSnapshot] is non-null, the 90-day mark = completedAt + 90 days.
  /// - Else uses the earliest log dateYmd + 90 days as the mark.
  /// - Returns false if no snapshot and no logs.
  bool isInReviewWindow({
    QuarterlySnapshot? latestSnapshot,
    required List<CompletionLog> allLogs,
    DateTime? now,
  }) {
    final checkNow = now ?? DateTime.now().toUtc();

    DateTime? referenceDate;

    if (latestSnapshot != null) {
      referenceDate = latestSnapshot.completedAt;
    } else if (allLogs.isNotEmpty) {
      // Use earliest log date
      final sorted = allLogs.map((l) => l.dateYmd).toList()..sort();
      referenceDate = DateTime.parse(sorted.first);
    } else {
      return false;
    }

    final ninetyDayMark = referenceDate.add(const Duration(days: 90));
    final windowStart = ninetyDayMark.subtract(const Duration(days: 7));
    final windowEnd = ninetyDayMark.add(const Duration(days: 30));

    return !checkNow.isBefore(windowStart) && !checkNow.isAfter(windowEnd);
  }

  /// Returns completion rate per goalId: completed / (completed + skipped + deferred).
  ///
  /// Used for archive suggestion threshold (rate <= 20% suggests archiving).
  Map<String, double> completionRateByGoal(
    List<CompletionLog> logs,
    String startYmd,
    String endYmd,
  ) {
    final completed = <String, int>{};
    final total = <String, int>{};

    for (final log in _inRange(logs, startYmd, endYmd)) {
      total[log.goalId] = (total[log.goalId] ?? 0) + 1;
      if (log.event == CompletionEvent.completed) {
        completed[log.goalId] = (completed[log.goalId] ?? 0) + 1;
      }
    }

    final result = <String, double>{};
    for (final goalId in total.keys) {
      final t = total[goalId]!;
      final c = completed[goalId] ?? 0;
      result[goalId] = t > 0 ? c / t : 0.0;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Filters logs to those whose dateYmd falls within [startYmd]..[endYmd] inclusive.
  Iterable<CompletionLog> _inRange(
    List<CompletionLog> logs,
    String startYmd,
    String endYmd,
  ) {
    return logs.where(
      (l) =>
          l.dateYmd.compareTo(startYmd) >= 0 &&
          l.dateYmd.compareTo(endYmd) <= 0,
    );
  }

  String _toYmd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
