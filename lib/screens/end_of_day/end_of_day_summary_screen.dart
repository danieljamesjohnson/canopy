import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/models/scheduled_chunk.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/schedule_notifier.dart';
import '../../utils/time_format.dart';

/// Full-screen end-of-day summary showing hero completed count, per-goal
/// breakdown, skipped note, and a "See you tomorrow" close button.
///
/// Route: `/summary` — outside [StatefulShellRoute] so no bottom nav bar
/// is shown.
class EndOfDaySummaryScreen extends StatelessWidget {
  const EndOfDaySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final schedule = context.watch<ScheduleNotifier>().todaySchedule;
    if (schedule == null) {
      return const Scaffold(body: Center(child: Text('No schedule today.')));
    }

    final goals = context.read<GoalsNotifier>().goals;
    final workChunks = schedule.chunks
        .where((c) => c.chunkType == ChunkType.work)
        .toList();
    final completed = workChunks.where((c) => c.isCompleted).length;
    final skipped = workChunks.where((c) => c.isSkipped).length;
    final total = workChunks.length;

    // Build per-goal breakdown map.
    final byGoal =
        <String, ({int done, int total, String name, String? colorHex})>{};
    for (final chunk in workChunks) {
      final gid = chunk.goalId ?? '';
      if (gid.isEmpty) continue;
      final goal = goals.where((g) => g.id == gid).firstOrNull;
      final entry =
          byGoal[gid] ??
          (
            done: 0,
            total: 0,
            name: goal?.name ?? 'Unknown',
            colorHex: goal?.color,
          );
      byGoal[gid] = (
        done: entry.done + (chunk.isCompleted ? 1 : 0),
        total: entry.total + 1,
        name: entry.name,
        colorHex: entry.colorHex,
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Your day'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section A — Hero stat
              const SizedBox(height: 32),
              Center(
                child: Text(
                  '$completed',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 48,
                  ),
                ),
              ),
              Center(
                child: Text(
                  'of $total chunks complete',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Section B — Per-goal breakdown
              if (byGoal.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: 4,
                  ),
                  child: Text(
                    'By goal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final entry in byGoal.values)
                  SizedBox(
                    height: 48,
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 6,
                        backgroundColor: entry.colorHex != null
                            ? hexToColor(entry.colorHex!)
                            : theme.colorScheme.primary,
                      ),
                      title: Text(entry.name),
                      trailing: Text(
                        '${entry.done} of ${entry.total}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],

              // Section C — Skipped count (only if any skipped)
              if (skipped > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                  child: Text(
                    '$skipped chunk${skipped == 1 ? '' : 's'} set aside today.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

              // Section D — Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 48),
                child: ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('See you tomorrow'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
