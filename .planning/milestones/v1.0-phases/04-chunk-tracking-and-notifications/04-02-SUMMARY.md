---
phase: "04-chunk-tracking-and-notifications"
plan: "04-02"
subsystem: "swipe-ui-notifications"
tags: ["swipe-gestures", "dismissible", "notifications", "end-of-day-summary", "web-banner"]
dependency_graph:
  requires: ["04-01"]
  provides: ["swipeable-chunk-card", "end-of-day-summary", "notification-service", "summary-route"]
  affects:
    - "lib/screens/schedule/widgets/swipeable_chunk_card.dart"
    - "lib/screens/schedule/widgets/chunk_card.dart"
    - "lib/screens/schedule/schedule_screen.dart"
    - "lib/screens/end_of_day/end_of_day_summary_screen.dart"
    - "lib/router.dart"
    - "lib/main.dart"
    - "lib/services/notification_service.dart"
    - "lib/screens/schedule/checkin_screen.dart"
tech_stack:
  added:
    - "flutter_local_notifications ^21.0.0"
    - "timezone ^0.11.0"
    - "flutter_timezone ^5.0.2"
  patterns:
    - "SwipeableChunkCard wraps ChunkCard in Dismissible (confirmDismiss=false, gesture-only)"
    - "rootNavigatorKey exposed from router.dart for context-free navigation in notification callbacks"
    - "NotificationService static singleton initialized in main() before runApp"
    - "iOS permission deferred to post-check-in via requestIOSPermissions()"
key_files:
  created:
    - "lib/screens/schedule/widgets/swipeable_chunk_card.dart"
    - "lib/screens/end_of_day/end_of_day_summary_screen.dart"
    - "lib/services/notification_service.dart"
  modified:
    - "lib/screens/schedule/widgets/chunk_card.dart"
    - "lib/screens/schedule/schedule_screen.dart"
    - "lib/router.dart"
    - "lib/main.dart"
    - "lib/screens/schedule/checkin_screen.dart"
    - "pubspec.yaml"
decisions:
  - "flutter_local_notifications v21 uses all-named-parameter API; positional args from RESEARCH.md pattern needed updating"
  - "rootNavigatorKey passed as navigatorKey to GoRouter so context.push works after notification tap"
  - "onTapCallback routes to /schedule when schedule exists, /schedule/checkin otherwise (AC-3)"
  - "LinuxInitializationSettings added to avoid missing platform settings on Linux desktop"
  - "timezone setup skipped on Windows/Linux since those platforms don't use TZDateTime scheduling"
metrics:
  duration: "5 minutes"
  completed: "2026-04-02"
  tasks: 2
  files: 9
---

# Phase 4 Plan 2: Swipe UI, End-of-Day Summary, and NotificationService Summary

SwipeableChunkCard widget extracting Dismissible gesture logic into its own file, ChunkCard isSkipped visual state, ScheduleScreen Web banner and "View your day" overflow menu, EndOfDaySummaryScreen with hero stat and per-goal breakdown, /summary route, NotificationService with flutter_local_notifications v21, and iOS permission request after first check-in.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | SwipeableChunkCard, ChunkCard isSkipped state, ScheduleScreen Web banner + overflow menu | 9501c10 | swipeable_chunk_card.dart, chunk_card.dart, schedule_screen.dart |
| 2 | EndOfDaySummaryScreen, /summary route, NotificationService, iOS permission request | 1658885 | end_of_day_summary_screen.dart, notification_service.dart, router.dart, main.dart, checkin_screen.dart, pubspec.yaml |

## Key Implementation Details

### SwipeableChunkCard

Created `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — a `StatelessWidget` that wraps `ChunkCard` in a `Dismissible`:
- Break chunks (`shortBreak`, `longBreak`) returned as plain `ChunkCard` (no swipe)
- Active work chunks: `DismissDirection.horizontal`, `confirmDismiss` calls `markComplete`/`markSkipped` then returns `false` (card stays in list)
- Resolved chunks: `DismissDirection.none` (no re-swipe)
- Swipe right: `Colors.green.shade400` background + `Icons.check_circle` + `HapticFeedback.lightImpact()`
- Swipe left: `Colors.orange.shade300` background + `Icons.arrow_forward` + `HapticFeedback.lightImpact()`

### ChunkCard isSkipped Visual State

Updated `_buildWork` in `chunk_card.dart`:
- `barColor`: `chunk.isCompleted || chunk.isSkipped` → `Colors.grey.shade400`
- `contentOpacity`: `chunk.isCompleted || chunk.isSkipped` → `0.5`
- Trailing icon: `isCompleted` → `check_circle` (green), `isSkipped` → `arrow_forward` (onSurfaceVariant), else `radio_button_unchecked`

### ScheduleScreen Changes

Replaced inline Dismissible with `SwipeableChunkCard`. Added:
- `_resolvedWorkChunkRatio()` helper: (completed + skipped) / total work chunks
- `PopupMenuButton` in AppBar actions: "View your day" visible when ratio >= 0.5 → `context.push('/summary')`
- `kIsWeb` `MaterialBanner` in empty state: "Start your morning check-in..." with "Start check-in" CTA
- Refactored to `_buildSwipeableCard()` and `_lookupGoalColor()` helpers

### EndOfDaySummaryScreen

Created `lib/screens/end_of_day/end_of_day_summary_screen.dart`:
- Section A: Large centered completed count + "of N chunks complete" sub-label
- Section B: "By goal" heading + `ListTile` rows (12dp `CircleAvatar` + goal name + "X of Y")
- Section C: "N chunk(s) set aside today." — only shown when skipped > 0
- Section D: Full-width "See you tomorrow" `ElevatedButton` → `context.pop()`

### Router and Navigation

- `rootNavigatorKey = GlobalKey<NavigatorState>()` exposed from `router.dart`
- Passed to `GoRouter(navigatorKey: rootNavigatorKey, ...)` so notification tap navigation works
- `/summary` `GoRoute` added outside `StatefulShellRoute` (no bottom nav)

### NotificationService

Created `lib/services/notification_service.dart` with flutter_local_notifications v21 API (all-named parameters):
- `initialize()`: configures timezone, creates `DarwinInitializationSettings` with all permissions deferred, calls `_plugin.initialize(settings: settings, ...)`
- `scheduleMorningNotification()` / `scheduleMidDayNudge()`: use `_plugin.zonedSchedule(id: ..., ...)`
- `cancelMorningNotification()` / `cancelMidDayNudge()`: use `_plugin.cancel(id: ...)`
- `requestIOSPermissions()`: no-op on non-iOS; calls `IOSFlutterLocalNotificationsPlugin.requestPermissions()`
- `onTapCallback` static setter for notification tap navigation

### main.dart Wiring

- `await NotificationService.initialize()` called after `scheduleNotifier.init()` before `runApp()`
- `NotificationService.onTapCallback` set to navigate via `rootNavigatorKey`: `/schedule` if schedule exists, `/schedule/checkin` otherwise (AC-3)

### iOS Permission Request

In `checkin_screen.dart` `_generate()` method: `await NotificationService.requestIOSPermissions()` called after `generateToday()` returns successfully — after first mood check-in, before state update.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] flutter_local_notifications v21 uses all-named-parameter API**
- **Found during:** Task 2 — `flutter analyze` after initial implementation
- **Issue:** RESEARCH.md pattern used positional arguments (`_plugin.initialize(settings, ...)`, `_plugin.cancel(0)`, `_plugin.zonedSchedule(0, 'title', ...)`) but v21 changed these to named parameters (`initialize(settings: settings)`, `cancel(id: 0)`, `zonedSchedule(id: 0, title: ..., ...)`)
- **Fix:** Updated all calls in `notification_service.dart` to use named parameters
- **Files modified:** `lib/services/notification_service.dart`
- **Commit:** 1658885

## Verification Results

- `flutter analyze`: zero issues (ran clean)
- `flutter test`: 16/16 tests passed
- All acceptance criteria grep checks passed

## Known Stubs

None — all implemented functionality is fully wired.

## Self-Check: PASSED
