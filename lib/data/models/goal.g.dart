// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoalAdapter extends TypeAdapter<Goal> {
  @override
  final typeId = 0;

  @override
  Goal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Goal(
      id: fields[0] as String?,
      name: fields[1] as String,
      goalTypeIndex: (fields[2] as num).toInt(),
      color: fields[4] as String?,
      priorityWeight: (fields[5] as num?)?.toDouble(),
      sortOrder: fields[6] == null ? 0 : (fields[6] as num).toInt(),
      weeklyHourBudget: (fields[7] as num?)?.toDouble(),
      deadline: fields[8] as DateTime?,
      outcomeDescription: fields[9] as String?,
      frequencyPerWeek: (fields[10] as num?)?.toInt(),
      streakCount: fields[11] == null ? 0 : (fields[11] as num).toInt(),
    )..isArchived = fields[3] as bool;
  }

  @override
  void write(BinaryWriter writer, Goal obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.goalTypeIndex)
      ..writeByte(3)
      ..write(obj.isArchived)
      ..writeByte(4)
      ..write(obj.color)
      ..writeByte(5)
      ..write(obj.priorityWeight)
      ..writeByte(6)
      ..write(obj.sortOrder)
      ..writeByte(7)
      ..write(obj.weeklyHourBudget)
      ..writeByte(8)
      ..write(obj.deadline)
      ..writeByte(9)
      ..write(obj.outcomeDescription)
      ..writeByte(10)
      ..write(obj.frequencyPerWeek)
      ..writeByte(11)
      ..write(obj.streakCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
