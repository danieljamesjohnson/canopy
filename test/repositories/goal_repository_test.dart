import 'package:flutter_test/flutter_test.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/goal_repository.dart';

/// In-memory implementation used only in tests.
class InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};

  @override
  Future<List<Goal>> getAll() async => _store.values.toList();

  @override
  Future<Goal?> getById(String id) async => _store[id];

  @override
  Future<void> save(Goal goal) async => _store[goal.id] = goal;

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}

void main() {
  late GoalRepository repo;

  setUp(() {
    repo = InMemoryGoalRepository();
  });

  test('getAll returns empty list when no goals saved', () async {
    final goals = await repo.getAll();
    expect(goals, isEmpty);
  });

  test('save and getById round-trip', () async {
    final goal = Goal(name: 'Test Goal', goalTypeIndex: 0);
    await repo.save(goal);
    final fetched = await repo.getById(goal.id);
    expect(fetched, isNotNull);
    expect(fetched!.name, equals('Test Goal'));
  });

  test('getActive excludes archived goals', () async {
    final active = Goal(name: 'Active', goalTypeIndex: 1);
    final archived = Goal(name: 'Archived', goalTypeIndex: 2)
      ..isArchived = true;
    await repo.save(active);
    await repo.save(archived);
    final result = await repo.getActive();
    expect(result.length, equals(1));
    expect(result.first.name, equals('Active'));
  });

  test('delete removes goal from store', () async {
    final goal = Goal(name: 'To Delete', goalTypeIndex: 0);
    await repo.save(goal);
    await repo.delete(goal.id);
    final fetched = await repo.getById(goal.id);
    expect(fetched, isNull);
  });

  test('Goal IDs are UUID v4 strings (not empty, not integers)', () async {
    final goal = Goal(name: 'UUID Test', goalTypeIndex: 0);
    expect(goal.id, isNotEmpty);
    expect(goal.id.length, equals(36)); // UUID v4 is 36 chars with hyphens
    expect(
      goal.id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
