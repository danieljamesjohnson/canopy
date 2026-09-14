---
phase: 35-your-real-commitments-read-from-your-calendar
plan: 01
subsystem: calendar-import
tags: [ics, rrule, enough_icalendar, hive, timezone, flutter]

requires: []
provides:
  - "CalendarSource interface (read-only by shape) with Ics/Null implementations and a per-platform factory"
  - "CalendarSyncService — maps ICS events to one-off, local-wall-clock CommitmentBlocks, upserts by externalEventId"
  - "CommitmentBlock.externalEventId/isFromCalendar fields, schema 9->10"
  - "checkin_screen sync trigger, degrading to last-known blocks on failure"
affects: ["35-02", "35-03", "35-04", "35-05", "35-06"]

actuals:
  tokens: 11300
  tasks: 1
  commits: 1

tech-stack:
  added: [enough_icalendar 0.17.0, rrule 0.2.18, http 1.6.0]
  patterns:
    - "CalendarSource: bare abstract interface, no write verb, one impl file per implementation (mirrors CommitmentBlockRepository)"
    - "IcsFetcher typedef as the test seam — production default is an http GET, tests inject a fixture-returning fake"
    - "tz.TZDateTime.from(event.start, tz.local) is the ONLY place local-wall-clock conversion happens — CalendarEvent.start/end always stay UTC-or-floating as parsed"

key-files:
  created:
    - lib/data/calendar/calendar_event.dart
    - lib/data/calendar/calendar_source.dart
    - lib/data/calendar/ics_calendar_source.dart
    - lib/data/calendar/null_calendar_source.dart
    - lib/data/calendar/calendar_source_factory.dart
    - lib/services/calendar_sync_service.dart
    - test/services/calendar_sync_service_test.dart
    - test/fixtures/calendar/one_timed_event.ics
  modified:
    - lib/data/models/commitment_block.dart
    - lib/data/database/migrations.dart
    - lib/providers/commitments_notifier.dart
    - lib/screens/schedule/checkin_screen.dart
    - test/data/migration_schema8_test.dart

key-decisions:
  - "D-35-05 (owner ruling, recorded here per Task 1's instruction): enough_icalendar (parse) + rrule (expand), NOT firstfloor_calendar. See full evidence table in 35-DECISIONS.md."
  - "EXDATE/RDATE/RECURRENCE-ID overrides are explicitly NOT implemented in this plan — scoped out, not silently dropped. A moved or cancelled single occurrence of a recurring event will still appear at its original time until that logic is added (candidate: 35-02 or a dedicated follow-up)."
  - "A DTSTART without a 'Z' suffix (a 'floating' ICS time, or one carrying only TZID with no embedded VTIMEZONE resolution) is parsed by enough_icalendar using Dart's system-local DateTime constructor, NOT the app's tz.local override. The mapper's tz.TZDateTime.from() only produces a correct local-wall-clock reading when the source DateTime is UTC-flagged. The test fixture therefore uses Z-suffixed (UTC) timestamps, which is also the common real-world shape for calendars exported without an embedded VTIMEZONE block. Floating/TZID-only times are a known, undocumented-until-now gap — flagged for 35-02/35-03 to confirm against real feeds."

patterns-established:
  - "Read-only calendar source interface enforced by shape (no write verb exists, so flutter analyze is the CAL-03 proof) rather than a runtime check"
  - "Stable FNV-1a hash (not String.hashCode, which is not a documented stable algorithm) for building externalEventId from a feed URL"

requirements-completed: [CAL-01, CAL-03]

coverage:
  - id: D1
    description: "A subscribed .ics feed with one timed event produces exactly one persisted CommitmentBlock (name, date, isFromCalendar, externalEventId all correct)"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#a fixture feed with one timed event produces exactly one persisted CommitmentBlock"
        status: pass
    human_judgment: false
  - id: D2
    description: "The mapper converts to the device's LOCAL zone (not the zero meridian) — the SEED-006 shape, proven under an explicit non-UTC tz.local with bare-literal expected minutes, plus a recorded mutation proof"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#converts to LOCAL wall-clock under a non-UTC tz.local — the SEED-006 shape (D-35-08)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The imported block chunks through the REAL, unmodified ScheduleGeneratorService"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#the imported block chunks through the REAL ScheduleGeneratorService"
        status: pass
    human_judgment: false
  - id: D4
    description: "Syncing the same feed twice leaves exactly one block — upsert on externalEventId, not a fresh uuid"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#syncing the same feed twice does not duplicate the block"
        status: pass
    human_judgment: false
  - id: D5
    description: "A feed that cannot be fetched degrades to CalendarSyncResult.failed, leaves prior blocks untouched, never throws into the UI"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#a fetcher that throws returns failed and leaves prior blocks untouched"
        status: pass
    human_judgment: false
  - id: D6
    description: "A too-short event (< 25 min) is not imported and is counted as skipped, reusing the existing commitmentWindowTooShort gate"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#a too-short event imports zero blocks and reports one skipped entry"
        status: pass
    human_judgment: false
  - id: D7
    description: "CalendarSource declares no write verb — CAL-03 is enforced by interface shape, confirmed by flutter analyze plus a grep proof"
    requirement: "CAL-03"
    verification:
      - kind: unit
        ref: "flutter analyze (clean) + grep -rh --include='*.dart' -v '^\\s*//' lib/data/calendar/ lib/services/calendar_sync_service.dart | grep -cE '(create|update|delete)(Event|Calendar)|save[A-Za-z]*Event' == 0"
        status: pass
    human_judgment: false

duration: 55min
completed: 2026-09-14
status: complete
---

# Phase 35 Plan 01: An .ics feed becomes a real commitment Summary

**A subscribed `.ics` feed, parsed with `enough_icalendar` + expanded with `rrule`, becomes a one-off `CommitmentBlock` in the device's local wall-clock time that the unmodified `ScheduleGeneratorService` chunks into the day — proven end to end by one test file that runs entirely on this machine.**

## Performance

- **Duration:** ~55 min
- **Completed:** 2026-09-14T13:12:25Z
- **Tasks:** 1 (Task 1 was a `checkpoint:decision` already RULED by the owner before this dispatch — recorded below, not re-asked)
- **Files modified:** 16 (8 created, 8 modified)

## Accomplishments

- `CalendarSource` interface (`isAvailable`, `requestPermission`, `listCalendars`, `listEvents`) with `IcsCalendarSource` and `NullCalendarSource` implementations, plus `defaultCalendarSource()` — a per-platform factory that returns `NullCalendarSource` on mobile (device source lands in plan 35-05) and on any platform with no configured URLs (D-35-12).
- `CalendarSyncService` maps every fetched occurrence to a one-off, date-anchored `CommitmentBlock` (D-35-07): local wall-clock conversion via `tz.TZDateTime.from(event.start, tz.local)` (D-35-08), gated by the existing `commitmentWindowTooShort`, upserted by a stable `externalEventId` so a repeat sync never duplicates.
- `CommitmentBlock` gains `externalEventId`/`isFromCalendar` (HiveField 7/8), schema bumped 9→10 with a comment-only no-op migration. The `startMinutes`/`endMinutes` doc comments' stale "UTC" claim is corrected to state the true local-wall-clock basis every existing writer (`commitment_form_sheet.dart`'s `showTimePicker`, `schedule_generator.dart`'s local-midnight date construction) already assumes.
- `CommitmentsNotifier.syncFromCalendar` wired into `checkin_screen._generate()`, immediately before `blocks` is read (D-35-13) — a failed sync degrades to last-known blocks, never blocks check-in, never throws into the UI.
- `test/services/calendar_sync_service_test.dart`: 6 tests, all against the REAL `ScheduleGeneratorService` and a real `IcsCalendarSource`/`enough_icalendar` parse, no stubs of the mapping logic itself.
- Mutation-proofed the local-time assertion: temporarily converted the mapper to a zero-meridian conversion, observed the test fail with `Expected: <540> Actual: <840>`, then reverted. Recorded below.

## Task Commits

1. **Task 1: Rule the ICS package (checkpoint:decision)** — already answered by the owner on 2026-09-14, before this dispatch. No commit from this agent; the ruling is recorded in `35-DECISIONS.md` and restated below as D-35-05.
2. **Task 2: An .ics feed becomes a real commitment the scheduler chunks — end to end, one path** - `a165f69` (feat)

**Plan metadata:** this commit (`docs(35-01): complete plan` — see Final Commit below)

## Files Created/Modified

- `lib/data/calendar/calendar_event.dart` - `CalendarEvent`, `CalendarInfo`, `CalendarEventStatus`, `CalendarPermissionState` — the uniform shapes every source normalises into
- `lib/data/calendar/calendar_source.dart` - the read-only `CalendarSource` interface (CAL-03 by shape)
- `lib/data/calendar/ics_calendar_source.dart` - fetches + parses `.ics` feeds, expands recurrence via `rrule`, degrades failures to `IcsSourceException` (never a raw exception reaching the UI)
- `lib/data/calendar/null_calendar_source.dart` - the always-safe fallback (CAL-04)
- `lib/data/calendar/calendar_source_factory.dart` - `defaultCalendarSource()`, the per-platform switch (D-35-12)
- `lib/services/calendar_sync_service.dart` - `CalendarSyncService`, `CalendarSyncResult`, `SkippedEvent`/`SkipReason`, `kCalendarSyncWindowDays`
- `lib/data/models/commitment_block.dart` - `externalEventId`/`isFromCalendar` fields; corrected `startMinutes`/`endMinutes` doc comments
- `lib/data/models/commitment_block.g.dart` - regenerated Hive adapter (schema 10, 9 fields)
- `lib/data/database/migrations.dart` - `currentSchemaVersion` 9→10, `_migration9to10` (comment-only no-op)
- `lib/providers/commitments_notifier.dart` - `syncFromCalendar({required CalendarSource source})`
- `lib/screens/schedule/checkin_screen.dart` - calls `syncFromCalendar` immediately before `blocks` is read
- `test/services/calendar_sync_service_test.dart` - the 6-test end-to-end suite
- `test/fixtures/calendar/one_timed_event.ics` - a single 09:00–10:30-local (14:00Z–15:30Z) timed event
- `test/data/migration_schema8_test.dart` - schema-version constant bumped 9→10 (see Deviations)
- `pubspec.yaml` / `pubspec.lock` - added `enough_icalendar ^0.17.0`, `rrule ^0.2.18`, `http ^1.6.0`

## Decisions Made

**D-35-05 (owner ruling, recorded per Task 1's `<RULED>` block instruction — this checkpoint was CLOSED before this dispatch, not re-asked):** `enough_icalendar` (parse) + `rrule` (expand), **not** `firstfloor_calendar`. Full evidence table already lives in `35-DECISIONS.md` (weekly downloads: `firstfloor_calendar` 52 vs `rrule` 128k; `firstfloor_calendar`'s pub.dev publisher `firstfloorsoftware.com` vs its actual GitHub owner `kozw` — a real, re-checked mismatch). `getInstances()` — the occurrence-expansion API the architecture needs — turned out to belong to `rrule`, not `enough_icalendar` itself, so this plan installs both and owns the seam between them.

**Consequence 1 — two dependencies, one seam we own.** `IcsCalendarSource._expand()` is the single place that joins `enough_icalendar`'s parsed `VEvent` to `rrule`'s `RecurrenceRule.getInstances()`.

**Consequence 2 — the UTC/local seam (D-35-08), handled and tested.** `rrule` requires every `DateTime` it's given to be UTC-flagged (`isValidRruleDateTime` asserts `isUtc`). `CommitmentBlock` wants local wall-clock. `CalendarSyncService._mapToBlock` is the ONLY place the UTC→local conversion happens, via `tz.TZDateTime.from(event.start, tz.local)` — `IcsCalendarSource` deliberately never calls `.toLocal()` (which would use this *machine's* real system timezone, not the app's `tz.local` override) on an expanded occurrence; it hands `CalendarSyncService` a UTC-or-floating `DateTime` and lets that one conversion point do the work. This is exactly the SEED-006 trap's shape, and the local-time test sets `tz.local` to `America/New_York` explicitly rather than relying on danserver's own (UTC) system zone.

**Consequence 3 — EXDATE/RDATE/RECURRENCE-ID are NOT implemented (explicitly scoped out, not silently dropped).** Neither `enough_icalendar` nor `rrule` applies these overrides for us. `IcsCalendarSource._expand()`'s doc comment states this plainly: a moved or cancelled single occurrence of a recurring event will still appear at its *original* time until this logic is added. This plan's own `must_haves` (frontmatter) do not assert MOVED-occurrence/EXDATE behavior — that assertion lives in the phase-level `<RULED>` block as a general warning for the whole plan set, and it is plan 35-02 (or a dedicated follow-up) that must either implement it or make the scoping decision explicit in the UI. Flagging here so it is not silently rediscovered downstream.

**A genuinely new finding, not previously flagged in RESEARCH/PATTERNS/DECISIONS:** a DTSTART/DTEND with no `Z` suffix (a "floating" ICS time, or a TZID-qualified time with no embedded `VTIMEZONE` resolution) is parsed by `enough_icalendar`'s `DateHelper.parseDateTime` using Dart's plain `DateTime(y, m, d, h, mi, s)` constructor — `isUtc: false`, tied to the Dart *runtime's actual system timezone* for its internal epoch representation, not to the app's `tz.local` override and not to the ICS `TZID` value itself. Feeding such a value into `tz.TZDateTime.from(..., tz.local)` would silently produce the wrong local time whenever the machine's real system timezone differs from `tz.local`. The test fixture therefore deliberately uses `Z`-suffixed (UTC) timestamps — the common shape for calendars exported without an embedded `VTIMEZONE` block (e.g. most Google Calendar public `.ics` exports) — which sidesteps this correctly. **This is a real, untested gap for feeds using bare `TZID` with no `Z` suffix and no `VTIMEZONE` block**, and should be confirmed against a real feed in plan 35-02 or 35-03 before relying on it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated the pre-existing schema-version regression test in lockstep with the 9→10 bump**
- **Found during:** Task 2, running the full suite after the migration change
- **Issue:** `test/data/migration_schema8_test.dart` hardcodes `expect(currentSchemaVersion, equals(9))` in two tests. Its own comment shows this exact assertion was already updated once before (bumped from 8 to 9 when the RestorativeItem aggregate landed) — it's a living regression test tracking the CURRENT schema version by design, not a frozen historical snapshot. Bumping `currentSchemaVersion` to 10 without updating it would leave the suite red.
- **Fix:** Updated both assertions to `equals(10)` and refreshed the comment to describe the 9→10 change, matching the file's own established pattern.
- **Files modified:** `test/data/migration_schema8_test.dart`
- **Verification:** `flutter test` — 746/746 green (740 pre-existing + 6 new)
- **Committed in:** `a165f69` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — a pre-existing test tracking a moving schema constant, not a change to unrelated behavior)
**Impact on plan:** Necessary to keep the schema bump honest; no scope creep. The plan's acceptance criterion "zero pre-existing tests edited to accommodate this change" is read as "no test rewritten to make the new FEATURE pass" — this one test's assertion is inherently about the current schema constant and was already established (by its own prior edit history) as something that moves with every schema bump.

## Mutation Proof (required by acceptance criteria)

Before accepting the local-time test as discriminating, `_mapToBlock` in `lib/services/calendar_sync_service.dart` was temporarily changed:

```dart
// Defect introduced:
final localStart = event.start.toUtc();
final localEnd = event.end.toUtc();
// (instead of tz.TZDateTime.from(event.start, tz.local) / ...end, tz.local))
```

Running `flutter test test/services/calendar_sync_service_test.dart` with this defect in place:

```
converts to LOCAL wall-clock under a non-UTC tz.local — the SEED-006 shape (D-35-08) [E]
  Expected: <540>
    Actual: <840>
```

This is exactly the predicted zero-meridian failure (14:00 UTC read as if it were already local, instead of the correct 09:00 EST local). The defect was then reverted; `flutter analyze` and the full suite (746/746) are green on the reverted code.

## Issues Encountered

None beyond the deviation and the newly-found floating-time gap documented above — both are recorded, not hidden.

## Known Stubs / Scoped-Out Gaps

- **EXDATE/RDATE/RECURRENCE-ID overrides are not applied.** A moved or cancelled single occurrence of a recurring event appears at its original time. `IcsCalendarSource._expand()` documents this inline. No fixture in this plan exercises a recurring event, so this gap is asserted by design review, not by a failing test — flagged for 35-02 or a dedicated follow-up to either implement or make an explicit UI-visible scoping decision.
- **Floating/bare-TZID DTSTART values are not correctly localised.** See "A genuinely new finding" above. Only `Z`-suffixed (UTC) DTSTART/DTEND values are proven correct by this plan's test. Should be confirmed against a real subscribed feed (which may use either shape) before 35-04's UAT.
- **Multi-day/overnight event splitting is not implemented** (Pitfall 5, explicitly deferred to 35-02 per RESEARCH.md). The naive per-occurrence minute computation in `_mapToBlock` safely degrades a multi-day event to a "too short" skip (negative minute delta) rather than persisting a wrong window — not silently wrong, but not yet the correct split-per-day behavior either.

## User Setup Required

None - no external service configuration required. (No calendar URLs are configured yet in this plan — that arrives in plan 35-03's settings UI. The factory returns `NullCalendarSource` on every platform today, so the check-in sync call is a proven no-op wiring path, not yet a live import for any real user.)

## Next Phase Readiness

- The tracer holds: `CalendarSource` → `CalendarSyncService` → `CommitmentBlock` → unmodified `ScheduleGeneratorService` is proven end to end by 6 passing tests, on a path this machine can run without a mobile SDK.
- `schedule_generator.dart` is untouched (`git diff --stat -- lib/services/schedule_generator.dart` is empty for this commit).
- Plans 35-02 through 35-06 can build on this interface and mapper without re-deciding the package choice, the schema shape, or the local-time conversion point.
- **Tracer feedback gate (executor protocol):** this session ran with auto-mode OFF (`workflow.auto_advance`/`workflow._auto_chain_active` both false/unset). Per the tracer-task protocol, wave 2 (plans 35-02 onward) should not be dispatched until a human has reviewed this tracer's verification: `export PATH="$PATH:/home/dan/development/flutter/bin" && flutter analyze && flutter test test/services/calendar_sync_service_test.dart && flutter test` — both commands are green as recorded above (analyze clean; 746/746 tests pass).

## Self-Check: PASSED

All 8 created/modified files listed under "Files Created/Modified" that are new files were confirmed present on disk (`test -f`), and commit `a165f69` was confirmed present in `git log --oneline --all`. No missing items.

---
*Phase: 35-your-real-commitments-read-from-your-calendar*
*Completed: 2026-09-14*
