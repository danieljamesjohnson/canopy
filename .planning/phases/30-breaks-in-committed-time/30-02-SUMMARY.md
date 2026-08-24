---
phase: 30-breaks-in-committed-time
plan: 02
subsystem: testing
tags: [flutter_test, schedule_notifier, chunk_card, tdd-red-proof]

# Dependency graph
requires:
  - phase: 28-the-day-is-a-lattice
    provides: the 30-minute lattice / footprint-reservation pattern this plan's second-path tests hold addEventToday to
  - phase: 29-breaks-you-can-see
    provides: the sub-compact break rendering tier that makes an inserted commitment break visible
  - plan: 30-01
    provides: "D-30-01 through D-30-04, and the 30-RED-generator.txt evidence pattern this plan's evidence file mirrors"
provides:
  - "3 new named tests proving COMMITBREAK-01/02 on the addEventToday (second) path, plus 1 D-30-02 trim regression test, all calling the real ScheduleNotifier.addEventToday"
  - "3 existing addEventToday tests re-pointed from the pre-Phase-30 shape to the post-fix shape, none deleted"
  - "1 render guard (COMMITBREAK-01/RENDER) that settles D-30-04 empirically by pumping a real generated commitment break through the real ChunkCard"
  - "30-RED-secondpath.txt: by-name RED/GUARD evidence with per-test wave attribution (2 or 3), captured at --concurrency=1"
affects: [30-03, 30-04, 30-05]

# Actuals (#2632)
actuals:
  tokens: 8183
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "RED-proof wave boundary carried from 30-01: every regression test written and proven failing (or explicitly documented as an unexpectedly-passing GUARD) before any lib/ change"
    - "Second-path tests filter to commitmentId == block.id and sort by anchoredStartMinutes before indexing, mirroring 30-01's anchoredStartMinutes != null filter convention"

key-files:
  created:
    - .planning/phases/30-breaks-in-committed-time/30-RED-secondpath.txt
  modified:
    - test/providers/schedule_notifier_add_event_test.dart
    - test/screens/lattice_break_pair_test.dart

key-decisions:
  - "D-30-03 (carried from 30-01, acted on here) — lib/providers/schedule_notifier.dart:addEventToday is confirmed as this plan's target: it carries the identical bare `cursor += 25` walk under a doc comment claiming it mirrors the generator, and its own _trimTrailingNonWork (unlike the generator's STEP E) has no commitmentId-based narrowing at all yet. This plan writes and proves RED the tests that prove both defects on the second path; the fix itself lands in 30-04."
  - "D-30-04 was proven empirically, not assumed, in this plan's own render guard rather than merely inherited from 30-01's SUMMARY. COMMITBREAK-01/RENDER pumps a real generated commitment break (carrying commitmentId) through the real ChunkCard and asserts the break title renders — proving ChunkCard.build()'s chunkType switch routes breaks to _buildBreak before _WorkChunkContent (the only place isCommitment/tertiaryContainer styling is read) is ever constructed. 30-RESEARCH.md's Pitfall 6 premise (that commitmentId would silently tint a break) is therefore corrected by this plan's own test, independently of 30-01's prose claim."
  - "COMMITBREAK-02/ADD-EVENT (new test) came back GREEN against the unfixed notifier — an unexpected GUARD, not distorted to force a failure, per the plan's own instruction and the 30-01/Phase-28 precedent (WR-03). Investigation: addEventToday's pre-existing tail-stretch (`last.durationMinutes = block.endMinutes - last.anchoredStartMinutes!`) already covers the full window, and the block object's own startMinutes/endMinutes were never mutated by the pre-phase code. COMMITBREAK-02 (D-01 preservation) was therefore never actually broken on the second path — only COMMITBREAK-01 (no lattice) and the D-30-02 trim defect are. Recorded here rather than silently dropping the test, since a GUARD is still evidence the fix in 30-04 must not regress."
  - "The COMMITBREAK-01/ADD-EVENT-TRIM fixture reproduces the trim bug via the `!anchorsToday` early-return branch (a block dated for a DIFFERENT day), not the more obvious same-day edit branch — this is deliberate: _trimTrailingNonWork() runs unconditionally before the anchorsToday check, so the early-return path is the minimal, most direct repro of 'a PREVIOUS addEventToday call's anchored break can be deleted by a later, unrelated call' per the plan's own <key_links> guidance."

patterns-established:
  - "Second-path regression naming convention: '<REQ-ID>/ADD-EVENT[-<SUFFIX>]' for schedule_notifier_add_event_test.dart, '<REQ-ID>/RENDER' for lattice_break_pair_test.dart — parallel to 30-01's '<REQ-ID>/<SUFFIX>' convention in schedule_generator_test.dart, so a future reader can tell which code path (generator vs. notifier vs. render) a given test exercises purely from its name."

requirements-completed: []  # COMMITBREAK-01/02 are proven by tests here but NOT yet satisfied on the second path — the notifier fix lands in 30-04, the render fix depends on the generator fix in 30-03. Left empty deliberately, mirroring 30-01.

coverage: []  # Test-only wave; no user-facing deliverable to classify yet.

duration: ~25min
completed: 2026-08-24
status: complete
---

# Phase 30 Plan 02: Second-Path COMMITBREAK Regression Tests Summary

**Three new tests plus a D-30-02 trim regression prove `addEventToday` carries the identical unbroken-lattice defect as the generator, and a fourth test proves — by pumping a real generated break through the real `ChunkCard` — that Research's D-30-04 styling concern was wrong; all evidence captured by name in `30-RED-secondpath.txt` with per-test wave attribution and a git-proven zero-`lib/` wave boundary.**

## Performance

- **Duration:** ~25 min
- **Tasks:** 3
- **Files modified:** 2 (test files), 1 file created (evidence)

## Accomplishments

- Added `COMMITBREAK-01/ADD-EVENT`, `COMMITBREAK-02/ADD-EVENT`, and `COMMITBREAK-01/ADD-EVENT-TRIM` to `test/providers/schedule_notifier_add_event_test.dart`, every one calling the real `ScheduleNotifier.addEventToday` — the second path D-30-03 names as carrying the identical `cursor += 25` defect.
- Re-pointed 3 existing `addEventToday` tests (`inserts a same-day one-off...`, `editing an event re-anchors today...`, `creates a minimal today schedule...`) off the pre-Phase-30 "no breaks inside a commitment" shape, without deleting any of them.
- Added `_commitmentDay()` and `COMMITBREAK-01/RENDER` to `test/screens/lattice_break_pair_test.dart`, generating a fixture from the REAL `ScheduleGeneratorService` (never a hand-built chunk list) and pumping its real shortBreak/longBreak through the real `ChunkCard` — this is the executable proof that corrects 30-RESEARCH.md Pitfall 6's premise (D-30-04).
- Captured `30-RED-secondpath.txt`: by-name RED/GUARD evidence at `--concurrency=1` for all 16 tests across both touched files, with wave attribution (2 for the render guard, 3 for the notifier tests) for every RED entry, and an explicit, undistorted record of `COMMITBREAK-02/ADD-EVENT`'s unexpected GUARD status.
- Confirmed via `git diff --stat` and `git log -1 --name-only` that both task commits touch zero `lib/` paths — the wave boundary `30-03`/`30-04` must respect.

## Task Commits

Each task was committed atomically:

1. **Task 1: The add-event lattice tests — new and re-pointed** - `4ab9505` (test)
2. **Task 2: COMMITBREAK-01/RENDER — prove a commitmentId-carrying break still renders as a break** - `ae11ad6` (test)
3. **Task 3: Capture second-path RED evidence and commit the test-only wave** - `e766e74` (docs)

_No TDD RED→GREEN cycle applies here — this plan (like 30-01) IS the RED half of the phase's RED-proof wave boundary; GREEN lands in `30-03` (render guard) and `30-04` (notifier tests)._

## Files Created/Modified

- `test/providers/schedule_notifier_add_event_test.dart` — Added 3 new tests, re-pointed 3 existing tests
- `test/screens/lattice_break_pair_test.dart` — Added `_commitmentDay()` fixture helper and `COMMITBREAK-01/RENDER`
- `.planning/phases/30-breaks-in-committed-time/30-RED-secondpath.txt` — By-name RED/GUARD classification, wave attribution, full captured output, and git wave-boundary proof

## Decisions Made

See `key-decisions` in frontmatter — D-30-03 acted on (confirmed and tested, not re-argued), D-30-04 proven empirically by this plan's own render guard (not just inherited from 30-01's prose), COMMITBREAK-02/ADD-EVENT's GUARD status investigated and recorded rather than distorted, and the deliberate choice of the `!anchorsToday` branch to repro the D-30-02 trim bug.

## Deviations from Plan

None in substance. One test's actual RED failure mode differed slightly from the plan's exact prediction: the re-pointed "inserts a same-day one-off..." test's plan-specified acceptance criterion asserted `dentist[1].anchoredStartMinutes == 870` directly; the implementation additionally asserts the intermediate short-break chunk at 865 explicitly (not strictly required by the plan's acceptance criteria, but directly supports the plan's own `must_haves.truths` about the lattice existing). No test needed adjustment from its planned shape to fail correctly, and no RED-predicted test came back unexpectedly green except `COMMITBREAK-02/ADD-EVENT`, which is documented above per the plan's own instruction to investigate and record rather than distort.

## Issues Encountered

None. `flutter test --concurrency=1` full-suite cross-check (597 tests: 587 baseline + 6 from 30-01 + 4 from this plan) confirmed exactly 17 failures — the 11 pre-existing RED failures from `30-RED-generator.txt` (unchanged, 30-01) plus this plan's 6 new/re-pointed failures — with no other regression anywhere else in the suite.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `30-RED-secondpath.txt` is the executable specification for both remaining waves: `30-03` (generator fix) must turn `COMMITBREAK-01/RENDER` green; `30-04` (notifier fix, `addEventToday` + its `_trimTrailingNonWork`) must turn the 4 RED tests in `schedule_notifier_add_event_test.dart` green.
- `git diff --stat` confirms zero `lib/` changes from this plan (matching 30-01) — `30-03`/`30-04` start from a clean `lib/` baseline with no test-file collision risk from this plan.
- `COMMITBREAK-02/ADD-EVENT` already passes (GUARD) and must keep passing after `30-04` — a regression there would mean the notifier fix broke the pre-existing tail-stretch or mutated the block object, not just failed to add breaks.
- The 4 GUARD tests in `lattice_break_pair_test.dart` (`D-06: ...`) already pass and must keep passing after `30-03` — they exercise the discretionary-lattice path from Phase 28/29, independent of this phase's commitment-block change.

---
*Phase: 30-breaks-in-committed-time*
*Completed: 2026-08-24*

## Self-Check: PASSED

All claimed files exist on disk (`test/providers/schedule_notifier_add_event_test.dart`,
`test/screens/lattice_break_pair_test.dart`,
`.planning/phases/30-breaks-in-committed-time/30-RED-secondpath.txt`, this
SUMMARY) and all three task commit hashes (`4ab9505`, `ae11ad6`, `e766e74`)
resolve in `git log --oneline --all`.
