import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'completion_log.g.dart';

const _uuid = Uuid();

/// Append-only event log. Records are never mutated or deleted.
enum CompletionEvent { completed, skipped, deferred }

@HiveType(typeId: 4)
class CompletionLog extends HiveObject {
  CompletionLog({
    String? id,
    required this.chunkId,
    required this.goalId,
    this.commitmentId,
    required this.dateYmd,
    required this.eventIndex,
  }) : id = id ?? _uuid.v4();

  @HiveField(0)
  final String id;

  @HiveField(1)
  String chunkId;

  /// The Goal this log is attributed to, or empty for commitment-block chunks.
  ///
  /// For commitment chunks this is `''` and [commitmentId] carries the
  /// CommitmentBlock id instead. Prefer [attributionId] for aggregation so the
  /// commitment-vs-goal distinction is explicit. Historical records (written
  /// before [commitmentId] existed) stored the commitment id here; the
  /// [attributionId] fallback keeps those resolving to the same key.
  @HiveField(2)
  String goalId;

  /// Date as YYYY-MM-DD string.
  @HiveField(3)
  String dateYmd;

  /// CompletionEvent.index
  @HiveField(4)
  int eventIndex;

  @HiveField(5)
  DateTime recordedAt = DateTime.now().toUtc();

  /// CommitmentBlock id when this log is for a commitment chunk; null otherwise.
  ///
  /// Added so [goalId] no longer carries dual meaning — code can definitively
  /// tell a commitment log from a goal log without inspecting [goalId].
  @HiveField(6)
  String? commitmentId;

  CompletionEvent get event => CompletionEvent.values[eventIndex];

  /// The id this log aggregates under: the commitment block id for commitment
  /// chunks, otherwise the goal id. Use this (not [goalId]) when grouping or
  /// classifying logs for reporting.
  String get attributionId => commitmentId ?? goalId;
}
