import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/energy_valence.dart';
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
    this.goalPriorityWeight,
    this.goalEmojiTag,
    this.goalValence,
    this.onTap,
    this.showStartTime = true,
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

  /// The goal's priority weight (0.25=Low, 0.5=Normal, 0.75=High). Null or
  /// 0.5 → no badge shown. Used to render the _PriorityChip badge below the
  /// clock-time line. Pass null for commitment chunks (goalId == null).
  final double? goalPriorityWeight;

  /// The goal's emoji tag (single emoji). Null → no emoji prefix in title.
  /// Pass null for commitment chunks (goalId == null).
  final String? goalEmojiTag;

  /// The goal's energy valence. Null or neutral → no chip shown.
  /// Pass null for commitment chunks (goalId == null).
  final EnergyValence? goalValence;

  /// Tap callback for opening the detail sheet. Only wired for non-resolved
  /// work chunks from the screen; null for break cards and resolved chunks.
  final VoidCallback? onTap;

  /// When false, the clock-time range is suppressed in favor of the
  /// duration fallback ("N min") even when [chunk.displayStartMinutes] is
  /// set — used inside the unified Today screen's time gutter (D-06), where
  /// the start time is already shown in the row's gutter column so showing
  /// it again here would be redundant. Defaults to true so every existing
  /// call site (schedule_screen.dart's plain list) is unaffected.
  final bool showStartTime;

  @override
  Widget build(BuildContext context) {
    switch (chunk.chunkType) {
      case ChunkType.shortBreak:
      case ChunkType.longBreak:
        return _buildBreak(context);
      case ChunkType.work:
        return _WorkChunkContent(
          chunk: chunk,
          goalColor: goalColor,
          goalName: goalName,
          displayRationale: displayRationale,
          goalPriorityWeight: goalPriorityWeight,
          goalEmojiTag: goalEmojiTag,
          goalValence: goalValence,
          onTap: onTap,
          showStartTime: showStartTime,
        );
    }
  }

  /// D-06: breaks read transparent with a dashed outline, never a filled
  /// Card — they are not achievements, so no bold title and no emoji.
  /// Replaces the old _buildShortBreak/_buildLongBreak pair, which used a
  /// filled surfaceContainerHighest pill and a coffee-emoji Card
  /// respectively; both are superseded by this single dashed treatment.
  Widget _buildBreak(BuildContext context) {
    final theme = Theme.of(context);
    final title = chunk.chunkType == ChunkType.shortBreak
        ? 'Short break'
        : 'Long break';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: theme.colorScheme.outlineVariant),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${chunk.durationMinutes} min',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (chunk.isCompleted) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// File-private dashed-outline painter for the D-06 break-row treatment
/// (~12dp corner radius, ~1dp stroke, ~4dp dash / ~4dp gap).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const double _radius = 12;
  static const double _dashWidth = 4;
  static const double _dashGap = 4;
  static const double _strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Internal widget for the work-variant chunk card.
///
/// SCHED-03: Action buttons (Complete/Skip) are always visible — no hover
/// required. MouseRegion is retained only for cursor change on desktop.
///
/// SCHED-01: Shows clock-time range "START – END" as secondary text when
/// `chunk.displayStartMinutes` is set AND `showStartTime` is true; falls
/// back to duration ("N min") otherwise.
class _WorkChunkContent extends StatelessWidget {
  const _WorkChunkContent({
    required this.chunk,
    this.goalColor,
    this.goalName,
    this.displayRationale,
    this.goalPriorityWeight,
    this.goalEmojiTag,
    this.goalValence,
    this.onTap,
    this.showStartTime = true,
  });

  final ScheduledChunk chunk;
  final Color? goalColor;
  final String? goalName;
  final String? displayRationale;
  final double? goalPriorityWeight;
  final String? goalEmojiTag;
  final EnergyValence? goalValence;
  final VoidCallback? onTap;
  final bool showStartTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCommitment = chunk.commitmentId != null;
    final isResolved = chunk.isCompleted || chunk.isSkipped;
    final contentOpacity = isResolved ? 0.5 : 1.0;
    final barColor = isResolved
        ? theme.colorScheme.outlineVariant
        : (goalColor ?? theme.colorScheme.primary);

    final cardColor = isCommitment
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.surfaceContainer;
    final cardShape = isCommitment
        ? const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide.none,
          )
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: cardColor,
          shape: cardShape,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Colored left bar — commitments read anchored (D-06), so no
              // discretionary-goal-color bar is drawn for them.
              if (!isCommitment)
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
                padding: EdgeInsets.only(left: isCommitment ? 0 : 4),
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
                                    '${goalEmojiTag != null ? "$goalEmojiTag " : ""}'
                                    '${goalName ?? (chunk.rationale.isNotEmpty ? chunk.rationale : "Work block")}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          decoration: isResolved
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // SCHED-01: Clock-time range or duration
                                  // fallback — gated on showStartTime so the
                                  // 46dp gutter (D-06) doesn't duplicate it.
                                  if (chunk.displayStartMinutes != null &&
                                      showStartTime) ...[
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
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${chunk.durationMinutes} min',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
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
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                  // Priority badge below rationale (GOALS-02).
                                  if (goalPriorityWeight != null &&
                                      goalPriorityWeight != 0.5) ...[
                                    const SizedBox(height: 4),
                                    _PriorityChip(
                                      priorityWeight: goalPriorityWeight!,
                                    ),
                                  ],
                                  // Valence chip after priority badge (ENERGY-04b).
                                  if (goalValence != null &&
                                      goalValence != EnergyValence.neutral) ...[
                                    const SizedBox(height: 4),
                                    _ValenceChip(valence: goalValence!),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            chunk.isCompleted
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                  )
                                : chunk.isSkipped
                                ? Text(
                                    'skipped',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
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
                                      color: theme.colorScheme.error,
                                    ),
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

/// File-private valence chip widget for ChunkCard (ENERGY-04b).
///
/// Visual duplicate of _ValenceBadge in goal_card.dart — intentionally
/// file-private per the existing _PriorityChip duplication pattern.
/// Uses tertiaryContainer (gives) and secondaryContainer (costs).
/// Neutral → SizedBox.shrink (caller already guards, but we double-guard).
class _ValenceChip extends StatelessWidget {
  const _ValenceChip({required this.valence});

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

/// File-private priority badge widget (GOALS-02).
///
/// Renders a small chip showing an arrow icon + label for Low (0.25) and
/// High (0.75) priorities. Display-only — no tap handlers.
/// Intentionally duplicated from goal_card.dart for file-disjoint parallelism
/// (UI-SPEC §Component Inventory item 3).
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
