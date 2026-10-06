---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 08
subsystem: calendar-sync
tags: [calendar, device-calendar, cal-02, windows-7, gap-closure]
dependency-graph:
  requires:
    - google_calendar_source.dart (constructor-time calendarIds precedent, googleCalendarIdPrefix)
    - calendar_source_factory.dart (iosCalendarSource/defaultCalendarSource composition)
  provides:
    - DeviceCalendarSource(calendarIds:, fetchEvents:) and DeviceEventsFetcher seam
    - DeviceCalendarSource.configuredCalendarIds
    - filterDeviceCalendarIds()
    - iosCalendarSource(deviceCalendarIds:) / defaultCalendarSource(deviceCalendarIds:)
  affects:
    - lib/screens/schedule/checkin_screen.dart (_generate())
    - lib/screens/settings/calendar_settings_screen.dart (_resolveSyncSource)
tech-stack:
  added: []
  patterns:
    - "constructor-time id list + empty-argument substitution (copied from GoogleCalendarSource)"
    - "injectable seam typedef for host-testable device plugin calls (mirrors IcsFetcher, GoogleApiClientFactory)"
key-files:
  created: []
  modified:
    - lib/data/calendar/device_calendar_source.dart
    - lib/data/calendar/google_calendar_source.dart
    - lib/data/calendar/calendar_source_factory.dart
    - lib/screens/schedule/checkin_screen.dart
    - lib/screens/settings/calendar_settings_screen.dart
    - test/data/calendar/device_calendar_source_mapping_test.dart
    - test/data/calendar/calendar_source_factory_test.dart
    - test/data/calendar/google_calendar_source_test.dart
decisions: []
actuals:
  tokens: 20825
  tasks: 3
  commits: 2
metrics:
  duration: "~55 minutes"
  completed: 2026-10-06
status: complete
plan_head_before: c3134e57bea82cd37fc7c89a4a8d66b4569e0153
plan_head_after: dc16890d973efec7a58c053c8e01660b6b036b05
---

# Phase 36 Plan 08: Close WINDOWS entry 7 — device calendar selection now reaches device_calendar_plus Summary

Gave `DeviceCalendarSource` the exact constructor-time calendar-id list `GoogleCalendarSource`
already had, wired the device half of `AppSettings.selectedCalendarIds` into it from both
production sync call sites, and proved — through a real `CalendarSyncService.sync()` call in a
host test, not a hand-called `listEvents` — that an unticked calendar now contributes zero events
instead of every calendar on the phone.

## What was fixed

`CalendarSyncService.sync()` always calls `listEvents(calendarIds: const [])` — that's its
documented "every calendar this source is configured for" convention. `GoogleCalendarSource`
already honored that convention by substituting a constructor-time list. `DeviceCalendarSource`
never did: it forwarded the empty list straight to `device_calendar_plus`, which resolves empty to
"every calendar on the device." That was WINDOWS entry 7, proven on the owner's iPhone on
2026-10-06 (one ticked id in Hive, four-plus distinct calendar ids in imported commitment blocks).

**Task 1** gave `DeviceCalendarSource` a `calendarIds` constructor parameter and a
`DeviceEventsFetcher` injectable seam (mirroring `IcsCalendarSource`'s `fetch:` and
`GoogleCalendarSource`'s `apiClientFactory:`), so the exact id list that would reach the plugin is
observable in a host test with no Xcode. `listEvents` now substitutes the configured list when
called with an empty argument (same convention as Google), and — the half that actually closes the
defect — returns an empty list without ever calling the seam when the resolved list is itself
empty. "Nothing ticked" now means "nothing imported," not "everything imported."

**Task 2** added `filterDeviceCalendarIds()` as the declared complement of the existing
`filterGoogleCalendarIds()` in `google_calendar_source.dart` (same file, adjacent, so the two
filters can't silently desync — this is WR-02's concern one level up), threaded a
`deviceCalendarIds` parameter through `iosCalendarSource`/`defaultCalendarSource`, and updated both
production call sites — `checkin_screen.dart`'s `_generate()` and
`calendar_settings_screen.dart`'s `_resolveSyncSource` — to pass
`filterDeviceCalendarIds(settings.selectedCalendarIds)` alongside the existing Google filter.
`_resolveDeviceSource` (the permission/list-only resolver) was left untouched, per the plan.

**Task 3** mutation-tested both load-bearing assertions, watched them fail for the right reason,
and reverted — see transcripts below.

## Mutation transcripts (Task 3)

Both mutations left the code compiling; neither failure below is a compile error.

### Mutation A — the substitution (`device_calendar_source.dart`)

Replaced the resolved target list with the incoming `calendarIds` argument verbatim and deleted
the empty-list early return (restoring the exact pre-fix forwarding behaviour). Ran
`flutter test test/data/calendar/device_calendar_source_mapping_test.dart`.

The end-to-end sync test failed with a concrete captured-vs-expected mismatch:

```
Expected: ['cal-A', 'cal-B']
  Actual: []
   Which: at location [0] is [] which shorter than expected
```

The nothing-ticked invocation-count test failed on its count, exactly as the plan predicted:

```
Expected: <0>
  Actual: <1>
```

Reverted. `flutter test test/data/calendar/device_calendar_source_mapping_test.dart` returned to
20/20 passing after the revert.

### Mutation B — the wiring (`calendar_source_factory.dart`)

Dropped the `deviceCalendarIds` argument from the `DeviceCalendarSource(...)` construction inside
`iosCalendarSource`, keeping the function's own parameter untouched. Ran
`flutter test test/data/calendar/calendar_source_factory_test.dart`.

Both new composition tests failed on `configuredCalendarIds` being empty rather than the
constructed literal list:

```
Expected: ['cal-A', 'cal-B']
  Actual: []
   Which: at location [0] is [] which shorter than expected
```

(This exact message appeared twice — once for the Google-client-present composite case, once for
the no-Google-client bare-source case — confirming both branches of `iosCalendarSource` wire the
argument through.)

Reverted. `flutter test test/data/calendar/calendar_source_factory_test.dart` returned to 7/7
passing after the revert.

`git status --short` after both reverts showed no modification to either file beyond the intended
Task 1/2 fix — confirmed before moving on.

## Verification

- `flutter test` — **915 passing, 0 failing** (baseline 908 + 7 new: 4 in
  `device_calendar_source_mapping_test.dart`, 2 in `calendar_source_factory_test.dart`, 1 in
  `google_calendar_source_test.dart`).
- `flutter analyze` — "No issues found!" (checked after every task, and again after both
  mutation reverts).
- `git diff 8f62a56 -- lib/services/schedule_generator.dart` — **empty**. The scheduling engine is
  byte-identical to its state at the start of this gap closure, as the plan required.
- `grep -c 'configuredCalendarIds' lib/data/calendar/device_calendar_source.dart` → 2 (getter +
  backing field use).
- `grep -c 'filterDeviceCalendarIds' lib/data/calendar/google_calendar_source.dart` → 1, defined
  immediately below `filterGoogleCalendarIds`.
- `grep -c "'google:'" lib/` outside `google_calendar_source.dart` → 0. No third place learned the
  prefix.
- Both production sync call sites (`checkin_screen.dart`, `calendar_settings_screen.dart`) pass
  `deviceCalendarIds:` outside a comment (grep-confirmed, count ≥ 1 each).
- `_resolveDeviceSource` in `calendar_settings_screen.dart` is unmodified — confirmed by reading
  the diff; only `_resolveSyncSource` and the new `_deviceSelectedIds` helper changed.

## What is proven vs. what is deferred

**Proven on danserver:** the user's persisted calendar selection reaches the exact point where
`device_calendar_plus` would be called, with the exact id list, through the real
`CalendarSyncService.sync()` production path — not a hand-called `listEvents()`. An unconfigured
`DeviceCalendarSource` now provably never calls the plugin seam and imports zero blocks.

**Explicitly NOT proven here, and not claimed:** whether `device_calendar_plus` itself honors a
non-empty `calendarIds` argument on real iOS hardware — restricting EventKit's actual query to
those calendars rather than, say, ignoring the argument and still returning everything. The device
path is iOS-only and cannot execute on danserver (no Xcode, no device). That confirmation is the
owner's own check, to be carried by plan 36-11's re-verification document on his iPhone. Do not
read this plan's green test suite as proof the owner's iPhone will behave correctly — it proves the
app-side wiring is correct up to the plugin boundary, nothing past it.

## Deviations from Plan

None — plan executed exactly as written. No Rule 1/2/3/4 auto-fixes were needed; the existing
`GoogleCalendarSource` pattern transferred to the device source with no surprises, and both
production call sites already imported `google_calendar_source.dart` (no new import wiring beyond
what the plan described).

## Known Stubs

None introduced by this plan.

## Threat Flags

None — every threat this plan touches (T-36-32, T-36-33, T-36-34) was already registered in the
plan's own `<threat_model>` and is covered by the mitigations/tests described above. No new
network endpoint, auth path, or schema change was introduced.
