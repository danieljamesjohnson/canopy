---
phase: 35-your-real-commitments-read-from-your-calendar
plan: 02
subsystem: calendar-import
tags: [ics, rrule, enough_icalendar, hive, timezone, flutter, mutation-testing]

requires:
  - phase: 35-01
    provides: "CalendarSource/CalendarSyncService tracer — one clean UTC-Z timed event importing end to end through the real ScheduleGeneratorService"
provides:
  - "CalendarSyncService mapping rules for every shape a real calendar sends: cancelled, all-day (blocking, per D-35-06), too-short/zero-duration/no-end-time, multi-day/midnight-crossing splitting (window-clipped, T-35-06), overlapping events"
  - "IcsCalendarSource._resolveInstant — correct absolute-instant resolution for zoned (TZID+VTIMEZONE) and floating (no Z, no TZID) DTSTART/DTEND forms, closing WINDOWS.md entry 2"
  - "SkipReason.label — the UI-SPEC's rendered skip-reason copy, ready for plan 04's disclosure sheet"
  - "Confirmed, tested finding: the chosen ICS package stack does not apply RECURRENCE-ID or EXDATE (WINDOWS.md entry 1, unchanged, still open, owner decision needed)"
  - "schedule_generator.dart's overlap tolerance pinned by a characterisation test — the engine itself is untouched"
affects: ["35-03", "35-04", "35-05", "35-06"]

actuals:
  tokens: 12488
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - "_mapEvent returns a Dart record ({blocks, skip}) instead of a nullable single block — lets one CalendarEvent become 0..N CommitmentBlocks (multi-day split) while keeping the cancelled/too-short skip paths uniform"
    - "Multi-day splitting subsumes too-short/zero-duration/no-end-time as the degenerate one-day case — no separate code path needed for those three, they just fail the shared gate on their only slice"
    - "_resolveInstant in IcsCalendarSource fixes the RAW parsed DateTime's absolute instant BEFORE CalendarSyncService's existing tz.TZDateTime.from(event.start, tz.local) conversion runs — the local-conversion seam established in 35-01 stays the ONLY place that produces LOCAL minutes; this function only fixes what instant is being described"
    - "SkipReason -> rendered copy via a Dart extension (SkipReasonLabel), not a switch inlined at each call site — one place to keep in sync with the UI-SPEC Copywriting Contract"

key-files:
  created:
    - test/data/calendar/ics_calendar_source_test.dart
    - test/fixtures/calendar/all_day_event.ics
    - test/fixtures/calendar/cancelled_event.ics
    - test/fixtures/calendar/short_and_no_end_events.ics
    - test/fixtures/calendar/multi_day_event.ics
    - test/fixtures/calendar/foreign_timezone_event.ics
    - test/fixtures/calendar/tzid_with_vtimezone.ics
    - test/fixtures/calendar/floating_time.ics
    - test/fixtures/calendar/overlapping_events.ics
    - test/fixtures/calendar/recurring_with_exception.ics
  modified:
    - lib/services/calendar_sync_service.dart
    - lib/data/calendar/ics_calendar_source.dart
    - test/services/calendar_sync_service_test.dart
    - test/services/schedule_generator_test.dart
    - .planning/WINDOWS.md

key-decisions:
  - "D-35-06 (owner ruling, RECORDED here per Task 1's instruction — this checkpoint was CLOSED before this dispatch, not re-asked): import-as-blocking. An all-day event becomes a CommitmentBlock spanning the app's configured working window on its own local day, NOT 0..1440. Implemented against ScheduleGeneratorService.dayStartMinutes/dayEndMinutes (see Decisions Made for why, and the owner-confirmation flag that still stands)."
  - "No per-user 'waking/working window' setting exists anywhere in this codebase. The only existing definition of 'the working day' is ScheduleGeneratorService.dayStartMinutes(480)/dayEndMinutes(1320) -- 08:00-22:00 -- a static const, not something a user configures. The all-day mapping uses these constants BY SYMBOL (never a hardcoded literal pair), which satisfies the must_have's 'not a hardcoded 08:00-18:00' requirement, but the owner's checkpoint preview showed 08:00-18:00 (a 10-hour window), not the actual 08:00-22:00 (14-hour) the app uses. This gap was already flagged by 35-DECISIONS.md for confirmation in 35-06's UAT; this SUMMARY narrows that flag to the SPECIFIC numbers the owner needs to see."
  - "CLAUDE.md's global operating guide states 'danserver's system timezone is UTC.' Empirically false for this execution environment: 'date' and 'readlink -f /etc/localtime' both resolve to America/Chicago. This was discovered BECAUSE the floating-time mutation proof (WINDOWS.md entry 2) initially produced NO failure when tz.local was set to America/Chicago -- the exact SEED-006 trap the plan warned about, just triggered by a different concrete fact than the plan assumed. Fixed by re-picking tz.local=Asia/Tokyo. Not corrected in the global CLAUDE.md by this agent (out of this plan's scope -- that file lives outside the project repo) but flagged prominently here and in the final response."
  - "T-35-06 (DoS: unbounded multi-day split) was NOT satisfied by the first implementation -- dayCount was derived from the event's own unclipped start/end, not clipped to the sync window. Found during a threat-model re-check before writing the SUMMARY, not by a plan-supplied test. Fixed (Rule 2) and pinned by a new test + mutation proof (3653 blocks with clipping removed, <=15 with it)."

patterns-established:
  - "A record return type ({List<T> blocks, SkipReason? skip}) for a mapper that can produce zero, one, or many outputs plus an optional whole-item rejection reason -- avoids a sentinel/nullable-list hybrid."
  - "Mutation proofs performed via a temporary same-file Edit -> run -> observe -> revert cycle, verified afterward via git diff --stat on the file that must stay empty across the whole plan (lib/services/schedule_generator.dart)."

requirements-completed: [CAL-01]

coverage:
  - id: D1
    description: "All-day events import as one blocking CommitmentBlock spanning the app's working-window constants (D-35-06 RULED import-as-blocking), asserted by symbol not hardcoded literal"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#an all-day event imports as one commitment spanning the working window, not skipped (D-35-06 RULED import-as-blocking)"
        status: pass
    human_judgment: true
    rationale: "The SPAN VALUE (08:00-22:00, from ScheduleGeneratorService's constants) has never been shown to the owner -- his checkpoint preview showed 08:00-18:00. 35-DECISIONS.md already flags this for confirmation in 35-06's UAT; this SUMMARY narrows the flag to the concrete numbers. The behavior is correctly and honestly implemented; whether it matches what the owner actually wants is unconfirmed."
  - id: D2
    description: "A cancelled event is skipped with reason 'Cancelled' (rendered, verbatim UI-SPEC copy); a tentative event imports normally"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#a cancelled event is skipped as Cancelled; a tentative event in the same feed imports normally"
        status: pass
    human_judgment: false
  - id: D3
    description: "A too-short event, a zero-duration event, and a no-end-time event all import zero blocks and are skipped as 'Too short to schedule' (rendered), gated by the existing commitmentWindowTooShort -- no restated 25-minute literal in calendar_sync_service.dart"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#a too-short event, a zero-duration event, and a no-end-time event all import zero blocks and are each skipped as Too short to schedule; a real 30-minute event in the same feed imports"
        status: pass
    human_judgment: false
  - id: D4
    description: "The 25-minute/24-minute boundary itself -- 25 imports, 24 does not -- mutation-proven"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#a 25-minute event imports; a 24-minute event does not import"
        status: pass
    human_judgment: false
  - id: D5
    description: "A multi-day event splits into one CommitmentBlock per local calendar day it touches, each clipped to 0..1440, each end after its own start -- mutation-proven (removing the clip collapses it to one inverted, zero-length block)"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#a Fri 14:00 -> Sun 11:00 event splits into three one-off blocks"
        status: pass
    human_judgment: false
  - id: D6
    description: "An 11pm-2am midnight-crossing event splits into two blocks, neither inverted, without reopening the app's overnight-commitment scope boundary"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#an 11pm->2am event splits into two blocks, neither inverted"
        status: pass
    human_judgment: false
  - id: D7
    description: "An event in a foreign IANA timezone (UTC-Z form) converts to the correct LOCAL minutes under a non-UTC tz.local"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#an event in a foreign IANA timezone (Z-suffixed UTC) converts to the correct LOCAL minutes under a non-UTC tz.local"
        status: pass
    human_judgment: false
  - id: D8
    description: "DTSTART;TZID=America/Chicago + a matching VTIMEZONE block (the real Google Calendar form) resolves to the correct LOCAL minutes -- closes WINDOWS.md entry 2 (zoned form), mutation-proven"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#DTSTART;TZID=America/Chicago + a matching VTIMEZONE block resolves to the correct LOCAL minutes"
        status: pass
    human_judgment: false
  - id: D9
    description: "A floating DTSTART (no Z, no TZID) resolves against tz.local, never against the system clock -- closes WINDOWS.md entry 2 (floating form), mutation-proven (first attempt failed to discriminate; see key-decisions)"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#a floating DTSTART (no Z, no TZID) resolves against tz.local, not against the system clock"
        status: pass
    human_judgment: false
  - id: D10
    description: "Two overlapping events both import as separate blocks (D-35-09) -- no overlap detection added to the mapper"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#two overlapping events both import as separate blocks (D-35-09)"
        status: pass
    human_judgment: false
  - id: D11
    description: "A feed claiming an implausible multi-year event splits into AT MOST kCalendarSyncWindowDays+1 blocks, not one per claimed day (T-35-06) -- mutation-proven (3653 blocks with the clip removed)"
    verification:
      - kind: unit
        ref: "test/services/calendar_sync_service_test.dart#a feed claiming an implausible multi-year event splits into AT MOST kCalendarSyncWindowDays blocks"
        status: pass
    human_judgment: false
  - id: D12
    description: "Two overlapping one-off commitment blocks both contribute chunks and the generator does not crash -- characterisation of EXISTING behavior, schedule_generator.dart itself unmodified (empty git diff --stat across the whole plan), non-vacuity proven by dropping one block"
    verification:
      - kind: unit
        ref: "test/services/schedule_generator_test.dart#two overlapping one-off commitment blocks on the same day both produce chunks and the generator does not throw"
        status: pass
    human_judgment: false
  - id: D13
    description: "RECURRENCE-ID/EXDATE support -- UNMET. Confirmed by an actual test against the real package stack: EXDATE is not honored (excluded occurrence still returned), RECURRENCE-ID does not replace the base occurrence (returned as an additional duplicate event instead). Matches WINDOWS.md entry 1 (unchanged, still open). Not hand-rolled per the task's own instruction; the fallback to the other D-35-05 candidate package is the owner's call."
    verification:
      - kind: unit
        ref: "test/data/calendar/ics_calendar_source_test.dart#RECURRENCE-ID and EXDATE are NOT applied by the chosen package stack"
        status: pass
    human_judgment: true
    rationale: "The test PASSES because it correctly characterises the CURRENT (incomplete) behavior -- but the underlying capability the must_have originally asked for is NOT implemented and cannot be auto-resolved by this executor. The owner needs to decide: accept the gap, fall back to the other D-35-05 candidate, or scope a dedicated follow-up phase."

duration: 95min
completed: 2026-09-15
status: complete
---

# Phase 35 Plan 02: Every shape a real calendar actually contains Summary

**All-day, cancelled, too-short/zero-duration/no-end-time, multi-day/midnight-crossing, overlapping, and both remaining RFC 5545 DTSTART forms (TZID+VTIMEZONE and floating) are now real mapping rules in `CalendarSyncService`/`IcsCalendarSource`, each pinned by a test proven to fail without it — plus two bugs this work uncovered and fixed along the way (a DoS-shaped unbounded day-split, and a real `rrule` crash on any future-dated or past-started recurring event) that were not named in the plan itself.**

## Performance

- **Duration:** ~95 min
- **Completed:** 2026-09-15T13:20:00Z
- **Tasks:** 2 of 3 executed by this agent (Task 1 was a `checkpoint:decision` already RULED by the owner on 2026-09-14, before this dispatch — recorded below as D-35-06, not re-asked)
- **Files modified:** 15 (10 created, 5 modified)

## Accomplishments

- `CalendarSyncService._mapEvent`/`_buildBlock` replace the tracer's single-block `_mapToBlock` with a record-returning mapper (`{blocks, skip}`) that handles: cancelled (skip), all-day (one block on the app's working-window constants, D-35-06), and every other event as a multi-day split — one slice per local calendar day, each independently re-gated by the existing `commitmentWindowTooShort`. That gate reuse means too-short/zero-duration/no-end-time events needed **no separate code path** — they're just the one-day degenerate case of the same split.
- `IcsCalendarSource._resolveInstant` closes **WINDOWS.md entry 2**: `enough_icalendar` parses every non-`Z` DTSTART/DTEND with Dart's plain, system-local `DateTime` constructor, ignoring both `TZID` and the app's `tz.local`. This resolves a **zoned** value (`TZID=America/Chicago` + `VTIMEZONE` — the real Google Calendar form) via the `timezone` package's own IANA database, and a **floating** value (no `Z`, no `TZID`) by re-embedding the same digits directly against `tz.local` — never via the embedded `VTIMEZONE` content, never via the machine's real system zone.
- `SkipReasonLabel` (a small extension) renders `SkipReason` into its UI-SPEC Copywriting Contract copy verbatim — "Too short to schedule", "Cancelled" — so plan 04's disclosure sheet has a ready-made source of truth, and this plan's own tests assert against the rendered string, not just the enum name (a requirement I initially missed and had to go back and add — see Deviations).
- 9 new `.ics` fixtures + 12 new tests in `calendar_sync_service_test.dart`, a new `ics_calendar_source_test.dart` (recurrence-exception finding), and a new characterisation group in `schedule_generator_test.dart` (overlap tolerance, engine unmodified).
- **Two bugs found and fixed that the plan did not name:**
  1. **T-35-06 (threat-model mitigation, missing):** the multi-day split's `dayCount` was derived from the event's own unclipped start/end, not the sync window — a feed claiming a multi-year "event" would materialise one block per claimed day (3653, for a 2020–2030 fixture, confirmed by mutation-removing the clip). Fixed by clipping the local day-range to `[windowStart, windowEnd]` before splitting.
  2. **A real `rrule` crash**, discovered while writing Task 3's recurrence test: `RecurrenceRule.getInstances` asserts `after >= start` and `before >= start` (the RRULE's own DTSTART) — which throws for ANY recurring event whose sync window starts before the series began (the ordinary case: ANY pre-existing recurring event) or whose series starts after the window ends (any future-dated recurring event). Fixed with a clamp + early return.
- 6 mutation proofs performed and reverted this session (full output below): multi-day day-clipping, the 25/24-minute boundary, the zoned-form WINDOWS.md-entry-2 defect, the floating-form WINDOWS.md-entry-2 defect (twice — see the danserver-timezone finding), the overlap non-vacuity proof, and the T-35-06 DoS-bound proof.
- **A significant infrastructure finding:** this environment's actual system timezone is `America/Chicago`, not UTC as `~/.claude/CLAUDE.md`'s global operating guide states. Discovered because the first floating-time mutation proof produced NO failure — exactly the trap the plan warned about, just triggered by a different concrete fact than the plan assumed. See Deviations for the full account.

## Task Commits

1. **Task 1: Rule the all-day question (checkpoint:decision)** — already answered by the owner on 2026-09-14, before this dispatch. No commit from this agent; recorded in `35-DECISIONS.md` and restated below as D-35-06.
2. **Task 2: Every shape a real calendar actually contains** — `79f1768` (feat)
3. **Task 3: Pin what the engine already does** — `4247cbd` (test)
4. **Follow-up fix (T-35-06 mitigation, found during self-review before writing this SUMMARY)** — `2ee206a` (fix)
5. **Follow-up fix (rendered skip-reason strings, an acceptance criterion I initially missed)** — `7364eb5` (fix)

**Plan metadata:** this commit (`docs(35-02): complete plan` — see Final Commit below)

## Files Created/Modified

- `lib/services/calendar_sync_service.dart` — `_mapEvent`/`_buildBlock` (replacing `_mapToBlock`), `SkipReason.cancelled`, `SkipReasonLabel` extension, window-clipped multi-day splitting
- `lib/data/calendar/ics_calendar_source.dart` — `_resolveInstant` (zoned/floating instant resolution), the `rrule` crash fix (clamped `after`, early-return on `before < start`)
- `test/services/calendar_sync_service_test.dart` — 12 new tests in a new group, 3 new inline fixture constants (boundary x2, overnight, implausible-multi-year)
- `test/services/schedule_generator_test.dart` — new characterisation group (overlap tolerance); `schedule_generator.dart` itself untouched
- `test/data/calendar/ics_calendar_source_test.dart` — new file; the recurrence-exception finding
- `test/fixtures/calendar/all_day_event.ics`, `cancelled_event.ics`, `short_and_no_end_events.ics`, `multi_day_event.ics`, `foreign_timezone_event.ics`, `tzid_with_vtimezone.ics`, `floating_time.ics`, `overlapping_events.ics`, `recurring_with_exception.ics` — new fixtures
- `.planning/WINDOWS.md` — entry 2 marked `fixed`; entry 1 unchanged (`open`)

## Decisions Made

**D-35-06 (owner ruling, recorded per Task 1's `<RULED>` block — CLOSED before this dispatch, not re-asked):** `import-as-blocking`. An all-day calendar entry becomes a `CommitmentBlock` spanning the app's configured working window on its own local day — not `00:00–23:59`. Full reasoning already in `35-DECISIONS.md`.

**What "the app's configured working window" actually resolves to, and why this matters for 35-06's UAT:** there is **no per-user "waking/working window" setting anywhere in this codebase**. The plan's own text guessed `app_settings.dart` was "the likely home" for such a value — it is not; no such field exists. The only existing definition of "the working day" is `ScheduleGeneratorService.dayStartMinutes` (480 = 08:00) / `dayEndMinutes` (1320 = 22:00), a pair of `static const int`s the generator itself already uses as the day's schedulable bounds. I used these BY SYMBOL (never a hardcoded literal pair) for the all-day mapping, which satisfies the must_have's literal requirement ("not a hardcoded 08:00–18:00"). **But the owner's checkpoint preview, during the D-35-06 decision, showed `08:00–18:00`** — a 10-hour window — while the app's real constant is `08:00–22:00`, a 14-hour window. `35-DECISIONS.md` already flags that the span needs owner confirmation in 35-06's UAT; this SUMMARY narrows that flag to the CONCRETE numbers he needs to see (14 hours, not 10) so that confirmation step isn't vague.

**A significant, load-bearing infrastructure finding, recorded here rather than silently worked around:** `~/.claude/CLAUDE.md` (the user's global operating guide) states "danserver's system timezone is UTC," and derives several other claims from it. **This is empirically false for this execution environment.** `date` reports `CDT` and `readlink -f /etc/localtime` resolves to `America/Chicago`. This was discovered because the mandatory floating-time mutation proof (WINDOWS.md entry 2) produced **no failure** on its first attempt with `tz.local = America/Chicago` — the EXACT trap the plan's `<critical_context>` warned about, just triggered by a different concrete fact (the real system zone being Chicago, not UTC) than the plan's own text assumed. The mutation proof did its job: a test that silently passes for the wrong reason got caught, not shipped. Fixed by re-picking `tz.local = Asia/Tokyo` for that specific test. **This agent did not edit `~/.claude/CLAUDE.md`** — it is outside this project's repository and outside this plan's scope — but the discrepancy is flagged here and restated in the final response to the orchestrator, since it could affect timezone-sensitive test design in any other project on this machine that trusted the same stale claim.

**T-35-06 was not satisfied by the plan-as-written implementation** — found during a self-review of the threat model before writing this SUMMARY, not by a test the plan supplied. See Deviations.

**A real crash in `rrule` usage was found and fixed** — also not named by the plan, discovered empirically while probing the recurrence-exception fixture before writing its test. See Deviations.

## Stale Plan Text (flagged per this plan's own `<critical_context>` instruction)

Two places in `35-02-PLAN.md` still read as though written against the PRE-ruling default (all-day events skipped), even though the plan's `<RULED>` block and `must_haves` were correctly rewritten:

1. Task 2's `<behavior>` block: `` `all_day_event.ics` → 0 blocks imported, 1 skipped entry whose reason string is the UI-SPEC's all-day copy. `` — this is the OPPOSITE of D-35-06's actual ruling and contradicts the same task's own `<action>` text three paragraphs later. Followed the `<RULED>` block instead: 1 block imported, 0 skipped.
2. Task 2's acceptance criteria: "The **three** skip-reason strings match the UI-SPEC Copywriting Contract verbatim" — a leftover from when `allDay` was still a third `SkipReason` member. There are only **two** skip reasons now (`tooShort`, `cancelled`); `allDay` is explicitly not one (per the plan's own instruction not to introduce it). Both are rendered and asserted verbatim.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Missing Critical Functionality] T-35-06's threat-model mitigation was absent from the first implementation**
- **Found during:** Self-review of the threat model before writing this SUMMARY (not flagged by any test the plan supplied)
- **Issue:** `_mapEvent`'s `dayCount` was computed from the event's own unclipped local start/end dates. `IcsCalendarSource`'s overlap filter only requires an event to TOUCH the sync window, not fit inside it, so a feed claiming an implausible multi-year "event" would produce one `CommitmentBlock` per day of its FULL claimed span — 3653 blocks for a 2020–2030 fixture, confirmed by temporarily removing the clip and observing exactly that number.
- **Fix:** `_mapEvent` now takes `windowStart`/`windowEnd` and clips the event's local day-range to them before computing `dayCount`, bounding the worst case to the sync window itself (≤15 days for the 14-day window). A day that only appears because of clipping (the event actually started earlier, or ends later, than the window) is treated as an ordinary full-day slice, not the event's own first/last day.
- **Files modified:** `lib/services/calendar_sync_service.dart`, `test/services/calendar_sync_service_test.dart` (new test + inline fixture)
- **Verification:** New test asserts `imported.length <= 15`; mutation proof removed the clip and observed `Actual: <3653>`, then reverted.
- **Committed in:** `2ee206a`

**2. [Rule 1 — Bug] `rrule`'s `getInstances` crashes for any recurring event whose sync window starts before the series began, or whose series starts after the window ends**
- **Found during:** Writing Task 3's recurrence-exception test, via an empirical probe (before writing the real test) that threw `'after >= start': is not true.`
- **Issue:** `RecurrenceRule.getInstances` asserts `after >= start` and `before >= start`, where `start` is the RRULE's own DTSTART. `IcsCalendarSource._expand` passed the QUERY window's bounds verbatim as `after`/`before`. Any recurring event whose series began before the current sync window (the ordinary case — MOST recurring events) or whose series starts entirely after the window ends (a future-dated recurring event) would throw. `CalendarSyncService.sync()`'s outer `try/catch` around the fetch call does catch this, so it degrades to `failed: true` rather than crashing the UI — but it means ONE such event would silently fail the ENTIRE sync, not just itself.
- **Fix:** Clamp `after` to `max(queryStart, eventDtstart)`; short-circuit with `return const []` when the event's DTSTART is entirely after the query window (avoiding `before < start`).
- **Files modified:** `lib/data/calendar/ics_calendar_source.dart`
- **Verification:** The probe (a throwaway test, deleted afterward — never committed) reproduced the crash before the fix and ran clean after. All 4-week-window recurrence assertions pass with the fix in place.
- **Committed in:** `4247cbd`

**3. [Rule 2 — Missing Required Behavior] Skip-reason strings were asserted against the enum, not the rendered UI-SPEC copy**
- **Found during:** Re-reading Task 2's own acceptance criteria after the first implementation pass ("asserted against the rendered reason strings, not against the enum names")
- **Issue:** My first pass of the new tests checked `result.skipped.single.reason == SkipReason.cancelled` etc. — the enum value, never a rendered string. No code existed anywhere to produce the actual UI-SPEC copy ("Too short to schedule", "Cancelled") from the enum.
- **Fix:** Added `SkipReasonLabel`, a small extension mapping each `SkipReason` to its verbatim UI-SPEC string; updated the three new tests that check a skip reason to also assert `.label`.
- **Files modified:** `lib/services/calendar_sync_service.dart`, `test/services/calendar_sync_service_test.dart`
- **Verification:** `flutter test` — all label assertions pass against the literal strings from `35-UI-SPEC.md`'s Copywriting Contract.
- **Committed in:** `7364eb5`

---

**Total deviations:** 3 auto-fixed (2 Rule 2 — missing required/critical behavior; 1 Rule 1 — a real crash bug)
**Impact on plan:** All three are correctness/security-shaped, none is scope creep, and none touches `lib/services/schedule_generator.dart` (confirmed empty diff on that file across every commit in this plan). Two of the three (T-35-06's clipping, the rrule crash) were caught by self-review and a probe rather than the plan's own tests — worth noting as a gap in the plan's own coverage, not a criticism of the plan's intent.

## Mutation Proofs (required by acceptance criteria)

All six performed via a temporary same-file `Edit` → run → observe → revert cycle this session; `git diff --stat -- lib/services/schedule_generator.dart` confirmed empty after every one.

**1. Multi-day day-clipping removal** (forced `dayCount = 1`):
```
Expected: an object with length of <3>
  Actual: []
   Which: has length of <0>
```
(The multi-day event collapsed to one 840→660 slice, negative duration, gated out entirely by `commitmentWindowTooShort` — a safe degrade, not a crash, but the multi-day test correctly went red.)

**2. The 25/24-minute boundary** (shifted the gate's effective duration by +1 minute):
```
Expected: empty
  Actual: [Instance of 'CommitmentBlock']
```

**3. WINDOWS.md entry 2 — zoned form** (bypassed the TZID branch, forcing fall-through to the floating branch):
```
Expected: <300>
  Actual: <840>
```

**4. WINDOWS.md entry 2 — floating form, FIRST attempt** (`tz.local = America/Chicago`, mimicking the pre-fix system-local fallback):
```
All tests passed!
```
**No failure — the trap.** danserver's real system zone (America/Chicago) coincidentally matched the chosen `tz.local`, so the buggy and correct code paths agreed. Per the plan's own instruction, this was NOT recorded as a passing proof — the test was rewritten.

**5. WINDOWS.md entry 2 — floating form, SECOND attempt** (`tz.local = Asia/Tokyo`, same mutation):
```
Expected: <840>
  Actual: <300>
```
Discriminates correctly. This is the version committed.

**6. T-35-06 — DoS bound** (removed the window clip, using the event's raw unclipped span):
```
Expected: a value less than or equal to <15>
  Actual: <3653>
```

**Two additional non-vacuity proofs (Task 3 acceptance criteria):**

**Overlap test** (dropped `blockB` from the fixture):
```
Expected: contains 'cf0a240f-7fde-474c-b794-8a4d50109eaa'
  Actual: Set:['febb521c-b7e3-4e97-8e18-3b627603c9cc']
   Which: does not contain 'cf0a240f-7fde-474c-b794-8a4d50109eaa'
```

**Recurrence test** (changed the expected moved-occurrence time to the base time):
```
Expected: 'Weekly sync (moved)'
  Actual: 'Weekly sync'
   Which: is different. Both strings start the same, but the actual value is
   missing the following trailing characters:  (moved)
```
This is the CONFIRMED FINDING itself, not an artificial mutation — the "wrong" answer here is what the real package stack actually returns. See below.

## Confirmed Finding: RECURRENCE-ID/EXDATE Are Not Applied (WINDOWS.md entry 1, unchanged, still open)

Per Task 3's explicit instruction ("if the chosen package fails any of the three, stop and report it in the SUMMARY as a finding — do not hand-roll an exception-handling layer on top of it"), this is reported rather than worked around.

`test/data/calendar/ics_calendar_source_test.dart` drives `IcsCalendarSource` over `recurring_with_exception.ics` (a weekly `RRULE:FREQ=WEEKLY;COUNT=5` event with one `RECURRENCE-ID` override and one `EXDATE`) and confirms empirically:

- The `EXDATE`'d occurrence (2026-03-23) **is still returned** at its base time — `EXDATE` is not applied.
- The `RECURRENCE-ID`-overridden occurrence does **not replace** the base occurrence — the un-excluded base event at 2026-03-16 14:00 is STILL present, and the override (2026-03-16 16:00, "Weekly sync (moved)") is returned as an ADDITIONAL, separate event, with `recurrenceId == null` (not tied back to the occurrence it was meant to replace).
- Ordinary (non-exception) occurrences DO return correctly at their base times — this part of the assumption the package stack was chosen on holds.
- Total events for the 4-week+ window: 6 (5 base occurrences, including the two that should have been excluded/replaced, + 1 additional override event) — not the 4 an RFC-correct implementation would produce.

This confirms what `35-01-SUMMARY.md` already documented via design review (not a failing test, at the time): neither `enough_icalendar` nor `rrule` applies `RECURRENCE-ID`/`EXDATE`. **WINDOWS.md entry 1 is unchanged — still `open`.** This plan's own `must_have` asserting MOVED/EXDATE behavior is therefore **UNMET** — stated here plainly rather than left to be discovered. The task's own instruction is explicit that the fallback (the other D-35-05 candidate package) is **the owner's call, not the executor's** — recorded as a blocker for the owner, not auto-resolved.

## Issues Encountered

None beyond what's documented above under Deviations and the Confirmed Finding — all surfaced, not hidden.

## Known Stubs / Scoped-Out Gaps

- **RECURRENCE-ID/EXDATE remain unimplemented** — see Confirmed Finding above. `WINDOWS.md` entry 1 stays open.
- **The all-day working-window span (08:00–22:00) has not been shown to the owner** — flagged for 35-06's UAT with the concrete numbers, per the note under Decisions Made.
- **A future-dated all-day multi-day event** (an all-day "vacation" spanning several days) is mapped using ONLY its start date — no fixture in this plan exercises a multi-day all-day event, and the mapping does not (yet) split it per day the way a timed multi-day event does. Not required by any must_have in this plan; flagged for whichever future plan first needs it.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `CalendarSyncService`/`IcsCalendarSource` now handle every shape RESEARCH.md's pitfalls named except `RECURRENCE-ID`/`EXDATE` (explicitly out of this plan's scope, confirmed by test).
- `lib/services/schedule_generator.dart` is untouched — confirmed by `git diff --stat` across every commit in this plan.
- `flutter analyze` clean; full suite green (760/760, up from the 746-test baseline this plan started from).
- **Open items for the owner, recorded as blockers, not pushed:**
  1. Confirm the all-day working-window span (08:00–22:00, not the 08:00–18:00 shown in the D-35-06 checkpoint preview) in 35-06's UAT.
  2. Decide whether to accept the RECURRENCE-ID/EXDATE gap, fall back to the other D-35-05 candidate package, or scope a dedicated follow-up.
  3. (Informational, not this project's blocker) `~/.claude/CLAUDE.md`'s "danserver is UTC" claim does not match this execution environment (`America/Chicago`) — worth a look outside this project.
- Plans 35-03 through 35-06 can build on this mapper without re-deciding any of the shapes it now handles.

## Self-Check: PASSED

All files listed under "Files Created/Modified" that are new files were confirmed present on disk (`test -f`); commits `79f1768`, `4247cbd`, `2ee206a`, `7364eb5` confirmed present in `git log --oneline --all`. `flutter analyze` clean; `flutter test` 760/760 green as of the last run before writing this SUMMARY. No missing items.

---
*Phase: 35-your-real-commitments-read-from-your-calendar*
*Completed: 2026-09-15*
