---
phase: 28-the-day-is-a-lattice
plan: 02
subsystem: testing
tags: [flutter, dart, flutter_test, schedule_generator, timeline, chunk_card, lattice]

# Dependency graph
requires:
  - phase: 28-the-day-is-a-lattice (plan 01)
    provides: "Rewritten schedule_generator_test.dart proving LATTICE-01/LATTICE-02 RED; the confirmed <50-min commitment-window chunking behavior"
provides:
  - "test/screens/lattice_break_pair_test.dart: four D-06 tests proving the cadence-boundary break-pair shape end-to-end (engine -> row model -> geometry -> render), all RED against the unfixed engine"
  - "28-RED-d06.txt: raw expanded-reporter evidence of the 4 failures"
affects: [28-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Generate the fixture day from the real ScheduleGeneratorService, never a hand-built ScheduledChunk list, so the test proves the engine's actual output rather than an assumption about it"
    - "A helper (_firstBreakPairIndex) that returns -1 rather than throwing, paired with an explicit expect(..., greaterThanOrEqualTo(0), reason: ...) before any indexing, so a RED run reads as a clean assertion failure instead of a StateError"

key-files:
  created:
    - test/screens/lattice_break_pair_test.dart
    - .planning/phases/28-the-day-is-a-lattice/28-RED-d06.txt
  modified: []

key-decisions:
  - "Task 2's render-level test uses testWidgets(), not test() — required because it calls tester.pumpWidget(). This makes the plan's own acceptance criterion (`grep -c '^\\s*test(' == 4`) structurally unsatisfiable while remaining correct: 'testWidgets(' never contains the literal substring 'test(' (the '(' in 'testWidgets(' follows 'Widgets', not 'test'), so any file with 3 test() + 1 testWidgets() greps to 3, not 4. Verified empirically before treating it as a plan-authoring inconsistency rather than a bug in my own file. Implemented correctly (testWidgets is the only way to pump a widget) and documented here rather than force-fitting an incorrect API choice to satisfy a miscounted grep target."

requirements-completed: [LATTICE-02]

# Metrics
duration: ~8min
completed: 2026-08-19
---

# Phase 28 Plan 02: Prove D-06's Break-Pair Shape RED Summary

**Added `test/screens/lattice_break_pair_test.dart` — four tests proving the new short-break-then-long-break cadence-boundary pair survives the engine, the row model, the pixel geometry, and the render layer, all generated from the real `ScheduleGeneratorService` and all RED against the unfixed engine — zero production code touched.**

## Performance

- **Duration:** ~8 min (init 12:35:49Z → final commit 12:41:50Z)
- **Started:** 2026-08-19T12:35:49Z
- **Completed:** 2026-08-19T12:41:50Z
- **Tasks:** 2 completed
- **Files modified:** 2 (`test/screens/lattice_break_pair_test.dart`, `.planning/phases/28-the-day-is-a-lattice/28-RED-d06.txt`)

## Accomplishments

- Added `_latticeDay()`, a fixture helper reusing the `BREAK-01: mood=1` fixture shape (2 habits + 2 time-targets, `moodIndex: 1`, `lighterDay: false`) verbatim from `test/services/schedule_generator_test.dart`, generating its day from the real `ScheduleGeneratorService().generate(...)` — never a hand-built `ScheduledChunk` list.
- Added `_firstBreakPairIndex(List<ScheduledChunk>)`, returning the index of the first `shortBreak` immediately followed by a `longBreak`, or `-1` — paired with an explicit `reason`-bearing `expect(..., greaterThanOrEqualTo(0))` in every test before indexing, so a RED run reads as a clean assertion failure rather than a `StateError`.
- Task 1: three model-level tests in `group('D-06: a cadence boundary emits two consecutive break chunks')` — the engine emits the 5-min/30-min pair adjacently; `buildTimeline` renders the pair as two adjacent `ChunkRow`s with nothing between them; `TimelineGeometry.yFor`/`heightFor` position the pair abutting exactly with no overlap or dead space.
- Task 2: one render-level test in `group('D-06: the pair renders')` — pumps both break chunks through `TimelineRowTile(child: ChunkCard(...))`, each sized by `TimelineGeometry.heightFor`, with the same `pumpWithMood` + fake `ScheduleNotifier` (stubs `init()` to avoid Hive I/O) convention as `today_row_widgets_test.dart`. Asserts `tester.takeException()` is null and exactly two `ChunkCard`s render — no text-width or glyph-metric assertion anywhere in the file.
- All four tests fail against the unfixed engine for the same, predicted reason: `_firstBreakPairIndex` returns `-1` because the unfixed engine's cadence boundary *replaces* the short break with a 25-minute long break rather than following it — not a compile error, not a `StateError`.
- `28-RED-d06.txt` holds the final expanded-reporter capture: 4 tests declared, all 4 failing, each with the explicit pairIndex-not-found reason visible in the raw output.
- Full suite re-run after Task 2: 559 passing / 20 failing (the 16 pre-existing failures from plan 28-01 plus these 4 new ones) — confirmed no unexpected regressions elsewhere. `flutter analyze` clean.

## Task Commits

1. **Task 1: Model-level D-06 proof — the pair becomes two adjacent, exactly-abutting rows** - `8731d0f` (test)
2. **Task 2: Render-level D-06 proof — both break cards paint without throwing** - `1478580` (test)

_No TDD RED/GREEN/REFACTOR cycle applies here — this is a `type: execute` plan whose entire deliverable is the RED half; plan 28-03 lands the fix and turns these green._

**Commit sequencing note:** the full four-test file was authored in one pass, then temporarily split back into its Task-1-only state (model tests only, imports/fake trimmed to match) to capture a genuine 3-failure RED run and commit Task 1 in isolation, before re-adding the Task 2 render group, re-capturing the 4-failure RED run, and committing Task 2 — so each commit's `28-RED-d06.txt` snapshot matches exactly what that commit's test file actually contains, per the task-commit-protocol's per-task atomicity requirement.

## Files Created/Modified

- `test/screens/lattice_break_pair_test.dart` (new, 291 lines) — four D-06 tests: 3 model-level (`test()`), 1 render-level (`testWidgets()`), plus `_latticeDay()` and `_firstBreakPairIndex()` helpers and a per-file `_FakeScheduleNotifier`.
- `.planning/phases/28-the-day-is-a-lattice/28-RED-d06.txt` (new) — raw `flutter test --reporter expanded` capture proving all 4 tests fail against the unfixed engine.

## Decisions Made

- **Task 2's test uses `testWidgets()`, not `test()`** — required because it calls `tester.pumpWidget()`; there is no way to obtain a `WidgetTester` inside a plain `test()` block. See Deviations for the resulting acceptance-criterion conflict this surfaced and how it was resolved.
- **Split the single-pass-authored file back into per-task commits.** I initially wrote the complete 4-test file in one `Write` call (simplest way to get the full picture right), then reconstructed the Task 1/Task 2 boundary by temporarily trimming the file to its Task-1-only shape, re-running verification, and committing, before restoring Task 2's content and re-verifying — so the plan's per-task atomic-commit contract and each commit's RED-evidence snapshot both hold exactly, not just the end state.

## Deviations from Plan

### Auto-fixed Issues

None — no bugs, missing functionality, or blocking issues encountered during implementation.

### Plan-Authoring Inconsistency (documented, not auto-fixed)

**1. Task 2's acceptance criterion `grep -c '^\s*test(' test/screens/lattice_break_pair_test.dart` (expected `4`) is structurally unsatisfiable while the render test is written correctly.**

- **Found during:** Task 2, while self-checking acceptance criteria after writing the render test.
- **Issue:** The plan's Task 2 acceptance criteria list `grep -c '^\s*test(' ... == 4` alongside a render test that (per the plan's own action text) must call `tester.pumpWidget()`. Pumping a widget requires a `WidgetTester`, which only `testWidgets()` provides — `test()` cannot supply one. I verified empirically (`printf` piped through the exact grep pattern) that `'testWidgets('` never matches `grep '^\s*test('` or even unanchored `grep 'test('`, because the literal substring `"test("` never occurs in `"testWidgets("` — the `(` there follows `Widgets`, not `test`. So a correctly-written file with 3 `test()` (Task 1) + 1 `testWidgets()` (Task 2) greps to `3`, not `4`, under the plan's literal pattern, and no valid Dart authorship of a widget-pumping test can make it grep to `4` under that pattern.
- **Resolution:** Implemented the render test as `testWidgets()`, the only correct choice, rather than distorting the test to force an incorrect grep count. Verified: `grep -c '^\s*test(' test/screens/lattice_break_pair_test.dart` → `3`; `grep -c '^\s*testWidgets(' test/screens/lattice_break_pair_test.dart` → `1` (4 test-registrations total, correctly typed). All other Task 2 acceptance criteria (`grep -c '\[E\]'` == 4, zero text-width assertions, `takeException` present, `flutter analyze` clean, no `lib/` diff) were verified and pass exactly.
- **Files modified:** none beyond the plan's own scope — this is a documentation-only note, not a code change.
- **Verification:** the four RED failures are all genuine (pairIndex == -1, not a compile error), confirming the test file is correctly structured and the discrepancy is confined to one miscounted acceptance-criterion pattern in the plan text itself.
- **Impact:** none on the plan's actual goal (four D-06 tests, all RED, zero `lib/` touched) — flagged here so a future planner/verifier reading this phase's acceptance criteria isn't misled by the unsatisfiable literal count.

---

**Total deviations:** 0 auto-fixed. 1 plan-authoring inconsistency documented (unsatisfiable acceptance-criterion grep pattern, resolved by implementing correctly and recording the discrepancy).
**Impact on plan:** No scope change, no production code touched, all four D-06 tests exist and are proven RED for the correct reason.

## Issues Encountered

None beyond the acceptance-criterion discrepancy documented above.

## RED Evidence — Exact Failing-Test List

From `.planning/phases/28-the-day-is-a-lattice/28-RED-d06.txt` (4 tests declared, all 4 failing):

1. `D-06: a cadence boundary emits two consecutive break chunks D-06: the engine emits a 5-minute break immediately followed by a 30-minute break` — `Expected: a value greater than or equal to <0>, Actual: <-1>` — no shortBreak→longBreak adjacency in the generated day.
2. `D-06: a cadence boundary emits two consecutive break chunks D-06: buildTimeline renders the pair as two adjacent ChunkRows with no gap row between` — same `pairIndex == -1` cause.
3. `D-06: a cadence boundary emits two consecutive break chunks D-06: TimelineGeometry positions the pair abutting exactly — no overlap, no dead space` — same `pairIndex == -1` cause.
4. `D-06: the pair renders D-06: a 5-minute break card and a 30-minute break card render adjacently without throwing` — same `pairIndex == -1` cause, caught as a `TestFailure` before any `pumpWidget` call.

No test failed for an unexpected reason (compile error, `StateError`, or an assertion unrelated to the missing pair). Full-suite run (`flutter test`) shows 559 passing / 20 failing: the 16 pre-existing failures from plan 28-01 plus exactly these 4, nothing else regressed.

## Downstream Consumer Check (per plan's `<output>` instruction)

Per `28-PATTERNS.md`'s exhaustive grep, no production file outside `schedule_generator.dart`/its own model reads `reservedBreakMinutes`, and no `ScheduledChunk` consumer outside the generator's own test file was found branching on chunk-adjacency/cardinality — except `BREAK-02`'s "no two adjacent non-work chunks" assertion, which plan 28-01 already rewrote to allow exactly the D-06 shape. This plan's own read of `timeline.dart`, `timeline_geometry.dart`, and `chunk_card.dart` (Task 1/2 `<read_first>` targets) found no other place that assumes a single break between two work chunks — `buildTimeline`'s `GapFreeRow` logic is driven purely by `start - prevEnd >= minGapMinutes`, which naturally emits nothing for a zero-gap adjacent pair, and `ChunkCard._buildBreak` already treats `shortBreak`/`longBreak` as two independent, self-contained renders (Phase 22-02's single dashed-painter treatment) with no assumption about what precedes or follows either. No new finding to route to plan 28-03 beyond what 28-01-SUMMARY.md already flagged (the <50-minute commitment-window chunking behavior).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 28-03 (wave 2) can now implement the lattice fix in `lib/services/schedule_generator.dart` against both this plan's 4 D-06 tests and plan 28-01's 16 LATTICE-01/LATTICE-02 tests — 20 RED tests total, all independently verified against the real (unfixed) engine's actual current behavior, none against an assumed one.
- No blockers. Zero production code touched across both wave-1 plans, so 28-03 starts from a clean, fully-RED-proven baseline.
- Flag for 28-03's author: `test/screens/lattice_break_pair_test.dart`'s render test pumps `ChunkCard` inside a `SizedBox` sized to `TimelineGeometry.heightFor` for each break chunk. Once the engine fix lands, that height for a 30-minute long break's slot is real (unlike today's structurally-impossible RED state) — if `ChunkCard`'s dashed-break treatment ever overflows that slot at the new size, `tester.takeException()` will surface it as a genuine GREEN-phase failure, not a false pass.

## Self-Check: PASSED

- FOUND: `test/screens/lattice_break_pair_test.dart`
- FOUND: `.planning/phases/28-the-day-is-a-lattice/28-RED-d06.txt`
- FOUND: `.planning/phases/28-the-day-is-a-lattice/28-02-SUMMARY.md`
- FOUND: commit `8731d0f` (Task 1)
- FOUND: commit `1478580` (Task 2)

---
*Phase: 28-the-day-is-a-lattice*
*Completed: 2026-08-19*
