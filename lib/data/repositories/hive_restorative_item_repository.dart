import 'package:hive_ce/hive.dart';
import '../models/restorative_item.dart';
import 'restorative_item_repository.dart';

class HiveRestorativeItemRepository implements RestorativeItemRepository {
  Box<RestorativeItem> get _box =>
      Hive.box<RestorativeItem>('restorative_items');

  @override
  Future<List<RestorativeItem>> getAll() async {
    final items = _box.values.toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  @override
  Future<RestorativeItem?> getById(String id) async =>
      _box.values.where((i) => i.id == id).firstOrNull;

  @override
  Future<void> save(RestorativeItem item) async => _box.put(item.id, item);

  @override
  Future<void> delete(String id) async => _box.delete(id);
}
