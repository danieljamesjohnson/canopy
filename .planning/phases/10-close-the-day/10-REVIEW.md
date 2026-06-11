---
phase: 10-close-the-day
reviewed: 2026-06-11T00:00:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - lib/data/database/migrations.dart
  - lib/data/models/app_settings.dart
  - lib/data/models/scheduled_chunk.dart
  - lib/main.dart
  - lib/providers/schedule_notifier.dart
  - lib/providers/settings_notifier.dart
  - lib/screens/home/home_screen.dart
  - lib/screens/home/widgets/end_of_day_card.dart
  - lib/screens/settings/settings_screen.dart
  - lib/services/notification_service.dart
  - lib/services/schedule_generator.dart
  - test/commitment_attribution_test.dart
  - test/defer_carryover_test.dart
  - test/end_of_day_card_test.dart
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-06-11T00:00:00Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

Phase 10 adds a `commitmentId` Hive field + schema migration 4→5, commitment-time attribution in completion logs, defer-to-tomorrow carryover (single-hop), a non-breaking-streak change to `computeStreak`, an `EndOfDayCard` home widget with a 6pm/50% trigger, and an opt-in evening reminder notification (id 2).

The Hive migration is structurally sound. The `commitmentId ?? goalId ?? ''` attribution chain is correct. The single-hop carry-in logic is correct. The `computeStreak` deferred-day walk is correct. The notification scheduling guards (web/desktop) are correct.

Four real defects were found: one critical (hardcoded `1200` constant bypasses the user's persisted evening reminder time), one correctness warning (missing `setEveningReminderMinutes` method means the persisted value can never be changed, locking the setting), one correctness warning (`_eodCardDismissed` survives a re-check-in within the same widget lifetime), and one test correctness warning (a test body is empty — it asserts nothing). Two info items round out the report.

---

## Critical Issues

### CR-01: Settings screen hardcodes `1200` instead of reading `eveningReminderMinutes`

**File:** `lib/screens/settings/settings_screen.dart:172,182`

**Issue:** The evening reminder `ListTile` subtitle always displays `_formatMinutes(1200)` instead of `_formatMinutes(settings.eveningReminderMinutes)`, and the `onChanged` handler calls `NotificationService.scheduleEveningReminder(1200)` instead of `NotificationService.scheduleEveningReminder(settings.eveningReminderMinutes)`. The result is that if `eveningReminderMinutes` is ever changed to a value other than 1200 in a future phase, (a) the subtitle always shows "8:00 PM" regardless of the stored value, and (b) re-toggling the switch reschedules the notification at the wrong time — overwriting a user's customized time with 8:00 PM. Even in the current phase where the time is intentionally fixed at 1200, the subtitle and the schedule call should read from `settings.eveningReminderMinutes` (which is also 1200) so the code correctly expresses intent. Right now the code is subtly wrong: it renders the subtitle from a different source than the persisted state.

**Fix:**
```dart
// Line 172: replace hardcoded literal with the notifier's value
subtitle: Text(
  eveningEnabled
      ? _formatMinutes(settings.eveningReminderMinutes)   // was: _formatMinutes(1200)
      : 'Opt-in reminder to close your day',
),

// Line 182: replace hardcoded literal in onChanged handler
if (val) {
  await NotificationService.scheduleEveningReminder(
    settings.eveningReminderMinutes,                      // was: 1200
  );
}
```

---

## Warnings

### WR-01: `SettingsNotifier` has no `setEveningReminderMinutes` method

**File:** `lib/providers/settings_notifier.dart:85-92`

**Issue:** `setEveningReminderEnabled` is implemented (line 85) but there is no corresponding `setEveningReminderMinutes` method. `_eveningReminderMinutes` is read from Hive on `init()` and exposed via a getter, but can never be written back. If a time-picker is added to the evening reminder row in a later phase (matching the pattern of `setMorningNotificationMinutes` / `setMidDayNudgeMinutes`), there will be no setter to call. The asymmetry is also a latent risk: any caller that tries to reschedule the evening reminder after a time-picker interaction will silently use the cached getter value (1200) rather than the new value, because the setter doesn't exist to update `_eveningReminderMinutes`.

**Fix:** Add a setter mirroring the morning and mid-day patterns:
```dart
Future<void> setEveningReminderMinutes(int value) async {
  _eveningReminderMinutes = value;
  final settings = await _repository.getSettings() ?? AppSettings();
  settings.eveningReminderMinutes = value;
  await _repository.saveSettings(settings);
  notifyListeners();
}
```

### WR-02: `_eodCardDismissed` is not reset when the user re-checks-in (re-generates the schedule)

**File:** `lib/screens/home/home_screen.dart:45,113`

**Issue:** `_eodCardDismissed` is declared as widget state and set to `true` when the user taps "✕" on `EndOfDayCard`. It is never reset to `false`. If the user taps the "Re-check-in" app bar action (line 97) — which navigates away and then back — the `_HomeScreenState` is rebuilt but `_eodCardDismissed` may stay `true` (depending on whether Flutter disposes and recreates the state). More critically, when `ScheduleNotifier.generateToday` completes and calls `notifyListeners()`, `build()` is re-entered with a new schedule object but the same `_eodCardDismissed = true`, so the card is permanently hidden for that day's session even if the trigger condition is re-met on the new schedule. This means a user who dismisses the card and then re-checks-in will never see the card again until the app is cold-restarted.

**Fix:** Reset `_eodCardDismissed` whenever the schedule changes. The cleanest approach is to listen for schedule changes in `didChangeDependencies` or `didUpdateWidget` and reset:
```dart
String? _lastScheduleDateYmd;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final notifier = context.read<ScheduleNotifier>();
  final newDateYmd = notifier.todaySchedule?.dateYmd;
  if (newDateYmd != _lastScheduleDateYmd) {
    _lastScheduleDateYmd = newDateYmd;
    _eodCardDismissed = false; // new schedule → show card again
  }
}
```

### WR-03: `defer_carryover_test.dart` — the `'completed-deferred chunk is NOT carried'` test asserts nothing

**File:** `test/defer_carryover_test.dart:526-560`

**Issue:** The test body at line 526 sets up the scenario, calls `generateToday`, and reads back `todaySchedule`, but then only calls `expect(todaySchedule, isNotNull)`. The comments at lines 555-559 acknowledge this ("We can't assert zero chunks… actually for this test, pass an ARCHIVED goal…") but leave the test with no meaningful assertion. The test PASSES regardless of whether the carry-in filter is broken. The behavior it was meant to cover (completed+deferred chunk should not be carried) is only tested in the *next* test ("completed-deferred chunk of archived goal is NOT carried"), but this test remains live in CI and provides false confidence.

**Fix:** Either (a) delete the test (its scenario is fully covered by the archived-goal test below it) or (b) rewrite it to use an archived goal and add the missing assertion:
```dart
// Replace goal with archived variant so normal generation won't schedule it:
final goal = Goal(
  id: goalId,
  name: 'Done goal',
  goalTypeIndex: GoalType.outcome.index,
)..isArchived = true;

// Add assertion at the end:
final carriedChunks = todaySchedule!.chunks
    .where((c) => c.chunkType == ChunkType.work && c.goalId == goalId)
    .toList();
expect(carriedChunks, isEmpty,
    reason: 'Completed-deferred chunk must NOT be carried over');
```

### WR-04: `shouldShowEodCard` calls `DateTime.now()` directly — untestable and potentially wrong across midnight

**File:** `lib/screens/home/widgets/end_of_day_card.dart:101`

**Issue:** `shouldShowEodCard` calls `DateTime.now().hour` directly to implement the `hour >= 18` branch. This has two problems: (1) all tests in `end_of_day_card_test.dart` that touch the hour branch work around the fact that the clock cannot be controlled (the comments at lines 125-136 and 181-191 explicitly note this) — those test paths are only partially exercised. (2) When the app is running across a midnight boundary (unlikely for a 6pm trigger, but not impossible), `DateTime.now()` gives the real system clock rather than the schedule's calendar day. The pattern elsewhere in the codebase (e.g., `ScheduleNotifier._now`) is to inject a `DateTime Function()` clock; `shouldShowEodCard` should do the same.

**Fix:**
```dart
// Add an optional clock parameter for testability:
bool shouldShowEodCard(
  List<ScheduledChunk> chunks, {
  DateTime Function() now = DateTime.now,
}) {
  final hour = now().hour;
  // ... rest unchanged
}
```
The `_HomeScreenState._shouldShowEodCard` wrapper can pass `_now` if injected, or continue to use `DateTime.now` in production since the wrapper only exists for delegation.

---

## Info

### IN-01: `migrations.dart` migration comments reference phase numbers, not Hive model names

**File:** `lib/data/database/migrations.dart:45-52`

**Issue:** The `_migration4to5` comment mentions "HiveField 8" for `eveningReminderMinutes` in `AppSettings`, which is correct. However it also mentions "HiveField 7, bool" for `eveningReminderEnabled` and "HiveField 8, int" for `eveningReminderMinutes`. These match the current `AppSettings` field indices. No bug — this is informational: a future reader adding "HiveField 8" to a different model should note that field indices are per-typeId (Hive CE), so the same index number across different `@HiveType(typeId:)` classes is safe.

### IN-02: `scheduleEveningReminder` produces a `matchDateTimeComponents: DateTimeComponents.time` daily repeat but has no macOS notification details

**File:** `lib/services/notification_service.dart:213-230`

**Issue:** `scheduleEveningReminder` and `scheduleMorningNotification` both omit macOS (`macOS: DarwinNotificationDetails()`) from their `NotificationDetails`. The `scheduleMorningNotification` call at line 113-126 only specifies `android` and `iOS`; the evening reminder at line 218-226 does the same. On macOS, the flutter_local_notifications plugin falls back gracefully, but the absence of explicit `macOS:` details means the notification uses default macOS settings rather than any app-specified channel configuration. This is low-risk (macOS is not a primary target), but inconsistent with the `initialize()` setup which explicitly includes a `DarwinInitializationSettings` for both iOS and macOS.

---

_Reviewed: 2026-06-11T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
