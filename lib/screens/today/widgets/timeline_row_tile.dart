import 'package:flutter/material.dart';

import '../../../utils/time_format.dart';

/// Width of the time gutter reserved on the left of every timeline row
/// (D-06's ~46px time column).
const double kGutterWidth = 46.0;

/// D-06's ~46dp time gutter, and explicitly NOT D-04's rejected vertical
/// rail: no connector line, no dot, no continuous stroke down the gutter.
/// Anyone adding one is re-opening a rejected sketch variant.
///
/// Reserves a fixed-width left column holding the row's compact start time
/// (or nothing, when [startMinutes] is null — the gutter stays reserved,
/// not collapsed, so every row's content still starts at the same
/// horizontal offset), then lays out [child] beside it.
class TimelineRowTile extends StatelessWidget {
  const TimelineRowTile({
    super.key,
    required this.startMinutes,
    required this.child,
  });

  /// Minutes-from-midnight for the row's start time. Null renders no time
  /// text but still reserves the gutter width.
  final int? startMinutes;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Tabular figures deliver the column alignment the UI-SPEC's "monospace"
    // is actually buying — no monospace font asset ships with the app, and
    // adding one would be a new dependency for a single text style. The
    // platform monospace family is used where it exists via the fallback
    // list; tabularFigures does the real work everywhere else.
    final gutterStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontFamilyFallback: const ['monospace', 'RobotoMono', 'Courier New'],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: kGutterWidth,
          child: startMinutes != null
              ? Text(formatMinutesCompact(startMinutes!), style: gutterStyle)
              : const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }
}
