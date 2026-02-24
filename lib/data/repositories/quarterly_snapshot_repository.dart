import '../models/quarterly_snapshot.dart';

/// Append-only repository — no delete or update methods.
abstract class QuarterlySnapshotRepository {
  Future<List<QuarterlySnapshot>> getAll();
  Future<QuarterlySnapshot?> getById(String id);
  Future<void> append(QuarterlySnapshot snapshot);
  Future<QuarterlySnapshot?> getLatest();
}
