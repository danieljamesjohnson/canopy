import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/daily_schedule.dart';
import '../../data/models/goal.dart';
import '../../data/models/scheduled_chunk.dart';
import '../../providers/commitments_notifier.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/schedule_notifier.dart';
import '../../providers/theme_notifier.dart';
import '../../services/notification_service.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  // Mood seed palette is the single source of truth in `ThemeNotifier.moodSeeds`
  // (Phase 6 Plan 02). This screen reads it directly via `ThemeNotifier.moodSeeds[mood]`.

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

  int? _selectedMood;
  bool _lighterDay = true;
  bool _scheduleGenerated = false;
  bool _isGenerating = false;

  Color get _backgroundColor {
    if (_selectedMood != null) {
      return ThemeNotifier.moodSeeds[_selectedMood!]!;
    }
    return Colors.transparent; // fallback; Builder supplies surface color
  }

  Future<void> _generate() async {
    if (_selectedMood == null || _isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      await context.read<ScheduleNotifier>().generateToday(
        moodIndex: _selectedMood!,
        goals: context.read<GoalsNotifier>().goals,
        blocks: context.read<CommitmentsNotifier>().blocks,
        lighterDay: _lighterDay,
      );

      // Request iOS notification permission after first successful check-in.
      // No-op on Web and non-iOS platforms; iOS ignores if already granted.
      await NotificationService.requestIOSPermissions();

      if (mounted) {
        setState(() {
          _scheduleGenerated = true;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        // Optionally surface feedback to the user here.
      }
      rethrow;
    }
  }

  String _buildAckText(
    DailySchedule schedule,
    int moodIndex,
    List<Goal> goals,
  ) {
    final prefix = _moodPrefix[moodIndex] ?? '';
    final workChunks = schedule.chunks
        .where((c) => c.chunkType == ChunkType.work)
        .toList();
    final count = workChunks.length;
    // Prefer the goal's real name over the raw rationale label ("Habit");
    // commitment chunks (no goalId) fall back to the block name.
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
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final bgColor = _selectedMood != null ? _backgroundColor : surfaceColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _scheduleGenerated
          ? null
          : AppBar(
              backgroundColor: bgColor,
              elevation: 0,
              title: Text(
                'How are you feeling?',
                style: TextStyle(
                  color: _selectedMood != null
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              iconTheme: IconThemeData(
                color: _selectedMood != null
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _scheduleGenerated
            ? _buildAcknowledgmentBody(context)
            : _buildCheckinBody(context),
      ),
    );
  }

  Widget _buildCheckinBody(BuildContext context) {
    final bgColor = _selectedMood != null
        ? _backgroundColor
        : Theme.of(context).colorScheme.surface;
    final onBg = _selectedMood != null
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return Center(
      key: const ValueKey('checkin'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            // Emoji row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _moodEmojis.entries.map((entry) {
                final mood = entry.key;
                final emoji = entry.value;
                final isSelected = _selectedMood == mood;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMood = mood;
                    });
                    // Phase 6 Plan 05: route the mood tap through ThemeNotifier
                    // so Plan 04's themeAnimationDuration warms the ColorScheme
                    // app-wide (AC-6, D-09).
                    context.read<ThemeNotifier>().setMoodSeed(
                      ThemeNotifier.moodSeeds[mood]!,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white.withAlpha(51) // ~20% opacity
                          : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 36)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            // Follow-up toggle — visible for all moods once selected (ENGINE-05)
            if (_selectedMood != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Want a lighter day?',
                    style: TextStyle(color: onBg, fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _lighterDay,
                    onChanged: (val) => setState(() => _lighterDay = val),
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.white.withAlpha(102),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            // Confirm button
            if (_selectedMood != null) ...[
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: bgColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isGenerating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: bgColor,
                          ),
                        )
                      : Text(
                          "Let's go",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: bgColor,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAcknowledgmentBody(BuildContext context) {
    final schedule = context.watch<ScheduleNotifier>().todaySchedule;
    final mood = _selectedMood ?? 3;
    final bgColor = ThemeNotifier.moodSeeds[mood]!;

    final goals = context.read<GoalsNotifier>().goals;
    final ackText = schedule != null
        ? _buildAckText(schedule, mood, goals)
        : '';

    return GestureDetector(
      key: const ValueKey('acknowledgment'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -300) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: bgColor,
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
                    color: Colors.white.withAlpha(179), // ~70% opacity
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
