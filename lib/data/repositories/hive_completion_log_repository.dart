import 'package:hive_ce/hive.dart';
import '../models/completion_log.dart';
import 'completion_log_repository.dart';

class HiveCompletionLogRepository implements CompletionLogRepository {
  Box<CompletionLog> get _box => Hive.box<CompletionLog>('completion_logs');

  @override
  Future<List<CompletionLog>> getAll() async => _box.values.toList();

  @override
  Future<CompletionLog?> getById(String id) async =>
      _box.values.where((e) => e.id == id).firstOrNull;

  @override
  Future<void> append(CompletionLog entry) async => _box.put(entry.id, entry);

  @override
  Future<List<CompletionLog>> getByDate(String dateYmd) async =>
      _box.values.where((e) => e.dateYmd == dateYmd).toList();

  @override
  Future<List<CompletionLog>> getByGoalId(String goalId) async =>
      _box.values.where((e) => e.goalId == goalId).toList();
}
