// Regression tests for RestorativesNotifier.addPresetItem's double-tap and
// concurrent-different-preset races — the restoratives-side half of
// 34-REVIEW.md WR-01, which named BOTH onboarding beats ("a fast double-tap
// creates two identical goals/restoratives") even though the reviewer's own
// numeric reproduction was against GoalsNotifier. addPresetItem mirrors
// GoalsNotifier.addPresetGoal's guard exactly; these tests mirror
// test/providers/goals_notifier_preset_race_test.dart's technique — a
// delayed fake repository holding the async gap open, not a widget-level
// pumpAndSettle test that would settle straight past the race window.

import 'package:canopy/data/models/restorative_item.dart';
import 'package:canopy/data/repositories/restorative_item_repository.dart';
import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryRestorativeItemRepository implements RestorativeItemRepository {
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

class _SlowSaveRestorativeItemRepository implements RestorativeItemRepository {
  _SlowSaveRestorativeItemRepository(this._inner);
  final _InMemoryRestorativeItemRepository _inner;

  @override
  Future<List<RestorativeItem>> getAll() => _inner.getAll();

  @override
  Future<RestorativeItem?> getById(String id) => _inner.getById(id);

  @override
  Future<void> delete(String id) => _inner.delete(id);

  @override
  Future<void> save(RestorativeItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await _inner.save(item);
  }
}

void main() {
  group('RestorativesNotifier.addPresetItem races (34-REVIEW.md WR-01)', () {
    late RestorativesNotifier notifier;

    setUp(() async {
      final repo = _SlowSaveRestorativeItemRepository(
        _InMemoryRestorativeItemRepository(),
      );
      notifier = RestorativesNotifier(repository: repo);
      await notifier.loadItems();
    });

    test(
      'two concurrent taps on the SAME preset create exactly one item — the '
      'second is a no-op, not a second creation',
      () async {
        final first = notifier.addPresetItem('Nap', emoji: '😴');
        final second = notifier.addPresetItem('Nap', emoji: '😴');

        final results = await Future.wait([first, second]);

        expect(results.where((i) => i != null).length, 1);
        expect(notifier.items, hasLength(1));
        expect(notifier.items.single.name, 'Nap');
      },
    );

    test(
      'two DIFFERENT presets tapped concurrently both create, with distinct '
      'sortOrder',
      () async {
        final first = notifier.addPresetItem('Nap', emoji: '😴');
        final second = notifier.addPresetItem('Music', emoji: '🎵');

        final results = await Future.wait([first, second]);

        expect(notifier.items, hasLength(2));
        expect(results[0]!.sortOrder, isNot(equals(results[1]!.sortOrder)));
      },
    );

    test('a failed save releases the guard so the same preset can be retried', () async {
      final failing = _FailOnceThenSlowRepository();
      final n = RestorativesNotifier(repository: failing);
      await n.loadItems();

      final failed = await n.addPresetItem('Nap', emoji: '😴');
      expect(failed, isNull);

      final retried = await n.addPresetItem('Nap', emoji: '😴');
      expect(retried, isNotNull);
      expect(n.items, hasLength(1));
    });
  });
}

class _FailOnceThenSlowRepository implements RestorativeItemRepository {
  final _inner = _SlowSaveRestorativeItemRepository(
    _InMemoryRestorativeItemRepository(),
  );
  var _first = true;

  @override
  Future<List<RestorativeItem>> getAll() => _inner.getAll();

  @override
  Future<RestorativeItem?> getById(String id) => _inner.getById(id);

  @override
  Future<void> delete(String id) => _inner.delete(id);

  @override
  Future<void> save(RestorativeItem item) async {
    if (_first) {
      _first = false;
      throw StateError('simulated save failure');
    }
    await _inner.save(item);
  }
}
