import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'goal.g.dart';

const _uuid = Uuid();

/// Internal goal type — never shown in UI. UI uses plain-language descriptions.
enum GoalType { timeTarget, outcome, habit }

@HiveType(typeId: 0)
class Goal extends HiveObject {
  Goal({
    String? id,
    required this.name,
    required this.goalTypeIndex,
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
}
