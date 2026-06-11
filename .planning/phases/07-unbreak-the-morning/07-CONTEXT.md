# Phase 7: Unbreak the Morning - Context

**Gathered:** 2026-06-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 7 makes the daily loop unable to dead-end. It is loop plumbing, not new features: the morning check-in must always generate a schedule from the user's *actual* saved goals and commitments on any cold launch or resume, the schedule must roll over correctly at the day boundary, the user must always have a way back into check-in/regeneration, morning notifications must fire and navigate correctly, and goal entry must work without the cursor bug. Delivers requirements LOOP-01 through LOOP-05. The scheduling *algorithm* itself is out of scope (that is Phase 9) — Phase 7 only guarantees the engine receives real data and the loop is reachable.

</domain>

<decisions>
## Implementation Decisions

### Loop plumbing (data loading + rollover)
- Fix B1 by constructing `GoalsNotifier` and `CommitmentsNotifier` and `await`-ing their load before `runApp` (mirroring how `ScheduleNotifier` is already initialized), so `checkin_screen._generate()` never reads empty in-memory lists. Generation must never see unloaded data regardless of which tabs were visited.
- Day rollover: add a `WidgetsBindingObserver` resume hook + date-aware `hasScheduleToday` in `ScheduleNotifier`, mirroring the working `ThemeNotifier._resetIfDayChanged()` pattern. The midnight seam is the same local-date boundary ThemeNotifier uses.
- **New-day behavior: fresh check-in.** On a new calendar day the app shows the un-generated "Start your day" state and the user re-taps mood to regenerate. Mood is core to the model, so the daily mood signal is preserved (not auto-regenerated with stale mood).

### Re-check-in / regenerate entry point
- **Prominent, always-visible button.** When a schedule already exists, both Home and the Schedule screen show a clear "Re-check-in / Regenerate" action (not hidden in an overflow menu). `generateToday()` already supports silent replace; this phase only adds the reachable entry points.

### Notifications (iOS is the daily driver)
- Fix B4 navigation: the notification tap handler must use the go_router instance (`router.go('/schedule')` via the root navigator/router), NOT `Navigator.pushNamed` — named routes don't exist under go_router and currently crash.
- Schedule the morning notification automatically when enabled — on app start and after onboarding completes — so it fires without the user toggling the Settings switch off/on. Reschedule idempotently.
- **Notification time: keep the existing default** (user can change in Settings). No new time-config UI in this phase.
- Guard `zonedSchedule` on platforms where the plugin doesn't support it (Linux desktop / web) so it degrades gracefully; iOS/Android are the real targets.

### Goal form cursor bug (LOOP-05)
- Hoist `TextEditingController`s into the `State` object (created in `initState`, disposed in `dispose`) instead of constructing them inside `build()`, which is what causes the cursor to jump to position 0 while typing into goal name / weekly-hours fields.

### Verification
- Automated gates: `flutter analyze` (clean) and `flutter test` (all pass), using the installed Flutter 3.44.1.
- Add a regression test that reproduces the cold-launch path (Home → check-in → mood, without visiting Goals/Commitments tabs) and asserts the generated schedule contains the user's real goals — locking B1 closed.
- On-device iOS morning-notification firing + tap navigation is a **manual UAT item** (cannot run an iOS simulator on this Linux box).

### Claude's Discretion
- Exact widget placement/label of the re-check-in button, the precise observer wiring, and test structure are at implementation discretion, guided by existing codebase conventions.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets / Patterns to mirror
- `lib/providers/theme_notifier.dart` — already implements lifecycle-aware day rollover (`_resetIfDayChanged` on resume). Copy this pattern into `ScheduleNotifier`.
- `lib/providers/schedule_notifier.dart` — already constructed before `runApp` with `await init()`; `GoalsNotifier`/`CommitmentsNotifier` should follow the same pattern.
- `lib/services/notification_service.dart` — `scheduleMorningNotification()` exists; currently only called from Settings handlers.
- `lib/providers/goals_notifier.dart:40` `loadGoals()` / `commitments_notifier.dart:14` `loadBlocks()` — the load methods exist; they're just never called at startup.

### Integration Points
- `lib/main.dart:~89-91` — provider construction site (where startup loads must be awaited).
- `lib/screens/schedule/checkin_screen.dart:55-59` — reads `GoalsNotifier.goals` / `CommitmentsNotifier.blocks` directly (the B1 consumer).
- `lib/main.dart:60-62` — notification tap handler using `pushNamed` (the B4 crash site).
- `lib/screens/home/home_screen.dart` + `lib/screens/schedule/schedule_screen.dart` — where the re-check-in entry point button goes.
- `lib/screens/goals/goal_form_sheet.dart` — controller-in-build cursor bug (LOOP-05).
- `lib/router.dart` — go_router instance for the notification-tap navigation fix.

</code_context>

<specifics>
## Specific Ideas

- Phase 7 starts with a runtime verification pass confirming the proposal's static findings. B1 is already confirmed in source (GoalsNotifier/CommitmentsNotifier never loaded before generation on cold launch); analyze is clean and all 90 existing tests pass.
- Carry-through constraints: rule-based only (no LLM), local Hive storage, additive-only Hive migrations, iOS primary daily driver.

</specifics>

<deferred>
## Deferred Ideas

- The actual scheduling algorithm improvements (capacity fill, weekly budgets, frequency, priority) — Phase 9.
- Goal-name display on chunk cards and coherent ordering — Phase 8.
- Companion focus-session mode — Phase 8.

</deferred>
