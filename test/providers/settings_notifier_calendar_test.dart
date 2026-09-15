import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:canopy/data/models/app_settings.dart';
import 'package:canopy/data/repositories/in_memory_app_settings_repository.dart';
import 'package:canopy/providers/settings_notifier.dart';

/// Mirrors the pre-Phase-35 `AppSettingsAdapter` (schema 10, 9 fields)
/// exactly as it existed before HiveField 9/10/11 were added. Used ONLY to
/// write a genuinely old-shaped record to a real Hive box, so the
/// "old records deserialize with an empty selection, no feed URLs and a
/// null last-sync time" must_have is proven against real binary ABSENCE of
/// those fields — not merely a field carrying a null value, which is a
/// different (always-safe, nullable-field) case and would not discriminate
/// the defect this test exists to catch.
class _OldAppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final typeId = 6;

  @override
  AppSettings read(BinaryReader reader) =>
      throw UnimplementedError('write-only — only used to produce old bytes');

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
}

void main() {
  group(
    'SettingsNotifier — calendar selection/feeds/last-sync persist across '
    'a restart (CAL-02)',
    () {
      late InMemoryAppSettingsRepository repo;

      setUp(() {
        repo = InMemoryAppSettingsRepository();
      });

      test(
        'setting a selection, adding two feed URLs and setting a last-sync '
        'time round-trips through the repository',
        () async {
          final notifier = SettingsNotifier(repository: repo);
          await notifier.init();

          await notifier.setSelectedCalendarIds(['cal-1', 'cal-2']);
          await notifier.addIcsUrl('https://example.com/a.ics');
          await notifier.addIcsUrl('https://example.com/b.ics');
          final syncTime = DateTime(2026, 3, 1, 9, 30);
          await notifier.setLastCalendarSyncAt(syncTime);

          // Reload from the SAME repository through a FRESH notifier
          // instance — reading the value back off the object that just set
          // it cannot fail, so this reads it off a second notifier that
          // only ever calls init().
          final reloaded = SettingsNotifier(repository: repo);
          await reloaded.init();

          expect(reloaded.selectedCalendarIds, ['cal-1', 'cal-2']);
          expect(reloaded.icsUrls, [
            'https://example.com/a.ics',
            'https://example.com/b.ics',
          ]);
          expect(reloaded.lastCalendarSyncAt, syncTime);
        },
      );

      test('addIcsUrl called twice with the same URL leaves one entry', () async {
        final notifier = SettingsNotifier(repository: repo);
        await notifier.init();

        await notifier.addIcsUrl('https://example.com/a.ics');
        await notifier.addIcsUrl('https://example.com/a.ics');

        expect(notifier.icsUrls, ['https://example.com/a.ics']);
        final persisted = await repo.getSettings();
        expect(persisted!.icsUrls, ['https://example.com/a.ics']);
      });

      test('removeIcsUrl removes only that URL', () async {
        final notifier = SettingsNotifier(repository: repo);
        await notifier.init();
        await notifier.addIcsUrl('https://example.com/a.ics');
        await notifier.addIcsUrl('https://example.com/b.ics');

        await notifier.removeIcsUrl('https://example.com/a.ics');

        expect(notifier.icsUrls, ['https://example.com/b.ics']);
        final persisted = await repo.getSettings();
        expect(persisted!.icsUrls, ['https://example.com/b.ics']);
      });

      test(
        'a default-constructed AppSettings has an empty selection, no feed '
        'URLs and a null last-sync time',
        () {
          final settings = AppSettings();
          expect(settings.selectedCalendarIds, isEmpty);
          expect(settings.icsUrls, isEmpty);
          expect(settings.lastCalendarSyncAt, isNull);
        },
      );

      test('setSelectedCalendarIds notifies its listeners exactly once', () async {
        final notifier = SettingsNotifier(repository: repo);
        await notifier.init();
        var notifications = 0;
        notifier.addListener(() => notifications++);

        await notifier.setSelectedCalendarIds(['cal-1']);

        expect(notifications, 1);
      });

      test('addIcsUrl notifies its listeners exactly once', () async {
        final notifier = SettingsNotifier(repository: repo);
        await notifier.init();
        var notifications = 0;
        notifier.addListener(() => notifications++);

        await notifier.addIcsUrl('https://example.com/a.ics');

        expect(notifications, 1);
      });

      test('removeIcsUrl notifies its listeners exactly once', () async {
        final notifier = SettingsNotifier(repository: repo);
        await notifier.init();
        await notifier.addIcsUrl('https://example.com/a.ics');
        var notifications = 0;
        notifier.addListener(() => notifications++);

        await notifier.removeIcsUrl('https://example.com/a.ics');

        expect(notifications, 1);
      });

      test('setLastCalendarSyncAt notifies its listeners exactly once', () async {
        final notifier = SettingsNotifier(repository: repo);
        await notifier.init();
        var notifications = 0;
        notifier.addListener(() => notifications++);

        await notifier.setLastCalendarSyncAt(DateTime(2026, 3, 1));

        expect(notifications, 1);
      });
    },
  );

  group(
    'AppSettings schema 10→11 — an old record survives the upgrade '
    '(CAL-02)',
    () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync(
          'hive_schema10to11_test_',
        );
        Hive.init(tempDir.path);
      });

      tearDown(() async {
        await Hive.close();
        tempDir.deleteSync(recursive: true);
      });

      test(
        'an old (schema 10, 9-field) AppSettings record reads back under '
        'the new (12-field) adapter with an empty selection, no feed URLs '
        'and a null last-sync time — no crash',
        () async {
          const boxName = 'app_settings_old_compat';

          // Write using the OLD (pre-Phase-35) adapter — HiveField 9/10/11
          // are physically ABSENT from the binary, matching an existing
          // user's real on-disk data at upgrade time.
          Hive.registerAdapter(_OldAppSettingsAdapter());
          final oldBox = await Hive.openBox<AppSettings>(boxName);
          final oldSettings = AppSettings()..morningNotificationMinutes = 500;
          await oldBox.put('settings', oldSettings);
          await oldBox.close();

          // Swap in the current (new) adapter and reopen the same box —
          // this is the schema 10→11 upgrade.
          Hive.registerAdapter(AppSettingsAdapter(), override: true);
          final reopened = await Hive.openBox<AppSettings>(boxName);
          final readBack = reopened.get('settings');

          expect(
            readBack,
            isNotNull,
            reason: 'AppSettings must be readable after the schema 10→11 upgrade',
          );
          expect(
            readBack!.morningNotificationMinutes,
            500,
            reason: 'pre-existing fields must survive unchanged',
          );
          expect(readBack.selectedCalendarIds, isEmpty);
          expect(readBack.icsUrls, isEmpty);
          expect(readBack.lastCalendarSyncAt, isNull);
          await reopened.close();
        },
      );
    },
  );
}
