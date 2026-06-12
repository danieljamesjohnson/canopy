import 'package:flutter/material.dart';

/// Thin visual divider with a "Now" label inserted before the first unresolved
/// work chunk in ScheduleScreen's ListView.
///
/// Decorative only — wrapped in ExcludeSemantics. All colors from
/// Theme.of(context).colorScheme.primary (no hardcoded values).
class NowMarker extends StatelessWidget {
  const NowMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 1,
              color: color.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              'Now',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: Container(height: 1, color: color.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
