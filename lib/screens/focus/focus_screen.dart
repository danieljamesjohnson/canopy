import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/scheduled_chunk.dart';
import '../../providers/schedule_notifier.dart';
import '../../utils/rationale_mapper.dart';
import '../../utils/time_format.dart';
import '../../providers/goals_notifier.dart';

/// Full-screen companion focus mode for a single work chunk.
///
/// Route: `/focus` — outside [StatefulShellRoute], no bottom nav bar
/// (same pattern as `/summary`).
///
/// Receives the target [chunkId] via GoRoute's `state.extra`. On arrival,
/// if the chunk is already resolved (completed/skipped), pops immediately.
///
/// Offers an optional 25-minute [Timer.periodic] countdown the user can
/// start, pause, or skip. On timer completion or an explicit "Done early"
/// or "Skip timer", calls [ScheduleNotifier.markComplete] and surfaces a
/// break suggestion derived from the next chunk in the schedule.
///
/// READ-04 — Phase 8.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, required this.chunkId});

  final String chunkId;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  Timer? _timer;
  int _secondsRemaining = 1500; // 25 * 60
  bool _isRunning = false;
  bool _isDone = false;
  bool _markedComplete = false;

  /// One-shot guard for the resolved-on-arrival auto-pop (WR-04). Because
  /// `build` watches the notifier, a resolved chunk would otherwise re-register
  /// a post-frame pop on every rebuild, letting two callbacks both pass the
  /// `mounted` check and pop twice (dropping the user past /schedule). Set
  /// before scheduling the pop so at most one pop is ever enqueued.
  bool _popScheduled = false;

  @override
  void dispose() {
    _timer?.cancel(); // CRITICAL: prevent setState-after-dispose (Pitfall 1)
    super.dispose();
  }

  void _start() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining <= 0) {
        t.cancel();
        if (mounted) {
          setState(() {
            _isDone = true;
            _isRunning = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() => _secondsRemaining--);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _doneEarly() {
    _timer?.cancel();
    setState(() {
      _isDone = true;
      _isRunning = false;
    });
  }

  void _skipTimer() {
    _timer?.cancel();
    setState(() {
      _isDone = true;
      _isRunning = false;
    });
  }

  void _markComplete(ScheduleNotifier notifier) {
    notifier.markComplete(widget.chunkId);
    setState(() => _markedComplete = true);
  }

  /// Formats remaining seconds as MM:SS.
  String get _timerDisplay {
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Derives a break suggestion from the chunk immediately following the
  /// current chunk in today's schedule.
  String _breakSuggestion(ScheduleNotifier notifier) {
    final chunks = notifier.todaySchedule?.chunks ?? [];
    final idx = chunks.indexWhere((c) => c.id == widget.chunkId);
    if (idx == -1 || idx + 1 >= chunks.length) return "You're done for now.";
    final next = chunks[idx + 1];
    if (next.chunkType == ChunkType.shortBreak) {
      return 'Nice work. Take a 5 min break.';
    }
    if (next.chunkType == ChunkType.longBreak) {
      return 'Great focus block. Take a 25 min break.';
    }
    return "You're done for now.";
  }

  @override
  Widget build(BuildContext context) {
    final scheduleNotifier = context.watch<ScheduleNotifier>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Find the target chunk.
    final chunks = scheduleNotifier.todaySchedule?.chunks ?? [];
    final chunk = chunks.where((c) => c.id == widget.chunkId).firstOrNull;

    // If the chunk is already resolved on arrival, pop immediately.
    // Guard: WidgetsBinding post-frame so we don't pop during build.
    if (chunk != null &&
        (chunk.isCompleted || chunk.isSkipped) &&
        !_popScheduled) {
      _popScheduled = true; // WR-04: enqueue at most one pop across rebuilds.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }

    // Resolve goal name and color for this chunk.
    String? goalName;
    Color? goalColor;
    if (chunk != null && chunk.goalId != null) {
      final goals = context.read<GoalsNotifier>().goals;
      final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
      goalName = goal?.name;
      if (goal?.color != null) goalColor = hexToColor(goal!.color!);
    }

    // Derive display strings. Map the raw rationale through the shared helper
    // so the focus screen reads identically to the schedule cards (READ-01).
    final displayGoalName = goalName ?? chunk?.rationale ?? 'Work block';
    final displayRationale = chunk == null
        ? ''
        : toDisplayRationale(chunk.rationale);
    final effectiveGoalColor = goalColor ?? colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: const Text(''),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Full-width goal color bar (4dp height) flush with AppBar bottom.
            Container(height: 4, color: effectiveGoalColor),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),

                      // Goal name + rationale in a primaryContainer card.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayGoalName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (displayRationale.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                displayRationale,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Timer area — hidden when done.
                      if (!_isDone) ...[
                        // Circular progress indicator wrapping the timer display.
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 160,
                                height: 160,
                                child: CircularProgressIndicator(
                                  value: _secondsRemaining / 1500,
                                  strokeWidth: 4,
                                  color: effectiveGoalColor,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                ),
                              ),
                              Text(
                                _timerDisplay,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w300,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Button row — state-driven per timer-states table.
                        if (_isRunning) ...[
                          // Running: Pause (primary) + Done early (outlined).
                          SizedBox(
                            height: 56,
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _pause,
                              child: const Text('Pause'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _doneEarly,
                              child: const Text('Done early'),
                            ),
                          ),
                        ] else if (_secondsRemaining < 1500) ...[
                          // Paused (timer was started but stopped): Resume.
                          SizedBox(
                            height: 56,
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _start,
                              child: const Text('Resume'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _doneEarly,
                              child: const Text('Done early'),
                            ),
                          ),
                        ] else ...[
                          // Not started (1500 seconds, not running).
                          SizedBox(
                            height: 56,
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _start,
                              child: const Text('Start 25 min timer'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _skipTimer,
                            child: const Text('Skip timer'),
                          ),
                        ],
                      ],

                      // Post-finish section: break suggestion + actions.
                      if (_isDone) ...[
                        const SizedBox(height: 24),

                        Text(
                          _breakSuggestion(scheduleNotifier),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _markedComplete
                                ? null
                                : () => _markComplete(scheduleNotifier),
                            child: const Text('Mark complete'),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to schedule'),
                        ),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
