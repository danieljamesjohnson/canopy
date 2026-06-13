import 'package:flutter/material.dart';
import '../../../data/models/goal.dart';

/// A vertical stack of three cards for selecting a goal type.
/// Uses plain-language descriptions — never exposes enum names to the UI.
class GoalTypePicker extends StatelessWidget {
  const GoalTypePicker({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  final GoalType? selectedType;
  final ValueChanged<GoalType> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TypeCard(
          goalType: GoalType.timeTarget,
          icon: Icons.access_time_outlined,
          title: 'I want to spend regular time on something',
          subtitle: 'e.g. family, health, a hobby',
          isSelected: selectedType == GoalType.timeTarget,
          onTap: () => onTypeSelected(GoalType.timeTarget),
        ),
        const SizedBox(height: 8),
        _TypeCard(
          goalType: GoalType.outcome,
          icon: Icons.flag_outlined,
          title: 'I\'m working toward a specific outcome',
          subtitle: 'e.g. finish a project, reach a goal',
          isSelected: selectedType == GoalType.outcome,
          onTap: () => onTypeSelected(GoalType.outcome),
        ),
        const SizedBox(height: 8),
        _TypeCard(
          goalType: GoalType.habit,
          icon: Icons.repeat_outlined,
          title: 'I want to build a daily habit',
          subtitle: 'e.g. exercise, journaling, meditation',
          isSelected: selectedType == GoalType.habit,
          onTap: () => onTypeSelected(GoalType.habit),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.goalType,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final GoalType goalType;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = isSelected ? colorScheme.primaryContainer : null;
    final borderColor = isSelected ? colorScheme.primary : Colors.transparent;

    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minVerticalPadding: 0,
          leading: Icon(
            icon,
            size: 20,
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          title: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isSelected
                  ? colorScheme.onPrimaryContainer.withAlpha(179)
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
