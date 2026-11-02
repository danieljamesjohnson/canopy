---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 14
subsystem: calendar-settings
tags: [flutter, device_calendar_plus, permissions, gap-closure, windows-12, windows-13]
requires: []
provides:
  - CalendarPermissionReader (prompt-free permission status capability)
  - DeviceCalendarSource.currentPermission() and readPermissionStatus / requestPermissionStatus seams
  - Calendars screen device-section restore on first build
  - in-place mobile "Sync now" with in-flight state and success SnackBar
affects: [lib/screens/settings/calendar_settings_screen.dart]
tech-stack:
  added: []
  patterns:
    - "separate one-method capability interface instead of widening CalendarSource"
    - "runtime `is` check for an optional capability (compiles when the capability is removed)"
key-files:
  created: []
  modified:
    - lib/data/calendar/calendar_source.dart
    - lib/data/calendar/device_calendar_source.dart
    - lib/screens/settings/calendar_settings_screen.dart
    - test/data/calendar/device_calendar_source_mapping_test.dart
    - test/screens/settings/calendar_settings_screen_test.dart
decisions:
  - "Permission status read is a separate CalendarPermissionReader, not a fifth CalendarSource verb (ROADMAP Phase 36 decision 3; Google four-verb structural test)."
  - "Restore lists calendars only; it never syncs and never requests."
  - "Desktop/web Sync now deliberately unchanged."
metrics:
  tasks: 2
  completed: 2026-11-02
status: complete
commits: 2
plan_head_before: 035cbf25fc0719bd8a9989c435589f95df4440f1
plan_head_after: 2462c6fb36f09556e220fa93211b0f854c3ea6b7
actuals:
  tokens: 6500
  tasks: 2
  commits: 2
---

# Phase 36 Plan 14: Device permission restore and in-place Sync now Summary

Re-opening Settings -> Calendars with iOS calendar access already granted now shows the calendar list through a prompt-free `hasPermissions()` read (zero permission requests), and mobile "Sync now" syncs in place with a disabled-plus-spinner button and a SnackBar carrying the locked status sentence.

## What was done

**Task 1 (tracer) — commit 74c1354.** WINDOWS entry 12.
- `CalendarPermissionReader` (one method, `currentPermission()`) added to `calendar_source.dart`. `CalendarSource` itself is unchanged.
- `DeviceCalendarSource` now `implements CalendarSource, CalendarPermissionReader`, with two optional seams (`readPermissionStatus`, `requestPermissionStatus`) defaulting to top-level functions that call the plugin's `hasPermissions` / `requestPermissions`. `currentPermission()` goes through the read seam; `requestPermission()` through the request seam. A bare `DeviceCalendarSource()` touches no plugin API.
- Screen: `_restoreDeviceSection` reads status, lists calendars if granted (cached in `_deviceCalendars`), never requests, never syncs; any throw folds to `notDetermined` (the existing CTA). `_buildDeviceSection` initialises `_mobileFuture` with it on first build via an `is CalendarPermissionReader` runtime check. `_deviceGranted` / `settings.googleConnected` now also show the footer, so a restored user always has "Sync now".
- Class doc and `_mobileFuture` doc rewritten (they claimed the future was "set only when the user taps").

**Task 2 — commit 2462c6f.** WINDOWS entry 13.
- `_syncNow` mobile branch now calls `_syncInPlace`: guarded by `_syncing`, resolves the sync source, awaits `_syncAndReport`, shows a SnackBar built by `_statusText` on success, clears `_syncing` in `finally`. It never touches `_mobileFuture`, never requests, never re-lists.
- `_statusText(syncedAt, importedCount)` is the single builder of the locked sentence; the footer uses it too.
- `_footer` lost its `syncResult` parameter and reads only `settings.lastCalendarSyncAt`, so a failed sync cannot render as a fresh "Synced just now".
- In flight, the footer button is a disabled `TextButton.icon` with a 16dp `CircularProgressIndicator(strokeWidth: 2)` and the unchanged "Sync now" label.
- No new user-visible string.

**Desktop/web "Sync now" is deliberately unchanged.** It already replaces the body with a spinner while it reloads, no defect was reported there, and it is outside entries 12/13. The asymmetry (mobile syncs in place; desktop reloads the body) is a decision, not an oversight.

## Verification

- `flutter test`: **947 passed, 0 failed** (baseline 934; +13: 2 device-source tests, 6 entry-12 screen tests, 5 entry-13 screen tests).
- `flutter analyze`: **No issues found!**
- Gate `git diff 8f62a56 -- lib/services/schedule_generator.dart`: **empty** (0 bytes).
- `grep -rc "Synced just now" lib/`: 0 for every file. No test locates the Sync now button with an exact-type `TextButton` lookup.
- Task 1 second verify (`hasPermissions` referenced outside comments in `device_calendar_source.dart`): passes (line 151, the default read seam).
- Pre-existing tests in both files pass unedited (only additions to the shared fake: new counters/fields and a new subclass).

## Mutation proofs (all RUNTIME failures, all reverted)

**Task 1**

(a) `_restoreDeviceSection` calls `source.requestPermission()` before listing. Failing tests: the granted-restore test and the re-open test.
```
Expected: <0>
  Actual: <1>      (granted status renders the three rows ... ZERO permission requests, and no sync)
Expected: <0>
  Actual: <2>      (re-opening the screen ... still never requests permission)
```

(b) Restore initialisation disabled in `_buildDeviceSection` (`if (false && source is CalendarPermissionReader)`). Four tests fail, e.g.:
```
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Home": []>
   Which: means none were found but one was expected
```
and likewise for "spunkl", "Not synced yet", and "Calendar access is off".

(c) `DeviceCalendarSource.currentPermission()` calls the request seam. The seam test fails:
```
Expected: CalendarPermissionState:<CalendarPermissionState.granted>
  Actual: CalendarPermissionState:<CalendarPermissionState.denied>
```

(d) `implements CalendarPermissionReader` removed from `DeviceCalendarSource`, method kept. Everything compiled (analyzer reported only `override_on_non_overriding_member` as a warning). The production-wiring test failed at runtime:
```
Expected: <Instance of 'CalendarPermissionReader'>
  Actual: <Instance of 'DeviceCalendarSource'>
   Which: is not an instance of 'CalendarPermissionReader'
```
No compile error anywhere, so the wiring is not statically typed.

**Task 2**

(a) Footer's `_syncing` branch removed (`(false && _syncing)`). The in-flight test fails:
```
Expected: null
  Actual: <Closure: () => void>
```
(the Sync now button's `onPressed` is still enabled while syncing).

(b) Old `_syncNow` mobile body restored (reassigns `_mobileFuture = _requestMobilePermission(...)`). Four tests fail. The test written to be independent of the spinner assertions fails on its own rows assertion:
```
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "spunkl": []>
   Which: means none were found but one was expected
```
Also the double-tap test (`Expected: <1>  Actual: <2>`, because the old body started a second sync) and the success-SnackBar test.

(c) Success SnackBar deleted (`if (false && !result.failed && mounted)`). The success test fails:
```
Expected: exactly one matching candidate
  Actual: _DescendantWidgetFinder:<Found 0 widgets with text "Synced just now — 1 commitment ...
   Which: means none were found but one was expected
```

(d) `_footer` prefers the last attempt's time again (`_lastSyncResult?.syncedAt ?? settings.lastCalendarSyncAt`). The failed-sync test fails:
```
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Not synced yet": []>
   Which: means none were found but one was expected
```

## Deviations from Plan

**1. [Rule 1 - Test discrimination] Split the in-flight Sync now test in two.**
- **Found during:** Task 2 mutation (b).
- **Issue:** with the old `_syncNow` body restored, the first assertion in the combined test (button disabled) failed and masked the rows-still-present and `requestPermissionCount == 0` assertions, so mutation (b) did not prove those independently.
- **Fix:** separate tests for "button disabled + spinner" and "rows stay, zero requests, no re-list". Mutation (b) now fails the rows assertion on its own.
- **Files:** test/screens/settings/calendar_settings_screen_test.dart.

**2. [Rule 3 - Blocking] Explicit cast for the capability hand-off.** `CalendarPermissionReader` is unrelated to `CalendarSource`, so `source is CalendarPermissionReader` does not promote `source`; the first draft did not compile. The screen passes `source as CalendarPermissionReader` inside the `is` branch (commented). Still a runtime check, and it still compiles with the `implements` clause removed (proven by mutation d).

**3. Comment wording.** Two comments initially contained the literal strings the acceptance greps look for ("Synced just now" in `lib/`, an exact-type `TextButton` lookup in the test). Reworded so the invariant greps report 0.

**4. Test-file formatting not applied.** `dart format` on the screen test file would have reformatted 166 pre-existing lines; it was reverted so pre-existing tests stay byte-identical. New test code is hand-formatted (one line slightly over 80 columns).

## Known Stubs

None.

## Threat Flags

None. T-36-51 (unrequested prompt), T-36-52 (failed sync shown as fresh), T-36-53 (overlapping syncs) are mitigated and mutation-proven above (T-36-53 by the `_syncing` guard plus the disabled button; the double-tap test asserts one fetch).

## Not touched

STATE.md, ROADMAP.md and WINDOWS.md were not modified, per the dispatch instruction. Entries 12 and 13 still need closing there by the orchestrator. Entry 14's list-teardown mechanism is removed by this plan; its remaining mechanism is not claimed fixed here. Nothing was verified on a real device: all evidence is host widget tests with fakes, plus the plugin source citations in `currentPermission()`'s doc comment.

## Self-Check: PASSED

- Commits 74c1354 and 2462c6f exist on this branch (`rev-list --count` from base = 2).
- All five modified files present; `flutter test` 947/947, `flutter analyze` clean, schedule_generator gate empty.
