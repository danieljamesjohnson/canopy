import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import 'scheduled_chunk.dart';

part 'daily_schedule.g.dart';

const _uuid = Uuid();

@HiveType(typeId: 2)
class DailySchedule extends HiveObject {
  DailySchedule({
    String? id,
    required this.dateYmd,
    required this.moodIndex,
    required this.chunks,
  }) : id = id ?? _uuid.v4();

  @HiveField(0)
  final String id;

  /// Date as YYYY-MM-DD string. One schedule per calendar day.
  @HiveField(1)
  String dateYmd;

  /// Mood 1–5 selected at morning check-in.
  @HiveField(2)
  int moodIndex;

  /// Ordered list of scheduled chunks including breaks.
  @HiveField(3)
  List<ScheduledChunk> chunks;

  @HiveField(4)
  DateTime generatedAt = DateTime.now().toUtc();
}
