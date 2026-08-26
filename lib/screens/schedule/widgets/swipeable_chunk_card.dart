import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/models/energy_valence.dart';
import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/schedule_notifier.dart';
import 'chunk_card.dart';

/// The one-directional-or-horizontal swipe-to-resolve gesture shell for a
/// chunk row — a [Dismissible] wrapping an arbitrary [child], confined to
/// [visualHeight] when set.
///
/// **Extracted from [SwipeableChunkCard] (Phase 31, D-31-07), verbatim and
/// API-preserving.** This is a mechanical extraction, not a rewrite:
/// [SwipeableChunkCard] is now a thin wrapper that builds this shell with
/// [ChunkCard] as its [child], and every existing call site/test for
/// [SwipeableChunkCard] compiles and passes with zero edits. The reason to
/// extract rather than duplicate: D-31-07 needs the identical swipe contract
/// for a live break's row (which wraps [LiveRowCard]-adjacent content, not a
/// [ChunkCard]) — reusing this shell keeps exactly **one** [Dismissible]
/// definition for chunk rows in the codebase, so the swipe contract cannot
/// drift between the live and non-live arms.
///
/// Already-resolved (completed or skipped) chunks have [DismissDirection.none]
/// so they cannot be re-swiped. A break can never be [ScheduledChunk.isCompleted]
/// (D-31-01) — the `isCompleted` term in `resolved` is defensive/future-proofing
/// for breaks and load-bearing for work chunks.
class SwipeableRowShell extends StatelessWidget {
  const SwipeableRowShell({
    super.key,
    required this.chunk,
    this.visualHeight,
    required this.child,
  });

  final ScheduledChunk chunk;

  /// When non-null (Phase 31, D-31-02/PD-31-02), the swipe reveals AND
  /// [child] are each confined to a band exactly [visualHeight] tall,
  /// vertically centred inside whatever larger box the parent supplies —
  /// this is what lets a break's touch target exceed its painted slot
  /// without violating SKIPBREAK-02. Default `null` keeps every existing
  /// call site byte-for-byte unchanged (an identity transform: no
  /// confinement, the widget sizes to whatever the parent gives it).
  final double? visualHeight;

  /// The row's own painted content — a [ChunkCard] for the non-live arm, or
  /// the live row's own content for D-31-07's live-break arm. This widget
  /// does not know or care which; it only confines and wraps it.
  final Widget child;

  /// Confines [child] (a swipe-reveal background) to [visualHeight] when set,
  /// else returns it unchanged. See [visualHeight]'s doc comment.
  Widget _confineReveal(Widget child) {
    if (visualHeight == null) return child;
    return Align(
      alignment: Alignment.center,
      child: SizedBox(height: visualHeight, child: child),
    );
  }

  /// Confines [child] (this shell's own painted content) to [visualHeight]
  /// via `ClipRect` + `OverflowBox`, when set, else returns it unchanged.
  ///
  /// **PD-31-03 (31-01-PLAN.md).** `ClipRect`/`OverflowBox` live HERE, inside
  /// this shell, rather than in `today_screen.dart` — because the outer box
  /// this widget's `Dismissible` receives is deliberately taller than the
  /// slot (the grown hit-test envelope), and per `31-RESEARCH.md` every
  /// `RenderBox` bounds its own hit-testing to its own `size` regardless of
  /// any clip: leaving the clip outside the grown box would reject the
  /// slop-band touch before the `Dismissible` inside it ever saw it. This
  /// widget must NOT import `TimelineRowTile` — that horizontal-inset
  /// wrapper stays in `today_screen.dart`, applied outside this widget.
  Widget _confineContent(Widget child) {
    if (visualHeight == null) return child;
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        height: visualHeight,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _completeReveal(ColorScheme colorScheme) => Container(
    color: colorScheme.primary,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.only(left: 20),
    child: Icon(Icons.check_circle, color: colorScheme.onPrimary, size: 28),
  );

  Widget _skipReveal(ColorScheme colorScheme, double iconSize) => Container(
    color: colorScheme.error,
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    child: Icon(
      Icons.arrow_forward,
      color: colorScheme.onError,
      size: iconSize,
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Swipe-reveal backgrounds resolve from the ColorScheme, matching the
    // Complete/Skip semantics ChunkCard already uses for its button row
    // (primary for complete, error for skip). Raw Colors.* literals here
    // would bypass the theme and not adapt to dark mode — the UI-SPEC's
    // colour rule, and the tech-debt item Phase 22 closed in chunk_card.dart.
    final colorScheme = Theme.of(context).colorScheme;

    final isWork = chunk.chunkType == ChunkType.work;
    // A break can never be isCompleted (D-31-01) — this term is defensive
    // for breaks and load-bearing for work chunks (a completed work chunk
    // must not be re-swipeable in either direction).
    final resolved = chunk.isCompleted || chunk.isSkipped;
    // The shipped work-chunk value (28.0) must stay exactly that; the
    // clamped branch is D-31-02's rule so a reveal icon fits inside a
    // confined band as small as a 5-minute break's 20dp slot.
    final revealIconSize = visualHeight == null
        ? 28.0
        : math.max(12.0, math.min(20.0, visualHeight! - 4.0));

    return Dismissible(
      key: ValueKey(chunk.id),
      // Resolved chunks cannot be re-swiped. A break can never complete
      // (D-31-01), so a break's only enabled direction is endToStart (skip).
      direction: resolved
          ? DismissDirection.none
          : (isWork ? DismissDirection.horizontal : DismissDirection.endToStart),
      // confirmDismiss always returns false — card stays in the list.
      // Dismissible is used purely as a gesture affordance.
      confirmDismiss: (direction) async {
        final notifier = context.read<ScheduleNotifier>();
        if (direction == DismissDirection.startToEnd) {
          await notifier.markComplete(chunk.id);
          HapticFeedback.lightImpact();
        } else {
          await notifier.markSkipped(chunk.id);
          HapticFeedback.lightImpact();
        }
        return false;
      },
      // PD-31-05 (31-01-PLAN.md), verified against the Flutter SDK this
      // session: Dismissible's constructor asserts
      // `secondaryBackground == null || background != null`, and
      // _DismissibleState.build only substitutes `secondaryBackground` when
      // it is non-null — otherwise `background` is used for EVERY direction,
      // including endToStart. So a one-directional break must supply its
      // reveal as `background` (never as `secondaryBackground` alone, which
      // would assert-fail in debug): `background` is always non-null;
      // `secondaryBackground` is non-null only for work chunks.
      background: _confineReveal(
        isWork
            ? _completeReveal(colorScheme)
            : _skipReveal(colorScheme, revealIconSize),
      ),
      secondaryBackground: isWork
          ? _confineReveal(_skipReveal(colorScheme, 28.0))
          : null,
      child: _confineContent(child),
    );
  }
}

/// Wraps [ChunkCard] in a single, unconditional [Dismissible] (via
/// [SwipeableRowShell]) providing swipe-to-skip for every chunk row; work
/// chunks additionally support swipe-to-complete (right) and tap.
///
/// **Supersedes `29-UI-SPEC.md`'s "non-interactive at every density" clause
/// for the swipe axis only (Phase 31, SKIPBREAK-01/02).** That document's
/// early return excluded break chunks from `Dismissible` entirely — deleted
/// here, per the `promote` decision (31-01-PLAN.md): skippability is the
/// general case, completability is a work-chunk-only detail of it. Tap
/// access stays out of scope for a break — the owner's 2026-08-21
/// instruction — enforced below by the `isWork` gate on `onTap`, not by a
/// separate early return.
///
/// **Phase 31, D-31-07:** the actual swipe/dismiss mechanics live in
/// [SwipeableRowShell] now, extracted verbatim so a live break's row can
/// reuse the identical gesture contract. This widget's own public surface —
/// constructor, every parameter, and the `isWork && !resolved` `onTap`
/// gating — is unchanged.
class SwipeableChunkCard extends StatelessWidget {
  const SwipeableChunkCard({
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
    this.visualHeight,
  });

  final ScheduledChunk chunk;

  /// The goal's color for the left bar. Null → falls back to theme primary.
  final Color? goalColor;

  /// The resolved goal name to display as primary title on work cards.
  final String? goalName;

  /// Pre-mapped human-readable rationale. Passed through to ChunkCard.
  final String? displayRationale;

  /// The goal's priority weight. Passed through to ChunkCard for badge
  /// rendering. Null for break chunks and commitment chunks.
  final double? goalPriorityWeight;

  /// The goal's emoji tag. Passed through to ChunkCard. Null for commitment chunks.
  final String? goalEmojiTag;

  /// The goal's energy valence. Passed through to ChunkCard. Null for commitment chunks.
  final EnergyValence? goalValence;

  /// Tap callback. Null for break cards and resolved work chunks — the
  /// `isWork` gate below is the single thing enforcing "no tap on a break",
  /// by the owner's explicit instruction (2026-08-21).
  final VoidCallback? onTap;

  /// Forwarded to [ChunkCard] — see its doc comment. Also applied on the
  /// break-card early-return path below so a gutter-driven screen never
  /// sees a break card's own clock time doubled.
  final bool showStartTime;

  /// Forwarded to [ChunkCard] — see its doc comment. Also applied on the
  /// break-card early-return path below (PD-4, 26-02-PLAN.md): a compact
  /// break must not render at [ChunkCardDensity.detailed] inside a tiny
  /// slot just because this early return forgot to forward it.
  final ChunkCardDensity density;

  /// When non-null (Phase 31, D-31-02/PD-31-02), the card's own painted
  /// content AND its swipe reveals are each confined to a band exactly
  /// [visualHeight] tall, vertically centred inside whatever larger box the
  /// parent supplies — this is what lets a break's touch target exceed its
  /// painted slot without violating SKIPBREAK-02. Default `null` keeps every
  /// existing call site byte-for-byte unchanged (an identity transform: no
  /// confinement, the widget sizes to whatever the parent gives it).
  final double? visualHeight;

  @override
  Widget build(BuildContext context) {
    final isWork = chunk.chunkType == ChunkType.work;
    // A break can never be isCompleted (D-31-01) — this term is defensive
    // for breaks and load-bearing for work chunks (a completed work chunk
    // must not be re-swipeable in either direction).
    final resolved = chunk.isCompleted || chunk.isSkipped;
    return SwipeableRowShell(
      chunk: chunk,
      visualHeight: visualHeight,
      child: ChunkCard(
        chunk: chunk,
        goalColor: goalColor,
        goalName: goalName,
        displayRationale: displayRationale,
        goalPriorityWeight: goalPriorityWeight,
        goalEmojiTag: goalEmojiTag,
        goalValence: goalValence,
        showStartTime: showStartTime,
        density: density,
        // A break never receives onTap, at any density — the owner's
        // 2026-08-21 instruction. This isWork gate is the ONLY thing
        // enforcing that after the `promote` decision deleted the old
        // break-only early return.
        onTap: (isWork && !resolved) ? onTap : null,
      ),
    );
  }
}
