import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_ce/hive.dart';

import '../data/models/app_settings.dart';
import '../data/models/commitment_block.dart';
import '../data/models/completion_log.dart';
import '../data/models/daily_schedule.dart';
import '../data/models/goal.dart';
import '../data/models/quarterly_snapshot.dart';
import '../data/models/scheduled_chunk.dart';
import '../data/repositories/hive_completion_log_repository.dart';
import '../data/repositories/hive_goal_repository.dart';
import '../data/repositories/hive_quarterly_snapshot_repository.dart';

/// Bundled scenario file path. Declared in pubspec.yaml under flutter > assets.
const String _kScenarioAssetPath = 'dev_data/typical_quarter.json';

/// Parsed payload — held in memory before being written to Hive.
class DevIngestData {
  DevIngestData({
    required this.goals,
    required this.completionLogs,
    required this.snapshots,
  });
  final List<Goal> goals;
  final List<CompletionLog> completionLogs;
  final List<QuarterlySnapshot> snapshots;
}

/// Result type for the parse step. Never throws to caller; surfaces errors via [error].
class DevIngestParseResult {
  DevIngestParseResult.success(this.data) : error = null;
  DevIngestParseResult.failure(this.error) : data = null;
  final DevIngestData? data;
  final Object? error;
  bool get success => data != null;
}

/// Result type for the ingest step. Reports counts on success and reason on failure.
class DevIngestResult {
  DevIngestResult.success({
    required this.goalsLoaded,
    required this.logsLoaded,
    required this.snapshotsLoaded,
  }) : success = true,
       error = null;
  DevIngestResult.failure(Object this.error)
    : success = false,
      goalsLoaded = 0,
      logsLoaded = 0,
      snapshotsLoaded = 0;
  final bool success;
  final Object? error;
  final int goalsLoaded;
  final int logsLoaded;
  final int snapshotsLoaded;
}

/// Result type for the clear step.
class DevClearResult {
  DevClearResult.success({
    required this.goalsCleared,
    required this.logsCleared,
    required this.snapshotsCleared,
  }) : success = true,
       error = null;
  DevClearResult.failure(Object this.error)
    : success = false,
      goalsCleared = 0,
      logsCleared = 0,
      snapshotsCleared = 0;
  final bool success;
  final Object? error;
  final int goalsCleared;
  final int logsCleared;
  final int snapshotsCleared;
}

/// Dev-only utility for seeding and wiping Hive data during UAT.
///
/// All public methods are static. Callers MUST gate invocation behind
/// [kDebugMode] — this class does not enforce that itself, since the
/// parser is also useful in tests.
class DevDataLoader {
  DevDataLoader._();

  /// Parses a JSON string into in-memory entities. Never throws — wraps
  /// [jsonDecode] and shape validation in try/catch and returns
  /// [DevIngestParseResult.failure] on any error.
  static DevIngestParseResult parseJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        return DevIngestParseResult.failure(
          'Top-level JSON must be an object, got ${decoded.runtimeType}',
        );
      }
      final goalsRaw = decoded['goals'];
      final logsRaw = decoded['completion_logs'];
      final snapshotsRaw = decoded['quarterly_snapshots'];
      if (goalsRaw is! List) {
        return DevIngestParseResult.failure(
          'goals must be a JSON array, got ${goalsRaw.runtimeType}',
        );
      }
      if (logsRaw is! List) {
        return DevIngestParseResult.failure(
          'completion_logs must be a JSON array, got ${logsRaw.runtimeType}',
        );
      }
      if (snapshotsRaw is! List) {
        return DevIngestParseResult.failure(
          'quarterly_snapshots must be a JSON array, got ${snapshotsRaw.runtimeType}',
        );
      }
      final goals = goalsRaw
          .map((e) => _goalFromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      final logs = logsRaw
          .map((e) => _logFromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      final snapshots = snapshotsRaw
          .map((e) => _snapshotFromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      return DevIngestParseResult.success(
        DevIngestData(goals: goals, completionLogs: logs, snapshots: snapshots),
      );
    } catch (e) {
      return DevIngestParseResult.failure(e);
    }
  }

  static Goal _goalFromJson(Map<String, dynamic> json) {
    final goal = Goal(
      id: json['id'] as String?,
      name: json['name'] as String,
      goalTypeIndex: json['goalTypeIndex'] as int,
      color: json['color'] as String?,
      priorityWeight: (json['priorityWeight'] as num?)?.toDouble(),
      sortOrder: (json['sortOrder'] as int?) ?? 0,
      weeklyHourBudget: (json['weeklyHourBudget'] as num?)?.toDouble(),
      deadline: json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
      outcomeDescription: json['outcomeDescription'] as String?,
      frequencyPerWeek: json['frequencyPerWeek'] as int?,
      streakCount: (json['streakCount'] as int?) ?? 0,
    );
    if (json['isArchived'] == true) {
      goal.isArchived = true;
    }
    return goal;
  }

  static CompletionLog _logFromJson(Map<String, dynamic> json) {
    final log = CompletionLog(
      id: json['id'] as String?,
      chunkId: json['chunkId'] as String,
      goalId: json['goalId'] as String,
      commitmentId: json['commitmentId'] as String?,
      dateYmd: json['dateYmd'] as String,
      eventIndex: json['eventIndex'] as int,
    );
    if (json['recordedAt'] != null) {
      log.recordedAt = DateTime.parse(json['recordedAt'] as String);
    }
    return log;
  }

  static QuarterlySnapshot _snapshotFromJson(Map<String, dynamic> json) {
    final snap = QuarterlySnapshot(
      id: json['id'] as String?,
      periodStartYmd: json['periodStartYmd'] as String,
      periodEndYmd: json['periodEndYmd'] as String,
    );
    if (json['completedAt'] != null) {
      snap.completedAt = DateTime.parse(json['completedAt'] as String);
    }
    if (json['goalChunkTotals'] is Map) {
      snap.goalChunkTotals = Map<String, int>.from(
        (json['goalChunkTotals'] as Map).map(
          (k, v) => MapEntry(k as String, v as int),
        ),
      );
    }
    if (json['reflectionAnswers'] is List) {
      snap.reflectionAnswers = List<String>.from(
        json['reflectionAnswers'] as List,
      );
    }
    if (json['goalPrioritySnapshot'] is Map) {
      snap.goalPrioritySnapshot = Map<String, int>.from(
        (json['goalPrioritySnapshot'] as Map).map(
          (k, v) => MapEntry(k as String, v as int),
        ),
      );
    }
    if (json['archivedGoalIds'] is List) {
      snap.archivedGoalIds = List<String>.from(json['archivedGoalIds'] as List);
    }
    return snap;
  }

  /// Reads the bundled scenario file, parses it, and writes all entities to
  /// Hive via the existing repositories. Additive — does not clear existing
  /// data first. Re-running [ingest] WILL create duplicate entries (by design;
  /// callers should use [clearAll] first if they want a clean slate).
  ///
  /// Never throws — surfaces any failure via [DevIngestResult.failure].
  static Future<DevIngestResult> ingest() async {
    try {
      final raw = await rootBundle.loadString(_kScenarioAssetPath);
      final parsed = parseJson(raw);
      if (!parsed.success) {
        return DevIngestResult.failure(parsed.error ?? 'unknown parse error');
      }
      final data = parsed.data!;
      final goalRepo = HiveGoalRepository();
      final logRepo = HiveCompletionLogRepository();
      final snapRepo = HiveQuarterlySnapshotRepository();
      for (final goal in data.goals) {
        await goalRepo.save(goal);
      }
      for (final log in data.completionLogs) {
        await logRepo.append(log);
      }
      for (final snap in data.snapshots) {
        await snapRepo.append(snap);
      }
      return DevIngestResult.success(
        goalsLoaded: data.goals.length,
        logsLoaded: data.completionLogs.length,
        snapshotsLoaded: data.snapshots.length,
      );
    } catch (e) {
      return DevIngestResult.failure(e);
    }
  }

  /// Wipes goals, completion_logs, and quarterly_snapshots boxes. Does NOT
  /// touch settings, daily schedules, scheduled chunks, or commitment blocks.
  /// Uses Hive.box(...).clear() directly because the append-only repositories
  /// deliberately do not expose a clear API.
  ///
  /// Never throws — surfaces any failure via [DevClearResult.failure].
  static Future<DevClearResult> clearAll() async {
    try {
      final goalsBox = Hive.box<Goal>('goals');
      final logsBox = Hive.box<CompletionLog>('completion_logs');
      final snapshotsBox = Hive.box<QuarterlySnapshot>('quarterly_snapshots');
      final goalsCleared = goalsBox.length;
      final logsCleared = logsBox.length;
      final snapshotsCleared = snapshotsBox.length;
      await goalsBox.clear();
      await logsBox.clear();
      await snapshotsBox.clear();
      return DevClearResult.success(
        goalsCleared: goalsCleared,
        logsCleared: logsCleared,
        snapshotsCleared: snapshotsCleared,
      );
    } catch (e) {
      return DevClearResult.failure(e);
    }
  }

  /// Clears only today's generated plan: the daily_schedules and
  /// scheduled_chunks boxes. Goals, commitments, logs, snapshots, and settings
  /// are untouched — so the next morning check-in regenerates from scratch
  /// against the SAME goals. Handy for iterating on the schedule generator
  /// without rebuilding the goal set.
  ///
  /// Never throws — surfaces any failure via [DevResetResult.failure].
  static Future<DevResetResult> resetTodaySchedule() async {
    try {
      const names = ['daily_schedules', 'scheduled_chunks'];
      final schedulesBox = Hive.box<DailySchedule>('daily_schedules');
      final chunksBox = Hive.box<ScheduledChunk>('scheduled_chunks');
      final cleared = schedulesBox.length + chunksBox.length;
      await schedulesBox.clear();
      await chunksBox.clear();
      return DevResetResult.success(
        boxesCleared: names.length,
        recordsCleared: cleared,
      );
    } catch (e) {
      return DevResetResult.failure(e);
    }
  }

  /// Factory reset: wipes ALL seven Hive boxes — including app_settings (the
  /// onboarding flag) — returning the app to a genuine first-launch state.
  /// After this completes, callers must reload the in-memory notifiers and
  /// route to onboarding (the boxes are emptied, but the providers built at
  /// startup still hold the old data until reloaded).
  ///
  /// Never throws — surfaces any failure via [DevResetResult.failure].
  static Future<DevResetResult> factoryReset() async {
    try {
      final boxes = <Box>[
        Hive.box<Goal>('goals'),
        Hive.box<CommitmentBlock>('commitment_blocks'),
        Hive.box<DailySchedule>('daily_schedules'),
        Hive.box<ScheduledChunk>('scheduled_chunks'),
        Hive.box<CompletionLog>('completion_logs'),
        Hive.box<QuarterlySnapshot>('quarterly_snapshots'),
        Hive.box<AppSettings>('app_settings'),
      ];
      int recordsCleared = 0;
      for (final box in boxes) {
        recordsCleared += box.length;
        await box.clear();
      }
      return DevResetResult.success(
        boxesCleared: boxes.length,
        recordsCleared: recordsCleared,
      );
    } catch (e) {
      return DevResetResult.failure(e);
    }
  }
}

/// Result type for the box-wipe reset helpers ([resetTodaySchedule],
/// [factoryReset]).
class DevResetResult {
  DevResetResult.success({
    required this.boxesCleared,
    required this.recordsCleared,
  }) : success = true,
       error = null;
  DevResetResult.failure(Object this.error)
    : success = false,
      boxesCleared = 0,
      recordsCleared = 0;
  final bool success;
  final Object? error;
  final int boxesCleared;
  final int recordsCleared;
}
