import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/daily_schedule.dart';
import '../../data/models/energy_valence.dart';
import '../../data/models/goal.dart';
import '../../data/models/scheduled_chunk.dart';
import '../../data/repositories/hive_completion_log_repository.dart';
import '../../data/repositories/hive_quarterly_snapshot_repository.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/schedule_notifier.dart';
import '../../providers/theme_notifier.dart';
import '../../services/quarterly_aggregation_service.dart';
import '../../utils/rationale_mapper.dart';
import '../../utils/time_format.dart';
import '../../widgets/adaptive_form_modal.dart';
import '../commitments/commitment_form_sheet.dart';
import '../home/widgets/end_of_day_card.dart';
import '../home/widgets/review_banner.dart';
import '../schedule/widgets/chunk_detail_sheet.dart';
import '../schedule/widgets/schedule_progress_bar.dart';
import 'widgets/breathing_pulse_cta.dart';

/// TodayScreen — the merged destination that replaces HomeScreen and
/// ScheduleScreen (UNIFY-01). One scrollable list shows what's happening
/// now AND the rest of the day; there is no separate "now" tab to switch
/// to (D-01).
///
/// This plan (22-03) builds the screen fully and independently testable,
/// but it is NOT yet wired into the router — that switch is plan 22-04, so
/// this file can land without breaking a single existing test.
class TodayScreen extends StatefulWidget {
  /// [now] is an optional clock-injection seam for testing. Defaults to
  /// [DateTime.now] at runtime. Forwarded to [_TodayScreenState._nowFn].
  const TodayScreen({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver {
  // Mood seed palette is the single source of truth in `ThemeNotifier.moodSeeds`.
  // This screen reads it directly via `ThemeNotifier.moodSeeds[mood]`.

  /// Injectable clock function. Defaults to [DateTime.now]; overridden in
  /// tests via [TodayScreen.now] to simulate specific wall-clock times.
  // ignore: unused_field — wired into resolveNowState in Task 2's day list.
  late final DateTime Function() _nowFn = widget.now ?? DateTime.now;

  /// 1-minute periodic timer that triggers setState() so resolveNowState is
  /// re-evaluated as wall-clock time passes. Paused on background, resumed
  /// on foreground (T-17-01 mitigation, carried from HomeScreen: no battery
  /// drain; no setState after dispose via mounted guard + dispose() cancel).
  Timer? _nowTimer;

  // ignore: unused_field — wired into the mood chip in Task 2's header block.
  static const Map<int, String> _moodEmojis = {
    1: '\u{1F327}️',
    2: '\u{1F325}️',
    3: '⛅',
    4: '\u{1F324}️',
    5: '☀️',
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

  /// Starts (or restarts) the 1-minute periodic timer that triggers a
  /// rebuild so the current-moment classification is re-evaluated with
  /// fresh [_nowFn] output. Idempotent: cancels any running timer first.
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

  // ── Goal-lookup layer, ported from schedule_screen.dart (P3) ────────────
  // schedule_screen's family is a strict superset of home_screen's — the
  // row vocabulary needs all five (color/name/priority/valence/emoji).

  /// Returns the single [Goal] for a chunk, or null for commitment-anchored
  /// chunks (goalId == null) or when the goal is not found (IN-01).
  Goal? _resolveGoal(BuildContext context, ScheduledChunk chunk) {
    if (chunk.goalId == null) return null;
    return context
        .read<GoalsNotifier>()
        .goals
        .where((g) => g.id == chunk.goalId)
        .firstOrNull;
  }

  // ignore: unused_element — wired into the row dispatch in Task 2.
  Color? _lookupGoalColor(BuildContext context, ScheduledChunk chunk) {
    final goal = _resolveGoal(context, chunk);
    if (goal?.color != null) return hexToColor(goal!.color!);
    return null;
  }

  // ignore: unused_element — wired into the row dispatch in Task 2.
  String? _lookupGoalName(BuildContext context, ScheduledChunk chunk) =>
      _resolveGoal(context, chunk)?.name;

  // ignore: unused_element — wired into the row dispatch in Task 2.
  double? _lookupGoalPriorityWeight(
    BuildContext context,
    ScheduledChunk chunk,
  ) => _resolveGoal(context, chunk)?.priorityWeight;

  // ignore: unused_element — wired into the row dispatch in Task 2.
  EnergyValence? _lookupGoalValence(
    BuildContext context,
    ScheduledChunk chunk,
  ) => _resolveGoal(context, chunk)?.energyValence;

  // ignore: unused_element — wired into the row dispatch in Task 2.
  String? _lookupGoalEmojiTag(BuildContext context, ScheduledChunk chunk) =>
      _resolveGoal(context, chunk)?.emojiTag;

  /// Maps the raw generator rationale string to a human-readable display
  /// string. Delegates to the shared [toDisplayRationale] helper so the
  /// merged screen, the detail sheet, and the focus screen render
  /// rationales identically.
  // ignore: unused_element — wired into the row dispatch in Task 2.
  static String _toDisplayRationale(String rationale) =>
      toDisplayRationale(rationale);

  /// Returns the ratio of resolved (completed or skipped) work chunks to
  /// total work chunks. Returns 0.0 when there are no work chunks.
  double _resolvedWorkChunkRatio(DailySchedule schedule) {
    final workChunks = schedule.chunks
        .where((c) => c.chunkType == ChunkType.work)
        .toList();
    if (workChunks.isEmpty) return 0.0;
    final resolved = workChunks
        .where((c) => c.isCompleted || c.isSkipped)
        .length;
    return resolved / workChunks.length;
  }

  /// Opens the ChunkDetailSheet for the given work chunk, ported from
  /// schedule_screen.dart.
  // ignore: unused_element — wired into the row dispatch in Task 2.
  void _openDetailSheet(
    BuildContext context,
    ScheduledChunk chunk,
    Color? goalColor,
    String? goalName,
    String displayRationale,
  ) {
    final notifier = context.read<ScheduleNotifier>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChunkDetailSheet(
        chunk: chunk,
        notifier: notifier,
        goalColor: goalColor,
        goalName: goalName,
        displayRationale: displayRationale,
      ),
    );
  }

  /// Opens the commitment form pre-set to a one-off event on today, straight
  /// from the Today screen — where a human actually looks to enter their
  /// schedule. Ported verbatim from schedule_screen.dart; routes through
  /// showAdaptiveFormModal (Phase 18 RESP-01/02/03 inherited contract, P12).
  void _openAddEvent(BuildContext context) {
    final scheduleNotifier = context.read<ScheduleNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    showAdaptiveFormModal(
      context: context,
      builder: (scrollController) => CommitmentFormSheet(
        scrollController: scrollController,
        initialOneOff: true,
        initialDate: today,
        onSaved: (block) async {
          final inserted = await scheduleNotifier.addEventToday(block);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                inserted
                    ? 'Added "${block.name}" to today'
                    : 'Added "${block.name}" to your commitments',
              ),
            ),
          );
        },
      ),
    );
  }

  /// Returns true when the end-of-day card trigger is met (active-schedule
  /// branch only). Delegates to the top-level [shouldShowEodCard] so the
  /// trigger logic is unit-testable without a widget pump.
  bool _shouldShowEodCard(List<ScheduledChunk> chunks) =>
      shouldShowEodCard(chunks);

  // ── AppBar — the union of the two old ones, de-duplicated ───────────────
  //
  // Built once and shared by both the empty state and the active-schedule
  // state so there is exactly ONE refresh IconButton in this file (the two
  // old screens each had one). Deliberately does NOT carry over
  // schedule_screen's `backgroundColor: moodColor` / `foregroundColor:
  // Colors.white` — a raw Colors.white violates the UI-SPEC colour rule,
  // and mood still reads through the seeded theme, the progress bar and the
  // header mood chip (recorded in plan 22-01's source audit).
  AppBar _buildAppBar(BuildContext context, DailySchedule? schedule) {
    return AppBar(
      title: const Text('Canopy'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add an event',
          onPressed: () => _openAddEvent(context),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Re-check-in',
          onPressed: () => context.push('/schedule/checkin'),
        ),
        IconButton(
          icon: const Icon(Icons.center_focus_strong_outlined),
          tooltip: 'Start focus',
          onPressed: () {
            if (schedule == null) return;
            final firstChunk = schedule.chunks
                .where(
                  (c) =>
                      c.chunkType == ChunkType.work &&
                      !c.isCompleted &&
                      !c.isSkipped,
                )
                .firstOrNull;
            if (firstChunk != null) {
              context.push('/focus', extra: firstChunk.id);
            }
          },
        ),
        if (schedule != null && _resolvedWorkChunkRatio(schedule) >= 0.5)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'summary') context.push('/summary');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'summary',
                child: Text('View your day'),
              ),
            ],
          ),
      ],
    );
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

    return Scaffold(
      appBar: _buildAppBar(context, schedule),
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
              // Task 2 replaces this placeholder with the day-as-a-list body
              // (header, mood chip, edge-state line, timeline rows).
            ],
          ),
        ),
      ),
    );
  }

  /// Empty state — the union of BOTH old empty states (P4): the
  /// ReviewBanner gate from Home, the kIsWeb MaterialBanner from Schedule,
  /// Schedule's icon-plus-headline block, the primary CTA wrapped in
  /// BreathingPulseCta from Home, and Schedule's "Add an event" button.
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isPreCheckin = context.watch<ThemeNotifier>().isPreCheckin;
    return Scaffold(
      appBar: _buildAppBar(context, null),
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
              if (kIsWeb)
                MaterialBanner(
                  content: const Text(
                    'Start your morning check-in to build today\'s schedule.',
                  ),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  contentTextStyle: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => context.push('/schedule/checkin'),
                      child: const Text('Start check-in'),
                    ),
                  ],
                ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wb_sunny_outlined,
                          size: 64,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Plan your day in 30 seconds.',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tell us how you\'re feeling and we\'ll build your schedule.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
                        const SizedBox(height: 8),
                        // Let a human put an event on today WITHOUT first
                        // doing a mood check-in — addEventToday creates a
                        // minimal day.
                        TextButton.icon(
                          onPressed: () => _openAddEvent(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add an event'),
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
