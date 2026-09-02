import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/energy_valence.dart';
import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/schedule_notifier.dart';
import '../../../utils/time_format.dart';
import '../../../widgets/break_skip_button.dart';
import '../../../widgets/hatch_fill.dart';
import '../../today/timeline_geometry.dart';

/// Phase 26 (CAL-01) row content density. `ChunkCard` renders distinct
/// content sets depending on how much vertical room its (now duration-sized,
/// per D-02) slot allocates — but the CONTENT degrades, never the box: no
/// branch here ever floors, ceilings, or clamps a widget's height.
///
/// **Phase 32 (D-32-02, TAPBREAK-01/03): the `subCompact` value is RETIRED,
/// not merely unused.** Phase 29 added it as a break-only hairline-with-label
/// tier for a slot too small for a real card; Phase 32 raises
/// `kPixelsPerMinute` and gives every break tier a real bordered `Card` with
/// a Skip rail instead, so the sub-compact tier's whole reason for existing
/// — "no card fits here" — no longer holds at any duration the engine emits.
/// Deleting the value (rather than leaving it unreferenced) is what makes
/// this codebase's own "retire deliberately, don't leave dead mechanism in
/// the tree" charter true here, not just asserted.
enum ChunkCardDensity {
  /// Today's card, byte-for-byte unchanged. Renders every field: title,
  /// clock-time range, rationale, priority chip, valence chip, action row.
  /// This is the default — every existing call site (four standalone
  /// `chunk_card_*_test.dart` files covering GOALS-02/ENERGY-04b, plus every
  /// screen that pumps `ChunkCard` without an explicit `density`) keeps
  /// exactly today's behaviour (PD-4, `26-02-PLAN.md`).
  detailed,

  /// The UI-SPEC's "Full" tier (`26-UI-SPEC.md` § "Row content density"):
  /// title + clock-time range + the Complete/Skip action row (work), or the
  /// heavier-weight break card + Skip rail (break, Phase 32). Drops the
  /// rationale line, the priority chip, and the valence chip — all three
  /// stay reachable through `ChunkDetailSheet`, unchanged.
  full,

  /// The UI-SPEC's "Compact" tier: title only for a work chunk (single line,
  /// ellipsis; Complete/Skip reached via the row's own tap into
  /// `ChunkDetailSheet`), or the bordered break card + Skip rail (Phase 32,
  /// TAPBREAK-01/03) for a break.
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

  /// **Phase 32 (D-32-02, TAPBREAK-01/03) — supersedes D-06's original
  /// "breaks read transparent with a dashed outline, never a filled Card"
  /// clause for the container only.** The owner's own words ("make it look
  /// like a small section similar to work") directly countermand that clause.
  /// What survives from D-06 unmodified: no bold title, no emoji, no colored
  /// goal-accent bar on a break (it has no goal) — a break still reads
  /// quieter than a goal card, it just also carries a real Skip action now.
  ///
  /// UAT G-02: a long break scales up in weight within the same vocabulary —
  /// taller padding, a heavier title style, a leading icon — so a 25-minute
  /// break visibly outweighs a 5-minute one. The standing collapse/accordion
  /// prohibition (carried from 22-02) stays in force; the only interaction
  /// either tier gains is the Skip rail below.
  Widget _buildBreak(BuildContext context) {
    final theme = Theme.of(context);
    final isLong = chunk.chunkType == ChunkType.longBreak;
    final title = isLong ? 'Long break' : 'Short break';

    // Compact tier (density-driven, CAL-01). Phase 32 (TAPBREAK-01/02/03,
    // D-32-02): rebuilt as a real bordered Card carrying a visible Skip
    // rail — the load-bearing analog is `_WorkChunkContent.build`'s own
    // discretionary-goal Card (color/shape/clipBehavior copied verbatim,
    // no left accent bar since a break has no goal color). Superseded: the
    // dashed-outline treatment this tier used to carry (D-06's original
    // break vocabulary) and the D-31-04 Semantics(excludeSemantics: true)
    // wrapper this tier used to carry.
    //
    // **No outer excluding Semantics wrapper here, deliberately.** Every
    // previous break tier wrapped its row in
    // `Semantics(excludeSemantics: true, ...)` because none of them had a
    // focusable child. This one does — the Skip button below owns a real
    // `Semantics(button: true, ...)` node — so an outer excluding wrapper
    // would swallow that button's own semantics entirely: visibly rendered,
    // tappable, and invisible to a screen reader. The label `Text` exposes
    // its own implicit semantics; `BreakSkipButton` exposes its own.
    if (density == ChunkCardDensity.compact) {
      // **Deviation (Rule 1 — bug), recorded here rather than silently
      // fixed.** `32-UI-SPEC.md`'s widget tree puts `Row(crossAxisAlignment:
      // stretch)` directly as the Card's child with no explicit height.
      // That throws `BoxConstraints forces an infinite height` at layout
      // time: every non-live chunk card (this one included, via
      // `today_screen.dart`'s unchanged `ClipRect`/`OverflowBox(minHeight:
      // 0, maxHeight: double.infinity)` PD-10 pattern) is laid out with an
      // AMBIENT UNBOUNDED height so it can size to its own natural content
      // — `CrossAxisAlignment.stretch` asks Flutter to give every Row child
      // a TIGHT constraint equal to the Row's own incoming max height, and
      // "tight at infinity" is not a size any RenderBox can report. Fixed
      // by giving this Card an EXPLICIT height computed the same way
      // `TimelineGeometry.heightFor` computes this row's own slot —
      // `chunk.durationMinutes * kPixelsPerMinute` — which the app's own
      // D-02/GRID-01 duration-exact invariant guarantees equals the slot
      // this card is rendered into (proven by the tracer test's own
      // painted-extent assertion). This also delivers the UI-SPEC's stated
      // intent more precisely than the literal tree would have: the rail is
      // now provably exactly the full SLOT height (30dp/180dp), not merely
      // whatever height the card's own content happens to want.
      return SizedBox(
        height: chunk.durationMinutes * kPixelsPerMinute,
        child: Card(
          // Deliberate exception, not an oversight: the smallest reachable
          // break slot (30dp @ kPixelsPerMinute = 6.0) cannot spend any of
          // itself on margin and still leave comfortable room for the
          // border, the label, and the rail's own icon+text. The
          // neighbouring work chunk's own 4dp margin alone preserves the
          // visible seam — Flutter margins do not collapse.
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          // Phase 33 gap closure (owner's verdict 2026-09-02) — the hatch.
          // Wraps the Row rather than sitting beside it in a Stack so the
          // painter inherits the Row's own (duration-exact) size; the Card's
          // `Clip.antiAlias` confines the lines to the rounded rect.
          child: HatchFill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          decoration: chunk.isSkipped
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: kBreakSkipButtonWidth,
                  child: chunk.isSkipped
                      ? const BreakSkippedIndicator()
                      : BreakSkipButton(
                          chunkId: chunk.id,
                          accessibleTitle: title,
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // detailed / full — Phase 32 (TAPBREAK-01/03): the same bordered-Card +
    // Skip-rail shape the compact tier above uses, keeping this tier's own
    // distinguishing treatment (the heavier titleMedium/w500 title, the
    // leading self_improvement icon, the taller vertical padding for a long
    // break, and the whole-row `Opacity(0.5)` mute on skip — D-31-04's
    // existing resolved-state vocabulary for this tier, unchanged by this
    // phase per the UI-SPEC's own "internal Row/Padding/icon layout
    // otherwise matches what already ships today, unchanged") unchanged.
    // `margin: EdgeInsets.symmetric(vertical: 4)` is restored here (rather
    // than the compact tier's `EdgeInsets.zero`) because this tier's
    // smallest reachable slot is 180dp (a 30-minute break) — there is no
    // room pressure the way there is at the compact tier's 30dp. The
    // trailing spacer-and-duration/status arrangement is replaced by the
    // identical rail structure the compact tier uses; a break's
    // `isCompleted` is always false (D-31-01), so the old
    // `Icons.check_circle` completed-branch here was unreachable dead code
    // and is not carried forward.
    //
    // Same explicit-height fix as the compact tier above, for the same
    // reason (`BoxConstraints forces an infinite height` under the ambient
    // unbounded `OverflowBox` this card is laid out inside) — `Row(
    // crossAxisAlignment: stretch)` cannot report a size against an
    // unbounded incoming height without a tight height supplied from above.
    final titleStyle = isLong
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
            decoration: chunk.isSkipped ? TextDecoration.lineThrough : null,
          )
        : theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            decoration: chunk.isSkipped ? TextDecoration.lineThrough : null,
          );

    return SizedBox(
      height: chunk.durationMinutes * kPixelsPerMinute,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: theme.colorScheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        // Phase 32 gap closure (G-32-02, sketch 002 variant C). **The tall
        // break's Skip is a centred pill, not a full-height side rail.**
        //
        // D-32-03 fixed the rail at 64dp wide and let
        // `CrossAxisAlignment.stretch` take its height from whatever row it
        // landed in. That was derived entirely from the 30dp short break,
        // where the control can only earn touch area from width. Applying the
        // same shape here was justified as "never a *smaller* target, only a
        // more generous one" — true about touch, and silently treated as
        // "never worse". It is not: at this tier's smallest reachable slot
        // (a 30-minute break, 180dp) it renders a 64dp-wide errorContainer
        // slab running the full height of the row, which the owner judged
        // FAIL on 2026-08-28 — *"the long break has too big of a skip."*
        //
        // The short break's 64x30 rail is NOT re-litigated; nothing in that
        // round contradicted it, and it keeps its own tier above.
        //
        // **Why an `OutlinedButton.icon` rather than a new pill widget.**
        // This is verbatim the control `_buildActionRow` gives a work chunk's
        // Skip — same icon, same word, same shape. It also closes the
        // orchestrator observation raised in `32-UAT.md` (a break's Skip and
        // a work chunk's Skip used the same icon and word in two different
        // arrangements). One vocabulary, one arrangement, wherever there is
        // room for it.
        // Phase 33 gap closure (owner's verdict 2026-09-02) — the hatch, and
        // it sits INSIDE the Opacity deliberately: a skipped break's lines
        // fade with its label and its indicator, rather than staying at full
        // strength over muted content.
        child: Opacity(
          opacity: chunk.isSkipped ? 0.5 : 1.0,
          child: HatchFill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLong) ...[
                          Icon(
                            Icons.self_improvement,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            title,
                            style: titleStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (chunk.isSkipped)
                      const BreakSkippedIndicator()
                    else
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
                            side: BorderSide(color: theme.colorScheme.error),
                          ),
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

    // **Phase 33 gap closure (owner's verdict 2026-09-02): a work chunk does
    // NOT share the break's fill.** *"i think side project should have a
    // color not the same as a break."* He was being exact, not approximate —
    // the work card here, the break card (`_buildBreak`) and the free-time
    // card (`free_time_row.dart`) all rendered `surfaceContainer` with the
    // same `outlineVariant` border and the same 12dp radius. Three kinds of
    // time, one fill; the only separator was the 4dp goal bar below.
    //
    // Fixed by moving WORK up the neutral ramp (tone 94 -> tone 100) rather
    // than by giving it a hue. A hue would have re-opened the complaint this
    // phase exists to answer — *"the colors are changing, it's not making a
    // ton of sense"* — and `33-UAT.md` item 4 already flags one card carrying
    // two colour systems. This adds no colour meaning at all: work is the
    // solid, bright card; non-work is the greyer hatched one (see
    // [HatchFill]). Commitments keep `tertiaryContainer`, untouched.
    final cardColor = isCommitment
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.surfaceContainerLowest;
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

    // Phase 32 gap closure (G-32-01, sketch 002 variant C — owner-selected
    // 2026-08-28). **The card is sized by its duration, not by its content.**
    //
    // Until now this Card laid out at its NATURAL height inside a
    // duration-exact slot, top-aligned by `today_screen.dart`'s
    // `OverflowBox(alignment: topCenter, maxHeight: infinity)`. A ~83dp work
    // card in a 150dp slot therefore trailed ~67dp of dead background on
    // every work chunk — the "huge gaps" the owner reported on 2026-08-28.
    // D-32-01 (4.0 -> 6.0) did not introduce this: at 4.0 the same mechanism
    // left ~17dp and read as ordinary card spacing. Raising the scale only
    // made a pre-existing flaw visible everywhere at once.
    //
    // The fix is the pattern this file ALREADY proves one method up:
    // `_buildBreak` has given its own Card an explicit
    // `durationMinutes * kPixelsPerMinute` height since this phase's wave 1,
    // which is exactly why breaks never showed the defect. Applying it here
    // is a re-use, not a new mechanism, and it keeps the duration-exact
    // invariant (D-02/GRID-01) intact rather than working around it — the
    // card's height IS its duration, so nothing starts lying.
    //
    // **`detailed` is deliberately excluded.** That tier renders on the
    // schedule screen, which is a plain list with no duration-proportional
    // slot; forcing a duration height there would invent a scale the screen
    // does not have. `full` and `compact` are the timeline's two tiers and
    // the only ones laid out against a slot.
    //
    // The Card keeps its own `margin: vertical 4`, so the visible seam
    // between consecutive rows is a deliberate 8dp — not the 67dp hole.
    final card = MouseRegion(
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

    return density == ChunkCardDensity.detailed
        ? card
        : SizedBox(
            height: chunk.durationMinutes * kPixelsPerMinute,
            child: card,
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
    //
    final isFull = density == ChunkCardDensity.full;

    // Phase 32 gap closure (G-32-01, sketch 002 variant C). Now that the
    // `full` card fills its slot, the extra height has to become something.
    // Variant C beat variant A on exactly this point: A filled the slot and
    // left the middle hollow with the buttons floating at the bottom, which
    // moved the gap inside the card rather than removing it. So the content
    // responds to the height it is handed — a roomy row earns a goal/duration
    // line, and the action row is pushed to the bottom edge deliberately
    // rather than left wherever the content happened to end.
    //
    // `detailed` is untouched: it has no slot, so `MainAxisSize.max` there
    // would try to expand into the schedule screen's unbounded list extent.
    final slotHeight = chunk.durationMinutes * kPixelsPerMinute;
    final isRoomy = isFull && slotHeight >= kRoomyWorkMinHeight;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: isFull ? MainAxisSize.max : MainAxisSize.min,
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
        // The goal/duration line a roomy row earns. `full` normally
        // suppresses everything below the title line (PD-4) precisely because
        // it was fighting for height it did not have; at >= 120dp that
        // constraint no longer binds, and the suppression becomes an empty
        // card instead of a saved dp. Only rendered when there is a goal name
        // to render — a commitment chunk has none and keeps the tighter shape.
        if (isRoomy && goalName != null && goalName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '$goalName · ${chunk.durationMinutes} min',
            style: metaStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        // SCHED-03: Always-visible action row for unresolved chunks.
        // Resolved chunks show status icon only (no buttons).
        if (!isResolved) ...[
          // `full` fills its slot, so the gap before the actions is whatever
          // is left over — the buttons sit on the card's bottom edge instead
          // of floating mid-card. `detailed` has no slot to fill and keeps
          // its fixed 12dp.
          if (isFull) const Spacer() else const SizedBox(height: 12),
          _buildActionRow(context, theme),
        ],
      ],
    );
  }

  /// UI-SPEC "Compact" tier: title only. No time text, no rationale, no
  /// chips, no action row — Complete/Skip live in ChunkDetailSheet, reached
  /// via the row's own tap ([onTap] is still wired by the caller).
  ///
  /// **Phase 33 (OBVIOUS-01, `33-UI-SPEC.md` item 1, sketch 003 variant B):
  /// the trailing status now renders in ALL THREE states, not just resolved
  /// ones.** T-26-02's original guard dropped it for an unresolved chunk on
  /// the reasoning that this "removes an empty icon slot" — true of an
  /// unlabelled circle, and exactly the rationale this phase overturns. The
  /// slot is no longer empty: it carries the word `To do`, which is the one
  /// thing the row was missing. An unresolved compact row that says nothing
  /// about its state is the 2026-06-12 complaint restated, so the guard is
  /// gone rather than merely relaxed.
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
        const SizedBox(width: 8),
        _buildTrailingStatus(theme),
      ],
    );
  }

  /// Shared trailing status: a labelled [_StatusChip] reading `Done`,
  /// `Skipped` or `To do`. Identical across every density — Phase 33
  /// (OBVIOUS-01) removed the compact tier's resolved-only guard, so all
  /// three tiers now call this for all three states.
  ///
  /// The chip replaced a three-way ternary of bare marks (a `check_circle`
  /// icon, the lowercase word `skipped`, and an unlabelled
  /// `radio_button_unchecked` circle). Every state now carries its word; none
  /// of them is a control (UI-SPEC item 3).
  Widget _buildTrailingStatus(ThemeData theme) {
    return _StatusChip(
      isCompleted: chunk.isCompleted,
      isSkipped: chunk.isSkipped,
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
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
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

/// File-private status chip for a work chunk's trailing slot (OBVIOUS-01,
/// `33-UI-SPEC.md` items 1-6, sketch 003 variant B — owner's verdict
/// 2026-09-01 against a served mockup).
///
/// **Every state carries its word.** `Done`, `Skipped`, `To do` — one
/// vocabulary, three labels, never a bare glyph. This replaces a trailing
/// slot that showed an unlabelled `radio_button_unchecked` circle on every
/// unresolved row, which the owner complained about on 2026-06-12 and which
/// survived 2.5 months. Variant A (delete the glyph, show nothing) and
/// variant C (a real checkbox) were both built, shown, and rejected — A
/// leaves the row mute, C adds a second way to complete a chunk.
///
/// **Display-only, deliberately (item 3).** No `InkWell`, no
/// `GestureDetector`, no `IconButton`, no `onTap`. `_buildActionRow`'s
/// `Complete` and `Skip` stay the only completion affordances (item 4).
///
/// Geometry is copied verbatim from [_ValenceChip] below so the file's chips
/// sit at one visual weight. Colours follow the container-role convention and
/// **never the error slot** (item 5) — `colorScheme.error` is reserved for
/// the destructive Skip *button*.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isCompleted, required this.isSkipped});

  final bool isCompleted;
  final bool isSkipped;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final IconData icon;
    final Color onColor;
    final String label;
    // Null, not `Colors.transparent`: a null `BoxDecoration.color` paints
    // nothing, and this file's own test gate forbids a hardcoded `Colors`
    // literal reaching the widget tree.
    Color? chipColor;
    BoxBorder? border;
    // The skipped state is the only one whose border is dashed; it is drawn
    // by a painter rather than a `BoxBorder`, so it needs its own flag.
    final dashedBorder = !isCompleted && isSkipped;

    // Branch order mirrors the three-way ternary this chip replaced —
    // completed, then skipped, then the unresolved default — so the state
    // precedence cannot drift from what shipped before.
    if (isCompleted) {
      icon = Icons.check;
      chipColor = colorScheme.primaryContainer;
      onColor = colorScheme.onPrimaryContainer;
      label = 'Done';
    } else if (isSkipped) {
      icon = Icons.remove;
      onColor = colorScheme.onSurfaceVariant;
      label = 'Skipped';
    } else {
      icon = Icons.schedule;
      chipColor = colorScheme.surfaceContainerHighest;
      onColor = colorScheme.onSurfaceVariant;
      label = 'To do';
      border = Border.all(color: colorScheme.outlineVariant);
    }

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(8),
        border: border,
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

    if (!dashedBorder) return chip;
    return CustomPaint(
      painter: _DashedChipBorderPainter(color: colorScheme.outlineVariant),
      child: chip,
    );
  }
}

/// File-private dashed rounded border for [_StatusChip]'s `Skipped` state.
///
/// **A deliberate file-private duplicate**, per the duplication charter this
/// file already states for [_ValenceChip] below: visual chip and painter
/// mechanics live beside the widget that uses them rather than in a shared
/// module. Do not extract this into a common painter.
///
/// It carries forward the dash rhythm of `_DashedRegionPainter`, the free-time
/// painter Phase 33 retires from `free_time_row.dart` — `strokeWidth = 1`,
/// 2.0 dash, 2.0 gap, walked with `path.computeMetrics()` so the rhythm stays
/// even around the corners instead of restarting at each edge. The radius is
/// `Radius.circular(8)` rather than that painter's 8-for-a-region, matching
/// this chip's own `BorderRadius.circular(8)`.
class _DashedChipBorderPainter extends CustomPainter {
  const _DashedChipBorderPainter({required this.color});

  final Color color;

  static const double _radius = 8.0;
  static const double _dashWidth = 2.0;
  static const double _dashGap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0.0, metric.length)),
          paint,
        );
        distance = next + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedChipBorderPainter oldDelegate) =>
      oldDelegate.color != color;
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
