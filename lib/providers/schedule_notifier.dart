import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/commitment_block.dart';
import '../data/models/completion_log.dart';
import '../data/models/daily_schedule.dart';
import '../data/models/goal.dart';
import '../data/models/scheduled_chunk.dart';
import '../data/repositories/completion_log_repository.dart';
import '../data/repositories/daily_schedule_repository.dart';
import '../data/repositories/goal_repository.dart';
import '../data/repositories/hive_completion_log_repository.dart';
import '../data/repositories/hive_daily_schedule_repository.dart';
import '../data/repositories/hive_goal_repository.dart';
import '../services/schedule_generator.dart';

class ScheduleNotifier extends ChangeNotifier with WidgetsBindingObserver {
  /// Construct a ScheduleNotifier. [now] defaults to `DateTime.now` and is
  /// injectable for unit tests to simulate day-boundary crossings without
  /// waiting for real wall-clock time. Mirrors ThemeNotifier's constructor
  /// style (lines 43-49 of theme_notifier.dart).
  ///
  /// [repo] and [logRepo] are optional injectable repositories for testing.
  /// Production code omits them and the notifier creates the Hive-backed
  /// implementations. Test code passes in-memory fakes to avoid Hive bootstrap.
  ScheduleNotifier({
    DateTime Function() now = DateTime.now,
    DailyScheduleRepository? repo,
    CompletionLogRepository? logRepo,
    GoalRepository? goalRepo,
  }) : _now = now,
       _repo = repo ?? HiveDailyScheduleRepository(),
       _logRepo = logRepo ?? HiveCompletionLogRepository(),
       _goalRepo = goalRepo ?? HiveGoalRepository();

  final DateTime Function() _now;
  final DailyScheduleRepository _repo;
  final CompletionLogRepository _logRepo;
  final GoalRepository _goalRepo;
  final ScheduleGeneratorService _generator = ScheduleGeneratorService();

  DailySchedule? _todaySchedule;
  bool _loading = false;

  DailySchedule? get todaySchedule => _todaySchedule;

  /// True only when a schedule exists AND it was generated for today's local
  /// calendar date (LOOP-02: stale schedule from a prior day returns false).
  bool get hasScheduleToday {
    if (_todaySchedule == null) return false;
    final todayStr = DateFormat('yyyy-MM-dd').format(_now());
    return _todaySchedule!.dateYmd == todayStr;
  }

  int? get moodIndex => _todaySchedule?.moodIndex;
  bool get isLoading => _loading;

  /// Loads today's persisted schedule, registers the lifecycle observer, and
  /// calls _resetIfDayChanged so a stale schedule from a prior day is cleared
  /// immediately on startup. Call once at startup before runApp().
  Future<void> init() async {
    await _loadToday();
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  /// Re-reads today's persisted schedule WITHOUT re-registering the
  /// lifecycle observer — [init] already does that once at startup, and
  /// calling it again here would register [this] as a duplicate
  /// [WidgetsBindingObserver] on every call.
  ///
  /// Phase 25 (Time Travel, DEV-01): this is what lets the debug clock
  /// override UI make the rest of the app agree on a simulated moment —
  /// after moving [DevClock], the "today" key `getTodaysSchedule()` reads
  /// may have changed, so the in-memory schedule needs to be re-fetched to
  /// match. Safe to call any time after [init].
  Future<void> reloadToday() async {
    await _loadToday();
    notifyListeners();
  }

  /// Shared load step behind [init] and [reloadToday]: fetch today's
  /// schedule and clear it if it turns out to be from a prior local day.
  Future<void> _loadToday() async {
    _loading = true;
    _todaySchedule = await _repo.getTodaysSchedule();
    _loading = false;
    // LOOP-02: clear stale in-memory schedule if it belongs to a prior day.
    _resetIfDayChanged();
  }

  /// Called on resume and at end of init(): if the loaded schedule is from a
  /// prior local calendar day, clear it so hasScheduleToday returns false and
  /// the UI shows the un-generated "Start your day" state. Per CONTEXT.md
  /// new-day behavior: fresh check-in, no auto-regenerate.
  void _resetIfDayChanged() {
    if (_todaySchedule == null) return;
    final todayStr = DateFormat('yyyy-MM-dd').format(_now());
    if (_todaySchedule!.dateYmd != todayStr) {
      _todaySchedule = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check date on resume so a user who backgrounds overnight sees the
      // un-generated state when they reopen the app (LOOP-02).
      _resetIfDayChanged();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> generateToday({
    required int moodIndex,
    required List<Goal> goals,
    required List<CommitmentBlock> blocks,
    bool lighterDay = true,
  }) async {
    final now = _now();
    final date = DateTime(now.year, now.month, now.day); // midnight local
    final dateYmd = DateFormat('yyyy-MM-dd').format(now);

    // Fetch completion logs for all active (non-archived) goals.
    // Uses getByGoalId per goal — not getAll — to avoid loading irrelevant logs.
    // Empty goalId guard: archived goals are excluded by the where filter,
    // so we never call getByGoalId('') for commitment chunks.
    final allLogs = <CompletionLog>[];
    for (final goal in goals.where((g) => !g.isArchived)) {
      allLogs.addAll(await _logRepo.getByGoalId(goal.id));
    }

    // CLOSE-02: single-hop deferred carry-in from the immediately preceding day.
    // Only discretionary (non-commitment) deferred chunks re-enter as fresh demand
    // for their goal. Commitment chunks are anchored to their day and do not carry
    // (goalId == null for commitment chunks, so the filter naturally excludes them).
    final yesterday = date.subtract(const Duration(days: 1));
    final yesterdayYmd = DateFormat('yyyy-MM-dd').format(yesterday);
    final priorSchedule = await _repo.getByDate(yesterdayYmd);
    final deferredGoalIds =
        priorSchedule?.chunks
            .where((c) => c.isDeferred && !c.isCompleted && c.goalId != null)
            .map((c) => c.goalId!)
            .toSet() ??
        {};

    final chunks = _generator.generate(
      goals: goals,
      blocks: blocks,
      moodIndex: moodIndex,
      date: date,
      completionLogs: allLogs,
      lighterDay: lighterDay,
      deferredGoalIds: deferredGoalIds, // CLOSE-02 carry-in
      // Start the discretionary plan near "now" (clamped to ≥8:00 AM in the
      // engine) so a mid-day check-in doesn't schedule into passed morning hours.
      startFloorMinutes: now.hour * 60 + now.minute,
    );

    // STREAK-01: sync streakCount for all active habit goals at generation time.
    // The engine computes the authoritative streak internally but does not write
    // it back to goal.streakCount — the displayed value lags until a mark action.
    // This write-back closes that divergence window on cold launch and day-boundary.
    // No-op guard: only saves when the computed value differs from the stored value
    // to avoid N redundant writes per day (Pitfall 3 / T-15-03).
    for (final goal in goals.where(
      (g) => !g.isArchived && g.goalType == GoalType.habit,
    )) {
      try {
        final due = ScheduleGeneratorService.computeDueWeekdays(
          goal.frequencyPerWeek ?? 7,
        );
        // allLogs already contains only entries for goals in this loop (built
        // via getByGoalId above), but re-filter defensively in case the
        // log-fetch strategy changes and allLogs starts containing mixed entries.
        final logsForGoal = allLogs.where((l) => l.goalId == goal.id).toList();
        final computed = ScheduleGeneratorService.computeStreak(
          goal.id,
          due,
          logsForGoal,
          today: date,
        );
        if (goal.streakCount != computed) {
          goal.streakCount = computed;
          await _goalRepo.save(goal);
        }
      } catch (_) {
        // T-15-04: streak staleness is tolerable; generation must not be blocked.
      }
    }

    // Silent replace: delete existing schedule for today if any.
    final existing = await _repo.getByDate(dateYmd);
    if (existing != null) await _repo.delete(existing.id);

    final schedule = DailySchedule(
      dateYmd: dateYmd,
      moodIndex: moodIndex,
      chunks: chunks,
    );
    // Set generatedAt explicitly (field-level default runs at class parse time, not instantiation).
    schedule.generatedAt = _now().toUtc();

    await _repo.save(schedule);
    _todaySchedule = schedule;
    notifyListeners();
  }

  /// Inserts a commitment [block]'s anchored work chunks into TODAY's existing
  /// schedule, in place, WITHOUT regenerating (so completed/skipped progress is
  /// preserved). This is what lets a human add an actual event from the Today
  /// screen and see it land immediately, rather than only after a mood
  /// re-check-in that would rebuild the whole day.
  ///
  /// Reconciles a commitment [block] onto TODAY's schedule in place, WITHOUT a
  /// full regenerate (so completed/skipped progress is preserved). This is what
  /// lets a human add — or edit — an actual event and see it land immediately,
  /// rather than only after a mood re-check-in that would rebuild the whole day.
  ///
  /// Idempotent by commitmentId: any chunks already on today for this block are
  /// removed first, so EDITING an event (e.g. changing its time on the
  /// Commitments screen) re-anchors correctly instead of leaving a stale copy.
  /// After inserting the event's anchored chunks, unresolved discretionary work
  /// chunks that would overlap the event are reflowed into free time, so a
  /// manual add can never silently double-book the timeline.
  ///
  /// Returns true when the block anchors on today and was placed; false when the
  /// block is for another day (nothing to show on today — any stale chunks for
  /// it are still cleared). When today has no schedule yet, a minimal one is
  /// CREATED containing just this event, so a human can enter an event from the
  /// empty Today screen WITHOUT a forced mood check-in. The event is a saved
  /// commitment, so a later check-in re-anchors it (silent-replace generate()).
  Future<bool> addEventToday(CommitmentBlock block) async {
    final now = _now();
    final date = DateTime(now.year, now.month, now.day);
    final bool anchorsToday;
    if (block.date != null) {
      final d = block.date!;
      anchorsToday =
          d.year == date.year && d.month == date.month && d.day == date.day;
    } else {
      anchorsToday = block.daysOfWeek.contains(date.weekday);
    }

    // Idempotent re-anchor: drop any existing chunks for this block from today
    // (handles edit; also clears stale chunks when a block is moved off today).
    var removedStale = false;
    if (hasScheduleToday && _todaySchedule != null) {
      final kept = _todaySchedule!.chunks
          .where((c) => c.commitmentId != block.id)
          .toList();
      removedStale = kept.length != _todaySchedule!.chunks.length;
      _todaySchedule!.chunks = kept;
      // If the removed block was the day's chronologically-last item, a break
      // that used to sit before it is now trailing with no re-trim (CR-01,
      // Phase 23 review iteration 2). Both branches below (`!anchorsToday`
      // early return and the `newChunks.isEmpty` guard) persist directly from
      // here without going through `_reflowDiscretionaryWork`, so re-trim now
      // rather than relying on either of those call sites remembering to.
      _trimTrailingNonWork();
    }

    if (!anchorsToday) {
      // Block no longer belongs to today — persist any stale removal and stop.
      if (removedStale) {
        await _repo.save(_todaySchedule!);
        notifyListeners();
      }
      return false;
    }

    // D-30-03: delegate to ScheduleGeneratorService.buildCommitmentChunks
    // instead of hand-rolling a second copy of the commitment-window walk.
    // The old local loop here carried the identical bare unbroken-lattice
    // defect as generate()'s pre-30-03 Step 1 — two independent
    // implementations of the same rule is exactly how that defect survived
    // into a second file, so the duplicate is deleted rather than repaired.
    // Both entry points (generate() and addEventToday) now produce
    // identical 25+5(+30) lattice windows BY CONSTRUCTION, because both
    // call the same helper. Cadence comes from today's own mood — the
    // existing schedule's moodIndex when one exists, else 3 (matching the
    // minimal-schedule branch's own default below for exactly this
    // situation) — via breakCadenceForMood, which carries the same
    // out-of-range fallback the generator uses.
    final cadenceMoodIndex = _todaySchedule?.moodIndex ?? 3;
    final newChunks = ScheduleGeneratorService.buildCommitmentChunks(
      block,
      longBreakEvery: ScheduleGeneratorService.breakCadenceForMood(
        cadenceMoodIndex,
      ),
    );
    if (newChunks.isEmpty) {
      if (removedStale) {
        await _repo.save(_todaySchedule!);
        notifyListeners();
      }
      return false;
    }

    if (hasScheduleToday && _todaySchedule != null) {
      final chunks = [..._todaySchedule!.chunks, ...newChunks];
      // Reflow unresolved discretionary work around the (now updated) set of
      // anchored commitment windows so nothing double-books the new event.
      final nowMinutes = now.hour * 60 + now.minute;
      // WR-01: source the reflow's break cadence from the same mood-derived
      // value buildCommitmentChunks just used above (cadenceMoodIndex),
      // instead of a hardcoded constant — otherwise the reflowed portion of
      // the day would silently diverge from the cadence the anchored chunks
      // inserted moments earlier in this same call used.
      final reflowed =
          _reflowDiscretionaryWork(
            chunks,
            nowMinutes: nowMinutes,
            longBreakEvery: ScheduleGeneratorService.breakCadenceForMood(
              cadenceMoodIndex,
            ),
          )..sort((a, b) {
            final aStart = a.displayStartMinutes ?? 9999;
            final bStart = b.displayStartMinutes ?? 9999;
            return aStart.compareTo(bStart);
          });
      _todaySchedule!.chunks = reflowed;
      await _repo.save(_todaySchedule!);
    } else {
      // No day built yet — create a minimal schedule holding just this event so
      // it shows immediately. moodIndex defaults to neutral (3); a subsequent
      // mood check-in regenerates the day and re-anchors this saved commitment.
      final dateYmd = DateFormat('yyyy-MM-dd').format(now);
      final existing = await _repo.getByDate(dateYmd);
      if (existing != null) await _repo.delete(existing.id);
      final schedule = DailySchedule(
        dateYmd: dateYmd,
        moodIndex: 3,
        chunks: newChunks,
      );
      schedule.generatedAt = now.toUtc();
      await _repo.save(schedule);
      _todaySchedule = schedule;
    }
    notifyListeners();
    return true;
  }

  /// Removes trailing DISCRETIONARY non-work chunks from
  /// `_todaySchedule!.chunks`, mirroring `ScheduleGeneratorService.generate()`'s
  /// STEP E trim (`schedule_generator.dart`). `addEventToday`'s stale-chunk-
  /// removal above can leave a break as the day's new trailing item when the
  /// commitment that used to follow it moves off today; without this trim,
  /// that dangling break survives into persisted state and whatever reads it
  /// next (e.g. `resolveNowState`). No-op if `_todaySchedule` is null or
  /// already trailing-work-clean.
  ///
  /// Mirrors the generator's own STEP E narrowing (schedule_generator.dart)
  /// with BOTH of its guards, not just one:
  ///
  /// 1. `chunkType == ChunkType.shortBreak` — only a trailing SHORT break is
  ///    ever trimmed. A trailing LONG break deliberately survives
  ///    (LATTICE-02: "never silently suppressed" — a day can legitimately
  ///    end on an explicit "take a 30-minute break" card with nothing after
  ///    it, e.g. Test 6 in schedule_generator_test.dart). CR-01 (code review
  ///    iteration 2): this guard was missing here even though STEP E has
  ///    always had it, so this trim matched `chunkType != ChunkType.work`
  ///    instead — both break types — and silently deleted a legitimate
  ///    trailing discretionary long break (and, via the cascading `while`,
  ///    its preceding short break too) out of persisted Hive state on every
  ///    `addEventToday` call.
  /// 2. `commitmentId == null` (D-30-02) — only a discretionary trailing
  ///    break may be trimmed. Before D-30-03 wired `addEventToday` to
  ///    `buildCommitmentChunks`, every break here was discretionary by
  ///    construction, so the unnarrowed loop was harmless; now that anchored
  ///    commitment breaks exist on this path too, an unnarrowed trim could
  ///    durably delete real committed minutes from Hive the moment a
  ///    commitment break happens to be the day's chronologically-last chunk.
  ///
  /// `chunks` is not guaranteed clock-sorted at this point, so trim against a
  /// sorted copy and remove by identity from the real list — "trailing"
  /// means the same thing here as it does in `resolveNowState`.
  void _trimTrailingNonWork() {
    final schedule = _todaySchedule;
    if (schedule == null) return;
    final sorted = List<ScheduledChunk>.from(schedule.chunks)
      ..sort((a, b) {
        final aStart = a.displayStartMinutes ?? 9999;
        final bStart = b.displayStartMinutes ?? 9999;
        return aStart.compareTo(bStart);
      });
    while (sorted.isNotEmpty &&
        sorted.last.chunkType == ChunkType.shortBreak &&
        sorted.last.commitmentId == null) {
      schedule.chunks.remove(sorted.removeLast());
    }
  }

  /// Re-packs unresolved discretionary WORK chunks (goal-driven, not anchored,
  /// not yet completed/skipped) into free 25-minute slots that avoid every
  /// anchored commitment window AND every already-resolved chunk, so inserting
  /// or editing an event never leaves two work chunks claiming the same clock
  /// time. Anchored (commitment) chunks and resolved chunks keep their positions.
  ///
  /// Break chunks are NOT frozen: the old (unresolved) breaks are DROPPED and
  /// fresh short/long breaks are re-emitted between the repacked work chunks
  /// (mirroring the generator's cadence), so a reflow can never leave a break
  /// overlapping a work chunk or orphan the Pomodoro spacing. Packing starts at
  /// max(8:00, [nowMinutes]) so an add mid-day never schedules work into hours
  /// that have already passed. Returns the rebuilt chunk list (callers sort it).
  ///
  /// [longBreakEvery] (WR-01) is the caller-supplied, mood-derived cadence —
  /// this method used to hardcode a constant `4` here regardless of the
  /// day's real mood, silently diverging from `buildCommitmentChunks`'s own
  /// mood-derived cadence in the very same `addEventToday` call. The caller
  /// (`addEventToday`) passes `ScheduleGeneratorService.breakCadenceForMood`.
  List<ScheduledChunk> _reflowDiscretionaryWork(
    List<ScheduledChunk> chunks, {
    required int nowMinutes,
    required int longBreakEvery,
  }) {
    // IN-01: read day-boundary/duration values from ScheduleGeneratorService
    // instead of re-declaring separate literals — the duplication is exactly
    // how WR-03's 25-vs-30 long-break value drifted unnoticed.
    const dayStart = ScheduleGeneratorService.dayStartMinutes;
    const dayEnd = ScheduleGeneratorService.dayEndMinutes;
    const workMinutes = ScheduleGeneratorService.workChunkMinutes;

    // Partition: keep anchored + resolved (incl. resolved work); collect movable
    // unresolved work; DROP unresolved breaks (re-emitted below).
    final kept = <ScheduledChunk>[];
    final movable = <ScheduledChunk>[];
    for (final c in chunks) {
      final resolved = c.isCompleted || c.isSkipped;
      if (c.anchoredStartMinutes != null || resolved) {
        kept.add(c);
      } else if (c.chunkType == ChunkType.work) {
        movable.add(c);
      }
      // else: an unresolved break chunk — dropped, re-derived after repacking.
    }
    if (movable.isEmpty) return kept;

    // Fixed occupied windows come from the kept (immovable) chunks.
    final fixed = <List<int>>[
      for (final c in kept)
        if (c.displayStartMinutes != null)
          [c.displayStartMinutes!, c.displayStartMinutes! + c.durationMinutes],
    ];
    final placed = <List<int>>[];
    bool hits(int s, int e) =>
        fixed.any((w) => s < w[1] && w[0] < e) ||
        placed.any((w) => s < w[1] && w[0] < e);

    final result = <ScheduledChunk>[...kept];
    // Round the now-floor up to the next 5-minute boundary, clamped into the day.
    final floor = (((nowMinutes + 4) ~/ 5) * 5).clamp(dayStart, dayEnd);
    int cursor = floor;
    int breakCount = 0;
    for (int i = 0; i < movable.length; i++) {
      final c = movable[i];
      int s = cursor;
      while (s + workMinutes <= dayEnd && hits(s, s + workMinutes)) {
        s += 5; // step by 5 for tidy start boundaries
      }
      if (s + workMinutes > dayEnd) {
        // Day genuinely full — leave the chunk untimed (sorts to the end) rather
        // than stacking it on an occupied slot.
        c.syntheticStartMinutes = null;
        result.add(c);
        continue;
      }
      c.syntheticStartMinutes = s;
      placed.add([s, s + workMinutes]);
      result.add(c);
      cursor = s + workMinutes;

      // Reserve + emit a break after this work chunk when more work remains and
      // it fits contiguously — same short/long break cadence the generator
      // uses (WR-03: this used to hardcode 25, five minutes short of the
      // system-wide 30-minute long break every other code path emits).
      if (i + 1 < movable.length) {
        breakCount++;
        final isLong = breakCount % longBreakEvery == 0;
        final dur = isLong
            ? ScheduleGeneratorService.longBreakMinutes
            : ScheduleGeneratorService.shortBreakMinutes;
        if (cursor + dur <= dayEnd && !hits(cursor, cursor + dur)) {
          result.add(
            ScheduledChunk(
              chunkTypeIndex:
                  (isLong ? ChunkType.longBreak : ChunkType.shortBreak).index,
              goalId: null,
              durationMinutes: dur,
              syntheticStartMinutes: cursor,
              rationale: '',
            ),
          );
          placed.add([cursor, cursor + dur]);
          cursor += dur;
        }
      }
    }
    return result;
  }

  /// G-05: when a work chunk is completed before its scheduled end, the
  /// immediately-following break (if any) absorbs the reclaimed time — it
  /// starts now and keeps its original end, becoming longer. This is Dan's
  /// decision from `23-UAT.md` ("extend the break to fill"): completing a
  /// 10:00-10:25 chunk at 10:10 turns a 10:25-10:30 break into a 10:10-10:30
  /// break. Nothing downstream shifts.
  ///
  /// This is a write-side-only change. Because the break's
  /// `syntheticStartMinutes` is genuinely moved to now, its clock window has
  /// genuinely opened — so `resolveNowState` reaches `Active` through its
  /// existing, unmodified path. The Phase 17 KEY INVARIANT ("an unopened
  /// break window is never promoted to Active",
  /// `test/screens/today_screen_now_state_test.dart:470-487`) is untouched:
  /// `_absorbReclaimedTimeIntoNextBreak` never promotes an unopened window,
  /// it moves the window itself before resolution ever runs.
  ///
  /// Returns null (a no-op) unless every explicit guard below holds. On
  /// success, mutates the following break's `syntheticStartMinutes` and
  /// `durationMinutes` in place and returns a record carrying the break plus
  /// its previous values, so `markComplete`'s WR-05 `catch` can restore both
  /// together if the save subsequently fails.
  ({ScheduledChunk chunk, int? previousStart, int previousDuration})?
  _absorbReclaimedTimeIntoNextBreak(ScheduledChunk completed) {
    final schedule = _todaySchedule;
    if (schedule == null) return null;

    // Guard 1: only a work chunk's early completion reclaims break time.
    if (completed.chunkType != ChunkType.work) return null;
    // Guard 2: the completed chunk must itself have a clock position.
    final completedStart = completed.displayStartMinutes;
    if (completedStart == null) return null;

    // Read the clock once through the injectable _now() seam (never
    // DateTime.now() directly), matching resolveNowState's local
    // wall-clock, no-toUtc() convention (FRAME-OF-REFERENCE, now_state.dart).
    final nowDt = _now();
    final nowMinutes = nowDt.hour * 60 + nowDt.minute;

    // Guard 3: never move a break earlier than the work chunk's own start.
    if (nowMinutes < completedStart) return null;
    // Guard 4: genuinely early — completing at/after the scheduled end
    // reclaims nothing.
    if (nowMinutes >= completedStart + completed.durationMinutes) {
      return null;
    }

    // Find the immediately following chunk by CLOCK order, not list order.
    final byClock =
        schedule.chunks.where((c) => c.displayStartMinutes != null).toList()
          ..sort(
            (a, b) => a.displayStartMinutes!.compareTo(b.displayStartMinutes!),
          );
    final idx = byClock.indexOf(completed);
    if (idx == -1 || idx + 1 >= byClock.length) return null;
    final next = byClock[idx + 1];

    // Guard 5: a following chunk exists and is a break.
    if (next.chunkType != ChunkType.shortBreak &&
        next.chunkType != ChunkType.longBreak) {
      return null;
    }
    // Guard 6: the break must be movable — a commitment-anchored chunk is
    // never re-anchored.
    if (next.anchoredStartMinutes != null) return null;
    final breakStart = next.displayStartMinutes;
    if (breakStart == null) return null;

    // Guard 9 (D-31-05): before Phase 31 no UI path could ever set a
    // break's isSkipped, so this guard had nothing to guard. Now that a
    // break can be skipped, absorbing reclaimed time into one would move
    // and extend it out from under its own skipped state — the row would
    // still render skipped (D-31-04) while its persisted start and
    // duration silently changed underneath that rendering, contradicting
    // D-31-03's "mark it skipped and move on."
    if (next.isSkipped) return null;

    // Guard 7: the break's window must not already be open — otherwise
    // there is nothing to move.
    if (nowMinutes >= breakStart) return null;

    // Guard 8: the reclaimed span must be strictly positive.
    final newDuration = (breakStart + next.durationMinutes) - nowMinutes;
    if (newDuration <= 0) return null;

    final previousStart = next.syntheticStartMinutes;
    final previousDuration = next.durationMinutes;
    next.syntheticStartMinutes = nowMinutes;
    next.durationMinutes = newDuration;

    return (
      chunk: next,
      previousStart: previousStart,
      previousDuration: previousDuration,
    );
  }

  /// Marks the chunk with [chunkId] as completed, saves the updated schedule,
  /// and appends a CompletionLog entry.
  Future<void> markComplete(String chunkId) async {
    if (_todaySchedule == null) return;
    final chunk = _todaySchedule!.chunks
        .where((c) => c.id == chunkId)
        .firstOrNull;
    if (chunk == null || chunk.isCompleted) return;

    chunk.isCompleted = true;
    // G-05: absorb reclaimed time into the following break, if eligible,
    // BEFORE the single save below so one write persists both facts.
    final absorbedBreak = _absorbReclaimedTimeIntoNextBreak(chunk);
    try {
      await _repo.save(_todaySchedule!);

      final dateYmd = _todaySchedule!.dateYmd;
      await _logRepo.append(
        CompletionLog(
          chunkId: chunkId,
          goalId: chunk.goalId ?? '',
          commitmentId: chunk.commitmentId,
          dateYmd: dateYmd,
          eventIndex: CompletionEvent.completed.index,
        ),
      );

      // Streak write-back (ENGINE-03): recompute and persist streakCount for
      // habit goals. Wrapped in its own try/catch so a goal-save failure does
      // NOT trigger the outer catch (which reverts the already-committed
      // schedule save and log append). Streak staleness is tolerable; a
      // log/schedule divergence is not (WR-01).
      // Guard: goalId must be a non-empty UUID (commitment chunks have
      // goalId == '' or null; never call getByGoalId('') — T-09-08).
      if (chunk.goalId != null && chunk.goalId!.isNotEmpty) {
        try {
          final goal = await _goalRepo.getById(chunk.goalId!);
          if (goal != null && goal.goalType == GoalType.habit) {
            final due = ScheduleGeneratorService.computeDueWeekdays(
              goal.frequencyPerWeek ?? 7,
            );
            // Fetch logs AFTER appending the completion entry above so the
            // just-appended entry is included in the streak computation.
            final updatedLogs = await _logRepo.getByGoalId(goal.id);
            goal.streakCount = ScheduleGeneratorService.computeStreak(
              goal.id,
              due,
              updatedLogs,
              today: DateTime.parse(_todaySchedule!.dateYmd),
            );
            await _goalRepo.save(goal);
          }
        } catch (_) {
          // Streak is stale until next generation — acceptable.
          // Do not rethrow: the primary writes (schedule + log) succeeded.
        }
      }
    } catch (_) {
      // WR-05: if save or log-append fails, revert the in-memory flag so the
      // schedule, the persisted store, and the completion log do not diverge,
      // then re-throw so the caller can surface feedback.
      // G-05: restore the absorbed break's previous start/duration together
      // with the completion flag, BEFORE re-saving, so an aborted completion
      // leaves the break exactly where it was.
      if (absorbedBreak != null) {
        absorbedBreak.chunk.syntheticStartMinutes = absorbedBreak.previousStart;
        absorbedBreak.chunk.durationMinutes = absorbedBreak.previousDuration;
      }
      chunk.isCompleted = false;
      // Re-persist the reverted state so disk and memory stay in sync.
      // Best-effort: if this also fails we still rethrow the original error.
      try {
        await _repo.save(_todaySchedule!);
      } catch (_) {}
      rethrow;
    } finally {
      // Always reflect the committed in-memory state, even on failure (the
      // revert above), so the UI never shows a partially-applied state.
      notifyListeners();
    }
  }

  /// Marks the chunk with [chunkId] as skipped, saves the updated schedule,
  /// and appends a CompletionLog entry.
  Future<void> markSkipped(String chunkId) async {
    if (_todaySchedule == null) return;
    final chunk = _todaySchedule!.chunks
        .where((c) => c.id == chunkId)
        .firstOrNull;
    if (chunk == null || chunk.isSkipped) return;

    chunk.isSkipped = true;
    try {
      await _repo.save(_todaySchedule!);

      final dateYmd = _todaySchedule!.dateYmd;
      await _logRepo.append(
        CompletionLog(
          chunkId: chunkId,
          goalId: chunk.goalId ?? '',
          commitmentId: chunk.commitmentId,
          dateYmd: dateYmd,
          eventIndex: CompletionEvent.skipped.index,
        ),
      );

      // Streak write-back (ENGINE-03): recompute and persist streakCount for
      // habit goals. A skip on a due day will reset the streak to 0 because
      // computeStreak breaks on the first non-completed due-day log.
      // Wrapped in its own try/catch so a goal-save failure does NOT trigger
      // the outer catch (WR-01). Streak staleness is tolerable; a
      // log/schedule divergence is not.
      if (chunk.goalId != null && chunk.goalId!.isNotEmpty) {
        try {
          final goal = await _goalRepo.getById(chunk.goalId!);
          if (goal != null && goal.goalType == GoalType.habit) {
            final due = ScheduleGeneratorService.computeDueWeekdays(
              goal.frequencyPerWeek ?? 7,
            );
            final updatedLogs = await _logRepo.getByGoalId(goal.id);
            goal.streakCount = ScheduleGeneratorService.computeStreak(
              goal.id,
              due,
              updatedLogs,
              today: DateTime.parse(_todaySchedule!.dateYmd),
            );
            await _goalRepo.save(goal);
          }
        } catch (_) {
          // Streak is stale until next generation — acceptable.
          // Do not rethrow: the primary writes (schedule + log) succeeded.
        }
      }
    } catch (_) {
      // WR-05: revert the in-memory flag on persistence/log failure so state
      // and log stay consistent, then re-throw for caller feedback.
      chunk.isSkipped = false;
      // Re-persist the reverted state so disk and memory stay in sync.
      try {
        await _repo.save(_todaySchedule!);
      } catch (_) {}
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Marks the chunk with [chunkId] as deferred.
  ///
  /// Sets both [isDeferred] and [isSkipped] so the schedule_screen partition
  /// (`!c.isSkipped`) moves the chunk to the skipped section immediately.
  /// CLOSE-02: logs as [CompletionEvent.deferred] (distinct from skipped) so
  /// computeStreak treats this as a "move, not miss" and the generator can
  /// carry the goal into the next morning's schedule via the single-hop look-up.
  Future<void> markDeferred(String chunkId) async {
    if (_todaySchedule == null) return;
    final chunk = _todaySchedule!.chunks
        .where((c) => c.id == chunkId)
        .firstOrNull;
    if (chunk == null || chunk.isDeferred) return;

    chunk.isDeferred = true;
    chunk.isSkipped = true; // drives existing schedule_screen partition
    try {
      await _repo.save(_todaySchedule!);

      final dateYmd = _todaySchedule!.dateYmd;
      await _logRepo.append(
        CompletionLog(
          chunkId: chunkId,
          goalId: chunk.goalId ?? '',
          commitmentId: chunk.commitmentId,
          dateYmd: dateYmd,
          eventIndex:
              CompletionEvent.deferred.index, // CLOSE-02: real deferred event
        ),
      );

      // Streak write-back (ENGINE-03): deferred logs are non-breaking per
      // CLOSE-02; computeStreak now treats deferred dates as "continue without
      // increment" rather than a reset. Wrapped in its own try/catch so a
      // goal-save failure does NOT trigger the outer catch (WR-01).
      // Streak staleness is tolerable; a log/schedule divergence is not.
      if (chunk.goalId != null && chunk.goalId!.isNotEmpty) {
        try {
          final goal = await _goalRepo.getById(chunk.goalId!);
          if (goal != null && goal.goalType == GoalType.habit) {
            final due = ScheduleGeneratorService.computeDueWeekdays(
              goal.frequencyPerWeek ?? 7,
            );
            final updatedLogs = await _logRepo.getByGoalId(goal.id);
            goal.streakCount = ScheduleGeneratorService.computeStreak(
              goal.id,
              due,
              updatedLogs,
              today: DateTime.parse(_todaySchedule!.dateYmd),
            );
            await _goalRepo.save(goal);
          }
        } catch (_) {
          // Streak is stale until next generation — acceptable.
          // Do not rethrow: the primary writes (schedule + log) succeeded.
        }
      }
    } catch (_) {
      // WR-05: revert BOTH flags on persistence/log failure so the schedule
      // partition and the completion log do not diverge, then re-throw.
      chunk.isDeferred = false;
      chunk.isSkipped = false;
      // Re-persist the reverted state so disk and memory stay in sync.
      try {
        await _repo.save(_todaySchedule!);
      } catch (_) {}
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
