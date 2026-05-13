// Widget tests for go_router redirect logic — Phase 6 Plan 06 Task 3.
//
// Covers AC-4 row "go_router redirect respects onboardingComplete on direct
// URL load" and provides the automated mitigation for T-router-1 (the
// elevation-of-privilege threat where a deep-link bypasses onboarding).
//
// Strategy: pump `MaterialApp.router(routerConfig: createRouter(settings))`
// with a fake SettingsNotifier and assert against
// `router.routerDelegate.currentConfiguration.uri.path` AFTER the redirect
// runs. This avoids rendering the screen widgets (which would pull in
// GoalsNotifier / ScheduleNotifier / CommitmentsNotifier provider deps and
// Hive boxes) — the redirect is what the test is actually about.
//
// We DO render the resulting screens, so we wrap createRouter's output in a
// MultiProvider that supplies stub notifiers; `pumpAndSettle` is avoided in
// favor of a small number of explicit `pump()` calls so post-frame init
// callbacks don't crash on a missing Hive box.

import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/settings_notifier.dart';
import 'package:canopy/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../test_helpers/viewport.dart';

/// Test double — overrides only the surface the router actually reads
/// (`onboardingComplete`) and skips any Hive I/O.
class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier({required bool onboardingComplete})
      : _flag = onboardingComplete;
  bool _flag;
  @override
  bool get onboardingComplete => _flag;

  void setForTest(bool value) {
    _flag = value;
    notifyListeners();
  }
}

/// Test double — overrides `loadGoals()` to a no-op so GoalsScreen's
/// `addPostFrameCallback(() => context.read<GoalsNotifier>().loadGoals())`
/// (goals_screen.dart:23-25) does NOT crash on the missing Hive box.
class _FakeGoalsNotifier extends GoalsNotifier {
  @override
  Future<void> loadGoals() async {
    // intentional no-op for tests; the underlying _goals list stays empty.
  }
}

/// Test double — overrides `init()` and `generateToday()` to avoid Hive.
class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}
}

/// Test double — placeholder. CommitmentsNotifier doesn't crash on
/// construction (the Hive box access is lazy on first method call), so a
/// plain instance works in router-redirect tests, but we still subclass to
/// be defensive against future additions.
class _FakeCommitmentsNotifier extends CommitmentsNotifier {}

Future<GoRouter> _pumpRouter(
  WidgetTester tester, {
  required bool onboardingComplete,
  required String initialPath,
}) async {
  // Use a generous viewport so the destination screens (OnboardingScreen
  // and the shell-wrapped GoalsScreen/ScheduleScreen) render without
  // overflowing the default 800×600 test view. We test the redirect
  // outcome, not the layout — but RenderFlex overflows during the build
  // surface as test failures even though they're cosmetic.
  setViewport(tester, const Size(1200, 1200));

  final settings = _FakeSettingsNotifier(onboardingComplete: onboardingComplete);
  final router = createRouter(settings);
  // Force the initial route BEFORE the widget pumps so the redirect runs on
  // the very first frame.
  router.go(initialPath);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsNotifier>.value(value: settings),
        ChangeNotifierProvider<GoalsNotifier>(create: (_) => _FakeGoalsNotifier()),
        ChangeNotifierProvider<ScheduleNotifier>(
            create: (_) => _FakeScheduleNotifier()),
        ChangeNotifierProvider<CommitmentsNotifier>(
            create: (_) => _FakeCommitmentsNotifier()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // One pump triggers the redirect (synchronous) and the first widget build.
  // pumpAndSettle is unsafe because destination screens may run
  // post-frame callbacks that would touch Hive even with fakes (any future
  // addition would surface as a test regression). A single pump is
  // sufficient: the redirect runs during initial route resolution.
  await tester.pump();
  return router;
}

String _currentPath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  group('go_router redirect honoring onboardingComplete', () {
    testWidgets(
      'onboardingComplete=false → /schedule deep link redirects to /onboarding',
      (tester) async {
        final router = await _pumpRouter(
          tester,
          onboardingComplete: false,
          initialPath: '/schedule',
        );
        expect(_currentPath(router), '/onboarding');
      },
    );

    testWidgets(
      'onboardingComplete=false → /goals deep link redirects to /onboarding',
      (tester) async {
        final router = await _pumpRouter(
          tester,
          onboardingComplete: false,
          initialPath: '/goals',
        );
        expect(_currentPath(router), '/onboarding');
      },
    );

    testWidgets(
      'onboardingComplete=true → /schedule deep link loads /schedule',
      (tester) async {
        final router = await _pumpRouter(
          tester,
          onboardingComplete: true,
          initialPath: '/schedule',
        );
        expect(_currentPath(router), '/schedule');
      },
    );

    testWidgets(
      'onboardingComplete=true → /goals deep link loads /goals',
      (tester) async {
        final router = await _pumpRouter(
          tester,
          onboardingComplete: true,
          initialPath: '/goals',
        );
        expect(_currentPath(router), '/goals');
      },
    );

    testWidgets(
      'onboardingComplete=true → /onboarding deep link redirects to /goals',
      (tester) async {
        // The router's redirect callback (lib/router.dart:33) sends already-
        // onboarded users away from /onboarding into the app shell.
        final router = await _pumpRouter(
          tester,
          onboardingComplete: true,
          initialPath: '/onboarding',
        );
        expect(_currentPath(router), '/goals');
      },
    );
  });
}
