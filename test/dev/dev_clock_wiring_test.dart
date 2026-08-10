// Phase 25 (Time Travel) — integration coverage for DEV-01's actual claim.
//
// dev_clock_test.dart proves DevClock's own arithmetic. These tests prove the
// WIRING: that a simulated time actually reaches the two consumers the harness
// exists to serve. Without them, DevClock could be perfectly correct while
// time travel did nothing observable — and the failure would only surface
// during a manual UAT, which is exactly the loop this phase exists to close.
//
// The load-bearing case: jump the clock to 9pm to inspect DayComplete. If
// getTodaysSchedule() ignored the override it would return the REAL day's
// schedule (or none at all), and the tester would see an empty day and
// reasonably conclude the feature was broken.

import 'dart:io';

import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/data/repositories/hive_daily_schedule_repository.dart';
import 'package:canopy/dev/dev_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DevClock wiring — HiveDailyScheduleRepository.getTodaysSchedule', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      DevClock.resetForTest();
      tempDir = Directory.systemTemp.createTempSync('hive_devclock_wiring_');
      Hive.init(tempDir.path);
      // DailySchedule is typeId 2, ScheduledChunk is typeId 3 (see the
      // @HiveType annotations). The guards must match those exact ids —
      // registration is process-global and survives Hive.close(), so a
      // mismatched guard throws on the second test in this file.
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(DailyScheduleAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(ScheduledChunkAdapter());
      }
      await Hive.openBox<DailySchedule>('daily_schedules');
    });

    tearDown(() async {
      DevClock.resetForTest();
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    test('a simulated day loads THAT day\'s schedule, not the real day\'s '
        '(DEV-01)', () async {
      final repo = HiveDailyScheduleRepository();
      final realToday = DateTime.now();
      // Far enough away that it cannot collide with the real date, and in
      // the past so the test can never depend on a future timezone change.
      final simulatedDay = realToday.subtract(const Duration(days: 40));

      // Two schedules on disk: one for the real day, one for the simulated
      // day. Only the correct one may come back.
      await repo.save(
        DailySchedule(
          id: 'real-day',
          dateYmd: _ymd(realToday),
          moodIndex: 3,
          chunks: [],
        ),
      );
      await repo.save(
        DailySchedule(
          id: 'simulated-day',
          dateYmd: _ymd(simulatedDay),
          moodIndex: 3,
          chunks: [],
        ),
      );

      // Baseline: with no override, the real day wins.
      expect((await repo.getTodaysSchedule())?.id, 'real-day');

      // Travel. Noon avoids any midnight-boundary ambiguity.
      await DevClock.setSimulatedNow(
        DateTime(simulatedDay.year, simulatedDay.month, simulatedDay.day, 12),
      );

      expect(
        (await repo.getTodaysSchedule())?.id,
        'simulated-day',
        reason:
            'getTodaysSchedule must key off DevClock.now(), otherwise '
            'jumping the clock shows an empty day and time travel looks '
            'broken to the tester',
      );

      // And travel back.
      await DevClock.clear();
      expect((await repo.getTodaysSchedule())?.id, 'real-day');
    });

    test(
      'an overridden clock still moves the day key forward across midnight',
      () async {
        final repo = HiveDailyScheduleRepository();
        final base = DateTime.now().subtract(const Duration(days: 40));
        final dayOne = DateTime(base.year, base.month, base.day, 23, 59);

        await repo.save(
          DailySchedule(
            id: 'day-one',
            dateYmd: _ymd(dayOne),
            moodIndex: 3,
            chunks: [],
          ),
        );
        final dayTwo = dayOne.add(const Duration(minutes: 2));
        await repo.save(
          DailySchedule(
            id: 'day-two',
            dateYmd: _ymd(dayTwo),
            moodIndex: 3,
            chunks: [],
          ),
        );

        await DevClock.setSimulatedNow(dayOne);
        expect((await repo.getTodaysSchedule())?.id, 'day-one');

        // The offset design (DEV-02) means time keeps flowing, so a simulated
        // 23:59 genuinely rolls into the next day rather than sticking.
        await DevClock.shift(const Duration(minutes: 2));
        expect((await repo.getTodaysSchedule())?.id, 'day-two');
      },
    );
  });
}
