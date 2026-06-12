import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../data/models/commitment_block.dart';
import '../../../data/models/goal.dart';
import '../../../providers/goals_notifier.dart';
import '../../../utils/time_format.dart';

/// Donut chart showing per-goal chunk proportions and a "Time not spent" slice.
///
/// No touch interaction (D-01). Uses [centerSpaceRadius] = 60 for donut effect.
/// Legend rows shown below the chart (one row per goal + commitment + other
/// catch-all + "Time not spent").
///
/// REVIEW-01: Every key in [goalChunkTotals] is classified against three lookup
/// sets — active goal ids, archived goal ids, and commitment block ids — with a
/// catch-all "Other" bucket for any unresolved id. This ensures all logged time
/// is drawn as a slice and percentages sum to 100%.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.goalChunkTotals,
    required this.notSpentCount,
    required this.goals,
    required this.archivedGoals,
    required this.commitmentBlocks,
  });

  final Map<String, int> goalChunkTotals;
  final int notSpentCount;

  /// Active goals (sorted by sortOrder).
  final List<Goal> goals;

  /// Archived goals that may have historical completions in the period.
  final List<Goal> archivedGoals;

  /// Commitment blocks whose ids may appear as goalChunkTotals keys.
  final List<CommitmentBlock> commitmentBlocks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlineVariant = theme.colorScheme.outlineVariant;
    final surface = theme.colorScheme.surface;

    // Build section data + legend entries
    final sections = <PieChartSectionData>[];
    final legendEntries = <({Color color, String label, double pct})>[];

    // Total value for percentage calculation.
    // goalChunkTotals.values fold covers all keys (active + archived +
    // commitment + other); adding notSpentCount yields the full denominator.
    final totalValue =
        goalChunkTotals.values.fold<int>(0, (a, b) => a + b) + notSpentCount;

    // Build lookup sets for ID resolution (O(1) contains checks).
    final commitmentIds = {for (final b in commitmentBlocks) b.id};
    final activeGoalIds = {for (final g in goals) g.id};
    final archivedGoalMap = {for (final g in archivedGoals) g.id: g};

    int commitmentTotal = 0;
    int otherTotal = 0;

    // Active goal slices (existing behavior, preserved).
    // Omit zero-value slices per UI-SPEC §Donut Chart Slice Contract.
    for (var i = 0; i < goals.length; i++) {
      final goal = goals[i];
      final count = goalChunkTotals[goal.id] ?? 0;
      if (count == 0) continue; // omit zero-value slices (UI-SPEC)
      final color = _colorForGoal(goal, i);
      final pct = totalValue > 0 ? count / totalValue * 100 : 0.0;
      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          color: color,
          radius: 50,
          showTitle: false,
        ),
      );
      legendEntries.add((color: color, label: goal.name, pct: pct));
    }

    // Classify remaining keys: accumulate commitment / other totals here.
    // Archived goals are emitted in a separate alphabetically-sorted pass below
    // so the legend order is deterministic (UI-SPEC §Legend order).
    for (final entry in goalChunkTotals.entries) {
      if (activeGoalIds.contains(entry.key)) continue; // already handled above
      if (entry.value == 0) continue; // omit zero-value slices

      if (archivedGoalMap.containsKey(entry.key)) {
        continue; // emitted in the sorted archived pass below
      } else if (commitmentIds.contains(entry.key)) {
        commitmentTotal += entry.value;
      } else {
        otherTotal += entry.value;
      }
    }

    // Archived goal slices — sorted alphabetically by name for stable legend
    // order (a HashMap iteration order would otherwise be non-deterministic).
    final archivedWithChunks =
        archivedGoals.where((g) => (goalChunkTotals[g.id] ?? 0) > 0).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    for (var i = 0; i < archivedWithChunks.length; i++) {
      final goal = archivedWithChunks[i];
      final count = goalChunkTotals[goal.id]!;
      final color = _colorForGoal(goal, goals.length + i);
      final pct = totalValue > 0 ? count / totalValue * 100 : 0.0;
      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          color: color,
          radius: 50,
          showTitle: false,
        ),
      );
      legendEntries.add((
        color: color,
        label: '${goal.name} (archived)',
        pct: pct,
      ));
    }

    // Aggregated Commitments slice — only if non-zero.
    // NOTE: 0xFF607D8B is also palette index 7; visual collision possible when
    // 8+ active goals are present — acceptable in v1 given rarity.
    if (commitmentTotal > 0) {
      const commitmentColor = Color(0xFF607D8B);
      final pct = totalValue > 0 ? commitmentTotal / totalValue * 100 : 0.0;
      sections.add(
        PieChartSectionData(
          value: commitmentTotal.toDouble(),
          color: commitmentColor,
          radius: 50,
          showTitle: false,
        ),
      );
      legendEntries.add((
        color: commitmentColor,
        label: 'Commitments',
        pct: pct,
      ));
    }

    // Other catch-all slice — only if non-zero.
    if (otherTotal > 0) {
      const otherColor = Color(0xFFBDBDBD);
      final pct = totalValue > 0 ? otherTotal / totalValue * 100 : 0.0;
      sections.add(
        PieChartSectionData(
          value: otherTotal.toDouble(),
          color: otherColor,
          radius: 50,
          showTitle: false,
        ),
      );
      legendEntries.add((color: otherColor, label: 'Other', pct: pct));
    }

    // "Time not spent" slice — guard zero per UI-SPEC (omit zero-value slices).
    if (notSpentCount > 0) {
      final notSpentPct = totalValue > 0
          ? notSpentCount / totalValue * 100
          : 0.0;
      sections.add(
        PieChartSectionData(
          value: notSpentCount.toDouble(),
          color: outlineVariant,
          radius: 50,
          showTitle: false,
        ),
      );
      legendEntries.add((
        color: outlineVariant,
        label: 'Time not spent',
        pct: notSpentPct,
      ));
    }

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
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                  ),
                )
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
      int.parse(palette[index % palette.length].replaceFirst('#', '0xFF')),
    );
  }
}
