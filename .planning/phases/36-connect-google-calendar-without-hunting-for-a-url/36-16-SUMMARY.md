---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 16
subsystem: calendar-settings-ui
tags: [calendar, picker, ordering, layout-shift, windows-14, CAL-02]
requires: [36-14, 36-15]
provides:
  - "sortCalendarsForPicker(List<CalendarInfo>): deterministic device-calendar order (account, name, id; case-insensitive; no-account first)"
  - "Calendars screen section order: banner -> device -> divider -> Google -> footer"
affects: [36-17]
tech-stack:
  added: []
  patterns: ["sort at render, not in the loaders", "exact-dy assertions across an async load"]
key-files:
  created: []
  modified:
    - lib/screens/settings/calendar_settings_screen.dart
    - lib/data/calendar/calendar_source_factory.dart
    - test/screens/settings/calendar_settings_screen_test.dart
key-decisions:
  - "Sort applies to the device section only; Google keeps the order its API returned."
  - "Device section moved above Google (reversible: swap two lines in _buildMobileBody)."
requirements-completed: [CAL-02]
duration: ~40min
completed: 2026-11-02
status: complete
commits: 2
plan_head_before: f593cd1e382a077d1aebdebdda076c7e46d691af
plan_head_after: 27e24becec82bcf4031a34b4a6a79c772046728e
actuals:
  tokens: 14000
  tasks: 2
  commits: 2
---

# Phase 36 Plan 16: Deterministic device order, device section above Google Summary

Device calendars now render in one deterministic order on every open (account, then name, then id, case-insensitive, no-account group first), and the device section sits above the Google section so a Google list that loads late over the network cannot shift device rows under a finger. This is the code half of WINDOWS entry 14; whether a tick ever lands wrong again is the owner's re-test in `36-UAT-R3.md` (plan 36-17).

## Tasks

| # | Task | Commit |
|---|------|--------|
| 1 (tracer) | `sortCalendarsForPicker` applied once in `_buildDeviceSection`; restorable fake gains `calendarOrders`; 3 tests | 5fdf76a |
| 2 | `_buildMobileBody` reordered; base fake gains `listCalendarsGate`; 2 tests; factory doc sentence corrected | 27e24be |

Tracer gate: Task 1's verify (the whole screen test file) was green, and its mutation done, before Task 2 began.

## Findings on WINDOWS entry 14 (for 36-17 to quote)

1. **No mechanism in the toggle path.** A plain, stationary tap cannot store the wrong id: `_toggleCalendar` keys by `calendar.id`; each `CheckboxListTile.onChanged` closes over the calendar it was built for; `SettingsNotifier.setSelectedCalendarIds` replaces the in-memory list synchronously before awaiting Hive, so two quick taps cannot read a stale selection.
2. **Mechanism A (real; likeliest cause of the observed tick): unstable row order.** Until 36-14 the device list was torn down and re-fetched on every "Allow calendar access" tap (every re-open, because of entry 12) and on mobile "Sync now"; the CTA collapsed to a spinner and the list reappeared in its place, moving rows under a finger aimed at the old layout. The re-fetched list also comes back in EventKit's order: `device_calendar_plus_ios-0.7.0` `CalendarService.swift` (lines 12-55) iterates `eventStore.calendars(for: .event)` and appends with no sort, Apple documents no order, and nothing between the plugin and `_calendarRows` sorted. 36-14 removed the teardown; this plan makes the order deterministic so even a re-fetch puts each row where it was.
3. **Mechanism B (real, latent on 2026-11-02, armed for the next sitting): Google above device.** With Google connected, its list loads over the network while the device list restores near-instantly, so device rows appeared and then jumped down by the whole Google list at an arbitrary moment. On 2026-11-02 Google was not connected (the screenshot shows the Connect card), so B cannot have caused the observed tick; the next sitting connects Google and would have armed it, producing a false "entry 14 reproduces". Fixed by rendering the device section first.
4. **Not mechanisms, not changed:** widget keys on `CheckboxListTile` matter only if the list re-orders between pointer-down and pointer-up; with no in-place teardown and a deterministic order, the rows are built from one list per open, so a key has nothing to protect (and an added key would be untestable). The account-groups map is a Dart `{}` literal (`LinkedHashMap`, insertion-ordered) and is deterministic once its input list is.

**Residual, recorded not fixed:** the skipped-events banner sits at the top (the owner's own ask, entry 10). When a sync the user just triggered turns the skipped set from empty to non-empty, the banner appears and shifts the list down once. It follows his own tap and is not a load-in race; moving the banner would undo entry 10's fix.

**Decided here:** the section-order change is visible and reversible (swap two lines). It contradicts nothing locked: 36-06's "Google section first" was an implementation choice; D-36-03 only rules that both sources coexist. The UAT document (36-17) must tell the owner the order changed and why.

## Final state

- `flutter test`: **1004 passed, 0 failed** (36-15 closing count 999; +5 = 3 in Task 1, 2 in Task 2).
- `flutter analyze`: **No issues found!**
- `git diff 8f62a56 -- lib/services/schedule_generator.dart`: **empty** (0 bytes).
- Factory gate: `git diff df106fe -- lib/data/calendar/calendar_source_factory.dart` has **0** changed lines that are not `///` doc comments.
- 36-14's `requestPermissionCount == 0` tests, 36-15's fresh-open banner tests and 36-09's banner-first/position tests pass unedited.

## Mutation proofs (RUNTIME failures; each reverted, `diff` against the pre-mutation copy printed `identical`)

**Task 1 — remove the `sortCalendarsForPicker` call from `_buildDeviceSection`** (`sortCalendarsForPicker(state.calendars)` -> `state.calendars`). The first-open order assertion failed (source returned `[spunkl, Home, Family]`, so Family sat below Home):
```
the device rows come out Family, Home, spunkl on the first open AND on a re-open where the source returned a different order [E]
Expected: a value less than <600.0>
  Actual: <656.0>
first open: Family above Home
```
Honest note: under this mutation the **tap-stores-the-label test stayed green** (and the pure-function test, which calls the function directly, naturally too). That test cannot discriminate the missing sort, because a tap by label stores that label's id whatever the order; it guards against a different regression (a row wired to another row's id, e.g. an index-based handler). The load-bearing discriminator for the sort is the `dy` order test above.

**Task 2 — swap the device and Google sections back** (Google, divider, device). Three tests failed, including the new exact-`dy` assertion (Google's spinner holds the top slot while loading, then the Google rows land above the device rows and push Family from 168.0 down to 388.0):
```
Google connected, its list held open: the device rows are visible first; releasing Google moves none of them, and every Google row sits below them [E]
Expected: <168.0>
  Actual: <388.0>
Family moved

Google not connected: the device rows render above the "Connect Google Calendar" button [E]
Expected: a value less than <402.0>
  Actual: <544.0>
   Which: is not a value less than <402.0>
Family

Plan 36-06 overlap disclosure ... a flagged row checkbox still toggles ... [E]
Expected: not contains 'google:work'
  Actual: ['google:work']
```
(The third is the pre-existing test that assumed Google-first; see Deviations.)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] An existing test encoded the old section order**
- **Found during:** Task 2
- **Issue:** `Plan 36-06 — overlap disclosure ... a flagged row checkbox still toggles` tapped `find.byType(CheckboxListTile).first` with the comment "the Google section renders first". With the device section first, `.first` is the device row, so it unticked the wrong calendar and failed. Both calendars are named "Work", so a label tap cannot disambiguate.
- **Fix:** tap `.last` and rewrite the comment to name 36-16 / entry 14 as the reason. This is the only edit to a pre-existing assertion. The plan said Google tests pass unedited with respect to Google's row order inside its section; this test depended on cross-section order, which this plan deliberately changes.
- **Files modified:** `test/screens/settings/calendar_settings_screen_test.dart`
- **Commit:** 27e24be

**2. [Environment] `flutter test --no-pub` crashed in a fresh worktree** (`Bad state: No element` in the native-assets builder) because `.dart_tool/` did not exist. `flutter pub get` fixed it; no `pubspec.yaml` / `pubspec.lock` change (checked with `git status`). A stray `flutter_01.log` crash report was deleted before any commit.

The existing "grouped by account" test needed no update: no assertion depended on the source's raw order.

## Known Stubs

None.

## Threat Flags

None. T-36-57 (row order) and T-36-58 (layout shift) are mitigated and mutation-proven above; T-36-SC accepted (no dependency added).

## Self-Check: PASSED

- 5fdf76a and 27e24be are ancestors of HEAD; `plan_head_before` is the dispatch base f593cd1.
- `sortCalendarsForPicker` present in `lib/screens/settings/calendar_settings_screen.dart`; section order verified by the tests above.
- STATE.md, ROADMAP.md, WINDOWS.md untouched.
