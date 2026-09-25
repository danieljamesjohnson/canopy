// Hive round-trip tests for the Phase 36 schema 11→12 bump: AppSettings
// gains googleAccessToken (HiveField 12), googleRefreshToken (HiveField 13),
// googleAccessTokenExpiresAt (HiveField 14) and googleReconnectNeeded
// (HiveField 15). See migration_schema_test.dart for the schema-constant
// assertions (currentSchemaVersion == 12) — this file is the Hive I/O half,
// following the per-phase migration test naming precedent
// (migration_schema8_test.dart's own two-part structure, before its rename).
//
// The old-record compatibility test below is mutation-proofed: temporarily
// declaring googleReconnectNeeded as a non-nullable List<String> with no
// default (the exact shape that crashed Phase 35 — see 35-03-SUMMARY.md)
// and regenerating reproduced a real crash here too, confirming this test
// is non-vacuous. See 36-01-SUMMARY.md for the observed output; reverted
// immediately after observing it.

import 'dart:io';

import 'package:canopy/data/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// Writes AppSettings using the PRE-Phase-36 (schema 11, 12-field) shape —
/// HiveFields 12-15 are physically ABSENT from the binary, matching an
/// existing user's real on-disk data at the moment of this upgrade.
class _OldAppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final typeId = 6;

  @override
  AppSettings read(BinaryReader reader) =>
      throw UnimplementedError('write-only — only used to produce old bytes');

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(12)
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
      ..write(obj.lastCalendarSyncAt);
  }
}

void main() {
  group('AppSettings schema 11→12 — Google token fields (CALAUTH-01/02/03)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hive_schema12_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    // The assertion that would have caught 35-03's crash class, and did
    // catch a real one here too (see file header) — this is why it exists
    // rather than trusting the migration comment's claim.
    test(
      'an old (schema 11, 12-field) AppSettings record reads back under the '
      'new (16-field) adapter with all four Google fields null/false, no '
      'crash',
      () async {
        const boxName = 'app_settings_schema12_old_compat';

        Hive.registerAdapter(_OldAppSettingsAdapter());
        final oldBox = await Hive.openBox<AppSettings>(boxName);
        final oldSettings = AppSettings()..morningNotificationMinutes = 480;
        await oldBox.put('settings', oldSettings);
        await oldBox.close();

        // Swap in the current (new) adapter and reopen the same box — this
        // is the schema 11→12 upgrade.
        Hive.registerAdapter(AppSettingsAdapter(), override: true);
        final reopened = await Hive.openBox<AppSettings>(boxName);
        final readBack = reopened.get('settings');

        expect(
          readBack,
          isNotNull,
          reason: 'AppSettings must be readable after the schema 11→12 upgrade',
        );
        expect(
          readBack!.morningNotificationMinutes,
          equals(480),
          reason: 'pre-existing fields must survive the upgrade untouched',
        );
        expect(
          readBack.googleAccessToken,
          isNull,
          reason: 'an upgrading user has no Google connection (CALAUTH-01)',
        );
        expect(readBack.googleRefreshToken, isNull);
        expect(readBack.googleAccessTokenExpiresAt, isNull);
        expect(
          readBack.googleReconnectNeeded,
          isFalse,
          reason:
              'an upgrading user with no Google connection must not be '
              'shown a reconnect prompt (CALAUTH-03)',
        );

        await reopened.close();
      },
    );

    test(
      'a new AppSettings record with all four Google fields populated '
      'survives a close/reopen cycle',
      () async {
        const boxName = 'app_settings_schema12_round_trip';
        if (!Hive.isAdapterRegistered(6)) {
          Hive.registerAdapter(AppSettingsAdapter());
        }

        final expiresAt = DateTime.utc(2026, 4, 1, 12, 30, 45);
        final box = await Hive.openBox<AppSettings>(boxName);
        final settings = AppSettings()
          ..googleAccessToken = 'access-token-value'
          ..googleRefreshToken = 'refresh-token-value'
          ..googleAccessTokenExpiresAt = expiresAt
          ..googleReconnectNeeded = true;
        await box.put('settings', settings);
        await box.close();

        final reopened = await Hive.openBox<AppSettings>(boxName);
        final readBack = reopened.get('settings');

        expect(readBack, isNotNull);
        expect(readBack!.googleAccessToken, equals('access-token-value'));
        expect(readBack.googleRefreshToken, equals('refresh-token-value'));
        expect(
          readBack.googleAccessTokenExpiresAt,
          equals(expiresAt),
          reason: 'googleAccessTokenExpiresAt must round-trip as the same instant',
        );
        expect(readBack.googleReconnectNeeded, isTrue);

        await reopened.close();
      },
    );
  });
}
