import 'package:flutter/material.dart';

import '../../../utils/time_format.dart';
import '../timeline_geometry.dart';
import 'timeline_row_tile.dart';

/// A persistent hour-boundary label plus a quiet hairline, positioned by
/// the caller at an arithmetic pixel offset (26-UI-SPEC.md "The time
/// gutter becomes an hour axis").
///
/// The `52dp` label column reuses [kGutterWidth] verbatim (unchanged
/// constant, new role) so the axis column lines up with
/// [TimelineRowTile]'s reserved column in Layer 1's row content. Purely
/// decorative — the call site wraps this widget in `IgnorePointer`; it
/// adds no `Semantics` of its own.
class HourAxisLine extends StatelessWidget {
  const HourAxisLine({super.key, required this.hourMinutes});

  /// Minutes-from-midnight of the hour boundary this line labels.
  final int hourMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: kHourAxisHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: kGutterWidth,
              child: Text(
                formatHourLabel(hourMinutes),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
