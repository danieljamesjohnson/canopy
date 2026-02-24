import '../models/completion_log.dart';

/// Append-only repository — no delete or update methods.
abstract class CompletionLogRepository {
  Future<List<CompletionLog>> getAll();
  Future<CompletionLog?> getById(String id);
  Future<void> append(CompletionLog entry);
  Future<List<CompletionLog>> getByDate(String dateYmd);
  Future<List<CompletionLog>> getByGoalId(String goalId);
}
