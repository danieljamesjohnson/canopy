import '../models/restorative_item.dart';

abstract class RestorativeItemRepository {
  Future<List<RestorativeItem>> getAll();
  Future<RestorativeItem?> getById(String id);
  Future<void> save(RestorativeItem item);
  Future<void> delete(String id);
}
