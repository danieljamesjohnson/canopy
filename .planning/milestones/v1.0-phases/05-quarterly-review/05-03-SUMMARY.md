---
phase: 05-quarterly-review
plan: "03"
subsystem: navigation
tags: [home-screen, settings, routing, quarterly-review, banner]
dependency_graph:
  requires: ["05-01"]
  provides: ["review-entry-points", "past-reviews-screen"]
  affects: ["lib/screens/home/home_screen.dart", "lib/router.dart"]
tech_stack:
  added: []
  patterns: ["StatefulWidget-setState", "GoRouter child routes", "Dismissible banner"]
key_files:
  created:
    - lib/screens/home/widgets/review_banner.dart
    - lib/screens/settings/past_reviews_screen.dart
  modified:
    - lib/screens/home/home_screen.dart
    - lib/screens/settings/settings_screen.dart
    - lib/router.dart
decisions:
  - "HomeScreen converted from StatelessWidget to StatefulWidget to track in-memory banner dismissal and review window state"
  - "Banner dismiss state held in memory only — reappears on app restart per UI-SPEC interaction contract"
  - "_buildEmptyState refactored from returning Scaffold to a Column with ReviewBanner as first item so banner shows in both schedule-present and empty states"
  - "/settings/past-reviews added as child route inside StatefulShellBranch so bottom nav remains visible on past reviews screen"
metrics:
  duration: "8 minutes"
  completed_date: "2026-04-07"
  tasks_completed: 2
  files_changed: 5
---

# Phase 05 Plan 03: Navigation Entry Points Summary

Review entry points wired: dismissable home screen banner using `primaryContainer` and `QuarterlyAggregationService.isInReviewWindow`, plus permanent Past reviews screen accessible from Settings at `/settings/past-reviews`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | ReviewBanner widget and HomeScreen integration | 5e5c8da | review_banner.dart, home_screen.dart |
| 2 | PastReviewsScreen, Settings entry, route registration | e88c023 | past_reviews_screen.dart, settings_screen.dart, router.dart |

## What Was Built

**ReviewBanner** (`lib/screens/home/widgets/review_banner.dart`): Dismissable card accepting `onStart` and `onDismiss` callbacks. Uses `Dismissible` with `key: Key('review_banner')`, `primaryContainer` card background, bold `titleMedium` title, `bodySmall` subtitle with `onSurfaceVariant` color, close `IconButton`, and `ElevatedButton` for "Start review".

**HomeScreen** converted to `StatefulWidget` with `_bannerDismissed` and `_inReviewWindow` state. `_checkReviewWindow` runs in `initState` via `HiveCompletionLogRepository` and `HiveQuarterlySnapshotRepository`. Banner inserted after `ScheduleProgressBar` in schedule-present path and as first content in empty state path.

**PastReviewsScreen** (`lib/screens/settings/past_reviews_screen.dart`): Loads all `QuarterlySnapshot` records, sorts descending by `completedAt`. Empty state shows "No reviews yet -- complete your first quarterly review to see it here." List shows "Q{n} -- {MMM yyyy}" with trailing "{N} chunks completed" derived from `goalChunkTotals.values` sum.

**SettingsScreen**: Added "Reviews" section heading and "Past reviews" `ListTile` with `Icons.history` and `Icons.chevron_right` after the Data section divider. Uses `context.push('/settings/past-reviews')`.

**Router**: `/settings/past-reviews` added as a child `GoRoute` under `/settings` inside the `StatefulShellBranch`, keeping bottom nav visible on the past reviews screen.

## Verification

- `flutter analyze` — zero issues
- `flutter test` — 31 tests pass, no regressions
- `grep 'ReviewBanner' lib/screens/home/home_screen.dart` — 2 matches
- `grep 'past-reviews' lib/router.dart` — 1 match
- `grep 'Past reviews' lib/screens/settings/settings_screen.dart` — 2 matches

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all data paths are wired to real repositories.

## Self-Check: PASSED

- lib/screens/home/widgets/review_banner.dart — FOUND
- lib/screens/settings/past_reviews_screen.dart — FOUND
- lib/screens/home/home_screen.dart — FOUND (modified)
- lib/screens/settings/settings_screen.dart — FOUND (modified)
- lib/router.dart — FOUND (modified)
- Commit 5e5c8da — FOUND
- Commit e88c023 — FOUND
