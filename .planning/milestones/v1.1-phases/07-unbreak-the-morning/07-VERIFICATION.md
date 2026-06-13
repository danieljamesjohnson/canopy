---
phase: 07-unbreak-the-morning
verified: 2026-06-10T00:00:00Z
status: human_needed
score: 5/5 must-haves verified (code-level); iOS on-device behaviors require human UAT
overrides_applied: 0
human_verification:
  - test: "Complete fresh install / onboarding with at least one goal. Do not touch the Settings toggle."
    expected: "Morning notification is scheduled automatically after onboarding completes — no manual Settings toggle required."
    why_human: "zonedSchedule is a no-op on Linux; cannot verify the iOS notification fires without a physical device or simulator."
  - test: "Wait for (or set the device clock near) the configured morning notification time."
    expected: "Notification appears on the lock screen or notification center."
    why_human: "Requires iOS device with flutter_local_notifications; not exercisable on this Linux host."
  - test: "Tap the morning notification."
    expected: "App opens to /schedule (or /schedule/checkin if no schedule exists) with no crash."
    why_human: "go_router navigation from an FCN/UNUserNotification tap requires a running iOS process; cannot simulate on Linux."
  - test: "On a day with an existing schedule, look at both the Home screen (Canopy AppBar) and the Schedule screen (Today AppBar)."
    expected: "Both show a visible refresh icon in the AppBar. Tapping it opens CheckinScreen and allows regeneration."
    why_human: "Visual presence of the widget on a real device with data; automated tests confirm the code path exists but not the on-device appearance."
  - test: "Background the app overnight (or change the device date to the next day) and resume."
    expected: "App shows the un-generated 'Start your day' / 'No schedule yet' state — NOT yesterday's schedule."
    why_human: "didChangeAppLifecycleState(resumed) + _resetIfDayChanged requires a real app lifecycle transition; cannot trigger from Linux CI."
  - test: "In the goal form, type into 'Weekly hours target' and the 'Description' fields."
    expected: "Cursor stays at the typed position after each keystroke — no jump to position 0."
    why_human: "TextEditingController cursor positioning requires interactive keyboard input; widget tests confirm the controllers are in State, but tactile UX requires a running app."
---

# Phase 7: Unbreak the Morning — Verification Report

**Phase Goal:** The morning check-in always generates from the user's actual saved goals and commitments — on any cold launch or resume, any day.
**Verified:** 2026-06-10
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | Cold launch produces non-empty schedule from real goals without visiting Goals/Commitments tabs | VERIFIED | `main.dart` lines 55-59: `GoalsNotifier()` + `await goalsNotifier.loadGoals()` and `CommitmentsNotifier()` + `await commitmentsNotifier.loadBlocks()` before `runApp`. Regression test `test/screens/cold_launch_morning_loop_test.dart` passes (no Goals/CommitmentsScreen pumped; asserts `goalId` match). |
| SC-2 | Resuming on a new calendar day shows fresh un-generated state | VERIFIED | `schedule_notifier.dart` lines 32-36: `hasScheduleToday` checks `_todaySchedule!.dateYmd == DateFormat('yyyy-MM-dd').format(_now())`. `_resetIfDayChanged()` called in `init()` (line 49) and `didChangeAppLifecycleState(resumed)` (line 79). |
| SC-3 | Persistent re-check-in entry point on Home and Schedule when schedule exists | VERIFIED | `home_screen.dart` lines 89-95: unconditional `IconButton(Icons.refresh)` → `context.push('/schedule/checkin')` in populated AppBar. `schedule_screen.dart` lines 47-51: same `IconButton` before the gated `>=50%` `PopupMenuButton`. |
| SC-4 | Morning notification fires without settings-toggle; tap navigates via go_router without crash | VERIFIED (code-level); NEEDS HUMAN (runtime) | `main.dart` lines 84-88: auto-schedules at startup if `morningNotificationEnabled`. `onboarding_screen.dart` lines 88-92: schedules after `setOnboardingComplete`. `main.dart` lines 72-79: `router.go('/schedule')` / `router.go('/schedule/checkin')` — no `pushNamed`. `notification_service.dart` lines 87-91: Linux/web early-return guard. iOS runtime behavior cannot be verified on this Linux host. |
| SC-5 | Cursor stays at typed position in goal-name / weekly-hours / description fields | VERIFIED | `goal_form_sheet.dart` lines 24-25, 49-56: `_weeklyHoursController` and `_descriptionController` declared as `late` State fields, initialized in `initState()`, disposed in `dispose()`. No `TextEditingController(` inside `build()`. |

**Score:** 5/5 truths verified at code level. SC-4 iOS runtime behavior requires human UAT.

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/providers/goals_notifier.dart` | Injectable `GoalRepository` constructor seam | VERIFIED | Line 10-11: `GoalsNotifier({GoalRepository? repository}) : _repository = repository ?? HiveGoalRepository();` |
| `lib/providers/commitments_notifier.dart` | Injectable `CommitmentBlockRepository` constructor seam | VERIFIED | Line 10-11: same pattern with `CommitmentBlockRepository`. |
| `lib/providers/schedule_notifier.dart` | `WidgetsBindingObserver` + date-aware `hasScheduleToday` + rollover + dispose | VERIFIED | Line 13: `with WidgetsBindingObserver`; lines 32-36: date-aware `hasScheduleToday`; lines 58-64: `_resetIfDayChanged`; lines 75-82: `didChangeAppLifecycleState`; lines 85-88: `dispose` removes observer. |
| `lib/main.dart` | Startup load before `runApp`; go_router notification nav; auto-schedule | VERIFIED | Lines 55-59: `loadGoals()`/`loadBlocks()` awaited before `runApp`. Lines 72-79: `router.go(...)` in tap callback, no `pushNamed`. Lines 84-88: `scheduleMorningNotification` at startup. |
| `lib/services/notification_service.dart` | Linux/web guard on `zonedSchedule` | VERIFIED | Lines 87-91: `if (kIsWeb) return` and `if (Platform.isLinux || Platform.isWindows) return`. |
| `lib/screens/onboarding/onboarding_screen.dart` | `scheduleMorningNotification` after `setOnboardingComplete` | VERIFIED | Lines 84-92: `setOnboardingComplete(true)` at line 84, then `scheduleMorningNotification` if `morningNotificationEnabled`. |
| `lib/screens/goals/goal_form_sheet.dart` | Controllers in State, not `build()` | VERIFIED | Lines 24-25: `late TextEditingController _weeklyHoursController` / `_descriptionController` in `_GoalFormSheetState`. Lines 49-56: initialized in `initState`. Lines 61-64: disposed in `dispose`. |
| `lib/screens/home/home_screen.dart` | Always-visible re-check-in action → `/schedule/checkin` | VERIFIED | Lines 89-95: `IconButton(Icons.refresh, tooltip: 'Re-check-in', onPressed: () => context.push('/schedule/checkin'))` in the `hasScheduleToday` AppBar `actions`. |
| `lib/screens/schedule/schedule_screen.dart` | Always-visible re-check-in action → `/schedule/checkin` | VERIFIED | Lines 47-51: `IconButton` before the gated `PopupMenuButton`; not gated by any condition. |
| `test/screens/cold_launch_morning_loop_test.dart` | Cold-launch regression test; no GoalsScreen/CommitmentsScreen pumped | VERIFIED | Exists. Seeds goal via `_InMemoryGoalRepository`; pumps `CheckinScreen` only; taps mood-3 + "Let's go"; asserts `chunk.goalId == seededGoal.id`. `GoalsScreen`/`CommitmentsScreen` do not appear in the file. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/main.dart` | `GoalsNotifier.loadGoals / CommitmentsNotifier.loadBlocks` | `await` before `runApp`, same instances in `ChangeNotifierProvider.value` | WIRED | Lines 55-59 await both loads; lines 126-128 pass them via `.value` providers. |
| `lib/main.dart` | `router.go('/schedule')` / `router.go('/schedule/checkin')` | GoRouter captured into `router` local, used in `onTapCallback` | WIRED | Lines 68, 72-79. No `pushNamed` anywhere in the file (only in a comment). |
| `lib/screens/onboarding/onboarding_screen.dart` | `NotificationService.scheduleMorningNotification` | After `setOnboardingComplete`, guarded by `morningNotificationEnabled` | WIRED | Lines 84-92. |
| `test/screens/cold_launch_morning_loop_test.dart` | `ScheduleNotifier.generateToday` via `CheckinScreen` mood tap | In-memory `GoalsNotifier`/`CommitmentsNotifier` seeded via injectable seam | WIRED | `_InMemoryScheduleNotifier.generateToday` calls real `ScheduleGeneratorService.generate()` with goals from provider tree; assertion on `goalId`. |
| `lib/screens/home/home_screen.dart` | `context.push('/schedule/checkin')` | Always-visible when `hasScheduleToday` branch renders | WIRED | Lines 89-95 — no condition gates the `IconButton`. |
| `lib/screens/schedule/schedule_screen.dart` | `context.push('/schedule/checkin')` | Unconditional `IconButton` before gated `PopupMenuButton` | WIRED | Lines 47-51. |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `CheckinScreen` (via test) | `goals` / `blocks` | `GoalsNotifier.goals` / `CommitmentsNotifier.blocks` loaded in `main.dart` before `runApp` | Yes — seeded via `_InMemoryGoalRepository.save` + `loadGoals()` in test; Hive in production | FLOWING |
| `HomeScreen` populated branch | `scheduleNotifier.todaySchedule` | `ScheduleNotifier._todaySchedule` set by `generateToday()` | Yes — chunks include `goalId` derived from real `GoalsNotifier.goals` | FLOWING |
| `ScheduleScreen` populated branch | `scheduleNotifier.todaySchedule` | Same | Yes | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `GoalsNotifier` injectable seam works | Verified via `cold_launch_morning_loop_test.dart` | Test passes (91/91) | PASS |
| `hasScheduleToday` is date-aware (not bare `!= null`) | Code read: `schedule_notifier.dart` lines 32-36 | Compares `_todaySchedule!.dateYmd` to `DateFormat('yyyy-MM-dd').format(_now())` | PASS |
| No `pushNamed` in `main.dart` | `grep -n pushNamed lib/main.dart` | Only appears in comment on line 66 | PASS |
| No `TextEditingController(` in `goal_form_sheet.dart` `build()` | `grep -n "TextEditingController(" goal_form_sheet.dart` | All 4 occurrences are in `initState()` (lines 40, 47, 49, 54) | PASS |
| Full test suite | `flutter test` | 91/91 passed | PASS |
| Static analysis | `flutter analyze` | 0 errors, 5 pre-existing info-level deprecations (unchanged) | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| LOOP-01 | 07-01, 07-02 | Cold-launch generation reads real saved goals/commitments | SATISFIED | Startup load in `main.dart`; injectable seam; regression test passes. |
| LOOP-02 | 07-01 | New-day resume clears stale schedule | SATISFIED | `_resetIfDayChanged` + `didChangeAppLifecycleState` in `schedule_notifier.dart`. |
| LOOP-03 | 07-02 | Persistent re-check-in entry point on Home and Schedule | SATISFIED | `IconButton(Icons.refresh)` in both populated AppBars. |
| LOOP-04 | 07-01 | Notification auto-schedules; tap navigates via go_router; Linux guard | SATISFIED (code); NEEDS HUMAN (iOS runtime) | Auto-schedule in `main.dart` + onboarding; `router.go()`; Linux guard in `notification_service.dart`. iOS firing/tap requires device. |
| LOOP-05 | 07-01 | Goal-form cursor does not jump to position 0 | SATISFIED | Controllers hoisted to State in `goal_form_sheet.dart`. |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | — | — | — | No debt markers, stubs, or hardcoded empty returns in phase-modified files. |

All phase-modified files scanned: `lib/main.dart`, `lib/providers/goals_notifier.dart`, `lib/providers/commitments_notifier.dart`, `lib/providers/schedule_notifier.dart`, `lib/services/notification_service.dart`, `lib/screens/onboarding/onboarding_screen.dart`, `lib/screens/goals/goal_form_sheet.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/schedule/schedule_screen.dart`, `test/screens/cold_launch_morning_loop_test.dart`. No TBD/FIXME/XXX markers, no placeholder returns, no inline controller construction.

---

### Human Verification Required

The following items cannot be verified on this Linux host. They require a physical iOS device or trusted iOS simulator:

#### 1. Morning Notification Auto-Fires After Onboarding

**Test:** Complete a fresh install / onboarding with at least one goal. Do not touch the Settings toggle after onboarding.
**Expected:** The morning notification appears at the configured time without any manual Settings toggle.
**Why human:** `zonedSchedule` is a no-op on Linux (guarded by `Platform.isLinux`). Scheduling + delivery requires an iOS process with `flutter_local_notifications` plugin running.

#### 2. Notification Fires Without Toggling Settings

**Test:** Wait for (or set the device clock near) the configured morning notification time.
**Expected:** Notification banner appears on lock screen or notification center.
**Why human:** Requires iOS device; not exercisable from Linux CI.

#### 3. Notification Tap Navigation (No Crash)

**Test:** Tap the morning notification from the lock screen or notification center.
**Expected:** App opens to `/schedule` (or `/schedule/checkin` if no schedule yet) via go_router with no crash.
**Why human:** `NotificationResponse` callback requires the iOS `UNUserNotification` tap path to be triggered by a real tap; cannot simulate from Linux. The `router.go()` code path is verified in source but the wiring requires runtime.

#### 4. Re-check-in Button Visible and Functional on Device

**Test:** Open the app on a day with an existing schedule. Check both the Home screen and the Schedule screen.
**Expected:** Both show a visible refresh icon in the AppBar header. Tapping either one opens CheckinScreen and allows regeneration.
**Why human:** Visual presence and tappability on a real device with an actual saved schedule.

#### 5. Day Rollover on Resume

**Test:** Background the app overnight (or change device date to the next day) and resume.
**Expected:** App shows the un-generated "Start your day" state — NOT yesterday's schedule.
**Why human:** `didChangeAppLifecycleState(resumed)` + `_resetIfDayChanged` requires a real app lifecycle transition triggered by the iOS process manager; cannot be triggered from Linux.

#### 6. Cursor Stays at Typed Position

**Test:** In the goal form, type into the "Weekly hours target" field and the outcome "Description" field.
**Expected:** After each keystroke the cursor stays at the insertion point — no jump to position 0.
**Why human:** TextEditingController cursor behavior requires interactive keyboard input in a running app. The code correctly hoists controllers to State (verified), but tactile UX requires a running iOS or Android app.

---

### Gaps Summary

No code-level gaps. All five ROADMAP success criteria have verified implementations in the codebase. The only open item is the iOS on-device UAT for SC-4 (notification firing/tap) and the interactive behaviors of SC-2 (rollover on resume), SC-3 (visual button presence), SC-4 (tap navigation), and SC-5 (cursor feel) — all of which require a running device and are documented in the human verification section above.

---

_Verified: 2026-06-10_
_Verifier: Claude (gsd-verifier)_
