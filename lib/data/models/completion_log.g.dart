// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompletionLogAdapter extends TypeAdapter<CompletionLog> {
  @override
  final typeId = 4;

  @override
  CompletionLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CompletionLog(
      id: fields[0] as String?,
      chunkId: fields[1] as String,
      goalId: fields[2] as String,
      dateYmd: fields[3] as String,
      eventIndex: (fields[4] as num).toInt(),
    )..recordedAt = fields[5] as DateTime;
  }

  @override
  void write(BinaryWriter writer, CompletionLog obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.chunkId)
      ..writeByte(2)
      ..write(obj.goalId)
      ..writeByte(3)
      ..write(obj.dateYmd)
      ..writeByte(4)
      ..write(obj.eventIndex)
      ..writeByte(5)
      ..write(obj.recordedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletionLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
