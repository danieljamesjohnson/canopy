import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/screens/quarterly_review/sections/adjustments_section.dart';
import 'package:canopy/screens/quarterly_review/sections/data_section.dart';
import 'package:canopy/screens/quarterly_review/sections/reflection_section.dart';
import 'package:canopy/screens/quarterly_review/widgets/donut_chart.dart';
import 'package:canopy/screens/quarterly_review/widgets/goal_adjustment_tile.dart';
import 'package:canopy/screens/quarterly_review/widgets/reflection_question_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// Stub helpers
// ---------------------------------------------------------------------------

/// Creates a stub Goal without Hive registration.
Goal _stubGoal({required String id, required String name, String? color}) {
  return Goal(id: id, name: name, goalTypeIndex: 0, color: color);
}

// ---------------------------------------------------------------------------
// Task 1 Tests: DataSection and DonutChart
// ---------------------------------------------------------------------------

void main() {
  group('DataSection', () {
    final goals = [
      _stubGoal(id: 'g1', name: 'Exercise', color: '#4CAF50'),
      _stubGoal(id: 'g2', name: 'Reading', color: '#2196F3'),
    ];

    testWidgets('renders hero stat number', (tester) async {
      await pumpWithMood(
        tester,
        DataSection(
          totalCompleted: 42,
          goalChunkTotals: {'g1': 30, 'g2': 12},
          notSpentCount: 10,
          weeklyData: const {},
          goals: goals,
          archivedGoals: const [],
          commitmentBlocks: const [],
          onNext: () {},
        ),
      );
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('renders "chunks completed this quarter" label', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        DataSection(
          totalCompleted: 42,
          goalChunkTotals: {'g1': 30, 'g2': 12},
          notSpentCount: 10,
          weeklyData: const {},
          goals: goals,
          archivedGoals: const [],
          commitmentBlocks: const [],
          onNext: () {},
        ),
      );
      expect(find.text('chunks completed this quarter'), findsOneWidget);
    });

    testWidgets('renders "Next: Reflect" button', (tester) async {
      await pumpWithMood(
        tester,
        DataSection(
          totalCompleted: 42,
          goalChunkTotals: {'g1': 30, 'g2': 12},
          notSpentCount: 10,
          weeklyData: const {},
          goals: goals,
          archivedGoals: const [],
          commitmentBlocks: const [],
          onNext: () {},
        ),
      );
      expect(find.text('Next: Reflect'), findsOneWidget);
    });

    testWidgets('"Next: Reflect" button invokes onNext callback', (
      tester,
    ) async {
      var tapped = false;
      await pumpWithMood(
        tester,
        DataSection(
          totalCompleted: 10,
          goalChunkTotals: const {},
          notSpentCount: 5,
          weeklyData: const {},
          goals: const [],
          archivedGoals: const [],
          commitmentBlocks: const [],
          onNext: () => tapped = true,
        ),
      );
      await tester.ensureVisible(find.text('Next: Reflect'));
      await tester.tap(find.text('Next: Reflect'));
      expect(tapped, isTrue);
    });
  });

  group('DonutChart', () {
    final goals = [
      _stubGoal(id: 'g1', name: 'Exercise', color: '#4CAF50'),
      _stubGoal(id: 'g2', name: 'Reading', color: '#2196F3'),
    ];

    testWidgets('renders correct number of legend rows', (tester) async {
      await pumpWithMood(
        tester,
        DonutChart(
          goalChunkTotals: {'g1': 20, 'g2': 10},
          notSpentCount: 5,
          goals: goals,
          archivedGoals: const [],
          commitmentBlocks: const [],
        ),
      );
      // Should have 2 goal rows + 1 "Time not spent" row = 3 total
      expect(find.text('Exercise'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('Time not spent'), findsOneWidget);
    });

    testWidgets('renders with no goals without crashing', (tester) async {
      await pumpWithMood(
        tester,
        const DonutChart(
          goalChunkTotals: {},
          notSpentCount: 0,
          goals: [],
          archivedGoals: [],
          commitmentBlocks: [],
        ),
      );
      // With all zeroes and no notSpentCount, no slices render — just an empty chart
    });

    testWidgets('renders Commitments legend row when commitment logs present', (
      tester,
    ) async {
      // commitment block id in goalChunkTotals key — matches commitmentBlocks list
      final block = CommitmentBlock(
        name: 'Work',
        daysOfWeek: [1, 2, 3, 4, 5],
        startMinutes: 540,
        endMinutes: 600,
      );
      await pumpWithMood(
        tester,
        DonutChart(
          goalChunkTotals: {block.id: 5},
          notSpentCount: 0,
          goals: const [],
          archivedGoals: const [],
          commitmentBlocks: [block],
        ),
      );
      expect(find.text('Commitments'), findsOneWidget);
    });

    testWidgets('renders archived goal legend row with (archived) suffix', (
      tester,
    ) async {
      final archivedGoal = _stubGoal(
        id: 'g_arch',
        name: 'Old Habit',
        color: '#9C27B0',
      );
      await pumpWithMood(
        tester,
        DonutChart(
          goalChunkTotals: {'g_arch': 8},
          notSpentCount: 0,
          goals: const [],
          archivedGoals: [archivedGoal],
          commitmentBlocks: const [],
        ),
      );
      expect(find.text('Old Habit (archived)'), findsOneWidget);
    });

    testWidgets(
      'legend percentages across all slice types sum to 100 (deterministic mix)',
      (tester) async {
        // Use a deterministic mix: 1 active goal (20 chunks) + 1 commitment (5 chunks)
        // + notSpentCount 5 → total 30. Percentages should sum to 100.
        final block = CommitmentBlock(
          name: 'Meeting',
          daysOfWeek: [1, 2, 3, 4, 5],
          startMinutes: 540,
          endMinutes: 600,
        );
        final activeGoal = _stubGoal(
          id: 'g1',
          name: 'Exercise',
          color: '#4CAF50',
        );
        await pumpWithMood(
          tester,
          DonutChart(
            goalChunkTotals: {'g1': 20, block.id: 5},
            notSpentCount: 5,
            goals: [activeGoal],
            archivedGoals: const [],
            commitmentBlocks: [block],
          ),
        );
        // Find all '%' text widgets and sum their rounded values.
        // Individual percentages use toStringAsFixed(0) (nearest integer), so
        // the sum may be 99–101 due to rounding — inRange is the correct check.
        final pctWidgets = tester.widgetList<Text>(find.textContaining('%'));
        int sum = 0;
        for (final w in pctWidgets) {
          final raw = w.data ?? '';
          sum += int.tryParse(raw.replaceAll('%', '').trim()) ?? 0;
        }
        expect(sum, inInclusiveRange(99, 101),
            reason:
                'Rounded per-slice percentages may sum to 99-101 due to toStringAsFixed(0) rounding');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Task 2 Tests: ReflectionQuestionCard, AdjustmentsSection, GoalAdjustmentTile
  // ---------------------------------------------------------------------------

  group('ReflectionQuestionCard', () {
    testWidgets('renders the question text', (tester) async {
      await pumpWithMood(
        tester,
        ReflectionQuestionCard(
          question: 'Which goal gave you the most energy?',
          suggestedAnswers: const ['Exercise', 'Reading'],
          onAnswered: (_) {},
        ),
      );
      expect(find.text('Which goal gave you the most energy?'), findsOneWidget);
    });

    testWidgets('renders suggestion chips', (tester) async {
      await pumpWithMood(
        tester,
        ReflectionQuestionCard(
          question: 'Test question',
          suggestedAnswers: const ['Exercise', 'Reading'],
          onAnswered: (_) {},
        ),
      );
      expect(find.text('Exercise'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget);
    });

    testWidgets('tapping a chip calls onAnswered with chip label', (
      tester,
    ) async {
      String? answered;
      await pumpWithMood(
        tester,
        ReflectionQuestionCard(
          question: 'Test question',
          suggestedAnswers: const ['Exercise', 'Reading'],
          onAnswered: (v) => answered = v,
        ),
      );
      await tester.tap(find.text('Exercise'));
      await tester.pump();
      expect(answered, equals('Exercise'));
    });

    testWidgets('renders "Other..." button', (tester) async {
      await pumpWithMood(
        tester,
        ReflectionQuestionCard(
          question: 'Test question',
          suggestedAnswers: const ['Exercise'],
          onAnswered: (_) {},
        ),
      );
      expect(find.text('Other...'), findsOneWidget);
    });
  });

  group('GoalAdjustmentTile', () {
    final goal = _stubGoal(id: 'g1', name: 'Exercise', color: '#4CAF50');

    testWidgets('renders goal name', (tester) async {
      await pumpWithMood(
        tester,
        ReorderableListView(
          onReorder: (oldIdx, newIdx) {},
          children: [
            GoalAdjustmentTile(
              key: const ValueKey('g1'),
              goal: goal,
              goalColor: const Color(0xFF4CAF50),
              index: 0,
            ),
          ],
        ),
      );
      expect(find.text('Exercise'), findsOneWidget);
    });

    testWidgets('shows archive prompt text when showArchivePrompt is true', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        ReorderableListView(
          onReorder: (oldIdx, newIdx) {},
          children: [
            GoalAdjustmentTile(
              key: const ValueKey('g1'),
              goal: goal,
              goalColor: const Color(0xFF4CAF50),
              index: 0,
              showArchivePrompt: true,
              onArchive: () {},
              onKeep: () {},
            ),
          ],
        ),
      );
      expect(find.textContaining('rarely made it in'), findsOneWidget);
    });
  });

  group('AdjustmentsSection', () {
    final goals = [
      _stubGoal(id: 'g1', name: 'Exercise', color: '#4CAF50'),
      _stubGoal(id: 'g2', name: 'Reading', color: '#2196F3'),
    ];

    testWidgets('renders "Set your priorities for next quarter" heading', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        AdjustmentsSection(
          goals: goals,
          completionRates: const {'g1': 0.8, 'g2': 0.5},
          reflectionAnswers: const [],
          periodStartYmd: '2026-01-01',
          periodEndYmd: '2026-04-01',
          goalChunkTotals: const {'g1': 20, 'g2': 10},
        ),
        extraProviders: [
          ChangeNotifierProvider<GoalsNotifier>(create: (_) => GoalsNotifier()),
        ],
      );
      expect(find.text('Set your priorities for next quarter'), findsOneWidget);
    });

    testWidgets('renders "Finish review" button', (tester) async {
      await pumpWithMood(
        tester,
        AdjustmentsSection(
          goals: goals,
          completionRates: const {'g1': 0.8, 'g2': 0.5},
          reflectionAnswers: const [],
          periodStartYmd: '2026-01-01',
          periodEndYmd: '2026-04-01',
          goalChunkTotals: const {'g1': 20, 'g2': 10},
        ),
        extraProviders: [
          ChangeNotifierProvider<GoalsNotifier>(create: (_) => GoalsNotifier()),
        ],
      );
      await tester.ensureVisible(find.text('Finish review'));
      expect(find.text('Finish review'), findsOneWidget);
    });
  });

  group('ReflectionSection', () {
    final goals = [_stubGoal(id: 'g1', name: 'Exercise', color: '#4CAF50')];

    testWidgets('renders the first question', (tester) async {
      await pumpWithMood(
        tester,
        ReflectionSection(
          goals: goals,
          goalChunkTotals: const {'g1': 10},
          completionRates: const {'g1': 0.8},
          onComplete: (_) {},
        ),
      );
      expect(find.textContaining('most energy'), findsOneWidget);
    });
  });
}
