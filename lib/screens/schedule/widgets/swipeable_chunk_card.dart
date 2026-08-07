import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/models/energy_valence.dart';
import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/schedule_notifier.dart';
import 'chunk_card.dart';

/// Wraps [ChunkCard] in a [Dismissible] to provide swipe-to-complete (right)
/// and swipe-to-skip (left) gestures for work chunks.
///
/// Break chunks are returned as plain [ChunkCard]s without swipe wrapping.
/// Already-resolved (completed or skipped) chunks have [DismissDirection.none]
/// so they cannot be re-swiped.
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

  /// Tap callback. Null for break cards and resolved work chunks.
  final VoidCallback? onTap;

  /// Forwarded to [ChunkCard] — see its doc comment. Also applied on the
  /// break-card early-return path below so a gutter-driven screen never
  /// sees a break card's own clock time doubled.
  final bool showStartTime;

  @override
  Widget build(BuildContext context) {
    // Break cards are not swipeable and do not receive goal name or tap.
    if (chunk.chunkType != ChunkType.work) {
      return ChunkCard(
        chunk: chunk,
        goalColor: goalColor,
        showStartTime: showStartTime,
      );
    }

    return Dismissible(
      key: ValueKey(chunk.id),
      // Resolved chunks cannot be re-swiped.
      direction: chunk.isCompleted || chunk.isSkipped
          ? DismissDirection.none
          : DismissDirection.horizontal,
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
      background: Container(
        color: Colors.green.shade400,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check_circle, color: Colors.white, size: 28),
      ),
      secondaryBackground: Container(
        color: Colors.orange.shade300,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.arrow_forward, color: Colors.white, size: 28),
      ),
      child: ChunkCard(
        chunk: chunk,
        goalColor: goalColor,
        goalName: goalName,
        displayRationale: displayRationale,
        goalPriorityWeight: goalPriorityWeight,
        goalEmojiTag: goalEmojiTag,
        goalValence: goalValence,
        showStartTime: showStartTime,
        // Resolved chunks are not tappable — null out the callback.
        onTap: (chunk.isCompleted || chunk.isSkipped) ? null : onTap,
      ),
    );
  }
}
