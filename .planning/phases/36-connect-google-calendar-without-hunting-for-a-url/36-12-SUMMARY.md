---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 12
subsystem: calendar-sync
tags: [calendar, sync, prune, destructive, WINDOWS-11, CAL-02]
requires: []
provides:
  - "CalendarSyncService.sync() selection prune (opt-in configuredCalendarIds) and event prune"
  - "CompositeCalendarSource.listEventsByChild (per-child success signal)"
  - "calendarIdHash(), Google/ICS configuredCalendarIds getters"
affects: [36-15, 36-17]
tech-stack:
  added: []
  patterns: ["default-deny by concrete type", "per-prune isFromCalendar guard", "ID-set assertions, never counts"]
key-files:
  created:
    - test/services/calendar_sync_uninitialised_tz_test.dart
  modified:
    - lib/services/calendar_sync_service.dart
    - lib/providers/commitments_notifier.dart
    - lib/data/calendar/composite_calendar_source.dart
    - lib/data/calendar/google_calendar_source.dart
    - lib/data/calendar/ics_calendar_source.dart
    - test/services/calendar_sync_service_test.dart
    - test/data/calendar/composite_calendar_source_test.dart
key-decisions:
  - "Selection prune runs on the failed-fetch path too, best-effort (a repository error there is swallowed so a failed sync never throws)."
  - "Each prune carries its own explicit isFromCalendar guard rather than sharing one helper, so each is independently mutation-provable."
  - "Event-prune window computation returns null (no event prune) when tz.local cannot be read."
requirements-completed: [CAL-02]
duration: ~1h30m
completed: 2026-11-02
status: complete
commits: 3
plan_head_before: 035cbf25fc0719bd8a9989c435589f95df4440f1
plan_head_after: de9390d891c10ad87e94d57c89d8c17e1f792794
actuals:
  tokens: 15000
  tasks: 3
  commits: 3
---

# Phase 36 Plan 12: Prune stale imported blocks (WINDOWS entry 11) Summary

`CalendarSyncService.sync()` now deletes stale imported commitment blocks: those of an unticked calendar (selection prune, no fetch needed) and those of a deleted or cancelled event (event prune, only from a source that verifiably answered, only on days the fetch fully covered).

## Tasks

| # | Task | Commit |
|---|------|--------|
| 1 (tracer) | Selection prune + `calendarIdHash` + notifier plumbing; owner's Home -> spunkl switch driven through `CommitmentsNotifier.syncFromCalendar` and a real `DeviceCalendarSource` | 40237be |
| 2 | `CompositeCalendarSource.listEventsByChild`; read-only `configuredCalendarIds` on Google and ICS sources | 2567b62 |
| 3 | Event prune (succeeded-children only, default-deny by type, strictly-inside-window days) | de9390d |

Tracer gate: the Task 1 `<verify>` suite was green end to end (28/28 in that file) before Tasks 2-3 expanded on it.

## Final state

- `flutter test`: **962 passed, 0 failed** (baseline 934; +28).
- `flutter analyze`: **No issues found!**
- `git diff 8f62a56 -- lib/services/schedule_generator.dart`: **empty** (0 bytes).
- `test/data/calendar/google_calendar_source_test.dart`: byte-identical to df106fe (`git diff --quiet df106fe -- ...` exit 0). The four-verb structural test passed unedited.
- `grep -vE "^\s*//" lib/services/calendar_sync_service.dart | grep -c "_repository.delete("`: 1 (baseline 0).
- `CalendarSource` interface: untouched.

## Mutation proofs (all RUNTIME failures, all reverted; `diff` against the pre-mutation copy printed `identical` each time)

Survivors are asserted by block id throughout. Real failure text, trimmed only of stack frames and uuid noise where noted.

**Task 1 (a) — drop `isFromCalendar` from the selection prune.** Only the impostor fixture failed:
```
a block with isFromCalendar == false that carries a well-formed ics:<hash-of-home>: id survives ... [E]
  Expected: Set:['6c88cdeb-...', 'hand-1', 'impostor-1']
    Actual: Set:['hand-1', '6c88cdeb-...']
     Which: does not contain 'impostor-1'
```

**Task 1 (b) — skip hash membership (prune every imported block not produced this sync).**
```
a spunkl block that sync #2 did not produce (its event has left the window) survives ... [E]
  Expected: Set:['1a1a20aa-...', 'hand-1']
    Actual: Set:['hand-1']
     Which: does not contain '1a1a20aa-...'
a fetch that throws still runs the selection prune ... [E]
  Expected: Set:['3c651163-...', 'hand-1']
    Actual: Set:['hand-1']
```

**Task 1 (c) — drop the "not written by this sync" exclusion.**
```
a block written by the CURRENT sync is never deleted, even when its calendar is absent from configuredCalendarIds [E]
  Expected: Set:['26f71c27-...', 'hand-1']
    Actual: Set:['hand-1']
     Which: does not contain '26f71c27-...'
```

**Task 1 extra — remove the failed-path repository guard** (`catch` narrowed to `on ArgumentError`):
```
a failed fetch whose selection prune hits a repository error still returns failed rather than throwing (D-35-13) [E]
  Bad state: hive unavailable
```

**Task 2 — `listEventsByChild` appends every child to `succeeded` regardless of outcome.** Three tests failed, including one pre-existing:
```
every child throws: the exception propagates ... [E]
  Expected: throws <Instance of 'Exception'>
    Actual: <Closure: () => Future<List<CalendarEvent>>>
     Which: returned a Future that emitted []
first child throws, second returns events: ... `succeeded` is exactly that child instance [E]
  Expected: an object with length of <1>
    Actual: [Instance of '_FakeCalendarSource', Instance of '_FakeCalendarSource']
     Which: has length of <2>
every child throws: rethrows, as listEvents always has [E]
  Expected: throws <Instance of 'Exception'>
     Which: returned a Future that emitted (events: [], succeeded: [Instance of '_FakeCalendarSource', Instance of '_FakeCalendarSource'])
```

**Task 3 (a) — treat every child as succeeded** (`succeeded = source.children`):
```
a google:x block on a covered day survives — the Google child failed, so absence proves nothing [E]
  Expected: contains 'google-mar2'
    Actual: Set:[ ... ]   Which: does not contain 'google-mar2'
```

**Task 3 (b) — drop the "strictly after today" bound.**
```
a block dated TODAY (or earlier) whose event is not returned survives — today is never event-pruned [E]
  Expected: contains 'today-mar1'
    Actual: Set:['hand-1', 'lastday-mar15', 'seed-kept', 'google-mar2', 'impostor-mar2']
     Which: does not contain 'today-mar1'
```
(also tripped the Task 1 "event has left the window" survivor, a free second witness.)

**Task 3 (c) — unknown-type branch returns the fetched events' calendar ids instead of empty.** Run against the pre-tz-guard shape (three-point edit passing `events` into `_verifiedCalendarHashes`):
```
a source type outside the three known classes is default-deny: its calendar's stale block survives even though that source succeeded [E]
  Expected: contains 'stale-fake'
    Actual: Set:['5b17daa6-...']
     Which: does not contain 'stale-fake'
```
After the later refactor (below) the same arm was re-mutated in a simpler form (`_ => const <String>['fake-cal']`) and failed the same test the same way (`Expected: contains 'stale-fake'`).

**Task 3 (d) — drop "strictly before window end".**
```
a block on the local date of windowEnd survives — the last day is only partially covered [E]
  Expected: contains 'lastday-mar15'
    Actual: Set:[ ... ]   Which: does not contain 'lastday-mar15'
```

**Task 3 (e) — drop `isFromCalendar` from the EVENT prune only** (selection prune's guard left in place):
```
a block with isFromCalendar == false carrying a well-formed ics:<hash-of-spunkl>: id, dated tomorrow, on the verified calendar and absent from the fetch, survives — the isFromCalendar guard is the ONLY thing protecting it [E]
  Expected: contains 'impostor-mar2'
    Actual: Set:['hand-1','today-mar1','past-feb28','lastday-mar15','seed-kept','google-mar2']
     Which: does not contain 'impostor-mar2'
```

**tz guard (added, see deviations)** — `catch` narrowed to `on FormatException` so the guard no longer fires:
```
LateInitializationError: Field '_local@83310200' has not been initialized.
  package:canopy/services/calendar_sync_service.dart 346:62  CalendarSyncService._eventPruneWindow
  package:canopy/services/calendar_sync_service.dart 265:19  CalendarSyncService.sync
```

Mutations (a), (b), (d) and the (c) variant were re-run against the FINAL code after the refactor; (e) and Task 1's mutations touch lines the refactor did not move.

## Accepted costs and residuals (recorded as the plan required)

- **Today-cost:** an event deleted *today* keeps its block for the rest of today. EventKit's partial-overlap semantics for an event that already ended this morning are unverified on hardware, so today is never event-pruned. Also documented in the class doc comment.
- **Window's last day** is never event-pruned (only partially fetched). Net covered days: strictly after today, strictly before the window-end local date.
- **Post-Disconnect Google residual (for 36-17 to log):** after Google Disconnect, `google:` ids remain in `selectedCalendarIds` (the Disconnect dialog promises imported commitments stay), and the Google child fails without a token. Those blocks are therefore neither selection-pruned (still "configured") nor event-pruned (child failed), and have no in-app removal path until the user reconnects and unticks. This is the Disconnect dialog's own promise; not reversed here.
- **The selection prune is inert in the shipped app until 36-15.** `configuredCalendarIds` is opt-in and neither caller passes it yet (per plan). The **event prune is live as soon as this merges.**

## Deviations from Plan

**1. [Rule 1 - Bug, found by the full suite] `tz.local` read in `sync()` broke three existing tests.**
- First cut computed the local sync-start / window-end dates unconditionally on the success path, copying `_mapEvent`'s `tz.TZDateTime.from(..., tz.local)`. But `tz.local` is a `late` field that is *never initialised* where nothing calls `setLocalLocation` — and the old `sync()` never touched it for a zero-event answer. Three pre-existing tests failed with `LateInitializationError` (`null_calendar_source_test`, `checkin_screen_widget_test`, `cold_launch_morning_loop_test`). The plan's Task 3 said "compute exactly as `_mapEvent` does" and did not foresee this.
- Fix: a private `_eventPruneWindow` that returns null (no event prune, i.e. default-deny) when no calendar is verified, and also when `tz.local` cannot be read. New dedicated file `test/services/calendar_sync_uninitialised_tz_test.dart` (its own isolate, never touches timezones) proves a zero-event verified-source sync neither throws nor deletes; mutation-proven above.
- **Observation, not verified:** `NotificationService.initialize` returns before `tz.initializeTimeZones()` on web, so `tz.local` appears uninitialised on web builds; this guard keeps zero-event web syncs working. Whether the pre-existing `_mapEvent` path works on web at all with real events was not examined.

**2. [Rule 2 - correctness] Failed-path selection prune is best-effort.** `sync()`'s failed path previously could not throw (D-35-13). Reading the repository there could. The prune is wrapped so a repository error leaves stale blocks in place and still returns `failed: true`. Test + mutation above. Not in the plan.

**3. Per-prune `isFromCalendar` guard instead of one shared gate.** The plan wants mutation (e) to drop the guard "from the event prune, leave the selection prune's untouched". A shared helper would make (a) and (e) the same line. I kept an id-shape-only helper and put an explicit guard in each loop.

**4. Test-authoring corrections (mine, not the code's).** My first "event has left the window" test advanced the clock 3 days, which left the 5 March event still inside the window, so it failed for the wrong reason; changed to 10 days. And the plan's Task 1 mutation (c) is only meaningful for a block that already exists before the sync (the prune iterates a pre-upsert snapshot), so that test runs sync #1 first and rewrites the block in sync #2.

**5. Added beyond the plan's behaviour list:** positive-path tests for the ICS and Google arms of the verified-set switch (otherwise deleting either arm would go unnoticed), a "past dates are never event-pruned" assertion, a malformed-id table (`null`, legacy, short/upper/long hash), and the all-children-fail composite test. `_DeviceSeam` is a new double (filters by calendar id and window like the real plugin) rather than reusing the mapping test's private `_RecordingEventsFetcher`, which is private to that file.

**6. Formatting hygiene.** `dart format` over a directory reformatted unrelated files (`goals_notifier.dart`, `settings_notifier.dart`) and pre-existing lines in two test files and `ics_calendar_source.dart`. I reverted all of that; the final diff against base is additions only in the test files and no unrelated lines changed. Task 1's commit was amended once for this before Task 2 began.

**Weakened tests:** none. No pre-existing test or assertion was edited or deleted; `google_calendar_source_test.dart` is untouched.

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat model. T-36-44 .. T-36-47 are mitigated and mutation-proven as above; this plan adds the first code path in the app that deletes user-visible rows, which is exactly what T-36-44/45/46 cover.

## Self-Check: PASSED

- Files present: `lib/services/calendar_sync_service.dart`, `lib/data/calendar/composite_calendar_source.dart`, `test/services/calendar_sync_uninitialised_tz_test.dart`, this SUMMARY.
- Commits present on HEAD: 40237be, 2567b62, de9390d.
- `flutter test` 962/962, `flutter analyze` clean, `schedule_generator.dart` diff against 8f62a56 empty.
