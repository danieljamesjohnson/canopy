---
phase: 10-close-the-day
plan: "03"
subsystem: ui
tags: [flutter, notifications, local_notifications, home_screen, settings, provider, end_of_day]

# Dependency graph
requires:
  - phase: 10-close-the-day
    plan: "01"
    provides: AppSettings.eveningReminderEnabled (HiveField 7) + eveningReminderMinutes (HiveField 8) — Hive schema ready for settings persistence
provides:
  - NotificationService.scheduleEveningReminder(int minutesFromMidnight) — id 2, kIsWeb + Linux/Windows guards (T-10-05 mitigated)
  - NotificationService.cancelEveningReminder() — id 2
  - SettingsNotifier.eveningReminderEnabled getter, eveningReminderMinutes getter, setEveningReminderEnabled(bool) setter, init() hydration
  - EndOfDayCard widget (lib/screens/home/widgets/end_of_day_card.dart) — Dismissible primaryContainer card, 'How did today go?' title, '$resolved of $total chunks done' subtitle, 'Close the day' CTA
  - shouldShowEodCard(List<ScheduledChunk>) top-level function — hour>=18 OR resolved/total>=0.5 trigger
  - HomeScreen _eodCardDismissed state + _shouldShowEodCard helper + EndOfDayCard insertion in active-schedule branch
  - Settings Evening reminder ListTile (nights_stay_outlined, fixed 8pm, default OFF, onTap null)
  - main.dart idempotent evening reminder scheduling on app start when enabled
  - 10 widget+trigger tests in test/end_of_day_card_test.dart
affects: [11-review-aggregation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Top-level testable trigger function pattern — shouldShowEodCard extracted to top level in end_of_day_card.dart so HomeScreen._shouldShowEodCard delegates to it; widget tests exercise the trigger logic without a full HomeScreen pump
    - ReviewBanner structural copy pattern — EndOfDayCard mirrors review_banner.dart exactly (Dismissible + primaryContainer Card + Row + Column + IconButton + ElevatedButton), then substitutes content per UI-SPEC

key-files:
  created:
    - lib/screens/home/widgets/end_of_day_card.dart
    - test/end_of_day_card_test.dart
  modified:
    - lib/services/notification_service.dart
    - lib/providers/settings_notifier.dart
    - lib/screens/settings/settings_screen.dart
    - lib/screens/home/home_screen.dart
    - lib/main.dart

key-decisions:
  - "shouldShowEodCard extracted as a top-level function (not a private method on _HomeScreenState) so widget tests can exercise trigger logic without pumping the full HomeScreen provider tree"
  - "onTap: null on the evening reminder ListTile — no time picker this phase per CONTEXT.md; fixed 8pm (1200 minutes) is the only supported time"
  - "EndOfDayCard NOT shown in _buildEmptyState — insertion is inside the active-schedule branch only (scheduleNotifier.hasScheduleToday == true path)"

patterns-established:
  - "Top-level trigger function pattern: extract screen-side trigger logic to a testable top-level function in the widget file; delegate from state helper to that function"

requirements-completed: [CLOSE-01]

# Metrics
duration: 10min
completed: 2026-06-11
---

# Phase 10 Plan 03: End-of-Day Card + Evening Reminder Summary

**Dismissible 'How did today go?' Home card triggering at 6pm or ≥50% chunks resolved routes to /summary; opt-in Evening reminder ListTile schedules/cancels notification id 2 with desktop/web guard; idempotent app-start (re)scheduling wired (CLOSE-01)**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-06-11T20:50:00Z
- **Completed:** 2026-06-11T20:59:57Z
- **Tasks:** 2
- **Files modified:** 5 modified, 2 created

## Accomplishments
- Added `scheduleEveningReminder`/`cancelEveningReminder` on notification id 2 in `NotificationService`, mirroring `scheduleMidDayNudge` exactly with all required guards (kIsWeb, Platform.isLinux||isWindows) per T-10-05 mitigation
- Added evening-reminder fields, getters, init() hydration, and `setEveningReminderEnabled` setter in `SettingsNotifier` hydrating from the HiveFields 7-8 delivered in Plan 01
- Added Evening reminder `ListTile` in `SettingsScreen` (nights_stay_outlined icon, fixed 8pm subtitle when enabled, Switch wired to schedule/cancel, `onTap: null`)
- Wired idempotent evening reminder scheduling on app start in `main.dart` when `eveningReminderEnabled` is true
- Created `EndOfDayCard` widget (exact structural copy of `ReviewBanner`) with `'How did today go?'` title, computed `'$resolved of $total chunks done'` subtitle, `'Close the day'` ElevatedButton, and dismiss IconButton with `tooltip: 'Dismiss'`
- Inserted `EndOfDayCard` in HomeScreen's active-schedule branch only (never on empty/pre-checkin state); trigger delegates to top-level `shouldShowEodCard` function; in-memory `_eodCardDismissed` state
- Extracted `shouldShowEodCard` as a top-level function for testability; 10 widget + trigger unit tests all green; full suite 151 tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Evening notification methods + SettingsNotifier plumbing + Settings toggle + app-start scheduling** - `0d2c849` (feat)
2. **Task 2: EndOfDayCard widget + Home insertion with 6pm/50% trigger + widget test** - `d3bb2f2` (feat)

## Files Created/Modified
- `lib/services/notification_service.dart` — Added `scheduleEveningReminder` and `cancelEveningReminder` on id 2 with kIsWeb + Linux/Windows guards
- `lib/providers/settings_notifier.dart` — Added `_eveningReminderEnabled`/`_eveningReminderMinutes` fields, getters, init() hydration, and `setEveningReminderEnabled` setter
- `lib/screens/settings/settings_screen.dart` — Added `eveningEnabled` local, Evening reminder `ListTile` after mid-day row
- `lib/main.dart` — Idempotent evening reminder scheduling on app start when enabled
- `lib/screens/home/widgets/end_of_day_card.dart` — New: `EndOfDayCard` widget + `shouldShowEodCard` top-level trigger function
- `lib/screens/home/home_screen.dart` — Added `_eodCardDismissed` state, `_shouldShowEodCard` helper, EndOfDayCard import and conditional insertion
- `test/end_of_day_card_test.dart` — New: 10 tests (4 widget + 6 trigger logic unit tests)

## Decisions Made
- `shouldShowEodCard` extracted to top level in `end_of_day_card.dart` (not private on `_HomeScreenState`) so widget tests can call it directly without pumping a full HomeScreen with its provider tree
- `onTap: null` on the Evening reminder ListTile — fixed 8pm per CONTEXT.md decision; no time-picker UI this phase
- EndOfDayCard insertion is strictly inside the active-schedule branch (the `build()` path after `scheduleNotifier.hasScheduleToday` is true); the empty-state `_buildEmptyState` branch remains unchanged

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `flutter analyze` reports 5 pre-existing `onReorder` deprecation warnings in `goals_screen.dart`, `adjustments_section.dart`, and test files — same warnings documented in Plan 01 Summary as out-of-scope. Zero new issues introduced by this plan.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. The EndOfDayCard subtitle is computed from real `ScheduledChunk` data at render time. The Settings toggle reads from and writes to the real `SettingsNotifier`/`AppSettings` Hive store. No hardcoded empty values or placeholder text.

## Threat Flags

No new threat surface beyond the plan's threat model (T-10-05, T-10-06). The only new notification path is local id 2 (non-PII static copy, no network). No new endpoints, auth paths, or trust boundary changes.

## Next Phase Readiness
- CLOSE-01 is fully delivered: end-of-day card discoverability layer live, opt-in evening reminder with desktop/web guard, idempotent app-start scheduling
- Phase 10 Wave 2 is now complete (Plans 02 and 03 done; Plan 01 was Wave 1)
- Phase 11 (REVIEW-01) quarterly chart aggregation can build on the correct commitment logs from Plan 01

## Self-Check: PASSED

- All 7 source/test files confirmed on disk
- SUMMARY.md confirmed on disk
- Commit 0d2c849 (Task 1) confirmed in git log
- Commit d3bb2f2 (Task 2) confirmed in git log

---
*Phase: 10-close-the-day*
*Completed: 2026-06-11*
