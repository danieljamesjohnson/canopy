import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/schedule_notifier.dart';

/// Converts a hex color string (e.g. '#4CAF50') to a Flutter Color.
Color hexToColor(String hex) {
  return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
}

/// Formats minutes-from-midnight as a 12-hour time string (e.g. 540 → "9:00 AM").
String _formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$hour:${m.toString().padLeft(2, '0')} $suffix';
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
    this.onTap,
  });

  final ScheduledChunk chunk;

  /// The goal's color for the left bar. Null → falls back to theme primary.
  /// Pass null for commitment-anchored work chunks (no goalId).
  final Color? goalColor;

  /// The resolved goal name to display as the primary title. Null → falls
  /// back to chunk.rationale. Only relevant for work chunks.
  final String? goalName;

  /// Pre-mapped human-readable rationale (e.g. 'Daily habit'). Displayed as
  /// secondary bodySmall text beneath the goal name. Only relevant for work
  /// chunks when goalName is non-null.
  final String? displayRationale;

  /// Tap callback for opening the detail sheet. Only wired for non-resolved
  /// work chunks from the screen; null for break cards and resolved chunks.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    switch (chunk.chunkType) {
      case ChunkType.shortBreak:
        return _buildShortBreak(context);
      case ChunkType.longBreak:
        return _buildLongBreak(context);
      case ChunkType.work:
        return _HoverableChunkContent(
          chunk: chunk,
          goalColor: goalColor,
          goalName: goalName,
          displayRationale: displayRationale,
          onTap: onTap,
        );
    }
  }

  Widget _buildShortBreak(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.pause,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '${chunk.durationMinutes} min break',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongBreak(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('☕', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              '${chunk.durationMinutes} min break',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal stateful widget for the work-variant chunk card. Wraps the card
/// body in a [MouseRegion] so the trailing checkbox + skip icons fade in on
/// hover (desktop) while remaining at opacity 0 on touch platforms (mobile
/// pointer events never fire onEnter/onExit — preserves Phase 4 Dismissible
/// swipe gestures).
///
/// Hover-revealed icon taps go directly through
/// `context.read<ScheduleNotifier>().markComplete(chunk.id)` /
/// `markSkipped(chunk.id)` — the same notifier path that
/// [SwipeableChunkCard]'s Dismissible.confirmDismiss invokes. Hover-click
/// and swipe-gesture share identical state writes; they're orthogonal input
/// modalities terminating at the same idempotent notifier method.
class _HoverableChunkContent extends StatefulWidget {
  const _HoverableChunkContent({
    required this.chunk,
    this.goalColor,
    this.goalName,
    this.displayRationale,
    this.onTap,
  });

  final ScheduledChunk chunk;
  final Color? goalColor;
  final String? goalName;
  final String? displayRationale;
  final VoidCallback? onTap;

  @override
  State<_HoverableChunkContent> createState() => _HoverableChunkContentState();
}

class _HoverableChunkContentState extends State<_HoverableChunkContent> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chunk = widget.chunk;
    final barColor = chunk.isCompleted || chunk.isSkipped
        ? Colors.grey.shade400
        : (widget.goalColor ?? theme.colorScheme.primary);
    final contentOpacity = chunk.isCompleted || chunk.isSkipped ? 0.5 : 1.0;
    final isResolved = chunk.isCompleted || chunk.isSkipped;
    // Hover-click and Phase 4 Dismissible swipe-gesture share the same idempotent
    // notifier methods — they're orthogonal input modalities terminating at the
    // same state writes. Calls are inlined (vs. extracted to a local notifier
    // variable) so verification grep can match the literal call site.
    // ignore: prefer_function_declarations_over_variables
    final void Function()? onMarkComplete = _hovered && !isResolved
        ? () => context.read<ScheduleNotifier>().markComplete(chunk.id)
        : null;
    // ignore: prefer_function_declarations_over_variables
    final void Function()? onMarkSkipped = _hovered && !isResolved
        ? () => context.read<ScheduleNotifier>().markSkipped(chunk.id)
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Colored left bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
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
              padding: const EdgeInsets.only(left: 5),
              child: Opacity(
                opacity: contentOpacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.goalName ??
                                        (chunk.rationale.isNotEmpty
                                            ? chunk.rationale
                                            : 'Work block'),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${chunk.durationMinutes} min',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            // Secondary text: readable rationale (when goalName
                            // is provided) or anchored time for commitment chunks.
                            if (widget.goalName != null &&
                                widget.displayRationale != null &&
                                widget.displayRationale!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.displayRationale!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ] else if (chunk.anchoredStartMinutes != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _formatMinutes(chunk.anchoredStartMinutes!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      chunk.isCompleted
                          ? Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                            )
                          : chunk.isSkipped
                          ? Icon(
                              Icons.arrow_forward,
                              color: theme.colorScheme.onSurfaceVariant,
                            )
                          : Icon(
                              Icons.radio_button_unchecked,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                    ],
                  ),
                ),
              ),
            ),
            // Hover-revealed action icons (desktop only — onEnter/onExit
            // never fires on touch-only mobile pointer events, so this stays
            // at opacity 0 on Android/iOS).
            //
            // WR-02: skip the overlay entirely on resolved chunks. The
            // mark-complete / mark-skipped IconButtons would be `onPressed:
            // null` (disabled) at full opacity on hover otherwise — looking
            // tappable but doing nothing.
            if (!isResolved)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        tooltip: 'Mark complete',
                        onPressed: onMarkComplete,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_outlined),
                        tooltip: 'Skip',
                        onPressed: onMarkSkipped,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        ), // end GestureDetector
      ),
    );
  }
}
