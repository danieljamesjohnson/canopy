---
phase: 30-breaks-in-committed-time
plan: 01
subsystem: testing
tags: [flutter_test, schedule_generator, tdd-red-proof]

# Dependency graph
requires:
  - phase: 28-the-day-is-a-lattice
    provides: the 30-minute lattice / footprint-reservation pattern this plan's tests hold the commitment-window loop to
  - phase: 29-breaks-you-can-see
    provides: the sub-compact break rendering tier that makes an inserted commitment break visible once 30-03 lands
provides:
  - "6 new COMMITBREAK regression tests, all calling the real ScheduleGeneratorService.generate() against a commitment-block fixture"
  - "6 existing tests re-pointed from the pre-Phase-30 'no breaks inside a commitment block' shape to the post-fix shape, none deleted"
  - "30-RED-generator.txt: by-name RED evidence proving 11 of 12 touched tests fail against the unfixed engine, captured at --concurrency=1"
  - "Proof (via git diff --stat) that this plan's commits touch only test/ paths — the wave boundary 30-03 must respect"
affects: [30-02, 30-03, 30-04, 30-05]

# Actuals (#2632)
actuals:
  tokens: 14400
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "RED-proof wave boundary: every regression test written and proven failing before any lib/ change, per STATE.md's carry-forward invariant (v1.5 shipped two defects behind tests that could not fail)"
    - "Every COMMITBREAK test filters to anchoredStartMinutes != null and sorts before indexing, so a change in STEP D's sort logic can never make a test pass by accident"

key-files:
  created:
    - .planning/phases/30-breaks-in-committed-time/30-RED-generator.txt
  modified:
    - test/services/schedule_generator_test.dart

key-decisions:
  - "D-30-01 — a commitment block runs its OWN cadence counter, fresh per block instance, not shared with _assignSyntheticStartTimes's discretionary breakCount. A shared counter would count in code-execution order (commitment loop runs first) rather than wall-clock order (a discretionary chunk can land chronologically before a 09:00 block), breaking the 'Nth chunk of your day' cadence model unpredictably — directly contradicting CLAUDE.md's product position that an unpredictable schedule is one the user won't trust. Settled on a simulation of the real packing loop (not an estimate): a 6-hour block at mood 3 yields 10 work + 10 short + 2 long breaks = 360 minutes exactly, matching COMMITBREAK-01/CADENCE's captured RED failure (Expected 10, Actual 14 bare work chunks)."
  - "D-30-02 — STEP E's trailing-short-break trim narrows to commitmentId == null. The unfixed trim strips ANY trailing short break regardless of origin; once Step 1 emits its own break chunks, a tail-stretched commitment break can legitimately be the day's last chunk, and the unnarrowed trim would silently delete however many minutes the stretch absorbed. COMMITBREAK-01/STEP-E is this decision's regression test — captured RED (Expected shortBreak, Actual work — the unfixed engine has no break there to delete, documenting exactly what the fix must prevent from regressing)."
  - "D-30-03 — lib/providers/schedule_notifier.dart:addEventToday is IN scope for Phase 30 (plans 30-02/30-04), a deliberate scope extension beyond the ROADMAP's two-line root-cause citation. It carries an identical bare cursor += 25 walk under a doc comment claiming it mirrors the generator; fixing only the generator would leave a second, unfixed path to the same owner-reported symptom (a day generated via check-in shows commitment breaks, but an event added mid-day from Today does not). This plan (30-01) does not touch that file — recorded here per the plan's instruction to carry all four decisions in this SUMMARY regardless of which plan implements each."
  - "D-30-04 — commitment break chunks carry commitmentId: block.id. Two reasons: (1) it is the exact discriminator D-30-02's narrowed STEP E trim depends on to distinguish a commitment break from a discretionary one; (2) attribution honesty — those minutes belong to the user's committed window. 30-RESEARCH.md's Pitfall 6 premise (that this would silently pick up tertiary-container commitment styling via chunk_card.dart:449) is corrected in the plan: ChunkCard.build() switches on chunkType first and routes break chunks to _buildBreak, never reaching the isCommitment branch — a break chunk's rendering is unaffected by commitmentId. Every assertion in COMMITBREAK-01/PRIMARY checks commitmentId == block.id on all 9 anchored chunks (work AND break)."
  - "WR-03's second loop, which previously read syntheticStartMinutes only (invisible to an anchored break), is re-scoped to displayStartMinutes and filtered to commitmentId == null — a legitimate anchored commitment break inside the window is no longer mistaken for the discretionary-break violation the test exists to catch."
  - "GUARD 7 (LATTICE-01/D-01)'s stale comment claiming D-01/D-02 'only affect the free-slot start rounding, never the anchored chunks themselves' is corrected in place — that sentence was 30-RESEARCH.md's named misreading of the actual root cause. The window's own boundaries (D-01) stay a GUARD (green before and after); the chunk composition inside the window is exactly what COMMITBREAK-01 changes, and now fails pre-fix as expected."

patterns-established:
  - "Six-test COMMITBREAK regression group, sibling to Phase 28's LATTICE group, each test's leading comment states (a) which requirement it proves, (b) the arithmetic derivation of its expected sequence, (c) RED vs GUARD classification — carried forward from Phase 28/29's convention."

requirements-completed: []  # COMMITBREAK-01/02 are proven by tests here but NOT yet satisfied — the engine fix lands in 30-03. Marking complete now would be false; left empty deliberately.

coverage: []  # Test-only wave; no user-facing deliverable to classify yet. Coverage is established once 30-03's fix turns these RED tests GREEN.

duration: ~10min
completed: 2026-08-24
status: complete
---

# Phase 30 Plan 01: COMMITBREAK Regression Tests Summary

**Six new tests built from a real commitment-block fixture (never a hand-built chunk list) prove Phase 30's fix is needed — 5 fail against the unfixed engine as RED, plus six existing tests re-pointed off the pre-phase "no breaks in a commitment" shape, all captured by name in 30-RED-generator.txt with a git-proven zero-`lib/` wave boundary.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-24T09:12:00-05:00 (approx, first Read call)
- **Completed:** 2026-08-24T09:19:44-05:00
- **Tasks:** 3
- **Files modified:** 2 (1 test file, 1 new evidence file)

## Accomplishments
- Added `group('COMMITBREAK — breaks inside a committed block')` with 6 named tests (PRIMARY, D-01, CADENCE, TAIL, STEP-E, NO-DOUBLE-BOOK), every one calling the real `sut.generate()` against a `makeBlock(...)` commitment fixture — the ROADMAP's own "the test gap is the actual defect behind the defect" observation, closed.
- Re-pointed 6 existing tests (Test 2, Test 10, Test 13, WR-03, LATTICE-02/D-05, LATTICE-01/D-01 "GUARD 7") that encoded the pre-phase shape, without deleting any of them — baseline test count only grew (70 → 76 in this file).
- Captured `30-RED-generator.txt`: by-name RED evidence at `--concurrency=1`, classifying all 12 touched tests RED/GUARD, with 11 RED tests genuinely failing and 1 GUARD (NO-DOUBLE-BOOK) genuinely passing — no test needed re-wording to force a failure.
- Proved via `git diff --stat` that this plan's two task commits touch only `test/services/schedule_generator_test.dart` — zero `lib/` paths — discharging the plan's explicit wave-boundary requirement for `30-03`.

## Task Commits

Each task was committed atomically:

1. **Task 1: The COMMITBREAK regression group — six tests, built from a commitment block** - `6a8b054` (test)
2. **Task 2: Re-point the six existing tests that assert the pre-phase "no breaks in a commitment" shape** - `d131603` (test)
3. **Task 3: Capture by-name RED evidence and commit the test-only wave** - `2aa16d4` (docs)

_No TDD RED→GREEN cycle applies here — this entire plan IS the RED half of the phase's RED-proof wave boundary; GREEN lands in `30-03`._

## Files Created/Modified
- `test/services/schedule_generator_test.dart` - Added the 6-test COMMITBREAK group; re-pointed Test 2, Test 10, Test 13, WR-03, LATTICE-02/D-05, LATTICE-01/D-01 to the post-fix shape
- `.planning/phases/30-breaks-in-committed-time/30-RED-generator.txt` - By-name RED evidence, classification table, and git wave-boundary proof

## Decisions Made
See `key-decisions` in frontmatter — D-30-01 through D-30-04 carried per the plan's `<output>` instruction, plus two test-authoring corrections (WR-03's re-scoping, GUARD 7's comment fix) discovered while re-pointing Task 2.

## Deviations from Plan

None — plan executed exactly as written. Every arithmetic derivation in the plan's `must_haves`/`acceptance_criteria` (all sourced from 30-RESEARCH.md's real-prototype simulation) matched what the real `generate()` produces once traced by hand; no test needed adjustment from its planned shape, and no RED-predicted test came back green.

## Issues Encountered

None. The one thing worth flagging as a non-issue: 30-RESEARCH.md's `LATTICE-02/D-05` narrow/control fixtures use mood 1 (N=2) for the *commitment block's own* cadence, distinct from the discretionary loop's mood-1 cadence exercised earlier in the same test — both derive from the same `_moodBreakCadence` table via the block's own fresh counter (D-30-01), so no special-casing was needed; the arithmetic simply composes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `30-RED-generator.txt` is the executable specification `30-03` must turn GREEN: 11 named RED failures across `test/services/schedule_generator_test.dart`, with `COMMITBREAK-01/PRIMARY` as the single end-to-end assertion crossing Step 1 → STEP A → STEP B → STEP C → STEP D → STEP E in one call to `generate()` — this plan's tracer-equivalent specification per the plan's own framing.
- `git diff --stat` confirms zero `lib/` changes from this plan — `30-03` starts from a clean `lib/` baseline with no test-file collision risk.
- `COMMITBREAK-01/NO-DOUBLE-BOOK` already passes (GUARD) and must keep passing after `30-03` — a regression there would mean the fix broke STEP B's window-merge dependency (30-RESEARCH.md Pitfall 2), not just failed to add breaks.
- `D-30-03` (the `addEventToday` duplicate-defect scope decision) is recorded here for `30-02`/`30-04` to act on; this plan did not touch `lib/providers/schedule_notifier.dart`.

---
*Phase: 30-breaks-in-committed-time*
*Completed: 2026-08-24*

## Self-Check: PASSED

All claimed files exist on disk (`test/services/schedule_generator_test.dart`,
`.planning/phases/30-breaks-in-committed-time/30-RED-generator.txt`, this
SUMMARY) and all three task commit hashes (`6a8b054`, `d131603`, `2aa16d4`)
resolve in `git log --oneline --all`.
