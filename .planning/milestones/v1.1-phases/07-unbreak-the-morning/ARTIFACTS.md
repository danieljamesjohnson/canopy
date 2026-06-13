# Phase 7: Unbreak the Morning — Artifacts This Phase Produces

Every new symbol / method / file created or materially changed in Phase 7. Downstream phases (8, 9) consume the startup-loaded providers and the day-rollover seam.

## New files
- `test/screens/cold_launch_morning_loop_test.dart` — cold-launch regression test that seeds a goal via an in-memory repo, pumps `CheckinScreen` (no Goals/Commitments tab), and asserts the generated schedule contains a chunk whose `goalId` matches the seeded goal. Locks LOOP-01.

## New / changed public symbols and methods
- `GoalsNotifier({GoalRepository? repository})` — additive optional-repository constructor seam (defaults to `HiveGoalRepository()`). Enables deterministic tests; production unaffected. (lib/providers/goals_notifier.dart)
- `CommitmentsNotifier({CommitmentBlockRepository? repository})` — additive optional-repository constructor seam (defaults to `HiveCommitmentBlockRepository()`). (lib/providers/commitments_notifier.dart)
- `ScheduleNotifier` now `with WidgetsBindingObserver`:
  - `ScheduleNotifier({DateTime Function() now})` — injectable clock (defaults to `DateTime.now`).
  - `bool get hasScheduleToday` — now date-aware (true only when the loaded schedule's date is today).
  - `void _resetIfDayChanged()` — clears `_todaySchedule` when the loaded schedule is from a prior local day (mirrors `ThemeNotifier._resetIfDayChanged`).
  - `int _ymdToday()` — local-date encoding (`year*10000+month*100+day`).
  - `didChangeAppLifecycleState` / `dispose` overrides — registers/removes the lifecycle observer; re-checks rollover on resume.
  (lib/providers/schedule_notifier.dart)

## Changed wiring (behavioral)
- `lib/main.dart`:
  - GoalsNotifier + CommitmentsNotifier constructed before `runApp`; `loadGoals()` / `loadBlocks()` awaited; both registered via `ChangeNotifierProvider.value` (LOOP-01).
  - GoRouter instance captured and passed to `MaterialApp.router`; notification `onTapCallback` navigates via `router.go('/schedule')` / `router.go('/schedule/checkin')` instead of `pushNamed` (LOOP-04).
  - Morning notification auto-scheduled at startup when `morningNotificationEnabled` (LOOP-04).
- `lib/screens/onboarding/onboarding_screen.dart`: `_completeOnboarding` schedules the morning notification after `setOnboardingComplete` when enabled (LOOP-04).
- `lib/services/notification_service.dart`: `scheduleMorningNotification` guards `zonedSchedule` on Linux/web (graceful no-op) (LOOP-04).
- `lib/screens/goals/goal_form_sheet.dart`: `_weeklyHoursController` and `_descriptionController` hoisted into State (initState/dispose); build() no longer constructs `TextEditingController` inline — fixes cursor-jump (LOOP-05).
- `lib/screens/home/home_screen.dart` and `lib/screens/schedule/schedule_screen.dart`: persistent, always-visible re-check-in/regenerate action (`context.push('/schedule/checkin')`) on the populated state (LOOP-03).

## Requirement coverage
| Requirement | Plan | Where |
|-------------|------|-------|
| LOOP-01 | 07-01, 07-02 | startup load in main.dart; regression test |
| LOOP-02 | 07-01 | date-aware ScheduleNotifier + resume hook |
| LOOP-03 | 07-02 | Home + Schedule re-check-in entry points |
| LOOP-04 | 07-01 | notification nav + auto-schedule + Linux guard |
| LOOP-05 | 07-01 | goal-form controller hoist |
