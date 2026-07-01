import '../models/restorative_item.dart';
import 'restorative_item_repository.dart';

/// In-memory [RestorativeItemRepository] for tests — avoids Hive init.
class InMemoryRestorativeItemRepository implements RestorativeItemRepository {
  final Map<String, RestorativeItem> _store = {};

  @override
  Future<List<RestorativeItem>> getAll() async {
    final items = _store.values.toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  @override
  Future<RestorativeItem?> getById(String id) async => _store[id];

  @override
  Future<void> save(RestorativeItem item) async => _store[item.id] = item;

  @override
  Future<void> delete(String id) async => _store.remove(id);
}
