// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final typeId = 6;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings()
      ..morningNotificationMinutes = (fields[0] as num).toInt()
      ..onboardingComplete = fields[1] as bool
      ..midDayNudgeEnabled = fields[2] as bool
      ..midDayNudgeMinutes = (fields[3] as num).toInt()
      ..morningNotificationEnabled = fields[4] as bool
      ..moodSeedArgb = (fields[5] as num?)?.toInt()
      ..lastMoodSetYmdInt = (fields[6] as num?)?.toInt()
      ..eveningReminderEnabled = fields[7] as bool
      ..eveningReminderMinutes = (fields[8] as num).toInt();
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.morningNotificationMinutes)
      ..writeByte(1)
      ..write(obj.onboardingComplete)
      ..writeByte(2)
      ..write(obj.midDayNudgeEnabled)
      ..writeByte(3)
      ..write(obj.midDayNudgeMinutes)
      ..writeByte(4)
      ..write(obj.morningNotificationEnabled)
      ..writeByte(5)
      ..write(obj.moodSeedArgb)
      ..writeByte(6)
      ..write(obj.lastMoodSetYmdInt)
      ..writeByte(7)
      ..write(obj.eveningReminderEnabled)
      ..writeByte(8)
      ..write(obj.eveningReminderMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
