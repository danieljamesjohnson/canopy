---
phase: 07-unbreak-the-morning
reviewed: 2026-06-10T00:00:00Z
depth: deep
files_reviewed: 10
files_reviewed_list:
  - lib/main.dart
  - lib/providers/goals_notifier.dart
  - lib/providers/commitments_notifier.dart
  - lib/providers/schedule_notifier.dart
  - lib/services/notification_service.dart
  - lib/screens/onboarding/onboarding_screen.dart
  - lib/screens/goals/goal_form_sheet.dart
  - lib/screens/home/home_screen.dart
  - lib/screens/schedule/schedule_screen.dart
  - test/screens/cold_launch_morning_loop_test.dart
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 7: Code Review Report

**Reviewed:** 2026-06-10
**Depth:** deep
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 7 fixes the cold-launch morning loop (LOOP-01 through LOOP-05): startup
eager-loading, stale-schedule day rollover, go_router notification navigation,
and TextEditingController cursor-reset. The core mechanics are sound — provider
ordering is correct, no double-construction, `ChangeNotifierProvider.value` used
throughout, `WidgetsBindingObserver` lifecycle added/removed symmetrically in the
production path.

Three warnings are present; none are show-stoppers for shipping, but two are
latent crash paths on real user devices.

---

## Warnings

### WR-01: `scheduleMidDayNudge` Missing Linux/Windows Platform Guard

**File:** `lib/services/notification_service.dart:132`

**Issue:** `scheduleMorningNotification` received a `Platform.isLinux || Platform.isWindows` guard (line 91) because `zonedSchedule` is unsupported on those platforms. The sibling method `scheduleMidDayNudge` (line 132) uses the same `zonedSchedule` API but has **no such guard** — only the `kIsWeb` early return. A user on Linux or Windows desktop who enables the mid-day nudge from the Settings screen will hit an unhandled runtime exception (the plugin throws `UnimplementedError` on those platforms for `zonedSchedule`).

The mid-day nudge toggle is live in `settings_screen.dart:139`, so this is reachable in production.

**Fix:**
```dart
static Future<void> scheduleMidDayNudge(int minutesFromMidnight) async {
  if (kIsWeb) return;
  if (Platform.isLinux || Platform.isWindows) return; // add this line
  await _plugin.cancel(id: 1);
  // ... rest unchanged
}
```

---

### WR-02: Notification Tap Fires Before Router is Ready (Race on Cold Launch via Notification)

**File:** `lib/main.dart:72-79`

**Issue:** `NotificationService.onTapCallback` is wired *before* `runApp()`. The
`GoRouter` instance (`router`) is captured in the closure correctly, but
`router.go()` will throw `GoException` ("Cannot navigate before a GoRouter is
created") if the notification tap fires in the brief window between
`onTapCallback` being assigned and `MaterialApp.router(routerConfig: router)`
completing its first build. This window is tiny in normal use, but on slow
devices (or when the OS delivers a pending tapped notification immediately on
launch) it is reachable.

The old code guarded against this via the `rootNavigatorKey.currentContext ==
null` null-check (now removed). The new code has no analogous guard.

**Fix:** Wrap `router.go()` calls in a post-frame callback or add a readiness
check. The simplest safe approach:
```dart
NotificationService.onTapCallback = (NotificationResponse response) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (scheduleNotifier.hasScheduleToday) {
      router.go('/schedule');
    } else {
      router.go('/schedule/checkin');
    }
  });
};
```
This defers navigation until after the first frame, by which point the router is
guaranteed to have rendered at least once.

---

### WR-03: `_InMemoryScheduleNotifier` Overrides `hasScheduleToday` — Weakens LOOP-02 Regression Lock

**File:** `test/screens/cold_launch_morning_loop_test.dart:128`

**Issue:** The test subclass overrides `hasScheduleToday` to return
`_inMemorySchedule != null` (bypassing the date-string comparison introduced for
LOOP-02). This is intentional for the LOOP-01 test, but it means the test cannot
detect a regression in the day-rollover logic. More importantly, it slightly
misrepresents what the production notifier does: production's `hasScheduleToday`
also validates the date string, which `_inMemorySchedule != null` does not.

This does not break the LOOP-01 regression lock (the test correctly locks
startup data loading), but a future developer adding a LOOP-02 regression test
might re-use this class and unknowingly skip the date check. The current
comment (line 776) explains the workaround but does not flag the override's
effect on LOOP-02 coverage.

**Fix:** Add an explicit comment directly on the `hasScheduleToday` override
noting that it intentionally skips the date check, and that any LOOP-02 test
must use the real `ScheduleNotifier` (not this subclass):
```dart
/// Intentionally skips the LOOP-02 date-string comparison so that
/// LOOP-01 can assert on the generated schedule regardless of the
/// test's wall-clock date. Do NOT reuse this class for LOOP-02 tests.
@override
bool get hasScheduleToday => _inMemorySchedule != null;
```

---

## Info

### IN-01: `ymdToday()` is a Dead Public Method

**File:** `lib/providers/schedule_notifier.dart:69`

**Issue:** `ymdToday()` is marked `public` but is described in its own comment as
"not currently used outside this class." It duplicates `ThemeNotifier._ymdToday()` 
(which is private) and returns a `yyyymmdd` int that nothing in the codebase
consumes. Making it public grows the API surface unnecessarily.

**Fix:** Either make it private (`_ymdToday()`) or remove it. If it's kept for
testability, prefix it with `@visibleForTesting`.

---

### IN-02: `_FakeScheduleNotifier` in `router_redirect_test.dart` No Longer Covers `init()` Observer Registration

**File:** `test/screens/router_redirect_test.dart:57`

**Issue:** `_FakeScheduleNotifier.init()` is a complete no-op — it does not call
`WidgetsBinding.instance.addObserver(this)`. The parent `dispose()` (called by
Provider at teardown) still calls `removeObserver(this)`. Flutter's
`removeObserver` silently ignores unregistered observers, so the tests pass and
do not crash. However, the asymmetry is a latent confusion: if the test ever
calls `dispose()` on a notifier that was never initialized, the asymmetry is
invisible but wrong. The test predates Phase 7; it is not a new bug, but the
Phase 7 change that added `addObserver` to `init()` now makes the asymmetry
observable.

**Fix:** For correctness, override `dispose()` in `_FakeScheduleNotifier` (or
alternatively, have the no-op `init()` still call `addObserver`):
```dart
class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {} // intentionally skips Hive + addObserver

  @override
  void dispose() {
    // skip removeObserver — init() never registered us
    ChangeNotifier.dispose(this); // or just: super.dispose() won't crash either
  }
}
```
(In practice, `super.dispose()` is safe here because `removeObserver` is a
no-op for unregistered observers, so this is low priority.)

---

_Reviewed: 2026-06-10_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
