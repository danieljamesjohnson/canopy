import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/goal.dart';
import '../../providers/goals_notifier.dart';
import '../../widgets/adaptive_form_modal.dart';
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
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    showAdaptiveFormModal(
      context: context,
      builder: (scrollController) => GoalFormSheet(
        scrollController: scrollController,
        isDialog: isDesktop,
      ),
    );
  }

  void _openEditSheet(BuildContext context, Goal goal) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    showAdaptiveFormModal(
      context: context,
      builder: (scrollController) => GoalFormSheet(
        scrollController: scrollController,
        goal: goal,
        isDialog: isDesktop,
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
              if (value == 'restoratives') {
                context.push('/restoratives');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'archived', child: Text('View archived')),
              PopupMenuItem(
                value: 'commitments',
                child: Text('Commitment blocks'),
              ),
              PopupMenuItem(
                value: 'restoratives',
                child: Text('What restores you'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<GoalsNotifier>(
        builder: (context, notifier, _) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final timeTargetGoals = notifier.timeTargetGoals;
          final outcomeGoals = notifier.outcomeGoals;
          final habitGoals = notifier.habitGoals;

          final allEmpty =
              timeTargetGoals.isEmpty &&
              outcomeGoals.isEmpty &&
              habitGoals.isEmpty;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: CustomScrollView(
                slivers: [
                  if (allEmpty)
                    const SliverFillRemaining(child: _EmptyState())
                  else ...[
                    // Heading sliver (GOALS-01): purpose + affordance hint.
                    // Only shown on the non-empty path.
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Your goals',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Drag to prioritize. Tap to edit.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
              ),
            ),
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
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: colorScheme.primary),
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
    // Phase 14 Plan 01 (GOALS-01): drag handle visible on BOTH desktop and
    // mobile using Icons.drag_indicator (six-dot grid). Desktop gets Tooltip +
    // 44×44 touch target + AnimatedOpacity at 0.6. Mobile gets a lighter
    // outlineVariant icon, always visible.
    final isMobileTouch =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
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
          onEdit: () => _openEditSheet(context, group[i]),
          onArchive: () => notifier.archiveGoal(group[i].id),
          trailing: isMobileTouch
              ? ReorderableDelayedDragStartListener(
                  index: i,
                  child: Semantics(
                    label: 'Drag to reorder',
                    button: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 20,
                        color: colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                )
              : Tooltip(
                  message: 'Drag to reorder',
                  child: ReorderableDelayedDragStartListener(
                    index: i,
                    child: Semantics(
                      label: 'Drag to reorder',
                      button: false,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 120),
                            opacity: 0.6,
                            child: Icon(
                              Icons.drag_indicator,
                              color: colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        // Phase 14 Plan 01 (GOALS-01): reorder writes priorityWeight via
        // reorderAllWithPriority (not sortOrder-only via reorder).
        // newIndex is post-removal — NO >oldIndex adjustment (Pitfall 1).
        onReorderItem: (oldIndex, newIndex) async {
          final reorderedGroup = [...group];
          final item = reorderedGroup.removeAt(oldIndex);
          reorderedGroup.insert(newIndex, item);
          final allOrdered = _buildFullOrderedIds(
            notifier,
            type,
            reorderedGroup,
          );
          await notifier.reorderAllWithPriority(allOrdered);
        },
      ),
    );
  }

  /// Reconstructs the flat goal ID list across all three type groups when a
  /// drag completes within one type group (Pitfall 2: order must match display
  /// order — timeTarget → outcome → habit).
  List<String> _buildFullOrderedIds(
    GoalsNotifier notifier,
    GoalType type,
    List<Goal> reorderedGroup,
  ) {
    final timeTargetIds = type == GoalType.timeTarget
        ? reorderedGroup.map((g) => g.id).toList()
        : notifier.timeTargetGoals.map((g) => g.id).toList();
    final outcomeIds = type == GoalType.outcome
        ? reorderedGroup.map((g) => g.id).toList()
        : notifier.outcomeGoals.map((g) => g.id).toList();
    final habitIds = type == GoalType.habit
        ? reorderedGroup.map((g) => g.id).toList()
        : notifier.habitGoals.map((g) => g.id).toList();
    return [...timeTargetIds, ...outcomeIds, ...habitIds];
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
          Text('No goals yet', style: Theme.of(context).textTheme.titleMedium),
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
