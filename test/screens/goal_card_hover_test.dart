// Widget tests for GoalCard hover-reveal behavior — Phase 6 Plan 06 Task 2.
//
// Covers AC-2 (InkWell.onHover reveals edit + archive icons on GoalCard).
// Also asserts the "trailing non-null" guard: when GoalsScreen supplies a
// drag handle in the trailing slot, the hover icons are suppressed entirely.

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/screens/goals/widgets/goal_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

Goal _stubGoal() =>
    Goal(id: 'g1', name: 'Exercise', goalTypeIndex: 0, color: '#4CAF50');

AnimatedOpacity _hoverIconsOpacity(WidgetTester tester, IconData iconData) {
  return tester.widget<AnimatedOpacity>(
    find
        .ancestor(
          of: find.byIcon(iconData),
          matching: find.byType(AnimatedOpacity),
        )
        .first,
  );
}

void main() {
  group('GoalCard hover behavior (no trailing supplied)', () {
    testWidgets(
      'InkWell.onHover(true) reveals edit_outlined + archive_outlined',
      (tester) async {
        await pumpWithMood(
          tester,
          GoalCard(
            goal: _stubGoal(),
            onTap: () {},
            onEdit: () {},
            onArchive: () {},
          ),
        );

        // Pre-hover both icons exist at opacity 0.
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
        expect(_hoverIconsOpacity(tester, Icons.edit_outlined).opacity, 0.0);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.byType(GoalCard)));
        await tester.pumpAndSettle();

        expect(_hoverIconsOpacity(tester, Icons.edit_outlined).opacity, 1.0);
        expect(_hoverIconsOpacity(tester, Icons.archive_outlined).opacity, 1.0);
      },
    );

    testWidgets('InkWell.onHover(false) returns hover icons to opacity 0', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        GoalCard(
          goal: _stubGoal(),
          onTap: () {},
          onEdit: () {},
          onArchive: () {},
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.byType(GoalCard)));
      await tester.pumpAndSettle();
      expect(_hoverIconsOpacity(tester, Icons.edit_outlined).opacity, 1.0);

      await gesture.moveTo(const Offset(-100, -100));
      await tester.pumpAndSettle();
      expect(_hoverIconsOpacity(tester, Icons.edit_outlined).opacity, 0.0);
    });
  });

  group('GoalCard hover behavior (trailing non-null guard)', () {
    testWidgets(
      'when trailing is supplied, hover icons are NOT shown (suppressed)',
      (tester) async {
        await pumpWithMood(
          tester,
          GoalCard(
            goal: _stubGoal(),
            onTap: () {},
            onEdit: () {},
            onArchive: () {},
            trailing: const SizedBox(width: 20, height: 20),
          ),
        );

        // The trailing slot replaces hover icons entirely — neither edit nor
        // archive icons exist in the tree (per goal_card.dart `showHoverIcons`
        // guard on line 167).
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.archive_outlined), findsNothing);

        // Hovering still doesn't reveal them.
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.byType(GoalCard)));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.archive_outlined), findsNothing);
      },
    );
  });
}
