import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/goal.dart';
import '../../providers/goals_notifier.dart';
import 'goal_form_sheet.dart';
import 'widgets/goal_card.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<GoalsNotifier>().loadGoals(),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        expand: false,
        snap: true,
        snapSizes: const [0.6, 1.0],
        builder: (ctx, scrollController) => GoalFormSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _openEditSheet(BuildContext context, Goal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        expand: false,
        snap: true,
        snapSizes: const [0.6, 1.0],
        builder: (ctx, scrollController) => GoalFormSheet(
          scrollController: scrollController,
          goal: goal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'archived') {
                context.push('/goals/archived');
              }
              if (value == 'commitments') {
                context.push('/commitments');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'archived',
                child: Text('View archived'),
              ),
              PopupMenuItem(
                value: 'commitments',
                child: Text('Commitment blocks'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<GoalsNotifier>(
        builder: (context, notifier, _) {
          final timeTargetGoals = notifier.timeTargetGoals;
          final outcomeGoals = notifier.outcomeGoals;
          final habitGoals = notifier.habitGoals;

          final allEmpty =
              timeTargetGoals.isEmpty &&
              outcomeGoals.isEmpty &&
              habitGoals.isEmpty;

          return CustomScrollView(
            slivers: [
              if (allEmpty)
                const SliverFillRemaining(child: _EmptyState())
              else ...[
                if (timeTargetGoals.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Regular time'),
                  _buildReorderableSection(
                    context,
                    notifier,
                    timeTargetGoals,
                    GoalType.timeTarget,
                  ),
                ],
                if (outcomeGoals.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Working toward'),
                  _buildReorderableSection(
                    context,
                    notifier,
                    outcomeGoals,
                    GoalType.outcome,
                  ),
                ],
                if (habitGoals.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Daily habits'),
                  _buildReorderableSection(
                    context,
                    notifier,
                    habitGoals,
                    GoalType.habit,
                  ),
                ],
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add goal'),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildReorderableSection(
    BuildContext context,
    GoalsNotifier notifier,
    List<Goal> group,
    GoalType type,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: group.length,
        itemBuilder: (ctx, i) => GoalCard(
          key: ValueKey(group[i].id),
          goal: group[i],
          onTap: () => _openEditSheet(context, group[i]),
          trailing: ReorderableDelayedDragStartListener(
            index: i,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.drag_handle, color: colorScheme.outline),
            ),
          ),
        ),
        onReorder: (oldIndex, newIndex) =>
            notifier.reorder(type, oldIndex, newIndex),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No goals yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first goal',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
