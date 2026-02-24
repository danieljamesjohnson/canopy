// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_chunk.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduledChunkAdapter extends TypeAdapter<ScheduledChunk> {
  @override
  final typeId = 3;

  @override
  ScheduledChunk read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduledChunk(
        id: fields[0] as String?,
        chunkTypeIndex: (fields[1] as num).toInt(),
        goalId: fields[2] as String?,
        durationMinutes: (fields[3] as num).toInt(),
        anchoredStartMinutes: (fields[4] as num?)?.toInt(),
        rationale: fields[5] == null ? '' : fields[5] as String,
      )
      ..isCompleted = fields[6] as bool
      ..isSkipped = fields[7] as bool;
  }

  @override
  void write(BinaryWriter writer, ScheduledChunk obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.chunkTypeIndex)
      ..writeByte(2)
      ..write(obj.goalId)
      ..writeByte(3)
      ..write(obj.durationMinutes)
      ..writeByte(4)
      ..write(obj.anchoredStartMinutes)
      ..writeByte(5)
      ..write(obj.rationale)
      ..writeByte(6)
      ..write(obj.isCompleted)
      ..writeByte(7)
      ..write(obj.isSkipped);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledChunkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
