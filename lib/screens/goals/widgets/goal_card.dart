import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../data/models/energy_valence.dart';
import '../../../data/models/goal.dart';

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
///
/// **Raised 40 → 56 by the owner's ruling on `33-UAT.md` item 4(a).** At 40dp
/// the fixture's 13.9% goal rendered a ~6px speck: *"technically red and
/// practically invisible."* Height is the channel that carries a LOW value —
/// widening the track only makes a short speck a fatter speck — so the track
/// grew taller and [kGoalProgressTrackWidth] grew alongside it to keep the bar
/// from reading as a hair. 56 is bounded by the card, not chosen for looks: a
/// goal card's content is ~92dp (title row + secondary line + chip run +
/// padding) and the track is CENTRED inside it, so anything past ~64 would
/// start to look like a bar the card cannot contain.
const double kGoalProgressTrackHeight = 56.0;

/// Track width, 5 → 8 with the height rise above. Not independently motivated:
/// a 56dp × 5dp bar reads as a hairline, so the aspect ratio had to follow.
const double kGoalProgressTrackWidth = 8.0;

/// **The minimum painted fill, and the whole of item 4(c).** Two reported
/// defects share this one constant:
///
/// - *"the lines are small … red barely registers"* — 13.9% of 56dp is 7.8dp,
///   still a speck. Floored here, it is a mark.
/// - *"red when just started is invisible at exactly just-started"* — a
///   budgeted goal with nothing done is 0.0, which painted **zero height**,
///   making it identical on screen to a goal with no weekly target at all.
///   The distinction was real in the data, unit-tested, and never reached the
///   eye.
///
/// **This deliberately breaks strict proportionality at the bottom of the
/// scale**, and that is the trade the owner was offered: below ~21% every
/// value paints the same 12dp mark. It costs nothing real — the line carries a
/// three-band traffic light with **no key and no number on screen** (UI-SPEC
/// item 15), so the band is the message and the exact fraction never was. A
/// value the eye cannot see is not more honest than one it can.
///
/// **12 rather than 10, decided by looking at the rendered screen.** At 10 the
/// mark is 8dp wide and 10dp tall on a 4dp-radius track, which paints a
/// near-perfect CIRCLE — a red dot, one screen after item 4(b) deleted a
/// coloured dot from this very card for being a meaningless pip. 12 reads as a
/// stub of a bar, which is what it is.
///
/// The null case is untouched: no weekly target still paints no fill at all,
/// which is now the ONLY thing an empty track means.
const double kGoalProgressMinFill = 12.0;

/// Painted fill height for [progress], floored at [kGoalProgressMinFill] and
/// clamped to [kGoalProgressTrackHeight].
///
/// Top-level and public so the floor can be asserted **arithmetically** rather
/// than only through a rendered box. A rendered-height assertion alone passes
/// at any floor value — including a 2dp one that is still invisible, which is
/// the defect being fixed. This lets a test pin the number that was chosen,
/// not merely that some number is applied.
double goalProgressFillHeight(double progress) => math.max(
  kGoalProgressMinFill,
  kGoalProgressTrackHeight * progress.clamp(0.0, 1.0),
);

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
/// optional rank number, the name, a labelled type chip, and an optional
/// secondary stat (weekly hours or streak count).
///
/// **The progress line is the only colour on this card** (item 4(b)) — the
/// identity swatch that used to sit at the end of the title row is deleted.
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
    // `goalColor` was resolved here (`hexToColor(goal.color!)`, falling back to
    // `colorScheme.primary`) for the identity swatch deleted in the title row
    // below. Nothing on this card paints the goal's colour any more, so the
    // lookup goes with it rather than sitting unused — `hexToColor` still has
    // callers elsewhere and is untouched.
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
              // Both of these read [kGoalProgressTrackWidth] rather than
              // repeating its value: when the track widened 5 → 8 for item
              // 4(a), this Positioned and the content Padding below still said
              // 5, so the track rendered at the OLD width no matter what
              // `_ProgressLine` asked for. Caught by the rendered-width
              // assertion in `goal_card_progress_line_test.dart`, not by
              // reading the diff.
              width: kGoalProgressTrackWidth,
              child: Center(
                child: _ProgressLine(progress: widget.weekProgress),
              ),
            ),
            // Content — determines Stack size
            Padding(
              padding: const EdgeInsets.only(left: kGoalProgressTrackWidth),
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
                          // **The identity swatch is GONE — item 4(b),
                          // owner's ruling.** A 16dp filled circle in the
                          // goal's colour used to sit at the end of this row.
                          //
                          // The complaint was not that it was ugly, it was
                          // that the card carried TWO colour systems and the
                          // meaningless one was louder: the left line's colour
                          // states weekly progress, while the dot stated an
                          // identity the user never chose and cannot change
                          // (`goal.color` is auto-assigned from a palette by
                          // `GoalsNotifier.autoColor()` — there is no colour
                          // control in `goal_form_sheet.dart`). Exercise
                          // rendered a GREEN dot beside a RED line. That is
                          // the standing complaint this whole phase answers —
                          // *"the colors are changing, it's not making a ton
                          // of sense"* — reappearing one screen over.
                          //
                          // Removed rather than muted, which was the other
                          // option offered: muting keeps a meaningless mark
                          // and only makes it quieter. One colour on this
                          // card, and it means something.
                          //
                          // **Known consequence, not an oversight:** the goal
                          // colour still paints the 4dp left bar on a work
                          // chunk (`chunk_card.dart`), and this card was the
                          // only place a user could see which colour belonged
                          // to which goal. That legend is now gone. It was
                          // never a legend anyone asked for — every timeline
                          // card also carries the goal's NAME — but if a
                          // future phase wants colour-to-goal identification,
                          // this row is where it goes back.
                          //
                          // The `showHoverIcons && _hovered` gate went with
                          // it: WR-03 existed only to stop the hover icons
                          // painting over the swatch.
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
/// assert a claim the data cannot support (item 16). **A progress of exactly
/// 0.0 is NOT that case** and no longer renders like it: see
/// [kGoalProgressMinFill].
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final p = progress;

    return SizedBox(
      width: kGoalProgressTrackWidth,
      height: kGoalProgressTrackHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              key: const ValueKey('goal-progress-track'),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(
                  kGoalProgressTrackWidth / 2,
                ),
              ),
            ),
          ),
          // `p != null`, not `p > 0`: zero is a real measurement — "budgeted,
          // nothing done yet" — and the whole of item 4(c) is that it must
          // reach the screen as a red mark rather than as an empty track.
          if (p != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: kGoalProgressTrackWidth,
                height: goalProgressFillHeight(p),
                child: DecoratedBox(
                  key: const ValueKey('goal-progress-fill'),
                  decoration: BoxDecoration(
                    color: _bandColor(p),
                    borderRadius: BorderRadius.circular(
                      kGoalProgressTrackWidth / 2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
