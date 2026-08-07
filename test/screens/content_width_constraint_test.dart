// Widget tests for primary screen content-width constraint — Phase 18 Plan 01.
// Phase 22 Plan 04 (UNIFY-02): repointed from the old Home landing screen to
// TodayScreen — the merged destination that replaced the separate Home and
// Schedule screens — and dropped the permanently-skipped case for the old
// plan-view screen (it no longer exists; TodayScreen's own case is now the
// single POLISH-01 guard for this surface).
//
// Covers POLISH-01:
//   Primary screens (today, goals) must wrap their main content in a
//   ConstrainedBox(maxWidth: 720) on desktop widths. These tests pump each
//   screen at 1024dp, then assert at least one ConstrainedBox with
//   constraints.maxWidth == 720.0 is present in the widget tree.
//
// Pattern sources:
//   - Pump helper structure: test/screens/responsive_layout_test.dart
//   - Fake notifiers: test/screens/today_screen_now_state_test.dart
//   - setViewport: test/test_helpers/viewport.dart (auto-teardown)
//   - widgetList<ConstrainedBox> + any(): 18-PATTERNS.md §content_width_constraint_test.dart

import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/restoratives_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/theme_notifier.dart';
import 'package:canopy/screens/goals/goals_screen.dart';
import 'package:canopy/screens/today/today_screen.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/viewport.dart';

// ---------------------------------------------------------------------------
// In-memory GoalRepository — no Hive I/O.
// ---------------------------------------------------------------------------
class _InMemoryGoalRepository implements GoalRepository {
  @override
  Future<List<Goal>> getAll() async => [];
  @override
  Future<Goal?> getById(String id) async => null;
  @override
  Future<void> save(Goal goal) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<Goal>> getActive() async => [];
}

// ---------------------------------------------------------------------------
// Fake notifiers — override async init so no Hive bootstrap is needed.
// ---------------------------------------------------------------------------

class _FakeGoalsNotifier extends GoalsNotifier {
  _FakeGoalsNotifier() : super(repository: _InMemoryGoalRepository());

  @override
  Future<void> loadGoals() async {}
}

class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}

  @override
  bool get hasScheduleToday => false;
}

class _FakeThemeNotifier extends ThemeNotifier {
  @override
  Future<void> init() async {}

  @override
  bool get isPreCheckin => false;
}

class _FakeRestorativesNotifier extends RestorativesNotifier {
  @override
  Future<void> loadItems() async {}
}

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

/// Pumps GoalsScreen at the given viewport with a GoalsNotifier stub.
Future<void> _pumpGoalsScreenAt(WidgetTester tester, Size size) async {
  setViewport(tester, size);
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: ThemeNotifier.moodSeeds[3]!),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GoalsNotifier>.value(
          value: _FakeGoalsNotifier(),
        ),
      ],
      child: MaterialApp(theme: theme, home: const GoalsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps TodayScreen at the given viewport with the required provider stubs.
/// Uses hasScheduleToday == false (empty state) to avoid needing a full
/// DailySchedule fixture. The empty state still renders a Scaffold body that
/// must be constrained at 720dp (POLISH-01 covers the active body; see note).
Future<void> _pumpTodayScreenAt(WidgetTester tester, Size size) async {
  setViewport(tester, size);
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: ThemeNotifier.moodSeeds[3]!),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleNotifier>.value(
          value: _FakeScheduleNotifier(),
        ),
        ChangeNotifierProvider<GoalsNotifier>.value(
          value: _FakeGoalsNotifier(),
        ),
        ChangeNotifierProvider<ThemeNotifier>.value(
          value: _FakeThemeNotifier(),
        ),
        ChangeNotifierProvider<RestorativesNotifier>.value(
          value: _FakeRestorativesNotifier(),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        home: TodayScreen(now: () => DateTime(2026, 6, 15, 9, 0)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('POLISH-01 — content-width constraint (720dp) on primary screens', () {
    testWidgets(
      'Goals screen body contains ConstrainedBox with maxWidth == 720.0 at 1024dp',
      (tester) async {
        await _pumpGoalsScreenAt(tester, const Size(1024, 768));

        final boxes = tester.widgetList<ConstrainedBox>(
          find.byType(ConstrainedBox),
        );
        expect(
          boxes.any((b) => b.constraints.maxWidth == 720.0),
          isTrue,
          reason:
              'POLISH-01: Goals screen body must be constrained to 720dp on desktop. '
              'Plan 18-04 adds Align(topCenter) + ConstrainedBox(maxWidth: 720) '
              'around the CustomScrollView.',
        );
      },
    );

    testWidgets(
      'Today screen body contains ConstrainedBox with maxWidth == 720.0 at 1024dp',
      (tester) async {
        // Phase 22 (UNIFY-02): TodayScreen is the merged Home+Schedule
        // destination — this is now the single POLISH-01 guard for that
        // surface. The old Home-screen case and the permanently-skipped
        // Schedule-screen case (schedule_screen.dart no longer exists) are
        // both retired in favor of this one.
        await _pumpTodayScreenAt(tester, const Size(1024, 768));

        final boxes = tester.widgetList<ConstrainedBox>(
          find.byType(ConstrainedBox),
        );
        expect(
          boxes.any((b) => b.constraints.maxWidth == 720.0),
          isTrue,
          reason:
              'POLISH-01: Today screen body must be constrained to 720dp on desktop. '
              'Plan 18-04 adds Align(topCenter) + ConstrainedBox(maxWidth: 720) '
              'around the body Column.',
        );
      },
    );
  });
}
