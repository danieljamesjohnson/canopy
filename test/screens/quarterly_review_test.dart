import 'package:canopy/data/models/goal.dart';
import 'package:canopy/screens/quarterly_review/sections/data_section.dart';
import 'package:canopy/screens/quarterly_review/widgets/donut_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  // (Added in Task 2)
  // ---------------------------------------------------------------------------
}
