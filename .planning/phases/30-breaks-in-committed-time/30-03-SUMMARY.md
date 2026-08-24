---
phase: 30-breaks-in-committed-time
plan: 03
subsystem: scheduling-engine
tags: [flutter, dart, schedule_generator, lattice, tdd-green-proof]

# Dependency graph
requires:
  - phase: 28-the-day-is-a-lattice
    provides: the 30-minute lattice / footprint-reservation pattern (_assignSyntheticStartTimes) this plan's buildCommitmentChunks mirrors
  - phase: 29-breaks-you-can-see
    provides: the sub-compact break rendering tier that makes the newly-inserted commitment breaks visible
  - plan: 30-01
    provides: the 12 generator-side RED/GUARD tests (30-RED-generator.txt) this plan turns GREEN
  - plan: 30-02
    provides: the second-path RED evidence (30-RED-secondpath.txt) whose COMMITBREAK-01/RENDER entry this plan clears
provides:
  - "ScheduleGeneratorService.buildCommitmentChunks — the single public static implementation of commitment-window chunking (work + breaks), shared with ScheduleNotifier.addEventToday in plan 30-04"
  - "ScheduleGeneratorService.breakCadenceForMood — the mood→N lookup, exposed for the same reason"
  - "Step 1 rewritten to call buildCommitmentChunks; STEP E's trailing trim narrowed to commitmentId == null (D-30-02)"
  - "30-GREEN-wave2.txt — by-name RED→GREEN cross-check against both 30-01 and 30-02's RED evidence, plus the git-proven zero-test wave boundary"
affects: [30-04, 30-05]

# Actuals (#2632)
actuals:
  tokens: 5922
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Commitment-window footprint reservation mirrors _assignSyntheticStartTimes's isBoundary/breakFootprint shape exactly, rather than a second independently-invented algorithm — per 30-RESEARCH.md's explicit 'mirror, don't reinvent' recommendation"
    - "Tracer-then-expand within a single file: Task 1 landed a short-break-only intermediate state end-to-end through every layer (Step 1 -> STEP A -> STEP B -> STEP C -> STEP D -> STEP E), verified by name against the exact 4 wave-1 tests predicted to remain RED, before Task 2 added the cadence boundary on top"

key-files:
  created:
    - .planning/phases/30-breaks-in-committed-time/30-GREEN-wave2.txt
  modified:
    - lib/services/schedule_generator.dart

key-decisions:
  - "D-30-01 (implemented) — buildCommitmentChunks gives each commitment block its OWN cadence counter (blockBreakCount), local to the call and fresh per block instance, never shared with _assignSyntheticStartTimes's discretionary breakCount. A shared counter would count in code-execution order (Step 1 finishes before Steps 2-4 collect discretionary demand) rather than wall-clock order (a discretionary chunk can land chronologically before a 09:00 commitment), breaking the 'Nth chunk of your day' cadence model unpredictably — directly against CLAUDE.md's product position that an unpredictable schedule is one the user won't trust. Verified by COMMITBREAK-01/CADENCE: a 6-hour block at mood 3 (N=4) now yields exactly 10 work + 10 short + 2 long breaks = 360 minutes exactly, matching 30-RESEARCH.md's real-prototype simulation to the minute."
  - "D-30-02 (implemented) — STEP E's trailing-short-break trim is narrowed to `result.last.chunkType == ChunkType.shortBreak && result.last.commitmentId == null`. The unnarrowed trim (pre-phase) stripped ANY trailing short break regardless of origin; once Step 1 emits its own break chunks, a tail-stretched commitment break can legitimately be the day's last chunk, and the unnarrowed trim would silently delete however many real committed minutes the stretch absorbed. Verified by COMMITBREAK-01/STEP-E: a 540-610 block's last chunk (a short break tail-stretched from 5 to 15 minutes, 595-610) survives STEP E intact."
  - "D-30-04 (implemented, carried from 30-01/30-02) — commitment break chunks carry commitmentId: block.id, same as their sibling work chunks. Two reasons: (1) it is the exact discriminator D-30-02's narrowed STEP E trim depends on to distinguish a commitment break from a discretionary one; (2) attribution honesty — those minutes belong to the user's committed window. This plan's own COMMITBREAK-01/PRIMARY assertion (every anchored chunk in the 9-chunk ROADMAP-repro fixture carries commitmentId == block.id) and the pre-existing COMMITBREAK-01/RENDER test (30-02, now GREEN) both confirm 30-RESEARCH.md's Pitfall 6 premise was wrong: ChunkCard.build() switches on chunkType before ever reaching the isCommitment/tertiaryContainer branch, so a commitment break renders as an ordinary break, not commitment-tinted. Correction to 30-RESEARCH.md Pitfall 6 recorded here per the plan's <output> instruction — no visible styling consequence exists from setting commitmentId on a break chunk."
  - "Plan-authoring inconsistency, documented rather than silently reconciled (per this plan's own <critical> instruction): Task 3's acceptance criteria named exactly 3 tests (COMMITBREAK-01/ADD-EVENT, COMMITBREAK-02/ADD-EVENT, COMMITBREAK-01/ADD-EVENT-TRIM) as the still-RED-by-design set clearing in wave 3. The real full-suite run has 5 RED failures in that file (the plan's list both wrongly includes COMMITBREAK-02/ADD-EVENT, which 30-02's own SUMMARY documents as an already-passing GUARD, and omits 2 real re-pointed RED tests — 'editing an event re-anchors today' and 'creates a minimal today schedule when none exists'). The plan's real invariant ('every failure belongs to schedule_notifier_add_event_test.dart') holds and is proven; 30-GREEN-wave2.txt records the accurate 5-RED/1-GUARD table so plan 30-04 isn't misled about what remains."

patterns-established:
  - "Public static commitment-chunking helper (buildCommitmentChunks) as the single implementation shared between generate() and addEventToday, replacing two independent bare-loop copies of the same defect — the shape plan 30-04 will wire ScheduleNotifier into."

requirements-completed: [COMMITBREAK-01, COMMITBREAK-02]

coverage:
  - id: D1
    description: "A break is emitted between consecutive work chunks inside a commitment block, on the 25+5(+30) lattice, seeded from the block's own unrounded start"
    requirement: "COMMITBREAK-01"
    verification:
      - kind: unit
        ref: "test/services/schedule_generator_test.dart#COMMITBREAK-01/PRIMARY"
        status: pass
      - kind: unit
        ref: "test/services/schedule_generator_test.dart#COMMITBREAK-01/CADENCE"
        status: pass
      - kind: unit
        ref: "test/services/schedule_generator_test.dart#COMMITBREAK-01/TAIL"
        status: pass
      - kind: unit
        ref: "test/services/schedule_generator_test.dart#COMMITBREAK-01/STEP-E"
        status: pass
      - kind: unit
        ref: "test/services/schedule_generator_test.dart#COMMITBREAK-01/NO-DOUBLE-BOOK"
        status: pass
      - kind: automated_ui
        ref: "test/screens/lattice_break_pair_test.dart#COMMITBREAK-01/RENDER"
        status: pass
    human_judgment: false
  - id: D2
    description: "The commitment's own start and end times are unchanged after generate() (D-01 preserved) — never rounded onto the lattice"
    requirement: "COMMITBREAK-02"
    verification:
      - kind: unit
        ref: "test/services/schedule_generator_test.dart#COMMITBREAK-02/D-01"
        status: pass
      - kind: unit
        ref: "test/services/schedule_generator_test.dart#LATTICE-01/D-01"
        status: pass
    human_judgment: false

duration: ~15min
completed: 2026-08-24
status: complete
---

# Phase 30 Plan 03: Generator Fix — Breaks Inside Committed Windows Summary

**`ScheduleGeneratorService.buildCommitmentChunks` mirrors the existing footprint-reservation lattice pattern for commitment windows, with its own per-block cadence counter (D-30-01), and STEP E's trailing trim is narrowed to `commitmentId == null` (D-30-02) so a tail-stretched commitment break can never be silently deleted — turning all 12 wave-1 generator-side tests plus the cross-file render guard GREEN, with zero test-file changes.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-24 (session start)
- **Completed:** 2026-08-24T09:39:55-05:00
- **Tasks:** 3
- **Files modified:** 2 (1 source file, 1 new evidence file)

## Accomplishments

- Added `ScheduleGeneratorService.buildCommitmentChunks` and `.breakCadenceForMood` as public static members, exposed for plan 30-04 to share (the same helper `addEventToday` will call instead of keeping a third copy of the loop).
- Rewrote Step 1's bare `cursor += 25` walk to call the new helper — commitment windows now get breaks on the same 25+5(+30) lattice as discretionary time, seeded from the block's own unrounded start (D-01/COMMITBREAK-02 preserved, never rounded).
- Gave the commitment loop its own independent cadence counter (D-30-01), settled by the 6-hour-block simulation from 30-RESEARCH.md and verified to the minute by COMMITBREAK-01/CADENCE (10 work + 10 short + 2 long = 360 minutes exactly).
- Narrowed STEP E's trailing-short-break trim to `commitmentId == null` (D-30-02), preventing a tail-stretched commitment break from being silently deleted.
- Landed as a tracer-then-expand sequence within the single file: Task 1's short-break-only intermediate state was verified end-to-end against the exact 4 tests 30-RESEARCH.md predicted would still fail (COMMITBREAK-01/PRIMARY, COMMITBREAK-01/CADENCE, COMMITBREAK-02/D-01, COMMITBREAK-01/RENDER), before Task 2 added the cadence boundary on top.
- Captured `30-GREEN-wave2.txt`: by-name RED→GREEN cross-check against both `30-RED-generator.txt` and `30-RED-secondpath.txt`, plus a git-proven zero-`test/`-path wave boundary across this plan's two `lib/`-touching commits.

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end tracer — one break inside one committed window** - `e20894b` (feat)
2. **Task 2: Expand the slice — per-block cadence counter, long break, tail** - `014bf02` (feat)
3. **Task 3: Full-suite gate, prove the wave boundary from git** - `1d7cced` (docs)

_No TDD RED→GREEN cycle applies to this plan itself — this plan IS the GREEN half of the phase's RED-proof wave boundary; the RED tests were written and proven failing in 30-01/30-02._

## Files Created/Modified

- `lib/services/schedule_generator.dart` — Added `buildCommitmentChunks`/`breakCadenceForMood`; rewrote Step 1; narrowed STEP E's trim; updated STEP C's and the class doc comment's stale pre-phase prose.
- `.planning/phases/30-breaks-in-committed-time/30-GREEN-wave2.txt` — By-name RED→GREEN cross-check, full-suite result, and git wave-boundary proof.

## Decisions Made

See `key-decisions` in frontmatter — D-30-01, D-30-02, and D-30-04 implemented and documented in-source with their reasoning (D-30-01/D-30-02 as doc comments and inline comments in `schedule_generator.dart`; D-30-04 already landed in 30-01/30-02's tests, confirmed here by the passing render guard). One plan-authoring inconsistency in Task 3's acceptance criteria is documented rather than silently worked around — see key-decisions and `30-GREEN-wave2.txt`'s own "DEVIATION NOTE" section for the full accounting.

## Deviations from Plan

### Auto-fixed Issues

None — no bugs, missing functionality, or blocking issues required Rule 1-3 fixes. The implementation followed 30-RESEARCH.md's verified prototype shape directly.

### Documented plan-authoring inconsistency (not a code deviation)

**1. Task 3's acceptance criteria misnames the still-RED addEventToday test set**
- **Found during:** Task 3 (full-suite gate)
- **Issue:** The plan's acceptance criteria lists exactly 3 tests as "still-RED-by-design, clearing in wave 3": `COMMITBREAK-01/ADD-EVENT`, `COMMITBREAK-02/ADD-EVENT`, `COMMITBREAK-01/ADD-EVENT-TRIM`. The real full-suite run has 5 RED failures in `test/providers/schedule_notifier_add_event_test.dart`, and `COMMITBREAK-02/ADD-EVENT` is not one of them — 30-02's own SUMMARY documents it as an unexpected GUARD (already passing pre-fix, since `addEventToday`'s pre-existing tail-stretch and D-01 preservation were never actually broken).
- **Fix:** No code change — this is a documentation-accuracy issue in the plan text, not a defect. `30-GREEN-wave2.txt`'s cross-check table records the accurate 5 RED tests (the 3 plan-named minus the incorrect GUARD, plus the 2 omitted re-pointed tests) and 1 GUARD, with an explicit "DEVIATION NOTE" explaining the discrepancy so plan 30-04 has an accurate list to work from.
- **Files modified:** `.planning/phases/30-breaks-in-committed-time/30-GREEN-wave2.txt` (evidence only; no `lib/` or `test/` change).
- **Verification:** Cross-checked every test name in the file against the actual `flutter test --concurrency=1 --reporter expanded` output this session.
- **Committed in:** `1d7cced` (Task 3 commit)

---

**Total deviations:** 1 documented (plan-text inaccuracy, not a code defect)
**Impact on plan:** None on the shipped code. The real invariant the plan's acceptance criteria actually depends on ("every full-suite failure belongs to `schedule_notifier_add_event_test.dart`") holds and is proven — 5/5 failures, 0 elsewhere.

## Issues Encountered

None. Every arithmetic prediction from 30-RESEARCH.md's real-prototype simulation (the cadence decision's 6-hour-block walkthrough, the tail-arithmetic worked-examples table, the exact test-by-test RED classification) matched what the actual implementation produced, verified by running the real suite rather than assumed.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `lib/providers/schedule_notifier.dart:addEventToday` still carries the identical unfixed `cursor += 25` walk and unnarrowed `_trimTrailingNonWork` — 5 named RED tests in `test/providers/schedule_notifier_add_event_test.dart` are exactly what plan 30-04 must turn GREEN (see `30-GREEN-wave2.txt`'s Part B table for the accurate list, correcting this plan's own Task 3 text).
- `ScheduleGeneratorService.buildCommitmentChunks` and `.breakCadenceForMood` are public and static specifically so 30-04 can call them from `ScheduleNotifier` instead of hand-rolling a third copy of this loop — this was the explicit design intent stated in 30-03-PLAN.md's `<key_links>`.
- `git diff --stat` confirms zero `lib/providers/` changes from this plan — 30-04 starts from a clean baseline with no collision risk.
- A real-browser screenshot (port 8143, debug build, per 30-VALIDATION.md's Manual-Only Verifications) is still required before phase close — deferred to 30-05 per the phase's own plan sequencing, not this plan's scope.

---
*Phase: 30-breaks-in-committed-time*
*Completed: 2026-08-24*

## Self-Check: PASSED

All claimed files exist on disk (`lib/services/schedule_generator.dart`,
`.planning/phases/30-breaks-in-committed-time/30-GREEN-wave2.txt`, this
SUMMARY) and all three task commit hashes (`e20894b`, `014bf02`, `1d7cced`)
resolve in `git log --oneline --all`.
