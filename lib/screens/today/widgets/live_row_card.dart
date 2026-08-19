import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/schedule_notifier.dart';
import '../timeline_geometry.dart';
import 'timeline_row_tile.dart';

/// Edge length of the compact tier's Complete/Skip touch targets.
///
/// **44.0, raised from 36.0 (UAT, 2026-08-19).** 44dp is the WCAG-recommended
/// minimum, and these are the two most time-sensitive buttons in the app —
/// they are tapped while a chunk is running, often one-handed. The original
/// 36dp shipped as a documented exception on the claim that a 100dp slot could
/// not fit two 44dp targets; UAT found them hard to hit with a thumb, and the
/// claim was wrong: the row's height comes from the kicker+title stack, not
/// the buttons.
///
/// Named rather than inlined because it is load-bearing in two places that
/// must not drift apart — this constant sizes the button, and
/// [kCompactLiveMinHeight] is measured against the row height it produces.
/// Changing it invalidates that measurement; re-measure in a real browser.
const double kLiveActionTouchTarget = 44.0;

/// The live row (D-01, `27-UI-SPEC.md` "The live row's two density tiers").
///
/// [kicker] and [remainingLabel] are INJECTED BY THE SCREEN — Phase 23's
/// LIVE-01 ("RIGHT NOW — RESTING" for a running break) and LIVE-02 (countdown
/// granularity) own what goes into them. A future agent extends the caller
/// that builds this widget, not this widget's layout.
///
/// **Phase 27 (GRID-02).** This row is duration-exact, like every other row
/// on the timeline — it no longer swells past its clock-implied slot. Its
/// prominence is carried entirely by `primaryContainer` fill, square
/// corners, elevation and the now-line, none of which need extra height.
/// [slotHeight] picks one of exactly two density tiers: `_buildCompact` at
/// or above [kCompactLiveMinHeight], `_buildSingleLine` below it — the same
/// slot-height-picks-the-tier rule `26-UI-SPEC.md` already uses for ordinary
/// `ChunkCard`s.
///
/// This card deliberately sits at its own clock position inside the day list
/// (D-01) and is never lifted into a hero region, a sticky bar (D-03), or a
/// floating pill. If a future change wants one of those, it is re-opening a
/// rejected sketch variant.
///
/// [kicker]/[remainingLabel] stay screen-injected, and every horizontal
/// offset must be stated in THIS file — the screen positions this row
/// `left: 0, right: 0` with no [TimelineRowTile], so it inherits no padding
/// from anything.
class LiveRowCard extends StatelessWidget {
  const LiveRowCard({
    super.key,
    required this.chunkId,
    required this.kicker,
    required this.title,
    required this.remainingLabel,
    required this.slotHeight,
    this.showActions = true,
    this.onTap,
  });

  /// The chunk this card acts on — Complete/Skip always target exactly this
  /// id (T-22-04).
  final String chunkId;

  /// Uppercase kicker line, e.g. "RIGHT NOW". Screen-injected. Only the
  /// compact tier renders it — the single-line tier has no room (GRID-02).
  final String kicker;

  final String title;

  /// Screen-injected remaining-time copy, rendered with tabular figures.
  final String remainingLabel;

  /// The row's clock-implied slot height in pixels — duration-exact, no
  /// exception (GRID-01). `>= kCompactLiveMinHeight` renders the compact
  /// tier; anything below renders the single-line tier. There is no third,
  /// "squeezed" tier (`27-UI-SPEC.md` "The live row's two density tiers").
  final double slotHeight;

  /// Complete/Skip are for work chunks only (UI-SPEC "Actions row"). False
  /// hides both buttons entirely. Only the compact tier renders them.
  final bool showActions;

  /// Fires when the single-line tier's row is tapped. Ignored by the compact
  /// tier, which has its own explicit icon actions instead. Per PD-27-06,
  /// the screen supplies this only for an unresolved live work chunk; a live
  /// break gets `null` in both tiers (`27-UI-SPEC.md`: "no tap target at
  /// all").
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return slotHeight >= kCompactLiveMinHeight
        ? _buildCompact(context, theme, colorScheme)
        : _buildSingleLine(context, theme, colorScheme);
  }

  /// The compact tier — kicker+title, two icon actions, and the
  /// remaining-time line. Fits a standard 25-minute work chunk's 100dp slot.
  ///
  /// **The Complete/Skip targets are [kLiveActionTouchTarget] — no longer a
  /// declared exception (UAT, 2026-08-19).** They shipped at 36×36dp with a
  /// documented WCAG shortfall and a claim that a 100dp slot "cannot also fit
  /// two 44dp targets side by side without either the title or the countdown
  /// losing its line." UAT on a real touch device found them hard to hit with
  /// a thumb, and the claim did not survive being checked: the row's height is
  /// set by the kicker+title stack (~37dp), not by the buttons, so widening
  /// them to 44dp costs 7dp against the compact tier's ~24dp of slack inside a
  /// 100dp slot. Nothing lost a line.
  ///
  /// This is why the stated remedy — "more slot height, revisit
  /// `kPixelsPerMinute`" — was NOT taken: it would have made the whole day
  /// taller to buy something the existing slack already covered, undoing the
  /// 5.5→4.0 compaction done for the opposite complaint.
  Widget _buildCompact(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: kCardLeftInset,
        right: kTimelineRowInset,
      ),
      color: colorScheme.primaryContainer,
      elevation: 6,
      shadowColor: colorScheme.shadow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kicker.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.72,
                          ),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (showActions) ...[
                  _buildActionIcon(
                    icon: Icons.check_circle_outline,
                    color: colorScheme.primary,
                    tooltip: 'Complete',
                    onPressed: () =>
                        context.read<ScheduleNotifier>().markComplete(
                          chunkId,
                        ),
                  ),
                  _buildActionIcon(
                    icon: Icons.skip_next_outlined,
                    color: colorScheme.error,
                    tooltip: 'Skip',
                    onPressed: () =>
                        context.read<ScheduleNotifier>().markSkipped(chunkId),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              remainingLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.82),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Shared chrome for the compact tier's Complete/Skip icons (IN-02) — one
  /// place for the sizing/tap-target treatment instead of two independently
  /// maintained blocks. Icon, color, tooltip, and callback are the only
  /// things that differ per button; deliberately kept as parameters rather
  /// than merged, so the two buttons' distinct identities stay explicit at
  /// each call site.
  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      color: color,
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(
        width: kLiveActionTouchTarget,
        height: kLiveActionTouchTarget,
      ),
      padding: EdgeInsets.zero,
      // `constraints:` alone caps the visible Material, but Material 3's
      // IconButton always wraps it in an invisible `_InputPadding` that
      // separately pads the HIT-TEST area out to `kMinInteractiveDimension`
      // (48dp) — measured directly (widget test, `tester.getSize`), stacking
      // `VisualDensity.compact` on top of the tight `constraints:` still
      // measured 40x40 rather than the constraints' own value, because visual
      // density only shaves the 48dp interactive minimum, it does not remove
      // it. `tapTargetSize: shrinkWrap` is what actually removes that separate
      // padding layer, so deliberately no `visualDensity` override here —
      // stacking one on top of `shrinkWrap` instead shrinks the tight
      // constraints' OWN minimum (visual density adjusts both layers), which
      // undersizes the button. `shrinkWrap` alone, against the unmodified
      // tight constraints, is the combination that measures exactly
      // [kLiveActionTouchTarget].
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
  }

  /// The single-line tier — one row of text, nothing else. Fits a 5-minute
  /// break's 20dp slot, and anything else below [kCompactLiveMinHeight].
  ///
  /// Margin is zero VERTICALLY ONLY (PD-27-01) — the smallest guaranteed
  /// slot cannot spend any of its height on margin and still leave room for
  /// one legible text line, but zeroing the HORIZONTAL margin would bleed
  /// this card to the raw viewport edge, since it is positioned
  /// `left: 0, right: 0` with no [TimelineRowTile] and inherits no inset
  /// from anything — the exact previously-shipped regression this file's
  /// class doc comment (and `timeline_row_tile.dart`'s) records.
  Widget _buildSingleLine(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final style = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onPrimaryContainer,
    );
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          // Deliberately never truncates (`27-UI-SPEC.md` "Single-line
          // tier": only the title sacrifices characters, the countdown is
          // the one piece of information this row can't lose). Known,
          // accepted risk: if `remainingLabel` itself (plus a zero-width
          // title) still exceeds the available row width, this overflows
          // the `Row` instead of clipping gracefully — unlikely at default
          // text scale with this app's `remainingLabel` lengths, but large
          // accessibility text scales are explicitly out of this phase's
          // verification scope (`27-VALIDATION.md`), so this has not been
          // exercised there. Not a regression to fix now — a documented
          // trade-off for whoever chases an overflow report later (IN-01,
          // 2026-08-18).
          Text(' · $remainingLabel', maxLines: 1, style: style),
        ],
      ),
    );
    return Semantics(
      label: 'Right now: $title, $remainingLabel',
      excludeSemantics: true,
      button: onTap != null,
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(
          top: 0,
          bottom: 0,
          left: kCardLeftInset,
          right: kTimelineRowInset,
        ),
        color: colorScheme.primaryContainer,
        elevation: 4,
        shadowColor: colorScheme.shadow,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: onTap != null ? InkWell(onTap: onTap, child: row) : row,
      ),
    );
  }
}
