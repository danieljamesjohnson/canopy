import '../models/goal.dart';

abstract class GoalRepository {
  Future<List<Goal>> getAll();
  Future<Goal?> getById(String id);
  Future<void> save(Goal goal);
  Future<void> delete(String id);
  Future<List<Goal>> getActive(); // excludes archived
}
