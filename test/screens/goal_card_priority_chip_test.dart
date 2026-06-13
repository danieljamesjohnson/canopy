// Widget tests for _PriorityChip rendering inside GoalCard — Phase 14 Plan 01.
//
// Covers GOALS-02: priority chip visible at 0.75 (High) and 0.25 (Low),
// absent at 0.5 (Normal) and null.

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/screens/goals/widgets/goal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

Goal _stubGoal(String id, String name, {double? priorityWeight}) => Goal(
      id: id,
      name: name,
      goalTypeIndex: 0,
      color: '#4CAF50',
      priorityWeight: priorityWeight,
    );

void main() {
  group('GoalCard priority chip', () {
    testWidgets('shows High chip for priorityWeight 0.75', (tester) async {
      await pumpWithMood(
        tester,
        GoalCard(goal: _stubGoal('g1', 'Exercise', priorityWeight: 0.75)),
      );
      expect(find.text('High'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('shows no chip for priorityWeight 0.5 (Normal)', (tester) async {
      await pumpWithMood(
        tester,
        GoalCard(goal: _stubGoal('g1', 'Exercise', priorityWeight: 0.5)),
      );
      expect(find.text('High'), findsNothing);
      expect(find.text('Low'), findsNothing);
    });

    testWidgets('shows Low chip for priorityWeight 0.25', (tester) async {
      await pumpWithMood(
        tester,
        GoalCard(goal: _stubGoal('g1', 'Exercise', priorityWeight: 0.25)),
      );
      expect(find.text('Low'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('shows no chip when priorityWeight is null (defaults Normal)',
        (tester) async {
      await pumpWithMood(
        tester,
        GoalCard(goal: _stubGoal('g1', 'Exercise')),
      );
      expect(find.text('High'), findsNothing);
      expect(find.text('Low'), findsNothing);
    });
  });
}
