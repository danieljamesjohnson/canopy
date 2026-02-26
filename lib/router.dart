import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'providers/settings_notifier.dart';
import 'screens/commitments/commitments_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/goals/archived_goals_screen.dart';
import 'screens/goals/goals_screen.dart';
import 'screens/schedule/schedule_screen.dart';
import 'screens/quarterly_review/quarterly_review_screen.dart';
import 'screens/settings/settings_screen.dart';

GoRouter createRouter(SettingsNotifier settingsNotifier) {
  return GoRouter(
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
          return _ScaffoldWithNavBar(navigationShell: navigationShell);
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
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
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
        builder: (context, state) => const QuarterlyReviewScreen(),
      ),
      // Commitments is outside the shell — settings-style focused screen.
      GoRoute(
        path: '/commitments',
        builder: (context, state) => const CommitmentsScreen(),
      ),
    ],
  );
}

class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Goals'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Schedule'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
