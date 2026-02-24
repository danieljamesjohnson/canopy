import '../models/daily_schedule.dart';

abstract class DailyScheduleRepository {
  Future<List<DailySchedule>> getAll();
  Future<DailySchedule?> getById(String id);
  Future<void> save(DailySchedule schedule);
  Future<void> delete(String id);
  Future<DailySchedule?> getByDate(String dateYmd);
  Future<DailySchedule?> getTodaysSchedule();
}
