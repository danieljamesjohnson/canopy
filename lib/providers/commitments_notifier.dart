import 'package:flutter/foundation.dart';
import '../data/calendar/calendar_source.dart';
import '../data/models/commitment_block.dart';
import '../data/repositories/commitment_block_repository.dart';
import '../data/repositories/hive_commitment_block_repository.dart';
import '../services/calendar_sync_service.dart';

class CommitmentsNotifier extends ChangeNotifier {
  /// Construct a CommitmentsNotifier. [repository] defaults to
  /// `HiveCommitmentBlockRepository()` (production). Pass an in-memory
  /// repository in tests to avoid Hive initialisation.
  CommitmentsNotifier({CommitmentBlockRepository? repository})
    : _repository = repository ?? HiveCommitmentBlockRepository();

  final CommitmentBlockRepository _repository;

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

  /// Syncs [source]'s events into commitment blocks (CAL-01), then reloads
  /// [blocks] so listeners see the imported/updated commitments. Reuses
  /// [loadBlocks] rather than inventing a parallel refresh path. A failed
  /// sync (see [CalendarSyncResult.failed]) leaves [blocks] as last-known —
  /// this method never throws (D-35-13: check-in must still generate a day
  /// from last-known blocks).
  Future<CalendarSyncResult> syncFromCalendar({
    required CalendarSource source,
  }) async {
    final service = CalendarSyncService(source: source, repository: _repository);
    final result = await service.sync();
    await loadBlocks();
    return result;
  }
}
