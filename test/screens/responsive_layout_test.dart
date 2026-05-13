// Widget tests for ResponsiveShell — Phase 6 Plan 06 Task 2.
//
// Covers AC-1 (LayoutBuilder swaps NavigationBar → NavigationRail at the
// 720dp inclusive boundary) and AC-5 (existing widget tests pass + new
// breakpoint tests at 480/720/1200dp).
//
// To avoid pulling in the entire app provider tree (HomeScreen reads
// ThemeNotifier + ScheduleNotifier; GoalsScreen reads GoalsNotifier), this
// test wires its own minimal StatefulShellRoute with four trivial body
// widgets. ResponsiveShell is the SUT — what it wraps doesn't matter for
// the breakpoint assertion.

import 'package:canopy/widgets/responsive_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test_helpers/viewport.dart';

GoRouter _testRouter() {
  return GoRouter(
    initialLocation: '/a',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ResponsiveShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/a',
                builder: (_, _) => const _DummyBranch(label: 'A'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/b',
                builder: (_, _) => const _DummyBranch(label: 'B'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/c',
                builder: (_, _) => const _DummyBranch(label: 'C'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/d',
                builder: (_, _) => const _DummyBranch(label: 'D'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _DummyBranch extends StatelessWidget {
  const _DummyBranch({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('Branch $label'));
}

Future<void> _pumpShellAt(WidgetTester tester, Size logicalSize) async {
  setViewport(tester, logicalSize);
  await tester.pumpWidget(MaterialApp.router(routerConfig: _testRouter()));
  await tester.pumpAndSettle();
}

void main() {
  group('Responsive shell layout', () {
    testWidgets('shows NavigationBar at 480dp (mobile)', (tester) async {
      await _pumpShellAt(tester, const Size(480, 800));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('switches to NavigationRail at 720dp (inclusive boundary)',
        (tester) async {
      await _pumpShellAt(tester, const Size(720, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('shows NavigationRail at 1200dp (desktop)', (tester) async {
      await _pumpShellAt(tester, const Size(1200, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('does not throw OverflowError at any breakpoint',
        (tester) async {
      // Capture framework errors emitted during pumps at each breakpoint and
      // assert none of them are overflow exceptions.
      final captured = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => captured.add(details);
      addTearDown(() => FlutterError.onError = originalOnError);

      for (final size in const [
        Size(480, 800),
        Size(720, 800),
        Size(1200, 800),
      ]) {
        await _pumpShellAt(tester, size);
      }
      final overflowed = captured.where((d) =>
          d.exceptionAsString().contains('A RenderFlex overflowed'));
      expect(overflowed, isEmpty,
          reason: 'no RenderFlex overflow at 480/720/1200dp');
    });
  });
}
