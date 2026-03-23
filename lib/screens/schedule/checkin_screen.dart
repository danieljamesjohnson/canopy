import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/daily_schedule.dart';
import '../../data/models/scheduled_chunk.dart';
import '../../providers/commitments_notifier.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/schedule_notifier.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  static const Map<int, Color> _moodColors = {
    1: Color(0xFF4A6275), // steel blue-grey (stormy)
    2: Color(0xFF5C7A8A), // slate (overcast)
    3: Color(0xFF4A8C7A), // muted teal (partly cloudy)
    4: Color(0xFF7AAF6A), // soft green (clearing)
    5: Color(0xFFE8C547), // warm amber (sunny)
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

  int? _selectedMood;
  bool _lighterDay = true;
  bool _scheduleGenerated = false;
  bool _isGenerating = false;

  Color get _backgroundColor {
    if (_selectedMood != null) {
      return _moodColors[_selectedMood!]!;
    }
    return Colors.transparent; // fallback; Builder supplies surface color
  }

  Future<void> _generate() async {
    if (_selectedMood == null || _isGenerating) return;
    setState(() => _isGenerating = true);

    await context.read<ScheduleNotifier>().generateToday(
          moodIndex: _selectedMood!,
          goals: context.read<GoalsNotifier>().goals,
          blocks: context.read<CommitmentsNotifier>().blocks,
        );

    if (mounted) {
      setState(() {
        _scheduleGenerated = true;
        _isGenerating = false;
      });
    }
  }

  String _buildAckText(DailySchedule schedule, int moodIndex) {
    final prefix = _moodPrefix[moodIndex] ?? '';
    final workChunks =
        schedule.chunks.where((c) => c.chunkType == ChunkType.work).toList();
    final count = workChunks.length;
    final firstName =
        workChunks.isNotEmpty ? workChunks.first.rationale : null;
    final countText = '$count chunk${count == 1 ? '' : 's'}.';
    final startText =
        firstName != null && firstName.isNotEmpty ? ' Starting with $firstName.' : '';
    return '$prefix $countText$startText';
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
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            // Follow-up toggle for mood 1-2
            if (_selectedMood != null && _selectedMood! <= 2) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Want a lighter day?',
                    style: TextStyle(
                      color: onBg,
                      fontSize: 16,
                    ),
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
    final bgColor = _moodColors[mood]!;

    final ackText = schedule != null ? _buildAckText(schedule, mood) : '';

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
