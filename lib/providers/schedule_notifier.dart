import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/commitment_block.dart';
import '../data/models/completion_log.dart';
import '../data/models/daily_schedule.dart';
import '../data/models/goal.dart';
import '../data/repositories/completion_log_repository.dart';
import '../data/repositories/daily_schedule_repository.dart';
import '../data/repositories/hive_completion_log_repository.dart';
import '../data/repositories/hive_daily_schedule_repository.dart';
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
  })  : _now = now,
        _repo = repo ?? HiveDailyScheduleRepository(),
        _logRepo = logRepo ?? HiveCompletionLogRepository();

  final DateTime Function() _now;
  final DailyScheduleRepository _repo;
  final CompletionLogRepository _logRepo;
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
    _loading = true;
    _todaySchedule = await _repo.getTodaysSchedule();
    _loading = false;
    // LOOP-02: clear stale in-memory schedule if it belongs to a prior day.
    _resetIfDayChanged();
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
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
  }) async {
    final now = _now();
    final date = DateTime(now.year, now.month, now.day); // midnight local
    final dateYmd = DateFormat('yyyy-MM-dd').format(now);

    final chunks = _generator.generate(
      goals: goals,
      blocks: blocks,
      moodIndex: moodIndex,
      date: date,
    );

    // Silent replace: delete existing schedule for today if any.
    final existing = await _repo.getByDate(dateYmd);
    if (existing != null) await _repo.delete(existing.id);

    final schedule = DailySchedule(
      dateYmd: dateYmd,
      moodIndex: moodIndex,
      chunks: chunks,
    );
    // Set generatedAt explicitly (field-level default runs at class parse time, not instantiation).
    schedule.generatedAt = DateTime.now().toUtc();

    await _repo.save(schedule);
    _todaySchedule = schedule;
    notifyListeners();
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
    await _repo.save(_todaySchedule!);

    final dateYmd = _todaySchedule!.dateYmd;
    await _logRepo.append(
      CompletionLog(
        chunkId: chunkId,
        goalId: chunk.goalId ?? '',
        dateYmd: dateYmd,
        eventIndex: CompletionEvent.completed.index,
      ),
    );

    notifyListeners();
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
    await _repo.save(_todaySchedule!);

    final dateYmd = _todaySchedule!.dateYmd;
    await _logRepo.append(
      CompletionLog(
        chunkId: chunkId,
        goalId: chunk.goalId ?? '',
        dateYmd: dateYmd,
        eventIndex: CompletionEvent.skipped.index,
      ),
    );

    notifyListeners();
  }

  /// Marks the chunk with [chunkId] as deferred (Phase 8: visual skip only;
  /// full cross-day carryover wired in Phase 10 CLOSE-02).
  ///
  /// Sets both [isDeferred] and [isSkipped] so the schedule_screen partition
  /// (`!c.isSkipped`) moves the chunk to the skipped section immediately.
  /// Logs as [CompletionEvent.skipped] in Phase 8; a dedicated deferred event
  /// is added in Phase 10.
  Future<void> markDeferred(String chunkId) async {
    if (_todaySchedule == null) return;
    final chunk = _todaySchedule!.chunks
        .where((c) => c.id == chunkId)
        .firstOrNull;
    if (chunk == null || chunk.isDeferred) return;

    chunk.isDeferred = true;
    chunk.isSkipped = true; // drives existing schedule_screen partition
    await _repo.save(_todaySchedule!);

    final dateYmd = _todaySchedule!.dateYmd;
    await _logRepo.append(
      CompletionLog(
        chunkId: chunkId,
        goalId: chunk.goalId ?? '',
        dateYmd: dateYmd,
        eventIndex: CompletionEvent.skipped.index, // Phase 8: log as skipped
      ),
    );

    notifyListeners();
  }
}
