import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_notifier.dart';

/// Phase 32 (TAPBREAK-01, D-32-03 LOCKED). The shared Skip rail for a break
/// row — non-live (`chunk_card.dart`'s compact/full break tiers) and live
/// (`live_row_card.dart`'s single-line tier) both render the identical
/// widget, so the two surfaces can never drift apart visually (the whole
/// reason this lives in `lib/widgets/` rather than under either feature's
/// own `widgets/` folder — see `32-RESEARCH.md` "Recommended Project
/// Structure").
///
/// Fills whatever box its parent gives it (typically a
/// `SizedBox(width: kBreakSkipButtonWidth)` inside a
/// `Row(crossAxisAlignment: CrossAxisAlignment.stretch)`) — at the smallest
/// reachable break slot (5 min, 30dp @ kPixelsPerMinute = 6.0) this is a
/// 64 x 30 rail; at the full tier (30 min, 180dp) the identical widget simply
/// gets a taller box, with no internal branching.
///
/// **Deliberately no local error-handling wrapper here.**
/// [ScheduleNotifier.markSkipped] already owns the WR-05 revert-and-rethrow
/// contract; duplicating that logic here would create two error paths for
/// one action.
class BreakSkipButton extends StatelessWidget {
  const BreakSkipButton({
    super.key,
    required this.chunkId,
    required this.accessibleTitle,
  });

  /// The break's own chunk id — passed straight to
  /// `ScheduleNotifier.markSkipped`, exactly the call the work-chunk Skip
  /// button already makes (`chunk_card.dart`'s `_buildActionRow`).
  final String chunkId;

  /// e.g. `'Short break'` / `'Long break'` — used only to build this
  /// button's own accessibility label (`'Skip $accessibleTitle'`). The
  /// visible label stays the bare word `'Skip'`, matching the app's existing
  /// skip vocabulary; a screen reader needs the object noun a sighted user
  /// already has from the card's own adjacent title text.
  final String accessibleTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // **Deviation (Rule 1 — bug), recorded here rather than silently
    // fixed.** `32-UI-SPEC.md`'s widget tree wraps a bare
    // `Semantics(button: true, label: ...)` around the visible content with
    // no `container`/`ExcludeSemantics`. Without those, this Semantics node
    // is NOT its own boundary — Flutter merges it with its unlabelled
    // sibling (the compact tier's title `Text`) AND with its own visible
    // `Text('Skip')` descendant into one combined, newline-joined label on
    // a shared ancestor node, so `find.bySemanticsLabel('Skip Short
    // break')` (an EXACT string match) never resolves; the actual merged
    // label reads `"Short break\nSkip Short break\nSkip"`. `container:
    // true` makes this Semantics node its own boundary (stops it merging
    // with the row's title); `ExcludeSemantics` on the visible content
    // stops the icon/label `Text` from appending a second line onto this
    // same node. Net effect matches the UI-SPEC's own stated intent exactly
    // — one reachable node, labelled `'Skip $accessibleTitle'`, nothing
    // more — the literal tree just didn't achieve it.
    return Semantics(
      container: true,
      button: true,
      label: 'Skip $accessibleTitle',
      child: Material(
        color: colorScheme.errorContainer,
        child: InkWell(
          onTap: () => context.read<ScheduleNotifier>().markSkipped(chunkId),
          child: ExcludeSemantics(
            // **Deviation (Rule 1 — bug), recorded here rather than
            // silently fixed.** The icon(18) + labelSmall Text stacked
            // with no gap measure ~34dp tall in `flutter test`'s own
            // harness (18 + a ~16dp labelSmall line box) — 4dp over the
            // 30dp the compact tier's slot gives this button at the
            // smallest reachable break duration, throwing a genuine
            // `RenderFlex overflowed` error, not a harness-measurement
            // caveat this project's placeholder-font notes would
            // otherwise wave off. `FittedBox(scaleDown)` is this
            // codebase's own D-02 philosophy ("content adapts, box never
            // grows") applied to this button specifically: at the 30dp
            // tier it shrinks the icon+label slightly rather than
            // overflowing or clipping; at the 180dp full tier (34dp of
            // natural content, 180dp available) it never triggers —
            // `scaleDown` never scales UP past natural size.
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.skip_next_outlined,
                      color: colorScheme.onErrorContainer,
                      size: 18,
                    ),
                    Text(
                      'Skip',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Skip rail's resolved-state counterpart (Phase 32, TAPBREAK-03). Once
/// a break is skipped, the rail's own 64dp slot keeps its exact width and
/// only its content swaps to this — a small centered `'skipped'` string,
/// verbatim reuse of D-31-04's existing string/style
/// (`chunk_card.dart._buildTrailingStatus`), relocated into this slot rather
/// than a new copy decision.
///
/// **Corrected (`32-REVIEW.md` finding 1): the slot-preserving claim above is
/// about `chunk_card.dart` ONLY.** Both of that file's break tiers keep their
/// `SizedBox(width: kBreakSkipButtonWidth)` and swap only the child, which is
/// what makes the sentence true there. `live_row_card.dart` never did — it
/// gates the whole `SizedBox` on `showActions`, and its call site passes
/// `showActions: isBreak ? !chunk.isSkipped : true`, so on a break the slot
/// disappears rather than being preserved. That made this widget's use in
/// that file unreachable, and the branch has been deleted there. The wording
/// is fixed here rather than left to imply a guarantee only one of the two
/// call sites ever offered.
///
/// **Sole renderer as of this fix: `chunk_card.dart`** (both the compact and
/// full break tiers). Still public rather than file-private because it lives
/// in `lib/widgets/` beside [BreakSkipButton], which two libraries do render,
/// and splitting the pair across libraries to save one keyword would obscure
/// that they are two halves of one rail.
class BreakSkippedIndicator extends StatelessWidget {
  const BreakSkippedIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'skipped',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
