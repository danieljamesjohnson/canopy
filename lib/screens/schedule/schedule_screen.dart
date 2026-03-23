import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/goals_notifier.dart';
import '../../providers/schedule_notifier.dart';
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
            child: ListView.builder(
              itemCount: schedule.chunks.length,
              itemBuilder: (context, i) {
                final chunk = schedule.chunks[i];
                Color? goalColor;
                if (chunk.goalId != null) {
                  final goals = context.read<GoalsNotifier>().goals;
                  final goal = goals
                      .where((g) => g.id == chunk.goalId)
                      .firstOrNull;
                  if (goal?.color != null) goalColor = hexToColor(goal!.color!);
                }
                return ChunkCard(chunk: chunk, goalColor: goalColor);
              },
            ),
          ),
        ],
      ),
    );
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
