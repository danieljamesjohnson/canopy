// Widget tests for platform-gated drag handle visibility — Phase 14 Plan 01.
//
// Updated from Phase 6 Plan 06 to reflect Phase 14 changes:
//   - Icon changed from Icons.drag_handle to Icons.drag_indicator
//   - Mobile (Android/iOS) now shows a visible Icons.drag_indicator handle
//     (was previously hidden — trailing: null)
//   - Desktop (macOS) continues to show Icons.drag_indicator at 0.6 opacity
//     inside a SizedBox(44×44) with Tooltip wrapper

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

Goal _stubGoal(String id, String name) =>
    Goal(id: id, name: name, goalTypeIndex: 0, color: '#4CAF50');

/// Production-mirroring reorderable list. Mirrors the platform gate logic
/// from `goals_screen.dart:_buildReorderableSection` (Phase 14 Phase 01):
/// both mobile and desktop now show Icons.drag_indicator, but with different
/// wrappers and colors.
Widget _reorderableSection(List<Goal> goals) {
  final colorScheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrangeAccent),
  ).colorScheme;
  final isMobileTouch =
      defaultTargetPlatform == TargetPlatform.android ||
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
          ? ReorderableDelayedDragStartListener(
              index: i,
              child: Semantics(
                label: 'Drag to reorder',
                button: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: colorScheme.outlineVariant,
                  ),
                ),
              ),
            )
          : Tooltip(
              message: 'Drag to reorder',
              child: ReorderableDelayedDragStartListener(
                index: i,
                child: Semantics(
                  label: 'Drag to reorder',
                  button: false,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: 0.6,
                        child: Icon(
                          Icons.drag_indicator,
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    ),
    onReorderItem: (oldIdx, newIdx) {},
  );
}

/// Runs [test] under [platform], guaranteeing the foundation debug variable
/// is reset BEFORE the test body returns.
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
    testWidgets(
      'visible on Android (mobile touch — Phase 14: now always shown)',
      (tester) async {
        await _underPlatform(TargetPlatform.android, () async {
          await pumpWithMood(
            tester,
            _reorderableSection([_stubGoal('g1', 'Exercise')]),
          );
          expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
        });
      },
    );

    testWidgets('visible on iOS (mobile touch — Phase 14: now always shown)', (
      tester,
    ) async {
      await _underPlatform(TargetPlatform.iOS, () async {
        await pumpWithMood(
          tester,
          _reorderableSection([_stubGoal('g1', 'Exercise')]),
        );
        expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
      });
    });

    testWidgets('visible at 0.6 opacity on macOS (desktop)', (tester) async {
      await _underPlatform(TargetPlatform.macOS, () async {
        await pumpWithMood(
          tester,
          _reorderableSection([_stubGoal('g1', 'Exercise')]),
        );
        expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
        final ao = tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byIcon(Icons.drag_indicator),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        );
        expect(ao.opacity, 0.6);
      });
    });
  });
}
