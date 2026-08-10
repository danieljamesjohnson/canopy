import 'package:hive_ce/hive.dart';
import '../../dev/dev_clock.dart';
import '../models/daily_schedule.dart';
import 'daily_schedule_repository.dart';

class HiveDailyScheduleRepository implements DailyScheduleRepository {
  Box<DailySchedule> get _box => Hive.box<DailySchedule>('daily_schedules');

  @override
  Future<List<DailySchedule>> getAll() async => _box.values.toList();

  @override
  Future<DailySchedule?> getById(String id) async =>
      _box.values.where((s) => s.id == id).firstOrNull;

  @override
  Future<void> save(DailySchedule schedule) async =>
      _box.put(schedule.id, schedule);

  @override
  Future<void> delete(String id) async => _box.delete(id);

  @override
  Future<DailySchedule?> getByDate(String dateYmd) async =>
      _box.values.where((s) => s.dateYmd == dateYmd).firstOrNull;

  @override
  Future<DailySchedule?> getTodaysSchedule() async {
    // Phase 25 (Time Travel, DEV-01): routed through DevClock so the loaded
    // schedule matches a simulated day, not just real wall-clock time.
    // DevClock.now() is DateTime.now() in release builds (DEV-03).
    final today =
        DevClock.now(); // local time — must match generateToday() key format
    final dateYmd =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return getByDate(dateYmd);
  }
}
