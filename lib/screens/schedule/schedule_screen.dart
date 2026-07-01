import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/commitment_block.dart';
import '../../data/models/daily_schedule.dart';
import '../../data/models/energy_valence.dart';
import '../../data/models/goal.dart';
import '../../data/models/scheduled_chunk.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/restoratives_notifier.dart';
import '../../providers/schedule_notifier.dart';
import '../../utils/rationale_mapper.dart';
import '../../utils/time_format.dart';
import '../../widgets/adaptive_form_modal.dart';
import '../commitments/commitment_form_sheet.dart';
import 'widgets/chunk_card.dart';
import 'widgets/chunk_detail_sheet.dart';
import 'widgets/now_marker.dart';
import 'widgets/schedule_progress_bar.dart';
import 'widgets/swipeable_chunk_card.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  static const Map<int, Color> _moodColors = {
    1: Color(0xFF4A6275),
    2: Color(0xFF5C7A8A),
    3: Color(0xFF4A8C7A),
    4: Color(0xFF7AAF6A),
    5: Color(0xFFE8C547),
  };

  @override
  Widget build(BuildContext context) {
    final scheduleNotifier = context.watch<ScheduleNotifier>();

    if (!scheduleNotifier.hasScheduleToday) {
      return _buildEmptyState(context);
    }

    final schedule = scheduleNotifier.todaySchedule!;
    final mood = scheduleNotifier.moodIndex ?? 3;
    final moodColor = _moodColors[mood] ?? _moodColors[3]!;

    // Partition chunks: active (not skipped) and skipped.
    final activeChunks = schedule.chunks.where((c) => !c.isSkipped).toList();
    final skippedChunks = schedule.chunks.where((c) => c.isSkipped).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        backgroundColor: moodColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add an event',
            onPressed: () => _openAddEvent(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-check-in',
            onPressed: () => context.push('/schedule/checkin'),
          ),
          // Focus entry affordance — passes first unresolved work chunk id.
          IconButton(
            icon: const Icon(Icons.center_focus_strong_outlined),
            tooltip: 'Start focus',
            onPressed: () {
              final firstChunk = schedule.chunks
                  .where(
                    (c) =>
                        c.chunkType == ChunkType.work &&
                        !c.isCompleted &&
                        !c.isSkipped,
                  )
                  .firstOrNull;
              if (firstChunk != null) {
                context.push('/focus', extra: firstChunk.id);
              }
            },
          ),
          if (_resolvedWorkChunkRatio(schedule) >= 0.5)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'summary') context.push('/summary');
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'summary',
                  child: Text('View your day'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          ScheduleProgressBar(schedule: schedule, moodColor: moodColor),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  children:
                      [
                        // Low-energy days (mood 1–2) resurface the user's
                        // restoratives — gentle, no-pressure suggestions that
                        // are deliberately NOT scheduled work.
                        if (mood <= 2) _buildRestorativeSuggestions(context),
                      ] +
                      _buildActiveChunkItems(context, activeChunks) +
                      [
                        // "Skipped today" expansion tile — hidden when no skipped chunks.
                        if (skippedChunks.isNotEmpty)
                          _buildSkippedSection(context, skippedChunks),
                      ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Low-energy-day surface for restoratives. Rendered only when mood ≤ 2.
  /// Lists the user's saved restorative activities as gentle suggestions; if
  /// they have none yet, shows a soft prompt to set some up. These never affect
  /// the schedule — they are the deliberate non-goal counterpart to the plan.
  Widget _buildRestorativeSuggestions(BuildContext context) {
    final restoratives = context.watch<RestorativesNotifier>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (restoratives.isEmpty) {
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        color: scheme.surfaceContainerHighest,
        child: ListTile(
          leading: Icon(Icons.spa_outlined, color: scheme.primary),
          title: const Text('Low on energy today?'),
          subtitle: const Text(
            'Add a few things that restore you — they\'ll show up here on '
            'days like this.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/restoratives'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A lighter day — here\'s what restores you',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in restoratives.items)
                  Chip(
                    avatar: (item.emojiTag != null && item.emojiTag!.isNotEmpty)
                        ? Text(
                            item.emojiTag!,
                            style: const TextStyle(fontSize: 16),
                          )
                        : null,
                    label: Text(item.name),
                    backgroundColor: scheme.secondaryContainer,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the active-chunk list items with a NowMarker inserted before the
  /// first unresolved work chunk at or after the current wall time (SCHED-02).
  ///
  /// Insertion rules:
  /// - Scan activeChunks for unresolved work chunks.
  /// - `nowMarkerIndex` starts as the first unresolved work chunk (fallback).
  /// - It advances to the first unresolved work chunk whose
  ///   displayStartMinutes >= nowMinutes (time-anchored position).
  /// - When no unresolved work chunk exists, nowMarkerIndex stays null and
  ///   no NowMarker is rendered (per RESEARCH Open Question 1).
  List<Widget> _buildActiveChunkItems(
    BuildContext context,
    List<ScheduledChunk> activeChunks,
  ) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    int? nowMarkerIndex;
    for (int i = 0; i < activeChunks.length; i++) {
      final c = activeChunks[i];
      if (c.chunkType != ChunkType.work || c.isCompleted || c.isSkipped) {
        continue;
      }

      final start = c.displayStartMinutes;
      if (start == null || start < nowMinutes) {
        // Chunk is either untimed or already in the past; treat it as current
        // until we find one that is in the future.
        nowMarkerIndex = i;
      } else {
        // First chunk at or after now — place marker here and stop.
        nowMarkerIndex = i;
        break;
      }
    }

    final List<Widget> items = [];
    for (int i = 0; i < activeChunks.length; i++) {
      if (i == nowMarkerIndex) items.add(const NowMarker());
      items.add(_buildSwipeableCard(context, activeChunks[i]));
    }
    return items;
  }

  /// Returns the ratio of resolved (completed or skipped) work chunks to
  /// total work chunks. Returns 0.0 when there are no work chunks.
  double _resolvedWorkChunkRatio(DailySchedule schedule) {
    final workChunks = schedule.chunks
        .where((c) => c.chunkType == ChunkType.work)
        .toList();
    if (workChunks.isEmpty) return 0.0;
    final resolved = workChunks
        .where((c) => c.isCompleted || c.isSkipped)
        .length;
    return resolved / workChunks.length;
  }

  Widget _buildSwipeableCard(BuildContext context, ScheduledChunk chunk) {
    final goalColor = _lookupGoalColor(context, chunk);
    final goalName = _lookupGoalName(context, chunk);
    final displayRationale = _toDisplayRationale(chunk.rationale);
    return SwipeableChunkCard(
      chunk: chunk,
      goalColor: goalColor,
      goalName: goalName,
      displayRationale: displayRationale,
      goalPriorityWeight: _lookupGoalPriorityWeight(context, chunk),
      goalEmojiTag: _lookupGoalEmojiTag(context, chunk),
      goalValence: _lookupGoalValence(context, chunk),
      // onTap wired in Task 2 (_openDetailSheet). Resolved chunks stay null.
      onTap: (chunk.isCompleted || chunk.isSkipped)
          ? null
          : () => _openDetailSheet(
              context,
              chunk,
              goalColor,
              goalName,
              displayRationale,
            ),
    );
  }

  Widget _buildSkippedSection(
    BuildContext context,
    List<ScheduledChunk> skippedChunks,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        title: Text(
          'Skipped today (${skippedChunks.length})',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: EdgeInsets.zero,
        children: skippedChunks.map((chunk) {
          final goalColor = _lookupGoalColor(context, chunk);
          return ChunkCard(
            chunk: chunk,
            goalColor: goalColor,
            goalName: _lookupGoalName(context, chunk),
            displayRationale: _toDisplayRationale(chunk.rationale),
            goalPriorityWeight: _lookupGoalPriorityWeight(context, chunk),
            goalEmojiTag: _lookupGoalEmojiTag(context, chunk),
            goalValence: _lookupGoalValence(context, chunk),
          );
        }).toList(),
      ),
    );
  }

  /// Returns the single [Goal] for a chunk, or null for commitment-anchored
  /// chunks (goalId == null) or when the goal is not found (IN-01).
  /// Callers use this instead of repeating the linear scan per attribute.
  Goal? _resolveGoal(BuildContext context, ScheduledChunk chunk) {
    if (chunk.goalId == null) return null;
    return context
        .read<GoalsNotifier>()
        .goals
        .where((g) => g.id == chunk.goalId)
        .firstOrNull;
  }

  /// Resolves goal color for a chunk by looking up its goalId in GoalsNotifier.
  Color? _lookupGoalColor(BuildContext context, ScheduledChunk chunk) {
    final goal = _resolveGoal(context, chunk);
    if (goal?.color != null) return hexToColor(goal!.color!);
    return null;
  }

  /// Resolves goal name for a chunk by looking up its goalId in GoalsNotifier.
  /// Returns null for commitment-anchored chunks (no goalId) so they display
  /// the block name from chunk.rationale instead.
  String? _lookupGoalName(BuildContext context, ScheduledChunk chunk) =>
      _resolveGoal(context, chunk)?.name;

  /// Resolves goal priority weight for a chunk by looking up its goalId in
  /// GoalsNotifier. Returns null for commitment chunks (goalId == null) so
  /// they show no priority badge.
  double? _lookupGoalPriorityWeight(
    BuildContext context,
    ScheduledChunk chunk,
  ) => _resolveGoal(context, chunk)?.priorityWeight;

  /// Resolves goal energy valence for a chunk by looking up its goalId in
  /// GoalsNotifier. Returns null for commitment chunks (goalId == null) so
  /// they show no valence chip (T-19-05).
  EnergyValence? _lookupGoalValence(
    BuildContext context,
    ScheduledChunk chunk,
  ) => _resolveGoal(context, chunk)?.energyValence;

  /// Resolves goal emoji tag for a chunk by looking up its goalId in
  /// GoalsNotifier. Returns null for commitment chunks (goalId == null) so
  /// they show no emoji prefix (T-19-05).
  String? _lookupGoalEmojiTag(BuildContext context, ScheduledChunk chunk) =>
      _resolveGoal(context, chunk)?.emojiTag;

  /// Maps the raw generator rationale string to a human-readable display
  /// string. Delegates to the shared [toDisplayRationale] helper so the
  /// schedule, detail sheet, and focus screen render rationales identically.
  static String _toDisplayRationale(String rationale) =>
      toDisplayRationale(rationale);

  /// Opens the ChunkDetailSheet for the given work chunk. Added in Task 2
  /// (Plan 08-02); referenced here so _buildSwipeableCard can wire the onTap.
  void _openDetailSheet(
    BuildContext context,
    ScheduledChunk chunk,
    Color? goalColor,
    String? goalName,
    String displayRationale,
  ) {
    final notifier = context.read<ScheduleNotifier>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChunkDetailSheet(
        chunk: chunk,
        notifier: notifier,
        goalColor: goalColor,
        goalName: goalName,
        displayRationale: displayRationale,
      ),
    );
  }

  /// Opens the commitment form pre-set to a one-off event on today, straight
  /// from the Today screen — where a human actually looks to enter their
  /// schedule. On save, the event is inserted into today's schedule in place
  /// (progress preserved) so it appears immediately without a re-check-in.
  void _openAddEvent(BuildContext context) {
    final scheduleNotifier = context.read<ScheduleNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    showAdaptiveFormModal(
      context: context,
      builder: (scrollController) => CommitmentFormSheet(
        scrollController: scrollController,
        initialOneOff: true,
        initialDate: today,
        onSaved: (CommitmentBlock block) async {
          final inserted = await scheduleNotifier.addEventToday(block);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                inserted
                    ? 'Added "${block.name}" to today'
                    : 'Added "${block.name}" to your commitments',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: Column(
        children: [
          if (kIsWeb)
            MaterialBanner(
              content: const Text(
                'Start your morning check-in to build today\'s schedule.',
              ),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              contentTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              actions: [
                TextButton(
                  onPressed: () => context.push('/schedule/checkin'),
                  child: const Text('Start check-in'),
                ),
              ],
            ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wb_sunny_outlined,
                      size: 64,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Plan your day in 30 seconds.',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us how you\'re feeling and we\'ll build your schedule.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.push('/schedule/checkin'),
                      child: const Text('Start your day'),
                    ),
                    const SizedBox(height: 8),
                    // Let a human put an event on today WITHOUT first doing a
                    // mood check-in — addEventToday creates a minimal day.
                    TextButton.icon(
                      onPressed: () => _openAddEvent(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add an event'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
