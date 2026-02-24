import 'package:hive_ce/hive.dart';
import '../models/quarterly_snapshot.dart';
import 'quarterly_snapshot_repository.dart';

class HiveQuarterlySnapshotRepository implements QuarterlySnapshotRepository {
  Box<QuarterlySnapshot> get _box =>
      Hive.box<QuarterlySnapshot>('quarterly_snapshots');

  @override
  Future<List<QuarterlySnapshot>> getAll() async => _box.values.toList();

  @override
  Future<QuarterlySnapshot?> getById(String id) async =>
      _box.values.where((s) => s.id == id).firstOrNull;

  @override
  Future<void> append(QuarterlySnapshot snapshot) async =>
      _box.put(snapshot.id, snapshot);

  @override
  Future<QuarterlySnapshot?> getLatest() async {
    if (_box.isEmpty) return null;
    return _box.values.reduce((a, b) =>
        a.completedAt.isAfter(b.completedAt) ? a : b);
  }
}
