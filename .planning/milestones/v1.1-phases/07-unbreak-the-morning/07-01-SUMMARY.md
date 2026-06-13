---
phase: 07-unbreak-the-morning
plan: "01"
subsystem: providers/main/notifications/goal-form
tags: [loop-plumbing, startup-load, day-rollover, notifications, cursor-fix]
dependency_graph:
  requires: []
  provides:
    - GoalsNotifier injectable-repository seam (lib/providers/goals_notifier.dart)
    - CommitmentsNotifier injectable-repository seam (lib/providers/commitments_notifier.dart)
    - ScheduleNotifier day-rollover + WidgetsBindingObserver (lib/providers/schedule_notifier.dart)
    - Startup load of goals/commitments before runApp (lib/main.dart)
    - go_router notification navigation + auto-schedule (lib/main.dart)
    - Linux/web guard for zonedSchedule (lib/services/notification_service.dart)
    - Onboarding post-complete notification scheduling (lib/screens/onboarding/onboarding_screen.dart)
    - Goal-form TextEditingController hoisted to State (lib/screens/goals/goal_form_sheet.dart)
  affects:
    - checkin_screen.dart (now always receives non-empty goals/blocks on cold launch)
    - schedule_notifier.dart (hasScheduleToday is date-aware)
tech_stack:
  added: []
  patterns:
    - ThemeNotifier rollover pattern (WidgetsBindingObserver + _resetIfDayChanged) applied to ScheduleNotifier
    - Injectable constructor seam (optional repository param defaulting to Hive impl) applied to GoalsNotifier and CommitmentsNotifier
    - GoRouter captured before runApp and used directly in notification callback
key_files:
  created: []
  modified:
    - lib/providers/goals_notifier.dart
    - lib/providers/commitments_notifier.dart
    - lib/providers/schedule_notifier.dart
    - lib/main.dart
    - lib/services/notification_service.dart
    - lib/screens/onboarding/onboarding_screen.dart
    - lib/screens/goals/goal_form_sheet.dart
decisions:
  - "Capture GoRouter instance before runApp (local variable, passed to CanopyApp) so notification tap callback can call router.go() without a BuildContext — avoids the Navigator.pushNamed crash on go_router apps"
  - "Register GoalsNotifier and CommitmentsNotifier via ChangeNotifierProvider.value (not lazy create:) to guarantee the same pre-loaded instances are exposed to the widget tree"
  - "ScheduleNotifier._resetIfDayChanged uses DateFormat('yyyy-MM-dd') string comparison against schedule.dateYmd — consistent with the existing dateYmd format used throughout the app"
  - "ymdToday() is public (not private _ymdToday) in ScheduleNotifier to allow test access without @visibleForTesting annotation"
metrics:
  duration_minutes: 25
  completed_date: "2026-06-11"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 7
---

# Phase 07 Plan 01: Loop Plumbing — Startup Load, Day Rollover, Notification Fix, Cursor Fix Summary

Wired the four broken daily-loop paths (LOOP-01, LOOP-02, LOOP-04, LOOP-05) by mirroring patterns already proven in the codebase and making additive, non-breaking changes throughout.

## What Was Built

### Task 1: Startup load + day-rollover seam

**GoalsNotifier** (`lib/providers/goals_notifier.dart`): Added additive optional `GoalRepository? repository` constructor parameter defaulting to `HiveGoalRepository()`. Production callers using the default constructor are unaffected. Enables deterministic in-memory testing without Hive.

**CommitmentsNotifier** (`lib/providers/commitments_notifier.dart`): Same pattern — optional `CommitmentBlockRepository? repository` constructor param defaulting to `HiveCommitmentBlockRepository()`.

**ScheduleNotifier** (`lib/providers/schedule_notifier.dart`): Full rewrite to add:
- `with WidgetsBindingObserver` mixin
- Injectable `DateTime Function() now` constructor param (default `DateTime.now`) for testable day simulation
- `_resetIfDayChanged()`: clears `_todaySchedule` when the loaded schedule's `dateYmd` is not today's date
- `ymdToday()`: local-date encoding helper mirroring ThemeNotifier
- `hasScheduleToday`: date-aware (returns false if loaded schedule is from a prior day)
- `didChangeAppLifecycleState`: calls `_resetIfDayChanged` + `notifyListeners` on resume
- `dispose` override: removes the WidgetsBinding observer
- `init()`: calls `_resetIfDayChanged` at the end and registers the observer (LOOP-02)

**main.dart** (`lib/main.dart`):
- GoalsNotifier and CommitmentsNotifier constructed before `runApp`, `loadGoals()`/`loadBlocks()` awaited (LOOP-01)
- All four startup notifiers registered via `ChangeNotifierProvider.value` (not lazy `create:`)
- GoRouter instance captured into local `router` variable before `runApp`; passed to `CanopyApp` and used as `routerConfig` in `MaterialApp.router`
- Notification `onTapCallback` uses `router.go('/schedule')` / `router.go('/schedule/checkin')` — no `pushNamed` anywhere (LOOP-04)
- Morning notification auto-scheduled at startup when `settingsNotifier.morningNotificationEnabled` (LOOP-04)

### Task 2: Linux guard + onboarding schedule + cursor fix

**notification_service.dart** (`lib/services/notification_service.dart`): Added `Platform.isLinux || Platform.isWindows` early-return in `scheduleMorningNotification`, so `zonedSchedule` is a no-op on unsupported desktop platforms. iOS and Android are unaffected (LOOP-04).

**onboarding_screen.dart** (`lib/screens/onboarding/onboarding_screen.dart`): Added `NotificationService` import; added `scheduleMorningNotification` call in `_completeOnboarding` after `setOnboardingComplete(true)`, guarded by `morningNotificationEnabled`. Morning notification now auto-schedules at the end of onboarding (LOOP-04).

**goal_form_sheet.dart** (`lib/screens/goals/goal_form_sheet.dart`): Hoisted `_weeklyHoursController` and `_descriptionController` from `build()` into `_GoalFormSheetState` — declared as `late TextEditingController`, initialized in `initState` with seed values from `widget.goal`, disposed in `dispose` alongside `_nameController`. When goal type changes, both controllers are `.clear()`-ed (not recreated). `build()` no longer constructs any `TextEditingController` inline. Fixes cursor jumping to position 0 on every keystroke (LOOP-05).

## Verification

- `flutter analyze`: 0 errors, 5 pre-existing info-level deprecation warnings (unchanged from before this plan)
- `flutter test`: 90/90 tests pass

## Deviations from Plan

None — plan executed exactly as written. The implementation followed every specified pattern (ThemeNotifier rollover, injectable constructor seam, GoRouter capture-before-runApp) without deviation.

## Known Stubs

None — no stubs or placeholder data introduced in this plan.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `lib/providers/goals_notifier.dart` — exists, contains `GoalRepository? repository` constructor
- `lib/providers/commitments_notifier.dart` — exists, contains `CommitmentBlockRepository? repository` constructor
- `lib/providers/schedule_notifier.dart` — exists, contains `WidgetsBindingObserver`, `_resetIfDayChanged`, `hasScheduleToday` date-aware
- `lib/main.dart` — exists, contains `loadGoals`, `loadBlocks`, `router.go('/schedule')`
- `lib/services/notification_service.dart` — exists, contains `Platform.isLinux` guard
- `lib/screens/onboarding/onboarding_screen.dart` — exists, calls `scheduleMorningNotification` after `setOnboardingComplete`
- `lib/screens/goals/goal_form_sheet.dart` — exists, `_weeklyHoursController`/`_descriptionController` in State
- Commits b0d3d60 and d288b8d exist in git log
