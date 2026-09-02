import 'package:flutter/material.dart';

import '../../../utils/time_format.dart';
import '../../../widgets/hatch_fill.dart';

/// D-05 (LOCKED): free time is named, never collapsed to whitespace.
///
/// Two named constructors keep the leading-gap and mid-day-gap forms distinct
/// so a call site can't mix them up: [FreeTimeRow.until] for the day's first
/// activity ("Free until 8:00 AM"), [FreeTimeRow.gap] for a mid-day gap
/// ("Free · 1h 40m"). Both label strings are locked copy — do not reword.
///
/// **Phase 26 (CAL-01, `26-UI-SPEC.md` "Free / gap rows at proportional
/// height"):** the label centres vertically within whatever height the parent
/// allocates, rather than top-aligning. Per D-02 an empty stretch renders at
/// its true duration-proportional height — a gap row can be many hundreds of
/// pixels tall — so a label pinned to the very top of that void would be
/// worse than one sitting where a scrolling eye lands.
///
/// **Phase 33 (OBVIOUS-01, `33-UI-SPEC.md` item 7, sketch 003 — owner's
/// verdict 2026-09-01): a filled [Card], not a dashed outline.** Phase 22
/// gave free time and breaks one visual language on purpose; Phase 32 then
/// rebuilt breaks as filled bordered cards (D-32-02) and left free time on
/// the old dashed treatment, so the match silently broke. This restores it by
/// copying the break card's own `color` / `shape` / `clipBehavior`
/// (`chunk_card.dart:186-235`) verbatim — including its 12dp radius, where
/// the retired painter used 8.
///
/// The fill is the point, not just the parity: **an outline reads as absence,
/// a fill reads as "this is yours."** Free time on this timeline is a claim
/// the user owns that stretch, not a hole in the day.
///
/// **Phase 33 gap closure (owner's verdict 2026-09-02) — the fill is
/// HATCHED.** Copying the break card's `color`/`shape`/`clipBehavior`
/// verbatim was right about the card and wrong about its surface: sketch 003,
/// the one he picked, fills `.free.filled` with a 135° repeating gradient,
/// and the copy dropped it. He drew the missing diagonals back in over this
/// exact block (`shots/07-owner-annotation-2026-09-02.png`). See [HatchFill]
/// — the same treatment now runs on both break tiers, so "diagonals mean not
/// work" is one rule rather than a free-time quirk.
class FreeTimeRow extends StatelessWidget {
  const FreeTimeRow.until({super.key, required int untilMinutes})
    : _untilMinutes = untilMinutes,
      _durationMinutes = null;

  const FreeTimeRow.gap({super.key, required int durationMinutes})
    : _untilMinutes = null,
      _durationMinutes = durationMinutes;

  final int? _untilMinutes;
  final int? _durationMinutes;

  String _resolveLabel() {
    if (_untilMinutes != null) {
      return 'Free until ${formatMinutes(_untilMinutes)}';
    }
    return 'Free · ${formatDurationShort(_durationMinutes!)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Fills the parent's allocated height (the gap's true
    // duration-proportional extent) rather than sizing to the label, so the
    // card marks where the free stretch starts and stops. `margin` matches
    // the break row's so a free region and a break line up on the timeline.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        // **[Center] is load-bearing — do not flatten it to a [Padding] or a
        // bare [Text].** A [Card] sizes to its child, and both production
        // call sites wrap this row in `Positioned(height:
        // geometry.heightFor(...))` (`today_screen.dart:697-732`) whose
        // height arrives through `TimelineRowTile`'s `Row(crossAxisAlignment:
        // start)` + `Expanded` — i.e. as a LOOSE constraint. An [Align] such
        // as [Center] expands to the incoming maximum under a loose
        // constraint; a bare [Text] does not, and the card would collapse to
        // label height, silently reintroducing the "weird long stretch of
        // white space" UAT 2026-08-18 rejected. This is the inverse of the
        // infinite-height trap `chunk_card.dart:166-185` documents: there the
        // child must not stretch, here it must. Pinned by the non-collapse
        // height test in `today_row_widgets_test.dart`.
        child: HatchFill(
          child: Center(
            child: Text(
              _resolveLabel(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Phase 33 (OBVIOUS-01, UI-SPEC item 9 — retired-mechanism deletion).
// `_DashedRegionPainter` lived here: a file-private dashed rounded outline
// that gave the free region the same treatment breaks carried before Phase
// 32. Phase 32 rebuilt breaks as filled bordered cards (D-32-02) and this row
// is now one too, so the painter has no remaining caller. Deleted outright
// rather than left unreferenced, per this codebase's own "retire deliberately,
// don't leave dead mechanism in the tree" charter (`chunk_card.dart:15-23`).
// Its dash rhythm is not lost — `_DashedChipBorderPainter` in
// `chunk_card.dart` carries it forward for the `Skipped` status chip's border.
