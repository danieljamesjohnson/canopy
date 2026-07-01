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

  /// Hard-deletes a restorative item by id and reloads the list.
  Future<void> deleteItem(String id) async {
    await _repository.delete(id);
    await loadItems();
  }
}
