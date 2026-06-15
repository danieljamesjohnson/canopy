import 'package:flutter/material.dart';
import '../../../data/models/energy_valence.dart';
import '../../../data/models/goal.dart';
import '../../../utils/time_format.dart';

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
    final pw = goal.priorityWeight ?? 0.5;
    final showPriorityChip = pw >= 0.75 || pw <= 0.25;

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
                          // Title row: icon + emoji (optional) + name + color swatch
                          Row(
                            children: [
                              Icon(
                                _typeIcon(goal.goalType),
                                size: 16,
                                color: goalColor,
                              ),
                              const SizedBox(width: 6),
                              if (goal.emojiTag != null) ...[
                                Text(
                                  goal.emojiTag!,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 4),
                              ],
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
                          // Priority chip + valence badge in secondary row (GOALS-02, ENERGY-04a)
                          if (secondary != null ||
                              showPriorityChip ||
                              goal.energyValence != EnergyValence.neutral) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (secondary != null)
                                  Expanded(
                                    child: Text(
                                      secondary,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                if (showPriorityChip)
                                  _PriorityChip(
                                    priorityWeight: goal.priorityWeight ?? 0.5,
                                  ),
                                if (goal.energyValence !=
                                    EnergyValence.neutral) ...[
                                  const SizedBox(width: 4),
                                  _ValenceBadge(valence: goal.energyValence),
                                ],
                              ],
                            ),
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

/// File-private valence badge widget for GoalCard (ENERGY-04a).
///
/// Renders a colored container chip with an icon and label for 'gives' and
/// 'costs' valence. Returns [SizedBox.shrink] for neutral — neutral is never
/// shown here (caller guards with != EnergyValence.neutral, but we double-guard
/// for safety). Display-only — no tap handlers.
/// Uses tertiaryContainer (gives) and secondaryContainer (costs) — never the error slot.
class _ValenceBadge extends StatelessWidget {
  const _ValenceBadge({required this.valence});

  final EnergyValence valence;

  @override
  Widget build(BuildContext context) {
    if (valence == EnergyValence.neutral) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final IconData icon;
    final Color chipColor;
    final Color onColor;
    final String label;

    if (valence == EnergyValence.gives) {
      icon = Icons.bolt;
      chipColor = colorScheme.tertiaryContainer;
      onColor = colorScheme.onTertiaryContainer;
      label = 'Gives';
    } else {
      // costs
      icon = Icons.hourglass_empty;
      chipColor = colorScheme.secondaryContainer;
      onColor = colorScheme.onSecondaryContainer;
      label = 'Costs';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(8),
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

/// File-private priority chip widget for GoalCard (GOALS-02).
///
/// Renders a colored container chip with an icon and label for Low (0.25) and
/// High (0.75) priority tiers. Returns [SizedBox.shrink] for Normal (0.5) or
/// any value between 0.25 and 0.75. Display-only — no tap handlers.
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
            style: textTheme.labelMedium?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
