import 'package:flutter/gestures.dart';
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

  // _hoveredMoods / _pressedMoods drive luminance-adaptive hover/pressed visuals.
  // (The intermediate "light or full day" decision screen was removed — check-in
  // now goes straight from mood → full-plan acknowledgment. A pace choice may
  // return later, gated to low-mood days.)
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
    final luminance = _selectedMood != null
        ? _backgroundColor.computeLuminance()
        : 0.0;
    final base = luminance > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;
    if (isSelected) {
      return base.withAlpha(isPressed ? 77 : (isHovered ? 64 : 51));
    } else {
      return base.withAlpha(isHovered ? 26 : 0);
    }
  }

  Future<void> _generate() async {
    if (_selectedMood == null || _isGenerating) return;
    setState(() {
      _isGenerating = true;
      _pressedMoods
          .clear(); // WR-01: clear any stale pressed state before transition
    });
    // Pre-capture context reads before the await gap (mirrors _commitAndProceed
    // WR-02 pattern — protects against context-after-await bugs in future refactors).
    final scheduleNotifier = context.read<ScheduleNotifier>();
    final goals = context.read<GoalsNotifier>().goals;
    final blocks = context.read<CommitmentsNotifier>().blocks;
    try {
      await scheduleNotifier.generateToday(
        moodIndex: _selectedMood!,
        goals: goals,
        blocks: blocks,
        lighterDay: false, // full plan — no pace prompt
      );

      // Request iOS notification permission after first successful check-in.
      // No-op on Web and non-iOS platforms; iOS ignores if already granted.
      await NotificationService.requestIOSPermissions();

      if (mounted) {
        setState(() {
          // Straight to the acknowledgment — the decision screen is gone.
          _scheduleGenerated = true;
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
    // A 0-chunk day is legitimate (nothing due today — e.g. a non-daily habit
    // on an off-day, or no discretionary goals yet). Without a dedicated copy
    // path the user saw "… 0 chunks." which reads like a failure. Reassure
    // instead and point them at adding goals.
    if (count == 0) {
      return '$prefix Nothing’s due today — your slate is clear. '
          'Add a goal or habit anytime to fill it.';
    }
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                    onEnter: (_) => setState(() => _hoveredMoods[mood] = true),
                    onExit: (_) => setState(() => _hoveredMoods[mood] = false),
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
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 36),
                        ),
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
      ),
    );
  }

  Widget _buildAcknowledgmentBody(BuildContext context) {
    final schedule = context.watch<ScheduleNotifier>().todaySchedule;
    final mood = _selectedMood ?? 3;
    // CHECKIN-01: use the existing _backgroundColor getter so the bgColor here
    // is always consistent with the one driving _onBgColor (same _selectedMood).
    final bgColor = _backgroundColor;

    final goals = context.read<GoalsNotifier>().goals;
    final ackText = schedule != null
        ? _buildAckText(schedule, mood, goals)
        : '';

    // "Begin" is reachable three ways so it works across input devices:
    //   • swipe up (touch / mouse drag) — original gesture
    //   • tap / click anywhere — desktop & accidental-proof since this screen's
    //     only action is "begin"
    //   • two-finger / wheel scroll up — trackpad users who can't flick a drag
    // On desktop a velocity-thresholded vertical drag almost never fires
    // (mouse/trackpad don't produce a -300 primaryVelocity), so without the
    // tap/scroll fallbacks the screen was a dead end on PC.
    void begin() => Navigator.of(context).pop();

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && event.scrollDelta.dy < -8) begin();
      },
      child: GestureDetector(
        key: const ValueKey('acknowledgment'),
        behavior: HitTestBehavior.opaque,
        onTap: begin,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -300) {
            begin();
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
                    // CHECKIN-01: _onBgColor replaces hardcoded Colors.white to
                    // pass WCAG AA on light backgrounds (moods 4 and 5).
                    style: TextStyle(
                      color: _onBgColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Tap or swipe up to begin',
                    style: TextStyle(
                      // CHECKIN-01: _onBgColor replaces hardcoded Colors.white.
                      color: _onBgColor.withAlpha(179), // ~70% opacity
                      fontSize: 14,
                      letterSpacing: 1.2,
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
}
