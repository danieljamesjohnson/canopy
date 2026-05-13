// Widget tests for ChunkCard hover-reveal behavior — Phase 6 Plan 06 Task 2.
//
// Covers AC-2 (MouseRegion.onEnter reveals checkbox + skip; onExit hides them)
// and the Phase 4 / RESEARCH.md Pitfall 5 invariant (touch-drag does NOT trigger
// hover events on a Dismissible-wrapped ChunkCard).

import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

ScheduledChunk _workChunk() => ScheduledChunk(
      id: 'c1',
      chunkTypeIndex: ChunkType.work.index,
      goalId: 'g1',
      durationMinutes: 45,
      rationale: 'Deep work',
    );

/// Locates the AnimatedOpacity that wraps the hover-revealed icons in
/// `_HoverableChunkContent.build`. Returns the topmost (closest to the icon)
/// matching ancestor — the production widget nests other AnimatedOpacity
/// instances elsewhere in the tree, so we anchor on the icon and walk up.
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
  group('ChunkCard hover behavior', () {
    testWidgets('MouseRegion.onEnter reveals check_circle_outline + skip_next_outlined',
        (tester) async {
      await pumpWithMood(tester, ChunkCard(chunk: _workChunk()));

      // Both icons exist in the tree at opacity 0 before hover.
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_outlined), findsOneWidget);
      expect(_hoverIconsOpacity(tester, Icons.check_circle_outline).opacity,
          0.0);

      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(ChunkCard)));
      await tester.pumpAndSettle();

      // After onEnter, AnimatedOpacity opacity is 1.0.
      expect(_hoverIconsOpacity(tester, Icons.check_circle_outline).opacity,
          1.0);
      expect(_hoverIconsOpacity(tester, Icons.skip_next_outlined).opacity,
          1.0);
    });

    testWidgets('MouseRegion.onExit returns hover icons to opacity 0',
        (tester) async {
      await pumpWithMood(tester, ChunkCard(chunk: _workChunk()));

      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Enter then exit.
      await gesture.moveTo(tester.getCenter(find.byType(ChunkCard)));
      await tester.pumpAndSettle();
      expect(_hoverIconsOpacity(tester, Icons.check_circle_outline).opacity,
          1.0);

      await gesture.moveTo(const Offset(-100, -100));
      await tester.pumpAndSettle();
      expect(_hoverIconsOpacity(tester, Icons.check_circle_outline).opacity,
          0.0);
    });

    testWidgets(
        'touch drag does NOT reveal hover icons (RESEARCH.md Pitfall 5)',
        (tester) async {
      await pumpWithMood(tester, ChunkCard(chunk: _workChunk()));
      // No mouse gesture created here — only `tester.drag` (a touch-style
      // pointer events stream) is sent. MouseRegion.onEnter must NOT fire.
      await tester.drag(find.byType(ChunkCard), const Offset(300, 0));
      await tester.pumpAndSettle();

      // Hover icons remain at opacity 0 throughout the touch drag.
      expect(_hoverIconsOpacity(tester, Icons.check_circle_outline).opacity,
          0.0);
      expect(_hoverIconsOpacity(tester, Icons.skip_next_outlined).opacity,
          0.0);
    });
  });
}
