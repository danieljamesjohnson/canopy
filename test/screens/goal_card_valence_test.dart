// Widget tests for valence badge and emoji tag on GoalCard — Phase 19 Plan 01.
//
// Covers ENERGY-03b (emoji renders on GoalCard title row when set) and
// ENERGY-04a (valence badge renders for gives/costs; absent for neutral).
//
// RED: This file fails to compile because EnergyValence / Goal.energyValenceIndex
// / Goal.emojiTag / Goal.energyValence / _ValenceBadge do not exist yet.

import 'package:canopy/data/models/energy_valence.dart'; // does not exist yet — RED
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/screens/goals/widgets/goal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Goal _stubGoal(
  String id,
  String name, {
  EnergyValence? valence, // does not exist yet — RED
  String? emojiTag,       // field on Goal does not exist yet — RED
}) => Goal(
      id: id,
      name: name,
      goalTypeIndex: GoalType.timeTarget.index,
      color: '#4CAF50',
      energyValenceIndex: valence?.index, // param does not exist yet — RED
      emojiTag: emojiTag,                 // param does not exist yet — RED
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GoalCard valence badge (ENERGY-04a)', () {
    testWidgets(
      'shows "Gives" badge + bolt icon when energyValence == gives',
      (tester) async {
        await pumpWithMood(
          tester,
          GoalCard(
            goal: _stubGoal('g1', 'Morning Run', valence: EnergyValence.gives),
          ),
        );

        expect(
          find.text('Gives'),
          findsOneWidget,
          reason: 'Valence badge must show "Gives" text for gives valence — ENERGY-04a',
        );
        expect(
          find.byIcon(Icons.bolt),
          findsOneWidget,
          reason: 'Valence badge must show bolt icon for gives valence — ENERGY-04a',
        );
      },
    );

    testWidgets(
      'shows "Costs" badge + hourglass icon when energyValence == costs',
      (tester) async {
        await pumpWithMood(
          tester,
          GoalCard(
            goal: _stubGoal('g1', 'Admin Work', valence: EnergyValence.costs),
          ),
        );

        expect(
          find.text('Costs'),
          findsOneWidget,
          reason: 'Valence badge must show "Costs" text for costs valence — ENERGY-04a',
        );
        expect(
          find.byIcon(Icons.hourglass_empty),
          findsOneWidget,
          reason: 'Valence badge must show hourglass icon for costs valence — ENERGY-04a',
        );
      },
    );

    testWidgets(
      'shows NO valence badge when energyValence == neutral',
      (tester) async {
        await pumpWithMood(
          tester,
          GoalCard(
            goal: _stubGoal('g1', 'Neutral Goal', valence: EnergyValence.neutral),
          ),
        );

        expect(
          find.text('Gives'),
          findsNothing,
          reason: 'No valence badge must render for neutral — ENERGY-04a',
        );
        expect(
          find.text('Costs'),
          findsNothing,
          reason: 'No valence badge must render for neutral — ENERGY-04a',
        );
      },
    );

    testWidgets(
      'shows NO valence badge when energyValenceIndex is null (old-record default)',
      (tester) async {
        await pumpWithMood(
          tester,
          GoalCard(
            goal: _stubGoal('g1', 'Legacy Goal'),
            // no valence specified — defaults to null → neutral
          ),
        );

        expect(find.text('Gives'), findsNothing);
        expect(find.text('Costs'), findsNothing);
      },
    );
  });

  group('GoalCard emoji tag (ENERGY-03b)', () {
    testWidgets(
      'emoji appears in title row when emojiTag is set',
      (tester) async {
        const knownEmoji = '⚡';
        await pumpWithMood(
          tester,
          GoalCard(
            goal: _stubGoal('g1', 'Running', emojiTag: knownEmoji),
          ),
        );

        expect(
          find.text(knownEmoji),
          findsOneWidget,
          reason:
              'Emoji tag must render as text in the GoalCard title row — ENERGY-03b',
        );
      },
    );

    testWidgets(
      'no emoji appears when emojiTag is null',
      (tester) async {
        await pumpWithMood(
          tester,
          GoalCard(
            goal: _stubGoal('g1', 'No Emoji Goal'),
          ),
        );

        // Just verify the goal name renders (no emoji prefix)
        expect(find.text('No Emoji Goal'), findsOneWidget);
        expect(find.text('⚡'), findsNothing);
      },
    );

    testWidgets(
      'emoji + gives badge both render together',
      (tester) async {
        const knownEmoji = '🌟';
        await pumpWithMood(
          tester,
          GoalCard(
            goal: _stubGoal(
              'g1',
              'Energizing Goal',
              valence: EnergyValence.gives,
              emojiTag: knownEmoji,
            ),
          ),
        );

        expect(find.text(knownEmoji), findsOneWidget);
        expect(find.text('Gives'), findsOneWidget);
        expect(find.byIcon(Icons.bolt), findsOneWidget);
      },
    );
  });
}
