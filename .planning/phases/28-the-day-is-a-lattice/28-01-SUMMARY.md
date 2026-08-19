---
phase: 28-the-day-is-a-lattice
plan: 01
subsystem: testing
tags: [flutter, dart, flutter_test, schedule_generator, lattice]

# Dependency graph
requires:
  - phase: 21-mood-scaled-breaks-honest-rationale
    provides: "_moodBreakCadence table {1:2,2:3,3:4,4:4,5:5} that N is keyed on"
provides:
  - "Rewritten schedule_generator_test.dart asserting the 30-minute lattice shape (LATTICE-01/LATTICE-02) and D-01..D-06"
  - "28-RED-unit.txt: raw evidence that 16 tests fail against the unfixed engine, 2 guards pass"
affects: [28-02, 28-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Fixture arithmetic verified by direct simulation of the packing algorithm before writing assertions, not hand-derived"
    - "RED-PROOF / GUARD comment labels on new tests so evidence files read unambiguously"

key-files:
  created:
    - .planning/phases/28-the-day-is-a-lattice/28-RED-unit.txt
  modified:
    - test/services/schedule_generator_test.dart

key-decisions:
  - "Corrected the plan's commitment-block-chunking assumption (a 45-min window emits ONE anchored chunk stretched to the full window, not two chunks of 25+20) after empirical verification against the actual code; rewrote the D-01 GUARD and narrow-slot fallback (RED-PROOF 6) fixtures to match verified behavior while preserving each test's intent"
  - "Used a Python simulation of the future (fixed) packing algorithm, cross-checked against every fixture's actual current-engine output via a throwaway probe test file, to derive exact expected sequences before writing any assertion — given the plan's own emphasis on RED-proof correctness, hand arithmetic was not trusted for 8 new tests plus 10 rewrites"

requirements-completed: [LATTICE-01, LATTICE-02]

# Metrics
duration: ~15min
completed: 2026-08-19
---

# Phase 28 Plan 01: Prove the Lattice RED Summary

**Rewrote 10 blast-radius tests and added 8 new LATTICE-01/LATTICE-02/D-04 tests in `schedule_generator_test.dart`, proving all 16 fail against the unfixed engine (2 guards green) — zero production code touched.**

## Performance

- **Duration:** ~15 min (init 12:18:45Z → final commit 12:33:30Z)
- **Started:** 2026-08-19T12:18:45Z
- **Completed:** 2026-08-19T12:33:30Z
- **Tasks:** 2 completed
- **Files modified:** 2 (`test/services/schedule_generator_test.dart`, `.planning/phases/28-the-day-is-a-lattice/28-RED-unit.txt`)

## Accomplishments

- Rewrote the 10 existing tests RESEARCH.md's Blast Radius named (Test 6, Test 7, WR-01, the 5 BREAK-01 mood tests, BREAK-02, and the `startFloorMinutes` rounding test) to the corrected 30-minute lattice shape, and captured raw `flutter test` output proving exactly those 10 fail against the unfixed engine — nothing else.
- Added a new `group('LATTICE — the day is a 30-minute lattice')` with 8 tests: 6 RED-PROOF (mod-30 boundary check across all moods, D-02 post-commitment slot rounding, LATTICE-02 long-break count/duration, the owner's-day regression asserting the full 9-chunk sequence verbatim, the cadence-boundary adjacency shape, and the narrow-slot partial-reservation fallback proven via a 3-fixture NARROW/CONTROL/BOUNDED comparison) plus 2 GUARD tests (D-01 commitment chunks stay unrounded, D-04 per-mood work-chunk counts are pinned).
- Verified every fixture's expected sequence with a Python simulation of the future packing algorithm, cross-checked against the real engine's *current* output via a throwaway probe test (deleted before any real edit), rather than trusting hand arithmetic — this caught and corrected a material error in the plan's own narrative (see Deviations).
- `28-RED-unit.txt` holds the full expanded-reporter capture: 70 tests declared, exactly 16 failing, 54 passing.

## Task Commits

1. **Task 1: Rewrite the 10 blast-radius tests, prove exactly those 10 RED** - `85f9ed2` (test)
2. **Task 2: Add LATTICE-01/LATTICE-02/D-04 assertion groups, prove 16 RED** - `ca1822d` (test)

_No TDD RED/GREEN/REFACTOR cycle applies here — this is a `type: execute` plan whose entire deliverable is the RED half; the GREEN half is plan 28-03._

## Files Created/Modified

- `test/services/schedule_generator_test.dart` - 10 tests rewritten to the lattice shape (62→62 declarations after Task 1), 8 new LATTICE tests appended (62→70 declarations after Task 2)
- `.planning/phases/28-the-day-is-a-lattice/28-RED-unit.txt` - raw `flutter test --reporter expanded` capture proving 16 failures against the unfixed engine

## Decisions Made

- **Fixture arithmetic verified by simulation, not hand math.** Given the plan's explicit warning that a RED-proof plan's entire value depends on getting the expected (post-fix) sequences right, I wrote a Python simulator of the intended fixed packing algorithm (additive `breakDur = 5 + (isBoundary ? 30 : 0)`, no `discIdx+1<length` guard, STEP E trimming only trailing short breaks, D-02's post-commitment rounding) and ran every fixture through it, then cross-checked the *current*-engine output for the same fixtures via a scratch probe test (`test/_scratch_lattice_probe_test.dart`, written, run, and deleted before any real edit — never committed).
- **Corrected a commitment-block-chunking assumption baked into the plan's own narrative.** See Deviations below — this is the most significant finding of this plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug in my own test authorship, corrected before commit] The plan's narrative assumed a 45-minute commitment window emits TWO anchored chunks; the actual code emits ONE.**

- **Found during:** Task 2, while deriving fixtures for the D-01 GUARD test and RED-PROOF 6 (the narrow-slot fallback test).
- **Issue:** `28-CONTEXT.md`/`28-RESEARCH.md`/`28-01-PLAN.md` all describe a 45-minute commitment block (e.g. `makeBlock(startMinutes: 555, endMinutes: 600)`) as producing two anchored chunks: one 25-minute chunk and a second, "stretched," 20-minute tail chunk. I verified this empirically against the actual `generate()` commitment-chunking loop (`lib/services/schedule_generator.dart:246-282`, unmodified by this plan) with a throwaway probe test. The loop only starts a new 25-minute chunk while `cursor + 25 <= block.endMinutes`; for a 45-minute window that condition is true only once, so exactly **one** anchored chunk is created, then stretched to cover the *entire* 45-minute window (`lastForBlock.durationMinutes = endMinutes - anchoredStart`, i.e. 45, not 20). A 60-minute window (the file's own default `makeBlock()` params, already documented in-file as "60-min window → 2 slots") does correctly split into two real chunks — the plan's "two chunks" mental model appears to have been drawn from that 60-minute case and misapplied to the 45-minute fixtures.
- **Fix:** Re-derived every affected fixture's expected sequence against the *verified* single-anchored-chunk behavior:
  - **D-01 GUARD (test 7):** switched the fixture from the plan's proposed 570-615 block (which the plan wrongly described as producing anchored chunks at 570/25 and 595/20) to `makeBlock()`'s default 540-600 (a genuine 60-minute, 2-chunk window), which really does produce two anchored chunks — 540 (25 min, unstretched) and 565 (35 min, stretched), the second one deliberately off-lattice (`565 % 30 == 25`). This preserves the test's intent (prove a commitment chunk's start is never rounded) using a fixture that actually exhibits it.
  - **RED-PROOF 6, NARROW (a):** `makeBlock(555, 600)` produces one anchored chunk at 555 lasting 45 minutes (not two chunks at 555/25 and 580/20). Corrected the expected result to 5 chunks total (not the plan's stated 6): `W@480 SB@505 W@510 SB@535 W@555(45,anchored)`, with the fallback reserving only the 5-minute short break after the boundary chunk (chunk 2) and no long break anywhere.
  - **RED-PROOF 6, CONTROL (b):** `makeBlock(585, 630)` likewise produces one anchored chunk at 585 lasting 45 minutes. Corrected the expected result to 6 chunks (not the plan's stated 7): `W@480 SB@505 W@510 SB@535 LB@540(30) W@585(45,anchored)` — the core assertions the plan actually cared about (exactly one long break, `durationMinutes == 30`, `syntheticStartMinutes == 540`) are unaffected by this correction and hold as written.
  - **RED-PROOF 2 (D-02) and LATTICE-01 (test 1):** unaffected — their assertions (discretionary-chunk `%30==0`, and "the first post-commitment discretionary chunk starts at 630") don't depend on the anchored-chunk *count*, only on the discretionary chunks' positions, which I'd already verified independently.
- **Impact on plan's pinned counts:** none. The plan's exact-count pins that matter for the RED-proof invariant — 10 failures after Task 1, 62 then 70 `test(` declarations, 16 failures after Task 2, both GUARDs green — all hold exactly as specified. Only the internal chunk-count narrative for one new test's three sub-fixtures needed correction, and I corrected it toward the verified engine behavior rather than toward the plan's stated (incorrect) numbers, per this plan's own instruction to report and resolve such discrepancies rather than silently reconciling them either direction.
- **Files modified:** `test/services/schedule_generator_test.dart` (within Task 2's own new-test authorship — no rewrite of already-committed Task 1 content was needed).
- **Verification:** `flutter test test/services/schedule_generator_test.dart --reporter expanded` — the corrected fixtures are RED for the exact reasons predicted (NARROW test fails its `expect(narrow.length, 5)` assertion with `Actual: <4>`, matching the pre-fix engine's real, verified 4-chunk output).
- **Committed in:** `ca1822d` (Task 2 commit).

**2. [Rule 1 - Bug] `grep -c "the owner's day"` initially returned 2, not the plan's pinned 1.**

- **Found during:** Task 2 acceptance-criteria self-check, after writing RED-PROOF 4 (whose test name legitimately contains the phrase) and RED-PROOF 6's part (c) comment (which also referenced "the owner's day" informally).
- **Fix:** Reworded RED-PROOF 6's comment to say "the 4-habit mood-3 fixture (the RED-PROOF 4 regression)" instead, preserving meaning without duplicating the pinned phrase.
- **Files modified:** `test/services/schedule_generator_test.dart`.
- **Verification:** `grep -c "the owner's day" test/services/schedule_generator_test.dart` → `1`.
- **Committed in:** `ca1822d` (Task 2 commit — the file was not yet committed when this was caught, so no separate fix commit was needed).

---

**Total deviations:** 2 auto-fixed (both Rule 1, both corrections to my own in-progress test authorship, caught before commit via empirical verification and the acceptance-criteria self-check).
**Impact on plan:** No scope change, no production code touched, no change to any of the plan's pinned counts. The one substantive finding — the commitment-block-chunking arithmetic in `28-CONTEXT.md`/`28-RESEARCH.md`/`28-01-PLAN.md` was wrong for 45-minute windows — is worth flagging to whoever authors 28-03 or a future planning pass, since the same wrong assumption could resurface there.

## Issues Encountered

None beyond the deviations documented above.

## RED Evidence — Exact Failing-Test List

From `.planning/phases/28-the-day-is-a-lattice/28-RED-unit.txt` (70 tests declared, 54 passing, 16 failing, `flutter analyze` clean):

**The 10 rewritten blast-radius tests (Task 1):**
1. `Test 6: mood=3 break pattern with 4 work chunks (boundary chunk is the last chunk)` — expected 9, actual 7
2. `Test 7: mood=1 break pattern with 2 work chunks (boundary chunk is the last chunk)` — expected 5, actual 3
3. `WR-01: emitted long break matches reserved slot — no overlapping synthetic times` — expected 30, actual 25
4. `startFloorMinutes ... a 15:42 floor starts the chunk at 16:00 (rounded up to 30), not 8 AM` — expected 960, actual 945
5. `BREAK-01: mood=1 places a long break after every 2 work chunks`
6. `BREAK-01: mood=2 places a long break after every 3 work chunks (...)`
7. `BREAK-01: mood=3 places a long break after every 4 work chunks (baseline unchanged)`
8. `BREAK-01: mood=4 places a long break after every 4 work chunks (...)`
9. `BREAK-01: mood=5 places a long break after every 5 work chunks`
10. `BREAK-02: only 5-min short breaks and 30-min long breaks are ever emitted, at every mood`

**The 6 new RED-PROOF tests (Task 2):**
11. `LATTICE-01: every cell starts on a 30-minute boundary, at every mood`
12. `LATTICE-01/D-02: work resumes on the lattice after an off-boundary commitment`
13. `LATTICE-02: exactly floor(workChunks / N) long breaks of exactly 30 minutes, at every mood`
14. `LATTICE-02/D-05: the owner's day — mood 3, N=4, 4 work chunks — still gets its long break` — expected 9-chunk sequence ending `longBreak(30)`, actual 7 chunks ending `work`, zero long breaks
15. `LATTICE-02: the Nth chunk closes its own cell AND is followed by a separate 30-minute cell`
16. `LATTICE-02/D-05: a slot too narrow for the boundary footprint reserves the short break only — capacity-driven, and it does not fire on a nominal day` — expected 5 (NARROW), actual 4

**GUARD tests confirmed GREEN (not in the failure list):**
- `LATTICE-01/D-01: a fixed commitment keeps its own wall-clock start, unrounded`
- `D-04: neither _moodCap nor the day end moves — per-mood work-chunk counts are unchanged`

No test failed for an unexpected reason — every failure in the list above is one of the 16 named tests, and every named test appears exactly once. No collateral RED: a full-suite run (`flutter test`) shows 559 passing / 16 failing, with the 16 failures being exactly this file's 16 named tests and nothing elsewhere in the codebase.

## D-04 Guard — Per-Mood Work-Chunk Counts Pinned

Measured directly against the current (unfixed) engine for the `BREAK-02` fixture (6 habits + 2 time-targets, `blocks: []`, `lighterDay: false`) and pinned as the deliberate non-change from D-04:

| Mood | N (cadence) | Work-chunk count |
|------|-------------|-------------------|
| 1 | 2 | 4 |
| 2 | 3 | 5 |
| 3 | 4 | 8 |
| 4 | 4 | 9 |
| 5 | 5 | 10 |

This guard is currently GREEN and, per D-04's capacity-simulation argument in `28-RESEARCH.md` (455-695 minutes of slack at every mood under the nominal 840-minute window), must remain GREEN after plan 28-03's fix — a failure here post-fix would mean the lattice cost capacity and the plan's central premise was wrong.

## Narrow-Slot Fallback — Pre-Fix Observed Results

Both fixtures observed directly against the current (unfixed) engine, via the throwaway probe test before any assertions were written:

**NARROW** (`mood: 1`, 3 habits capped to 2 discretionary chunks, `blocks: [makeBlock(555, 600)]`):
- Pre-fix actual: **4 chunks** — `W@480(25) SB@505(5) W@510(25) [anchored W@555(45)]`.
- **No break at all follows the boundary chunk** (chunk 2, at 510) — the old engine's 25-minute reservation check (`535 + 25 = 560 > 555`) fails to fit, so nothing is reserved; defect 1/2's un-additive 25-minute-only footprint has no partial-fit fallback.
- Post-fix expected (asserted in RED-PROOF 6, corrected per the deviation above): **5 chunks**, with the boundary chunk's short break (5 min) reserved via the new partial-fallback logic, but still no long break (the full 35-minute footprint still doesn't fit in this 75-minute slot).

**CONTROL** (identical fixture, block moved 30 min later to `makeBlock(585, 630)`):
- Pre-fix actual: **4 chunks** — `W@480(25) SB@505(5) W@510(25) [anchored W@585(45)]`.
- **No long break is emitted** even though the wider slot has room — this is defect 3 in isolation: the old `discIdx + 1 < discretionaryChunks.length` guard suppresses the reservation because chunk 2 is the last discretionary chunk demanded that day, regardless of available room.
- Post-fix expected: **6 chunks**, with exactly one long break (`durationMinutes == 30`, `syntheticStartMinutes == 540`) — the only difference from NARROW is 30 minutes of slot width, which is what makes the eventual fallback capacity-driven rather than a suppression rule.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 28-02 (if it exists in this wave) or plan 28-03 (wave 2) can now implement the lattice fix in `lib/services/schedule_generator.dart` against these exact assertions — every expected value in the new LATTICE tests was independently verified via simulation, not just transcribed from the plan.
- **Flag for 28-03's author:** the commitment-block-chunking loop (`generate()`, lines ~246-282) is untouched by this plan and, per D-01, must remain untouched by 28-03 too — but be aware that a 45-minute (or any <50-minute) commitment window produces exactly ONE anchored chunk stretched over the whole window, not a 25+remainder pair. Any future test or reasoning about commitment-block behavior should verify against the actual loop rather than assuming a fixed 25-minute-chunk-plus-tail split.
- No blockers. Zero production code touched, so 28-03 starts from a clean, fully-RED-proven baseline.

## Self-Check: PASSED

- FOUND: `test/services/schedule_generator_test.dart`
- FOUND: `.planning/phases/28-the-day-is-a-lattice/28-RED-unit.txt`
- FOUND: commit `85f9ed2` (Task 1)
- FOUND: commit `ca1822d` (Task 2)
