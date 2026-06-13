import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/goals_notifier.dart';
import '../../../providers/schedule_notifier.dart';
import '../../../utils/time_format.dart';

/// Card widget displayed in the Home screen "Now" section for the current
/// (first unresolved) work chunk.
///
/// Renders the goal name, clock-time range (or duration fallback), a "Now"
/// badge, and always-visible Complete/Skip action buttons (NAV-02 / SCHED-03).
/// All colors use [ColorScheme] tokens — no hardcoded Colors references.
class ActiveChunkCard extends StatelessWidget {
  const ActiveChunkCard({
    super.key,
    required this.chunk,
  });

  final ScheduledChunk chunk;

  Color? _lookupGoalColor(BuildContext context) {
    if (chunk.goalId == null) return null;
    final goals = context.read<GoalsNotifier>().goals;
    final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
    if (goal?.color != null) return hexToColor(goal!.color!);
    return null;
  }

  String? _lookupGoalName(BuildContext context) {
    if (chunk.goalId == null) return null;
    final goals = context.read<GoalsNotifier>().goals;
    final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
    return goal?.name;
  }

  double? _lookupGoalPriorityWeight(BuildContext context) {
    if (chunk.goalId == null) return null;
    final goals = context.read<GoalsNotifier>().goals;
    final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
    return goal?.priorityWeight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalColor = _lookupGoalColor(context);
    final goalName = _lookupGoalName(context);
    final goalPriorityWeight = _lookupGoalPriorityWeight(context);
    final barColor = goalColor ?? theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Left color bar — 4dp wide (UI-SPEC §Spacing)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              goalName ??
                                  (chunk.rationale.isNotEmpty
                                      ? chunk.rationale
                                      : 'Work block'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (chunk.displayStartMinutes != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${formatTimeRange(chunk.displayStartMinutes!, chunk.displayStartMinutes! + chunk.durationMinutes)} · ${chunk.durationMinutes} min',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 2),
                              Text(
                                '${chunk.durationMinutes} min',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // "Now" badge — accent fill, onPrimary label
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Now',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Priority badge below clock-time line (GOALS-02).
                  if (goalPriorityWeight != null && goalPriorityWeight != 0.5) ...[
                    const SizedBox(height: 4),
                    _PriorityChip(priorityWeight: goalPriorityWeight),
                  ],
                  const SizedBox(height: 12),
                  // Always-visible action row (NAV-02 / SCHED-03)
                  Row(
                    children: [
                      Tooltip(
                        message: 'Complete',
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Complete'),
                          onPressed: () => context
                              .read<ScheduleNotifier>()
                              .markComplete(chunk.id),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Skip',
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.skip_next_outlined),
                          label: const Text('Skip'),
                          onPressed: () => context
                              .read<ScheduleNotifier>()
                              .markSkipped(chunk.id),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// File-private priority badge widget (GOALS-02).
///
/// Renders a small chip showing an arrow icon + label for Low (0.25) and
/// High (0.75) priorities. Display-only — no tap handlers.
/// Intentionally duplicated from goal_card.dart and chunk_card.dart for
/// file-disjoint plan parallelism (UI-SPEC §Component Inventory item 3).
class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priorityWeight});

  final double priorityWeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final IconData icon;
    final Color chipColor;
    final Color onColor;
    final String label;

    if (priorityWeight >= 0.75) {
      icon = Icons.arrow_upward;
      chipColor = colorScheme.primaryContainer;
      onColor = colorScheme.onPrimaryContainer;
      label = 'High';
    } else if (priorityWeight <= 0.25) {
      icon = Icons.arrow_downward;
      chipColor = colorScheme.surfaceContainerHighest;
      onColor = colorScheme.onSurfaceVariant;
      label = 'Low';
    } else {
      return const SizedBox.shrink(); // Normal (0.5) — no chip
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
