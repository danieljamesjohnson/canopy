---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 11
subsystem: calendar-sync
tags: [uat, windows-ledger, gap-closure, documentation-only]

requires:
  - phase: 36-connect-google-calendar-without-hunting-for-a-url
    provides: "plans 36-08, 36-09, 36-10's merged code fixes for WINDOWS entries 6, 7 (code half), 8, 10"
provides:
  - "36-UAT-R2.md — the device re-verification script for this gap closure, with a mandatory Step 0 re-check-in sequence, items R1-R5, and every carried-forward item from the stopped 2026-10-06 sitting"
  - "WINDOWS.md reconciled: entries 6, 8, 10 marked fixed; entry 7 deliberately left open pending device confirmation; entry 11 (sync() never prunes) newly logged"
affects: [36-ship-gate, future-device-uat]

actuals:
  tokens: 9284
  tasks: 2
  commits: 2
  plan_head_before: a876fa7415155c123863010cee6cdc1eb77d48f3
  plan_head_after: 06e2c74209e3041d07bac7fb4b27ec1f0388f728

tech-stack:
  added: []
  patterns:
    - "Hand-edit WINDOWS.md's three views (markdown table, JSON array, frontmatter counts) directly rather than through a gsd-tools writer, per the project's own CLAUDE.md data-loss warning; verify with a machine-checkable consistency assertion before committing"

key-files:
  created:
    - .planning/phases/36-connect-google-calendar-without-hunting-for-a-url/36-UAT-R2.md
  modified:
    - .planning/WINDOWS.md

key-decisions:
  - "Entry 7 stays open even though its code fix (plan 36-08) is mutation-proven correct up to the plugin boundary — marking it fixed on a danserver-only proof would be exactly the overclaim this gap closure exists to prevent. It closes only when 36-UAT-R2.md item R1 is observed on the owner's real iPhone."
  - "Entry 11 (sync() never prunes) logged as its own open defect rather than folded into entry 8's closure — it is a distinct, pre-existing defect that contradicts 35-UI-SPEC.md's locked 'Remove this calendar?' dialog copy, found while reading the sync path during 36-09 and deliberately left unfixed because a window-scoped prune is unsafe while CompositeCalendarSource swallows per-child failures"
  - "WINDOWS.md was hand-edited with Read+Edit, never via a gsd-tools writer verb, per the user's global CLAUDE.md data-loss warning about whole-file-regex planning-markdown writers"
  - "36-UAT-R2.md deliberately contains no feed-URL step anywhere, and says so explicitly, to prevent Phase 35's http://-vs-HTTPS trap from recurring in a document this gap closure exists partly to fix"

patterns-established:
  - "A gap-closure UAT document names, per item, exactly which danserver-side proof already exists and exactly what remains for the human — rather than re-asking something already settled or asking for something a test could have settled"

requirements-completed: [CAL-02, CAL-04, CALAUTH-03]

coverage:
  - id: D1
    description: "36-UAT-R2.md exists, with Step 0 first and mandatory (ending in Re-check-in, citing the 2026-08-21 precedent), all six all-day entries named for R2, a genuinely blank Your Answers section, and no feed-URL step anywhere in the document"
    verification:
      - kind: other
        ref: "grep -c 'Re-check-in' 36-UAT-R2.md >= 2"
        status: pass
      - kind: other
        ref: "grep for Vacation/Payday/Fall break/Columbus Day/Indigenous Peoples/Birthday, all present"
        status: pass
      - kind: other
        ref: "grep -ci 'your answers' >= 1 AND grep -c 'http://' <= 1"
        status: pass
    human_judgment: false
  - id: D2
    description: "WINDOWS.md's three views (markdown table, JSON array, frontmatter counts) agree: entries 6/8/10 fixed, entry 7 open, entry 11 present and open, entries 1/3/4/9 byte-identical to pre-plan state"
    verification:
      - kind: other
        ref: "python3 consistency checker (plan's own <verify> block) — printed 'WINDOWS OK' with the exact expected status map"
        status: pass
      - kind: other
        ref: "grep -c '^| 11 |' WINDOWS.md >= 1 (markdown row exists, not just JSON)"
        status: pass
      - kind: other
        ref: "git diff 8f62a56 -- .planning/WINDOWS.md, filtered to entries 1/3/4/9 — no output"
        status: pass
    human_judgment: false
  - id: D3
    description: "Items R1 (device calendarIds honoured), R2 (six all-day blocks gone), R3 (disclosure noticed cold), R4 (Google connection persists on screen re-open) and R5 (accepted-cost preference) are answered by the owner on his real iPhone"
    verification: []
    human_judgment: true
    rationale: "Every one of these is either a real-device plugin behavior (R1) or a perceptual human judgment (R2, R3, R4, R5) that this plan explicitly states cannot be settled on danserver — that is the entire reason this plan exists as documentation rather than code."

duration: ~25min
completed: 2026-10-06
status: complete
---

# Phase 36 Plan 11: Write 36-UAT-R2.md and reconcile WINDOWS.md Summary

**Wrote the device re-verification script the owner will actually follow on his phone, and hand-edited `WINDOWS.md` so its defect register says exactly what shipped — three entries closed, one honestly still open with its remaining proof named, and one new defect recorded rather than absorbed into a done claim.**

## Performance

- **Duration:** ~25 min
- **Tasks:** 2/2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- `36-UAT-R2.md` created: a mandatory, first, five-step "Sync now → ⟳ Re-check-in" Step 0 (citing the 2026-08-21 trap #4 precedent by date), a "what you'll see first and it isn't a bug" note about the schema 12→13 purge, five numbered items (R1-R5) covering WINDOWS entries 7/8/10/6 and D-36-05's accepted cost, a carried-forward section for everything the stopped 2026-10-06 sitting never reached, an explicit "no URL anywhere in this document" limits section, and a genuinely blank answers section.
- `WINDOWS.md` reconciled by hand across all three of its views: entries 6, 8 and 10 marked `fixed` with a `resolved_at` timestamp and a note naming which plan fixed the code and which `36-UAT-R2.md` item carries the remaining device/perceptual confirmation; entry 7 deliberately left `open` with an added explanation of why a mutation-proven host fix is not suffient to close it; entry 11 added as a new open defect (`sync()` never prunes).

## Task Commits

1. **Task 1: Write 36-UAT-R2.md — the device re-verification script** - `a858fcc` (docs)
2. **Task 2: Square WINDOWS.md with what actually shipped — and add the entry that planning found** - `06e2c74` (fix)

_No separate plan-metadata commit — this SUMMARY and any STATE.md/ROADMAP.md updates are committed by the orchestrator after the wave completes, per this run's instructions._

## Files Created/Modified

- `.planning/phases/36-connect-google-calendar-without-hunting-for-a-url/36-UAT-R2.md` — new device re-verification script, no feed URL anywhere
- `.planning/WINDOWS.md` — entries 6/8/10 fixed, entry 7 left open with updated reasoning, entry 11 added, frontmatter counts updated to match

## Decisions Made

See `key-decisions` in frontmatter. The load-bearing one: **entry 7 stays open.** Plan 36-08's fix is mutation-tested and proves the exact ticked calendar-id list reaches the exact point `device_calendar_plus` is called, through the real `sync()` path — but whether the plugin itself honours a non-empty `calendarIds` argument on real iOS hardware has never been observed by anyone, and cannot be observed on danserver (no Xcode, no device). Marking it `fixed` here would be the overclaim this entire gap closure exists to prevent. It closes only when the owner runs `36-UAT-R2.md` item R1.

## Arithmetic cross-check against the dispatch prompt's own count

The dispatch prompt offered this arithmetic and asked me to reconcile against it:

> Before: open 1,3,4,6,7,8,10 (7); fixed 2,5 (2); waived 9 (1); total 10.
> After: open 1,3,4,7,11 (5); fixed 2,5,6,8,10 (5); waived 9 (1); total 11.

**I agree with it exactly.** The shipped file's machine-checked state is `{1: open, 2: fixed, 3: open, 4: open, 5: fixed, 6: fixed, 7: open, 8: fixed, 9: waived, 10: fixed, 11: open}` — open_count 5, fixed_count 5, waived_count 1, total_count 11. All three views (markdown table, JSON array, frontmatter) agree, verified by the plan's own Python consistency checker before committing.

## Deviations from Plan

None — plan executed exactly as written. Both tasks' verification blocks passed on the first attempt after one correction: the first draft of `36-UAT-R2.md`'s "Limits of this document" section used the literal string `http://` twice (once describing the trap, once describing what it rejects), which the plan's own gate (`grep -c "http://" <= 1`) correctly caught as a near-recurrence of the exact over-mention risk it exists to prevent. Reworded to a single mention before committing — not a deviation from the plan's intent, since the plan's own verification step is what caught it.

## Issues Encountered

None beyond the `http://` phrasing above, resolved before any commit.

## User Setup Required

None — no external service configuration required. This is a documentation-only plan; the owner's required action is to read and follow `36-UAT-R2.md` on his own device, which is the plan's entire purpose rather than a setup step.

## Findings in the three upstream SUMMARYs and the code — nothing contradicted

Cross-checked every claim this plan relies on against the actual code and the three SUMMARYs (36-08, 36-09, 36-10) rather than trusting their prose:

- `lib/services/calendar_sync_service.dart` confirmed to contain no `delete`/`remove` call in `sync()` or `_mapEvent` (only a `save()` loop).
- `grep -rn '\.delete(' lib/` returns exactly five sites, not four as the SUMMARYs state in prose — but the fifth is `lib/data/database/migrations.dart:173`, which is plan 36-09's own one-time schema 12→13 purge (`purgeImportedCalendarBlocks`), not a standing prune mechanism in the sync path. The "four call sites outside the calendar path" claim is accurate once the migration's own one-time delete is correctly excluded as a different mechanism; I worded entry 11 to say "outside migrations.dart's own one-time purge" rather than repeat the slightly-imprecise "four" framing verbatim.
- `calendar_settings_screen.dart`'s `_disconnectGoogle` doc comment confirmed to contain the exact admission quoted in `D-36-05` and the SUMMARYs: *"that sentence is not true today; `sync()` only ever upserts."*
- `35-UI-SPEC.md` line 165 confirmed to carry the locked, now-contradicted dialog body: *"Commitments already imported from it will disappear the next time you sync."*
- `git diff 8f62a56 -- lib/services/schedule_generator.dart` confirmed empty on this tree, matching every SUMMARY's claim that the scheduling engine was never touched across the whole gap closure.
- Full suite confirmed green on this tree: **934/934 passing**, `flutter analyze` clean — matching plan 36-10's closing numbers exactly, with no drift introduced by this (documentation-only) plan.

No contradiction found between the three upstream SUMMARYs, `36-DECISIONS.md`'s D-36-05, and the code as it stands. The only correction made was the minor "four vs. five `.delete(` sites" framing above, which does not change any conclusion — it only changes how entry 11's evidence is worded to stay precise.

## Next Phase Readiness

- `36-UAT-R2.md` is ready for the owner to run on his next device sitting — nothing in it depends on a URL, a prerequisite that doesn't exist, or data judged before a sync.
- `WINDOWS.md` now reports `open_count: 5` (entries 1, 3, 4, 7, 11). If `workflow.windows_enforce` is active, `/gsd-ship` remains blocked on this count — entry 7 cannot close without the owner's device confirmation (R1), and entries 1/3/4/11 were never in scope for this gap closure.
- Phase 36 itself is not complete: three WINDOWS entries remain open and the device re-verification sitting has not yet happened. This plan's job was to make that sitting possible and honest, not to close the phase.

---
*Phase: 36-connect-google-calendar-without-hunting-for-a-url*
*Completed: 2026-10-06*

## Self-Check: PASSED

- FOUND: `.planning/phases/36-connect-google-calendar-without-hunting-for-a-url/36-UAT-R2.md`
- FOUND: `.planning/WINDOWS.md` (modified, consistency-checked)
- FOUND: commit `a858fcc` is an ancestor of HEAD
- FOUND: commit `06e2c74` is an ancestor of HEAD
