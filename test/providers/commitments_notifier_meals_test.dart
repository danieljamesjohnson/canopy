// Phase 37: CommitmentsNotifier.saveMeals — one block per switched-on meal,
// all seven days, keyed by kind; switched-off meals deleted; ordinary
// commitments untouched. Mutation log: 37-01-SUMMARY.md.

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/utils/meals.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements CommitmentBlockRepository {
  final Map<String, CommitmentBlock> store = {};
  @override
  Future<List<CommitmentBlock>> getAll() async => store.values.toList();
  @override
  Future<CommitmentBlock?> getById(String id) async => store[id];
  @override
  Future<void> save(CommitmentBlock block) async => store[block.id] = block;
  @override
  Future<void> delete(String id) async => store.remove(id);
  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async =>
      store.values.where((b) => b.daysOfWeek.contains(day)).toList();
}

void main() {
  test('the defaults save exactly three meals, every day, at 7-7:30, 12-1, '
      '6-7', () async {
    final repo = _Repo();
    final n = CommitmentsNotifier(repository: repo);
    await n.saveMeals(MealDraft.defaults());
    final meals = repo.store.values.toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    expect(meals.map((b) => (b.kind, b.name, b.startMinutes, b.endMinutes)), [
      ('breakfast', 'Breakfast', 420, 450),
      ('lunch', 'Lunch', 720, 780),
      ('dinner', 'Dinner', 1080, 1140),
    ]);
    for (final b in meals) {
      expect(b.daysOfWeek, [1, 2, 3, 4, 5, 6, 7]);
      expect(b.isFromCalendar, isFalse);
    }
    expect(n.mealBlocks, hasLength(3));
  });

  test('saving again updates in place — no duplicates — and switching a meal '
      'off deletes it, leaving ordinary commitments alone', () async {
    final repo = _Repo();
    final work = CommitmentBlock(
      id: 'work',
      name: 'Work',
      daysOfWeek: const [1, 2, 3, 4, 5],
      startMinutes: 540,
      endMinutes: 1020,
    );
    repo.store['work'] = work;
    final n = CommitmentsNotifier(repository: repo);
    await n.saveMeals(MealDraft.defaults());
    final lunchId = repo.store.values.firstWhere((b) => b.kind == 'lunch').id;

    final drafts = MealDraft.defaults();
    drafts[1]
      ..startMinutes = 750
      ..endMinutes = 795;
    drafts[2].enabled = false;
    await n.saveMeals(drafts);

    expect(repo.store, hasLength(3)); // work + breakfast + lunch
    final lunch = repo.store[lunchId]!;
    expect((lunch.startMinutes, lunch.endMinutes), (750, 795));
    expect(repo.store.values.where((b) => b.kind == 'dinner'), isEmpty);
    expect(repo.store['work'], same(work));
  });

  test('MealDraft.fromBlocks: none saved -> the three defaults, on; some saved '
      '-> their times, and the missing one off', () {
    expect(
      MealDraft.fromBlocks(const []).map((d) => (d.enabled, d.startMinutes)),
      [(true, 420), (true, 720), (true, 1080)],
    );
    final drafts = MealDraft.fromBlocks([
      CommitmentBlock(
        name: 'Lunch',
        daysOfWeek: kAllWeekdays,
        startMinutes: 750,
        endMinutes: 795,
        kind: 'lunch',
      ),
    ]);
    expect(
      drafts.map((d) => (d.slot, d.enabled, d.startMinutes, d.endMinutes)),
      [
        (MealSlot.breakfast, false, 420, 450),
        (MealSlot.lunch, true, 750, 795),
        (MealSlot.dinner, false, 1080, 1140),
      ],
    );
  });

  test('a meal window under 10 minutes is invalid; 10 is fine; off is never '
      'invalid', () {
    final d = MealDraft(
      slot: MealSlot.lunch,
      startMinutes: 720,
      endMinutes: 729,
    );
    expect(d.isValid, isFalse);
    d.endMinutes = 730;
    expect(d.isValid, isTrue);
    d
      ..endMinutes = 700
      ..enabled = false;
    expect(d.isValid, isTrue);
  });
}
