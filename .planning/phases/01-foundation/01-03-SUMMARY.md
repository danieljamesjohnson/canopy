---
phase: 01-foundation
plan: 03
subsystem: routing
tags: [go_router, navigation, screens, providers]
dependency_graph:
  requires: [01-01]
  provides: [router, stub-screens, stub-providers]
  affects: [01-04]
tech_stack:
  added: [go_router StatefulShellRoute, NavigationBar]
  patterns: [factory-function router, ChangeNotifier stubs, shell-route navigation]
key_files:
  created:
    - lib/router.dart
    - lib/screens/home/home_screen.dart
    - lib/screens/onboarding/onboarding_screen.dart
    - lib/screens/goals/goals_screen.dart
    - lib/screens/schedule/schedule_screen.dart
    - lib/screens/quarterly_review/quarterly_review_screen.dart
    - lib/screens/settings/settings_screen.dart
    - lib/providers/goals_notifier.dart
    - lib/providers/commitments_notifier.dart
    - lib/providers/schedule_notifier.dart
    - lib/providers/settings_notifier.dart
  modified: []
decisions:
  - "createRouter(SettingsNotifier) is a factory function not a global — prevents GoRouter initialization before Provider tree exists"
  - "SettingsNotifier gets minimal onboardingComplete state in Phase 1 because go_router refreshListenable requires it now"
  - "Onboarding and QuarterlyReview routes placed outside StatefulShellRoute shell — no bottom nav bar shown on those screens"
metrics:
  duration: 4 minutes
  completed: 2026-02-24
---

# Phase 1 Plan 03: Routing and Stub Screens Summary

**One-liner:** go_router StatefulShellRoute with 4-tab NavigationBar, onboarding redirect via SettingsNotifier.refreshListenable, and 6 stub screens + 4 ChangeNotifier stubs.

## Route Table

| Path | Screen Class | Shell? |
|------|-------------|--------|
| `/home` | HomeScreen | Yes (tab 0) |
| `/goals` | GoalsScreen | Yes (tab 1) |
| `/schedule` | ScheduleScreen | Yes (tab 2) |
| `/settings` | SettingsScreen | Yes (tab 3) |
| `/onboarding` | OnboardingScreen | No |
| `/review` | QuarterlyReviewScreen | No |

## Navigation Structure

- **Bottom nav (4 tabs):** Home, Goals, Schedule, Settings — wrapped by `StatefulShellRoute.indexedStack` via `_ScaffoldWithNavBar`
- **Outside shell:** Onboarding (`/onboarding`) and Quarterly Review (`/review`) — full-screen, no bottom nav bar
- **Redirect logic:** If `onboardingComplete == false`, any non-onboarding route redirects to `/onboarding`; once complete, `/onboarding` redirects to `/home`

## Decisions Made

1. **Factory function over global router** — `createRouter(SettingsNotifier)` receives the notifier as a parameter. This avoids the RESEARCH.md pitfall #3 where GoRouter initialized before the Provider tree fails when redirect reads Provider state. Plan 01-04 will instantiate and wire it.

2. **SettingsNotifier minimal state added now** — `onboardingComplete` getter and `setOnboardingComplete()` added in Phase 1 because `refreshListenable` requires a `Listenable` at router creation time. Full persistence to `shared_preferences` deferred to plan 01-04.

3. **Other three notifiers are empty stubs** — GoalsNotifier, CommitmentsNotifier, ScheduleNotifier have zero state or methods. Phase 2+ will add real implementation. This avoids premature state design.

4. **NavigationBar (Material 3)** — Used over BottomNavigationBar per ROADMAP.md Material 3 requirement. `NavigationDestination` with outlined icons.

## go_router API Observations (v17.1.0)

- `StatefulShellRoute.indexedStack` builder receives `(context, state, navigationShell)` — navigationShell is `StatefulNavigationShell`
- `navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex)` — the `initialLocation` flag navigates to the branch's initial route when tapping the already-selected tab
- `state.matchedLocation` used in redirect (not `state.fullPath`) for accurate current-location check

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] lib/router.dart exists and contains StatefulShellRoute, refreshListenable
- [x] All 6 screen files exist
- [x] All 4 provider files exist
- [x] dart analyze lib/screens/ lib/providers/ lib/router.dart — No issues found
- [x] Commits: 2c4e32e (screens/providers), 7e4f6cd (router)

## Self-Check: PASSED
