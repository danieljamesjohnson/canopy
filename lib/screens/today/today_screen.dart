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
import '../schedule/widgets/chunk_detail_sheet.dart';
import '../schedule/widgets/schedule_progress_bar.dart';
import '../schedule/widgets/swipeable_chunk_card.dart';
import 'now_state.dart';
import 'timeline.dart';
import 'widgets/breathing_pulse_cta.dart';
import 'widgets/end_of_day_card.dart';
import 'widgets/free_time_row.dart';
import 'widgets/live_row_card.dart';
import 'widgets/review_banner.dart';
import 'widgets/timeline_row_tile.dart';

/// TodayScreen — the merged destination that replaces the old separate Home
/// landing screen and Schedule plan-view screen (UNIFY-01). One scrollable
/// list shows what's happening now AND the rest of the day; there is no
/// separate "now" tab to switch to (D-01).
///
/// Built in plan 22-03 fully independently testable, then wired into the
/// router as the shell's merged /today destination in plan 22-04, which also
/// deleted the two screens this one replaces.
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
  /// the original time-anchored Home implementation: no battery drain; no
  /// setState after dispose via mounted guard + dispose() cancel).
  Timer? _nowTimer;

  /// 1-second cadence timer. Exists ONLY while the live activity has under
  /// 60 seconds left (T-23-04) — an addition to [_nowTimer], not a
  /// replacement: D-01 forbids a blanket 1-second ticker on a screen the
  /// user leaves open all day. Bounded at roughly 60 wakeups per activity
  /// boundary rather than running continuously. Cancelled on pause and on
  /// dispose for the same battery/CPU reason [_nowTimer] is.
  Timer? _fastTimer;

  /// True while the app is backgrounded (between a `paused` lifecycle event
  /// and the matching `resumed`). Exists solely so the 1-second [_fastTimer]
  /// cannot be restarted by [_nowTimer]'s now-surviving minute tick while
  /// backgrounded (G-03) — [_nowTimer] itself is deliberately NOT cancelled
  /// on pause any more (see `didChangeAppLifecycleState` below), so without
  /// this guard a background minute tick would call `build()`, which would
  /// call `_syncFastTimer`, which would happily restart the 1/second ticker
  /// in a backgrounded tab. Read at the single `_syncFastTimer` call site in
  /// `build()`.
  bool _isBackgrounded = false;

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

  /// Idempotent — safe to call on every `build()`. A plain field mutation
  /// plus a timer start/cancel; it does NOT itself call `setState`, so
  /// calling it synchronously from `build()` is legal. Starts [_fastTimer]
  /// when [shouldBeRunning] is true and none is running yet; cancels it
  /// (and nulls the field, which is what makes this idempotent) when
  /// [shouldBeRunning] is false and one is running.
  void _syncFastTimer(bool shouldBeRunning) {
    if (shouldBeRunning && _fastTimer == null) {
      _fastTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!shouldBeRunning && _fastTimer != null) {
      _fastTimer!.cancel();
      _fastTimer = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isBackgrounded = false;
      _startNowTimer();
      // Rebuild so build() re-runs and re-decides _syncFastTimer against the
      // fresh clock (P-5a), rather than blindly restarting the fast timer:
      // the app may resume minutes later, past the live chunk entirely, so
      // the <60s condition must be re-evaluated, not assumed. This also
      // fixes a pre-existing staleness bug: resuming used to show stale
      // content until the next minute boundary.
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.paused) {
      // G-03: _nowTimer is deliberately NOT cancelled here any more. It used
      // to be, and `resumed` above was the ONLY code path anywhere in this
      // file that revived either timer — so a `paused` with no matching
      // `resumed` (a missed/delayed browser callback, plausible during the
      // debug build's own ~20s single-bundle first paint, a devtools focus
      // steal, or background-tab throttling) stranded the live row
      // permanently, and only a full page reload could recover it. That is
      // exactly what Dan hit in UAT: opened the app at 9:13 with a chunk at
      // 9:15, and the live row never appeared until a manual refresh.
      //
      // One wakeup a minute is negligible — this file already argued that
      // cost for [_nowTimer] before G-03 existed. The real battery concern
      // is [_fastTimer] (1/second), which IS still cancelled below, AND is
      // now additionally guarded from restarting while backgrounded via
      // [_isBackgrounded] (see the `_syncFastTimer` call site in `build()`).
      _isBackgrounded = true;
      _fastTimer?.cancel();
      _fastTimer = null;
    }
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    _fastTimer?.cancel();
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
            // UAT G-06: the chunk count deliberately does NOT live here — it
            // lives once, in the ScheduleProgressBar above (completed-of-total
            // rather than a bare total), so don't re-add it here.
            child: Text(
              '$moodEmoji $moodLabel',
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
  /// those (D-01). The PreStart and DayComplete strings are LOCKED by D-03
  /// (23-CONTEXT.md decision 3 / 23-UI-SPEC.md "Edge states", from sketch
  /// 001) and must not be reworded without a new design decision. The
  /// Copywriting Contract (23-UI-SPEC.md) forbids deficit language
  /// ("behind", "missed", "you still owe") anywhere in this line, and
  /// forbids any score, total, or percentage in the DayComplete branch — a
  /// finish line, not a scoreboard. The GapBeforeNext banner is unchanged
  /// from Phase 22 (P-1, recorded in the doc comment on its case below).
  /// Styled quiet (bodyMedium/titleMedium on onSurfaceVariant, no Card, no
  /// elevation, no accent fill): a header line, NOT a hero card (D-01) and
  /// NOT sticky (D-03).
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
                'Nothing until '
                '${formatMinutes(firstChunk.displayStartMinutes!)}',
                style: headingStyle,
              ),
              const SizedBox(height: 24),
              Text(
                'The day starts with $title. Until then the time is yours.',
                style: bodyStyle,
              ),
            ],
          ),
        );
      // P-1 (23-03-PLAN.md, DECIDED): this banner does NOT change. The
      // "Up next" heading, the title/subtitle derivation below, and the
      // "Starts at …" / "Starting soon" body all stay exactly as written.
      //
      // (a) LIVE-03 deliberately left this banner unchanged.
      // (b) 23-CONTEXT.md decision 3 supplied verbatim replacement copy for
      //     PreStart and DayComplete but only a *description* for the gap
      //     ("named as free time inline (Phase 22 decision 5)") — that
      //     explains why no new gap copy was authored, not an instruction to
      //     remove this banner.
      // (c) GapFreeRow (the inline list row for free time) renders a
      //     duration, never a name — deleting this banner would remove the
      //     only place the screen says *what* is coming next during a gap,
      //     which would make the gap state read LESS truthfully, not more.
      // (d) As of LIVE-01 (plan 23-01), `next` can be a break chunk. It is
      //     already named correctly below because `_chunkTitle` is
      //     break-aware ("Short break"/"Long break") — do NOT add a
      //     `chunkType` check in this case; the shared helper already
      //     handles it.
      //
      // One consequence of (d): for a break, `_lookupGoalName(context, next)`
      // returns null (breaks carry `goalId == null`), so `subtitle` below is
      // null and the body renders as heading + 'Short break' + 'Starts at
      // …' with no subtitle line. That is correct and intended, not a
      // missing-subtitle bug.
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
              Text("That's the day.", style: headingStyle),
              const SizedBox(height: 24),
              Text('Everything scheduled is behind you.', style: bodyStyle),
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
    int? secondsRemaining,
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
              child: _buildLiveRow(context, chunk, nowState, secondsRemaining),
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

  /// Builds the *reference* title string for a chunk — used everywhere a
  /// chunk is named EXCEPT the live row itself (the "Next · …" line, the
  /// edge-state bodies). A break returns its fixed literal ('Short break' /
  /// 'Long break'); every other chunk falls through to the existing
  /// goal-name → rationale → 'Work block' chain, unchanged. The live row
  /// uses [_liveTitle] instead, which is present-continuous for the current
  /// activity and delegates back here for everything else.
  ///
  /// The two break literals deliberately match the non-live break row in
  /// the schedule chunk card, so the same break reads identically whether
  /// it is above or below the live row.
  String _chunkTitle(BuildContext context, ScheduledChunk chunk) {
    if (chunk.chunkType == ChunkType.shortBreak) return 'Short break';
    if (chunk.chunkType == ChunkType.longBreak) return 'Long break';
    final goalName = _lookupGoalName(context, chunk);
    if (goalName != null && goalName.isNotEmpty) return goalName;
    return chunk.rationale.isNotEmpty ? chunk.rationale : 'Work block';
  }

  /// Present-continuous title for the CURRENT activity only (D-02). These
  /// two strings are LOCKED and must never be used for a future chunk —
  /// present continuous reads wrong for an event that hasn't happened yet
  /// (that's what [_chunkTitle]'s "Short break"/"Long break" are for).
  String _liveTitle(BuildContext context, ScheduledChunk chunk) {
    if (chunk.chunkType == ChunkType.shortBreak) return 'Taking a break';
    if (chunk.chunkType == ChunkType.longBreak) return 'Taking a long break';
    return _chunkTitle(context, chunk);
  }

  /// Kicker for the live row only. Screen-injected because [LiveRowCard] is
  /// a dumb widget by contract (its own doc comment, lines 8-11) — it never
  /// computes this itself. The em dash is U+2014 with a single space either
  /// side, exactly as specified in 23-UI-SPEC.md's "Break as a current
  /// activity" table.
  String _liveKicker(ScheduledChunk chunk) {
    final isBreak =
        chunk.chunkType == ChunkType.shortBreak ||
        chunk.chunkType == ChunkType.longBreak;
    return isBreak ? 'RIGHT NOW — RESTING' : 'RIGHT NOW';
  }

  /// The single source of "how much of the current activity is left," in
  /// whole seconds. Feeds the live row's remaining-time label, its progress
  /// bar, AND the fast-timer decision ([_syncFastTimer]) — because all three
  /// read this one value, they can never disagree (P-5). Returns `null`
  /// unless [nowState] is [Active] and its current chunk has a clock
  /// position (`displayStartMinutes`).
  ///
  /// [nowDt] must be the SAME sample used to produce [nowState] (see the
  /// call site in `build()`) — this function does not read the clock
  /// itself. Reusing the caller's sample instead of re-reading `_nowFn()`
  /// avoids the exact hazard [resolveNowState]'s own doc comment warns
  /// about: two independent clock reads in the same render pass straddling
  /// a second boundary and disagreeing (WR-01).
  int? _liveSecondsRemaining(NowState nowState, DateTime nowDt) {
    if (nowState is! Active) return null;
    final current = nowState.current;
    final start = current.displayStartMinutes;
    if (start == null) return null;
    final end = start + current.durationMinutes;
    final endSeconds = end * 60;
    final nowSeconds = nowDt.hour * 3600 + nowDt.minute * 60 + nowDt.second;
    final rawSecondsLeft = endSeconds - nowSeconds;
    return rawSecondsLeft.clamp(0, current.durationMinutes * 60);
  }

  /// Builds the swelled in-place live row (D-01). The kicker names a
  /// running break as "RIGHT NOW — RESTING" (LIVE-01). [secondsRemaining] is
  /// [_liveSecondsRemaining]'s output, threaded down from build() so the
  /// countdown is computed exactly once (P-5).
  Widget _buildLiveRow(
    BuildContext context,
    ScheduledChunk chunk,
    NowState nowState,
    int? secondsRemaining,
  ) {
    final title = _liveTitle(context, chunk);
    final start = chunk.displayStartMinutes;
    final end = start != null ? start + chunk.durationMinutes : null;

    final ScheduledChunk? nextChunk = switch (nowState) {
      Active(:final next) => next,
      Overdue(:final next) => next,
      _ => null,
    };

    String remainingLabel;
    double progress;
    if (nowState is Active &&
        start != null &&
        end != null &&
        secondsRemaining != null) {
      if (secondsRemaining >= 60) {
        final minLeft = (secondsRemaining + 59) ~/ 60;
        remainingLabel = '$minLeft min left · until ${formatMinutes(end)}';
      } else {
        remainingLabel =
            '${secondsRemaining}s left · until ${formatMinutes(end)}';
      }
      progress = chunk.durationMinutes == 0
          ? 1.0
          : 1 - secondsRemaining / (chunk.durationMinutes * 60);
    } else if (start != null && end != null) {
      // Overdue — the old "now" card's existing plain time-range copy.
      // The Overdue branch deliberately shows the plain window range and no
      // countdown (LIVE-02 does not ask it to); do NOT invent "behind"
      // wording here (Copywriting Contract).
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
      kicker: _liveKicker(chunk),
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
    final now = _nowFn();
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
  AppBar _buildAppBar(
    BuildContext context,
    DailySchedule? schedule,
    NowState? nowState,
  ) {
    // Focus target is derived from the SAME nowState the rest of the screen
    // renders from (P1 / 22-PATTERNS.md section 5) — not a fresh
    // first-unresolved-chunk scan. That old scan could disagree with what
    // the live row visually presents as "now" whenever an earlier chunk was
    // left unresolved (WR-01). DayComplete (and no schedule at all) has no
    // meaningful focus target, so the button is disabled rather than
    // guessing.
    //
    // Before LIVE-01, the now-classifier filtered to work chunks, so this
    // switch could only ever produce a work chunk by construction. LIVE-01
    // broadened that filter, so all four non-null arms below can now
    // resolve to a break. FocusScreen is a 25-minute Pomodoro that calls
    // ScheduleNotifier.markComplete on its target — and per D-02 and
    // 23-UI-SPEC.md, there is nothing to complete about a break. A break
    // therefore produces the same disabled button the DayComplete() arm
    // already produces (T-23-01).
    final ScheduledChunk? resolvedTarget = switch (nowState) {
      Active(:final current) => current,
      Overdue(:final overdue) => overdue,
      GapBeforeNext(:final next) => next,
      PreStart(:final firstChunk) => firstChunk,
      DayComplete() => null,
      null => null,
    };
    final ScheduledChunk? focusTarget =
        resolvedTarget?.chunkType == ChunkType.work ? resolvedTarget : null;
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
          onPressed: focusTarget == null
              ? null
              : () => context.push('/focus', extra: focusTarget.id),
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
    // G-03 belt-and-braces: revive a dead _nowTimer. Legal synchronously
    // from build() for the same reason _syncFastTimer already is (see its
    // doc comment) — a plain field mutation plus a timer start, no setState
    // call of its own. A live Timer.periodic always reports isActive, so
    // this is a no-op on the normal path; it only fires if a lifecycle
    // callback was somehow dropped despite `paused` no longer cancelling
    // this timer, giving a second, independent recovery path on top of
    // that primary fix. CLAUDE.md already flags that browsers throttle
    // timers in background tabs as a known risk class for this app — this
    // is the secondary layer against that class, not the primary one.
    if (_nowTimer == null || !_nowTimer!.isActive) {
      _startNowTimer();
    }

    final scheduleNotifier = context.watch<ScheduleNotifier>();

    if (!scheduleNotifier.hasScheduleToday) {
      // A running fast timer cannot outlive the schedule that justified it.
      _syncFastTimer(false);
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
    //
    // nowDt is sampled here and threaded into BOTH resolveNowState (via a
    // closure that always returns this same value) and _liveSecondsRemaining
    // directly — a single clock read per build, so the two consumers can
    // never straddle a second/minute boundary and disagree (WR-01).
    final nowDt = _nowFn();
    final nowState = resolveNowState(chunks: schedule.chunks, now: () => nowDt);
    final liveSecondsLeft = _liveSecondsRemaining(nowState, nowDt);
    // The only place the fast-timer decision is made (P-5). Guarded by
    // !_isBackgrounded (G-03) so the 1/second ticker can never start while
    // the app is backgrounded, even though _nowTimer's now-surviving minute
    // tick can still reach this line via a background rebuild.
    _syncFastTimer(
      !_isBackgrounded && liveSecondsLeft != null && liveSecondsLeft < 60,
    );
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
      appBar: _buildAppBar(context, schedule, nowState),
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
                        _buildTimelineRow(
                          context,
                          row,
                          nowState,
                          liveSecondsLeft,
                        ),
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
      appBar: _buildAppBar(context, null, null),
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
