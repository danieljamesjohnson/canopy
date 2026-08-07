// Widget tests for HomeScreen's BreathingPulseCta — Phase 6 Plan 06 Task 3.
//
// Covers the "Pulse" rows in 06-VALIDATION.md:
//   - Pulse animates when no mood set (enabled=true)
//   - Pulse stops when mood is set (enabled=false)
//   - Pulse respects reduced-motion (controller pinned to 0.5,
//     blur = 8 + 8*0.5 = 12px, no frame-to-frame change)
//
// Per W-3 we pump `BreathingPulseCta` directly (extracted public widget in
// home_screen.dart) so the test does not need HomeScreen's full provider
// tree.
//
// The reduced-motion path reads from
// `WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations`
// (see home_screen.dart `_animationsDisabled` getter). Tests configure that
// via `tester.platformDispatcher.accessibilityFeaturesTestValue` — the
// canonical Flutter test path; `MediaQueryData(disableAnimations: true)`
// alone does NOT propagate to the platform dispatcher.

import 'dart:ui' show AccessibilityFeatures;

import 'package:canopy/screens/today/widgets/breathing_pulse_cta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pulls the current `BoxShadow.blurRadius` from the BoxDecoration that
/// `BreathingPulseCta` renders. The widget wraps its child in a single
/// `Container` whose `BoxDecoration.boxShadow[0]` is the pulsing shadow.
double _currentBlur(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(BreathingPulseCta),
          matching: find.byType(Container),
        )
        .first,
  );
  final deco = container.decoration as BoxDecoration;
  return deco.boxShadow!.first.blurRadius;
}

Widget _harness({required bool enabled}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: BreathingPulseCta(
          enabled: enabled,
          onPressed: () {},
          child: OutlinedButton(
            onPressed: () {},
            child: const Text('Start your day'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('BreathingPulseCta', () {
    testWidgets(
        'animates when enabled=true (blur changes across frames)',
        (tester) async {
      await tester.pumpWidget(_harness(enabled: true));
      // One frame to start the AnimationController.
      await tester.pump();
      final blurA = _currentBlur(tester);
      // Half the 2400ms period to land somewhere along the easeInOut curve.
      await tester.pump(const Duration(milliseconds: 600));
      final blurB = _currentBlur(tester);
      expect(blurA, isNot(equals(blurB)),
          reason: 'controller must be running while enabled');
      // Bound check: 8.0–16.0 per UI-SPEC.
      expect(blurA, inInclusiveRange(8.0, 16.0));
      expect(blurB, inInclusiveRange(8.0, 16.0));
      // Clean up the timer the controller installed before the test ends.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'does NOT animate when enabled=false (blur static at midpoint)',
        (tester) async {
      await tester.pumpWidget(_harness(enabled: false));
      await tester.pump();
      final blurA = _currentBlur(tester);
      await tester.pump(const Duration(milliseconds: 600));
      final blurB = _currentBlur(tester);
      expect(blurA, equals(blurB),
          reason: 'controller must be stopped when disabled');
      // 8.0 + 8.0 * 0.5 = 12.0 — UI-SPEC midpoint.
      expect(blurA, closeTo(12.0, 0.001));
    });

    testWidgets(
        'respects reduced-motion (controller pinned at midpoint, blur=12)',
        (tester) async {
      // Production reads platformDispatcher.accessibilityFeatures.disableAnimations
      // — set the test value, run the assertions, then restore.
      const AccessibilityFeatures fake = FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue = fake;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(_harness(enabled: true));
      await tester.pump();
      final blurA = _currentBlur(tester);
      await tester.pump(const Duration(milliseconds: 600));
      final blurB = _currentBlur(tester);
      expect(blurA, equals(blurB),
          reason: 'reduced-motion must NOT animate the pulse');
      expect(blurA, closeTo(12.0, 0.001));
    });
  });
}
