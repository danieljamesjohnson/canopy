import 'dart:math';

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';

/// Pure Dart service — no Flutter imports, no async, no side effects.
///
/// Generates an ordered flat list of [ScheduledChunk]s for a given day,
/// mood level, goal list, and commitment blocks.
///
/// Allocation order:
///   1. Commitment blocks (anchored work chunks, not counted against cap)
///   2. Habits (always included, counted against cap)
///   3. Outcome goals (mood 3-5 only, or deadline==today; sorted by urgency)
///   4. Time-target goals (mood 3-5 only; sorted by priorityWeight)
///
/// After allocation, a break insertion pass interleaves shortBreak / longBreak
/// chunks between every work chunk. longBreakEvery = 3 for mood 1-2, 4 for 3-5.
class ScheduleGeneratorService {
  /// Capacity table: maps moodIndex → max discretionary work chunks at 80%.
  ///
  /// Raw max:  mood 1=6, 2=8, 3=10, 4=12, 5=14
  /// 80% cap:  mood 1=4, 2=6, 3=8,  4=9,  5=11
  static const Map<int, int> _moodCap = {
    1: 4,
    2: 6,
    3: 8,
    4: 9,
    5: 11,
  };

  /// Generate a schedule for [date] given [moodIndex] (1-5), active [goals],
  /// and recurring [blocks].
  List<ScheduledChunk> generate({
    required List<Goal> goals,
    required List<CommitmentBlock> blocks,
    required int moodIndex,
    required DateTime date,
  }) {
    final int cap = _moodCap[moodIndex] ?? 8;
    final bool isLowMood = moodIndex <= 2;
    final int longBreakEvery = isLowMood ? 3 : 4;

    // Collect work chunks in allocation order.
    final List<ScheduledChunk> workChunks = [];
    int discretionaryCount = 0;

    // -------------------------------------------------------------------------
    // Step 1: Commitment block chunks (anchored; not counted against cap).
    // -------------------------------------------------------------------------
    for (final block in blocks) {
      if (!block.daysOfWeek.contains(date.weekday)) continue;
      int cursor = block.startMinutes;
      while (cursor + 25 <= block.endMinutes) {
        workChunks.add(
          ScheduledChunk(
            chunkTypeIndex: ChunkType.work.index,
            goalId: null,
            durationMinutes: 25,
            anchoredStartMinutes: cursor,
            rationale: block.name,
          ),
        );
        cursor += 25;
      }
    }

    // -------------------------------------------------------------------------
    // Step 2: Habits — always included regardless of mood.
    // -------------------------------------------------------------------------
    final activeGoals = goals.where((g) => !g.isArchived).toList();

    for (final goal in activeGoals) {
      if (discretionaryCount >= cap) break;
      if (goal.goalType != GoalType.habit) continue;
      workChunks.add(
        ScheduledChunk(
          chunkTypeIndex: ChunkType.work.index,
          goalId: goal.id,
          durationMinutes: 25,
          rationale: 'Habit',
        ),
      );
      discretionaryCount++;
    }

    // -------------------------------------------------------------------------
    // Step 3: Outcome goals (mood 3-5 only, unless deadline==today).
    // -------------------------------------------------------------------------
    final outcomeGoals = activeGoals
        .where((g) => g.goalType == GoalType.outcome)
        .toList();

    // Compute urgency score for each outcome goal.
    double urgencyScore(Goal g, DateTime d) {
      if (g.deadline == null) {
        return (g.priorityWeight ?? 0.5) * 0.1;
      }
      final daysRemaining = max(1, g.deadline!.difference(d).inDays);
      // Phase 3 uses placeholder chunksRemaining = 2.0
      return (g.priorityWeight ?? 0.5) * 2.0 / daysRemaining.toDouble();
    }

    outcomeGoals.sort((a, b) =>
        urgencyScore(b, date).compareTo(urgencyScore(a, date)));

    for (final goal in outcomeGoals) {
      if (discretionaryCount >= cap) break;
      // Include if: mood 3-5 OR deadline == today
      final bool deadlineToday = goal.deadline != null &&
          goal.deadline!.year == date.year &&
          goal.deadline!.month == date.month &&
          goal.deadline!.day == date.day;
      if (!isLowMood || deadlineToday) {
        workChunks.add(
          ScheduledChunk(
            chunkTypeIndex: ChunkType.work.index,
            goalId: goal.id,
            durationMinutes: 25,
            rationale: 'Outcome goal',
          ),
        );
        discretionaryCount++;
      }
    }

    // -------------------------------------------------------------------------
    // Step 4: Time-target goals (mood 3-5 only).
    // -------------------------------------------------------------------------
    if (!isLowMood) {
      final timeTargetGoals = activeGoals
          .where((g) => g.goalType == GoalType.timeTarget)
          .toList()
        ..sort((a, b) =>
            (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5));

      for (final goal in timeTargetGoals) {
        if (discretionaryCount >= cap) break;
        workChunks.add(
          ScheduledChunk(
            chunkTypeIndex: ChunkType.work.index,
            goalId: goal.id,
            durationMinutes: 25,
            rationale: 'Weekly goal',
          ),
        );
        discretionaryCount++;
      }
    }

    // -------------------------------------------------------------------------
    // Break insertion pass.
    // -------------------------------------------------------------------------
    if (workChunks.isEmpty) return [];

    final List<ScheduledChunk> result = [];
    int workChunkCounter = 0;

    for (final chunk in workChunks) {
      result.add(chunk);
      workChunkCounter++;

      if (workChunkCounter % longBreakEvery == 0) {
        // Long break
        result.add(
          ScheduledChunk(
            chunkTypeIndex: ChunkType.longBreak.index,
            goalId: null,
            durationMinutes: 25,
            rationale: '',
          ),
        );
      } else {
        // Short break
        result.add(
          ScheduledChunk(
            chunkTypeIndex: ChunkType.shortBreak.index,
            goalId: null,
            durationMinutes: 5,
            rationale: '',
          ),
        );
      }
    }

    return result;
  }
}
