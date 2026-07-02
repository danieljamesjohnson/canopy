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
                  // Frictionless slate entry (always available): type a name,
                  // press Enter, keep going. The full form (FAB) stays for
                  // refining type/energy/etc.
                  SliverToBoxAdapter(
                    child: _QuickAddBar(
                      goalCount:
                          timeTargetGoals.length +
                          outcomeGoals.length +
                          habitGoals.length,
                      onSubmit: (names) => notifier.quickAddGoals(names),
                    ),
                  ),
                  if (allEmpty)
                    const SliverToBoxAdapter(child: _EmptyState())
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Lay down your slate',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Type a goal above and press Enter — keep going to add your '
              'whole week. You can refine type, priority, and energy later by '
              'tapping any goal.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky, always-available rapid entry. Type a name and press Enter to add a
/// goal with sensible defaults; the field clears and keeps focus so a full
/// slate goes in with type-Enter-type-Enter. Also accepts a pasted,
/// newline-separated list (each line becomes a goal).
class _QuickAddBar extends StatefulWidget {
  const _QuickAddBar({required this.goalCount, required this.onSubmit});

  /// Current number of active goals — drives the encouraging progress hint.
  final int goalCount;

  /// Adds the given goal names; returns how many were actually created.
  final Future<int> Function(List<String> names) onSubmit;

  @override
  State<_QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<_QuickAddBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  // Drop-free entry: completed goal names are queued and a single worker drains
  // the queue serially. A prior save being in-flight must NEVER cause an
  // already-stripped line to be lost — so we queue instead of guarding-and-
  // bailing. This holds even when goals are entered faster than each save.
  final List<String> _queue = [];
  bool _draining = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Queue [names] for saving and ensure the drain worker is running. Blank
  /// names are skipped. Never drops, regardless of in-flight saves.
  void _enqueue(Iterable<String> names) {
    _queue.addAll(names.map((n) => n.trim()).where((n) => n.isNotEmpty));
    _drain();
  }

  /// Serially persist everything in the queue, then keep focus for the next
  /// goal. Reentrancy-guarded by [_draining]; anything enqueued mid-drain is
  /// picked up by the loop before it exits, so no entry is ever dropped.
  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    var totalAdded = 0;
    while (_queue.isNotEmpty) {
      final batch = List<String>.from(_queue);
      _queue.clear();
      totalAdded += await widget.onSubmit(batch);
    }
    _draining = false;
    if (!mounted) return;
    // Keep the keyboard up and the cursor ready for the next goal.
    _focusNode.requestFocus();
    if (totalAdded > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $totalAdded goals'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// The field is multi-line so a pasted newline-separated slate survives (a
  /// single-line field silently strips newlines and collapses the paste into
  /// one goal). Every COMPLETE line — i.e. text followed by a newline, whether
  /// from pressing Enter or from a paste — is queued immediately; any trailing
  /// text with no newline stays in the field as the in-progress goal. This
  /// makes Enter act as "add" for typing AND explodes a paste into N goals.
  void _onChanged(String value) {
    final lastNewline = value.lastIndexOf('\n');
    if (lastNewline < 0) return; // still typing the current line
    final complete = value.substring(0, lastNewline);
    final remainder = value.substring(lastNewline + 1);
    // Strip the committed lines from the field WITHOUT triggering onChanged
    // (programmatic controller edits don't re-fire the TextField callback).
    _controller.value = TextEditingValue(
      text: remainder,
      selection: TextSelection.collapsed(offset: remainder.length),
    );
    _enqueue(complete.split('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.goalCount;
    // Encourage a full slate; "8" is the reference the whole job is measured by.
    final hint = count == 0
        ? 'Add a goal'
        : count < 8
        ? 'Add another ($count so far)'
        : 'Add another ($count goals)';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: count == 0,
        // Multi-line so pasted newlines survive; grows a little, then scrolls.
        minLines: 1,
        maxLines: 4,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        onChanged: _onChanged,
        // Fallback commit path (e.g. desktop "Done" that doesn't insert a
        // newline): flush whatever is in the field and clear it.
        onSubmitted: (value) {
          _controller.clear();
          _enqueue(value.split('\n'));
        },
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.add),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: IconButton(
            tooltip: 'Add goal',
            icon: const Icon(Icons.subdirectory_arrow_left),
            onPressed: () {
              final text = _controller.text;
              _controller.clear();
              _enqueue(text.split('\n'));
            },
          ),
          helperText: 'Enter after each, or paste a list — refine details later',
          helperStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
