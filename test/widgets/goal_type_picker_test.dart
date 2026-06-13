// Widget layout tests for GoalTypePicker _TypeCard compaction — Phase 13 Plan 02.
//
// Covers GOALFORM-01: compact _TypeCard must fit within 64dp height and have
// minVerticalPadding == 0 so Priority + Save are reachable without in-sheet
// scrolling on a standard phone (iPhone 14-class, 844dp height).
//
// Analogs: test/screens/goal_form_priority_test.dart (pumpWithMood + widget
// property inspection), test/test_helpers/viewport.dart (setViewport).

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/screens/goals/widgets/goal_type_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';
import '../test_helpers/viewport.dart';

void main() {
  group('GoalTypePicker _TypeCard compaction (GOALFORM-01)', () {
    testWidgets(
      '_TypeCard height is <= 64dp on a 390x844 viewport (iPhone 14)',
      (tester) async {
        setViewport(tester, const Size(390, 844));

        await pumpWithMood(
          tester,
          GoalTypePicker(
            selectedType: null,
            onTypeSelected: (_) {},
          ),
        );

        final cardSize = tester.getSize(find.byType(Card).first);
        expect(
          cardSize.height,
          lessThanOrEqualTo(64.0),
          reason:
              'GOALFORM-01: compact _TypeCard must fit within 64dp height so '
              'Priority + Save are reachable without in-sheet scrolling',
        );
      },
    );

    testWidgets(
      '_TypeCard ListTile has minVerticalPadding == 0 (guards Pitfall 4)',
      (tester) async {
        setViewport(tester, const Size(390, 844));

        await pumpWithMood(
          tester,
          GoalTypePicker(
            selectedType: null,
            onTypeSelected: (_) {},
          ),
        );

        final tile = tester.widget<ListTile>(find.byType(ListTile).first);
        expect(
          tile.minVerticalPadding,
          0.0,
          reason:
              'minVerticalPadding must be 0 — default 8dp enforced minimum '
              'inflates the card height and defeats the compaction fix',
        );
      },
    );

    testWidgets(
      'selected _TypeCard title uses FontWeight.w600',
      (tester) async {
        setViewport(tester, const Size(390, 844));

        await pumpWithMood(
          tester,
          GoalTypePicker(
            selectedType: GoalType.timeTarget,
            onTypeSelected: (_) {},
          ),
        );

        // Find the title Text of the selected card (first card = timeTarget).
        // The title Text is the direct child of ListTile's title slot.
        // We find all Text widgets and pick the one with the timeTarget title.
        final titleFinder = find.text(
          'I want to spend regular time on something',
        );
        expect(titleFinder, findsOneWidget);

        final titleWidget = tester.widget<Text>(titleFinder);
        final resolvedWeight =
            titleWidget.style?.fontWeight ?? FontWeight.normal;
        expect(
          resolvedWeight,
          FontWeight.w600,
          reason:
              'Selected card title must use FontWeight.w600 — '
              'selection must not rely on color alone (accessibility)',
        );
      },
    );
  });
}
