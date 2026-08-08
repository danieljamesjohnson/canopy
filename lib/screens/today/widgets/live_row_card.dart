import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/schedule_notifier.dart';

/// The swelled in-place current-activity card (D-01, UI-SPEC "The live row").
///
/// [kicker] and [remainingLabel] are INJECTED BY THE SCREEN — Phase 23's
/// LIVE-01 ("RIGHT NOW — RESTING" for a running break) and LIVE-02 (countdown
/// granularity) own what goes into them. A future agent extends the caller
/// that builds this widget, not this widget's layout.
///
/// This card deliberately sits at its own clock position inside the day list
/// (D-01) and is never lifted into a hero region, a sticky bar (D-03), or a
/// floating pill. If a future change wants one of those, it is re-opening a
/// rejected sketch variant.
class LiveRowCard extends StatelessWidget {
  const LiveRowCard({
    super.key,
    required this.chunkId,
    required this.kicker,
    required this.title,
    required this.remainingLabel,
    required this.progress,
    this.nextLine,
    this.showActions = true,
  });

  /// The chunk this card acts on — Complete/Skip always target exactly this
  /// id (T-22-04).
  final String chunkId;

  /// Uppercase kicker line, e.g. "RIGHT NOW". Screen-injected.
  final String kicker;

  final String title;

  /// Screen-injected remaining-time copy, rendered with tabular figures.
  final String remainingLabel;

  /// 0..1 fraction of the activity's window elapsed. Values outside 0..1
  /// (an overdue chunk, a zero-duration chunk) are clamped rather than
  /// asserted (T-22-05).
  final double progress;

  /// "Next · <title> at <time>" line. Null renders nothing.
  final String? nextLine;

  /// Complete/Skip are for work chunks only (UI-SPEC "Actions row"). False
  /// hides both buttons entirely.
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final clampedProgress = progress.clamp(0.0, 1.0);

    // "Let now break the grid" (22-UI-SPEC.md "The live row", amended
    // 2026-08-08 after UAT). Zero horizontal margin + square corners means
    // this row spans the full content column while every other row is inset
    // by the time gutter — a different silhouette, not just a different fill.
    // The generous vertical margin gives it air the list rows don't get.
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: colorScheme.primaryContainer,
      elevation: 6,
      shadowColor: colorScheme.shadow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kicker.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              remainingLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.82),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clampedProgress,
                minHeight: 6,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                backgroundColor: colorScheme.onPrimaryContainer.withValues(
                  alpha: 0.16,
                ),
              ),
            ),
            if (showActions) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Tooltip(
                    message: 'Complete',
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Complete'),
                      onPressed: () => context
                          .read<ScheduleNotifier>()
                          .markComplete(chunkId),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Skip',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.skip_next_outlined),
                      label: const Text('Skip'),
                      onPressed: () =>
                          context.read<ScheduleNotifier>().markSkipped(chunkId),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (nextLine != null) ...[
              const SizedBox(height: 10),
              Text(
                nextLine!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.72),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
