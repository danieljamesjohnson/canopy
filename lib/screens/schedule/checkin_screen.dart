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
  bool _scheduleGenerated = false;
  bool _isGenerating = false;

  // CHECKIN-01: three new state fields added alongside existing ones.
  // _generationDone drives the AnimatedSwitcher to the decision screen (Task 2).
  // _hoveredMoods / _pressedMoods drive luminance-adaptive hover/pressed visuals.
  bool _generationDone = false;
  final Map<int, bool> _hoveredMoods = {};
  final Map<int, bool> _pressedMoods = {};

  Color get _backgroundColor {
    if (_selectedMood != null) {
      return ThemeNotifier.moodSeeds[_selectedMood!]!;
    }
    return Colors.transparent; // fallback; Builder supplies surface color
  }

  /// Luminance-adaptive foreground color for text/icons overlaid on the
  /// mood background (CHECKIN-01). Replaces all hardcoded `Colors.white`
  /// foreground references when `_selectedMood != null`.
  ///
  /// Returns `Color(0xFF1A1A1A)` (near-black) for light backgrounds
  /// (luminance > 0.35 — moods 4 and 5 require this to pass WCAG AA).
  /// Returns `Colors.white` for dark backgrounds (moods 1-3).
  /// Falls back to `colorScheme.onSurface` when no mood is selected.
  Color get _onBgColor {
    if (_selectedMood == null) return Theme.of(context).colorScheme.onSurface;
    final bg = _backgroundColor;
    final luminance = bg.computeLuminance();
    // WCAG requirement: use dark text on light backgrounds (luminance > 0.35).
    // Mood 5 (#E8C547 amber, luminance ≈ 0.55) and mood 4 (#7AAF6A sage,
    // luminance ≈ 0.36) both exceed 0.35 and require the dark foreground.
    return luminance > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;
  }

  /// Resolves the emoji target background color, incorporating hover and
  /// pressed states with luminance-adaptive base color (CHECKIN-01).
  Color _resolveEmojiBackground(int mood, bool isSelected) {
    final isHovered = _hoveredMoods[mood] ?? false;
    final isPressed = _pressedMoods[mood] ?? false;
    final luminance =
        _selectedMood != null ? _backgroundColor.computeLuminance() : 0.0;
    final base =
        luminance > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;
    if (isSelected) {
      return base.withAlpha(isPressed ? 77 : (isHovered ? 64 : 51));
    } else {
      return base.withAlpha(isHovered ? 26 : 0);
    }
  }

  Future<void> _generate() async {
    if (_selectedMood == null || _isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      await context.read<ScheduleNotifier>().generateToday(
        moodIndex: _selectedMood!,
        goals: context.read<GoalsNotifier>().goals,
        blocks: context.read<CommitmentsNotifier>().blocks,
        lighterDay: false, // provisional — decision screen may regenerate
      );

      // Request iOS notification permission after first successful check-in.
      // No-op on Web and non-iOS platforms; iOS ignores if already granted.
      await NotificationService.requestIOSPermissions();

      if (mounted) {
        setState(() {
          _generationDone = true; // triggers AnimatedSwitcher → decision screen
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _commitAndProceed({required bool lighterDay}) async {
    if (lighterDay) {
      // Regenerate with lighter day — fast engine call; overwrites the
      // provisional lighterDay:false schedule generated in _generate().
      await context.read<ScheduleNotifier>().generateToday(
        moodIndex: _selectedMood!,
        goals: context.read<GoalsNotifier>().goals,
        blocks: context.read<CommitmentsNotifier>().blocks,
        lighterDay: true,
      );
    }
    // else: reuse the schedule already generated in _generate() (lighterDay: false).
    if (mounted) {
      setState(() => _scheduleGenerated = true);
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
                  // CHECKIN-01: _onBgColor replaces hardcoded Colors.white
                  color: _selectedMood != null
                      ? _onBgColor
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              iconTheme: IconThemeData(
                // CHECKIN-01: _onBgColor replaces hardcoded Colors.white
                color: _selectedMood != null
                    ? _onBgColor
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _scheduleGenerated
            ? _buildAcknowledgmentBody(context)
            : _generationDone
                ? _buildDecisionBody(context)
                : _buildCheckinBody(context),
      ),
    );
  }

  Widget _buildCheckinBody(BuildContext context) {
    final bgColor = _selectedMood != null
        ? _backgroundColor
        : Theme.of(context).colorScheme.surface;

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
                // CHECKIN-01: wrap GestureDetector in MouseRegion for hover,
                // add onTapDown/onTapUp/onTapCancel for pressed visual feedback.
                return MouseRegion(
                  onEnter: (_) =>
                      setState(() => _hoveredMoods[mood] = true),
                  onExit: (_) =>
                      setState(() => _hoveredMoods[mood] = false),
                  child: GestureDetector(
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
                    onTapDown: (_) =>
                        setState(() => _pressedMoods[mood] = true),
                    onTapUp: (_) =>
                        setState(() => _pressedMoods[mood] = false),
                    onTapCancel: () =>
                        setState(() => _pressedMoods[mood] = false),
                    child: AnimatedContainer(
                      // CHECKIN-01: 120ms hover timing per UI-SPEC
                      duration: const Duration(milliseconds: 120),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // CHECKIN-01: luminance-adaptive hover/pressed color
                        color: _resolveEmojiBackground(mood, isSelected),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 36)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            // Confirm button — visible once mood is selected.
            // Inline "Want a lighter day?" Switch removed (CHECKIN-02).
            if (_selectedMood != null) ...[
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  // CHECKIN-01 / Pitfall 6: non-null no-op during generation
                  // avoids the unreadable Material disabled foreground on light
                  // backgrounds (e.g. amber mood 5).
                  onPressed: _isGenerating ? () {} : _generate,
                  style: ElevatedButton.styleFrom(
                    // CHECKIN-01: luminance-adaptive button colors
                    backgroundColor: _onBgColor,
                    foregroundColor: _backgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    // StadiumBorder adapts to button height (e.g. spinner swap)
                    shape: const StadiumBorder(),
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
                            color: _backgroundColor,
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

  Widget _buildDecisionBody(BuildContext context) {
    final onBg = _onBgColor;
    return Container(
      key: const ValueKey('decision'),
      width: double.infinity,
      height: double.infinity,
      color: _backgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ready to start?',
                    style: TextStyle(
                      color: onBg,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your pace for today',
                    style: TextStyle(
                      color: onBg.withAlpha(179),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _LighterDayCard(
                    icon: Icons.bolt_outlined,
                    title: 'Full day',
                    subtitle: 'Push forward with your complete plan',
                    onBgColor: onBg,
                    onTap: () => _commitAndProceed(lighterDay: false),
                  ),
                  const SizedBox(height: 12),
                  _LighterDayCard(
                    icon: Icons.self_improvement_outlined,
                    title: 'Lighter day',
                    subtitle: 'A gentler pace — fewer chunks, lower stakes',
                    onBgColor: onBg,
                    onTap: () => _commitAndProceed(lighterDay: true),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        setState(() => _generationDone = false),
                    child: Text(
                      'Go back',
                      style: TextStyle(color: onBg.withAlpha(179)),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

// ---------------------------------------------------------------------------
// _LighterDayCard — private StatefulWidget for lighter-day choice cards.
// Used only in _buildDecisionBody. Provides AnimatedScale press feedback,
// MouseRegion hover states, and GestureDetector tap handling (CHECKIN-02).
// ---------------------------------------------------------------------------

class _LighterDayCard extends StatefulWidget {
  const _LighterDayCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onBgColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color onBgColor;
  final VoidCallback onTap;

  @override
  State<_LighterDayCard> createState() => _LighterDayCardState();
}

class _LighterDayCardState extends State<_LighterDayCard> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          // Pitfall 5: setState first, then invoke onTap so the press visual
          // clears before the parent setState (schedule change) rebuilds.
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.onBgColor.withAlpha(_hovered ? 153 : 77),
                width: 1.5,
              ),
              color: widget.onBgColor.withAlpha(_hovered ? 38 : 26),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(widget.icon, color: widget.onBgColor, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: widget.onBgColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: widget.onBgColor.withAlpha(179),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
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
