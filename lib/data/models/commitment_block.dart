import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'commitment_block.g.dart';

const _uuid = Uuid();

@HiveType(typeId: 1)
class CommitmentBlock extends HiveObject {
  CommitmentBlock({
    String? id,
    required this.name,
    required this.daysOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    this.date,
  }) : id = id ?? _uuid.v4();

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  /// List of weekday integers: 1=Monday ... 7=Sunday (ISO 8601)
  @HiveField(2)
  List<int> daysOfWeek;

  /// Start time as minutes from midnight UTC (e.g. 540 = 9:00am)
  @HiveField(3)
  int startMinutes;

  /// End time as minutes from midnight UTC (e.g. 1020 = 5:00pm)
  @HiveField(4)
  int endMinutes;

  @HiveField(5)
  String color = '#FF5722'; // default deep orange

  /// Optional specific calendar date for a ONE-OFF commitment (e.g. a dentist
  /// appointment this Thursday). When non-null the block is anchored only on
  /// that single day and [daysOfWeek] is ignored; when null the block is a
  /// recurring weekly commitment driven by [daysOfWeek]. Additive field — old
  /// records deserialize with date == null and stay recurring.
  @HiveField(6)
  DateTime? date;

  /// True when this is a single-date commitment rather than a recurring one.
  bool get isOneOff => date != null;
}
