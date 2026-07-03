import 'package:flutter/foundation.dart';
import '../data/models/restorative_item.dart';
import '../data/repositories/restorative_item_repository.dart';
import '../data/repositories/hive_restorative_item_repository.dart';

/// Holds the user's restorative activities (things that recharge them, kept
/// deliberately separate from goals). Mirrors [CommitmentsNotifier]: construct
/// before runApp, await [loadItems] on cold launch so the list is ready when
/// the low-energy surface reads it.
class RestorativesNotifier extends ChangeNotifier {
  /// [repository] defaults to [HiveRestorativeItemRepository] (production).
  /// Pass an in-memory repository in tests to avoid Hive initialisation.
  RestorativesNotifier({RestorativeItemRepository? repository})
    : _repository = repository ?? HiveRestorativeItemRepository();

  final RestorativeItemRepository _repository;

  List<RestorativeItem> _items = [];

  List<RestorativeItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  /// Loads all restorative items (sorted by sortOrder) and notifies listeners.
  Future<void> loadItems() async {
    _items = await _repository.getAll();
    notifyListeners();
  }

  /// Saves a restorative item (create or update) and reloads the list.
  Future<void> saveItem(RestorativeItem item) async {
    await _repository.save(item);
    await loadItems();
  }

  /// Frictionless bulk entry: create one or more restoratives from plain names
  /// (type a name + Enter, repeat — or paste a newline-separated list). Blank
  /// names are skipped; new items are appended after existing ones. On a save
  /// failure we stop and return the honest count actually persisted rather than
  /// throwing, so the caller can recover the unsaved tail. Reloads once.
  Future<int> quickAddItems(Iterable<String> names) async {
    final cleaned = names
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return 0;

    var nextSort = _items.isEmpty
        ? 0
        : _items.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    var saved = 0;
    for (final name in cleaned) {
      final item = RestorativeItem(name: name, sortOrder: nextSort++);
      try {
        await _repository.save(item);
        saved++;
      } catch (_) {
        break;
      }
    }
    await loadItems();
    return saved;
  }

  /// Hard-deletes a restorative item by id and reloads the list.
  Future<void> deleteItem(String id) async {
    await _repository.delete(id);
    await loadItems();
  }
}
