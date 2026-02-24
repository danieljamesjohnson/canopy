import 'package:hive_ce/hive.dart';
import '../models/goal.dart';
import 'goal_repository.dart';

class HiveGoalRepository implements GoalRepository {
  Box<Goal> get _box => Hive.box<Goal>('goals');

  @override
  Future<List<Goal>> getAll() async => _box.values.toList();

  @override
  Future<Goal?> getById(String id) async =>
      _box.values.where((g) => g.id == id).firstOrNull;

  @override
  Future<void> save(Goal goal) async => _box.put(goal.id, goal);

  @override
  Future<void> delete(String id) async => _box.delete(id);

  @override
  Future<List<Goal>> getActive() async =>
      _box.values.where((g) => !g.isArchived).toList();
}
