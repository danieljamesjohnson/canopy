import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/models/energy_valence.dart';
import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/schedule_notifier.dart';
import 'chunk_card.dart';

/// The one-directional-or-horizontal swipe-to-resolve gesture shell for a
/// chunk row — a [Dismissible] wrapping an arbitrary [child].
///
/// **Extracted from [SwipeableChunkCard] (Phase 31, D-31-07), verbatim and
/// API-preserving.** This is a mechanical extraction, not a rewrite:
/// [SwipeableChunkCard] is now a thin wrapper that builds this shell with
/// [ChunkCard] as its [child], and every existing call site/test for
/// [SwipeableChunkCard] compiles and passes with zero edits.
///
/// **Phase 32 (D-32-02, TAPBREAK-01): the confinement mechanism is
/// RETIRED.** This shell used to accept a `visualHeight` parameter (Phase
/// 31, D-31-02/PD-31-02) so a break's grown hit-test envelope could exceed
/// its painted slot while `_confineReveal`/`_confineContent` clipped the
/// paint back down to the true slot. Breaks are button-only now — no swipe
/// target to widen — and the live break's own `SwipeableRowShell` call site
/// (`today_screen.dart`) is deleted with it, so every remaining caller (work
/// chunks only) always passed `null` even before this phase; `visualHeight`
/// had zero live non-null callers. Deleted rather than left
/// present-but-uncalled, per this phase's own "retire deliberately" charter
/// — Dart does not warn about an unused public parameter carrying a default
/// value, so nothing else would have forced the issue
/// (`32-RESEARCH.md` Pitfall 2).
///
/// Already-resolved (completed or skipped) chunks have [DismissDirection.none]
/// so they cannot be re-swiped. A break can never be [ScheduledChunk.isCompleted]
/// (D-31-01) — the `isCompleted` term in `resolved` is defensive/future-proofing
/// for breaks and load-bearing for work chunks.
class SwipeableRowShell extends StatelessWidget {
  const SwipeableRowShell({
    super.key,
    required this.chunk,
    required this.child,
  });

  final ScheduledChunk chunk;

  /// The row's own painted content — a [ChunkCard] for the work-chunk arm,
  /// the only caller left after Phase 32 retires the live break's own call
  /// site. This widget does not know or care which; it only wraps it.
  final Widget child;

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
    // Phase 32: the confined branch of this value is retired along with
    // `visualHeight` — every remaining caller is a work chunk, which always
    // used the unconfined 28.0 value.
    const revealIconSize = 28.0;

    return Dismissible(
      key: ValueKey(chunk.id),
      // Resolved chunks cannot be re-swiped. A break can never complete
      // (D-31-01), so a break's only enabled direction is endToStart (skip).
      direction: resolved
          ? DismissDirection.none
          : (isWork
                ? DismissDirection.horizontal
                : DismissDirection.endToStart),
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
      background: isWork
          ? _completeReveal(colorScheme)
          : _skipReveal(colorScheme, revealIconSize),
      secondaryBackground: isWork ? _skipReveal(colorScheme, 28.0) : null,
      child: child,
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

  @override
  Widget build(BuildContext context) {
    // Phase 32 (TAPBREAK-01, D-32-02): RESTORED — this is a revert of
    // Phase 31's `promote` decision, which deleted this exact early return
    // so every chunk type reached `Dismissible`. Breaks no longer use any
    // swipe mechanism at all (button-only, D-32-02), so this early return
    // comes back verbatim: a break renders through `ChunkCard` directly and
    // never reaches `SwipeableRowShell`/`Dismissible`. `onTap` stays null —
    // tappable is still out of scope (owner, 2026-08-21, unchanged).
    if (chunk.chunkType != ChunkType.work) {
      return ChunkCard(
        chunk: chunk,
        goalColor: goalColor,
        density: density,
        showStartTime: showStartTime,
      );
    }

    final isWork = chunk.chunkType == ChunkType.work;
    // A break can never be isCompleted (D-31-01) — this term is defensive
    // for breaks and load-bearing for work chunks (a completed work chunk
    // must not be re-swipeable in either direction).
    final resolved = chunk.isCompleted || chunk.isSkipped;
    return SwipeableRowShell(
      chunk: chunk,
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
