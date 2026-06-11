// Wave 0 stub for READ-04 — turns green when Plan 08-03 creates
// lib/screens/focus/focus_screen.dart with a 25-minute countdown timer.
//
// Status: RED until Plan 08-03.
//
// A local stub FocusScreen is defined below so this file compiles before the
// real implementation exists. Plan 08-03 should REMOVE the local stub and
// add the real import:
//   import 'package:canopy/screens/focus/focus_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/mood_pump.dart';

// ---------------------------------------------------------------------------
// LOCAL STUB — remove and replace with real import when Plan 08-03 lands.
// ---------------------------------------------------------------------------

/// Placeholder FocusScreen that renders NOTHING, so the timer-label and
/// button expects below fail RED until the real widget is implemented.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, required this.chunkId});

  final String chunkId;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  @override
  void dispose() {
    // Stub: no timer to cancel (yet).
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Stub renders nothing — causes all expects to fail RED.
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FocusScreen (READ-04)', () {
    testWidgets(
      'renders timer label or start button for 25-minute countdown',
      (tester) async {
        await pumpWithMood(tester, const FocusScreen(chunkId: 'c1'));

        // These expects are RED until Plan 08-03 replaces the stub widget.
        // The real FocusScreen must show the timer display (e.g. '25:00')
        // or a 'Start 25 min timer' button when first loaded.
        final hasTimerLabel = tester.any(find.text('25:00'));
        final hasStartButton = tester.any(find.text('Start 25 min timer'));
        expect(
          hasTimerLabel || hasStartButton,
          isTrue,
          reason:
              'READ-04: FocusScreen must show the 25-min timer label or start button',
        );
      },
    );

    testWidgets(
      'Timer.cancel called on dispose — no setState-after-dispose exception',
      (tester) async {
        // Pump the FocusScreen and then remove it from the tree.
        // With the real implementation, failing to cancel the timer in dispose()
        // would cause a setState-after-dispose exception when the Timer fires
        // after the widget is unmounted. This test verifies the dispose path is
        // clean (Pitfall 1 from RESEARCH.md).
        await pumpWithMood(tester, const FocusScreen(chunkId: 'c1'));

        // Attempt to start the timer (noop on stub).
        if (tester.any(find.text('Start 25 min timer'))) {
          await tester.tap(find.text('Start 25 min timer'));
          await tester.pump();
        }

        // Replace the widget tree to trigger dispose().
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pump();

        // If no exception was thrown, the dispose path is clean.
        // The stub always passes this test; the real implementation must
        // also pass it (tested by the absence of FlutterError in the logs).
      },
    );
  });
}
