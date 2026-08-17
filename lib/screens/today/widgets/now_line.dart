import 'package:flutter/material.dart';

import '../../../utils/time_format.dart';
import '../timeline_geometry.dart';
import 'timeline_row_tile.dart';

/// Diameter of the now-line's terminus dot (the Google Calendar
/// current-time idiom). 10dp reads clearly against the 2dp rule without
/// exceeding [kNowLineHeight]'s 28dp band.
const double kNowDotDiameter = 10.0;

/// `TimelineRowTile`'s horizontal row inset. The now-line is positioned
/// `left: 0, right: 0` by its caller (it must be free to sit at any pixel
/// offset), so it does NOT inherit that tile's padding and has to reapply
/// the inset itself — on BOTH sides. Miss the right one and the rule
/// overshoots every card and the hour axis by 16dp and runs off the screen
/// edge (caught in UAT on a narrow viewport, where the overhang is obvious).
const double kTimelineRowInset = 16.0;

/// Where the timeline's content column begins: [kTimelineRowInset] plus the
/// reserved [kGutterWidth] column. Both the rule and the dot start here, so
/// the now-line aligns with every card's left edge and never intrudes on the
/// gutter the hour axis owns. Derived from the same constants the rows use —
/// do not hard-code 68.
const double kNowContentEdge = kTimelineRowInset + kGutterWidth;

/// The screen's primary visual anchor (CAL-02): a 2dp rule spanning the
/// content column, capped at its left end by a terminus dot, plus a compact
/// time chip in the gutter — positioned by the caller at an arithmetic pixel
/// offset, never a between-rows list item.
///
/// **G-01 (26-UAT.md, fixed 26-07-PLAN.md):** the chip is confined to the
/// `kGutterWidth` (52dp) time-gutter column and can never reach a
/// `ChunkCard`'s content. The original UI-SPEC specified both a 52dp chip
/// AND a longer two-part "Now" + full-time label — arithmetically
/// incompatible (that longer string is ~101px at `labelSmall` 12px/w600).
/// The chip honours the width and uses [formatMinutesCompact] instead; the
/// full time survives only in the screen-reader `Semantics` label at the
/// call site. Do NOT restore the longer bare-time label here — that is
/// precisely what shipped the occlusion bug.
///
/// Renders in every `NowState` — there is no `Active`-suppression here;
/// that Phase 24 rule is superseded outright by this overlay's ability to
/// sit truthfully mid-chunk (26-UI-SPEC.md "The now-line (CAL-02)").
///
/// **G-03 (26-UAT.md, fixed 26-09-PLAN.md):** [showChip] suppresses the
/// chip specifically — the 2dp rule still always renders — while the line
/// falls inside the live row's span. `LiveRowCard` is full-bleed by design
/// (26-UI-SPEC.md "let now break the grid", inherited from Phase 22/23), so
/// there is no gutter column there for a gutter-confined chip (G-01,
/// 26-07-PLAN.md) to occupy: it would sit directly over `LiveRowCard`'s
/// title, which is the defect G-01's own fix did not cover. The live row
/// already states the current time in its own copy (`RIGHT NOW · <time>`),
/// so the chip is redundant there, not lost — do not "simplify" this
/// parameter away; without it the chip re-collides with the live row.
///
/// Carries NO `Semantics` node of its own. The call site in
/// `today_screen.dart` applies one labelled `excludeSemantics` node around
/// the whole positioned element (24-REVIEW.md WR-01: the wrapper must
/// enclose the whole positioned element, not just an inner child, to avoid
/// a double-announcement regression). That `Semantics` node must sit
/// OUTSIDE the `IgnorePointer` the call site also wraps this widget in —
/// modern `IgnorePointer` also removes its subtree from the semantics
/// tree, so putting the label inside it would silently delete the
/// announcement.
class NowLineOverlay extends StatelessWidget {
  const NowLineOverlay({super.key, required this.nowMinutes, this.showChip = true});

  /// Minutes-from-midnight of the current moment, injected — never derived
  /// from a clock read inside this file.
  final int nowMinutes;

  /// Whether the time chip renders. The 2dp rule below always renders
  /// regardless of this flag — only the chip is conditional. The caller
  /// passes `false` while [nowMinutes] falls inside the live row's span
  /// (see the G-03 doc comment above); every other call passes `true` (or
  /// omits the parameter), preserving G-01's gutter-confined chip exactly
  /// as 26-07 left it.
  final bool showChip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: kNowLineHeight,
      child: Stack(
        children: [
          // The rule begins at the content edge — the dot's left edge — so
          // the dot caps it rather than sitting as a bead on a longer
          // stroke (Google Calendar's current-time indicator). It does NOT
          // run back through the gutter: that full-bleed stroke read as a
          // stray line crossing the time column, which is what the dot plus
          // this inset together fix. The gutter column belongs to the hour
          // axis and the chip.
          //
          // The right inset is NOT optional symmetry: the caller positions
          // this overlay `right: 0`, so without it the rule outruns every
          // card and the hour axis by [kTimelineRowInset] and bleeds off the
          // viewport edge. Both ends must land on the content column.
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(
                left: kNowContentEdge,
                right: kTimelineRowInset,
              ),
              child: Container(height: 2, color: colorScheme.primary),
            ),
          ),
          // The calendar-style terminus dot, drawn after the rule so it caps
          // the rule's starting edge. Its left edge sits on [kNowContentEdge]
          // — the same offset the rule starts at — so it cannot touch the
          // gutter-confined chip (which ends there). Do not centre it ON that
          // offset "to straddle the boundary": the chip and the dot are both
          // `colorScheme.primary`, so a 5px overlap reads as a lump growing
          // out of the chip rather than as two elements.
          //
          // This is NOT the vertical rail rejected as D-04 (see
          // `timeline_row_tile.dart`'s constant doc): that rejection covers a
          // per-row connector running down the gutter column. This is a single
          // dot on the now-line only, the Google Calendar current-time idiom.
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: kNowContentEdge),
              child: Container(
                width: kNowDotDiameter,
                height: kNowDotDiameter,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          if (showChip)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                // G-01: confined to the gutter column so the chip can never
                // reach a ChunkCard's content (which begins immediately after
                // this SizedBox, at 16dp + kGutterWidth).
                child: SizedBox(
                  width: kGutterWidth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.3),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      formatMinutesCompact(nowMinutes),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
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
