import 'package:flutter/material.dart';
import '../../../data/models/daily_schedule.dart';
import '../../../data/models/scheduled_chunk.dart';

/// Displays an 'X of Y Chunks' label and a LinearProgressIndicator tinted
/// with the current mood color.
class ScheduleProgressBar extends StatelessWidget {
  const ScheduleProgressBar({
    super.key,
    required this.schedule,
    required this.moodColor,
  });

  final DailySchedule schedule;
  final Color moodColor;

  @override
  Widget build(BuildContext context) {
    final workChunks = schedule.chunks
        .where((c) => c.chunkType == ChunkType.work)
        .toList();
    final total = workChunks.length;
    final completed = workChunks.where((c) => c.isCompleted).length;
    final progress = total == 0 ? 0.0 : completed / total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$completed of $total Chunks',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            color: moodColor,
            backgroundColor: moodColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
