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

// ---------------------------------------------------------------------------
// Stub helpers
// ---------------------------------------------------------------------------

/// Creates a stub Goal without Hive registration.
Goal _stubGoal({
  required String id,
  required String name,
  String? color,
}) {
  return Goal(
    id: id,
    name: name,
    goalTypeIndex: 0,
    color: color,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));


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
      await tester.pumpWidget(_wrap(DataSection(
        totalCompleted: 42,
        goalChunkTotals: {'g1': 30, 'g2': 12},
        notSpentCount: 10,
        weeklyData: const {},
        goals: goals,
        onNext: () {},
      )));
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('renders "chunks completed this quarter" label', (tester) async {
      await tester.pumpWidget(_wrap(DataSection(
        totalCompleted: 42,
        goalChunkTotals: {'g1': 30, 'g2': 12},
        notSpentCount: 10,
        weeklyData: const {},
        goals: goals,
        onNext: () {},
      )));
      expect(find.text('chunks completed this quarter'), findsOneWidget);
    });

    testWidgets('renders "Next: Reflect" button', (tester) async {
      await tester.pumpWidget(_wrap(DataSection(
        totalCompleted: 42,
        goalChunkTotals: {'g1': 30, 'g2': 12},
        notSpentCount: 10,
        weeklyData: const {},
        goals: goals,
        onNext: () {},
      )));
      expect(find.text('Next: Reflect'), findsOneWidget);
    });

    testWidgets('"Next: Reflect" button invokes onNext callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(DataSection(
        totalCompleted: 10,
        goalChunkTotals: const {},
        notSpentCount: 5,
        weeklyData: const {},
        goals: const [],
        onNext: () => tapped = true,
      )));
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
      await tester.pumpWidget(_wrap(DonutChart(
        goalChunkTotals: {'g1': 20, 'g2': 10},
        notSpentCount: 5,
        goals: goals,
      )));
      // Should have 2 goal rows + 1 "Time not spent" row = 3 total
      expect(find.text('Exercise'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('Time not spent'), findsOneWidget);
    });

    testWidgets('renders with no goals without crashing', (tester) async {
      await tester.pumpWidget(_wrap(const DonutChart(
        goalChunkTotals: {},
        notSpentCount: 0,
        goals: [],
      )));
      expect(find.text('Time not spent'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Task 2 Tests: ReflectionQuestionCard, AdjustmentsSection, GoalAdjustmentTile
  // ---------------------------------------------------------------------------

  group('ReflectionQuestionCard', () {
    testWidgets('renders the question text', (tester) async {
      await tester.pumpWidget(_wrap(ReflectionQuestionCard(
        question: 'Which goal gave you the most energy?',
        suggestedAnswers: const ['Exercise', 'Reading'],
        onAnswered: (_) {},
      )));
      expect(find.text('Which goal gave you the most energy?'), findsOneWidget);
    });

    testWidgets('renders suggestion chips', (tester) async {
      await tester.pumpWidget(_wrap(ReflectionQuestionCard(
        question: 'Test question',
        suggestedAnswers: const ['Exercise', 'Reading'],
        onAnswered: (_) {},
      )));
      expect(find.text('Exercise'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget);
    });

    testWidgets('tapping a chip calls onAnswered with chip label', (tester) async {
      String? answered;
      await tester.pumpWidget(_wrap(ReflectionQuestionCard(
        question: 'Test question',
        suggestedAnswers: const ['Exercise', 'Reading'],
        onAnswered: (v) => answered = v,
      )));
      await tester.tap(find.text('Exercise'));
      await tester.pump();
      expect(answered, equals('Exercise'));
    });

    testWidgets('renders "Other..." button', (tester) async {
      await tester.pumpWidget(_wrap(ReflectionQuestionCard(
        question: 'Test question',
        suggestedAnswers: const ['Exercise'],
        onAnswered: (_) {},
      )));
      expect(find.text('Other...'), findsOneWidget);
    });
  });

  group('GoalAdjustmentTile', () {
    final goal = _stubGoal(id: 'g1', name: 'Exercise', color: '#4CAF50');

    testWidgets('renders goal name', (tester) async {
      await tester.pumpWidget(_wrap(ReorderableListView(
        onReorder: (oldIdx, newIdx) {},
        children: [
          GoalAdjustmentTile(
            key: const ValueKey('g1'),
            goal: goal,
            goalColor: const Color(0xFF4CAF50),
            index: 0,
          ),
        ],
      )));
      expect(find.text('Exercise'), findsOneWidget);
    });

    testWidgets('shows archive prompt text when showArchivePrompt is true',
        (tester) async {
      await tester.pumpWidget(_wrap(ReorderableListView(
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
      )));
      expect(find.textContaining('rarely made it in'), findsOneWidget);
    });
  });

  group('AdjustmentsSection', () {
    final goals = [
      _stubGoal(id: 'g1', name: 'Exercise', color: '#4CAF50'),
      _stubGoal(id: 'g2', name: 'Reading', color: '#2196F3'),
    ];

    Widget wrapWithProvider(Widget child) =>
        ChangeNotifierProvider<GoalsNotifier>(
          create: (ctx) => GoalsNotifier(),
          child: MaterialApp(home: Scaffold(body: child)),
        );

    testWidgets('renders "Set your priorities for next quarter" heading',
        (tester) async {
      await tester.pumpWidget(wrapWithProvider(AdjustmentsSection(
        goals: goals,
        completionRates: const {'g1': 0.8, 'g2': 0.5},
        reflectionAnswers: const [],
        periodStartYmd: '2026-01-01',
        periodEndYmd: '2026-04-01',
        goalChunkTotals: const {'g1': 20, 'g2': 10},
      )));
      expect(find.text('Set your priorities for next quarter'), findsOneWidget);
    });

    testWidgets('renders "Finish review" button', (tester) async {
      await tester.pumpWidget(wrapWithProvider(AdjustmentsSection(
        goals: goals,
        completionRates: const {'g1': 0.8, 'g2': 0.5},
        reflectionAnswers: const [],
        periodStartYmd: '2026-01-01',
        periodEndYmd: '2026-04-01',
        goalChunkTotals: const {'g1': 20, 'g2': 10},
      )));
      await tester.ensureVisible(find.text('Finish review'));
      expect(find.text('Finish review'), findsOneWidget);
    });
  });

  group('ReflectionSection', () {
    final goals = [
      _stubGoal(id: 'g1', name: 'Exercise', color: '#4CAF50'),
    ];

    testWidgets('renders the first question', (tester) async {
      await tester.pumpWidget(_wrap(ReflectionSection(
        goals: goals,
        goalChunkTotals: const {'g1': 10},
        completionRates: const {'g1': 0.8},
        onComplete: (_) {},
      )));
      expect(
        find.textContaining('most energy'),
        findsOneWidget,
      );
    });
  });
}
