---
phase: 10-close-the-day
fixed_at: 2026-06-11T00:00:00Z
review_path: .planning/phases/10-close-the-day/10-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 10: Code Review Fix Report

**Fixed at:** 2026-06-11T00:00:00Z
**Source review:** .planning/phases/10-close-the-day/10-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (CR-01, WR-01, WR-02, WR-03, WR-04)
- Fixed: 5
- Skipped: 0

## Fixed Issues

### CR-01 + WR-01: Settings screen hardcodes 1200 / missing setEveningReminderMinutes

**Files modified:** `lib/screens/settings/settings_screen.dart`, `lib/providers/settings_notifier.dart`
**Commit:** f0d247f
**Applied fix:**
- Added `setEveningReminderMinutes(int value)` to `SettingsNotifier` matching the morning/mid-day setter pattern (reads current settings from Hive, updates the field, saves, notifies).
- Added `final eveningMinutes = settings.eveningReminderMinutes;` local variable in `_SettingsScreenState.build`.
- Replaced `_formatMinutes(1200)` in the subtitle with `_formatMinutes(eveningMinutes)`.
- Replaced `NotificationService.scheduleEveningReminder(1200)` in the `onChanged` handler with `NotificationService.scheduleEveningReminder(eveningMinutes)`.

### WR-02: `_eodCardDismissed` not reset on re-check-in

**Files modified:** `lib/screens/home/home_screen.dart`
**Commit:** 3a02b24
**Applied fix:**
Added `String? _lastScheduleDateYmd` field and a `didChangeDependencies` override that reads `notifier.todaySchedule?.dateYmd`. When the dateYmd changes (new schedule generated), `_eodCardDismissed` is reset to `false` so the card can reappear if the trigger condition is met on the new schedule.

### WR-03: Empty-assertion stub test in defer_carryover_test.dart

**Files modified:** `test/defer_carryover_test.dart`
**Commit:** aa080e5
**Applied fix:**
Deleted the 35-line `'completed-deferred chunk is NOT carried into next schedule'` test body that asserted only `isNotNull`. The scenario is fully covered by the immediately following `'completed-deferred chunk of archived goal is NOT carried'` test, which uses an archived goal so only carry-in could produce the chunk, and includes the proper `isEmpty` assertion with a reason string.

### WR-04: `shouldShowEodCard` calls `DateTime.now()` directly — untestable

**Files modified:** `lib/screens/home/widgets/end_of_day_card.dart`
**Commit:** 4e45fb8
**Applied fix:**
Added optional named parameter `DateTime Function() now = DateTime.now` to `shouldShowEodCard`. Changed the internal `DateTime.now().hour` call to `now().hour`. All existing call sites (home_screen.dart and tests) pass no argument and continue to work with the default. Tests can now pass a fixed clock to exercise the `hour >= 18` branch deterministically.

---

_Fixed: 2026-06-11T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
