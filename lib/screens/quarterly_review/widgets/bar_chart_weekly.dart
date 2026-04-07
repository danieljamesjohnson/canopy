import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Bar chart showing completed chunks per ISO week over the quarter.
///
/// [weeklyData] maps Monday ISO date keys (e.g. "2026-01-06") to chunk counts.
/// Bars are sorted by date ascending. Week axis labels use "Jan 6" format.
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({
    super.key,
    required this.weeklyData,
  });

  final Map<String, int> weeklyData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sort entries by date key ascending
    final sortedEntries = weeklyData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final weekLabels = sortedEntries
        .map((e) => DateFormat('MMM d').format(DateTime.parse(e.key)))
        .toList();

    final barGroups = sortedEntries.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.value.toDouble(),
            color: theme.colorScheme.primary,
            width: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barGroups: barGroups,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= weekLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    weekLabels[idx],
                    style: const TextStyle(fontSize: 9),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
