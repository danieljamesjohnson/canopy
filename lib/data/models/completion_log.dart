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
    required this.dateYmd,
    required this.eventIndex,
  }) : id = id ?? _uuid.v4();

  @HiveField(0)
  final String id;

  @HiveField(1)
  String chunkId;

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

  CompletionEvent get event => CompletionEvent.values[eventIndex];
}
