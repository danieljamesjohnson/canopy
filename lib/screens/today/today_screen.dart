import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/daily_schedule.dart';
import '../../data/models/energy_valence.dart';
import '../../data/models/goal.dart';
import '../../data/models/scheduled_chunk.dart';
import '../../data/repositories/hive_completion_log_repository.dart';
import '../../data/repositories/hive_quarterly_snapshot_repository.dart';
import '../../dev/dev_clock.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/restoratives_notifier.dart';
import '../../providers/schedule_notifier.dart';
import '../../providers/theme_notifier.dart';
import '../../services/quarterly_aggregation_service.dart';
import '../../utils/rationale_mapper.dart';
import '../../utils/time_format.dart';
import '../../widgets/adaptive_form_modal.dart';
import '../commitments/commitment_form_sheet.dart';
import '../schedule/widgets/chunk_card.dart';
import '../schedule/widgets/chunk_detail_sheet.dart';
import '../schedule/widgets/schedule_progress_bar.dart';
import '../schedule/widgets/swipeable_chunk_card.dart';
import 'now_state.dart';
import 'timeline.dart';
import 'timeline_geometry.dart';
import 'widgets/breathing_pulse_cta.dart';
import 'widgets/end_of_day_card.dart';
import 'widgets/free_time_row.dart';
import 'widgets/hour_axis.dart';
import 'widgets/live_row_card.dart';
import 'widgets/now_line.dart';
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

  /// Injectable clock function. Defaults to [DevClock.now] (Phase 25,
  /// DEV-01) so this screen picks up a debug-only simulated time; that is
  /// exactly [DateTime.now] in release builds (DEV-03). Overridden in tests
  /// via [TodayScreen.now] to simulate specific wall-clock times — the
  /// widget's own `now` constructor parameter is unchanged, so existing
  /// tests keep passing.
  late final DateTime Function() _nowFn = widget.now ?? DevClock.now;

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

  /// Centre-on-open (CAL-03) plumbing — ONE flag, ONE arithmetic
  /// `animateTo` path (26-05-PLAN.md). This flag is set synchronously in
  /// build() — before the post-frame callback is even scheduled — so a
  /// rebuild triggered by the same tick that flips it can never schedule a
  /// second callback (T-22-08). It is reset only when the schedule's
  /// dateYmd changes (a new day) or on a `DevClock.offset` jump (Phase 25,
  /// see build()), never on a tick.
  ///
  /// Replaces Phase 24's two flags (one for the live row, one as its
  /// PreStart/GapBeforeNext/DayComplete fallback) and the pair of
  /// `GlobalKey`s and widget-lookup scroll calls each of those flags used.
  /// There is no longer a "does a live row exist" branch to choose
  /// between: the now-line overlay always exists at a computable offset in
  /// every `NowState` (PreStart, Active, Overdue, GapBeforeNext,
  /// DayComplete), so opening the day centres on "now" unconditionally —
  /// this is what closes the DayComplete gap Dan reported in the Phase 24
  /// UAT, by construction rather than by a fallback branch. A
  /// PreStart -> Active transition deliberately does NOT re-centre (PD-19,
  /// 26-05-PLAN.md) — only a new day or a debug time jump re-arms this
  /// flag.
  ///
  /// Do NOT add a sticky bar, floating pill, or jump button here (D-03) —
  /// that is the rejected sketch variant B.
  //
  // NEVER pass a computed offset into the controller's constructor below —
  // an out-of-bounds value there is a documented hard crash on iOS
  // (flutter/flutter#96924). Scroll only via `animateTo` inside a
  // post-frame callback (see build()).
  final ScrollController _dayScrollController = ScrollController();
  bool _didCentreOnOpen = false;

  /// Tags the day's `SizedBox`-wrapped `Stack` (the fixed-height Layer-1
  /// timeline surface, CAL-01) so the scroll-on-open arithmetic below can
  /// ask the viewport where the Stack's top sits inside the scroll content
  /// — the restoratives card can precede it, so that offset is not always
  /// zero.
  final GlobalKey _timelineStackKey = GlobalKey();

  /// Last-seen [DevClock.offset], so a debug time jump can re-arm the
  /// one-shot above (see build()). Always [Duration.zero] in release
  /// builds, where it therefore never triggers anything.
  Duration _lastDevClockOffset = DevClock.offset;

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
        _didCentreOnOpen = false; // a new day re-centres; a tick never does
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

  /// Phase 25 (Time Travel, DEV-02) — a compact banner making it impossible
  /// to leave a debug clock override on and mistake it for real time.
  /// Visible only when [kDebugMode] AND [DevClock.isActive]; renders nothing
  /// in every other case (including every release build, DEV-03). Takes
  /// [nowDt] — build()'s single already-sampled clock read — rather than
  /// calling `DevClock.now()` itself, so this indicator can never be the
  /// second, independent clock read the D-01 discipline forbids in the
  /// render path (see the doc comment on `build()`'s `nowDt` sample).
  Widget _buildDevClockBanner(BuildContext context, DateTime nowDt) {
    if (!kDebugMode || !DevClock.isActive) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 16,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Simulated time — ${DateFormat('EEE d MMM, h:mm a').format(nowDt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header + mood chip (UI-SPEC "Structure") ─────────────────────────────
  //
  // A body element, NOT a collapsing app bar — stays put per the UI-SPEC.

  /// [nowDt] is build()'s single clock sample (D-01). It is threaded in
  /// rather than re-read here: this header previously called `_nowFn()`
  /// directly for its date text, which made it a second, independent clock
  /// read in the render path (24-REVIEW.md WR-02) — the same defect class as
  /// the end-of-day card's (fixed in a8966b4). Low blast radius since the
  /// text is a date rather than a time, but a build straddling midnight
  /// could render a header date that disagrees with the timeline beneath it.
  Widget _buildHeader(
    BuildContext context,
    DailySchedule schedule,
    int mood,
    DateTime nowDt,
  ) {
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
                DateFormat('EEE d MMM').format(nowDt),
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
  // handed. Per CAL-01 (26-03-PLAN.md) every row is now placed at an
  // absolute pixel offset via [TimelineGeometry] rather than laid out in a
  // Column, so this dispatch returns a [Positioned] per row instead of a
  // plain child widget.

  /// Builds the [SwipeableChunkCard] for [chunk] at the given [density].
  /// Shared by the Layer-1 positioned arm below and the trailing untimed
  /// block (PD-11) so both keep supplying identical goal-lookup data —
  /// [density] is the only thing that varies between call sites.
  Widget _buildChunkCard(
    BuildContext context,
    ScheduledChunk chunk,
    ChunkCardDensity density, {
    double? visualHeight,
  }) {
    final goalColor = _lookupGoalColor(context, chunk);
    final goalName = _lookupGoalName(context, chunk);
    final displayRationale = _toDisplayRationale(chunk.rationale);
    return SwipeableChunkCard(
      chunk: chunk,
      goalColor: goalColor,
      goalName: goalName,
      displayRationale: displayRationale,
      goalPriorityWeight: _lookupGoalPriorityWeight(context, chunk),
      goalEmojiTag: _lookupGoalEmojiTag(context, chunk),
      goalValence: _lookupGoalValence(context, chunk),
      // The per-row gutter that used to carry a chunk's start time is gone
      // (the hour axis owns round-hour reference points instead), so the
      // card is now the only place a chunk's exact start time is legible —
      // flipped from Phase 22's `false` (26-UI-SPEC.md "The time gutter
      // becomes an hour axis").
      showStartTime: true,
      density: density,
      // Phase 31 (D-31-02): non-null only for a slop-bearing break's grown
      // envelope (the ChunkRow arm below). Every other call site passes
      // null, keeping this an identity transform there.
      visualHeight: visualHeight,
      // The isWork gate inside SwipeableChunkCard is what actually keeps a
      // break untappable (PD-31-02's promote decision deleted the old
      // break-only early return) — this closure is unchanged and simply
      // forwarded for every chunk type, exactly as before this phase.
      onTap: (chunk.isCompleted || chunk.isSkipped)
          ? null
          : () => _openDetailSheet(
              context,
              chunk,
              goalColor,
              goalName,
              displayRationale,
            ),
    );
  }

  /// True only for a short/long break whose slot has a clock position and
  /// whose rendered height is under [kMinBreakDragTarget] (Phase 31,
  /// D-31-02). Governs two things together: whether the break's
  /// `_buildPositionedRow` arm grows its hit-test envelope (below), and
  /// whether the row is deferred to the Layer 1b Stack pass (Step 3) instead
  /// of the normal Layer 1a loop — both must agree, or a slop-bearing break
  /// would render in the wrong pass and lose the z-order fix `31-RESEARCH.md`
  /// Pitfall 1 exists to provide.
  bool _needsSlop(ScheduledChunk chunk, TimelineGeometry geometry) {
    final isBreak =
        chunk.chunkType == ChunkType.shortBreak ||
        chunk.chunkType == ChunkType.longBreak;
    if (!isBreak) return false;
    final start = chunk.displayStartMinutes;
    if (start == null) return false;
    return geometry.heightFor(start, chunk.durationMinutes) <
        kMinBreakDragTarget;
  }

  /// Returns a [Positioned] for [row], placed by [geometry] against the
  /// day's rendered range. This dispatch never reads the clock or
  /// re-derives which chunk is "now" — [nowState]/[secondsRemaining] are
  /// threaded straight through to the live row.
  Widget _buildPositionedRow(
    BuildContext context,
    TimelineRow row,
    TimelineGeometry geometry,
    NowState nowState,
    int? secondsRemaining,
  ) {
    switch (row) {
      case LeadingFreeRow(:final untilMinutes, :final windowPassed):
        return Positioned(
          // geometry.yFor(geometry.rangeStart), not a hard-coded 0 — that
          // literal only ever equaled yFor(rangeStart) because yFor used to
          // return exactly 0 there (26-10-PLAN.md's edge-padding fix,
          // timeline_geometry.dart, changed that). A hard-coded 0 would
          // silently misalign this row from every other consumer of
          // geometry now that yFor(rangeStart) carries a fixed offset.
          top: geometry.yFor(geometry.rangeStart),
          left: 0,
          right: 0,
          height: geometry.heightFor(
            geometry.rangeStart,
            untilMinutes - geometry.rangeStart,
          ),
          child: TimelineRowTile(
            // NOW-02: "Free until <time>" is only truthful while that time is
            // still ahead. Once it has passed, the same region takes the
            // duration copy, which reads correctly either way — see
            // LeadingFreeRow.windowPassed.
            child: windowPassed
                ? FreeTimeRow.gap(
                    durationMinutes: untilMinutes - geometry.rangeStart,
                  )
                : FreeTimeRow.until(untilMinutes: untilMinutes),
          ),
        );
      case GapFreeRow(:final startMinutes, :final durationMinutes):
        return Positioned(
          top: geometry.yFor(startMinutes),
          left: 0,
          right: 0,
          height: geometry.heightFor(startMinutes, durationMinutes),
          child: TimelineRowTile(
            child: FreeTimeRow.gap(durationMinutes: durationMinutes),
          ),
        );
      case ChunkRow(:final chunk, :final isLive):
        final start = chunk.displayStartMinutes;
        if (start == null) {
          // No clock position — rendered in the trailing untimed block
          // below the Stack instead (PD-11); this arm contributes nothing
          // to Layer 1.
          return const Positioned(
            top: 0,
            left: 0,
            width: 0,
            height: 0,
            child: SizedBox.shrink(),
          );
        }
        // Every row's slot height is geometry.heightFor(...) and nothing
        // else (D-02/GRID-01) — no floor, no ceiling, no "cap a huge gap"
        // shortcut, and (Phase 27) no exception for the live row either: it
        // is duration-exact like every other row now.
        final slot = geometry.heightFor(start, chunk.durationMinutes);
        if (isLive) {
          // PD-10: ClipRect + OverflowBox is the same safety net the
          // non-live arm below uses (not a min/max clamp) — the card lays
          // out at its natural height (no RenderFlex overflow even for a
          // pathological short live chunk), ClipRect guarantees nothing
          // paints outside the slot. LiveRowCard picks its own density tier
          // from the slot height it is handed, exactly as ChunkCardDensity
          // is picked below.
          //
          // Deliberately NOT wrapped in TimelineRowTile — it spans the full
          // content width instead of reserving the fixed gutter column every
          // other row shares, and restates its own horizontal insets
          // internally (kCardLeftInset/kTimelineRowInset). Adding
          // TimelineRowTile here would double that inset — a documented,
          // previously-shipped regression class (timeline_row_tile.dart doc
          // comment). This is the one difference from the non-live arm below
          // that a future reader may otherwise "fix" — don't.
          return Positioned(
            top: geometry.yFor(start),
            left: 0,
            right: 0,
            height: slot,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: double.infinity,
                child: _buildLiveRow(
                  context,
                  chunk,
                  nowState,
                  secondsRemaining,
                  slot,
                ),
              ),
            ),
          );
        }
        final isBreak =
            chunk.chunkType == ChunkType.shortBreak ||
            chunk.chunkType == ChunkType.longBreak;
        // Phase 29 (SEEBREAK-01): break rows get a third, lower density band.
        // Under Phase 28's lattice this is slot-height-driven, not
        // chunk-type-driven: a 5-minute break (20dp) always lands in
        // `subCompact`, a 30-minute long break (120dp) always lands in
        // `full`, and the `compact` band is unreachable at today's two
        // generated durations — kept because a future cadence change could
        // reach it. The work branch below is UNCHANGED (byte-identical) —
        // this phase changes breaks only (29-UI-SPEC.md § Scope boundary).
        final density = isBreak
            ? (slot >= kFullBreakMinHeight
                  ? ChunkCardDensity.full
                  : slot >= kSubCompactBreakMinHeight
                  ? ChunkCardDensity.compact
                  : ChunkCardDensity.subCompact)
            : (slot >= kFullTierMinHeight
                  ? ChunkCardDensity.full
                  : ChunkCardDensity.compact);
        // Phase 31 (D-31-02/SKIPBREAK-02): a break under kMinBreakDragTarget
        // grows its OWN Positioned/Dismissible hit-test box by kBreakHitSlop
        // on both top and bottom, while everything that paints stays
        // confined to exactly `slot` inside it (SwipeableChunkCard's
        // `visualHeight`, PD-31-02). The grown box is the direct child of
        // this Positioned — NOT wrapped in the row's usual outer ClipRect —
        // because `RenderBox.hitTest` bounds every render box to its own
        // `size` regardless of any clip (31-RESEARCH.md, verified against
        // the Flutter SDK): a ClipRect wrapped around the whole grown
        // Positioned would reject the slop-band touch before the
        // Dismissible inside it ever saw it. ClipRect instead moved down
        // inside SwipeableChunkCard, confined to `slot` only. Slop is
        // symmetric with no per-neighbour clamp (PD-31-01, kBreakHitSlop's
        // own doc comment) — an asymmetric grown box would shift the
        // Align(center)-confined painted content off geometry.yFor(start).
        // Every break takes this arm (PD-31-04); only a sub-48dp one gets
        // non-zero slop, so a full/compact-tier break's `slop` is 0.0 and
        // this Positioned is byte-for-byte the pre-existing one.
        //
        // A slop-bearing break's grown box is emitted here but is NEVER
        // reached by THIS loop at render time — Layer 1a below excludes any
        // row `_needsSlop` calls true for, and Layer 1b (Step 3, the
        // load-bearing fix) re-invokes this same function for exactly those
        // rows, later in the Stack's children list. That later position is
        // what wins the bottom slop band against the following work
        // chunk's own, unenlarged Positioned — see the Layer 1b comment at
        // this file's Stack-children site for the full z-order argument
        // (31-RESEARCH.md Pitfall 1). This function does not know or care
        // which pass invoked it; it always returns the same grown box for a
        // slop-bearing break, so the two loops staying mutually exclusive on
        // `_needsSlop` is what actually enforces the ordering.
        if (isBreak) {
          final slop = slot < kMinBreakDragTarget ? kBreakHitSlop : 0.0;
          return Positioned(
            top: geometry.yFor(start) - slop,
            left: 0,
            right: 0,
            height: slot + 2 * slop,
            child: TimelineRowTile(
              child: _buildChunkCard(
                context,
                chunk,
                density,
                visualHeight: slot,
              ),
            ),
          );
        }
        // PD-10: ClipRect + OverflowBox is a safety net, not a min/max
        // clamp — the slot is always exactly `durationMinutes *
        // kPixelsPerMinute`. OverflowBox lets the card lay out at its
        // natural height (no RenderFlex overflow even for a pathological
        // 3-minute chunk); ClipRect guarantees nothing paints outside the
        // slot.
        return Positioned(
          top: geometry.yFor(start),
          left: 0,
          right: 0,
          height: slot,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: TimelineRowTile(
                child: _buildChunkCard(context, chunk, density),
              ),
            ),
          ),
        );
    }
  }

  /// Builds the *reference* title string for a chunk — used everywhere a
  /// chunk is named EXCEPT the live row itself (see [_liveTitle]) and the
  /// edge-state bodies' break-awareness call sites. A break returns its
  /// fixed literal ('Short break' / 'Long break'); every other chunk falls
  /// through to the existing goal-name → rationale → 'Work block' chain,
  /// unchanged. The live row uses [_liveTitle] instead, which is
  /// present-continuous for the current activity and delegates back here
  /// for everything else.
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
    final base = isBreak ? 'RIGHT NOW — RESTING' : 'RIGHT NOW';
    // The live row is rendered OUTSIDE TimelineRowTile (see _buildTimelineRow)
    // so it can span the full content width, which means it has no time
    // gutter to sit in. The start time therefore moves into the kicker —
    // 22-UI-SPEC.md "The live row", amended 2026-08-08 after UAT.
    final start = chunk.displayStartMinutes;
    if (start == null) return base;
    // formatMinutes ("12:30 PM"), not formatMinutesCompact ("12:30p"):
    // LiveRowCard uppercases the whole kicker, which would render the
    // compact form's lowercase meridiem as a stray "12:30P".
    return '$base · ${formatMinutes(start)}';
  }

  /// The single source of "how much of the current activity is left," in
  /// whole seconds. Feeds the live row's remaining-time label AND the
  /// fast-timer decision ([_syncFastTimer]) — because both read this one
  /// value, they can never disagree (P-5). (The live row's progress bar was
  /// deleted in Phase 27/GRID-02 — the now-line's position within the row's
  /// duration-exact slot already communicates fraction-elapsed, so a
  /// second, redundant indicator was removed rather than kept in sync.)
  /// Returns `null` unless [nowState] is [Active] and its current chunk has
  /// a clock position (`displayStartMinutes`).
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

  /// Builds the live row (D-01, GRID-02). The kicker names a running break
  /// as "RIGHT NOW — RESTING" (LIVE-01). [secondsRemaining] is
  /// [_liveSecondsRemaining]'s output, threaded down from build() so the
  /// countdown is computed exactly once (P-5). [slotHeight] is this row's
  /// duration-exact slot height, threaded straight through to
  /// [LiveRowCard.slotHeight] so it can pick its own density tier — this row
  /// no longer swells past it.
  Widget _buildLiveRow(
    BuildContext context,
    ScheduledChunk chunk,
    NowState nowState,
    int? secondsRemaining,
    double slotHeight,
  ) {
    final title = _liveTitle(context, chunk);
    final start = chunk.displayStartMinutes;
    final end = start != null ? start + chunk.durationMinutes : null;

    String remainingLabel;
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
    } else if (start != null && end != null) {
      // Overdue — the old "now" card's existing plain time-range copy.
      // The Overdue branch deliberately shows the plain window range and no
      // countdown (LIVE-02 does not ask it to); do NOT invent "behind"
      // wording here (Copywriting Contract).
      remainingLabel = formatTimeRange(start, end);
    } else {
      remainingLabel = '${chunk.durationMinutes} min';
    }

    // PD-27-06: the tap handler is non-null only for an unresolved live WORK
    // chunk — mirroring the onTap gate _buildChunkCard applies. Tier
    // selection lives in LiveRowCard itself, so this screen cannot know
    // which tier will render; the compact tier has explicit icon buttons and
    // deliberately ignores onTap, and a live BREAK gets onTap: null in both
    // tiers (27-UI-SPEC.md: "no tap target at all").
    final goalColor = _lookupGoalColor(context, chunk);
    final goalName = _lookupGoalName(context, chunk);
    final displayRationale = _toDisplayRationale(chunk.rationale);
    final onTap =
        chunk.chunkType == ChunkType.work &&
            !chunk.isCompleted &&
            !chunk.isSkipped
        ? () => _openDetailSheet(
            context,
            chunk,
            goalColor,
            goalName,
            displayRationale,
          )
        : null;

    // D-31-07: a live break is skip-only now, not action-less. `isBreak`
    // is any non-work chunk type — the same definition `_needsSlop` and the
    // non-live break arm above use. `showActions` used to mean "work chunks
    // only"; it now means "this row offers at least one action", true for a
    // work chunk exactly as before and, additively, for an unresolved break
    // — a resolved (already-skipped) break must not advertise an action it
    // will not accept, the same rule SwipeableChunkCard enforces with
    // DismissDirection.none.
    final isBreak = chunk.chunkType != ChunkType.work;
    return LiveRowCard(
      chunkId: chunk.id,
      kicker: _liveKicker(chunk),
      title: title,
      remainingLabel: remainingLabel,
      slotHeight: slotHeight,
      showActions: isBreak ? !chunk.isSkipped : true,
      showComplete: !isBreak,
      isSkipped: chunk.isSkipped,
      onTap: onTap,
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
  ///
  /// [nowDt] is build()'s single clock sample, forwarded through
  /// [shouldShowEodCard]'s `now` seam. It is REQUIRED, not defaulted: the
  /// top-level function falls back to `DateTime.now` when the seam is
  /// omitted, and omitting it here is exactly the D-01 violation this
  /// signature now makes impossible to reintroduce. Before this parameter
  /// existed the card read its own independent clock, so its `hour >= 18`
  /// branch ignored the screen's injected `_nowFn` entirely — every widget
  /// test that pumped this screen silently changed behaviour at 6pm local
  /// time, which is how the suite came to fail only in the evenings.
  bool _shouldShowEodCard(List<ScheduledChunk> chunks, DateTime nowDt) =>
      shouldShowEodCard(chunks, now: () => nowDt);

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

    // The only three "what is happening now" calls on this screen (P1 /
    // 22-PATTERNS.md section 5): this samples the clock exactly once,
    // buildTimeline turns that classification into a row list, and nothing
    // below this point re-derives which chunk is current.
    //
    // nowDt is sampled here and threaded into FOUR consumers —
    // resolveNowState (via a closure that always returns this same value),
    // _liveSecondsRemaining directly, nowMinutes below, and
    // _shouldShowEodCard's `now` seam — a single clock read per build, so the
    // consumers can never straddle a second/minute boundary and disagree
    // (WR-01). The end-of-day card was the fourth consumer all along but
    // used to read its own `DateTime.now`; that made it the one element on
    // this screen that could disagree with every other one about what time
    // it was. nowMinutes also feeds the geometry construction below and
    // (plan 04) the now-line overlay: it is a *position* derived from that
    // same sample, never a second opinion about which chunk is current
    // (D-01).
    final nowDt = _nowFn();
    final nowMinutes = minutesOfDay(nowDt);
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
      nowMinutes: nowMinutes,
    );

    // CAL-01 geometry (26-03-PLAN.md): derived from the SAME nowMinutes
    // sampled above — never a second clock read (T-26-04). firstStart/
    // lastEnd span every chunk with a clock position; the live chunk's
    // bounds mirror timeline.dart's own liveId derivation (Active and
    // Overdue both count as "live"). liveStartMinutes/liveEndMinutes are
    // still threaded into TimelineGeometry.forDay below even though GRID-01
    // (Phase 27) deleted the yFor() exception that used to consume them —
    // TimelineGeometry retains them as the documented source for a possible
    // future now-line time chip's live-span predicate (see this file's
    // NowLineOverlay comment below), and this derivation must keep
    // mirroring timeline.dart's liveId so the two never disagree about which
    // chunk is live.
    int? firstStartMinutes;
    int? lastEndMinutes;
    for (final chunk in schedule.chunks) {
      final start = chunk.displayStartMinutes;
      if (start == null) continue;
      if (firstStartMinutes == null || start < firstStartMinutes) {
        firstStartMinutes = start;
      }
      final end = start + chunk.durationMinutes;
      if (lastEndMinutes == null || end > lastEndMinutes) {
        lastEndMinutes = end;
      }
    }
    final ScheduledChunk? liveChunk = switch (nowState) {
      Active(:final current) => current,
      Overdue(:final overdue) => overdue,
      _ => null,
    };
    final liveStartMinutes = liveChunk?.displayStartMinutes;
    final liveEndMinutes = liveStartMinutes != null
        ? liveStartMinutes + liveChunk!.durationMinutes
        : null;
    final geometry = TimelineGeometry.forDay(
      nowMinutes: nowMinutes,
      firstStartMinutes: firstStartMinutes,
      lastEndMinutes: lastEndMinutes,
      liveStartMinutes: liveStartMinutes,
      liveEndMinutes: liveEndMinutes,
    );

    // A debug clock jump re-arms centre-on-open (Phase 25, DEV-01).
    //
    // The one-shot below otherwise resets ONLY when the schedule's dateYmd
    // changes (didChangeDependencies). Time-travelling from morning to 9pm
    // on the SAME day leaves dateYmd untouched, so without this the list
    // would stay wherever it was and "now" would never be scrolled to —
    // which would make the exact UAT this harness exists to enable ("jump
    // to 9pm, check DayComplete") report a false negative against a fix
    // that works.
    //
    // Release-safe and behaviour-preserving: DevClock.offset is always
    // Duration.zero in release (DEV-03), so this can never fire there.
    // Reading `offset` is a Duration field access, not a clock read, so
    // D-01's single-sample rule is untouched.
    if (DevClock.offset != _lastDevClockOffset) {
      _lastDevClockOffset = DevClock.offset;
      _didCentreOnOpen = false;
    }

    // Centre-on-open (CAL-03): schedule the scroll exactly once, in every
    // NowState, with no primary/fallback branch (26-05-PLAN.md PD-19). The
    // flag is set synchronously here — before the post-frame callback even
    // runs — so a rebuild triggered by the same tick that flips this bit
    // can never schedule a second one (T-22-08). See the field doc comment
    // above for the full reset/one-shot discipline.
    if (!_didCentreOnOpen) {
      _didCentreOnOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // The empty state renders no scroll view at all, and a schedule
        // can also become empty between the frame that scheduled this
        // callback and the frame it runs in — reading the controller's
        // position on a clientless controller throws (T-26-08).
        if (!_dayScrollController.hasClients) return;
        // The Stack's own leading offset inside the scroll content — NOT
        // geometry.yFor(nowMinutes) alone, since a mood<=2 day scrolls the
        // restoratives card above the Stack (PD-17). Resolved with the
        // same viewport machinery Flutter's own scroll-into-view helper
        // uses internally.
        final stackBox =
            _timelineStackKey.currentContext?.findRenderObject()
                as RenderBox?;
        if (stackBox == null) return;
        final stackTop = RenderAbstractViewport.of(
          stackBox,
        ).getOffsetToReveal(stackBox, 0.0).offset;
        final viewportHeight =
            _dayScrollController.position.viewportDimension;
        final raw = stackTop + geometry.yFor(nowMinutes) - viewportHeight / 2;
        // Read post-layout only — this line, and only this line (PD-16). A
        // DayComplete day puts "now" at the very bottom, so the naive
        // target routinely exceeds this bound; clamping here is what lands
        // that case gracefully at the bottom instead of throwing or
        // no-op-ing.
        final target = raw.clamp(
          0.0,
          _dayScrollController.position.maxScrollExtent,
        );
        _dayScrollController.animateTo(
          target,
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
              _buildDevClockBanner(context, nowDt),
              ScheduleProgressBar(schedule: schedule, moodColor: moodColor),
              if (_inReviewWindow && !_bannerDismissed)
                ReviewBanner(
                  onStart: () => context.push('/review'),
                  onDismiss: () => setState(() => _bannerDismissed = true),
                ),
              if (!_eodCardDismissed &&
                  _shouldShowEodCard(schedule.chunks, nowDt))
                EndOfDayCard(
                  chunks: schedule.chunks,
                  onDismiss: () => setState(() => _eodCardDismissed = true),
                  onGoToSummary: () => context.push('/summary'),
                ),
              _buildHeader(context, schedule, mood, nowDt),
              _buildEdgeStateLine(context, nowState),
              // SingleChildScrollView + Column, deliberately NOT a ListView:
              // the centre-on-open above needs the live row already laid
              // out, and a lazy ListView may not have built a row far down
              // the day. A day is bounded at a few dozen rows, so eager
              // layout is the cheap correct answer and avoids a
              // scroll-positioning package. CAL-01 (26-03-PLAN.md) adds a
              // second reason that now applies too: a lazy list cannot
              // express an overlay painted at an arbitrary absolute pixel
              // offset across the whole scrollable content, which plan 04's
              // hour axis and now-line both require — eager layout is what
              // makes a single fixed-height Stack region possible at all.
              Expanded(
                child: SingleChildScrollView(
                  controller: _dayScrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mood <= 2) _buildRestorativeSuggestions(context),
                      // Layer 1 — every non-live row first, then the live
                      // row's Positioned last (PD-10): it is appended last
                      // within this Stack so a future content addition that
                      // overruns its reservation paints over its neighbour
                      // rather than being clipped by one painted after it.
                      SizedBox(
                        key: _timelineStackKey,
                        height: geometry.totalHeight,
                        child: Stack(
                          children: [
                            // Layer 2 — hour axis, painted behind every row's
                            // content. The hairline is `outlineVariant`, not
                            // `primary` (26-UI-SPEC.md "The time gutter
                            // becomes an hour axis") — deliberately, so the
                            // axis reads as quiet infrastructure and
                            // `colorScheme.primary` stays reserved for
                            // "where now is" (D-03). Purely decorative:
                            // wrapped below so it never eats a tap, and
                            // `ExcludeSemantics` so it doesn't add a dozen
                            // unlabelled nodes to a screen that already
                            // announces every row.
                            for (final hourMinutes in geometry.hourBoundaries)
                              Positioned(
                                top:
                                    geometry.yFor(hourMinutes) -
                                    kHourAxisHeight / 2,
                                left: 0,
                                right: 0,
                                height: kHourAxisHeight,
                                child: IgnorePointer(
                                  child: ExcludeSemantics(
                                    child: HourAxisLine(
                                      hourMinutes: hourMinutes,
                                    ),
                                  ),
                                ),
                              ),
                            // Layer 1a — the rows (26-03-PLAN.md), minus the
                            // live row AND minus any slop-bearing break
                            // (Phase 31, the third exclusion added below).
                            // Non-live, non-slop rows first, in their normal
                            // chronological order.
                            for (final row in timelineRows)
                              if (!(row is ChunkRow && row.isLive) &&
                                  !(row is ChunkRow &&
                                      row.chunk.displayStartMinutes == null) &&
                                  !(row is ChunkRow &&
                                      _needsSlop(row.chunk, geometry)))
                                _buildPositionedRow(
                                  context,
                                  row,
                                  geometry,
                                  nowState,
                                  liveSecondsLeft,
                                ),
                            // Layer 1b (Phase 31, D-31-02 — the load-bearing
                            // fix from 31-RESEARCH.md Pitfall 1) — every
                            // non-live, slop-bearing break, added AFTER
                            // Layer 1a and BEFORE the now-line overlay.
                            //
                            // `Stack` resolves overlapping siblings by
                            // walking `lastChild` backward and stopping at
                            // the first hit (RenderStack /
                            // defaultHitTestChildren) — before this phase
                            // every row's box was exactly its slot with zero
                            // gap between rows, so no two siblings' hit-test
                            // boxes ever overlapped and hit-test order was
                            // irrelevant. A slop-bearing break's grown box
                            // (_buildPositionedRow's break arm) is the FIRST
                            // overlap this codebase has ever had: it now
                            // covers pixels also still geometrically inside
                            // its unenlarged neighbours' own boxes.
                            // `timelineRows` is chronological, so iterating
                            // this row in place (inside Layer 1a above)
                            // would win the top slop band against the
                            // preceding work chunk (added earlier) but LOSE
                            // the bottom slop band to the following one
                            // (added later) — halving the effective touch
                            // target from 52dp to ~36dp, under both
                            // Material's 48dp and iOS's 44pt minimums.
                            // Emitting these rows in their own later pass
                            // makes them `lastChild`-ward of BOTH
                            // neighbours, mirroring the live-row pattern
                            // (PD-10) below. The ordering IS the mechanism,
                            // exactly as the live-row comment states —
                            // moving this loop back into Layer 1a silently
                            // halves the touch target with every test still
                            // green except the bottom-band one.
                            for (final row in timelineRows)
                              if (row is ChunkRow &&
                                  !row.isLive &&
                                  row.chunk.displayStartMinutes != null &&
                                  _needsSlop(row.chunk, geometry))
                                _buildPositionedRow(
                                  context,
                                  row,
                                  geometry,
                                  nowState,
                                  liveSecondsLeft,
                                ),
                            // The live row is NOT emitted here any more — it
                            // moved below the now-line overlay (UAT,
                            // 2026-08-19). See the comment at its new
                            // position for why the order is load-bearing.
                            // Layer 3 — the now-line (CAL-02), topmost in the
                            // Stack, above every card's elevation/shadow.
                            // This overlay replaces Phase 24's
                            // `NowMarkerRow`; the state-check suppression
                            // that used to hide it whenever the current
                            // moment fell outside an active chunk's window
                            // is DELETED, not relocated (PD-12) — a
                            // proportional layout can place the line
                            // truthfully mid-chunk, which is the exact
                            // condition that suppression existed to avoid,
                            // and the exact reason this phase exists.
                            // Unconditional: no `if`, no ternary, no state
                            // check. `Semantics` sits OUTSIDE the
                            // pointer-ignoring wrapper below (PD-13) —
                            // modern pointer-ignoring widgets also strip
                            // their subtree from the semantics tree, so
                            // putting the label inside it would silently
                            // delete the "Now — <time>" announcement
                            // (24-REVIEW.md WR-01).
                            Positioned(
                              top: geometry.yFor(nowMinutes) - kNowLineHeight / 2,
                              left: 0,
                              right: 0,
                              height: kNowLineHeight,
                              child: Semantics(
                                label: 'Now — ${formatMinutes(nowMinutes)}',
                                excludeSemantics: true,
                                child: IgnorePointer(
                                  // The overlay takes no suppression flag any
                                  // more: the `showChip` argument that used to
                                  // sit here existed only to keep the time
                                  // chip off the live row (G-03,
                                  // 26-09-PLAN.md), and the chip is gone. The
                                  // rule and dot are safe over the live row —
                                  // they carry no text to occlude. If a chip
                                  // is ever restored, the live-span predicate
                                  // it needs is in this file's git history;
                                  // read it off `TimelineGeometry`
                                  // (`liveStartMinutes`/`liveEndMinutes`,
                                  // half-open), never from `resolveNowState`
                                  // or the chunk list.
                                  child: NowLineOverlay(
                                    nowMinutes: nowMinutes,
                                  ),
                                ),
                              ),
                            ),
                            // The live row, painted LAST — above the now-line
                            // rule (UAT, 2026-08-19). Order is the whole fix.
                            //
                            // Phase 27 shortened this card from ~200dp to
                            // ~90dp, and a card that short has no whitespace
                            // for the rule to land in: it struck clean through
                            // "Exercise" on the compact tier and through the
                            // single line of the break tier, which reads as
                            // strikethrough — "done"/"cancelled" — on the one
                            // row that is emphatically neither
                            // (`27-UI-REVIEW.md` addendum, with screenshots).
                            // `27-UI-SPEC.md` had reasoned the crossing would
                            // be harmless; it is not, and it only looked
                            // harmless because the evidence screenshots
                            // happened to catch the rule at a card edge.
                            //
                            // Painting the card over the rule stops the line
                            // at the card's edges, which is what Google
                            // Calendar does with its current event. The rule
                            // is NOT suppressed and the overlay takes no new
                            // flag — nothing is conditional, so this cannot
                            // rot the way the old `showChip` predicate did.
                            //
                            // The now-marker stays discoverable because the
                            // dot is centred on `kNowContentEdge`, which is
                            // exactly `kCardLeftInset` — so its left half sits
                            // outside the card and remains visible, along with
                            // the gutter time. Do not inset this card further
                            // left to "fix" that; three prior attempts to move
                            // this row horizontally each broke something
                            // (see `LiveRowCard`'s own doc comment).
                            for (final row in timelineRows)
                              if (row is ChunkRow && row.isLive)
                                _buildPositionedRow(
                                  context,
                                  row,
                                  geometry,
                                  nowState,
                                  liveSecondsLeft,
                                ),
                          ],
                        ),
                      ),
                      // Trailing block (PD-11): a chunk with no clock
                      // position has no truthful y, so it renders here at
                      // natural height instead of inside the Stack above.
                      // The schedule generator does not currently produce
                      // one — this is a preservation branch, not a feature.
                      for (final row in timelineRows)
                        if (row is ChunkRow &&
                            row.chunk.displayStartMinutes == null)
                          TimelineRowTile(
                            child: _buildChunkCard(
                              context,
                              row.chunk,
                              ChunkCardDensity.detailed,
                            ),
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
              // The empty state has no schedule to derive a nowDt sample
              // from (build() below never reaches the active-schedule
              // branch that samples _nowFn()), so this is the one path in
              // this file that reads the clock fresh for display purposes
              // only — nothing here derives day-state from it.
              _buildDevClockBanner(context, _nowFn()),
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
