import 'package:flutter/material.dart';
import '../../../data/models/goal.dart';

/// Converts a hex color string (e.g. '#4CAF50') to a Flutter Color.
Color hexToColor(String hex) {
  return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
}

/// A Material Card displaying a goal with a colored left border, type icon,
/// name, and an optional secondary stat (weekly hours or streak count).
///
/// When [trailing] is null and the pointer hovers (desktop), the hover-revealed
/// edit + archive icons fade in via [AnimatedOpacity] (120ms easeOut). On mobile
/// (Android/iOS) pointer events never fire `onHover`, so the icons stay at
/// opacity 0 — preserving touch UX. When a caller supplies [trailing] (e.g.
/// the drag handle from `GoalsScreen`'s ReorderableListView), the hover icons
/// are NOT shown; the trailing slot is exclusively used.
class GoalCard extends StatefulWidget {
  const GoalCard({
    super.key,
    required this.goal,
    this.trailing,
    this.onTap,
    this.onEdit,
    this.onArchive,
  });

  final Goal goal;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Hover-revealed "Edit goal" affordance (desktop). Null disables the icon.
  final VoidCallback? onEdit;

  /// Hover-revealed "Archive goal" affordance (desktop). Null disables the icon.
  final VoidCallback? onArchive;

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  bool _hovered = false;

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
    final goal = widget.goal;
    final goalColor = goal.color != null
        ? hexToColor(goal.color!)
        : theme.colorScheme.primary;
    final secondary = _secondaryLine(goal);
    final showHoverIcons = widget.trailing == null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        onHover: (hovered) => setState(() => _hovered = hovered),
        child: Stack(
          children: [
            // Colored left border — sized by Stack to match content height
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: goalColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
            ),
            // Content — determines Stack size
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title row: icon + name + color swatch
                          Row(
                            children: [
                              Icon(
                                _typeIcon(goal.goalType),
                                size: 16,
                                color: goalColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  goal.name,
                                  style: theme.textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // WR-03: hide the color swatch on hover so the
                              // hover-revealed edit + archive IconButtons
                              // (~96dp wide, painted by the Positioned stack
                              // child below) do not paint over the swatch.
                              // Without this gate the swatch silently
                              // disappears under the icons on hover; with the
                              // gate the swatch fades out as the icons fade
                              // in, keeping the right-edge readable.
                              if (showHoverIcons && _hovered)
                                const SizedBox(width: 16, height: 16)
                              else
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
                            Text(secondary, style: theme.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ),
                  ?widget.trailing,
                ],
              ),
            ),
            // Hover-revealed edit + archive icons (desktop only — onHover
            // never fires on touch-only mobile pointer events, so this stays
            // at opacity 0 on Android/iOS). Suppressed when a trailing
            // widget is supplied (e.g. the drag handle from GoalsScreen).
            if (showHoverIcons)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit goal',
                        onPressed: _hovered ? widget.onEdit : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.archive_outlined),
                        tooltip: 'Archive goal',
                        onPressed: _hovered ? widget.onArchive : null,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
