// Phase 37 — Three Meals, One Tap. The engine half: a meal is ONE solid
// chunk of ChunkType.meal (D-37-07), a meeting carves it (D-37-01, pieces
// under 10 minutes dropped), a hand-entered commitment yields to it the way it
// yields to a meeting (entry 19's shape), and it costs no goal capacity
// (D-37-03). Mutation log: 37-01-SUMMARY.md.

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/services/schedule_generator.dart';
import 'package:canopy/utils/meals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final monday = DateTime(2026, 3, 23);
  final service = ScheduleGeneratorService();

  CommitmentBlock meal(MealSlot slot, {int? start, int? end}) =>
      CommitmentBlock(
        id: 'meal-${slot.kind}',
        name: slot.label,
        daysOfWeek: kAllWeekdays,
        startMinutes: start ?? slot.defaultStart,
        endMinutes: end ?? slot.defaultEnd,
        kind: slot.kind,
      );

  CommitmentBlock work() => CommitmentBlock(
    id: 'work',
    name: 'Work',
    daysOfWeek: const [1, 2, 3, 4, 5],
    startMinutes: 9 * 60,
    endMinutes: 17 * 60,
  );

  CommitmentBlock meeting(String id, int s, int e) => CommitmentBlock(
    id: id,
    name: 'Meeting',
    daysOfWeek: const [],
    date: monday,
    startMinutes: s,
    endMinutes: e,
    externalEventId: 'ics:x:$id:',
    isFromCalendar: true,
  );

  bool overlaps(ScheduledChunk c, int s, int e) {
    final cs = c.displayStartMinutes!;
    return cs < e && s < cs + c.durationMinutes;
  }

  List<ScheduledChunk> gen(List<CommitmentBlock> blocks, {List<Goal>? goals}) =>
      service.generate(
        goals: goals ?? const [],
        blocks: blocks,
        moodIndex: 3,
        date: monday,
      );

  group('a meal is one solid block (D-37-07)', () {
    test('lunch 12-1 is exactly one meal chunk covering 12:00-13:00', () {
      final chunks = gen([meal(MealSlot.lunch)]);
      final lunch = chunks
          .where((c) => c.commitmentId == 'meal-lunch')
          .toList();
      expect(lunch, hasLength(1));
      expect(lunch.single.chunkType, ChunkType.meal);
      expect(lunch.single.anchoredStartMinutes, 12 * 60);
      expect(lunch.single.durationMinutes, 60);
      expect(lunch.single.rationale, 'Lunch');
    });

    test('an ordinary commitment is still work chunks, never meal', () {
      final chunks = gen([work()]);
      expect(chunks.where((c) => c.chunkType == ChunkType.meal), isEmpty);
    });

    test('a 10-minute meal is kept; a 9-minute one is not', () {
      final ten = ScheduleGeneratorService.buildCommitmentChunks(
        meal(MealSlot.breakfast, start: 420, end: 430),
        longBreakEvery: 4,
      );
      expect(ten, hasLength(1));
      final nine = ScheduleGeneratorService.buildCommitmentChunks(
        meal(MealSlot.breakfast, start: 420, end: 429),
        longBreakEvery: 4,
      );
      expect(nine, isEmpty);
    });
  });

  group('breakfast at 7:00 vs the 08:00 day start (riskiest assumption)', () {
    test('a 7:00-7:30 breakfast survives generate() and comes first', () {
      final goal = Goal(name: 'Write', goalTypeIndex: GoalType.habit.index);
      final chunks = gen(MealSlot.values.map(meal).toList(), goals: [goal]);
      expect(chunks.first.commitmentId, 'meal-breakfast');
      expect(chunks.first.anchoredStartMinutes, 7 * 60);
      expect(chunks.first.durationMinutes, 30);
      // Discretionary packing still starts at 08:00, not at breakfast's end.
      final firstGoal = chunks.firstWhere((c) => c.goalId == goal.id);
      expect(firstGoal.syntheticStartMinutes, 8 * 60);
    });
  });

  group('the meeting wins (D-37-01)', () {
    test('a 12:30-13:00 meeting carves lunch to 12:00-12:30', () {
      final chunks = gen([meal(MealSlot.lunch), meeting('m', 750, 780)]);
      final lunch = chunks
          .where((c) => c.commitmentId == 'meal-lunch')
          .toList();
      expect(lunch, hasLength(1));
      expect(lunch.single.anchoredStartMinutes, 720);
      expect(lunch.single.durationMinutes, 30);
    });

    test('a meeting in the middle splits lunch into two pieces', () {
      final chunks = gen([meal(MealSlot.lunch), meeting('m', 740, 760)]);
      final lunch = chunks
          .where((c) => c.commitmentId == 'meal-lunch')
          .toList();
      expect(
        lunch.map((c) => (c.anchoredStartMinutes, c.durationMinutes)).toList(),
        [(720, 20), (760, 20)],
      );
      expect(lunch.every((c) => c.chunkType == ChunkType.meal), isTrue);
    });

    test('a leftover piece under 10 minutes is dropped', () {
      // 12:00-12:55 meeting leaves 12:55-13:00 — five minutes, not a meal.
      final chunks = gen([meal(MealSlot.lunch), meeting('m', 720, 775)]);
      expect(chunks.where((c) => c.commitmentId == 'meal-lunch'), isEmpty);
    });

    test('a meal fully covered by a meeting does not appear', () {
      final chunks = gen([meal(MealSlot.lunch), meeting('m', 690, 810)]);
      expect(chunks.where((c) => c.commitmentId == 'meal-lunch'), isEmpty);
      expect(chunks.where((c) => c.commitmentId == 'm'), hasLength(1));
    });
  });

  group('Work yields to a meal (D-37-07, entry 19 shape)', () {
    test('Work 9-5 with lunch 12-1: nothing of Work is under lunch, and Work '
        'runs before and after it', () {
      final chunks = gen([work(), meal(MealSlot.lunch)]);
      final underLunch = chunks.where(
        (c) => c.commitmentId == 'work' && overlaps(c, 720, 780),
      );
      expect(underLunch, isEmpty);
      expect(
        chunks.where((c) => c.commitmentId == 'work' && overlaps(c, 540, 720)),
        isNotEmpty,
      );
      expect(
        chunks.where((c) => c.commitmentId == 'work' && overlaps(c, 780, 1020)),
        isNotEmpty,
      );
      // Each remaining segment has its own lattice: Work's last chunk before
      // lunch ends exactly at 12:00, its first after lunch starts at 13:00.
      final before = chunks
          .where(
            (c) => c.commitmentId == 'work' && c.anchoredStartMinutes! < 720,
          )
          .toList();
      final last = before.last;
      expect(last.anchoredStartMinutes! + last.durationMinutes, 720);
      final after = chunks
          .where(
            (c) => c.commitmentId == 'work' && c.anchoredStartMinutes! >= 780,
          )
          .toList();
      expect(after.first.anchoredStartMinutes, 780);
      expect(after.first.chunkType, ChunkType.work);
    });

    test('a meeting over lunch and Work: Work yields to both', () {
      final chunks = gen([
        work(),
        meal(MealSlot.lunch),
        meeting('m', 750, 810),
      ]);
      expect(
        chunks.where((c) => c.commitmentId == 'work' && overlaps(c, 720, 810)),
        isEmpty,
      );
    });

    test('a meal does not yield to Work', () {
      final chunks = gen([work(), meal(MealSlot.lunch)]);
      final lunch = chunks
          .where((c) => c.commitmentId == 'meal-lunch')
          .toList();
      expect(lunch, hasLength(1));
      expect(lunch.single.durationMinutes, 60);
    });
  });

  group('meals are not tracked and cost no capacity (D-37-03)', () {
    test('three meals do not reduce the number of goal chunks', () {
      final goals = [
        for (var i = 0; i < 6; i++)
          Goal(name: 'G$i', goalTypeIndex: GoalType.habit.index),
      ];
      int goalChunks(List<ScheduledChunk> cs) =>
          cs.where((c) => c.goalId != null).length;
      final without = gen(const [], goals: goals);
      final withMeals = gen(MealSlot.values.map(meal).toList(), goals: goals);
      expect(goalChunks(withMeals), goalChunks(without));
      // ...and nothing discretionary lands inside a meal.
      for (final m in withMeals.where((c) => c.chunkType == ChunkType.meal)) {
        final s = m.anchoredStartMinutes!;
        expect(
          withMeals.where(
            (c) =>
                c.commitmentId == null && overlaps(c, s, s + m.durationMinutes),
          ),
          isEmpty,
        );
      }
    });
  });
}
