import 'package:flutter/material.dart';

/// The quiet current-moment row (NOW-01, 24-UI-SPEC.md "The Now-Marker").
///
/// Not a [Card] — same tier as [FreeTimeRow], deliberately not competing
/// with `LiveRowCard`. Renders a solid leading rule, the literal "Now"
/// label, and a fading trailing rule, all in `colorScheme.primary`. Carries
/// no horizontal inset of its own — the caller wraps it in
/// `TimelineRowTile`, which owns the 16dp inset and the time gutter.
///
/// Carries no accessibility-node wrapper of its own — the call site applies
/// a single labeled, merged announcement node around this widget
/// (24-UI-SPEC.md), so a screen reader user gets one clean announcement
/// instead of the double-silence regression of the deleted pre-merge widget.
class NowMarker extends StatelessWidget {
  const NowMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 24, height: 2, color: color),
          const SizedBox(width: 8),
          Text(
            'Now',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: 2, color: color.withValues(alpha: 0.35)),
          ),
        ],
      ),
    );
  }
}
