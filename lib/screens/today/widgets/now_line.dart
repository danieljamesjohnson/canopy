import 'package:flutter/material.dart';

import '../../../utils/time_format.dart';
import '../timeline_geometry.dart';
import 'timeline_row_tile.dart';

/// The screen's primary visual anchor (CAL-02): a full-content-width 2dp
/// rule plus a compact time chip, positioned by the caller at an
/// arithmetic pixel offset — never a between-rows list item.
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
  final int nowMinutes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: kNowLineHeight,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(height: 2, color: colorScheme.primary),
          ),
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
