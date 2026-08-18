import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/energy_valence.dart';
import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/schedule_notifier.dart';
import '../../../utils/time_format.dart';

/// Phase 26 (CAL-01) row content density. `ChunkCard` renders three distinct
/// content sets depending on how much vertical room its (now duration-sized,
/// per D-02) slot allocates — but the CONTENT degrades, never the box: no
/// branch here ever floors, ceilings, or clamps a widget's height.
enum ChunkCardDensity {
  /// Today's card, byte-for-byte unchanged. Renders every field: title,
  /// clock-time range, rationale, priority chip, valence chip, action row.
  /// This is the default — every existing call site (four standalone
  /// `chunk_card_*_test.dart` files covering GOALS-02/ENERGY-04b, plus every
  /// screen that pumps `ChunkCard` without an explicit `density`) keeps
  /// exactly today's behaviour (PD-4, `26-02-PLAN.md`).
  detailed,

  /// The UI-SPEC's "Full" tier (`26-UI-SPEC.md` § "Row content density"):
  /// title + clock-time range + the Complete/Skip action row. Drops the
  /// rationale line, the priority chip, and the valence chip — all three
  /// stay reachable through `ChunkDetailSheet`, unchanged. Asked for by
  /// `today_screen.dart` starting in plan 04, not this plan.
  full,

  /// The UI-SPEC's "Compact" tier: title only (single line, ellipsis). No
  /// time text, no rationale, no chips, no action row — Complete/Skip are
  /// reached via the row's own tap into `ChunkDetailSheet`. Asked for by
  /// `today_screen.dart` starting in plan 04, not this plan.
  compact,
}

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
    this.density = ChunkCardDensity.detailed,
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

  /// Phase 26 (CAL-01) row content density. Defaults to [ChunkCardDensity.detailed]
  /// — today's card, unchanged — so this parameter is purely additive.
  final ChunkCardDensity density;

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
          density: density,
        );
    }
  }

  /// D-06: breaks read transparent with a dashed outline, never a filled
  /// Card — they are not achievements, so no bold title and no emoji.
  /// Replaces the old _buildShortBreak/_buildLongBreak pair, which used a
  /// filled surfaceContainerHighest pill and a coffee-emoji Card
  /// respectively; both are superseded by this single dashed treatment.
  ///
  /// UAT G-02: a long break scales up in weight within that same dashed
  /// vocabulary — taller padding, a heavier title style, a leading icon and
  /// a thicker outline — so a 25-minute break visibly outweighs a 5-minute
  /// one. No new interaction is added; the standing collapse/accordion
  /// prohibition (carried from 22-02) stays in force.
  Widget _buildBreak(BuildContext context) {
    final theme = Theme.of(context);
    final isLong = chunk.chunkType == ChunkType.longBreak;
    final title = isLong ? 'Long break' : 'Short break';

    // Compact tier (density-driven, CAL-01): label only, no leading icon,
    // no duration text, no completed check icon — D-02 forbids inflating the
    // box, so at a 5-minute break's 27.5px slot the only lever is content.
    if (density == ChunkCardDensity.compact) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: theme.colorScheme.outlineVariant,
            strokeWidth: 1,
            dashWidth: 2,
            dashGap: 2,
            radius: 6,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Center(
              child: Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // detailed / full — today's unchanged treatment (measured 80.0px for a
    // long break, fits its 137.5px slot at kPixelsPerMinute).
    final titleStyle = isLong
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          )
        : theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: theme.colorScheme.outlineVariant,
          strokeWidth: isLong ? 1.5 : 1,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isLong ? 24 : 12,
          ),
          child: Row(
            children: [
              if (isLong) ...[
                Icon(
                  Icons.self_improvement,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
              ],
              Text(title, style: titleStyle),
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
///
/// [strokeWidth] defaults to the original 1dp; a long break (G-02) passes
/// 1.5 for a slightly heavier outline within the same dashed vocabulary.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1,
    this.dashWidth = 4,
    this.dashGap = 4,
    this.radius = 12,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.dashGap != dashGap ||
      oldDelegate.radius != radius;
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
    this.density = ChunkCardDensity.detailed,
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

  /// Phase 26 (CAL-01/PD-4). Defaults to [ChunkCardDensity.detailed] — every
  /// branch below changes CONTENT only; the Card/Stack wrapper, the coloured
  /// left bar, the commitment tertiaryContainer treatment and the resolved
  /// Opacity(0.5) rule are shared by all three densities and never resized.
  final ChunkCardDensity density;

  String get _titleText =>
      '${goalEmojiTag != null ? "$goalEmojiTag " : ""}'
      '${goalName ?? (chunk.rationale.isNotEmpty ? chunk.rationale : "Work block")}';

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

    // Vertical padding tightens as the tier gets denser (D-02: the box is
    // never inflated to make room — only its content's padding changes).
    // `full` sits at 8 rather than `detailed`'s 12 for the same reason it
    // puts the time on the title line: it is the tier laid out against a
    // duration-proportional slot, so every dp here is a dp kPixelsPerMinute
    // must pay for on every row of the day.
    final contentPadding = switch (density) {
      ChunkCardDensity.compact => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      ChunkCardDensity.full => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      ChunkCardDensity.detailed => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
    };

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
                    padding: contentPadding,
                    child: switch (density) {
                      ChunkCardDensity.compact => _buildCompactContent(
                        context,
                        theme,
                        isResolved,
                      ),
                      ChunkCardDensity.full => _buildFullContent(
                        context,
                        theme,
                        isResolved,
                      ),
                      ChunkCardDensity.detailed => _buildDetailedContent(
                        context,
                        theme,
                        isResolved,
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Today's unchanged content: title, clock-time-or-duration, rationale,
  /// priority chip, valence chip, trailing status/action row.
  Widget _buildDetailedContent(
    BuildContext context,
    ThemeData theme,
    bool isResolved,
  ) {
    return _buildContentShell(
      context,
      theme,
      isResolved,
      extras: [
        // Rationale below clock time when present.
        if (goalName != null &&
            displayRationale != null &&
            displayRationale!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            displayRationale!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        // Priority badge below rationale (GOALS-02).
        if (goalPriorityWeight != null && goalPriorityWeight != 0.5) ...[
          const SizedBox(height: 4),
          _PriorityChip(priorityWeight: goalPriorityWeight!),
        ],
        // Valence chip after priority badge (ENERGY-04b).
        if (goalValence != null && goalValence != EnergyValence.neutral) ...[
          const SizedBox(height: 4),
          _ValenceChip(valence: goalValence!),
        ],
      ],
    );
  }

  /// UI-SPEC "Full" tier (26-02-PLAN.md PD-4): title + clock-time range +
  /// action row (or status icon). Rationale, priority chip and valence chip
  /// are suppressed — all three remain reachable via ChunkDetailSheet.
  Widget _buildFullContent(
    BuildContext context,
    ThemeData theme,
    bool isResolved,
  ) {
    return _buildContentShell(context, theme, isResolved);
  }

  /// Shared shell for the `detailed` and `full` densities (WR-02,
  /// `26-REVIEW.md`): title, clock-time-or-duration fallback, trailing
  /// status, and (for unresolved chunks) the action row. [extras] renders
  /// immediately after the time/duration text and before the trailing
  /// status column — empty for `full`; the rationale line, priority chip,
  /// and valence chip (in that order) for `detailed`. Do not add a
  /// density-specific branch here — anything that differs between the two
  /// tiers belongs in the caller's `extras` list, not in this shell.
  Widget _buildContentShell(
    BuildContext context,
    ThemeData theme,
    bool isResolved, {
    List<Widget> extras = const [],
  }) {
    // SCHED-01: clock-time range, or a duration fallback — gated on
    // showStartTime so the time gutter (D-06) doesn't duplicate it.
    final timeText = chunk.displayStartMinutes != null && showStartTime
        ? formatTimeRange(
            chunk.displayStartMinutes!,
            chunk.displayStartMinutes! + chunk.durationMinutes,
          )
        : '${chunk.durationMinutes} min';
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      decoration: isResolved ? TextDecoration.lineThrough : null,
    );
    final timeStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // `full` puts the time on the title's own line; `detailed` stacks it
    // underneath. This is the one place the two tiers may diverge in the
    // shared shell (WR-02 otherwise routes differences through `extras`),
    // because it is a height decision, not a content one: `full` is the tier
    // laid out against a duration-proportional slot, so ~18dp of stacked
    // second line is 18dp that kPixelsPerMinute has to pay for on EVERY row.
    // `detailed` is used by the schedule screen, which is a plain list with
    // no such budget, so it keeps the roomier stack.
    final isFull = density == ChunkCardDensity.full;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: isFull
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            _titleText,
                            style: titleStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(timeText, style: timeStyle),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _titleText,
                          style: titleStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(timeText, style: timeStyle),
                        ...extras,
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            _buildTrailingStatus(theme),
          ],
        ),
        // SCHED-03: Always-visible action row for unresolved chunks.
        // Resolved chunks show status icon only (no buttons).
        if (!isResolved) ...[
          SizedBox(height: isFull ? 8 : 12),
          _buildActionRow(context, theme),
        ],
      ],
    );
  }

  /// UI-SPEC "Compact" tier: title only. No time text, no rationale, no
  /// chips, no action row — Complete/Skip live in ChunkDetailSheet, reached
  /// via the row's own tap ([onTap] is still wired by the caller). The
  /// trailing status indicator stays ONLY for a resolved chunk (T-26-02):
  /// dropping it for an unresolved chunk removes an empty icon slot; keeping
  /// it for a resolved one avoids a completed chunk reading as unresolved.
  Widget _buildCompactContent(
    BuildContext context,
    ThemeData theme,
    bool isResolved,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            _titleText,
            style: theme.textTheme.bodyMedium?.copyWith(
              decoration: isResolved ? TextDecoration.lineThrough : null,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (isResolved) ...[const SizedBox(width: 8), _buildTrailingStatus(theme)],
      ],
    );
  }

  /// Shared trailing status: completed check icon, skipped label, or (for
  /// unresolved chunks) the unchecked radio icon. Unchanged across densities
  /// except that compact only calls this for a resolved chunk.
  Widget _buildTrailingStatus(ThemeData theme) {
    return chunk.isCompleted
        ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
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
          );
  }

  /// Shared Complete/Skip action row (SCHED-03), unchanged across densities.
  Widget _buildActionRow(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Tooltip(
          message: 'Complete',
          child: FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Complete'),
            onPressed: () =>
                context.read<ScheduleNotifier>().markComplete(chunk.id),
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
                context.read<ScheduleNotifier>().markSkipped(chunk.id),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
          ),
        ),
      ],
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
