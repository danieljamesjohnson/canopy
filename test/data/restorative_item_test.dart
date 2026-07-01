// Tests for the RestorativeItem aggregate (schema 9 / typeId 7):
// - Hive round-trip preserves fields (incl. null emoji)
// - RestorativesNotifier CRUD + sortOrder ordering via an in-memory repo
// - Restoratives are a separate aggregate from goals (no GoalType coupling)

import 'dart:io';

import 'package:canopy/data/models/restorative_item.dart';
import 'package:canopy/data/repositories/in_memory_restorative_item_repository.dart';
import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  group('RestorativeItem Hive round-trip (typeId 7)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hive_restorative_test_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(7)) {
        Hive.registerAdapter(RestorativeItemAdapter());
      }
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    test('item with emoji survives close/reopen', () async {
      const boxName = 'restoratives_round_trip';
      final box = await Hive.openBox<RestorativeItem>(boxName);
      final item = RestorativeItem(
        id: 'r1',
        name: 'Listen to music',
        emojiTag: '🎵',
        sortOrder: 2,
      );
      await box.put(item.id, item);
      await box.close();

      final reopened = await Hive.openBox<RestorativeItem>(boxName);
      final readBack = reopened.get('r1');
      expect(readBack, isNotNull);
      expect(readBack!.name, 'Listen to music');
      expect(readBack.emojiTag, '🎵');
      expect(readBack.sortOrder, 2);
      await reopened.close();
    });

    test('item without emoji reads back with null emojiTag', () async {
      const boxName = 'restoratives_no_emoji';
      final box = await Hive.openBox<RestorativeItem>(boxName);
      await box.put('r2', RestorativeItem(id: 'r2', name: 'Take a walk'));
      await box.close();

      final reopened = await Hive.openBox<RestorativeItem>(boxName);
      final readBack = reopened.get('r2');
      expect(readBack!.emojiTag, isNull);
      expect(readBack.sortOrder, 0);
      await reopened.close();
    });
  });

  group('RestorativesNotifier CRUD', () {
    test('starts empty', () async {
      final notifier = RestorativesNotifier(
        repository: InMemoryRestorativeItemRepository(),
      );
      await notifier.loadItems();
      expect(notifier.isEmpty, isTrue);
      expect(notifier.items, isEmpty);
    });

    test('save adds an item and reloads', () async {
      final notifier = RestorativesNotifier(
        repository: InMemoryRestorativeItemRepository(),
      );
      await notifier.saveItem(RestorativeItem(name: 'Read a book'));
      expect(notifier.items, hasLength(1));
      expect(notifier.items.first.name, 'Read a book');
      expect(notifier.isEmpty, isFalse);
    });

    test('items are returned in sortOrder', () async {
      final notifier = RestorativesNotifier(
        repository: InMemoryRestorativeItemRepository(),
      );
      await notifier.saveItem(RestorativeItem(name: 'Third', sortOrder: 2));
      await notifier.saveItem(RestorativeItem(name: 'First', sortOrder: 0));
      await notifier.saveItem(RestorativeItem(name: 'Second', sortOrder: 1));
      expect(
        notifier.items.map((i) => i.name).toList(),
        ['First', 'Second', 'Third'],
      );
    });

    test('editing an existing item updates in place, no duplicate', () async {
      final notifier = RestorativesNotifier(
        repository: InMemoryRestorativeItemRepository(),
      );
      final item = RestorativeItem(name: 'Guitar');
      await notifier.saveItem(item);
      item.name = 'Play guitar';
      await notifier.saveItem(item);
      expect(notifier.items, hasLength(1));
      expect(notifier.items.first.name, 'Play guitar');
    });

    test('delete removes the item', () async {
      final notifier = RestorativesNotifier(
        repository: InMemoryRestorativeItemRepository(),
      );
      final item = RestorativeItem(name: 'Nap');
      await notifier.saveItem(item);
      await notifier.deleteItem(item.id);
      expect(notifier.isEmpty, isTrue);
    });

    test('notifies listeners on load and save', () async {
      final notifier = RestorativesNotifier(
        repository: InMemoryRestorativeItemRepository(),
      );
      var notifications = 0;
      notifier.addListener(() => notifications++);
      await notifier.loadItems();
      await notifier.saveItem(RestorativeItem(name: 'Stretch'));
      expect(notifications, greaterThanOrEqualTo(2));
    });
  });
}
