import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import 'energy_valence.dart';

part 'goal.g.dart';

const _uuid = Uuid();

// ORDER IS FIXED — GoalType stored as int index; never reorder enum values.
// @HiveField 0: id (String)
// @HiveField 1: name (String)
// @HiveField 2: goalTypeIndex (int)
// @HiveField 3: isArchived (bool)
// @HiveField 4: color (String?)
// @HiveField 5: priorityWeight (double?)
// @HiveField 6: sortOrder (int)
// @HiveField 7: weeklyHourBudget (double?)
// @HiveField 8: deadline (DateTime?)
// @HiveField 9: outcomeDescription (String?)
// @HiveField 10: frequencyPerWeek (int?)
// @HiveField 11: streakCount (int)
// @HiveField 12: energyValenceIndex (int?) — Phase 19
// @HiveField 13: emojiTag (String?) — Phase 19

/// Internal goal type — never shown in UI. UI uses plain-language descriptions.
enum GoalType { timeTarget, outcome, habit }

@HiveType(typeId: 0)
class Goal extends HiveObject {
  Goal({
    String? id,
    required this.name,
    required this.goalTypeIndex,
    this.color,
    this.priorityWeight,
    this.sortOrder = 0,
    this.weeklyHourBudget,
    this.deadline,
    this.outcomeDescription,
    this.frequencyPerWeek,
    this.streakCount = 0,
    this.energyValenceIndex,
    this.emojiTag,
  }) : id = id ?? _uuid.v4();

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  /// GoalType.index — store enum as int, never as string.
  @HiveField(2)
  int goalTypeIndex;

  @HiveField(3)
  bool isArchived = false;

  GoalType get goalType => GoalType.values[goalTypeIndex];

  @HiveField(4)
  String? color; // hex string e.g. '#4CAF50'; null = auto-assign from palette

  @HiveField(5)
  double? priorityWeight; // 0.0–1.0 scheduling weight; null defaults to 0.5 in notifier

  @HiveField(6)
  int sortOrder = 0; // position within type group for display ordering

  // Time-target specific (null for other GoalTypes)
  @HiveField(7)
  double? weeklyHourBudget;

  // Outcome specific (null for other GoalTypes)
  @HiveField(8)
  DateTime? deadline;

  @HiveField(9)
  String? outcomeDescription;

  // Habit specific (null for other GoalTypes)
  @HiveField(10)
  int? frequencyPerWeek; // sessions per week; null defaults to 7 (daily) in notifier

  @HiveField(11)
  int streakCount = 0; // updated by Phase 4; read-only in Phase 2

  // Phase 19: Energy valence. Stored as int index; getter converts.
  // neutral = 0 so existing records without this field read correctly.
  @HiveField(12)
  int? energyValenceIndex;

  // Phase 19: Optional emoji tag (single Unicode character). null = no tag.
  @HiveField(13)
  String? emojiTag;

  EnergyValence get energyValence {
    final idx = energyValenceIndex ?? 0;
    if (idx < 0 || idx >= EnergyValence.values.length) {
      return EnergyValence
          .neutral; // safe default for out-of-range index (WR-01)
    }
    return EnergyValence.values[idx];
  }
}
