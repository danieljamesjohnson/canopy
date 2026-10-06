---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 09
subsystem: calendar-sync
tags: [hive, hive_ce, flutter, calendar, migration, material3]

requires:
  - phase: 36-connect-google-calendar-without-hunting-for-a-url
    provides: "plan 36-08's merged fix (device/Google calendar ticks actually reach the respective sources)"
provides:
  - "An all-day calendar event is never imported as a blocking commitment — it is always skipped and disclosed (D-36-05, supersedes D-35-06)"
  - "A one-time schema 12->13 migration that discards every previously-imported calendar block, since sync() never prunes and the pre-fix imported set is untrustworthy on both axes this and 36-08 changed"
  - "The skipped-events disclosure promoted to the top of the Calendars screen, above both calendar sections, in a neutral card"
affects: [36-11-verification, calendar-settings-screen, calendar-sync-service, hive-migrations]

actuals:
  tokens: 8937
  tasks: 3
  commits: 3
  plan_head_before: 46cddf051848378c89e872bdc8d77bbf31611876
  plan_head_after: b3051b8484d4f5cc9c10b2fab9afc75ff6c476f1

tech-stack:
  added: []
  patterns:
    - "Destructive one-time Hive migration as a pure function taking the repository as a parameter (purgeImportedCalendarBlocks), following the mapDeviceEvent/mapGoogleEvent pure-function-plus-thin-adapter split"
    - "Mutation-proof isolation: when two assertions guard the same code path and the first would mask the second's failure, temporarily comment out the first to observe the second fail on its own, then revert both"

key-files:
  created:
    - test/data/migration_schema13_test.dart
  modified:
    - lib/services/calendar_sync_service.dart
    - lib/data/database/migrations.dart
    - lib/screens/settings/calendar_settings_screen.dart
    - test/services/calendar_sync_service_test.dart
    - test/data/migration_schema_test.dart
    - test/screens/settings/calendar_settings_screen_test.dart

key-decisions:
  - "D-36-05 implemented exactly as ruled: allDay is now a SkipReason member; the branch returns (blocks: const [], skip: SkipReason.allDay); schedule_generator.dart untouched (byte-identical, verified by empty git diff)"
  - "The locked UI-SPEC string 'All-day — not imported automatically' (35-UI-SPEC.md Copywriting Contract, 'Skipped-event reason strings' row, Pitfall 6) was reused verbatim — no new copy authored, no checkpoint raised"
  - "The migration purges ALL isFromCalendar==true blocks, not just all-day-shaped ones, because the pre-fix imported set is untrustworthy on both the which-calendars (36-08) and which-events (this plan) axes — a shape sweep could never reach blocks from calendars 36-08 stops querying entirely"
  - "Accepted cost (T-36-37, disposition accept): one post-upgrade offline check-in has no last-known imported blocks to degrade to (D-35-13 weakened for that single window); remedy is one successful sync, to be made mandatory in 36-11's UAT"

patterns-established:
  - "A destructive migration's doc comment states WHY in full (WINDOWS entries, the untrustworthy-data reasoning, the accepted cost) because a reader who reverts an unexplained destructive migration is a realistic failure mode"

requirements-completed: [D-36-05, CAL-04]

coverage:
  - id: D1
    description: "An all-day calendar event imports zero blocks and is reported as one skipped entry with reason SkipReason.allDay, rendering the locked 'All-day — not imported automatically' string"
    requirement: "D-36-05"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#an all-day event imports zero blocks and is skipped and disclosed (D-36-05 RULED — supersedes D-35-06 import-as-blocking)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A one-time schema 12->13 migration purges every calendar-imported CommitmentBlock while leaving every hand-entered block untouched, asserted by surviving id (not count)"
    requirement: "D-36-05"
    verification:
      - kind: unit
        ref: "test/data/migration_schema13_test.dart#deletes exactly the 3 calendar-imported blocks and leaves both hand-entered blocks present, identified by id"
        status: pass
      - kind: unit
        ref: "test/data/migration_schema13_test.dart#an imported block is purged, a hand-entered block survives by id, and the persisted schemaVersion reads 13"
        status: pass
    human_judgment: false
  - id: D3
    description: "The skipped-events disclosure renders above both calendar sections (mobile: above the Google CTA; desktop: above the ICS list), unchanged wording, exactly once, never in the error color role"
    requirement: "CAL-04"
    verification:
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#the disclosure renders ABOVE the Google section's \"Connect Google Calendar\" button on the mobile branch, proven by comparing rendered y-offsets, not widget order in source"
        status: pass
      - kind: unit
        ref: "test/screens/settings/calendar_settings_screen_test.dart#the disclosure appears exactly once on screen — moved, not duplicated"
        status: pass
    human_judgment: true
    rationale: "The owner's original complaint (D-36-05/entry 10) was a perceptual judgment made on a real device — he did not notice the disclosure even though it existed and was tested. A widget test proving geometric position cannot by itself confirm a human will notice the banner on a real phone; 36-11's device UAT is the gate for that judgment, consistent with this project's own CLAUDE.md precedent for perceptual claims (D-36-03's overlap warning)."

duration: 55min
completed: 2026-10-06
status: complete
---

# Phase 36 Plan 09: All-day events skipped-and-disclosed + one-time import cleanup + disclosure promoted to top Summary

**D-36-05 implemented (all-day calendar entries skip-and-disclose instead of blocking the whole working day), a schema 12->13 migration purges every stale imported CommitmentBlock from the pre-fix sync, and the skipped-events disclosure moved from the bottom of the Calendars screen to a neutral card at the top (WINDOWS entries 7/8/10 closed by this plan's code).**

## Performance

- **Duration:** ~55 min
- **Tasks:** 3/3
- **Files modified:** 7 (1 created, 6 modified)

## Accomplishments

- `SkipReason.allDay` added; `CalendarSyncService._mapEvent`'s all-day branch now returns `(blocks: const [], skip: SkipReason.allDay)` instead of building a block spanning `dayStartMinutes..dayEndMinutes`. The now-unused `schedule_generator.dart` import was removed from the sync service entirely — the file itself is byte-identical (`git diff 8f62a56 -- lib/services/schedule_generator.dart` is empty).
- Every doc comment that asserted the now-superseded D-35-06 ruling (the enum, the label extension, the class doc comment's mapping-rules list, `_mapEvent`'s own doc comment) was rewritten to state D-36-05 and its device evidence, rather than left standing beside contradicting code.
- A one-time Hive schema 12->13 migration (`purgeImportedCalendarBlocks` + `_migration12to13`) discards every `isFromCalendar == true` block on upgrade, so the six fake blocks already on the owner's device (and any other pre-fix imported data) are gone the moment he upgrades, without him doing anything but syncing once afterward.
- The skipped-events disclosure was extracted out of the footer into its own `_skippedBanner` method and promoted to the first child of both the mobile and desktop screen bodies — rendered above the Google section/ICS list respectively, in a neutral outlined card (never the error color role), with its locked wording completely unchanged.

## Task Commits

1. **Task 1: All-day events are skipped and disclosed, never imported (D-36-05)** - `19c28d5` (fix)
2. **Task 2: One-time cleanup — the already-persisted imported blocks are discarded and re-derived** - `22e32d3` (fix)
3. **Task 3: The skipped-events disclosure moves to the top of the Calendars screen and gains weight** - `b3051b8` (fix)

_No separate plan-metadata commit — this SUMMARY and any STATE.md/ROADMAP.md updates are committed by the orchestrator after the wave completes, per this run's instructions._

## Files Created/Modified

- `lib/services/calendar_sync_service.dart` — `SkipReason.allDay` added; all-day branch skips instead of blocking; doc comments rewritten; unused `schedule_generator.dart` import removed
- `lib/data/database/migrations.dart` — `currentSchemaVersion` 12->13; `purgeImportedCalendarBlocks` + `_migration12to13` added
- `lib/screens/settings/calendar_settings_screen.dart` — `_skippedBanner` extracted from `_footer`, rendered first in both bodies
- `test/services/calendar_sync_service_test.dart` — all-day test rewritten for the new (skip) behavior
- `test/data/migration_schema13_test.dart` — new; pure-function + real-Hive round-trip tests for the migration
- `test/data/migration_schema_test.dart` — `currentSchemaVersion` assertions bumped to 13
- `test/screens/settings/calendar_settings_screen_test.dart` — two new tests (geometric position, no-duplication) for the relocated banner

## Mutation Proofs (real runtime failures, all reverted)

**Task 1 — restored the old block-building branch (kept `SkipReason.allDay` declared, so this stayed a runtime failure, not a compile error):**

```
Expected: empty
  Actual: [Instance of 'CommitmentBlock']
```

**Task 2 — removed the `isFromCalendar` predicate from `purgeImportedCalendarBlocks`.** The deleted-count assertion caught it first (`Expected: <3> / Actual: <5>`), which by itself doesn't prove the SURVIVING-ID assertion discriminates — so the count assertion was temporarily commented out in isolation to observe the id assertion fail on its own, confirming it is the one that actually catches the data-loss case:

```
Expected: Set:['51eedf78-...', '5f907edc-...']
  Actual: Set:[]
   Which: does not contain '51eedf78-...'
only the two hand-entered blocks must survive, identified by id — not by count alone
```

Both the migration code and the temporary test isolation were reverted immediately after observing the failure.

**Task 3 — moved `_skippedBanner(context)` to the end of `_buildMobileBody`'s children, below the device section:**

```
Expected: a value less than <402.0>
  Actual: <608.0>
   Which: is not a value less than <402.0>
the disclosure must render above the Google section — banner dy=608.0, Google CTA dy=402.0
```

## Decisions Made

- **D-36-05 is fully implemented per the ruling text** — see `key-decisions` in frontmatter. Nothing here re-litigates the 10-vs-14-hour span question D-36-05 explicitly closed by removing the behavior.
- **Copy verification:** the shipped string is `'All-day — not imported automatically'`. The locked row in `35-UI-SPEC.md` (line ~160, Copywriting Contract, "Skipped-event reason strings," Pitfall 6) reads: `"Too short to schedule" (Pitfall 4) · "All-day — not imported automatically" (Pitfall 6) · "Cancelled"`. Byte-identical; verbatim reuse, no new copy authored.
- **`SkipReasonLabel`'s doc comment rewritten** — it no longer claims "No `allDay` case exists here because it is not a `SkipReason` member (D-35-06)"; it now states the string was locked in Phase 35 for exactly this behavior and orphaned when D-35-06 initially declined it, and that D-36-05 adopts the behavior the string was always written for.
- **The migration purges ALL imported blocks, not a shape-matching subset** — see `key-decisions`. This matches the plan's explicit reasoning and was not deviated from.
- **D3's coverage entry is marked `human_judgment: true`** despite having passing automated tests, because the defect this closes (WINDOWS entry 10) was itself a perceptual "owner didn't notice it" finding on a real device — a widget test proving geometric position is necessary but not sufficient evidence that a human will actually notice the banner. 36-11's device UAT is where that judgment belongs.

## Deviations from Plan

None — the plan was followed exactly as written, including its explicit instruction NOT to re-litigate D-35-06's span question and NOT to invent new copy.

### Findings recorded for 36-11 (not fixed here, by design)

**The no-prune defect (entry 11, to be logged by plan 36-11 per this plan's own instructions).** `CalendarSyncService.sync()` never prunes — verified three independent ways during Task 2: (1) `sync()` (lines ~149-176, now shifted slightly by Task 1's edits) calls `_repository.getAll()` and only ever `_repository.save(block)`, no `delete` call anywhere in the method or in `_mapEvent`; (2) `grep -rn '\.delete(' lib/` returns exactly four call sites — `restoratives_notifier`, `schedule_notifier` (×2, re-anchoring), and the user-initiated `commitments_notifier.removeBlock` — none in the calendar path; (3) `calendar_settings_screen.dart`'s `_disconnectGoogle` doc comment already says so: *"that sentence is not true today; `sync()` only ever upserts."* This means unticking a calendar, or deleting an event in the calendar app, leaves its already-imported blocks on the schedule forever — and `35-UI-SPEC.md`'s **locked** "Remove this calendar?" dialog body claims the opposite (*"will disappear the next time you sync"*). This plan's migration does not fix that general defect and is not meant to — it is a one-time cleanup of the specific pre-fix data, not a standing prune mechanism. Deliberately out of scope here: a window-scoped prune is unsafe while `CompositeCalendarSource` swallows per-child failures and returns a partial list with no error signal, since pruning against that could delete a healthy source's blocks on a mere network blip.

**Accepted cost (T-36-37, STRIDE register, disposition accept):** for exactly one post-upgrade check-in, if the calendar source cannot be read at all (offline), there are no last-known imported blocks to degrade to — D-35-13's guarantee is weakened for that single window. The remedy is one successful sync. Plan 36-11's re-verification document must make "sync once before judging the schedule" its mandatory first step, consistent with this project's own CLAUDE.md trap #4 (stale-data UAT false failures).

## Issues Encountered

None beyond the mutation-proof isolation noted above (Task 2's count assertion masking the id assertion) — resolved by isolating the assertion under test rather than changing the shipped code.

## User Setup Required

None — no external service configuration required. The schema 12->13 migration runs automatically on next app launch via `HiveDatabase.init` -> `runMigrations`; no user action needed beyond the one post-upgrade sync already covered under "Accepted cost" above.

## Next Phase Readiness

- Full suite: 924/924 passing (baseline 915 + 7 new migration tests + 2 new disclosure-placement tests), `flutter analyze` clean ("No issues found!").
- `git diff 8f62a56 -- lib/services/schedule_generator.dart` is empty — the scheduling engine was not touched, as required.
- Ready for 36-11's device UAT: it must (a) exercise one post-upgrade sync before judging anything, consistent with the accepted-cost note above, (b) log the no-prune finding as WINDOWS entry 11, and (c) make the perceptual judgment this plan's D3 coverage entry defers to it — whether the relocated, weighted disclosure actually gets noticed on a real device this time.

---
*Phase: 36-connect-google-calendar-without-hunting-for-a-url*
*Completed: 2026-10-06*

## Self-Check: PASSED

All 8 modified/created files confirmed present on disk; all 3 task commits (`19c28d5`, `22e32d3`, `b3051b8`) confirmed ancestors of HEAD.
