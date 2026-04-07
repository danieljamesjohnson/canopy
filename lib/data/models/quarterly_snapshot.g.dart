// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quarterly_snapshot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuarterlySnapshotAdapter extends TypeAdapter<QuarterlySnapshot> {
  @override
  final typeId = 5;

  @override
  QuarterlySnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuarterlySnapshot(
        id: fields[0] as String?,
        periodStartYmd: fields[1] as String,
        periodEndYmd: fields[2] as String,
      )
      ..completedAt = fields[3] as DateTime
      ..goalChunkTotals = (fields[4] as Map).cast<String, int>()
      ..reflectionAnswers = (fields[5] as List).cast<String>()
      ..goalPrioritySnapshot = (fields[6] as Map).cast<String, int>()
      ..archivedGoalIds = (fields[7] as List).cast<String>();
  }

  @override
  void write(BinaryWriter writer, QuarterlySnapshot obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.periodStartYmd)
      ..writeByte(2)
      ..write(obj.periodEndYmd)
      ..writeByte(3)
      ..write(obj.completedAt)
      ..writeByte(4)
      ..write(obj.goalChunkTotals)
      ..writeByte(5)
      ..write(obj.reflectionAnswers)
      ..writeByte(6)
      ..write(obj.goalPrioritySnapshot)
      ..writeByte(7)
      ..write(obj.archivedGoalIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuarterlySnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
