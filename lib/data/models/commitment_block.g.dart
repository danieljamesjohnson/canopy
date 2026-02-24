// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commitment_block.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CommitmentBlockAdapter extends TypeAdapter<CommitmentBlock> {
  @override
  final typeId = 1;

  @override
  CommitmentBlock read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CommitmentBlock(
      id: fields[0] as String?,
      name: fields[1] as String,
      daysOfWeek: (fields[2] as List).cast<int>(),
      startMinutes: (fields[3] as num).toInt(),
      endMinutes: (fields[4] as num).toInt(),
    )..color = fields[5] as String;
  }

  @override
  void write(BinaryWriter writer, CommitmentBlock obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.daysOfWeek)
      ..writeByte(3)
      ..write(obj.startMinutes)
      ..writeByte(4)
      ..write(obj.endMinutes)
      ..writeByte(5)
      ..write(obj.color);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommitmentBlockAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
