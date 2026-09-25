---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 03
subsystem: calendar
tags: [google-calendar, googleapis, recurrence-mapping, timezone, oauth-scope]

requires:
  - phase: 36-01
    provides: GoogleAuthClient, the GoogleCalendarSource tracer skeleton, the google: id prefix convention, kGoogleCalendarReadonlyScope
provides:
  - "mapGoogleEvent/mapGoogleEventStatus/resolveGoogleInstant — pure, fixture-tested mapping from googleapis's Event/EventDateTime onto CalendarEvent, covering all eight shapes Google actually returns (moved recurrence, cancelled-with-fallback, timeless cancelled stub, all-day, foreign-offset, no-summary, tentative)"
  - "CalendarInfo.sourceLabel — nullable DTO field distinguishing a Google calendar from a device calendar in the picker (D-36-03)"
  - "GoogleCalendarSource.listCalendars() — full mapping against Google's real calendarList.list shape, accountName sourced from the PRIMARY entry's id"
  - "CALAUTH-02 proven mechanically: one read-only scope reaching the auth client, no mutating CalendarApi verb reachable, no public method beyond the four CalendarSource verbs"
affects: [36-05, 36-06, calendar_settings_screen]

actuals:
  tokens: 9300
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Pure-function/adapter split for Google mapping, mirroring device_calendar_source.dart: mapGoogleEvent/mapGoogleEventStatus/resolveGoogleInstant live above the class and take plain googleapis-shaped values, so the mapping is unit-tested with fixture JSON and no network"
    - "originalStartTime read-then-discard: the moved-occurrence fix is 'read the field, prove you didn't use it as the primary start' — documented in the function's own doc comment so a future reader doesn't wire it back in"

key-files:
  created:
    - test/fixtures/calendar/google_events_list_recurring_moved.json
    - test/fixtures/calendar/google_events_list_edge_cases.json
    - test/fixtures/calendar/google_calendar_list.json
  modified:
    - lib/data/calendar/calendar_event.dart
    - lib/data/calendar/google_calendar_source.dart
    - lib/data/calendar/device_calendar_source.dart
    - test/data/calendar/google_calendar_source_test.dart
    - test/data/calendar/device_calendar_source_mapping_test.dart

key-decisions:
  - "resolveGoogleInstant returns EventDateTime.dateTime UNCHANGED for a timed value — googleapis's own DateTime.parse already normalizes an explicit offset or Z to the correct absolute UTC instant (confirmed by direct experiment against the installed 17.0.0 package, not assumed), so no re-resolution logic like IcsCalendarSource's is needed for the timed case; only the all-day date-only case needs the tz.local reconstruction, mirroring the ICS floating-value discipline."
  - "The null-guard that lets a timeless cancelled stub drop cleanly is written with an explicit force-unwrap (ownStart ?? fallbackStart!) specifically so its mandatory mutation proof is a genuine RUNTIME throw, not a compile error — a guard written as a simple type-promoting `if (x == null) return null;` would only fail to compile if removed, which is a weaker, less instructive mutation signal."
  - "accountName for every Google calendar (primary or secondary) is the PRIMARY entry's id, never a calendar's own id — a secondary calendar's id is often synthetic (@group.calendar.google.com, a holiday feed's opaque id) and is not an account identifier; grouping and plan 36-05's overlap detector both need one shared account value."

requirements-completed: [CALAUTH-01, CALAUTH-02]

coverage:
  - id: D1
    description: "Google's eight real event shapes (moved recurrence, cancelled-with-fallback, timeless cancelled stub, all-day, foreign-offset, no-summary, tentative, and shared uid/recurrenceId identity) all map correctly or drop cleanly"
    requirement: CALAUTH-01
    verification:
      - kind: unit
        ref: "test/data/calendar/google_calendar_source_test.dart#mapGoogleEvent — Google event shapes the real API actually returns (Task 1)"
        status: pass
      - kind: unit
        ref: "test/data/calendar/google_calendar_source_test.dart#a moved recurring instance maps to its own (moved) start... (mutation-proofed)"
        status: pass
    human_judgment: false
  - id: D2
    description: "CalendarInfo.sourceLabel added (Google/This device) and listCalendars() fully maps summary/backgroundColor/isReadOnly/accountName against Google's real calendarList.list shape, with the google: id prefix round-tripping correctly"
    requirement: CALAUTH-01
    verification:
      - kind: unit
        ref: "test/data/calendar/google_calendar_source_test.dart#GoogleCalendarSource.listCalendars() — CalendarInfo mapping and sourceLabel (Task 2, D-36-03)"
        status: pass
      - kind: unit
        ref: "test/data/calendar/device_calendar_source_mapping_test.dart#sourceLabel is always \"This device\"..."
        status: pass
    human_judgment: false
  - id: D3
    description: "CALAUTH-02 machine-checked: exactly one read-only scope reaches the auth client, no mutating CalendarApi verb is reachable, GoogleCalendarSource exposes no public method beyond the four CalendarSource verbs"
    requirement: CALAUTH-02
    verification:
      - kind: unit
        ref: "test/data/calendar/google_calendar_source_test.dart#requestPermission() hands the auth client exactly one scope..."
        status: pass
      - kind: unit
        ref: "test/data/calendar/google_calendar_source_test.dart#GoogleCalendarSource satisfies CalendarSource and exposes no public method..."
        status: pass
      - kind: other
        ref: "grep -rh --include='*.dart' -v '^\\s*//' lib/data/calendar/ | grep -cE '\\.(insert|update|patch|delete|move|import)\\(' == 0"
        status: pass
    human_judgment: false

duration: not precisely measurable — all three commits were made together at the end of a single continuous session after implementation, mutation-proofing, and full-suite verification, so their git timestamps (~40s apart) do not reflect elapsed working time
completed: 2026-09-25
status: complete
---

# Phase 36 Plan 03: Google Calendar Mapping Build-Out Summary

**Google's eight real event shapes (moved recurrence, cancelled stubs, all-day, foreign-offset, tentative) map correctly or drop cleanly through pure fixture-tested functions; `CalendarInfo.sourceLabel` lets the picker tell a Google calendar from a device one; and CALAUTH-02's read-only guarantee is proven by two grep gates and a scope-assertion test rather than asserted in prose.**

## Performance

- **Tasks:** 3 (all implemented and committed)
- **Files created:** 3 (fixtures)
- **Files modified:** 5

## Accomplishments

- `mapGoogleEvent`, `mapGoogleEventStatus`, and `resolveGoogleInstant` — three pure, top-level functions in `google_calendar_source.dart`, split above the adapter class exactly as `device_calendar_source.dart` already does. Fixture-driven tests exercise all eight `<behavior>` shapes directly against the mapping functions, not through the adapter.
- **The moved-recurrence fix (WINDOWS.md entry 1, `.ics` path only):** a weekly series with one instance moved to a different time maps that instance to its OWN `start.dateTime`, never to `originalStartTime`. `originalStartTime` is read and then deliberately discarded — its doc comment states this explicitly so a future reader doesn't "fix" the unused-looking field back in.
- `uid`/`recurrenceId` follow `CalendarEvent`'s documented contract: `recurringEventId` (the series) becomes `uid`, the instance's own `id` becomes `recurrenceId` — the mirror image of `device_calendar_source.dart`'s `mapDeviceEvent`.
- A cancelled instance returned only because `showDeleted: true` maps to `CalendarEventStatus.cancelled` and is not dropped by the mapper (`CalendarSyncService` already skips it downstream). A cancelled stub with only `id`/`status`/`recurringEventId`/`originalStartTime` falls back to `originalStartTime`. A cancelled stub with **neither** a usable `start` **nor** a usable `originalStartTime** — Google's minimal shape for a deleted instance — drops cleanly via a null-guard, proven load-bearing by a recorded mutation (below).
- An all-day event (`start.date`, not `dateTime`) maps `isAllDay: true` using only the extracted year/month/day reinterpreted in `tz.local` — never the parsed `DateTime`'s own instant, which Dart ties to this machine's real system clock for a date-only string. A timed event with a non-local UTC offset (`-05:00`) resolves to the correct absolute instant with no `.toLocal()` call anywhere — confirmed by direct experiment that `googleapis`'s own `DateTime.parse` already normalizes an explicit offset to UTC.
- A missing `summary` maps to `''` rather than throwing; a tentative event imports normally, matching the `.ics` path's existing behaviour.
- `CalendarInfo` gains a nullable `sourceLabel` field (D-36-03). `GoogleCalendarSource.listCalendars()` sets it to `'Google'`; `mapDeviceCalendar` sets it to `'This device'` — byte-identical to the account-less fallback `calendar_settings_screen.dart:459` already renders, so the picker gains no second vocabulary for the same idea.
- `listCalendars()` fully maps Google's `calendarList.list` response: `summary` → `name`, `backgroundColor` → `colorHex`, `isReadOnly: true` unconditionally, and — the one non-obvious rule — `accountName` sourced from the **PRIMARY** entry's id for **every** calendar in the response, since a secondary or subscribed calendar's own id is often synthetic (`...@group.calendar.google.com`, a holiday feed's opaque id) and is not an account identifier. Grouping and plan 36-05's overlap detector both need one shared account value per source.
- The `google:` id prefix round-trips: prefixed on the way out of `listCalendars()`, stripped from the outbound `events.list()` request — proven by inspecting the ACTUAL request URL through a recording fake `http.Client`, not by re-reading the constant that does the stripping.
- CALAUTH-02 machine-checked: `requestPermission()` hands the auth client exactly one scope, asserted against a bare literal (`'https://www.googleapis.com/auth/calendar.readonly'`), never re-derived from `kGoogleCalendarReadonlyScope`. `GoogleCalendarSource` is proven to satisfy `CalendarSource` and expose no public method beyond the four interface verbs plus its constructor, by scanning the class's own source text for any additional `Future<...>`-returning method. All grep gates pass: no mutating `CalendarApi` verb reachable (0), the scope string exists in exactly one file (1), no write-capable scope anywhere (0).

## What `googleapis` 17.0.0 actually looks like vs. Assumption A4

**Confirmed exactly as assumed.** Read the installed package directly (`~/.pub-cache/hosted/pub.dev/googleapis-17.0.0/lib/calendar/v3.dart`) rather than trusting research: `Event` exposes `id`, `status`, `summary`, `recurringEventId`, `originalStartTime`, `start`, `end` with those exact names; `EventDateTime` exposes `date`/`dateTime`/`timeZone`; `CalendarListEntry` exposes `id`/`summary`/`primary`/`backgroundColor`. No field-name correction was needed to the fixtures.

**One thing research's field list didn't need to say, discovered by direct experiment rather than assumed:** `EventDateTime.dateTime` is parsed by `googleapis` itself via `DateTime.parse`, which ALREADY normalizes an explicit numeric offset (or `Z`) to the correct absolute UTC instant — `DateTime.parse('2026-03-03T14:00:00-05:00')` returns `2026-03-03 19:00:00.000Z` with `isUtc == true`, not a value re-anchored to any other zone. This meant the timed-event resolver needed no `IcsCalendarSource`-style re-resolution logic at all; only the all-day (`date`-only) case needed the `tz.local` reconstruction, because `DateTime.parse('2026-03-05')` (no time, no zone) resolves as a **system-local** `DateTime`, which is unsafe to use directly.

## Two mandatory mutation proofs, run and reverted

**1. Preferring `originalStartTime` over `start`.** Changed `final start = ownStart ?? fallbackStart!;` to `final start = fallbackStart ?? ownStart!;`, ran the suite, observed:
```
Expected: DateTime:<2026-03-09 15:00:00.000Z>
  Actual: DateTime:<2026-03-09 14:00:00.000Z>
```
The moved-instance test failed with the ORIGINAL (pre-move) time exactly where the moved time was expected — confirming the assertion genuinely discriminates the bug this whole path exists to fix. Reverted immediately.

**2. Removing the null-guard on the timeless cancelled stub.** Changed the guard from `if (ownStart == null && fallbackStart == null) return null;` to nothing, ran the suite, observed:
```
Expected: return normally
  Actual: <Closure: () => CalendarEvent?>
   Which: threw _TypeError:<Null check operator used on a null value>
```
A genuine RUNTIME throw, not a compile error — the guard is written with an explicit `ownStart ?? fallbackStart!` force-unwrap specifically so removing the guard produces this kind of failure rather than a type-promotion compile error, which would be a weaker mutation signal. Reverted immediately.

## What the fixtures prove and what they do not

**Proven here, against fixtures built from `googleapis` 17.0.0's own documented field names:** our mapper honours a moved instance's own start, drops a timeless cancelled stub cleanly instead of crashing, resolves a foreign-UTC-offset event to the correct absolute instant, and tags every calendar with which source it came from. Two mutation proofs (above) confirm the load-bearing assertions actually discriminate the defects they claim to catch.

**Not proven here, and not provable on this machine:** that Google's live API genuinely returns a moved occurrence at its moved time when queried with `singleEvents=true`. Nobody on danserver can capture a real Google response — that is plan 36-07's item 4, on the owner's MacBook, against a real recurring meeting he moves himself.

**The WINDOWS.md entry 1 claim is scoped to the `.ics` path only, per `36-DECISIONS.md`'s "Correction on the record."** Phase 35 Assumption A1 records that `device_calendar_plus.listEvents()` already returns expanded occurrences with exceptions applied, so on the iOS device path Google sign-in adds no recurrence advantage — and A1 itself is still unverified, because 35-05's device gate is open. This SUMMARY does not repeat the overstated claim; the recurrence fix is a genuine advantage over `.ics` alone, which is what the browser and Android use.

## Task Commits

1. **Task 2 (dependency, ordered first — CalendarInfo.sourceLabel field)** — `46dc5f0` (feat)
2. **Tasks 1 and 3, plus Task 2's Google-side mapping (all three share `google_calendar_source.dart` and its test file, so they land in one commit)** — `b15fd68` (feat)
3. **Task 2's device-side change (`mapDeviceCalendar` sourceLabel assignment)** — `47defac` (feat)

**Commit-granularity note (not a deviation, a disclosure):** the plan's three tasks are not one-commit-per-task here because Tasks 1, 2 (Google side), and 3 all modify the SAME two files (`google_calendar_source.dart` and its test file) as one coherent, tightly-coupled unit of work — the mapping functions, the calendar-list mapping, and the CALAUTH-02 proof are not independently compilable/testable slices of that file. `calendar_event.dart`'s `sourceLabel` field had to land first (commit 1) because both later commits depend on it compiling. `mapDeviceCalendar`'s own `sourceLabel` assignment is the one piece of Task 2 that lives in a genuinely separate file, so it is its own commit (3). Every task's own acceptance-criteria tests are labelled by task number in their test descriptions, so which commit satisfies which task's criteria is traceable from the test names, not just the commit message.

## Files Created/Modified

- `lib/data/calendar/google_calendar_source.dart` — pure mapping functions + `listCalendars()` full mapping + CALAUTH-02 doc comment
- `lib/data/calendar/calendar_event.dart` — `CalendarInfo.sourceLabel` (nullable, additive)
- `lib/data/calendar/device_calendar_source.dart` — `mapDeviceCalendar` sets `sourceLabel: 'This device'`
- `test/data/calendar/google_calendar_source_test.dart` — 13 new tests across Tasks 1-3 (2 original tracer tests untouched)
- `test/data/calendar/device_calendar_source_mapping_test.dart` — 1 new test for the device `sourceLabel`
- `test/fixtures/calendar/google_events_list_recurring_moved.json` — a weekly series, three ordinary instances plus one moved instance
- `test/fixtures/calendar/google_events_list_edge_cases.json` — two cancelled shapes (with/without a usable fallback time), all-day, foreign-offset, no-summary, tentative
- `test/fixtures/calendar/google_calendar_list.json` — a primary calendar, a secondary `@group.calendar.google.com` calendar, a subscribed holiday calendar

## Decisions Made

See `key-decisions` in the frontmatter — the `resolveGoogleInstant`/`.toLocal()` avoidance rule, the force-unwrap guard design for a genuine mutation-provable drop, and the primary-entry-id `accountName` rule.

## Deviations from Plan

None — plan executed exactly as written. The commit-granularity note above is a disclosure about HOW the three tasks were committed (see "Task Commits"), not a deviation from what was built or verified; every acceptance criterion in the plan was satisfied and every required test/mutation proof was run.

## Known Stubs

None. Every function shipped here is a real, working implementation exercised by a passing test — no hardcoded empty/placeholder data.

## Issues Encountered

None.

## Verification Run

- `flutter analyze`: clean (0 issues), run after every commit and again at the end.
- `flutter test`: 844/844 green (830 baseline from 36-01 + 14 new: 13 in `google_calendar_source_test.dart`, 1 in `device_calendar_source_mapping_test.dart`).
- `lib/services/schedule_generator.dart`: byte-identical (`git diff --quiet` exits 0), checked after every commit.
- Grep gates: `showDeleted`/`singleEvents` each ≥1 (both 1); no mutating verb (0); scope string in exactly 1 file (1); no write-capable scope (0); `sourceLabel:` assigned in exactly 2 files (2).

## Next Phase Readiness

- Plan 36-05 (composite calendar source, overlap detection) can rely on `CalendarInfo.sourceLabel` and the `google:` id prefix's proven round-trip.
- Plan 36-06 (calendar picker UI) can group by `sourceLabel` directly — both values (`'Google'`, `'This device'`) are already the exact copy the UI-SPEC's plain voice calls for.
- Plan 36-07 (the owner's MacBook) is the only place the WINDOWS.md entry 1 fix can be confirmed against a real Google response — this plan proves the mapping is correct GIVEN Google's documented shape; it does not and cannot prove Google emits that shape live.

## Self-Check: PASSED

All 3 created fixture files confirmed present on disk (`test -f`). All 3 task commit hashes (`46dc5f0`, `b15fd68`, `47defac`) confirmed present in `git log --oneline --all`. Full suite re-run before this SUMMARY was written: 844/844 green, `flutter analyze` clean, `schedule_generator.dart` byte-identical.

---
*Phase: 36-connect-google-calendar-without-hunting-for-a-url*
*Plan: 03*
*Completed: 2026-09-25*
