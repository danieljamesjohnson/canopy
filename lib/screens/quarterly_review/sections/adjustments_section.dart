import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/goal.dart';
import '../../../data/models/quarterly_snapshot.dart';
import '../../../data/repositories/hive_quarterly_snapshot_repository.dart';
import '../../../data/repositories/quarterly_snapshot_repository.dart';
import '../../../providers/goals_notifier.dart';
import '../../../utils/time_format.dart';
import '../widgets/goal_adjustment_tile.dart';

/// Section 3 of the quarterly review: drag-to-reorder goal priorities,
/// inline archive suggestions for underused goals, and a "Finish review" button
/// that persists the [QuarterlySnapshot] and updates [GoalsNotifier] priorities.
class AdjustmentsSection extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  AdjustmentsSection({
    super.key,
    required this.goals,
    required this.completionRates,
    required this.reflectionAnswers,
    required this.periodStartYmd,
    required this.periodEndYmd,
    required this.goalChunkTotals,
    QuarterlySnapshotRepository? snapshotRepository,
  }) : _snapshotRepository =
           snapshotRepository ?? HiveQuarterlySnapshotRepository();

  final List<Goal> goals;
  final Map<String, double> completionRates;
  final List<String> reflectionAnswers;
  final String periodStartYmd;
  final String periodEndYmd;
  final Map<String, int> goalChunkTotals;
  final QuarterlySnapshotRepository _snapshotRepository;

  @override
  State<AdjustmentsSection> createState() => _AdjustmentsSectionState();
}

class _AdjustmentsSectionState extends State<AdjustmentsSection> {
  late List<Goal> _orderedGoals;
  final Set<String> _archivedIds = {};

  /// Goals whose archive prompt was dismissed by tapping "Keep".
  final Set<String> _dismissedPrompts = {};

  bool _isSaving = false;
  String? _saveError;

  /// Pending snapshot cached across retries so a re-tap of "Retry" reuses
  /// the same `QuarterlySnapshot.id` and `_box.put(id, snapshot)` overwrites
  /// the prior (possibly-failed) row instead of minting a duplicate
  /// quarter — protecting the append-only history the call site comment
  /// promises. See CR-02 in 06-REVIEW.md.
  QuarterlySnapshot? _pendingSnapshot;

  @override
  void initState() {
    super.initState();
    _orderedGoals = List.of(widget.goals);
  }

  bool _showArchivePrompt(Goal goal) =>
      !_archivedIds.contains(goal.id) &&
      !_dismissedPrompts.contains(goal.id) &&
      (widget.completionRates[goal.id] ?? 0.0) <= 0.20;

  Color _colorForGoal(Goal goal, int index) {
    if (goal.color != null) return hexToColor(goal.color!);
    const palette = GoalsNotifier.colorPalette;
    return Color(
      int.parse(palette[index % palette.length].replaceFirst('#', '0xFF')),
    );
  }

  Future<void> _finish() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final notifier = context.read<GoalsNotifier>();

      // Archive flagged goals. `archiveGoal` is idempotent against an
      // already-archived id (a no-op on retry), so re-running this loop
      // after a partial failure is safe.
      for (final id in _archivedIds) {
        await notifier.archiveGoal(id);
      }

      // Persist new sort order (excluding archived)
      final orderedIds = _orderedGoals
          .where((g) => !_archivedIds.contains(g.id))
          .map((g) => g.id)
          .toList();
      await notifier.reorderAllWithPriority(orderedIds);

      // Build priority snapshot map
      final prioritySnapshot = <String, int>{};
      for (var i = 0; i < orderedIds.length; i++) {
        prioritySnapshot[orderedIds[i]] = i;
      }

      // Persist QuarterlySnapshot (append-only — never overwrite)
      //
      // CR-02: cache the constructed `QuarterlySnapshot` across retries so
      // a re-tap of "Retry" reuses the same `id`. `_box.put(id, snapshot)`
      // is keyed on the snapshot id, so re-running with the same id
      // overwrites the prior failed row instead of minting a duplicate
      // quarterly history entry. The mutable fields are re-stamped on
      // every attempt so the snapshot reflects the latest in-memory
      // archive/reorder state.
      _pendingSnapshot ??= QuarterlySnapshot(
        periodStartYmd: widget.periodStartYmd,
        periodEndYmd: widget.periodEndYmd,
      );
      _pendingSnapshot!
        ..goalChunkTotals = Map.of(widget.goalChunkTotals)
        ..reflectionAnswers = List.of(widget.reflectionAnswers)
        ..goalPrioritySnapshot = prioritySnapshot
        ..archivedGoalIds = _archivedIds.toList();

      await widget._snapshotRepository.append(_pendingSnapshot!);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      // Log the original exception so a silent quarterly-review failure
      // is not opaque to support. `catch (_)` would hide the cause.
      debugPrint('AdjustmentsSection._finish failed: $e\n$st');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError =
              "Something went wrong saving your review. Your answers are not lost \u2014 try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final visibleGoals = _orderedGoals
        .where((g) => !_archivedIds.contains(g.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Set your priorities for next quarter',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Drag to reorder. Your schedule will reflect this tomorrow.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        // Reorderable goal list. Drag handle visibility is platform-gated per
        // UI-SPEC §Drag Handle Visibility — opacity 0.6 on desktop, hidden
        // on mobile (long-press-drag still works either way).
        Expanded(
          child: Builder(
            builder: (context) {
              final isMobileTouch =
                  defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS;
              return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: visibleGoals.length,
                itemBuilder: (context, i) {
                  final goal = visibleGoals[i];
                  final globalIndex = _orderedGoals.indexWhere(
                    (g) => g.id == goal.id,
                  );
                  return GoalAdjustmentTile(
                    key: ValueKey(goal.id),
                    goal: goal,
                    goalColor: _colorForGoal(goal, globalIndex),
                    index: i,
                    completionRate: widget.completionRates[goal.id],
                    showArchivePrompt: _showArchivePrompt(goal),
                    onArchive: () => setState(() => _archivedIds.add(goal.id)),
                    onKeep: () =>
                        setState(() => _dismissedPrompts.add(goal.id)),
                    dragHandleVisible: !isMobileTouch,
                  );
                },
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final visible = _orderedGoals
                        .where((g) => !_archivedIds.contains(g.id))
                        .toList();
                    final item = visible.removeAt(oldIndex);
                    visible.insert(newIndex, item);
                    final archived = _orderedGoals
                        .where((g) => _archivedIds.contains(g.id))
                        .toList();
                    _orderedGoals = [...visible, ...archived];
                  });
                },
              );
            },
          ),
        ),

        // Error message
        if (_saveError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _saveError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                TextButton(
                  onPressed: _isSaving ? null : _finish,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),

        // Finish review button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _finish,
            child: Text(_isSaving ? 'Saving...' : 'Finish review'),
          ),
        ),
      ],
    );
  }
}
