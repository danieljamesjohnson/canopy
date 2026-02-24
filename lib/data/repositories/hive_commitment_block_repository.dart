import 'package:hive_ce/hive.dart';
import '../models/commitment_block.dart';
import 'commitment_block_repository.dart';

class HiveCommitmentBlockRepository implements CommitmentBlockRepository {
  Box<CommitmentBlock> get _box => Hive.box<CommitmentBlock>('commitment_blocks');

  @override
  Future<List<CommitmentBlock>> getAll() async => _box.values.toList();

  @override
  Future<CommitmentBlock?> getById(String id) async =>
      _box.values.where((b) => b.id == id).firstOrNull;

  @override
  Future<void> save(CommitmentBlock block) async => _box.put(block.id, block);

  @override
  Future<void> delete(String id) async => _box.delete(id);

  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async =>
      _box.values.where((b) => b.daysOfWeek.contains(day)).toList();
}
