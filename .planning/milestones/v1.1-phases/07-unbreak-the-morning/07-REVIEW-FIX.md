---
phase: 07-unbreak-the-morning
fixed_at: 2026-06-10T00:00:00Z
review_path: .planning/phases/07-unbreak-the-morning/07-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 7: Code Review Fix Report

**Fixed at:** 2026-06-10
**Source review:** `.planning/phases/07-unbreak-the-morning/07-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (WR-01, WR-02, WR-03, IN-01; IN-02 explicitly out of scope per instructions)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: `scheduleMidDayNudge` Missing Linux/Windows Platform Guard

**Files modified:** `lib/services/notification_service.dart`
**Commit:** `3da4308`
**Applied fix:** Added `if (Platform.isLinux || Platform.isWindows) return;` immediately after the existing `kIsWeb` guard, with the same LOOP-04 comment that documents the reasoning in `scheduleMorningNotification`. The guard appears before `_plugin.cancel(id: 1)` so the method is a no-op on desktop (cancel also calls through to the plugin and would fail on Linux/Windows with the uninitialized timezone database).

---

### WR-02: Notification Tap Fires Before Router is Ready (Race on Cold Launch)

**Files modified:** `lib/main.dart`
**Commit:** `ced632f`
**Applied fix:** Wrapped both `router.go('/schedule')` and `router.go('/schedule/checkin')` inside `WidgetsBinding.instance.addPostFrameCallback((_) { ... })`. The `scheduleNotifier.hasScheduleToday` check and the conditional navigation logic are unchanged — only the timing is deferred. A `WR-02:` comment explains why the callback is necessary.

---

### WR-03: `_InMemoryScheduleNotifier.hasScheduleToday` Override Weakens LOOP-02 Lock

**Files modified:** `test/screens/cold_launch_morning_loop_test.dart`
**Commit:** `6e61e01`
**Applied fix:** Added a four-line doc-comment directly above the `hasScheduleToday` override explaining that it intentionally skips the LOOP-02 date-string comparison and that any LOOP-02 (day-rollover) regression test must use the real `ScheduleNotifier`. No logic changed.

---

### IN-01: `ymdToday()` is a Dead Public Method

**Files modified:** `lib/providers/schedule_notifier.dart`
**Commit:** `b080da8`
**Applied fix:** Removed `ymdToday()` entirely. Grep confirmed zero callers in `lib/` and `test/`. Renaming to `_ymdToday()` was tried first but triggered an `unused_element` lint (the method has no call sites within the class either), so deletion was the cleanest resolution. `flutter analyze` confirmed 0 errors/warnings on the file after removal.

---

## Skipped Issues

None.

---

## Post-Fix Verification

**`flutter analyze`:** 0 errors, 0 warnings. 5 pre-existing `deprecated_member_use` (info-level) on `onReorder` in unrelated files — present before these fixes.

**`flutter test`:** 91/91 passed.

---

_Fixed: 2026-06-10_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
