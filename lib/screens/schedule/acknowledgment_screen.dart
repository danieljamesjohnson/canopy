import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/goal.dart';
import '../../data/models/scheduled_chunk.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/schedule_notifier.dart';

/// Standalone acknowledgment screen.
///
/// Reads [ScheduleNotifier.todaySchedule] directly. Used when navigated to
/// as a separate route. In the current Phase 3 flow the acknowledgment content
/// is shown inline inside [CheckinScreen] via AnimatedSwitcher — this widget
/// exists for potential future standalone use.
class AcknowledgmentScreen extends StatelessWidget {
  const AcknowledgmentScreen({super.key});

  static const Map<int, Color> _moodColors = {
    1: Color(0xFF4A6275),
    2: Color(0xFF5C7A8A),
    3: Color(0xFF4A8C7A),
    4: Color(0xFF7AAF6A),
    5: Color(0xFFE8C547),
  };

  static const Map<int, String> _moodEmojis = {
    1: '🌧️',
    2: '🌥️',
    3: '⛅',
    4: '🌤️',
    5: '☀️',
  };

  static const Map<int, String> _moodPrefix = {
    1: 'Stormy day — keeping it light.',
    2: 'Overcast — gentle pace.',
    3: 'Partly cloudy — steady.',
    4: 'Clearing up — good flow.',
    5: 'Clear skies — let\'s go.',
  };

  String _buildAckText(ScheduleNotifier notifier, List<Goal> goals) {
    final schedule = notifier.todaySchedule;
    final mood = notifier.moodIndex ?? 3;
    if (schedule == null) return _moodPrefix[mood] ?? '';

    final prefix = _moodPrefix[mood] ?? '';
    final workChunks = schedule.chunks
        .where((c) => c.chunkType == ChunkType.work)
        .toList();
    final count = workChunks.length;
    // Prefer the goal's real name ("vibe code") over the raw rationale label
    // ("Habit"); commitment chunks (no goalId) fall back to the block name.
    final firstName = workChunks.isNotEmpty
        ? _firstChunkName(workChunks.first, goals)
        : null;
    final countText = '$count chunk${count == 1 ? '' : 's'}.';
    final startText = firstName != null && firstName.isNotEmpty
        ? ' Starting with $firstName.'
        : '';
    return '$prefix $countText$startText';
  }

  /// Resolves the display label for a chunk: the goal's real name when tied to
  /// a goal, otherwise the raw rationale (commitment block name).
  String _firstChunkName(ScheduledChunk chunk, List<Goal> goals) {
    if (chunk.goalId != null) {
      final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
      if (goal != null) return goal.name;
    }
    return chunk.rationale;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ScheduleNotifier>();
    final mood = notifier.moodIndex ?? 3;
    final bgColor = _moodColors[mood] ?? _moodColors[3]!;
    final goals = context.read<GoalsNotifier>().goals;
    final ackText = _buildAckText(notifier, goals);

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -300) {
            Navigator.of(context).pop();
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _moodEmojis[mood] ?? '⛅',
                  style: const TextStyle(fontSize: 72),
                ),
                const SizedBox(height: 32),
                Text(
                  ackText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Swipe up to begin',
                  style: TextStyle(
                    color: Colors.white.withAlpha(179),
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
