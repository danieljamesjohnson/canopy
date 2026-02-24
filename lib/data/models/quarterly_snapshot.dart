import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'quarterly_snapshot.g.dart';

const _uuid = Uuid();

/// Append-only record of a completed quarterly review. Never overwritten.
@HiveType(typeId: 5)
class QuarterlySnapshot extends HiveObject {
  QuarterlySnapshot({
    String? id,
    required this.periodStartYmd,
    required this.periodEndYmd,
  }) : id = id ?? _uuid.v4();

  @HiveField(0)
  final String id;

  @HiveField(1)
  String periodStartYmd;

  @HiveField(2)
  String periodEndYmd;

  @HiveField(3)
  DateTime completedAt = DateTime.now().toUtc();

  /// Stub: rich data added in Phase 5.
  @HiveField(4)
  Map<String, int> goalChunkTotals = {};

  @HiveField(5)
  List<String> reflectionAnswers = [];
}
