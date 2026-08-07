import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/scheduled_chunk.dart';
import '../../data/repositories/hive_completion_log_repository.dart';
import '../../data/repositories/hive_quarterly_snapshot_repository.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/schedule_notifier.dart';
import '../../providers/theme_notifier.dart';
import '../../services/quarterly_aggregation_service.dart';
import '../../utils/rationale_mapper.dart';
import '../../utils/time_format.dart';
import '../schedule/widgets/schedule_progress_bar.dart';
import '../today/now_state.dart';
import 'widgets/active_chunk_card.dart';
import 'widgets/end_of_day_card.dart';
import 'widgets/review_banner.dart';

// ─── HomeScreen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  /// [now] is an optional clock-injection seam for testing. Defaults to
  /// [DateTime.now] at runtime. Forwarded to [_HomeScreenState._nowFn].
  const HomeScreen({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Mood seed palette is the single source of truth in `ThemeNotifier.moodSeeds`
  // (Phase 6 Plan 02). This screen reads it directly via `ThemeNotifier.moodSeeds[mood]`.

  /// Injectable clock function. Defaults to [DateTime.now]; overridden in
  /// tests via [HomeScreen.now] to simulate specific wall-clock times.
  late final DateTime Function() _nowFn = widget.now ?? DateTime.now;

  /// 1-minute periodic timer that triggers setState() so resolveNowState is
  /// re-evaluated as wall-clock time passes. Paused on background, resumed
  /// on foreground (T-17-01 mitigation: no battery drain; no setState after
  /// dispose via mounted guard + dispose() cancel).
  Timer? _nowTimer;

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
  bool _eodCardDismissed = false;
  bool _inReviewWindow = false;
  String? _lastScheduleDateYmd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startNowTimer();
    _checkReviewWindow();
  }

  /// Starts (or restarts) the 1-minute periodic timer that triggers a rebuild
  /// so [resolveNowState] is re-evaluated with fresh [_nowFn] output.
  /// Idempotent: cancels any running timer before starting a new one.
  void _startNowTimer() {
    _nowTimer?.cancel();
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startNowTimer();
    } else if (state == AppLifecycleState.paused) {
      _nowTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<ScheduleNotifier>();
    final newDateYmd = notifier.todaySchedule?.dateYmd;
    if (newDateYmd != _lastScheduleDateYmd) {
      setState(() {
        _lastScheduleDateYmd = newDateYmd;
        _eodCardDismissed = false; // new schedule → show card again
      });
    }
  }

  Future<void> _checkReviewWindow() async {
    try {
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
    } catch (_) {
      // Hive boxes not yet open (test environment or cold start before init).
      // _inReviewWindow stays false — the banner simply won't show.
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

    // Classify the current moment against the day's chunk windows.
    final nowState = resolveNowState(chunks: schedule.chunks, now: _nowFn);

    // Extract the next chunk from states that carry one; null in pre-start,
    // gap-before-next, and day-complete so the Next section is hidden in
    // those states (GapBeforeNext shows its own "up next" inline content).
    final ScheduledChunk? nextChunk = switch (nowState) {
      Active(:final next) => next,
      Overdue(:final next) => next,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canopy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-check-in',
            onPressed: () => context.push('/schedule/checkin'),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScheduleProgressBar(schedule: schedule, moodColor: moodColor),
              if (_inReviewWindow && !_bannerDismissed)
                ReviewBanner(
                  onStart: () => context.push('/review'),
                  onDismiss: () => setState(() => _bannerDismissed = true),
                ),
              if (!_eodCardDismissed && _shouldShowEodCard(schedule.chunks))
                EndOfDayCard(
                  chunks: schedule.chunks,
                  onDismiss: () => setState(() => _eodCardDismissed = true),
                  onGoToSummary: () => context.push('/summary'),
                ),
              // ── NOW section ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Now',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              _buildNowContent(context, nowState),
              // ── NEXT section ─────────────────────────────────────────────────
              if (nextChunk != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Next',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    // Compact next-chunk row: goal name + clock-time range + duration.
                    final goalName = _lookupGoalName(context, nextChunk);
                    final title =
                        goalName ??
                        (nextChunk.rationale.isNotEmpty
                            ? nextChunk.rationale
                            : 'Work block');
                    final subtitle = goalName != null
                        ? toDisplayRationale(nextChunk.rationale)
                        : null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (subtitle != null &&
                                    subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            nextChunk.displayStartMinutes != null
                                ? formatTimeRange(
                                    nextChunk.displayStartMinutes!,
                                    nextChunk.displayStartMinutes! +
                                        nextChunk.durationMinutes,
                                  )
                                : '${nextChunk.durationMinutes} min',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              // ── Mood row ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
              // ── See full schedule link ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextButton(
                  onPressed: () => context.go('/schedule'),
                  child: const Text('See full schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns true when the end-of-day card trigger is met (active-schedule
  /// branch only). Delegates to the top-level [shouldShowEodCard] so the
  /// trigger logic is unit-testable without a widget pump.
  bool _shouldShowEodCard(List<ScheduledChunk> chunks) =>
      shouldShowEodCard(chunks);

  /// Resolves the goal name for a chunk by looking up its goalId in
  /// GoalsNotifier. Returns null for commitment-anchored chunks (no goalId)
  /// so they fall back to the block name carried in chunk.rationale. Mirrors
  /// ScheduleScreen._lookupGoalName so Home and Schedule read identically.
  String? _lookupGoalName(BuildContext context, ScheduledChunk chunk) {
    if (chunk.goalId == null) return null;
    final goals = context.read<GoalsNotifier>().goals;
    final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
    return goal?.name;
  }

  /// Builds the Now zone content based on the current [NowState].
  /// Exhaustive switch drives the five states: pre-start, active, overdue,
  /// gap-before-next, day-complete. Called from build() to keep the children
  /// list clean.
  Widget _buildNowContent(BuildContext context, NowState nowState) {
    switch (nowState) {
      case PreStart(:final firstChunk):
        return _buildPreStartContent(context, firstChunk);
      case Active(:final current):
        return ActiveChunkCard(chunk: current);
      case Overdue(:final overdue):
        return ActiveChunkCard(chunk: overdue);
      case GapBeforeNext(:final next):
        return _buildGapBeforeNextContent(context, next);
      case DayComplete():
        return _buildDayCompleteContent(context);
    }
  }

  /// Pre-start inline Now zone — shown when the current time is before the
  /// first work chunk's window. Inline Padding/Column/Text per UI-SPEC §State 2.
  Widget _buildPreStartContent(
    BuildContext context,
    ScheduledChunk firstChunk,
  ) {
    final theme = Theme.of(context);
    final goalName = _lookupGoalName(context, firstChunk);
    final bodyText = (goalName != null && goalName.isNotEmpty)
        ? '$goalName · ${firstChunk.durationMinutes} min'
        : (firstChunk.rationale.isNotEmpty
              ? '${firstChunk.rationale} · ${firstChunk.durationMinutes} min'
              : 'Work block · ${firstChunk.durationMinutes} min');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your day starts at ${formatMinutes(firstChunk.displayStartMinutes!)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          // lg (24px) heading-to-body gap per UI-SPEC spacing scale.
          const SizedBox(height: 24),
          Text(
            bodyText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Gap-before-next inline Now zone — shown when the current chunk is
  /// resolved and the next chunk's window has not yet opened. The day is NOT
  /// complete: [next] is the upcoming unresolved chunk.
  ///
  /// Calm, no accent — mirrors pre-start visual treatment per UI-SPEC tone.
  Widget _buildGapBeforeNextContent(BuildContext context, ScheduledChunk next) {
    final theme = Theme.of(context);
    // Name the upcoming chunk's goal, mirroring the Next-section fallback.
    final goalName = _lookupGoalName(context, next);
    final title =
        goalName ?? (next.rationale.isNotEmpty ? next.rationale : 'Work block');
    final subtitle = goalName != null
        ? toDisplayRationale(next.rationale)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Up next',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          // lg (24px) heading-to-body gap per UI-SPEC spacing scale.
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            next.displayStartMinutes != null
                ? 'Starts at ${formatMinutes(next.displayStartMinutes!)}'
                : 'Starting soon',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Day-complete inline Now zone — shown when all chunk windows have passed
  /// or all chunks are resolved (UI-SPEC §State 4).
  /// Calm, no emoji, no accent — "That's a wrap" is understated and honest.
  Widget _buildDayCompleteContent(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "That's a wrap",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          // lg (24px) heading-to-body gap per UI-SPEC spacing scale.
          const SizedBox(height: 24),
          Text(
            "You've reached the end of today's schedule.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
        ),
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
    this.onPressed,
    required this.child,
  });

  /// True when the pulse should animate (pre-check-in state per
  /// `ThemeNotifier.isPreCheckin`). False settles the controller at the
  /// midpoint (no animation).
  final bool enabled;

  /// Optional outer-tap callback. When non-null, a [GestureDetector] wraps
  /// the animated container so that tapping anywhere in the glow ring also
  /// fires the callback. Callers should still attach the callback to [child]
  /// directly to keep the inner tap target valid on all platforms.
  final VoidCallback? onPressed;

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
        return GestureDetector(
          onTap: widget.onPressed,
          child: Container(
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
          ),
        );
      },
      child: widget.child,
    );
  }
}
