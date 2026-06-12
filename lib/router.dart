import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'providers/settings_notifier.dart';
import 'screens/commitments/commitments_screen.dart';
import 'screens/end_of_day/end_of_day_summary_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/goals/archived_goals_screen.dart';
import 'screens/goals/goals_screen.dart';
import 'screens/schedule/checkin_screen.dart';
import 'screens/schedule/schedule_screen.dart';
import 'screens/focus/focus_screen.dart';
import 'screens/quarterly_review/quarterly_review_screen.dart';
import 'screens/settings/past_reviews_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'widgets/responsive_shell.dart';

/// Root navigator key exposed so main.dart can use it for notification tap
/// navigation without a BuildContext (notification callbacks have no context).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(SettingsNotifier settingsNotifier) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: settingsNotifier,
    redirect: (context, state) {
      final onboardingDone = settingsNotifier.onboardingComplete;
      final onOnboarding = state.matchedLocation == '/onboarding';

      if (!onboardingDone && !onOnboarding) return '/onboarding';
      if (onboardingDone && onOnboarding) return '/home';
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ResponsiveShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/goals',
                builder: (context, state) => const GoalsScreen(),
                routes: [
                  GoRoute(
                    path: 'archived',
                    builder: (context, state) => const ArchivedGoalsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (context, state) => const ScheduleScreen(),
                routes: [
                  GoRoute(
                    path: 'checkin',
                    builder: (context, state) => const CheckinScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'past-reviews',
                    builder: (context, state) => const PastReviewsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Onboarding is outside the shell — no bottom nav shown.
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Quarterly review is outside the shell — full-screen experience.
      GoRoute(
        path: '/review',
        builder: (context, state) => QuarterlyReviewScreen(),
      ),
      // Commitments is outside the shell — settings-style focused screen.
      GoRoute(
        path: '/commitments',
        builder: (context, state) => const CommitmentsScreen(),
      ),
      // End-of-day summary is outside the shell — no bottom nav shown.
      GoRoute(
        path: '/summary',
        builder: (context, state) => const EndOfDaySummaryScreen(),
      ),
      // Focus mode is outside the shell — no bottom nav shown (same pattern
      // as /summary). Receives chunkId via state.extra (String).
      // Guard: if extra is not a String, return a harmless empty Scaffold
      // instead of an unsafe cast crash (T-08-05 / ASVS V5).
      GoRoute(
        path: '/focus',
        builder: (context, state) {
          if (state.extra is! String) {
            return const Scaffold(body: SizedBox.shrink());
          }
          return FocusScreen(chunkId: state.extra as String);
        },
      ),
    ],
  );
}
