// Hive round-trip tests for the Phase 36 plan 36-13 schema 13→14 bump:
// AppSettings gains lastCalendarSyncSkippedTitles (HiveField 16) and
// lastCalendarSyncSkippedReasons (HiveField 17) — WINDOWS entry 10. See
// migration_schema_test.dart for the schema-constant assertions
// (currentSchemaVersion == 14); this file is the Hive I/O half.
//
// MUTATION PROOF (observed 2026-11-02, reverted): removing
// `defaultValue: <String>[]` from HiveField(16), regenerating, and running
// the old-record test below produced a RUNTIME failure, not a compile error:
//
//   type 'Null' is not a subtype of type 'List<dynamic>' in type cast
//   package:canopy/data/models/app_settings.g.dart 38:53  AppSettingsAdapter.read
//
// Restoring the annotation and regenerating made the test pass again, and
// `git diff HEAD -- lib/data/models/app_settings.dart
// lib/data/models/app_settings.g.dart` was empty afterwards. This is the
// Q-02 defect class: the Hive reader does NOT supply a default for a
// non-nullable field on its own.

import 'dart:io';

import 'package:canopy/data/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// Writes AppSettings using the PRE-36-13 (schema 13, 16-field) shape —
/// HiveFields 16 and 17 are physically ABSENT from the binary (the leading
/// field count is 16 and only fields 0-15 are written), matching an existing
/// user's real on-disk data at the moment of this upgrade.
class _OldAppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final typeId = 6;

  @override
  AppSettings read(BinaryReader reader) =>
      throw UnimplementedError('write-only — only used to produce old bytes');

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(16)
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
      ..write(obj.eveningReminderMinutes)
      ..writeByte(9)
      ..write(obj.selectedCalendarIds)
      ..writeByte(10)
      ..write(obj.icsUrls)
      ..writeByte(11)
      ..write(obj.lastCalendarSyncAt)
      ..writeByte(12)
      ..write(obj.googleAccessToken)
      ..writeByte(13)
      ..write(obj.googleRefreshToken)
      ..writeByte(14)
      ..write(obj.googleAccessTokenExpiresAt)
      ..writeByte(15)
      ..write(obj.googleReconnectNeeded);
  }
}

void main() {
  group('AppSettings schema 13→14 — last-sync skipped events (entry 10)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hive_schema14_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    test(
      'an old (schema 13, 16-field) AppSettings record reads back under the '
      'new (18-field) adapter with both skipped lists empty and every older '
      'field intact — no crash',
      () async {
        const boxName = 'app_settings_schema14_old_compat';

        Hive.registerAdapter(_OldAppSettingsAdapter());
        final oldBox = await Hive.openBox<AppSettings>(boxName);
        final oldSettings = AppSettings()
          ..morningNotificationMinutes = 480
          ..selectedCalendarIds = ['cal-1']
          ..icsUrls = ['https://example.com/a.ics']
          ..lastCalendarSyncAt = DateTime.utc(2026, 11, 1, 8)
          ..googleAccessToken = 'tok'
          ..googleReconnectNeeded = true;
        await oldBox.put('settings', oldSettings);
        await oldBox.close();

        // Swap in the current (new) adapter and reopen the same box — this
        // is the schema 13→14 upgrade.
        Hive.registerAdapter(AppSettingsAdapter(), override: true);
        final reopened = await Hive.openBox<AppSettings>(boxName);
        final readBack = reopened.get('settings');

        expect(readBack, isNotNull);
        expect(readBack!.lastCalendarSyncSkippedTitles, isEmpty);
        expect(readBack.lastCalendarSyncSkippedReasons, isEmpty);
        expect(readBack.morningNotificationMinutes, equals(480));
        expect(readBack.selectedCalendarIds, equals(['cal-1']));
        expect(readBack.icsUrls, equals(['https://example.com/a.ics']));
        expect(
          readBack.lastCalendarSyncAt,
          equals(DateTime.utc(2026, 11, 1, 8)),
        );
        expect(readBack.googleAccessToken, equals('tok'));
        expect(readBack.googleReconnectNeeded, isTrue);

        await reopened.close();
      },
    );

    test(
      'a new record with two skipped titles and reasons round-trips '
      'through Hive',
      () async {
        const boxName = 'app_settings_schema14_round_trip';
        Hive.registerAdapter(AppSettingsAdapter(), override: true);

        final box = await Hive.openBox<AppSettings>(boxName);
        final settings = AppSettings()
          ..lastCalendarSyncSkippedTitles = ['Vacation', 'Standup']
          ..lastCalendarSyncSkippedReasons = ['allDay', 'tooShort'];
        await box.put('settings', settings);
        await box.close();

        final reopened = await Hive.openBox<AppSettings>(boxName);
        final readBack = reopened.get('settings');

        expect(readBack, isNotNull);
        expect(
          readBack!.lastCalendarSyncSkippedTitles,
          equals(['Vacation', 'Standup']),
        );
        expect(
          readBack.lastCalendarSyncSkippedReasons,
          equals(['allDay', 'tooShort']),
        );

        await reopened.close();
      },
    );
  });
}
