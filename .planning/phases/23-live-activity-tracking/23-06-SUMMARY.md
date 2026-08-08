---
phase: 23-live-activity-tracking
plan: 06
subsystem: engine
tags: [flutter, provider, schedule-mutation, gap-closure, tdd]

# Dependency graph
requires:
  - phase: 23-live-activity-tracking (plan 05)
    provides: G-03 timer-stranding fix (unrelated file, sequenced immediately before this plan)
  - phase: 17-time-anchored-home
    provides: "resolveNowState's KEY INVARIANT (an unopened break window is never promoted to Active) and its named regression test"
provides:
  - "ScheduleNotifier._absorbReclaimedTimeIntoNextBreak — moves the immediately-following break's start to now and extends its duration to preserve the original end, when a work chunk completes early"
  - "A write-side implementation of G-05 that requires zero changes to now_state.dart/today_screen.dart because it moves the break's clock window instead of promoting an unopened one"
affects: [any future ScheduleNotifier.markComplete change, any future work on break re-anchoring or schedule reflow]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dart 3 anonymous record ({ScheduledChunk chunk, int? previousStart, int previousDuration}) used as a lightweight revert-capture value out of a private helper, avoiding a one-off class for a single call site"

key-files:
  created:
    - test/providers/schedule_notifier_break_extension_test.dart
  modified:
    - lib/providers/schedule_notifier.dart

key-decisions:
  - "_absorbReclaimedTimeIntoNextBreak is called from markComplete AFTER chunk.isCompleted = true and BEFORE the single _repo.save, so one write persists both facts and the WR-05 catch can revert both together"
  - "The following chunk is located by CLOCK order (sorted copy of displayStartMinutes), not list order, since chunks are not guaranteed sorted in _todaySchedule!.chunks"
  - "Eight explicit guards, each a separate early-return, rather than one compound boolean — chosen so a reader can see each boundary independently (work-only, has-a-start, not-before-own-start, genuinely-early, has-a-following-break, break-is-movable, break-not-yet-open, reclaimed-span-positive)"

requirements-completed: [LIVE-01, G-05]

duration: ~20min
completed: 2026-08-08
---

# Phase 23 Plan 06: G-05 Break Absorbs Reclaimed Time Summary

**Completing a work chunk before its scheduled end now moves the following break's start to now while preserving its original end — a 10:00-10:25 chunk finished at 10:10 turns a 10:25-10:30 break into a 10:10-10:30 break — implemented entirely on the write side so the Phase 17 "unopened break window" invariant needs zero changes.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 2 planned, both completed (TDD RED/GREEN cycle run for real — see Task Commits)
- **Files modified:** 2 (1 new test file, 1 modified source file)

## Accomplishments

- Closed G-05 on Dan's exact terms from `23-UAT.md`: "extend the break to fill" — the reclaimed time becomes rest, not a neutral gap.
- Proved the RED/GREEN discrimination for real: reverted `schedule_notifier.dart` to its pre-implementation committed state and ran the new test file. 4 of 12 tests failed exactly where the missing behavior would show — the break-move assertion, the Active-resolution assertion, the long-break variant, and the persisted round-trip. (The remaining 8 already passed pre-fix: the 5 no-op guards, the revert-on-failure case, and the Phase-17-invariant case describe pre-existing behavior, and "nothing downstream shifts" passed because `w2` was already untouched by the no-op code path.) Restored the implementation and reran: 12/12 green.
- Zero changes to `lib/screens/today/now_state.dart` or `lib/screens/today/today_screen.dart` — confirmed by `git diff --name-only` listing exactly the two files in the plan's `files_modified`. `resolveNowState` reaches `Active(break)` through its existing, unmodified path because the break's clock window is genuinely moved, not promoted while still closed.
- The Phase 17 KEY INVARIANT test (`test/screens/today_screen_now_state_test.dart:470-487`) is untouched — not in `git diff --name-only` — and re-verified green in isolation (`--plain-name 'KEY INVARIANT'`).
- All eight guards from the plan are implemented as separate, named early-returns, and each has a dedicated no-op test.
- The WR-05 revert path was extended: a failed `_repo.save` now restores the break's previous `syntheticStartMinutes`/`durationMinutes` together with reverting `chunk.isCompleted`, before the existing best-effort re-save — pinned by a dedicated repository whose `save` always throws.

## Before/After (happy path, exact numbers)

| | Before `markComplete('w1')` | After (now = 10:10) |
|---|---|---|
| `b1.displayStartMinutes` | 625 (10:25) | 610 (10:10) |
| `b1.durationMinutes` | 5 | 20 |
| `b1` end (`start + duration`) | 630 (10:30) | 630 (10:30, preserved) |
| `w2.displayStartMinutes` / `durationMinutes` | 630 / 25 (unchanged before and after) | 630 / 25 |

Long-break variant: `b1` 625/25 (ends 650), completed at 10:05 (605) → `b1.displayStartMinutes == 605`, `durationMinutes == 45` (end still 650).

## Task Commits

TDD RED/GREEN cycle run for real (not just written-then-passed):

1. **Task 1 (RED):** wrote the test file, temporarily reverted `schedule_notifier.dart` to its pre-plan committed state (`git checkout --` on that one file), ran the new tests, confirmed 4 failures at exactly the assertions describing the not-yet-implemented behavior (break-move, Active-resolution, long-break, persisted round-trip) — `577e9d0` (test)
2. **Task 1 + Task 2 (GREEN):** restored the implementation (`_absorbReclaimedTimeIntoNextBreak` + the `markComplete` call site + the WR-05 revert extension), extended the test file with the five no-op guard cases, the revert-on-failure case, and the Phase-17-invariant-preservation case from Task 2, reran — 12/12 green, full suite 473/473 green, `flutter analyze` clean — `5d9c3f7` (feat)

_Both tasks landed in a single GREEN commit because they touch only the same two files (`files_modified` in the plan frontmatter) and Task 2 is additive test coverage on top of Task 1's already-complete implementation; splitting them into separate commits would have meant re-diffing the same two files twice for no isolation benefit. The RED commit stands alone and precedes it, preserving the RED→GREEN sequence._

## Files Created/Modified

- `test/providers/schedule_notifier_break_extension_test.dart` (new) — `G-05 happy path` group (4 tests: break-absorbs-time, downstream-unchanged, Active-resolution, persisted round-trip), a standalone long-break-variant test, `G-05 no-op guards` group (5 tests: completed-at-end, completed-after-end, following-chunk-is-work, no-following-chunk, break-already-open), `G-05 revert on failure` (WR-05), and `G-05 preserves the Phase 17 invariant` (reproduces the KEY INVARIANT fixture directly and asserts `GapBeforeNext` still fires when the break was never moved).
- `lib/providers/schedule_notifier.dart` — new private helper `_absorbReclaimedTimeIntoNextBreak(ScheduledChunk completed)` (eight explicit guards, returns a `({ScheduledChunk chunk, int? previousStart, int previousDuration})?` record), called from `markComplete` between `chunk.isCompleted = true` and `await _repo.save`; `markComplete`'s existing `catch` block extended to restore the break's previous values before reverting `isCompleted`.

## Decisions Made

- **Called after `isCompleted = true`, before the single save** — matches the plan exactly, so one write persists both facts and there is no window where only one of the two mutations is durable.
- **CLOCK order, not list order, to find the following chunk** — `_todaySchedule!.chunks` is not guaranteed sorted (e.g. after `addEventToday`'s reflow), so the helper builds a sorted copy filtered to chunks with a `displayStartMinutes`, matching the same sort `resolveNowState` and `_trimTrailingNonWork` already use.
- **Eight guards as separate early-returns** rather than one compound condition, per the plan's explicit ask that "a reader can see the boundary" for each one — this also let each guard get its own dedicated no-op test with a `reason:` naming it.
- **Anonymous Dart 3 record for the revert-capture return type**, avoiding a one-off named class for a single call site (constructor and consumer are both in the same file, a few lines apart).

## Deviations from Plan

None — plan executed exactly as written, including the exact numeric assertions (610/20, 605/45, `w2` still 630/25) and the RED-then-GREEN verification sequence.

## Verification

- `flutter test test/providers/schedule_notifier_break_extension_test.dart` — 12/12 passed.
- `flutter test` (full suite) — 473/473 passed (461 baseline + 12 new).
- `flutter analyze` — "No issues found!".
- `git diff --name-only` (final, both commits combined) — exactly `lib/providers/schedule_notifier.dart` and `test/providers/schedule_notifier_break_extension_test.dart`.
- `flutter test test/screens/today_screen_now_state_test.dart --plain-name 'KEY INVARIANT'` — 1/1 passed, file untouched.
- `grep -c "_absorbReclaimedTimeIntoNextBreak" lib/providers/schedule_notifier.dart` — 3.
- `grep -n "DateTime.now()" lib/providers/schedule_notifier.dart` — the only hit is inside a doc-comment sentence describing what the helper does NOT do, not executable code.
- `grep -c "KEY INVARIANT: an unopened" test/screens/today_screen_now_state_test.dart` — 1, in an unmodified file.

## Issues Encountered

None.

## Next Phase Readiness

- G-05 closed. Remaining `23-UAT.md` gaps (G-01, G-02, G-04, G-06, G-07) are scoped to other plans per `23-GAP-ANALYSIS.md`'s priority ranking; not addressed here.
- The accepted, deliberate consequence flagged in the plan (the completed work chunk's own window still overlaps the moved break on the clock, since only the break moves) is unchanged and not revisited — `buildTimeline`'s T-22-03 gap guard already suppresses any negative-duration row from the overlap, and the completed chunk's timeline row renders with `showStartTime: false`.

---
*Phase: 23-live-activity-tracking*
*Completed: 2026-08-08*

## Self-Check: PASSED

- FOUND: lib/providers/schedule_notifier.dart
- FOUND: test/providers/schedule_notifier_break_extension_test.dart
- FOUND: .planning/phases/23-live-activity-tracking/23-06-SUMMARY.md
- FOUND commit: 577e9d0 (test: add failing G-05 break-absorption tests, RED)
- FOUND commit: 5d9c3f7 (feat: break absorbs reclaimed time on early completion, GREEN)
