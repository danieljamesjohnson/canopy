import 'package:flutter/material.dart';
import '../../../data/models/energy_valence.dart';
import '../../../data/models/goal.dart';
import '../../../utils/time_format.dart';

/// Fixed height of the goal card's left progress track, in logical pixels.
///
/// **This constant is the whole of UI-SPEC item 18.** The track lives inside a
/// `Positioned(top: 0, bottom: 0)` whose height is set by the [Stack], i.e. by
/// the card's own content — and card heights vary with the secondary line and
/// the chip run. A fill expressed as a *fraction of that* makes a 90% line on a
/// short card render shorter in real pixels than a 62% line on a tall one,
/// which is the defect the sketch found. The eye compares pixels, not
/// percentages, so the fill is `kGoalProgressTrackHeight * progress` and never
/// a fraction of the card. Do not reintroduce `FractionallySizedBox` here and
/// do not tie the fill to the card's height by any other route.
const double kGoalProgressTrackHeight = 40.0;

/// Red/yellow/green is a universally-read scale and is deliberately NOT
/// sourced from the mood-seeded ColorScheme: `ColorScheme.fromSeed` moves
/// every role with the seed, and mood 5's yellow seed (#E8C547) would make a
/// theme-derived "green" and "yellow" nearly indistinguishable — which is
/// exactly the legibility failure this line exists to fix. There is no key on
/// screen (UI-SPEC item 15), so the scale must carry itself in every mood.
const Color _kProgressRed = Color(0xFFE53935);
const Color _kProgressAmber = Color(0xFFFFB300);
const Color _kProgressGreen = Color(0xFF43A047);

/// Band boundaries, verbatim from the owner via UI-SPEC item 14: *"red when
/// just started, yellow when below 70%, 70% and above green."*
Color _bandColor(double progress) {
  if (progress < 0.20) return _kProgressRed;
  if (progress < 0.70) return _kProgressAmber;
  return _kProgressGreen;
}

/// The single source of the goal-type icon mapping, read by [_TypeChip].
IconData _typeIcon(GoalType type) {
  switch (type) {
    case GoalType.timeTarget:
      return Icons.access_time_outlined;
    case GoalType.outcome:
      return Icons.flag_outlined;
    case GoalType.habit:
      return Icons.repeat_outlined;
  }
}

/// Plain-language type labels. A chip is a glyph **and** a word, never a bare
/// glyph (UI-SPEC items 29-30).
String _typeLabel(GoalType type) {
  switch (type) {
    case GoalType.timeTarget:
      return 'Regular time';
    case GoalType.outcome:
      return 'Working toward';
    case GoalType.habit:
      return 'Daily habit';
  }
}

/// A Material Card displaying a goal with a left-hand weekly-progress line, an
/// optional rank number, the name, an identity swatch, a labelled type chip,
/// and an optional secondary stat (weekly hours or streak count).
///
/// When [trailing] is null and the pointer hovers (desktop), the hover-revealed
/// edit + archive icons fade in via [AnimatedOpacity] (120ms easeOut). On mobile
/// (Android/iOS) pointer events never fire `onHover`, so the icons stay at
/// opacity 0 — preserving touch UX. When a caller supplies [trailing] (e.g.
/// the drag handle from `GoalsScreen`'s ReorderableListView), the hover icons
/// are NOT shown; the trailing slot is exclusively used.
class GoalCard extends StatefulWidget {
  const GoalCard({
    super.key,
    required this.goal,
    this.rank,
    this.weekProgress,
    this.trailing,
    this.onTap,
    this.onEdit,
    this.onArchive,
  });

  final Goal goal;

  /// 1-based position in the priority order; null renders no rank gutter.
  ///
  /// Optional because `archived_goals_screen.dart` builds a [GoalCard] with
  /// neither of the two new parameters, and an archived list is not a priority
  /// order.
  final int? rank;

  /// Progress through this week's target in `0.0..1.0`, or null when the model
  /// carries no target to measure against.
  ///
  /// Null and `0.0` are a real distinction and must not be collapsed: null is
  /// "no weekly target" (an outcome goal — an empty grey track, never red,
  /// UI-SPEC item 16), while `0.0` is a budgeted goal with nothing done yet.
  final double? weekProgress;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// Hover-revealed "Edit goal" affordance (desktop). Null disables the icon.
  final VoidCallback? onEdit;

  /// Hover-revealed "Archive goal" affordance (desktop). Null disables the icon.
  final VoidCallback? onArchive;

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  bool _hovered = false;

  String? _secondaryLine(Goal g) {
    switch (g.goalType) {
      case GoalType.timeTarget:
        if (g.weeklyHourBudget != null) {
          return '${g.weeklyHourBudget!.toStringAsFixed(1)} hrs/week';
        }
        return null;
      case GoalType.habit:
        if (g.streakCount > 0) {
          return '${g.streakCount}-day streak';
        }
        return null;
      case GoalType.outcome:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = widget.goal;
    final goalColor = goal.color != null
        ? hexToColor(goal.color!)
        : theme.colorScheme.primary;
    final secondary = _secondaryLine(goal);
    final showHoverIcons = widget.trailing == null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        onHover: (hovered) => setState(() => _hovered = hovered),
        child: Stack(
          children: [
            // Weekly progress line (UI-SPEC item 13). This Positioned is
            // still sized by the Stack — i.e. by content — so the track it
            // holds is CENTRED at a fixed height rather than stretched.
            // See kGoalProgressTrackHeight for why (item 18).
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: Center(
                child: _ProgressLine(progress: widget.weekProgress),
              ),
            ),
            // Content — determines Stack size
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Row(
                children: [
                  // Rank gutter, on the LEADING side: `trailing` holds the
                  // drag handle and `showHoverIcons` keys off it, so a rank in
                  // the trailing slot would silently kill the hover icons.
                  if (widget.rank != null)
                    SizedBox(
                      width: 32,
                      child: Center(
                        child: Text(
                          '${widget.rank}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title row: emoji (optional) + name + color swatch.
                          // The bare 16dp type glyph that used to lead this
                          // row is gone — an unlabelled glyph in an identity
                          // colour is precisely the shape UI-SPEC item 30
                          // forbids. It is now the labelled _TypeChip below.
                          Row(
                            children: [
                              if (goal.emojiTag != null) ...[
                                Text(
                                  goal.emojiTag!,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  goal.name,
                                  style: theme.textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // WR-03: hide the color swatch on hover so the
                              // hover-revealed edit + archive IconButtons
                              // (~96dp wide, painted by the Positioned stack
                              // child below) do not paint over the swatch.
                              // Without this gate the swatch silently
                              // disappears under the icons on hover; with the
                              // gate the swatch fades out as the icons fade
                              // in, keeping the right-edge readable.
                              if (showHoverIcons && _hovered)
                                const SizedBox(width: 16, height: 16)
                              else
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: goalColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          // Secondary stat on its own line — it no longer
                          // shares a row, so no Expanded.
                          if (secondary != null) ...[
                            const SizedBox(height: 4),
                            Text(secondary, style: theme.textTheme.bodySmall),
                          ],
                          // Chip run. The type chip is unconditional, so every
                          // card carries one (ENERGY-04a keeps the valence
                          // badge conditional). Priority is carried by the
                          // rank number alone now (UI-SPEC item 17).
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              _TypeChip(type: goal.goalType),
                              if (goal.energyValence != EnergyValence.neutral)
                                _ValenceBadge(valence: goal.energyValence),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  ?widget.trailing,
                ],
              ),
            ),
            // Hover-revealed edit + archive icons (desktop only — onHover
            // never fires on touch-only mobile pointer events, so this stays
            // at opacity 0 on Android/iOS). Suppressed when a trailing
            // widget is supplied (e.g. the drag handle from GoalsScreen).
            if (showHoverIcons)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit goal',
                        onPressed: _hovered ? widget.onEdit : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.archive_outlined),
                        tooltip: 'Archive goal',
                        onPressed: _hovered ? widget.onArchive : null,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// File-private valence badge widget for GoalCard (ENERGY-04a).
///
/// Renders a colored container chip with an icon and label for 'gives' and
/// 'costs' valence. Returns [SizedBox.shrink] for neutral — neutral is never
/// shown here (caller guards with != EnergyValence.neutral, but we double-guard
/// for safety). Display-only — no tap handlers.
/// Uses tertiaryContainer (gives) and secondaryContainer (costs) — never the error slot.
class _ValenceBadge extends StatelessWidget {
  const _ValenceBadge({required this.valence});

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

/// File-private goal-type chip for GoalCard (UI-SPEC item 12).
///
/// Deliberately duplicates [_ValenceBadge]'s geometry rather than extracting a
/// shared chip widget: file-private chips per file is this codebase's recorded
/// convention (see the same note on `chunk_card.dart`'s own chips). Neutral
/// container role — the type is a label, not a signal, and the one strong
/// colour on this card belongs to [_ProgressLine].
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final GoalType type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final onColor = colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_typeIcon(type), size: 12, color: onColor),
          const SizedBox(width: 4),
          Text(
            _typeLabel(type),
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

/// File-private weekly-progress line for GoalCard (UI-SPEC items 13-18).
///
/// A grey track of [kGoalProgressTrackHeight] logical pixels holding a fill
/// that grows **bottom-up** to `kGoalProgressTrackHeight * progress`. The
/// geometry is fixed on purpose: see [kGoalProgressTrackHeight].
///
/// A null [progress] renders the bare grey track and no fill at all — the
/// model has no weekly target to measure against, so a coloured line would
/// assert a claim the data cannot support (item 16).
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final p = progress;

    return SizedBox(
      width: 5,
      height: kGoalProgressTrackHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              key: const ValueKey('goal-progress-track'),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          if (p != null && p > 0)
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 5,
                height: kGoalProgressTrackHeight * p.clamp(0.0, 1.0),
                child: DecoratedBox(
                  key: const ValueKey('goal-progress-fill'),
                  decoration: BoxDecoration(
                    color: _bandColor(p),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
