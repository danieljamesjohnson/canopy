import 'package:flutter/material.dart';

import '../../../data/models/scheduled_chunk.dart';

/// Dismissable card shown on HomeScreen when the end-of-day trigger is met
/// (after 6pm OR ≥50% of work chunks resolved).
///
/// Tapping "Close the day" routes to the existing EndOfDaySummaryScreen at
/// `/summary`. Dismiss state is in-memory only (same pattern as ReviewBanner).
class EndOfDayCard extends StatelessWidget {
  const EndOfDayCard({
    super.key,
    required this.chunks,
    required this.onDismiss,
    required this.onGoToSummary,
  });

  final List<ScheduledChunk> chunks;
  final VoidCallback onDismiss;
  final VoidCallback onGoToSummary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final workChunks =
        chunks.where((c) => c.chunkType == ChunkType.work).toList();
    final total = workChunks.length;
    final resolved = workChunks
        .where((c) => c.isCompleted || c.isSkipped || c.isDeferred)
        .length;

    return Dismissible(
      key: const Key('end_of_day_card'),
      onDismissed: (_) => onDismiss(),
      direction: DismissDirection.horizontal,
      child: Card(
        color: colorScheme.primaryContainer,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'How did today go?',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: onDismiss,
                            tooltip: 'Dismiss',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      Text(
                        '$resolved of $total chunks done',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 8),
                child: ElevatedButton(
                  onPressed: onGoToSummary,
                  child: const Text('Close the day'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Returns true when the end-of-day card should be shown.
///
/// Trigger: current local hour >= 18 (6pm) OR (work chunks non-empty AND
/// resolved / total >= 0.5). Extracted as a top-level function so widget
/// tests can exercise the logic in isolation.
bool shouldShowEodCard(List<ScheduledChunk> chunks) {
  final hour = DateTime.now().hour;
  if (hour >= 18) return true;
  final workChunks =
      chunks.where((c) => c.chunkType == ChunkType.work).toList();
  if (workChunks.isEmpty) return false;
  final resolved = workChunks
      .where((c) => c.isCompleted || c.isSkipped || c.isDeferred)
      .length;
  return resolved / workChunks.length >= 0.5;
}
