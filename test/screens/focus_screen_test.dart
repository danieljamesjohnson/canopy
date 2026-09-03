// Tests for FocusScreen (READ-04) — Phase 8 Plan 03.
//
// Covers:
//   - Timer label '25:00' or 'Start 25 min timer' button visible on load
//   - dispose() cancels the Timer with no setState-after-dispose exception

import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/screens/focus/focus_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Minimal fake ScheduleNotifier that skips Hive I/O.
/// todaySchedule returns null → FocusScreen renders with empty chunk list
/// (no early pop, since the chunk 'c1' won't be found as resolved).
class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}
}

/// Minimal fake GoalsNotifier that skips Hive I/O.
class _FakeGoalsNotifier extends GoalsNotifier {
  @override
  Future<void> loadGoals() async {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FocusScreen (READ-04)', () {
    testWidgets('renders timer label or start button for 25-minute countdown', (
      tester,
    ) async {
      await pumpWithMood(
        tester,
        const FocusScreen(chunkId: 'c1'),
        extraProviders: [
          ChangeNotifierProvider<ScheduleNotifier>(
            create: (_) => _FakeScheduleNotifier(),
          ),
          ChangeNotifierProvider<GoalsNotifier>(
            create: (_) => _FakeGoalsNotifier(),
          ),
        ],
      );

      // FocusScreen must show the timer display (e.g. '25:00')
      // or a 'Start 25 min timer' button when first loaded.
      final hasTimerLabel = tester.any(find.text('25:00'));
      final hasStartButton = tester.any(find.text('Start 25 min timer'));
      expect(
        hasTimerLabel || hasStartButton,
        isTrue,
        reason:
            'READ-04: FocusScreen must show the 25-min timer label or start button',
      );
    });

    testWidgets(
      'Timer.cancel called on dispose — no setState-after-dispose exception',
      (tester) async {
        // Pump the FocusScreen and then remove it from the tree.
        // Failing to cancel the timer in dispose() would cause a
        // setState-after-dispose exception when the Timer fires after the
        // widget is unmounted. This test verifies the dispose path is clean
        // (Pitfall 1 from RESEARCH.md / T-08-06).
        await pumpWithMood(
          tester,
          const FocusScreen(chunkId: 'c1'),
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>(
              create: (_) => _FakeScheduleNotifier(),
            ),
            ChangeNotifierProvider<GoalsNotifier>(
              create: (_) => _FakeGoalsNotifier(),
            ),
          ],
        );

        // Attempt to start the timer.
        if (tester.any(find.text('Start 25 min timer'))) {
          await tester.tap(find.text('Start 25 min timer'));
          await tester.pump();
        }

        // Replace the widget tree to trigger dispose().
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pump();

        // If no exception was thrown, the dispose path is clean.
        // The Timer was started and then cancelled via dispose() — no leak.
      },
    );
  });
}
