// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restorative_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RestorativeItemAdapter extends TypeAdapter<RestorativeItem> {
  @override
  final typeId = 7;

  @override
  RestorativeItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RestorativeItem(
      id: fields[0] as String?,
      name: fields[1] as String,
      emojiTag: fields[2] as String?,
      sortOrder: fields[3] == null ? 0 : (fields[3] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, RestorativeItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.emojiTag)
      ..writeByte(3)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestorativeItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
