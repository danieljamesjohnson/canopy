import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/models/commitment_block.dart';
import '../data/models/daily_schedule.dart';
import '../data/models/goal.dart';
import '../data/repositories/daily_schedule_repository.dart';
import '../data/repositories/hive_daily_schedule_repository.dart';
import '../services/schedule_generator.dart';

class ScheduleNotifier extends ChangeNotifier {
  final DailyScheduleRepository _repo = HiveDailyScheduleRepository();
  final ScheduleGeneratorService _generator = ScheduleGeneratorService();

  DailySchedule? _todaySchedule;
  bool _loading = false;

  DailySchedule? get todaySchedule => _todaySchedule;
  bool get hasScheduleToday => _todaySchedule != null;
  int? get moodIndex => _todaySchedule?.moodIndex;
  bool get isLoading => _loading;

  Future<void> init() async {
    _loading = true;
    _todaySchedule = await _repo.getTodaysSchedule();
    _loading = false;
    notifyListeners();
  }

  Future<void> generateToday({
    required int moodIndex,
    required List<Goal> goals,
    required List<CommitmentBlock> blocks,
  }) async {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day); // midnight local
    final dateYmd = DateFormat('yyyy-MM-dd').format(now);

    final chunks = _generator.generate(
      goals: goals,
      blocks: blocks,
      moodIndex: moodIndex,
      date: date,
    );

    // Silent replace: delete existing schedule for today if any.
    final existing = await _repo.getByDate(dateYmd);
    if (existing != null) await _repo.delete(existing.id);

    final schedule = DailySchedule(
      dateYmd: dateYmd,
      moodIndex: moodIndex,
      chunks: chunks,
    );
    // Set generatedAt explicitly (field-level default runs at class parse time, not instantiation).
    schedule.generatedAt = DateTime.now().toUtc();

    await _repo.save(schedule);
    _todaySchedule = schedule;
    notifyListeners();
  }
}
