import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/scheduled_chunk.dart';
import '../../data/repositories/hive_completion_log_repository.dart';
import '../../data/repositories/hive_quarterly_snapshot_repository.dart';
import '../../providers/schedule_notifier.dart';
import '../../providers/theme_notifier.dart';
import '../../services/quarterly_aggregation_service.dart';
import '../schedule/widgets/schedule_progress_bar.dart';
import 'widgets/review_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Mood seed palette is the single source of truth in `ThemeNotifier.moodSeeds`
  // (Phase 6 Plan 02). This screen reads it directly via `ThemeNotifier.moodSeeds[mood]`.

  static const Map<int, String> _moodEmojis = {
    1: '\u{1F327}️',
    2: '\u{1F325}️',
    3: '⛅',
    4: '\u{1F324}️',
    5: '☀️',
  };

  static const Map<int, String> _moodDescriptions = {
    1: 'Low energy — keep it light today',
    2: 'Cloudy — a few things you can push through',
    3: 'Okay — steady and focused',
    4: 'Good energy — tackle some harder things',
    5: 'Great energy — go for your stretch goals',
  };

  bool _bannerDismissed = false;
  bool _inReviewWindow = false;

  @override
  void initState() {
    super.initState();
    _checkReviewWindow();
  }

  Future<void> _checkReviewWindow() async {
    final logs = await HiveCompletionLogRepository().getAll();
    final latest = await HiveQuarterlySnapshotRepository().getLatest();
    final service = QuarterlyAggregationService();
    if (mounted) {
      setState(() {
        _inReviewWindow = service.isInReviewWindow(
          latestSnapshot: latest,
          allLogs: logs,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleNotifier = context.watch<ScheduleNotifier>();

    if (!scheduleNotifier.hasScheduleToday) {
      return _buildEmptyState(context);
    }

    final schedule = scheduleNotifier.todaySchedule!;
    final mood = scheduleNotifier.moodIndex ?? 3;
    final moodColor =
        ThemeNotifier.moodSeeds[mood] ?? ThemeNotifier.moodSeeds[3]!;
    final moodEmoji = _moodEmojis[mood] ?? _moodEmojis[3]!;
    final moodDescription = _moodDescriptions[mood] ?? _moodDescriptions[3]!;

    final nextChunk = schedule.chunks
        .where(
          (c) =>
              c.chunkType == ChunkType.work && !c.isCompleted && !c.isSkipped,
        )
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Canopy')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScheduleProgressBar(schedule: schedule, moodColor: moodColor),
          if (_inReviewWindow && !_bannerDismissed)
            ReviewBanner(
              onStart: () => context.push('/review'),
              onDismiss: () => setState(() => _bannerDismissed = true),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(moodEmoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    moodDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Up next',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (nextChunk == null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'All done today!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      nextChunk.rationale.isNotEmpty
                          ? nextChunk.rationale
                          : 'Work block',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${nextChunk.durationMinutes} min',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isPreCheckin = context.watch<ThemeNotifier>().isPreCheckin;
    return Scaffold(
      appBar: AppBar(title: const Text('Canopy')),
      body: Column(
        children: [
          if (_inReviewWindow && !_bannerDismissed)
            ReviewBanner(
              onStart: () => context.push('/review'),
              onDismiss: () => setState(() => _bannerDismissed = true),
            ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No schedule yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start your morning check-in to generate today\'s schedule.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    BreathingPulseCta(
                      enabled: isPreCheckin,
                      onPressed: () => context.push('/schedule/checkin'),
                      child: OutlinedButton(
                        onPressed: () => context.push('/schedule/checkin'),
                        child: const Text('Start your day'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A subtle breathing-pulse decoration around a CTA. Drives a 2400ms easeInOut
/// AnimationController that fades a [BoxShadow] from 8px to 16px blur (UI-SPEC
/// §Breathing Pulse, D-08). Only animates when [enabled] is true AND when
/// MediaQuery/PlatformDispatcher reduced-motion is NOT requested.
///
/// Extracted as a public top-level widget so Plan 06 Task 3 can pump it in
/// isolation without HomeScreen's full provider tree (W-3 resolution).
class BreathingPulseCta extends StatefulWidget {
  const BreathingPulseCta({
    super.key,
    required this.enabled,
    required this.onPressed,
    required this.child,
  });

  /// True when the pulse should animate (pre-check-in state per
  /// `ThemeNotifier.isPreCheckin`). False settles the controller at the
  /// midpoint (no animation).
  final bool enabled;

  /// Forwarded to outer taps where the parent does not already supply the
  /// callback on [child]. Kept for completeness; callers should attach the
  /// callback directly to their [child] widget as well to ensure tap
  /// targets remain valid.
  final VoidCallback onPressed;

  /// The CTA being decorated (typically an [OutlinedButton]).
  final Widget child;

  @override
  State<BreathingPulseCta> createState() => _BreathingPulseCtaState();
}

class _BreathingPulseCtaState extends State<BreathingPulseCta>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  bool get _animationsDisabled => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  @override
  void initState() {
    super.initState();
    // WR-01: register as a binding observer so a mid-session toggle of
    // the OS "reduce motion" / accessibility-disable-animations setting
    // is reflected in the controller's run state without waiting for a
    // parent rebuild with a different `enabled` value.
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _applyAnimationState();
  }

  @override
  void didUpdateWidget(covariant BreathingPulseCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      _applyAnimationState();
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    // Re-evaluate the run state in lockstep with the OS toggle.
    _applyAnimationState();
  }

  /// Single source of truth for the controller's run state.
  ///
  /// UI-SPEC §Breathing Pulse — when disabled OR reduced-motion is on,
  /// render the pulse at midpoint (blur 12px) and do not animate.
  void _applyAnimationState() {
    if (widget.enabled && !_animationsDisabled) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      builder: (context, child) {
        final t = _controller.value;
        final blur = 8.0 + 8.0 * t;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.25),
                blurRadius: blur,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
