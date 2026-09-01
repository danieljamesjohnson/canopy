// Widget tests for GoalCard's rank gutter, weekly progress line and type chip.
//
// Phase 33 Plan 03 — OBVIOUS-02, UI-SPEC items 13-18.
//
// ---------------------------------------------------------------------------
// RETIREMENT RECORD (recorded in place, not in a commit message)
// ---------------------------------------------------------------------------
// This file replaces two test files deleted in the same commit:
//
//   * test/screens/goal_card_priority_chip_test.dart
//       Asserted `_PriorityChip` rendered a "High" chip with Icons.arrow_upward
//       at priorityWeight 0.75, a "Low" chip with Icons.arrow_downward at 0.25,
//       and no chip at 0.5 or null (GOALS-02).
//
//   * test/screens/goal_card_priority_chip_rebuild_test.dart
//       Asserted the same chip followed the goal's CURRENT priorityWeight
//       through a reorderAllWithPriority -> loadGoals -> Consumer rebuild, so
//       a reordered goal never showed a stale High/Low chip (PRIORITY-03).
//
// Both are Kind A retirements: their PREMISE is gone, not their expected value.
// UI-SPEC item 17 deletes `_PriorityChip` and its `pw >= 0.75 / <= 0.25` dead
// zone outright — priority is carried by the rank number alone, and every
// goal's position is now unambiguous rather than only the top and bottom
// quartiles being labelled. There is no new widget to repoint the assertions
// at, so there was nothing to rewrite. What survives of their intent is the
// negative assertion below ("the priority chip is gone") plus the rank tests,
// which cover the same user-facing question — *where does this goal stand?* —
// through the mechanism that replaced it.
//
// Precedent for recording a retirement in the replacement file rather than in
// a commit message: test/screens/today_row_widgets_test.dart:740-763.
//
// NOTE: `test/screens/chunk_card_priority_badge_test.dart` covers a DIFFERENT
// priority badge, on the chunk row in chunk_card.dart, which this phase does
// not touch. It was deliberately not deleted.

import 'package:canopy/data/models/energy_valence.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/screens/goals/widgets/goal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

// The owner's colour bands (UI-SPEC item 14), duplicated here on purpose: the
// consts are file-private in goal_card.dart because they are NOT theme tokens
// and nothing outside that file should be painting with them. Pinning the
// literal values here is what makes a silent re-theming of the scale fail.
const _red = Color(0xFFE53935);
const _amber = Color(0xFFFFB300);
const _green = Color(0xFF43A047);

const _fillKey = ValueKey('goal-progress-fill');
const _trackKey = ValueKey('goal-progress-track');

Goal _goal({
  String id = 'g1',
  String name = 'Exercise',
  GoalType type = GoalType.timeTarget,
  double? priorityWeight,
  double? weeklyHourBudget,
  EnergyValence valence = EnergyValence.neutral,
}) => Goal(
  id: id,
  name: name,
  goalTypeIndex: type.index,
  color: '#4CAF50',
  priorityWeight: priorityWeight,
  weeklyHourBudget: weeklyHourBudget,
  energyValenceIndex: valence.index,
);

/// The fill's paint colour, or null when no fill is rendered.
Color? _fillColour(WidgetTester tester, {Finder? within}) {
  final finder = within == null
      ? find.byKey(_fillKey)
      : find.descendant(of: within, matching: find.byKey(_fillKey));
  if (finder.evaluate().isEmpty) return null;
  final decorated = tester.widget<DecoratedBox>(finder);
  return (decorated.decoration as BoxDecoration).color;
}

/// Every BoxDecoration colour painted anywhere in the pumped tree.
///
/// Uses `byWidgetPredicate` rather than `byType`: `find.byType` compares
/// runtimeType exactly and would miss subclasses, which is one of the two
/// measured "assertion cannot fail" traps recorded in CLAUDE.md.
List<Color?> _paintedColours(WidgetTester tester) {
  final colours = <Color?>[];
  for (final w in tester.widgetList(
    find.byWidgetPredicate((w) => w is DecoratedBox || w is Container),
  )) {
    final decoration = w is DecoratedBox
        ? w.decoration
        : (w as Container).decoration;
    if (decoration is BoxDecoration) colours.add(decoration.color);
  }
  return colours;
}

void main() {
  group('GoalCard rank gutter', () {
    testWidgets('renders the rank number when one is supplied', (tester) async {
      await pumpWithMood(tester, GoalCard(goal: _goal(), rank: 3));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('renders no rank gutter when rank is null', (tester) async {
      // The archived-goals call site passes neither new parameter, and an
      // archived list is not a priority order.
      await pumpWithMood(tester, GoalCard(goal: _goal()));
      expect(find.text('1'), findsNothing);
      expect(find.text('3'), findsNothing);
    });
  });

  group('GoalCard progress line — colour bands (UI-SPEC item 14)', () {
    testWidgets('0.10 paints the red band', (tester) async {
      await pumpWithMood(tester, GoalCard(goal: _goal(), weekProgress: 0.10));
      expect(_fillColour(tester), _red);
    });

    testWidgets('0.35 paints the amber band', (tester) async {
      await pumpWithMood(tester, GoalCard(goal: _goal(), weekProgress: 0.35));
      expect(_fillColour(tester), _amber);
    });

    testWidgets('0.85 paints the green band', (tester) async {
      await pumpWithMood(tester, GoalCard(goal: _goal(), weekProgress: 0.85));
      expect(_fillColour(tester), _green);
    });

    testWidgets('band edges are exact: 0.20 is amber, 0.70 is green', (
      tester,
    ) async {
      await pumpWithMood(tester, GoalCard(goal: _goal(), weekProgress: 0.20));
      expect(
        _fillColour(tester),
        _amber,
        reason: '0.20 is the first amber value, not the last red one',
      );

      await pumpWithMood(tester, GoalCard(goal: _goal(), weekProgress: 0.70));
      expect(
        _fillColour(tester),
        _green,
        reason: '0.70 is the first green value — "70% and above green"',
      );
    });
  });

  group('GoalCard progress line — no target (UI-SPEC item 16)', () {
    testWidgets('null progress renders the grey track and no fill', (
      tester,
    ) async {
      await pumpWithMood(tester, GoalCard(goal: _goal()));
      expect(find.byKey(_trackKey), findsOneWidget);
      expect(find.byKey(_fillKey), findsNothing);
    });

    testWidgets('an outcome goal shows no red anywhere on the card', (
      tester,
    ) async {
      // An outcome goal has no progress field in the model, so red would
      // assert "barely started" — a claim the data cannot support.
      await pumpWithMood(
        tester,
        GoalCard(goal: _goal(type: GoalType.outcome), weekProgress: null),
      );
      expect(find.byKey(_trackKey), findsOneWidget);
      expect(find.byKey(_fillKey), findsNothing);
      expect(
        _paintedColours(tester),
        isNot(contains(_red)),
        reason: 'an outcome goal must show an empty grey track, never red',
      );
    });
  });

  group('GoalCard priority chip is gone (UI-SPEC item 17)', () {
    testWidgets(
      'a 0.75 goal renders no High chip and a 0.25 goal no Low chip',
      (tester) async {
        await pumpWithMood(tester, GoalCard(goal: _goal(priorityWeight: 0.75)));
        expect(find.text('High'), findsNothing);
        expect(find.byIcon(Icons.arrow_upward), findsNothing);

        await pumpWithMood(tester, GoalCard(goal: _goal(priorityWeight: 0.25)));
        expect(find.text('Low'), findsNothing);
        expect(find.byIcon(Icons.arrow_downward), findsNothing);
      },
    );
  });

  group('GoalCard type chip is glyph AND word (UI-SPEC items 12, 29-30)', () {
    testWidgets('each type renders its icon alongside its label', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        GoalCard(goal: _goal(type: GoalType.timeTarget)),
      );
      expect(find.text('Regular time'), findsOneWidget);
      expect(find.byIcon(Icons.access_time_outlined), findsOneWidget);

      await pumpWithMood(tester, GoalCard(goal: _goal(type: GoalType.outcome)));
      expect(find.text('Working toward'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

      await pumpWithMood(tester, GoalCard(goal: _goal(type: GoalType.habit)));
      expect(find.text('Daily habit'), findsOneWidget);
      expect(find.byIcon(Icons.repeat_outlined), findsOneWidget);
    });
  });

  group('GoalCard progress line is FIXED geometry (UI-SPEC item 18)', () {
    testWidgets(
      'a 0.90 line on a short card is taller in pixels than a 0.62 line on a '
      'tall one',
      (tester) async {
        // The defect this pins, found in sketch 004: the progress line lives
        // in a Positioned(top: 0, bottom: 0) sized by the Stack — i.e. by the
        // card's own content. A fill expressed as a FRACTION of that is a
        // fraction of a VARYING height, so a 90% line on a short card renders
        // shorter in real pixels than a 62% line on a tall one. The eye
        // compares pixels, not percentages.
        //
        // Card heights are made to differ on purpose: the tall card is a
        // timeTarget with a weeklyHourBudget (so it gets a stat line) and a
        // 'gives' valence (so its chip run has two chips); the short card is
        // an outcome with neither. The width is constrained so the tall
        // card's chip run also wraps to a second line, widening the gap far
        // enough that a proportional fill would INVERT the comparison —
        // see the discrimination guard below.
        const tallKey = ValueKey('card-tall');
        const shortKey = ValueKey('card-short');

        await pumpWithMood(
          tester,
          Center(
            child: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GoalCard(
                    key: tallKey,
                    goal: _goal(
                      id: 'tall',
                      name: 'Tall',
                      type: GoalType.timeTarget,
                      weeklyHourBudget: 4.0,
                      valence: EnergyValence.gives,
                    ),
                    weekProgress: 0.62,
                  ),
                  GoalCard(
                    key: shortKey,
                    goal: _goal(
                      id: 'short',
                      name: 'Short',
                      type: GoalType.outcome,
                    ),
                    weekProgress: 0.90,
                  ),
                ],
              ),
            ),
          ),
        );

        final tallCard = tester.getSize(find.byKey(tallKey)).height;
        final shortCard = tester.getSize(find.byKey(shortKey)).height;

        // Card margin is EdgeInsets.symmetric(vertical: 4) (goal_card.dart),
        // so the Stack a proportional fill would be sized by is card - 8.
        const cardVerticalMargin = 8.0;
        final tallStack = tallCard - cardVerticalMargin;
        final shortStack = shortCard - cardVerticalMargin;

        // Guard 1: without a real height difference this test proves nothing.
        expect(
          tallStack,
          greaterThan(shortStack),
          reason: 'the two cards must differ in height or the test is vacuous',
        );

        // Guard 2 — the discrimination check. It asserts the FIXTURE is able
        // to catch the defect: under a fill proportional to the card, the
        // short card's 0.90 line would come out SHORTER than the tall card's
        // 0.62 line, so the real assertion below would flip. If a future
        // layout change shrinks this gap, this guard fails loudly rather
        // than letting the backstop quietly become unfalsifiable.
        expect(
          shortStack * 0.90,
          lessThan(tallStack * 0.62),
          reason:
              'fixture too weak: a proportional fill would still satisfy the '
              'assertion below, so it could not fail. Widen the height gap. '
              '(tall=$tallStack, short=$shortStack)',
        );

        final tallFill = tester
            .getSize(
              find.descendant(
                of: find.byKey(tallKey),
                matching: find.byKey(_fillKey),
              ),
            )
            .height;
        final shortFill = tester
            .getSize(
              find.descendant(
                of: find.byKey(shortKey),
                matching: find.byKey(_fillKey),
              ),
            )
            .height;

        // The actual requirement: more progress means more pixels, full stop.
        expect(
          shortFill,
          greaterThan(tallFill),
          reason:
              'the 0.90 line must be taller than the 0.62 line in logical '
              'pixels regardless of which card is taller',
        );

        // And both are measured off the constant, not off their cards.
        expect(shortFill, closeTo(kGoalProgressTrackHeight * 0.90, 0.01));
        expect(tallFill, closeTo(kGoalProgressTrackHeight * 0.62, 0.01));
      },
    );
  });
}
