import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'scheduled_chunk.g.dart';

const _uuid = Uuid();

/// Type of a scheduled chunk. Break types have null goalId.
enum ChunkType { work, shortBreak, longBreak }

@HiveType(typeId: 3)
class ScheduledChunk extends HiveObject {
  ScheduledChunk({
    String? id,
    required this.chunkTypeIndex,
    this.goalId,
    required this.durationMinutes,
    this.anchoredStartMinutes,
    this.rationale = '',
  }) : id = id ?? _uuid.v4();

  @HiveField(0)
  final String id;

  /// ChunkType.index
  @HiveField(1)
  int chunkTypeIndex;

  /// null for break chunks
  @HiveField(2)
  String? goalId;

  @HiveField(3)
  int durationMinutes;

  /// Set only when anchored to a CommitmentBlock. Minutes from midnight UTC.
  @HiveField(4)
  int? anchoredStartMinutes;

  /// One-line explanation of why this chunk was scheduled.
  @HiveField(5)
  String rationale;

  @HiveField(6)
  bool isCompleted = false;

  @HiveField(7)
  bool isSkipped = false;

  @HiveField(8)
  bool isDeferred = false;

  // Synthetic start time assigned during generation; NOT stored in Hive.
  // Used as sort key for discretionary chunks in ScheduleGeneratorService.
  int? syntheticStartMinutes;

  // Duration (minutes) of the break reserved AFTER this discretionary work
  // chunk during the packing pass; NOT stored in Hive. Single source of truth
  // for the long-break cadence so the break emitted in STEP C matches the slot
  // room reserved during packing (WR-01). null = no break reserved.
  int? reservedBreakMinutes;

  ChunkType get chunkType => ChunkType.values[chunkTypeIndex];
}
