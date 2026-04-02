import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/goals_notifier.dart';
import '../../providers/schedule_notifier.dart';
import '../../data/models/scheduled_chunk.dart';
import 'widgets/chunk_card.dart';
import 'widgets/schedule_progress_bar.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  static const Map<int, Color> _moodColors = {
    1: Color(0xFF4A6275),
    2: Color(0xFF5C7A8A),
    3: Color(0xFF4A8C7A),
    4: Color(0xFF7AAF6A),
    5: Color(0xFFE8C547),
  };

  @override
  Widget build(BuildContext context) {
    final scheduleNotifier = context.watch<ScheduleNotifier>();

    if (!scheduleNotifier.hasScheduleToday) {
      return _buildEmptyState(context);
    }

    final schedule = scheduleNotifier.todaySchedule!;
    final mood = scheduleNotifier.moodIndex ?? 3;
    final moodColor = _moodColors[mood] ?? _moodColors[3]!;

    // Partition chunks: active (not skipped) and skipped.
    final activeChunks =
        schedule.chunks.where((c) => !c.isSkipped).toList();
    final skippedChunks =
        schedule.chunks.where((c) => c.isSkipped).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        backgroundColor: moodColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          ScheduleProgressBar(schedule: schedule, moodColor: moodColor),
          Expanded(
            child: ListView(
              children: [
                // Active (non-skipped) chunks with swipe gestures on work chunks.
                ...activeChunks.map(
                  (chunk) => _buildChunkItem(context, chunk, scheduleNotifier),
                ),
                // "Skipped today" expansion tile — hidden when no skipped chunks.
                if (skippedChunks.isNotEmpty)
                  _buildSkippedSection(context, skippedChunks),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChunkItem(
    BuildContext context,
    ScheduledChunk chunk,
    ScheduleNotifier scheduleNotifier,
  ) {
    final goalColor = _resolveGoalColor(context, chunk);
    final card = ChunkCard(chunk: chunk, goalColor: goalColor);

    // Only work chunks that are not yet completed or skipped get swipe wrapping.
    final isSwipeable =
        chunk.chunkType == ChunkType.work && !chunk.isCompleted && !chunk.isSkipped;

    if (!isSwipeable) return card;

    return Dismissible(
      key: ValueKey(chunk.id),
      // confirmDismiss always returns false — the card stays in position.
      // We use Dismissible purely for the drag gesture affordance.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await scheduleNotifier.markComplete(chunk.id);
        } else if (direction == DismissDirection.endToStart) {
          await scheduleNotifier.markSkipped(chunk.id);
        }
        return false;
      },
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        color: Colors.green.shade400,
        icon: Icons.check_circle_outline,
      ),
      secondaryBackground: _buildSwipeBackground(
        alignment: Alignment.centerRight,
        color: Colors.orange.shade400,
        icon: Icons.skip_next_outlined,
      ),
      child: card,
    );
  }

  Widget _buildSwipeBackground({
    required AlignmentGeometry alignment,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  Widget _buildSkippedSection(
    BuildContext context,
    List<ScheduledChunk> skippedChunks,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        title: Text(
          'Skipped today (${skippedChunks.length})',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: EdgeInsets.zero,
        children: skippedChunks.map((chunk) {
          final goalColor = _resolveGoalColor(context, chunk);
          return ChunkCard(chunk: chunk, goalColor: goalColor);
        }).toList(),
      ),
    );
  }

  /// Resolves goal color for a chunk by looking up its goalId in GoalsNotifier.
  Color? _resolveGoalColor(BuildContext context, ScheduledChunk chunk) {
    if (chunk.goalId == null) return null;
    final goals = context.read<GoalsNotifier>().goals;
    final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
    if (goal?.color != null) return hexToColor(goal!.color!);
    return null;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wb_sunny_outlined, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'Plan your day in 30 seconds.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us how you\'re feeling and we\'ll build your schedule.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.push('/schedule/checkin'),
                child: const Text('Start your day'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
