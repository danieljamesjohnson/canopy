import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/completion_log.dart';
import '../../data/models/goal.dart';
import '../../data/repositories/completion_log_repository.dart';
import '../../data/repositories/hive_completion_log_repository.dart';
import '../../dev/dev_clock.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/schedule_notifier.dart';
import '../../services/weekly_progress_service.dart';
import '../../widgets/adaptive_form_modal.dart';
import '../../widgets/quick_add_field.dart';
import 'goal_form_sheet.dart';
import 'widgets/add_kind_fork.dart';
import 'widgets/goal_card.dart';

/// Encouraging placeholder for the quick-add field; "8" is the reference the
/// frictionless-slate goal is measured by.
String _quickAddHint(int count) => count == 0
    ? 'Add a goal'
    : count < 8
    ? 'Add another ($count so far)'
    : 'Add another ($count goals)';

/// The Goals screen: one list, ordered by priority, headed `Priority order`.
///
/// [completionLogRepository] is an optional injectable repository so widget
/// tests can exercise the progress line without bootstrapping Hive — the same
/// seam `QuarterlyReviewScreen` uses (`quarterly_review_screen.dart:25-36`).
/// The screen owns the *read*; the arithmetic lives in the pure
/// [WeeklyProgressService] (UI-SPEC item 21).
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    super.key,
    CompletionLogRepository? completionLogRepository,
  }) : _completionLogRepository = completionLogRepository;

  final CompletionLogRepository? _completionLogRepository;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  /// Week-to-date progress per goal id. A null *value* means the goal has no
  /// weekly target (grey track); a missing *key* means not loaded yet.
  Map<String, double?> _weekProgress = {};

  ScheduleNotifier? _schedule;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<GoalsNotifier>().loadGoals();
      await _loadWeekProgress();
    });

    // Refresh progress whenever the schedule changes. This is not polish:
    // `router.dart` uses StatefulShellRoute.indexedStack, so this screen
    // stays mounted across tab switches — a mount-only read would keep
    // showing a stale bar after a chunk is completed on Today, which is the
    // class of false-failure CLAUDE.md trap #4 documents.
    try {
      _schedule = context.read<ScheduleNotifier>()
        ..addListener(_loadWeekProgress);
    } on ProviderNotFoundException {
      // The notifier is absent from the tree (widget tests that provide only
      // a GoalsNotifier). The refresh listener is simply not registered;
      // progress still loads once from the post-frame callback. Caught
      // narrowly on purpose — a bare `Exception` here would hide a real
      // production wiring failure behind a silent no-refresh.
      _schedule = null;
    }
  }

  @override
  void dispose() {
    _schedule?.removeListener(_loadWeekProgress);
    super.dispose();
  }

  /// Reads the completion log once and recomputes every goal's week fraction.
  ///
  /// One `getAll()` per refresh, not one `getByGoalId` per goal.
  Future<void> _loadWeekProgress() async {
    if (!mounted) return;
    // Capture provider refs and the repository BEFORE any await (Pitfall 6,
    // as stated in quarterly_review_screen.dart:73-75).
    final goals = context.read<GoalsNotifier>().goals;
    final repo =
        widget._completionLogRepository ?? HiveCompletionLogRepository();

    final List<CompletionLog> logs;
    try {
      logs = await repo.getAll();
    } catch (_) {
      // Hive boxes not yet open (test environment or cold start before init)
      // — today_screen.dart:259 catches the same thing for the same reason.
      // _weekProgress stays as it was; every track simply renders grey.
      return;
    }

    // DevClock.now() is DateTime.now() in release builds (DEV-03); using it
    // keeps the progress line consistent with the app's other clock-gated
    // surfaces, so time travel moves the week window too
    // (quarterly_review_screen.dart:98-100).
    final today = DevClock.now();
    const service = WeeklyProgressService();
    final next = <String, double?>{
      for (final g in goals) g.id: service.weekFractionFor(g, logs, today),
    };
    if (mounted) setState(() => _weekProgress = next);
  }

  /// The FAB's add path. Asks which kind is being added BEFORE any form
  /// exists (UI-SPEC item 24): the restorative door records a `RestorativeItem`
  /// from a name and an emoji and never shows a goal form.
  ///
  /// Scope, deliberate and surfaced: the fork is in front of the FAB **only**.
  /// The quick-add field above the list stays a goal-only path — typing into a
  /// field labelled "Add a goal" has already answered the question, and the
  /// round-two UAT asks the owner to rule on whether that narrowing is right.
  Future<void> _openAddSheet(BuildContext context) async {
    final kind = await showAddKindFork(context);
    if (kind == null || !context.mounted) return;
    if (kind == AddKind.restorative) {
      await showRestorativeQuickAdd(context);
      return;
    }
    if (!context.mounted) return;
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    await showAdaptiveFormModal(
      context: context,
      builder: (scrollController) => GoalFormSheet(
        scrollController: scrollController,
        isDialog: isDesktop,
      ),
    );
  }

  /// Editing an existing goal has already answered the fork's question, so this
  /// path must NOT fork (UI-SPEC item 24's boundary).
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

          // One list, not three type sections (UI-SPEC item 11). The
          // sortOrder tie-break is load-bearing, not decoration:
          // quickAddGoals leaves priorityWeight null (→ 0.5) for every goal
          // it creates, so a freshly-laid slate is entirely ties, and Dart's
          // List.sort is not documented as stable. Without the tie-break the
          // rank numbers could reshuffle between rebuilds — a worse
          // legibility defect than the one this screen is fixing.
          final ranked = [...notifier.goals]
            ..sort((a, b) {
              final byPriority = (b.priorityWeight ?? 0.5).compareTo(
                a.priorityWeight ?? 0.5,
              );
              return byPriority != 0
                  ? byPriority
                  : a.sortOrder.compareTo(b.sortOrder);
            });

          final allEmpty = notifier.goals.isEmpty;

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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: QuickAddField(
                        onSubmit: (names) => notifier.quickAddGoals(names),
                        autofocus: allEmpty,
                        multiAddNoun: 'goals',
                        addTooltip: 'Add goal',
                        // No helperText (UI-SPEC item 28 — instructions go).
                        // hintText stays: a placeholder is a label, not an
                        // instruction (item 29).
                        hintText: _quickAddHint(notifier.goals.length),
                      ),
                    ),
                  ),
                  if (allEmpty)
                    const SliverToBoxAdapter(child: _EmptyState())
                  else ...[
                    // Heading sliver: the screen names its own purpose, and
                    // nothing else. No explanatory sub-line — it was deleted,
                    // not reworded (OBVIOUS-02, UI-SPEC items 10, 28).
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Priority order',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    _buildReorderableList(context, notifier, ranked),
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

  Widget _buildReorderableList(
    BuildContext context,
    GoalsNotifier notifier,
    List<Goal> ranked,
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
        itemCount: ranked.length,
        itemBuilder: (ctx, i) => GoalCard(
          key: ValueKey(ranked[i].id),
          goal: ranked[i],
          rank: i + 1,
          weekProgress: _weekProgress[ranked[i].id],
          onTap: () => _openEditSheet(context, ranked[i]),
          onEdit: () => _openEditSheet(context, ranked[i]),
          onArchive: () => notifier.archiveGoal(ranked[i].id),
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
        // Phase 14 Plan 01 (GOALS-01): a drag writes priorityWeight via the
        // notifier call below, not sortOrder-only via `reorder`.
        // newIndex is post-removal — NO >oldIndex adjustment (Pitfall 1).
        // With one list the reordered ids ARE the full order — no splicing
        // back into a three-group display order, so this is a straight
        // pass-through.
        onReorderItem: (oldIndex, newIndex) async {
          final reordered = [...ranked];
          final item = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, item);
          await notifier.reorderAllWithPriority(
            reordered.map((g) => g.id).toList(),
          );
        },
      ),
    );
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
