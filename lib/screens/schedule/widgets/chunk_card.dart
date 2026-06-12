import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/schedule_notifier.dart';
import '../../../utils/time_format.dart';

/// A card widget that renders one of three visual variants depending on
/// [chunk.chunkType]: work, shortBreak, or longBreak.
class ChunkCard extends StatelessWidget {
  const ChunkCard({
    super.key,
    required this.chunk,
    this.goalColor,
    this.goalName,
    this.displayRationale,
    this.onTap,
  });

  final ScheduledChunk chunk;

  /// The goal's color for the left bar. Null → falls back to theme primary.
  /// Pass null for commitment-anchored work chunks (no goalId).
  final Color? goalColor;

  /// The resolved goal name to display as the primary title. Null → falls
  /// back to chunk.rationale. Only relevant for work chunks.
  final String? goalName;

  /// Pre-mapped human-readable rationale (e.g. 'Daily habit'). Displayed as
  /// secondary bodySmall text beneath the clock time. Only relevant for work
  /// chunks when goalName is non-null.
  final String? displayRationale;

  /// Tap callback for opening the detail sheet. Only wired for non-resolved
  /// work chunks from the screen; null for break cards and resolved chunks.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    switch (chunk.chunkType) {
      case ChunkType.shortBreak:
        return _buildShortBreak(context);
      case ChunkType.longBreak:
        return _buildLongBreak(context);
      case ChunkType.work:
        return _WorkChunkContent(
          chunk: chunk,
          goalColor: goalColor,
          goalName: goalName,
          displayRationale: displayRationale,
          onTap: onTap,
        );
    }
  }

  Widget _buildShortBreak(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.pause,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '${chunk.durationMinutes} min break',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongBreak(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('☕', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              '${chunk.durationMinutes} min break',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal widget for the work-variant chunk card.
///
/// SCHED-03: Action buttons (Complete/Skip) are always visible — no hover
/// required. MouseRegion is retained only for cursor change on desktop.
///
/// SCHED-01: Shows clock-time range "START – END" as secondary text when
/// `chunk.displayStartMinutes` is set; falls back to duration ("N min").
class _WorkChunkContent extends StatelessWidget {
  const _WorkChunkContent({
    required this.chunk,
    this.goalColor,
    this.goalName,
    this.displayRationale,
    this.onTap,
  });

  final ScheduledChunk chunk;
  final Color? goalColor;
  final String? goalName;
  final String? displayRationale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = chunk.isCompleted || chunk.isSkipped
        ? Colors.grey.shade400
        : (goalColor ?? theme.colorScheme.primary);
    final contentOpacity = chunk.isCompleted || chunk.isSkipped ? 0.5 : 1.0;
    final isResolved = chunk.isCompleted || chunk.isSkipped;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Colored left bar
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Opacity(
                  opacity: contentOpacity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    goalName ??
                                        (chunk.rationale.isNotEmpty
                                            ? chunk.rationale
                                            : 'Work block'),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // SCHED-01: Clock-time range or duration fallback.
                                  if (chunk.displayStartMinutes != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      formatTimeRange(
                                        chunk.displayStartMinutes!,
                                        chunk.displayStartMinutes! +
                                            chunk.durationMinutes,
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${chunk.durationMinutes} min',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                  // Rationale below clock time when present.
                                  if (goalName != null &&
                                      displayRationale != null &&
                                      displayRationale!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      displayRationale!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            chunk.isCompleted
                                ? Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade600,
                                  )
                                : chunk.isSkipped
                                ? Icon(
                                    Icons.arrow_forward,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  )
                                : Icon(
                                    Icons.radio_button_unchecked,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                          ],
                        ),
                        // SCHED-03: Always-visible action row for unresolved chunks.
                        // Resolved chunks show status icon only (no buttons).
                        if (!isResolved) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Tooltip(
                                message: 'Complete',
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Complete'),
                                  onPressed: () => context
                                      .read<ScheduleNotifier>()
                                      .markComplete(chunk.id),
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
                                  onPressed: () => context
                                      .read<ScheduleNotifier>()
                                      .markSkipped(chunk.id),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: theme.colorScheme.error,
                                    side: BorderSide(
                                        color: theme.colorScheme.error),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
