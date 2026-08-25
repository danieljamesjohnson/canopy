---
phase: 31-breaks-you-can-skip
plan: 03
subsystem: testing
tags: [flutter, widget-test, dismissible, hit-testing, stack-zorder, regression]

# Dependency graph
requires:
  - phase: 31-01
    provides: kBreakHitSlop/kMinBreakDragTarget, the Layer 1a/1b Stack split, _needsSlop, and the top-slop-band tracer test this plan extends
  - phase: 31-02
    provides: the skipped-break rendering vocabulary (Opacity/lineThrough) this plan's Task 2 asserts stays duration-exact under
provides:
  - "The bottom-slop-band proof: a drag started inside a break's grown envelope BELOW its painted slot resolves to the break, not the following work chunk — the one claim that only holds because of the Layer 1b Stack pass"
  - "The negative/no-theft proof: a drag well inside a neighbouring work chunk's own painted content still resolves to that neighbour"
  - "A non-vacuity proof, executed and recorded: temporarily deleting Layer 1b and its _needsSlop exclusion makes the bottom-band case fail (Expected: b1, Actual: w2) while every other Phase 31 case stays green"
  - "The SKIPBREAK-02 painted-grid proof: duration-exact extent in every resolved state at both density tiers, exact row adjacency checked against TimelineGeometry's own yFor authority, unchanged total timeline height, a break-free day introduces no copy, and a mixed day renders every row independently"
affects: [31-05 (human UAT — this plan closes the automated half of the touch-target claim; the real-thumb check is still theirs)]

# Actuals (#2632)
actuals:
  tokens: 5960
  tasks: 2
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Ordering-test non-vacuity via production-code reversal: to prove a Stack z-order fix is load-bearing (not a green test that could never fail), temporarily delete the later pass and its loop-exclusion predicate, observe the specific case the fix protects go RED while every case it doesn't protect stays green, then restore byte-identical (verified via empty git diff) before committing — the same class of proof 31-02 applied to a gate, applied here to Stack ordering instead."
    - "Anchor a neighbour's own painted rect by its title text, not its key, for hit-test-envelope tests — requires the fixture give siblings of the same chunk type distinct rationale strings so find.text(...) resolves unambiguously."

key-files:
  modified:
    - test/screens/today_screen_test.dart

key-decisions:
  - "skipTracerFixture() (defined in plan 31-01, shared by every case in this group) gained distinct rationale strings on w1/w2 ('Preceding work'/'Following work') so this plan's cases could anchor find.text(...) on each work chunk's own painted title to get its rect — the factory default ('Deep work') left both chunks with identical text, which 31-01's single-case tracer never needed to disambiguate. No existing assertion reads either string."
  - "The timeline Stack's own SizedBox is located by its distinctive height value (`widget.height == geometry.totalHeight`) rather than by key — today_screen.dart's `_timelineStackKey` is a private field of `_TodayScreenState`, unreachable from this test file's library. The derived height is specific enough (a multi-thousand-pixel value from this fixture's own arithmetic) that no other SizedBox in the tree could coincidentally match it; if the Stack ever grew to accommodate a break's hit-test envelope, the finder would return zero matches rather than a wrong one."
  - "Dismissible counts in the SKIPBREAK-02 zero-breaks/mixed-day cases exclude end_of_day_card.dart's own Dismissible (Key('end_of_day_card')) via a `chunkDismissibles()` helper — that card renders its own dismiss affordance whenever the pumped fixture is DayComplete-eligible, which both fixtures are, and a bare `find.byType(Dismissible)` over-counted by exactly one in both cases before this fix."

requirements-completed: [SKIPBREAK-01, SKIPBREAK-02]

coverage:
  - id: D1
    description: "A drag started inside a slop-bearing break's BOTTOM slop band (below its painted slot) resolves to that break, not the following work chunk — the claim that only holds because of the Layer 1b Stack pass, per 31-RESEARCH.md Pitfall 1."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_test.dart#Phase 31 — SKIPBREAK: breaks you can skip#SKIPBREAK-01: a drag started inside the break's BOTTOM slop band resolves to that break, not the following work chunk"
        status: pass
    human_judgment: false
  - id: D2
    description: "A drag started well inside the following work chunk's own painted content still resolves to that work chunk — the no-theft proof, the one thing flutter test's exact-coordinate synthetic gestures can genuinely settle."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_test.dart#Phase 31 — SKIPBREAK: breaks you can skip#SKIPBREAK-01 negative case: a drag started well inside the following work chunk's own painted content still resolves to that work chunk"
        status: pass
    human_judgment: false
  - id: D3
    description: "A below-threshold drag (well under dismissThresholds, which is a fraction of row WIDTH not height) resolves nothing and the break still renders unresolved (UI-SPEC E1 partial)."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_test.dart#Phase 31 — SKIPBREAK: breaks you can skip#SKIPBREAK-01: a below-threshold drag resolves nothing (UI-SPEC E1 partial)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Painted extent is exactly durationMinutes x kPixelsPerMinute in every resolved state (unresolved/skipped), at both the sub-compact (5-minute) and full (30-minute) density tiers — asserted against the confined ClipRect, never the grown Positioned."
    requirement: "SKIPBREAK-02"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_test.dart#Phase 31 — SKIPBREAK: breaks you can skip#SKIPBREAK-02 — the grid is unchanged#painted extent is exactly duration x kPixelsPerMinute in every resolved state, at every density"
        status: pass
    human_judgment: false
  - id: D5
    description: "Painted rows stay exactly adjacent — zero gap, zero overlap — and the break's own painted top matches TimelineGeometry's own yFor authority under the same mapping the preceding row uses, not just the neighbour's own edge."
    requirement: "SKIPBREAK-02"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_test.dart#Phase 31 — SKIPBREAK: breaks you can skip#SKIPBREAK-02 — the grid is unchanged#painted rows stay exactly adjacent — zero gap, zero overlap"
        status: pass
    human_judgment: false
  - id: D6
    description: "The timeline's total painted extent (the Stack's own SizedBox height) is unchanged by this phase, even though a slop-bearing break's hit-test box individually grows — edge-probe row 5 made executable."
    requirement: "SKIPBREAK-02"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_test.dart#Phase 31 — SKIPBREAK: breaks you can skip#SKIPBREAK-02 — the grid is unchanged#the timeline's total painted extent is unchanged by this phase"
        status: pass
    human_judgment: false
  - id: D7
    description: "A break-free day introduces no break copy anywhere on screen and no extra row (UI-SPEC E3 empty); a mixed day (completed/skipped work, skipped short break, unresolved long break, unresolved work) renders every row independently with duration-exact extent and correct per-row skipped treatment (UI-SPEC E3 populated / zero-one-many)."
    requirement: "SKIPBREAK-02"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_test.dart#Phase 31 — SKIPBREAK: breaks you can skip#SKIPBREAK-02 — the grid is unchanged#a day with zero breaks introduces no new copy and no new row (UI-SPEC E3 empty)"
        status: pass
      - kind: automated_ui
        ref: "test/screens/today_screen_test.dart#Phase 31 — SKIPBREAK: breaks you can skip#SKIPBREAK-02 — the grid is unchanged#a mixed day renders every row independently (UI-SPEC E3 populated / zero-one-many)"
        status: pass
    human_judgment: false
  - id: D8
    description: "The bottom-band test (D1) is not vacuous: temporarily deleting the Layer 1b Stack pass and its _needsSlop exclusion from Layer 1a makes D1 fail with a specific, thief-naming assertion (Expected: b1, Actual: w2), while the top-band tracer (31-01), the negative case (D2), and the below-threshold case (D3) all stay green — proving the failure is scoped to exactly the claim Layer 1b protects."
    verification:
      - kind: other
        ref: "manual RED experiment (recorded verbatim below): today_screen.dart's Layer 1a/1b split temporarily collapsed into one chronological loop, `flutter test --plain-name \"SKIPBREAK-01\"` run, output captured, production file restored byte-identical (git diff empty) before the commit"
        status: pass
    human_judgment: false

# Metrics
duration: ~25min
completed: 2026-08-25
status: complete
---

# Phase 31 Plan 03: The Bottom-Band Proof and the True-Grid Invariants Summary

**Pinned the one Phase 31 claim that would regress silently — a break's bottom slop band winning against the following work chunk, which only holds because of plan 31-01's Layer 1b Stack pass — by writing a test that fails with a named thief when that pass is removed, then restored the production file byte-identical; also proved the painted grid never moved (duration-exact extent, exact adjacency against `TimelineGeometry`'s own authority, unchanged total height) across every resolved state, tier, and a mixed five-chunk day.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-25 (worktree wave 3, after 31-01/31-02 merged)
- **Completed:** 2026-08-25
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Extended plan 31-01's `Phase 31 — SKIPBREAK` group with three new cases: the bottom-slop-band case (the one 31-01 explicitly deferred, per its own coverage entry D4), the negative/no-theft case, and a below-threshold-drag case (UI-SPEC E1 partial).
- Proved the bottom-band case is not vacuous by temporarily deleting the Layer 1b Stack pass and its `_needsSlop` exclusion from Layer 1a in `today_screen.dart`, running the group, observing the bottom-band case fail with `Expected: b1, Actual: w2` while every other case in the group (including 31-01's own top-band tracer) stayed green, then restoring the file byte-identical (`git diff` empty) before committing anything.
- Added a nested `SKIPBREAK-02 — the grid is unchanged` group: duration-exact painted extent across a 2x2 table (5-min/30-min x unresolved/skipped), exact row-to-row adjacency cross-checked against `TimelineGeometry.yFor`'s own authority (not just each row's neighbour), unchanged total timeline height, a break-free day introducing no copy, and a five-chunk mixed day rendering every row independently.
- `skipTracerFixture()` (shared by every case in the group, defined in 31-01) gained distinct `rationale` strings on its two work chunks so the new cases could locate each neighbour's own painted rect by title text — a test-fixture-only change, no behavior change, no existing assertion depends on the old default text.

## Task Commits

Each task was committed atomically:

1. **Tasks 1 & 2 combined: bottom-band/negative/threshold cases + the SKIPBREAK-02 painted-grid group** - `b5beb5a` (test)

_Both plan tasks landed in a single commit — Task 1's acceptance criteria required a temporary, uncommitted production-code reversal experiment between writing the tests and committing them, so the natural commit boundary was "after both tasks' tests exist, pass, and the reversal experiment is complete and reverted," not per-task. No plan-metadata commit yet — this plan runs inside a git worktree; the orchestrator commits SUMMARY.md centrally after the wave merges._

## Files Created/Modified

- `test/screens/today_screen_test.dart` - three new `Phase 31 — SKIPBREAK` cases (bottom band, negative/no-theft, below-threshold) plus a new nested `SKIPBREAK-02 — the grid is unchanged` group (5 cases); `skipTracerFixture()` gained distinct rationale strings on w1/w2

## Decisions Made

- **`skipTracerFixture()` edited in place rather than duplicated.** Giving w1/w2 distinct rationale strings is a test-fixture change shared by every case in the `Phase 31 — SKIPBREAK` group (including 31-01's already-passing tracer, which was re-run and confirmed unaffected). Duplicating the fixture under a new name would have left two near-identical builders in the file for no behavioral reason.
- **The timeline Stack's SizedBox located by its derived height value, not a key.** `today_screen.dart`'s `_timelineStackKey` is private to that library and unreachable from this test file. `find.byWidgetPredicate` matching `widget.height == geometry.totalHeight` is unique in practice (a multi-thousand-pixel derived value) and fails closed: if the Stack ever grew to accommodate a break's hit-test envelope, the predicate would match nothing rather than silently matching the wrong widget.
- **`chunkDismissibles()` helper excludes `end_of_day_card.dart`'s own `Dismissible`.** Both SKIPBREAK-02 fixtures pump at 18:00 (DayComplete), which is exactly when `EndOfDayCard` (with its own `Key('end_of_day_card')` `Dismissible`) renders — a bare `find.byType(Dismissible)` over-counted by one in both cases before this fix (see Deviations).
- **Both plan tasks committed together, not separately.** Task 1's acceptance criteria mandates a production-code reversal experiment (delete Layer 1b, observe RED, restore) performed between writing the tests and finalizing them. Since that experiment must never land in a commit, and both tasks touch the same test file's same group, one commit after both tasks' tests exist and the experiment is complete/reverted was the cleaner boundary than an artificial mid-experiment commit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `skipTracerFixture()`'s two work chunks shared identical title text**
- **Found during:** Task 1 (writing the negative/no-theft case, which needs to anchor `find.text(...)` on the following work chunk's own painted title)
- **Issue:** `skipTracerFixture()` (from plan 31-01) called `_workChunk(id: 'w1', ...)` and `_workChunk(id: 'w2', ...)` with no `rationale`, so both defaulted to `'Deep work'` — `find.text('Deep work')` would match two widgets, making it impossible to locate either work chunk's own rect unambiguously.
- **Fix:** Added distinct `rationale: 'Preceding work'` / `rationale: 'Following work'` to w1/w2 in the shared fixture.
- **Files modified:** test/screens/today_screen_test.dart
- **Verification:** 31-01's own top-band tracer test (which reads neither string) re-ran green; all new cases that anchor on the distinct titles resolve to exactly one widget each.
- **Committed in:** b5beb5a (single task commit)

**2. [Rule 1 - Bug] `find.byType(Dismissible)` over-counted by including `end_of_day_card.dart`'s own dismiss affordance**
- **Found during:** Task 2 (the zero-breaks and mixed-day cases, both pumped at 18:00/DayComplete)
- **Issue:** `EndOfDayCard` wraps itself in its own `Dismissible(key: const Key('end_of_day_card'))` and renders whenever the fixture is DayComplete-eligible — both of Task 2's fixtures qualify, so a bare `find.byType(Dismissible)` returned one more widget than the plan's stated expected chunk count (3 instead of 2, 6 instead of 5).
- **Fix:** Added a local `chunkDismissibles()` finder excluding the `end_of_day_card` key, used in both assertions.
- **Files modified:** test/screens/today_screen_test.dart
- **Verification:** both cases pass with the corrected finder; full suite and `flutter analyze` both green.
- **Committed in:** b5beb5a (single task commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1, test-fixture-only — no production code touched, no existing assertion's meaning changed)
**Impact on plan:** Both fixes were necessary for the plan's own instructed tests to be constructible and non-vacuous at all; neither widens scope beyond `test/screens/today_screen_test.dart`.

## Non-vacuity experiment (recorded verbatim, per this plan's own `<output>` instruction)

Layer 1a's `_needsSlop` exclusion and the entire Layer 1b loop were temporarily collapsed into one chronological loop in `today_screen.dart` (production code, never committed). Running `flutter test test/screens/today_screen_test.dart --plain-name "SKIPBREAK-01"` against that reversal produced:

```
00:00 +2: Phase 31 — SKIPBREAK: breaks you can skip SKIPBREAK-01: a drag started inside the break's BOTTOM slop band resolves to that break, not the following work chunk
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════
The following TestFailure was thrown running a test:
Expected: 'b1'
  Actual: 'w2'
   Which: is different.
          Expected: b1
            Actual: w2
                    ^
           Differ at offset 0
31-RESEARCH.md Pitfall 1: if the slop-bearing break is emitted in the chronological Layer 1a loop
instead of its own later Layer 1b pass, the following work chunk (added to the Stack later) wins the
contested bottom-slop pixels and the effective touch target is roughly 36dp, not 52dp.
...
00:00 +2 -1: Phase 31 — SKIPBREAK: breaks you can skip SKIPBREAK-01: a drag started inside the break's BOTTOM slop band resolves to that break, not the following work chunk [E]
00:00 +3 -1: Phase 31 — SKIPBREAK: breaks you can skip SKIPBREAK-01 negative case: a drag started well inside the following work chunk's own painted content still resolves to that work chunk
00:00 +4 -1: Phase 31 — SKIPBREAK: breaks you can skip SKIPBREAK-01: a below-threshold drag resolves nothing (UI-SPEC E1 partial)
```

The top-band tracer (31-01, `+0`), the bottom-band case's own negative case (`+3`), and the below-threshold case (`+4`) all stayed green — only the bottom-band case (`+2 -1`) failed, and it failed with the exact thief (`w2`), not a generic timeout or null. `today_screen.dart` was restored from a pre-experiment copy immediately after capturing this output; `git diff --stat lib/screens/today/today_screen.dart` and `git status --short` were both empty before the test commit.

## Issues Encountered

None beyond the two Rule-1 fixture fixes documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Every automated claim SKIPBREAK-01/02 make about hit-testing and the painted grid is now proven, including the one (bottom slop band) that plan 31-01 explicitly deferred and flagged as human-judgment-only in its own coverage entry D4 — that entry's automated half is now closed; only the real-thumb touch-target question remains for plan 31-05's human UAT.
- `flutter test` (full suite, 625 tests) and `flutter analyze` are both green.
- Only `test/screens/today_screen_test.dart` was modified — confirmed via `git status --short` both before and after the temporary production-code reversal experiment (which was never staged or committed).
- No blockers. Plan 31-05's human UAT can proceed knowing every geometric/ordering claim this phase makes has an executed, non-vacuous test behind it.

---
*Phase: 31-breaks-you-can-skip*
*Completed: 2026-08-25*

## Self-Check: PASSED

- `test/screens/today_screen_test.dart` — FOUND
- `.planning/phases/31-breaks-you-can-skip/31-03-SUMMARY.md` — FOUND
- Commit `b5beb5a` (test: bottom-band + grid-unchanged cases) — FOUND in `git log`
