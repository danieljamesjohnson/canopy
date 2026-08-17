import 'package:flutter/material.dart';

import '../timeline_geometry.dart';
import 'timeline_row_tile.dart';

/// The screen's primary visual anchor (CAL-02): a 2dp rule spanning the
/// content column, capped at its left end by a terminus dot — positioned by
/// the caller at an arithmetic pixel offset, never a between-rows list item.
///
/// **The time chip was retired (2026-08-17, Dan's call during UAT).** The
/// overlay used to carry a `formatMinutesCompact` chip inside the gutter
/// column, and that chip — not the hour-axis labels — was what held
/// [kGutterWidth] at 52dp: measured in the browser it filled 51 of those
/// 52dp. Retiring it let the gutter drop to 40dp and gave every chunk card
/// that width back, which is what this change was for. The dot now marks the
/// line's position and `HourAxisLine` still labels the column, so the chip's
/// job is covered; the precise current minute survives in the screen-reader
/// `Semantics` label at the call site, in `LiveRowCard`'s `RIGHT NOW ·
/// <time>` copy, and in the header's own copy.
///
/// Two guards died with it, and both are now unreachable rather than
/// ignored — do NOT reintroduce a chip without re-reading them in git
/// history: G-01 (26-07-PLAN.md) confined the chip to the gutter so it could
/// never occlude a `ChunkCard`'s content, and G-03 (26-09-PLAN.md) suppressed
/// it over the full-bleed live row, where no gutter column exists for it to
/// occupy. A restored chip re-opens both, and at 40dp the gutter no longer
/// has room for one.
///
/// Renders in every `NowState` — there is no `Active`-suppression here;
/// that Phase 24 rule is superseded outright by this overlay's ability to
/// sit truthfully mid-chunk (26-UI-SPEC.md "The now-line (CAL-02)").
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
  const NowLineOverlay({super.key, required this.nowMinutes});

  /// Minutes-from-midnight of the current moment, injected — never derived
  /// from a clock read inside this file.
  ///
  /// Still required with the chip gone: the caller's `Semantics` label reads
  /// it, and it documents that this widget never touches a clock itself.
  final int nowMinutes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          // the rule's starting edge.
          //
          // CENTRED on [kNowContentEdge] — straddling the boundary between the
          // hour-label gutter and the content column, which is exactly what
          // Google Calendar does with its own now-dot. Its left half therefore
          // overhangs into the gutter and its right half onto the card's left
          // edge, and that overhang is the point: it is what lets the cards sit
          // flush against the gutter with no blank clearance strip (the strip
          // was tried, and reading as dead space was the complaint that killed
          // it — see kCardLeftInset).
          //
          // A previous pass deliberately did NOT centre it, to avoid a 5px
          // overlap with the time chip that used to occupy the gutter. That
          // chip is retired, so the constraint is gone.
          //
          // This is NOT the vertical rail rejected as D-04 (see
          // `timeline_row_tile.dart`'s constant doc): that rejection covers a
          // per-row connector running down the gutter column. This is a single
          // dot on the now-line only, the Google Calendar current-time idiom.
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(
                left: kNowContentEdge - kNowDotDiameter / 2,
              ),
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
        ],
      ),
    );
  }
}
