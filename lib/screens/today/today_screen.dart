import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/daily_schedule.dart';
import '../../data/models/energy_valence.dart';
import '../../data/models/goal.dart';
import '../../data/models/scheduled_chunk.dart';
import '../../data/repositories/hive_completion_log_repository.dart';
import '../../data/repositories/hive_quarterly_snapshot_repository.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/restoratives_notifier.dart';
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
import '../schedule/widgets/swipeable_chunk_card.dart';
import 'now_state.dart';
import 'timeline.dart';
import 'widgets/breathing_pulse_cta.dart';
import 'widgets/free_time_row.dart';
import 'widgets/live_row_card.dart';
import 'widgets/timeline_row_tile.dart';

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
  late final DateTime Function() _nowFn = widget.now ?? DateTime.now;

  /// 1-minute periodic timer that triggers setState() so the current-moment
  /// classification below is re-evaluated as wall-clock time passes. Paused
  /// on background, resumed on foreground (T-17-01 mitigation, carried from
  /// HomeScreen: no battery drain; no setState after dispose via mounted
  /// guard + dispose() cancel).
  Timer? _nowTimer;

  static const Map<int, String> _moodEmojis = {
    1: '\u{1F327}️',
    2: '\u{1F325}️',
    3: '⛅',
    4: '\u{1F324}️',
    5: '☀️',
  };

  /// Mood-chip labels (1, 3, 5 are the sketch's own strings; 2 and 4
  /// interpolate the same voice).
  static const Map<int, String> _moodLabels = {
    1: 'Low day',
    2: 'Cloudy day',
    3: 'Steady day',
    4: 'Bright day',
    5: 'Sunny day',
  };

  bool _bannerDismissed = false;
  bool _eodCardDismissed = false;
  bool _inReviewWindow = false;
  String? _lastScheduleDateYmd;

  /// Centre-on-open (D-02) plumbing. [_liveRowKey] tags the live row's
  /// TimelineRowTile so [Scrollable.ensureVisible] can find it;
  /// [_dayScrollController] owns the day list's scroll position.
  /// [_didCentreLiveRow] is a ONE-SHOT flag: the screen rebuilds every
  /// minute (the ticker above), and re-running ensureVisible on every tick
  /// would drag the list out from under a reading user (T-22-08). It is
  /// set synchronously in build() — before the post-frame callback is even
  /// scheduled — and is reset only when the schedule's dateYmd changes (a
  /// new day), never on a tick. Do NOT add a sticky bar, floating pill, or
  /// jump button here (D-03) — that is the rejected sketch variant B.
  final GlobalKey _liveRowKey = GlobalKey();
  final ScrollController _dayScrollController = ScrollController();
  bool _didCentreLiveRow = false;

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
    _dayScrollController.dispose();
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
        _didCentreLiveRow = false; // a new day re-centres; a tick never does
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

  Color? _lookupGoalColor(BuildContext context, ScheduledChunk chunk) {
    final goal = _resolveGoal(context, chunk);
    if (goal?.color != null) return hexToColor(goal!.color!);
    return null;
  }

  String? _lookupGoalName(BuildContext context, ScheduledChunk chunk) =>
      _resolveGoal(context, chunk)?.name;

  double? _lookupGoalPriorityWeight(
    BuildContext context,
    ScheduledChunk chunk,
  ) => _resolveGoal(context, chunk)?.priorityWeight;

  EnergyValence? _lookupGoalValence(
    BuildContext context,
    ScheduledChunk chunk,
  ) => _resolveGoal(context, chunk)?.energyValence;

  String? _lookupGoalEmojiTag(BuildContext context, ScheduledChunk chunk) =>
      _resolveGoal(context, chunk)?.emojiTag;

  /// Maps the raw generator rationale string to a human-readable display
  /// string. Delegates to the shared [toDisplayRationale] helper so the
  /// merged screen, the detail sheet, and the focus screen render
  /// rationales identically.
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

  // ── Header + mood chip (UI-SPEC "Structure") ─────────────────────────────
  //
  // A body element, NOT a collapsing app bar — stays put per the UI-SPEC.

  Widget _buildHeader(BuildContext context, DailySchedule schedule, int mood) {
    final theme = Theme.of(context);
    final moodEmoji = _moodEmojis[mood] ?? _moodEmojis[3]!;
    final moodLabel = _moodLabels[mood] ?? _moodLabels[3]!;
    final workChunkCount = schedule.chunks
        .where((c) => c.chunkType == ChunkType.work)
        .length;
    final chunkWord = workChunkCount == 1 ? 'chunk' : 'chunks';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Today',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('EEE d MMM').format(_nowFn()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$moodEmoji $moodLabel · $workChunkCount $chunkWord',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Quiet edge-state line directly beneath the mood chip. Renders a
  /// two-line status for PreStart, GapBeforeNext and DayComplete; renders
  /// nothing for Active/Overdue — the live row in the list speaks for
  /// those (D-01). Copy is carried across WORD FOR WORD from
  /// home_screen.dart's now-removed pre-start / gap / day-complete content
  /// builders (LIVE-03 input) — Phase 23 / LIVE-03 owns any future wording
  /// change here, not this plan. Styled quiet (bodyMedium/titleMedium on
  /// onSurfaceVariant, no Card, no elevation, no accent fill): a header
  /// line, NOT a hero card (D-01) and NOT sticky (D-03).
  Widget _buildEdgeStateLine(BuildContext context, NowState nowState) {
    final theme = Theme.of(context);
    final onVariant = theme.colorScheme.onSurfaceVariant;
    final headingStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: onVariant,
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(color: onVariant);

    switch (nowState) {
      case PreStart(:final firstChunk):
        final title = _chunkTitle(context, firstChunk);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your day starts at '
                '${formatMinutes(firstChunk.displayStartMinutes!)}',
                style: headingStyle,
              ),
              const SizedBox(height: 24),
              Text(
                '$title · ${firstChunk.durationMinutes} min',
                style: bodyStyle,
              ),
            ],
          ),
        );
      case GapBeforeNext(:final next):
        final goalName = _lookupGoalName(context, next);
        final title = _chunkTitle(context, next);
        final subtitle = goalName != null
            ? _toDisplayRationale(next.rationale)
            : null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Up next', style: headingStyle),
              const SizedBox(height: 24),
              Text(title, style: headingStyle, overflow: TextOverflow.ellipsis),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(color: onVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                next.displayStartMinutes != null
                    ? 'Starts at ${formatMinutes(next.displayStartMinutes!)}'
                    : 'Starting soon',
                style: bodyStyle,
              ),
            ],
          ),
        );
      case DayComplete():
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("That's a wrap", style: headingStyle),
              const SizedBox(height: 24),
              Text(
                "You've reached the end of today's schedule.",
                style: bodyStyle,
              ),
            ],
          ),
        );
      case Active():
      case Overdue():
        // The live row in the list speaks for these states (D-01) — no
        // separate header content.
        return const SizedBox.shrink();
    }
  }

  /// Low-energy-day surface for restoratives, ported from schedule_screen.
  /// Rendered only when mood ≤ 2. These never affect the schedule — they
  /// are the deliberate non-goal counterpart to the plan (P11).
  Widget _buildRestorativeSuggestions(BuildContext context) {
    final restoratives = context.watch<RestorativesNotifier>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (restoratives.isEmpty) {
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        color: scheme.surfaceContainerHighest,
        child: ListTile(
          leading: Icon(Icons.spa_outlined, color: scheme.primary),
          title: const Text('Low on energy today?'),
          subtitle: const Text(
            'Add a few things that restore you — they\'ll show up here on '
            'days like this.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/restoratives'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A lighter day — here\'s what restores you',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in restoratives.items)
                  Chip(
                    avatar: (item.emojiTag != null && item.emojiTag!.isNotEmpty)
                        ? Text(
                            item.emojiTag!,
                            style: const TextStyle(fontSize: 16),
                          )
                        : null,
                    label: Text(item.name),
                    backgroundColor: scheme.secondaryContainer,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── The day — row dispatch over buildTimeline's exhaustive TimelineRow ──
  //
  // The now-classifier and buildTimeline are called exactly once, in
  // build() (P1 / 22-PATTERNS.md section 5): this dispatch never reads the
  // clock or re-derives which chunk is "now" — it only renders what it is
  // handed.

  Widget _buildTimelineRow(
    BuildContext context,
    TimelineRow row,
    NowState nowState,
  ) {
    switch (row) {
      case LeadingFreeRow(:final untilMinutes):
        return TimelineRowTile(
          startMinutes: null,
          child: FreeTimeRow.until(untilMinutes: untilMinutes),
        );
      case GapFreeRow(:final startMinutes, :final durationMinutes):
        return TimelineRowTile(
          startMinutes: startMinutes,
          child: FreeTimeRow.gap(durationMinutes: durationMinutes),
        );
      case ChunkRow(:final chunk, :final isLive):
        if (isLive) {
          // Keyed so build()'s centre-on-open can find this row's context
          // via Scrollable.ensureVisible without a second "now" scan.
          return KeyedSubtree(
            key: _liveRowKey,
            child: TimelineRowTile(
              startMinutes: chunk.displayStartMinutes,
              child: _buildLiveRow(context, chunk, nowState),
            ),
          );
        }
        final goalColor = _lookupGoalColor(context, chunk);
        final goalName = _lookupGoalName(context, chunk);
        final displayRationale = _toDisplayRationale(chunk.rationale);
        return TimelineRowTile(
          startMinutes: chunk.displayStartMinutes,
          child: SwipeableChunkCard(
            chunk: chunk,
            goalColor: goalColor,
            goalName: goalName,
            displayRationale: displayRationale,
            goalPriorityWeight: _lookupGoalPriorityWeight(context, chunk),
            goalEmojiTag: _lookupGoalEmojiTag(context, chunk),
            goalValence: _lookupGoalValence(context, chunk),
            showStartTime: false,
            onTap: (chunk.isCompleted || chunk.isSkipped)
                ? null
                : () => _openDetailSheet(
                    context,
                    chunk,
                    goalColor,
                    goalName,
                    displayRationale,
                  ),
          ),
        );
    }
  }

  /// Builds a single title string for a chunk: the goal name, or (for
  /// commitment/unattached chunks) the rationale, or a plain fallback.
  String _chunkTitle(BuildContext context, ScheduledChunk chunk) {
    final goalName = _lookupGoalName(context, chunk);
    if (goalName != null && goalName.isNotEmpty) return goalName;
    return chunk.rationale.isNotEmpty ? chunk.rationale : 'Work block';
  }

  /// Builds the swelled in-place live row (D-01). kicker is always
  /// "RIGHT NOW" here — the "RESTING" variant and any faster tick
  /// granularity are Phase 23 / LIVE-01 / LIVE-02's decisions, not this
  /// plan's (scope boundary).
  Widget _buildLiveRow(
    BuildContext context,
    ScheduledChunk chunk,
    NowState nowState,
  ) {
    final title = _chunkTitle(context, chunk);
    final start = chunk.displayStartMinutes;
    final end = start != null ? start + chunk.durationMinutes : null;

    final ScheduledChunk? nextChunk = switch (nowState) {
      Active(:final next) => next,
      Overdue(:final next) => next,
      _ => null,
    };

    String remainingLabel;
    double progress;
    if (nowState is Active && start != null && end != null) {
      final nowDt = _nowFn();
      final nowMinutes = nowDt.hour * 60 + nowDt.minute;
      final rawMinLeft = end - nowMinutes;
      final minLeft = rawMinLeft.clamp(0, chunk.durationMinutes).toInt();
      remainingLabel = '$minLeft min left · until ${formatMinutes(end)}';
      progress = chunk.durationMinutes == 0
          ? 1.0
          : (nowMinutes - start) / chunk.durationMinutes;
    } else if (start != null && end != null) {
      // Overdue — the ActiveChunkCard's existing plain time-range copy.
      // Do NOT invent "behind" wording here (Copywriting Contract);
      // the remaining-time granularity is Phase 23 / LIVE-02's decision.
      remainingLabel = formatTimeRange(start, end);
      progress = 1.0;
    } else {
      remainingLabel = '${chunk.durationMinutes} min';
      progress = 0.0;
    }

    String? nextLine;
    if (nextChunk != null && nextChunk.displayStartMinutes != null) {
      final nextTitle = _chunkTitle(context, nextChunk);
      nextLine =
          'Next · $nextTitle at '
          '${formatMinutes(nextChunk.displayStartMinutes!)}';
    }

    return LiveRowCard(
      chunkId: chunk.id,
      kicker: 'RIGHT NOW',
      title: title,
      remainingLabel: remainingLabel,
      progress: progress,
      nextLine: nextLine,
      showActions: chunk.chunkType == ChunkType.work,
    );
  }

  /// Opens the ChunkDetailSheet for the given work chunk, ported from
  /// schedule_screen.dart.
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

    // The only two "what is happening now" calls on this screen (P1 /
    // 22-PATTERNS.md section 5): this samples the clock exactly once,
    // buildTimeline turns that classification into a row list, and nothing
    // below this point re-derives which chunk is current.
    final nowState = resolveNowState(chunks: schedule.chunks, now: _nowFn);
    final timelineRows = buildTimeline(
      chunks: schedule.chunks,
      nowState: nowState,
    );

    // Centre-on-open (D-02): schedule the scroll exactly once. The flag is
    // set synchronously here — before the post-frame callback even runs —
    // so a rebuild triggered by the same tick that flips this bit can never
    // schedule a second one (T-22-08). See the field doc comment for why
    // this is a one-shot, not a listener.
    final hasLiveRow = timelineRows.any((row) => row is ChunkRow && row.isLive);
    if (!_didCentreLiveRow && hasLiveRow) {
      _didCentreLiveRow = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final liveRowContext = _liveRowKey.currentContext;
        // T-22-10: guarded on a non-null, still-mounted context — the day
        // uses SingleChildScrollView (eager layout) so the target is
        // always laid out by the time this callback runs.
        if (liveRowContext == null) return;
        Scrollable.ensureVisible(
          liveRowContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }

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
              _buildHeader(context, schedule, mood),
              _buildEdgeStateLine(context, nowState),
              // SingleChildScrollView + Column, deliberately NOT a ListView:
              // the centre-on-open above needs the live row already laid
              // out, and a lazy ListView may not have built a row far down
              // the day. A day is bounded at a few dozen rows, so eager
              // layout is the cheap correct answer and avoids a
              // scroll-positioning package.
              Expanded(
                child: SingleChildScrollView(
                  controller: _dayScrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mood <= 2) _buildRestorativeSuggestions(context),
                      for (final row in timelineRows)
                        _buildTimelineRow(context, row, nowState),
                    ],
                  ),
                ),
              ),
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
