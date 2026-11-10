import 'package:flutter/foundation.dart';
import '../data/calendar/calendar_source.dart';
import '../data/models/commitment_block.dart';
import '../data/repositories/commitment_block_repository.dart';
import '../data/repositories/hive_commitment_block_repository.dart';
import '../services/calendar_sync_service.dart';
import '../utils/meals.dart';

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

  /// The saved meal blocks (Phase 37), in no particular order.
  List<CommitmentBlock> get mealBlocks =>
      List.unmodifiable(_blocks.where((b) => b.isMeal));

  /// Saves the three meal rows (Phase 37, D-37-02/-05/-07): each switched-on
  /// meal becomes (or updates) ONE recurring block on all seven days, keyed by
  /// its [CommitmentBlock.kind]; each switched-off meal's block is deleted.
  /// Ordinary commitments are never touched. Reloads [blocks] once at the end.
  Future<void> saveMeals(List<MealDraft> drafts) async {
    final existing = {
      for (final b in await _repository.getAll())
        if (b.isMeal) b.kind!: b,
    };
    for (final d in drafts) {
      final current = existing[d.slot.kind];
      if (!d.enabled) {
        if (current != null) await _repository.delete(current.id);
        continue;
      }
      if (current != null) {
        current
          ..name = d.slot.label
          ..daysOfWeek = List.of(kAllWeekdays)
          ..startMinutes = d.startMinutes
          ..endMinutes = d.endMinutes;
        await _repository.save(current);
      } else {
        await _repository.save(
          CommitmentBlock(
            name: d.slot.label,
            daysOfWeek: List.of(kAllWeekdays),
            startMinutes: d.startMinutes,
            endMinutes: d.endMinutes,
            kind: d.slot.kind,
          ),
        );
      }
    }
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
  /// sync (see [CalendarSyncResult.failed]) imports nothing and leaves
  /// [blocks] as last-known, apart from the selection prune below, which
  /// needs no fetch — this method never throws (D-35-13: check-in must
  /// still generate a day from last-known blocks).
  ///
  /// [configuredCalendarIds] is the user's currently ticked calendar ids,
  /// forwarded unchanged to [CalendarSyncService]; when non-null, imported
  /// blocks from any other calendar are removed (WINDOWS entry 11). Null
  /// (the default) leaves that prune off.
  Future<CalendarSyncResult> syncFromCalendar({
    required CalendarSource source,
    Iterable<String>? configuredCalendarIds,
  }) async {
    final service = CalendarSyncService(
      source: source,
      repository: _repository,
      configuredCalendarIds: configuredCalendarIds,
    );
    final result = await service.sync();
    await loadBlocks();
    return result;
  }
}
