import 'package:flutter/material.dart';

import '../../../data/models/goal.dart';

/// A list tile for the goal adjustments section.
///
/// Shows a left color bar, goal name, and a drag handle. When [showArchivePrompt]
/// is true, an inline archive suggestion appears below the main row via
/// [AnimatedSwitcher].
class GoalAdjustmentTile extends StatelessWidget {
  const GoalAdjustmentTile({
    super.key,
    required this.goal,
    required this.goalColor,
    required this.index,
    this.completionRate,
    this.showArchivePrompt = false,
    this.onArchive,
    this.onKeep,
  });

  final Goal goal;
  final Color goalColor;
  final int index;
  final double? completionRate;
  final bool showArchivePrompt;
  final VoidCallback? onArchive;
  final VoidCallback? onKeep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final mainRow = Row(
      children: [
        // Left color bar
        Container(width: 5, height: 56, color: goalColor),
        const SizedBox(width: 12),
        Expanded(child: Text(goal.name, style: theme.textTheme.bodyMedium)),
        // Drag handle — wrapped in ReorderableDelayedDragStartListener
        ReorderableDelayedDragStartListener(
          index: index,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.drag_handle, color: theme.colorScheme.outline),
          ),
        ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: mainRow,
        ),
        // Archive prompt (animated in/out)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeIn,
          child: showArchivePrompt
              ? Padding(
                  key: const ValueKey('archive_prompt'),
                  padding: const EdgeInsets.only(left: 17, right: 8, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'This one rarely made it in \u2014 archive it?',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        onPressed: onArchive,
                        child: const Text('Archive'),
                      ),
                      TextButton(onPressed: onKeep, child: const Text('Keep')),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('no_prompt')),
        ),
      ],
    );
  }
}
