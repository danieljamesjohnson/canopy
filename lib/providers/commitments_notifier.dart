import 'package:flutter/foundation.dart';
import '../data/models/commitment_block.dart';
import '../data/repositories/commitment_block_repository.dart';
import '../data/repositories/hive_commitment_block_repository.dart';

class CommitmentsNotifier extends ChangeNotifier {
  final CommitmentBlockRepository _repository = HiveCommitmentBlockRepository();

  List<CommitmentBlock> _blocks = [];

  List<CommitmentBlock> get blocks => List.unmodifiable(_blocks);

  /// Loads all commitment blocks and notifies listeners.
  Future<void> loadBlocks() async {
    _blocks = await _repository.getAll();
    notifyListeners();
  }

  /// Saves a commitment block (create or update) and reloads the list.
  Future<void> saveBlock(CommitmentBlock block) async {
    await _repository.save(block);
    await loadBlocks();
  }

  /// Hard-deletes a commitment block by id and reloads the list.
  Future<void> deleteBlock(String id) async {
    await _repository.delete(id);
    await loadBlocks();
  }
}
