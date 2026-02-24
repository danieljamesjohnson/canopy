// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyScheduleAdapter extends TypeAdapter<DailySchedule> {
  @override
  final typeId = 2;

  @override
  DailySchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailySchedule(
      id: fields[0] as String?,
      dateYmd: fields[1] as String,
      moodIndex: (fields[2] as num).toInt(),
      chunks: (fields[3] as List).cast<ScheduledChunk>(),
    )..generatedAt = fields[4] as DateTime;
  }

  @override
  void write(BinaryWriter writer, DailySchedule obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dateYmd)
      ..writeByte(2)
      ..write(obj.moodIndex)
      ..writeByte(3)
      ..write(obj.chunks)
      ..writeByte(4)
      ..write(obj.generatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
