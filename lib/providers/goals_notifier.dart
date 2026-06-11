import 'package:flutter/foundation.dart';
import '../data/models/goal.dart';
import '../data/repositories/goal_repository.dart';
import '../data/repositories/hive_goal_repository.dart';

class GoalsNotifier extends ChangeNotifier {
  /// Construct a GoalsNotifier. [repository] defaults to
  /// `HiveGoalRepository()` (production). Pass an in-memory repository
  /// in tests to avoid Hive initialisation.
  GoalsNotifier({GoalRepository? repository})
    : _repository = repository ?? HiveGoalRepository();

  final GoalRepository _repository;

  List<Goal> _goals = [];

  List<Goal> get goals => List.unmodifiable(_goals);

  List<Goal> get timeTargetGoals =>
      _goals.where((g) => g.goalType == GoalType.timeTarget).toList();

  List<Goal> get outcomeGoals =>
      _goals.where((g) => g.goalType == GoalType.outcome).toList();

  List<Goal> get habitGoals =>
      _goals.where((g) => g.goalType == GoalType.habit).toList();

  static const List<String> _colorPalette = [
    '#4CAF50',
    '#2196F3',
    '#FF9800',
    '#9C27B0',
    '#F44336',
    '#00BCD4',
    '#FF5722',
    '#607D8B',
  ];

  /// Public read-only access to the color palette for use in chart widgets.
  static const List<String> colorPalette = _colorPalette;

  /// Returns next color from palette based on current goals count.
  String autoColor() => _colorPalette[_goals.length % _colorPalette.length];

  /// Loads all active (non-archived) goals, sorted by sortOrder.
  Future<void> loadGoals() async {
    final active = await _repository.getActive();
    active.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _goals = active;
    notifyListeners();
  }

  /// Saves a goal (create or update) and reloads the list.
  Future<void> saveGoal(Goal goal) async {
    await _repository.save(goal);
    await loadGoals();
  }

  /// Archives a goal by id — sets isArchived = true, does NOT delete.
  Future<void> archiveGoal(String id) async {
    final goal = await _repository.getById(id);
    if (goal == null) return;
    goal.isArchived = true;
    await _repository.save(goal);
    await loadGoals();
  }

  /// Returns archived goals sorted by name. Does NOT call notifyListeners.
  Future<List<Goal>> getArchivedGoals() async {
    final all = await _repository.getAll();
    final archived = all.where((g) => g.isArchived).toList();
    archived.sort((a, b) => a.name.compareTo(b.name));
    return archived;
  }

  /// Reorders all goals across types using a flat ordered ID list.
  /// Sets sortOrder = index position for each goal found in [orderedGoalIds].
  Future<void> reorderAll(List<String> orderedGoalIds) async {
    for (var i = 0; i < orderedGoalIds.length; i++) {
      final goal = _goals.where((g) => g.id == orderedGoalIds[i]).firstOrNull;
      if (goal != null) {
        goal.sortOrder = i;
        await _repository.save(goal);
      }
    }
    await loadGoals();
  }

  /// Reorders all goals using a flat ordered ID list, writing both [sortOrder]
  /// and [priorityWeight] so the schedule generator picks up priority changes.
  ///
  /// Linear spread: index 0 (top) → 0.75, index n-1 (bottom) → 0.25.
  /// Single goal: weight = 0.75. Weights are monotonically distinct.
  ///
  /// Formula: priorityWeight[i] = high - (high - low) * i / (n - 1)  when n > 1
  ///          priorityWeight[0] = high                                 when n == 1
  Future<void> reorderAllWithPriority(List<String> orderedIds) async {
    const double high = 0.75;
    const double low = 0.25;
    final n = orderedIds.length;
    for (var i = 0; i < n; i++) {
      final goal = _goals.where((g) => g.id == orderedIds[i]).firstOrNull;
      if (goal != null) {
        goal.sortOrder = i;
        goal.priorityWeight = n <= 1 ? high : high - (high - low) * i / (n - 1);
        await _repository.save(goal);
      }
    }
    await loadGoals();
  }

  /// Reorders goals within a [type] group.
  ///
  /// [oldIndex] and [newIndex] are indices within the type-filtered list.
  /// [newIndex] is the post-removal target index (as supplied by
  /// `ReorderableListView.onReorderItem`), so no off-by-one adjustment is
  /// applied here. After reorder, sortOrder values are updated and saved.
  Future<void> reorder(GoalType type, int oldIndex, int newIndex) async {
    final group = _goals.where((g) => g.goalType == type).toList();

    final item = group.removeAt(oldIndex);
    group.insert(newIndex, item);

    for (var i = 0; i < group.length; i++) {
      group[i].sortOrder = i;
      await _repository.save(group[i]);
    }

    await loadGoals();
  }
}
