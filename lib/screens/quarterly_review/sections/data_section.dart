import 'package:flutter/material.dart';

import '../../../data/models/goal.dart';
import '../../schedule/widgets/chunk_card.dart';
import '../widgets/bar_chart_weekly.dart';
import '../widgets/donut_chart.dart';

/// Section 1 of the quarterly review: hero stat, donut chart, bar chart,
/// top-3 goals, and a "Next: Reflect" button.
///
/// All data is pre-aggregated and passed in — no async calls here.
class DataSection extends StatelessWidget {
  const DataSection({
    super.key,
    required this.totalCompleted,
    required this.goalChunkTotals,
    required this.notSpentCount,
    required this.weeklyData,
    required this.goals,
    required this.onNext,
  });

  /// Total completed chunks for the quarter.
  final int totalCompleted;

  /// Completed chunk counts per goalId.
  final Map<String, int> goalChunkTotals;

  /// Count of skipped + deferred chunks ("Time not spent").
  final int notSpentCount;

  /// Map from ISO Monday date key -> completed chunk count for bar chart.
  final Map<String, int> weeklyData;

  /// Active goals for chart legend and top-3 display.
  final List<Goal> goals;

  /// Called when user taps "Next: Reflect".
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Top 3 goals by chunk count, descending
    final sortedGoals = goals.toList()
      ..sort(
        (a, b) =>
            (goalChunkTotals[b.id] ?? 0).compareTo(goalChunkTotals[a.id] ?? 0),
      );
    final top3 = sortedGoals.take(3).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero stat
          const SizedBox(height: 32),
          Center(
            child: Text(
              '$totalCompleted',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 48,
              ),
            ),
          ),
          Center(
            child: Text(
              'chunks completed this quarter',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Donut chart
          DonutChart(
            goalChunkTotals: goalChunkTotals,
            notSpentCount: notSpentCount,
            goals: goals,
          ),
          const SizedBox(height: 24),

          // Weekly bar chart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WeeklyBarChart(weeklyData: weeklyData),
          ),
          const SizedBox(height: 24),

          // Top 3 goals by time
          if (top3.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'By goal',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...top3.map((goal) {
              final count = goalChunkTotals[goal.id] ?? 0;
              final color = goal.color != null
                  ? hexToColor(goal.color!)
                  : theme.colorScheme.primary;
              return SizedBox(
                height: 48,
                child: ListTile(
                  leading: CircleAvatar(radius: 6, backgroundColor: color),
                  title: Text(goal.name),
                  trailing: Text(
                    '$count chunks',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }),
          ],

          // Next button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
            child: ElevatedButton(
              onPressed: onNext,
              child: const Text('Next: Reflect'),
            ),
          ),
        ],
      ),
    );
  }
}
