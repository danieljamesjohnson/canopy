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
  critical: 0
  warning: 0
  info: 1
  total: 1
status: clean
---

# Phase 10: Code Review Report (Iteration 2)

**Reviewed:** 2026-06-11T00:00:00Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** clean

## Summary

All five prior findings from Iteration 1 are confirmed resolved. No new Critical or Warning issues were introduced by the fixes.

**Prior findings disposition:**

1. **BL-01 (blocker) — `setEveningReminderMinutes` setter missing:** Present in `settings_notifier.dart` lines 93-99. Mirrors the morning/mid-day setter pattern: updates the private field, reads-or-creates the Hive record, persists the new value, calls `notifyListeners()`. Correct.

2. **WR-01 — `settings_screen` not reading `eveningReminderMinutes`:** Lines 63-64 of `settings_screen.dart` now capture `eveningEnabled` and `eveningMinutes` from the notifier. Line 173 passes `eveningMinutes` to `_formatMinutes` for the subtitle, and line 184 passes it to `NotificationService.scheduleEveningReminder`. Both values track the persisted state. Correct.

3. **WR-02 — `_eodCardDismissed` not resetting on schedule-date change:** `didChangeDependencies` in `home_screen.dart` (lines 56-64) tracks `_lastScheduleDateYmd` and sets `_eodCardDismissed = false` when `todaySchedule?.dateYmd` changes. Mutation in `didChangeDependencies` without an explicit `setState` call is correct Flutter practice — the framework schedules a rebuild automatically after this lifecycle method. The fix is sound.

4. **WR-03 — `shouldShowEodCard` not injectable for testing:** The function now accepts `DateTime Function() now = DateTime.now` (lines 101-103 of `end_of_day_card.dart`). Production call-site in `home_screen.dart` passes no `now` argument (correctly uses wall clock). Tests exercise the ratio branch (time-independent when ratio >= 0.5) and avoid asserting on the time-dependent path without clock control. Correct.

5. **WR-04 — No-assertion stub test:** Confirmed absent from all three test files. The `defer_carryover_test.dart` test at line 526 ("completed-deferred chunk of archived goal is NOT carried") now includes both the archived-goal setup and the `isEmpty` assertion at lines 560-567. All tests contain meaningful assertions.

## Info

### IN-01: One test validates ratio math without calling `shouldShowEodCard`

**File:** `test/end_of_day_card_test.dart:141-155`
**Issue:** The test named `'returns false when <50% resolved and hour < 18 (time-independent branch)'` manually computes `resolved / total` and asserts `lessThan(0.5)`, but never calls `shouldShowEodCard(chunks, ...)`. The assertion confirms the ratio arithmetic is correct but exercises no code path in the function itself. Since `shouldShowEodCard` now accepts an injectable `now` clock, the function can be called directly with a morning-hour stub to verify the false-return case without relying on wall-clock time.
**Fix:** Replace the math-only body with a direct function call using the injectable clock:
```dart
test('returns false when <50% resolved and hour < 18 (time-independent branch)', () {
  final chunks = [
    _makeWork(completed: true),
    _makeWork(),
    _makeWork(),
  ];
  // Inject a morning hour so the hour-branch does not interfere.
  expect(
    shouldShowEodCard(chunks, now: () => DateTime(2026, 1, 1, 9)),
    isFalse,
    reason: '1 of 3 resolved (33%) is below the 50% threshold at 9am',
  );
});
```

---

_Reviewed: 2026-06-11T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
