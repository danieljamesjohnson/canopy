import '../models/commitment_block.dart';

abstract class CommitmentBlockRepository {
  Future<List<CommitmentBlock>> getAll();
  Future<CommitmentBlock?> getById(String id);
  Future<void> save(CommitmentBlock block);
  Future<void> delete(String id);
  Future<List<CommitmentBlock>> getByDayOfWeek(int day);
}
