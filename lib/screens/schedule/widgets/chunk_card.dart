import 'package:flutter/material.dart';
import '../../../data/models/scheduled_chunk.dart';

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
  });

  final ScheduledChunk chunk;

  /// The goal's color for the left bar. Null → falls back to theme primary.
  /// Pass null for commitment-anchored work chunks (no goalId).
  final Color? goalColor;

  @override
  Widget build(BuildContext context) {
    switch (chunk.chunkType) {
      case ChunkType.shortBreak:
        return _buildShortBreak(context);
      case ChunkType.longBreak:
        return _buildLongBreak(context);
      case ChunkType.work:
        return _buildWork(context);
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
          Icon(Icons.pause, size: 16, color: theme.colorScheme.onSurfaceVariant),
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
            const Text('\u2615', style: TextStyle(fontSize: 24)),
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

  Widget _buildWork(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = chunk.isCompleted || chunk.isSkipped
        ? Colors.grey.shade400
        : (goalColor ?? theme.colorScheme.primary);
    final contentOpacity = chunk.isCompleted || chunk.isSkipped ? 0.5 : 1.0;

    return Card(
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                  chunk.rationale.isNotEmpty
                                      ? chunk.rationale
                                      : 'Work block',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
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
                          if (chunk.anchoredStartMinutes != null) ...[
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
                        ? Icon(Icons.check_circle, color: Colors.green.shade600)
                        : chunk.isSkipped
                            ? Icon(Icons.arrow_forward,
                                color: theme.colorScheme.onSurfaceVariant)
                            : Icon(Icons.radio_button_unchecked,
                                color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
