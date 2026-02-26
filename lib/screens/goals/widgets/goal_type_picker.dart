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
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor =
        isSelected ? colorScheme.primaryContainer : null;
    final borderColor =
        isSelected ? colorScheme.primary : Colors.transparent;

    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Icon(
            icon,
            color: isSelected ? colorScheme.primary : null,
          ),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      ),
    );
  }
}
