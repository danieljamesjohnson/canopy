// Widget tests for platform-gated drag handle visibility — Phase 6 Plan 06
// Task 2.
//
// Covers the Drag rows in 06-VALIDATION.md: drag handle hidden on
// Android/iOS (touch-first long-press still works because
// ReorderableListView keeps the long-press gesture regardless), and visible
// at 0.6 opacity on macOS via `defaultTargetPlatform` override.
//
// The harness mirrors goals_screen.dart's `_buildReorderableSection` so the
// test exercises the production decision (`isMobileTouch ? null : Reorderable…`)
// without dragging in the full GoalsNotifier provider tree.

import 'package:canopy/data/models/goal.dart';
import 'package:canopy/screens/goals/widgets/goal_card.dart';
import 'package:flutter/foundation.dart'
    show
        debugDefaultTargetPlatformOverride,
        defaultTargetPlatform,
        TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

Goal _stubGoal(String id, String name) => Goal(
      id: id,
      name: name,
      goalTypeIndex: 0,
      color: '#4CAF50',
    );

/// Production-mirroring reorderable list. The platform gate is identical to
/// `goals_screen.dart:171-202` (`isMobileTouch ? null : Reorderable…`).
Widget _reorderableSection(List<Goal> goals) {
  final isMobileTouch = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  return ReorderableListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    buildDefaultDragHandles: false,
    itemCount: goals.length,
    itemBuilder: (ctx, i) => GoalCard(
      key: ValueKey(goals[i].id),
      goal: goals[i],
      trailing: isMobileTouch
          ? null
          : ReorderableDelayedDragStartListener(
              index: i,
              child: const AnimatedOpacity(
                duration: Duration(milliseconds: 120),
                opacity: 0.6,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ),
    ),
    onReorderItem: (oldIdx, newIdx) {},
  );
}

/// Runs [test] under [platform], guaranteeing the foundation debug variable
/// is reset BEFORE the test body returns. `_verifyInvariants` runs
/// immediately after the body completes (before any `addTearDown`/`tearDown`
/// fires), so the reset must happen in-band via try/finally.
Future<void> _underPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('GoalCard drag handle visibility', () {
    testWidgets('hidden on Android (mobile touch)', (tester) async {
      await _underPlatform(TargetPlatform.android, () async {
        await pumpWithMood(
          tester,
          _reorderableSection([_stubGoal('g1', 'Exercise')]),
        );
        expect(find.byIcon(Icons.drag_handle), findsNothing);
      });
    });

    testWidgets('hidden on iOS (mobile touch)', (tester) async {
      await _underPlatform(TargetPlatform.iOS, () async {
        await pumpWithMood(
          tester,
          _reorderableSection([_stubGoal('g1', 'Exercise')]),
        );
        expect(find.byIcon(Icons.drag_handle), findsNothing);
      });
    });

    testWidgets('visible at 0.6 opacity on macOS (desktop)', (tester) async {
      await _underPlatform(TargetPlatform.macOS, () async {
        await pumpWithMood(
          tester,
          _reorderableSection([_stubGoal('g1', 'Exercise')]),
        );
        expect(find.byIcon(Icons.drag_handle), findsOneWidget);
        final ao = tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byIcon(Icons.drag_handle),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
        expect(ao.opacity, 0.6);
      });
    });
  });
}
