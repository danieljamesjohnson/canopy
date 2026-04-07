import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../data/models/goal.dart';
import '../../../providers/goals_notifier.dart';
import '../../schedule/widgets/chunk_card.dart';

/// Donut chart showing per-goal chunk proportions and a "Time not spent" slice.
///
/// No touch interaction (D-01). Uses [centerSpaceRadius] = 60 for donut effect.
/// Legend rows shown below the chart (one row per goal + "Time not spent").
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.goalChunkTotals,
    required this.notSpentCount,
    required this.goals,
  });

  final Map<String, int> goalChunkTotals;
  final int notSpentCount;
  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlineVariant = theme.colorScheme.outlineVariant;
    final surface = theme.colorScheme.surface;

    // Build section data + legend entries
    final sections = <PieChartSectionData>[];
    final legendEntries = <({Color color, String label, double pct})>[];

    // Total value for percentage calculation
    final totalValue = goalChunkTotals.values.fold<int>(0, (a, b) => a + b) +
        notSpentCount;

    for (var i = 0; i < goals.length; i++) {
      final goal = goals[i];
      final count = goalChunkTotals[goal.id] ?? 0;
      final color = _colorForGoal(goal, i);
      final pct = totalValue > 0 ? count / totalValue * 100 : 0.0;

      sections.add(PieChartSectionData(
        value: count.toDouble(),
        color: color,
        radius: 50,
        showTitle: false,
      ));
      legendEntries.add((color: color, label: goal.name, pct: pct));
    }

    // "Time not spent" slice
    final notSpentPct =
        totalValue > 0 ? notSpentCount / totalValue * 100 : 0.0;
    sections.add(PieChartSectionData(
      value: notSpentCount.toDouble(),
      color: outlineVariant,
      radius: 50,
      showTitle: false,
    ));
    legendEntries.add(
        (color: outlineVariant, label: 'Time not spent', pct: notSpentPct));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 60,
              centerSpaceColor: surface,
              sectionsSpace: 2,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: legendEntries
                .map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 6, backgroundColor: e.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.label,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${e.pct.toStringAsFixed(0)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Color _colorForGoal(Goal goal, int index) {
    if (goal.color != null) return hexToColor(goal.color!);
    const palette = GoalsNotifier.colorPalette;
    return Color(
        int.parse(palette[index % palette.length].replaceFirst('#', '0xFF')));
  }
}
