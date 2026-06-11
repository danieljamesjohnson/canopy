import '../models/completion_log.dart';
import 'completion_log_repository.dart';

/// In-memory implementation of [CompletionLogRepository] for tests.
///
/// Mirrors the [HiveCompletionLogRepository] contract without disk I/O so
/// that unit tests can exercise schedule generation and notifier logic without
/// bootstrapping Hive boxes. Published under `lib/` (rather than `test/`) so
/// multiple test files can share the same fake without test-to-test imports.
///
/// Plan 09-01 Task 1 — sibling of `InMemoryAppSettingsRepository` from
/// `lib/data/repositories/in_memory_app_settings_repository.dart`.
class InMemoryCompletionLogRepository implements CompletionLogRepository {
  final List<CompletionLog> _logs = [];

  @override
  Future<void> append(CompletionLog log) async => _logs.add(log);

  @override
  Future<List<CompletionLog>> getAll() async => List.unmodifiable(_logs);

  @override
  Future<CompletionLog?> getById(String id) async =>
      _logs.where((l) => l.id == id).firstOrNull;

  @override
  Future<List<CompletionLog>> getByDate(String dateYmd) async =>
      _logs.where((l) => l.dateYmd == dateYmd).toList();

  @override
  Future<List<CompletionLog>> getByGoalId(String goalId) async =>
      _logs.where((l) => l.goalId == goalId).toList();
}
