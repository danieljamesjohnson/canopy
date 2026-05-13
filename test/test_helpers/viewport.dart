// Viewport helper for Phase 6 responsive-layout widget tests, per
// RESEARCH.md Pattern 6 and Pitfall 4.
//
// flutter_test's `tester.view` state persists across tests in the same
// run group. Tests that resize the viewport without calling
// `tester.view.reset` leak that size into subsequent tests and produce
// non-deterministic failures depending on test execution order. The
// `addTearDown(tester.view.reset)` call below is the lock that prevents
// that class of flake.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resizes the test view to [size] with a 1.0 device pixel ratio and
/// registers a teardown that resets the view after the test. Use this
/// instead of touching `tester.view.physicalSize` directly.
void setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}
