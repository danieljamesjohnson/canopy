---
phase: 28-the-day-is-a-lattice
plan: 03
subsystem: scheduling-engine
tags: [dart, flutter, schedule_generator, lattice, break-cadence]

# Dependency graph
requires:
  - phase: 28-the-day-is-a-lattice (plan 01)
    provides: "20 RED tests proving LATTICE-01/LATTICE-02/D-01..D-06 fail against the unfixed engine, with every fixture's expected value independently verified by simulation"
  - phase: 28-the-day-is-a-lattice (plan 02)
    provides: "4 D-06 tests proving the cadence-boundary break-pair shape end-to-end (engine -> row model -> geometry -> render)"
provides:
  - "lib/services/schedule_generator.dart rebuilt on a provable 30-minute lattice invariant: footprint-encoded break reservation (5 ordinary / 35 boundary), one-or-two-break STEP C decode, short-break-only STEP E trim, unconditional cursor realignment, 30-minute rounding at both off-lattice entry points"
  - "28-GREEN-final.txt: raw evidence that all 20 wave-1 RED tests are now GREEN and the full 579-test suite passes"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Additive footprint encoding on a single scratch int field (reservedBreakMinutes: 5 or 35) instead of two fields, decoded at emission time — keeps the cadence's single source of truth in one place per WR-01"
    - "Unconditional post-reservation cursor realignment (_roundUpToLattice) as the closing move of a packing-loop branch, proven necessary by the one case (partial-fallback) that would otherwise leave the cursor at S+25"
    - "flutter test --concurrency=1 for reliable per-test-name lines in a captured expanded-reporter evidence file — default concurrency interleaves/duplicates progress lines across test files and cannot be trusted for by-name verification"

key-files:
  created:
    - .planning/phases/28-the-day-is-a-lattice/28-GREEN-final.txt
  modified:
    - lib/services/schedule_generator.dart
    - .planning/phases/28-the-day-is-a-lattice/28-VALIDATION.md

key-decisions:
  - "No wave-1 test expectation required correction — every one of the 20 RED tests (and all 50 previously-green tests) passed exactly as originally written the first time the engine change was verified, with zero hand-tuning of assertions"
  - "Captured 28-GREEN-final.txt with flutter test --concurrency=1 rather than the plan's literal verify command (default concurrency) — a first default-concurrency capture aggregated to the correct 579/0 total but silently dropped/duplicated per-test-name lines for fast-running files (schedule_generator_test.dart never appeared by name), which would have made the by-name RED-to-GREEN cross-check unverifiable; --concurrency=1 produced a reliable 1:1 capture at a 52s cost instead of 16s"

requirements-completed: [LATTICE-01, LATTICE-02]

# Metrics
duration: ~8min
completed: 2026-08-19
---

# Phase 28 Plan 03: The Day Is a Lattice — Engine Fix Summary

**Fixed all four defects in `schedule_generator.dart` (25-vs-30 min long break, replace-vs-additive reservation, silent last-chunk suppression, and the two 5-minute rounding entry points) as one coherent additive-footprint change, turning all 20 wave-1 RED tests GREEN with zero test-expectation corrections — 579/579 tests pass, `flutter analyze` clean.**

## Performance

- **Duration:** ~8 min (commit 98e7f61 → 9771517)
- **Started:** 2026-08-19T07:47:46-05:00
- **Completed:** 2026-08-19T07:52:24-05:00
- **Tasks:** 3 completed
- **Files modified:** 2 (`lib/services/schedule_generator.dart`, `.planning/phases/28-the-day-is-a-lattice/28-VALIDATION.md`), 1 created (`28-GREEN-final.txt`)

## Accomplishments

- **Task 1 (the cadence fix, LATTICE-02/D-05):** rewired the packing loop's break reservation from a single replace-duration (`isLong ? 25 : 5`) to an additive footprint (`5 + (isBoundary ? 30 : 0)` → 5 or 35), deleted the `discIdx + 1 < discretionaryChunks.length` suppression guard entirely, added a capacity-driven partial-reservation fallback (reserve the 5-minute short break only when the full 35-minute footprint doesn't fit), and made STEP C decode the footprint into one or two break chunks instead of a single `reserved >= 25` threshold. Narrowed STEP E's trailing trim to short-breaks-only so a trailing long break survives — the fix that makes "never silently suppressed" literally true in the rendered output, not just in the packing pass's internal state. After this task, exactly the two predicted rounding tests remained RED; every other wave-1 test (18 of 20) passed.
- **Task 2 (the two rounding entry points, LATTICE-01/D-01/D-02/D-03):** replaced the `dayStart` 5-minute round-up with `_roundUpToLattice` (a 15:42 mid-day floor now starts work at 16:00, not 15:45), and wrapped the post-commitment free-slot cursor advance in the same helper so a commitment ending off-lattice (e.g. a 45-minute block) no longer cascades its offset through the rest of that slot. Verified `anchoredStartMinutes: cursor` (Step 1, commitment anchoring) is byte-identical to `HEAD~2` — D-01 untouched. All 70 tests in `schedule_generator_test.dart` passed.
- **Task 3 (phase gate):** ran the full suite and captured raw evidence to `28-GREEN-final.txt`. Cross-checked every one of the 20 named RED tests from `28-RED-unit.txt` and `28-RED-d06.txt` against the GREEN capture by exact name — all 20 present, none marked `[E]`. No wave-1 expectation needed correction. Updated `28-VALIDATION.md`'s sign-off checklist, per-task verification map, and `nyquist_compliant: true`.

## Task Commits

Each task was committed atomically:

1. **Task 1: The cadence fix — 30-minute long break in its own cell, never suppressed (LATTICE-02, D-05)** - `98e7f61` (fix)
2. **Task 2: The two rounding entry points — mid-day start and post-commitment slot (LATTICE-01, D-01, D-02, D-03)** - `a4c2d97` (fix)
3. **Task 3: Phase gate — full suite green, nothing deleted, nothing weakened, D-04 held** - `9771517` (docs)

_No TDD RED/GREEN/REFACTOR commit cycle applies here — the RED half was wave 1's entire deliverable (plans 28-01/28-02); this plan is the GREEN half against tests that already existed and were already proven RED._

## Files Created/Modified

- `lib/services/schedule_generator.dart` — added `_latticeMinutes`/`_shortBreakMinutes`/`_longBreakMinutes`/`_roundUpToLattice` to `ScheduleGeneratorService`; rewrote the packing loop's break-reservation branch (Site 1), STEP C's break-chunk emission (Site 2), STEP E's trailing trim (Site 3), `dayStart` derivation (Site 4), and the post-commitment free-slot cursor advance (Site 5). `_moodCap`, `_moodBreakCadence`, `dayEnd` byte-identical throughout (verified by exact-string grep both tasks).
- `.planning/phases/28-the-day-is-a-lattice/28-GREEN-final.txt` — raw `flutter test --reporter expanded --concurrency=1` capture: 579 tests, 0 failures, `All tests passed!`.
- `.planning/phases/28-the-day-is-a-lattice/28-VALIDATION.md` — sign-off ticked, per-task verification map filled in, `nyquist_compliant: true`.

## Decisions Made

- **No wave-1 test correction needed.** Every one of the 20 RED tests, and all 50 already-passing tests in the two files under test, passed exactly as originally written the first time each task's engine change was verified — a direct consequence of plan 28-01/28-02's own discipline of deriving every fixture's expected value from a Python simulation of the *intended* fixed algorithm (not hand arithmetic) before this plan ever touched `lib/`.
- **Evidence-file capture needed `--concurrency=1`, not the plan's literal command.** A first default-concurrency `flutter test --reporter expanded` run correctly totaled 579 passed / 0 failed, but its per-line test names were unreliable at scale — fast files like `schedule_generator_test.dart` (70 tests, sub-second) never appeared by name in the captured output at all, because Dart's default concurrent sharding interleaves/overwrites expanded-reporter progress lines across files. Since the acceptance criteria require confirming each of the 20 RED-named tests by exact name in the GREEN capture, a second capture with `--concurrency=1` was taken (52s vs. 16s) and used as the committed evidence file instead.

## Deviations from Plan

### Auto-fixed Issues

None — no bugs, missing functionality, or blocking issues encountered. The engine change was verified correct against all 90 tests (70 in `schedule_generator_test.dart`, 4 in `lattice_break_pair_test.dart`, and the 16 that already passed at 28-01) on the first attempt for both Task 1 and Task 2.

### Plan-Authoring Note (documented, not auto-fixed)

**1. `test/screens/lattice_break_pair_test.dart` greps to 3 `test(`, not 4 — same structural pattern-count issue 28-02-SUMMARY.md already documented.**
- **Found during:** Task 3's acceptance-criteria check (`grep -c '^\s*test(' test/screens/lattice_break_pair_test.dart` returns `4` per the plan text).
- **Issue:** The file has 3 `test()` registrations and 1 `testWidgets()` registration (4 tests total) — `testWidgets(` never matches the literal substring `test(` (the `(` follows `Widgets`, not `test`), so no correctly-written render test can make this grep return 4.
- **Resolution:** Left the test file untouched (it is correct — `testWidgets()` is required to obtain a `WidgetTester` for `pumpWidget`) and recorded the discrepancy here rather than distorting a passing test to satisfy a miscounted grep pattern, per this plan's own instruction not to touch tests to force a criterion. All four tests exist, all four pass, all four are named in `28-GREEN-final.txt` without `[E]`.
- **Impact:** none on the plan's actual goal.

---

**Total deviations:** 0 auto-fixed. 1 pre-existing plan-authoring note re-confirmed (not new — 28-02-SUMMARY.md flagged it first; this plan's Task 3 acceptance criteria repeated the same unsatisfiable pattern).

## Issues Encountered

None beyond the evidence-capture concurrency issue documented above (resolved by re-capturing at `--concurrency=1`, not a code or test issue).

## LATTICE-01 / LATTICE-02 — Final State

- Every discretionary chunk's start minute is ≡ 0 (mod 30), at every mood, with and without commitment blocks, and on a mid-day `startFloorMinutes` regeneration. Commitment-anchored chunks keep their raw wall-clock minutes (D-01), verified byte-identical to `HEAD~2`.
- Exactly `floor(discretionaryWorkChunks / N)` long breaks are emitted, each exactly 30 minutes, following (never replacing) the Nth chunk's own 5-minute short break — including when the boundary chunk is the day's literal last chunk.
- The owner's day (mood 3, N=4, 4 habits) now produces the full 9-chunk sequence: `W@480(25) SB@505(5) W@510(25) SB@535(5) W@540(25) SB@565(5) W@570(25) SB@595(5) LB@600(30)`. Before this plan: 7 chunks, ending on `work`, zero long breaks.
- The narrow-slot partial-reservation fallback (the one remaining path that can withhold a long break) is proven capacity-driven by the wave-1 NARROW/CONTROL fixture pair — identical except for 30 minutes of slot width — and does not fire on the owner's day or any of the five nominal per-mood fixtures. No test in the full 579-test suite hit the fallback branch outside its own dedicated fixture (confirmed indirectly: every other test's expected chunk count/sequence matched the full-footprint path exactly, with zero corrections needed).

## D-04 — Capacity Held (Behavioral Proof)

Wave 1 pinned these per-mood work-chunk counts against the *unfixed* engine (fixture: 6 habits + 2 time-targets, `blocks: []`, `lighterDay: false`):

| Mood | N (cadence) | Work-chunk count |
|------|-------------|-------------------|
| 1 | 2 | 4 |
| 2 | 3 | 5 |
| 3 | 4 | 8 |
| 4 | 4 | 9 |
| 5 | 5 | 10 |

The `D-04: neither _moodCap nor the day end moves — per-mood work-chunk counts are unchanged` guard test ran unmodified against the *fixed* engine in this plan's Task 1/Task 2/Task 3 verification runs and passed every time — the counts above are unchanged post-fix. This is the behavioral confirmation (not just source inspection) that `28-RESEARCH.md`'s capacity simulation was correct: the lattice costs 10-20 extra minutes of wall-clock per day, not capacity, and every mood still fits the nominal 480-1320 window with hundreds of minutes of slack.

## Was the Owner's Regression the Whole Story?

Very likely yes, for the specific complaint ("the schedule still isn't functioning right"). The mood-3/N=4/4-chunk day was the exact scenario CONTEXT.md named as the probable whole cause: at that mood and chunk count, defect 3's `discIdx + 1 < discretionaryChunks.length` guard was false exactly once — on the day's last chunk — silently dropping the only long break the day would have gotten. That guard is now deleted, and the fixture that reproduces the owner's literal day (RED-PROOF 4 / "the owner's day" test) is green with the full 9-chunk sequence.

Two things worth naming as residual, out-of-this-plan's-scope risk rather than loose ends:
- The pre-existing "silently drop discretionary chunks that don't fit the window" behavior (documented in `_assignSyntheticStartTimes`'s own trailing comment) is unchanged in kind — the lattice makes the threshold at which it can trigger marginally later (10-20 more minutes of demand per RESEARCH.md), not newly possible. This was a deliberate D-04 non-change, not something this plan silently left broken.
- If the owner's actual day today has commitment blocks or an unusually late check-in time, D-02's up-to-29-minutes-idle trade-off is a new, small, visible behavior (previously the engine would silently drift off-lattice instead) — worth watching for in the next UAT round, but it is the documented, deliberate cost of LATTICE-01 holding through a commitment.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Phase 28 is functionally complete: LATTICE-01 and LATTICE-02 both hold, D-01 through D-06 are all satisfied and tested, the full suite is green (579/579), and `flutter analyze` is clean. No blockers. No follow-up plan is required by this phase's own scope — the engine-side lattice fix is the entirety of what was asked.

## Self-Check: PASSED

- FOUND: `lib/services/schedule_generator.dart` (modified, verified via `git diff --stat`)
- FOUND: `.planning/phases/28-the-day-is-a-lattice/28-GREEN-final.txt`
- FOUND: `.planning/phases/28-the-day-is-a-lattice/28-VALIDATION.md` (modified)
- FOUND: commit `98e7f61` (Task 1)
- FOUND: commit `a4c2d97` (Task 2)
- FOUND: commit `9771517` (Task 3)
