// WINDOWS entry 3 / QUESTIONS.md Q-02: AppSettings.eveningReminderEnabled
// (HiveField 7) and eveningReminderMinutes (HiveField 8) arrived in schema
// 4→5 as NON-nullable fields with no `defaultValue:`, so the generated adapter
// cast `fields[7] as bool` / `(fields[8] as num).toInt()` with no null guard.
// A genuinely pre-schema-5 record — fields 7 and 8 physically absent from the
// bytes — crashed on read. The fix adds `defaultValue: false` /
// `defaultValue: 1200`, matching the Dart initializers.
//
// No schema version bump: `defaultValue` changes only how the adapter READS a
// missing field; the on-disk format and the bytes written are identical, and
// this codebase bumps currentSchemaVersion only for field additions or data
// transformations (migrations.dart).
//
// MUTATION PROOF (observed 2026-11-02, reverted): removing
// `defaultValue: false` from HiveField(7), regenerating, and running the
// old-record test below produced a RUNTIME failure, not a compile error:
//
//   type 'Null' is not a subtype of type 'bool' in type cast
//   package:canopy/data/models/app_settings.g.dart 27:44  AppSettingsAdapter.read
//
// The same mutation on HiveField(8) alone (`defaultValue: 1200` removed)
// failed independently with:
//
//   type 'Null' is not a subtype of type 'num' in type cast
//   package:canopy/data/models/app_settings.g.dart 28:45  AppSettingsAdapter.read
//
// Restoring each annotation and regenerating made the test pass again, and
// the model + generated adapter diff returned to exactly this fix.

import 'dart:io';

import 'package:canopy/data/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// Writes AppSettings in the PRE-schema-5 (7-field) shape — HiveFields 7 and
/// 8 are physically ABSENT from the binary (the leading field count is 7 and
/// only fields 0-6 are written), matching a user's on-disk data from before
/// the evening reminder existed.
class _PreSchema5AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final typeId = 6;

  @override
  AppSettings read(BinaryReader reader) =>
      throw UnimplementedError('write-only — only used to produce old bytes');

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.lastMoodSetYmdInt);
  }
}

void main() {
  group('AppSettings evening reminder fields 7/8 — WINDOWS entry 3', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hive_evening_defaults_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    test(
      'a pre-schema-5 (7-field) record with fields 7 and 8 absent reads back '
      'with eveningReminderEnabled=false and eveningReminderMinutes=1200 and '
      'every older field intact — no crash',
      () async {
        const boxName = 'app_settings_pre_schema5_compat';

        Hive.registerAdapter(_PreSchema5AppSettingsAdapter());
        final oldBox = await Hive.openBox<AppSettings>(boxName);
        // Non-default values on the older fields, so "intact" is a real check
        // rather than a coincidence with the constructor defaults.
        final oldSettings = AppSettings()
          ..morningNotificationMinutes = 480
          ..onboardingComplete = true
          ..midDayNudgeEnabled = true
          ..midDayNudgeMinutes = 750
          ..morningNotificationEnabled = false
          ..moodSeedArgb = 0xFF336699
          ..lastMoodSetYmdInt = 20240115
          // Set to NON-default values: the old adapter must not write them, so
          // reading back the defaults proves they came from `defaultValue`,
          // not from bytes on disk.
          ..eveningReminderEnabled = true
          ..eveningReminderMinutes = 1320;
        await oldBox.put('settings', oldSettings);
        await oldBox.close();

        Hive.registerAdapter(AppSettingsAdapter(), override: true);
        final reopened = await Hive.openBox<AppSettings>(boxName);
        final readBack = reopened.get('settings');

        expect(readBack, isNotNull);
        expect(readBack!.eveningReminderEnabled, isFalse);
        expect(readBack.eveningReminderMinutes, equals(1200));
        expect(readBack.morningNotificationMinutes, equals(480));
        expect(readBack.onboardingComplete, isTrue);
        expect(readBack.midDayNudgeEnabled, isTrue);
        expect(readBack.midDayNudgeMinutes, equals(750));
        expect(readBack.morningNotificationEnabled, isFalse);
        expect(readBack.moodSeedArgb, equals(0xFF336699));
        expect(readBack.lastMoodSetYmdInt, equals(20240115));

        await reopened.close();
      },
    );

    test('the defaults match the model constructor defaults', () {
      final fresh = AppSettings();
      expect(fresh.eveningReminderEnabled, isFalse);
      expect(fresh.eveningReminderMinutes, equals(1200));
    });

    test(
      'a current record with set values round-trips fields 7 and 8',
      () async {
        const boxName = 'app_settings_evening_round_trip';
        Hive.registerAdapter(AppSettingsAdapter(), override: true);

        final box = await Hive.openBox<AppSettings>(boxName);
        await box.put(
          'settings',
          AppSettings()
            ..eveningReminderEnabled = true
            ..eveningReminderMinutes = 1320,
        );
        await box.close();

        final reopened = await Hive.openBox<AppSettings>(boxName);
        final readBack = reopened.get('settings');
        expect(readBack!.eveningReminderEnabled, isTrue);
        expect(readBack.eveningReminderMinutes, equals(1320));
        await reopened.close();
      },
    );
  });
}
