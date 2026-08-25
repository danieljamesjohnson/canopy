---
phase: 31-breaks-you-can-skip
plan: 04
subsystem: engine
tags: [flutter, provider, hive, guard-chain, regression-test]

# Dependency graph
requires:
  - phase: 31-01
    provides: the UI path (SwipeableChunkCard's endToStart Dismissible branch) that makes a break's isSkipped reachable at all — the precondition that turns _absorbReclaimedTimeIntoNextBreak's guard gap from inert into live
provides:
  - "The ninth guard in _absorbReclaimedTimeIntoNextBreak: if (next.isSkipped) return null;"
  - "A proven-RED-first regression test pinning D-31-05 (an already-skipped break is never moved/extended by G-05), paired with a proof the original G-05 absorption path still works"
  - "An asserted (not assumed) proof that skipping a break writes no Goal, moves no other chunk, and logs exactly one un-attributed CompletionLog entry"
affects: [31-05 (human UAT, can now truthfully claim skipping a break has no engine side effects)]

# Actuals (#2632)
actuals:
  tokens: 4128
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Guard-chain style preserved exactly: single-line `if (cond) return null;`, no braces, grouped with the semantically adjacent break-eligibility guards rather than appended at the end."
    - "Guard-removal red proof: to prove a prohibition test can actually fail, temporarily bypass the guard under test in production code, observe the assertion fail, restore, and record the observed failure text — rather than trusting the guard's presence as self-evidently correct."

key-files:
  modified:
    - lib/providers/schedule_notifier.dart
    - test/providers/schedule_notifier_break_extension_test.dart
  created:
    - .planning/phases/31-breaks-you-can-skip/31-RED-d3105.txt

key-decisions:
  - "Guard numbered 'Guard 9' rather than renumbering the eight existing guards to make room for its physical mid-chain position — preserves every other guard's comment byte-for-byte (acceptance criteria required zero unrelated diff lines), at the cost of the guard numbers no longer matching top-to-bottom reading order."
  - "Added a small _RecordingGoalRepository subclass rather than extending the shared _InMemoryGoalRepository — its getById is deliberately permissive (returns a habit Goal for any id, including the empty-string fallback used by the guard-removal experiment) so the recording fake can actually observe a save() call if the guard under test is ever weakened, without disturbing any of the file's other cases that depend on _InMemoryGoalRepository's real always-empty/always-null behavior."
  - "The guard-removal experiment for Case 1 used `chunk.goalId ?? ''` in place of `chunk.goalId!` (not just deleting the outer if): a break's goalId is genuinely null, so `chunk.goalId!` on null throws a NullCheckError that the function's own inner try/catch silently swallows — deleting only the outer guard would not have reached _goalRepo.save() at all, and the test would have stayed green even with the guard gone, which is exactly the failure mode 'a prohibition test that cannot fail' warns against. Using `?? ''` simulates what a naive (guard-free) reimplementation would actually do, so the experiment tests the guard's real protective value rather than Dart's incidental null-safety."

requirements-completed: [SKIPBREAK-01]

coverage:
  - id: D1
    description: "_absorbReclaimedTimeIntoNextBreak never moves or extends an already-skipped break (D-31-05), proven RED first against the unfixed eight-guard chain."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: unit
        ref: "test/providers/schedule_notifier_break_extension_test.dart#G-05 no-op guards D-31-05: an already-skipped following break is never moved or extended by G-05"
        status: pass
    human_judgment: false
  - id: D2
    description: "The original G-05 absorption behaviour survives the new guard — an unresolved following break still moves its start to now and extends to preserve its original end."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: unit
        ref: "test/providers/schedule_notifier_break_extension_test.dart#G-05 no-op guards D-31-05 does not disable G-05: an unresolved following break still absorbs reclaimed time"
        status: pass
    human_judgment: false
  - id: D3
    description: "Skipping a break never writes a Goal (streak write-back is unreachable) — asserted with a recording fake, and proven capable of failing by temporarily removing the guard it depends on."
    verification:
      - kind: unit
        ref: "test/providers/schedule_notifier_break_extension_test.dart#Phase 31 — skipping a break is inert below the UI skipping a break never writes a Goal"
        status: pass
    human_judgment: false
  - id: D4
    description: "Skipping a break moves no other chunk (D-31-03) — a five-chunk day snapshotted before and after markSkipped, every chunk but the skipped one byte-identical."
    verification:
      - kind: unit
        ref: "test/providers/schedule_notifier_break_extension_test.dart#Phase 31 — skipping a break is inert below the UI skipping a break moves no other chunk"
        status: pass
    human_judgment: false
  - id: D5
    description: "Skipping a break appends exactly one CompletionLog entry with no goal attribution (empty goalId)."
    verification:
      - kind: unit
        ref: "test/providers/schedule_notifier_break_extension_test.dart#Phase 31 — skipping a break is inert below the UI skipping a break appends exactly one CompletionLog entry, with no goal attribution"
        status: pass
    human_judgment: false

# Metrics
duration: ~15min
completed: 2026-08-25
status: complete
---

# Phase 31 Plan 04: The D-31-05 Guard Fix Summary

**Closed the one guard gap Phase 31's own D-31-03 decision made reachable — `_absorbReclaimedTimeIntoNextBreak` now refuses to move or extend an already-skipped break — proven with a RED-first regression test, and paired with two asserted (not assumed) proofs that skipping a break touches no habit data and moves no other chunk on the day.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-25 (worktree wave 2, parallel with 31-02)
- **Completed:** 2026-08-25
- **Tasks:** 3
- **Files modified:** 2 (+1 artifact created)

## Accomplishments

- Added two cases to the existing `G-05 no-op guards` group proving D-31-05: an already-skipped following break's `displayStartMinutes`/`durationMinutes`/`isSkipped` are untouched by an early work-chunk completion, and — critically — that the fix does not disable the original G-05 behaviour for an unresolved break. Captured the RED run against the unfixed eight-guard chain to `.planning/phases/31-breaks-you-can-skip/31-RED-d3105.txt` before any production code changed.
- Added the ninth guard, `if (next.isSkipped) return null;`, to `_absorbReclaimedTimeIntoNextBreak`, positioned after the `anchoredStartMinutes`/`breakStart` break-eligibility checks and before the window-open check, matching the existing single-line no-brace guard style exactly. `markSkipped` itself was not touched (verified via `git diff -U0 | grep markSkipped`).
- Added a new test group, `Phase 31 — skipping a break is inert below the UI`, with three cases: skipping a break never writes a `Goal` (via a new recording fake), moves no other chunk on the day (D-31-03, five-chunk fixture, element-wise before/after comparison), and appends exactly one `CompletionLog` entry with an empty `goalId`.
- Proved Case 1 is a real prohibition test, not a green test that could never fail: temporarily bypassed `markSkipped`'s `goalId != null && isNotEmpty` guard in production code, reran the test in isolation, observed it fail (`Expected: empty, Actual: [Instance of 'Goal']`), then restored the guard and confirmed the full 605-test suite green again.

## Task Commits

Each task was committed atomically:

1. **Task 1: The D-31-05 regression test, proven RED against the unfixed guard chain** - `e8f8cb4` (test)
2. **Task 2: The ninth guard** - `876deb8` (fix)
3. **Task 3: Skipping a break touches no habit data and moves no other chunk** - `18548ce` (test)

_No plan-metadata commit yet — this plan runs inside a git worktree; the orchestrator commits SUMMARY.md/STATE.md/ROADMAP.md centrally after the wave merges, per this executor's worktree-mode instructions._

## Files Created/Modified

- `lib/providers/schedule_notifier.dart` - added Guard 9 (`if (next.isSkipped) return null;`) to `_absorbReclaimedTimeIntoNextBreak`, with a comment explaining why it did not exist before Phase 31 and what it protects
- `test/providers/schedule_notifier_break_extension_test.dart` - two new `G-05 no-op guards` cases (D-31-05 RED/GREEN pair) plus a new `Phase 31 — skipping a break is inert below the UI` group (3 cases) and a `_RecordingGoalRepository` fake
- `.planning/phases/31-breaks-you-can-skip/31-RED-d3105.txt` - captured RED output proving the guard test failed against the unfixed chain (Task 1)

## Decisions Made

- **Guard numbered "Guard 9" rather than renumbering the existing eight.** The insertion point sits physically between Guard 6 and the old Guard 7, but renumbering would have edited seven other guards' comments, violating the plan's acceptance criterion that only the new guard's own lines appear in `git diff -U0`. The numbering is now addition-order, not top-to-bottom reading order — documented here so a future reader isn't confused by "Guard 9" appearing before "Guard 7" in the file.
- **Added `_RecordingGoalRepository` as a small subclass alongside `_InMemoryGoalRepository`, per the plan's explicit fallback instruction**, rather than changing the shared fake. `git diff` on `_InMemoryGoalRepository` itself is empty — only new call sites reference the new class.
- **The guard-removal experiment used `chunk.goalId ?? ''` instead of deleting only the outer `if`.** A break's `goalId` is genuinely `null` (not empty string), so `chunk.goalId!` on `null` throws a `NullCheckError` that the function's own inner `catch (_) {}` silently swallows — deleting just the `if` guard while leaving the `!` operator would never have reached `_goalRepo.save()`, and Case 1 would have stayed green even with the application-level guard fully removed. Using `?? ''` reaches the call the way an un-guarded, naively-written version of this code actually would, so the red proof tests the guard's real protective value rather than an accident of Dart's null safety.

## Deviations from Plan

None — plan executed exactly as written, including the exact guard insertion point, comment content, and the two-case RED/GREEN pairing the plan specified for Task 1.

**Guard-removal red proof (Task 3 acceptance criterion, not a deviation but worth recording verbatim):**

```
00:00 +0: Phase 31 — skipping a break is inert below the UI skipping a break never writes a Goal
00:00 +0 -1: Phase 31 — skipping a break is inert below the UI skipping a break never writes a Goal [E]
  Expected: empty
    Actual: [Instance of 'Goal']
  a break's goalId is always null, so the streak write-back is unreachable — a failure here means a break just touched the user's habit data, which is the serious regression the ROADMAP told planning to verify rather than assume
```

Production code was reverted immediately after capturing this output (`git diff lib/providers/schedule_notifier.dart` confirmed empty before the Task 3 commit).

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `_absorbReclaimedTimeIntoNextBreak`'s guard gap is closed and regression-tested; `markSkipped` and the original G-05 absorption path are both unchanged and re-verified green.
- Both prohibitions this phase's UI-SPEC required below-the-UI (habit-streak inertness, no-chunk-movement) are now asserted by executed tests, not assumed from reading the guard.
- Full suite (605 tests) green, `flutter analyze` clean.
- Plan 31-05's human UAT can now truthfully state that skipping a break has zero engine side effects, including in the early-completion-of-the-preceding-work-chunk case this plan closes.
- No blockers.

---
*Phase: 31-breaks-you-can-skip*
*Completed: 2026-08-25*
