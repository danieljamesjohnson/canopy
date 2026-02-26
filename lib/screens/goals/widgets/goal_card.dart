import 'package:flutter/material.dart';
import '../../../data/models/goal.dart';

/// Converts a hex color string (e.g. '#4CAF50') to a Flutter Color.
Color hexToColor(String hex) {
  return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
}

/// A Material Card displaying a goal with a colored left border, type icon,
/// name, and an optional secondary stat (weekly hours or streak count).
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    this.trailing,
    this.onTap,
  });

  final Goal goal;
  final Widget? trailing;
  final VoidCallback? onTap;

  IconData _typeIcon(GoalType type) {
    switch (type) {
      case GoalType.timeTarget:
        return Icons.access_time_outlined;
      case GoalType.outcome:
        return Icons.flag_outlined;
      case GoalType.habit:
        return Icons.repeat_outlined;
    }
  }

  String? _secondaryLine(Goal g) {
    switch (g.goalType) {
      case GoalType.timeTarget:
        if (g.weeklyHourBudget != null) {
          return '${g.weeklyHourBudget!.toStringAsFixed(1)} hrs/week';
        }
        return null;
      case GoalType.habit:
        if (g.streakCount > 0) {
          return '${g.streakCount}-day streak';
        }
        return null;
      case GoalType.outcome:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalColor =
        goal.color != null ? hexToColor(goal.color!) : theme.colorScheme.primary;
    final secondary = _secondaryLine(goal);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored left border
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: goalColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title row: icon + name + color swatch
                    Row(
                      children: [
                        Icon(_typeIcon(goal.goalType), size: 16, color: goalColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            goal.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: goalColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    if (secondary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        secondary,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
