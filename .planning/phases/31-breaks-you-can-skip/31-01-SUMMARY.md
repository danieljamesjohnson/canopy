---
phase: 31-breaks-you-can-skip
plan: 01
subsystem: ui
tags: [flutter, dismissible, hit-testing, stack-zorder, gesture]

# Dependency graph
requires:
  - phase: 29-breaks-you-can-see
    provides: kSubCompactBreakMinHeight, the sub-compact break density tier the tracer's 5-minute break renders through
  - phase: 30-breaks-in-committed-time
    provides: a lattice where every break is sandwiched between 25-minute-or-longer work chunks, the premise PD-31-01's symmetric-slop decision relies on
provides:
  - kBreakHitSlop/kMinBreakDragTarget constants (timeline_geometry.dart)
  - SwipeableChunkCard promoted to one unconditional Dismissible with an optional visualHeight confinement parameter
  - today_screen.dart's break arm growing its own hit-test envelope, plus the Layer 1b Stack pass that wins both slop bands
  - the first Dismissible-drag-simulation widget test in this codebase's history
affects: [31-02 (skipped-break rendering at every density), 31-03 (negative/no-theft drag test), 31-04 (D-31-05 guard fix), 31-05 (human UAT)]

# Actuals (#2632)
actuals:
  tokens: 11211
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Grown hit-test envelope: Positioned/Dismissible box taller than its slot, with paint confinement (Align(center)+SizedBox+ClipRect+OverflowBox) pushed INSIDE the Dismissible rather than wrapped around it — the outer box governs hit-testing, the inner box governs what paints."
    - "Dedicated later Stack pass (Layer 1b) for any row whose grown hit-test box overlaps chronological neighbours, mirroring the existing live-row (PD-10) z-order pattern — lastChild-ward wins Stack's hit-test resolution."

key-files:
  created:
    - .planning/phases/31-breaks-you-can-skip/31-RED-tracer.txt
  modified:
    - lib/screens/today/timeline_geometry.dart
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart
    - lib/screens/today/today_screen.dart
    - test/screens/today_screen_test.dart

key-decisions:
  - "Used the existing _FakeScheduleNotifierWithSchedule (already overrides markSkipped/markComplete to record ids without calling super) instead of adding a new _FakeScheduleNotifierRecordingSkips subclass the plan described — the existing fake already provides the exact recording shape needed."
  - "Moved the tracer test's simulated 'now' from 18:00 to 09:00 (both DayComplete) — 18:00 triggers CAL-03's centre-on-open auto-scroll far past this tiny fixture, pushing the whole day off the SingleChildScrollView's viewport so a coordinate-based drag misses every widget."
  - "PD-31-01 (symmetric slop, no per-neighbour clamp), PD-31-02 (confinement lives in SwipeableChunkCard), PD-31-03 (ClipRect/OverflowBox move inside SwipeableChunkCard), PD-31-04 (every break takes the new arm, slop only when under 48dp), PD-31-05 (background/secondaryBackground pairing verified against Dismissible's own assert) — all implemented exactly as the plan specified; no relitigation."

requirements-completed: [SKIPBREAK-01, SKIPBREAK-02]

coverage:
  - id: D1
    description: "A leftward drag started kBreakHitSlop-2 px above a 5-minute break's painted top edge calls ScheduleNotifier.markSkipped with that break's id (SKIPBREAK-01 tracer, top slop band, one-directional endToStart)."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_test.dart#SKIPBREAK-01 tracer: a drag started inside the break's top slop band resolves to that break"
        status: pass
    human_judgment: false
  - id: D2
    description: "The break's painted content stays exactly duration-exact (durationMinutes x kPixelsPerMinute) even though its hit-test envelope grew — the confined ClipRect measures 20.0dp for a 5-minute break, byte-identical to before this phase."
    requirement: "SKIPBREAK-02"
    verification:
      - kind: unit
        ref: "test/screens/today_screen_test.dart#SEEBREAK-02: a 5-minute break occupies exactly 20.0dp of slot at sub-compact density (unmodified, zero-line diff)"
        status: pass
    human_judgment: false
  - id: D3
    description: "No break, at any density, exposes the complete (startToEnd) direction or a tap callback; SwipeableChunkCard collapses to exactly one Dismissible construction site (the promote decision) with the deleted chunkType != work early return gone."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: other
        ref: "grep acceptance criteria: chunkType != ChunkType.work count=0, Dismissible( count=1, dismissThresholds count=0, showActions work-only count=1 — all run and confirmed in-session"
        status: pass
    human_judgment: false
  - id: D4
    description: "The full 52dp effective touch target (both top AND bottom slop bands) reliably accepts a real thumb, and the bottom-slop-band z-order fix (Layer 1b) does not steal a touch that legitimately belongs to the following work chunk's own painted content."
    verification: []
    human_judgment: true
    rationale: "This plan's tracer test proves only the top slop band (mirroring the tracer's single-path scope). The negative/no-theft case and a real touch-device check are explicitly deferred to plans 31-03 (negative widget test) and 31-05 (mandatory checkpoint:human-verify, per 31-RESEARCH.md Pitfall 6 — flutter test cannot model a real thumb's contact-patch centroid)."

# Metrics
duration: ~35min
completed: 2026-08-25
status: complete
---

# Phase 31 Plan 01: Tracer Slice — Breaks You Can Skip Summary

**Proved the whole of Phase 31 end-to-end on one path: a 5-minute break's 20dp row accepts a leftward drag started inside an invisible 16dp band above its painted top edge, resolving to `ScheduleNotifier.markSkipped`, with the painted band unchanged and the fix expressed as a dedicated later Stack pass rather than an in-place reorder.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-08-25T14:03:11Z (approx, per STATE.md session start)
- **Completed:** 2026-08-25
- **Tasks:** 2
- **Files modified:** 4 (+1 artifact created)

## Accomplishments

- Added `kBreakHitSlop = 16.0` and `kMinBreakDragTarget = 48.0` to `timeline_geometry.dart`, with PD-31-01's symmetric-slop rationale recorded in the doc comment.
- Added the first `Dismissible`-drag-simulation test in this repository's history (`test/screens/today_screen_test.dart`), proven RED against the unmodified code (`.planning/phases/31-breaks-you-can-skip/31-RED-tracer.txt`), then turned GREEN.
- Promoted `SwipeableChunkCard` from a work-chunk-only `Dismissible` (with a bare-`ChunkCard` early return for breaks) to a single unconditional `Dismissible` for every chunk type — the `promote` decision from `31-01-PLAN.md`. Work-chunk-ness is now three additive details on a local `isWork`: the extra `startToEnd` direction, `secondaryBackground`, and `onTap`.
- Added `SwipeableChunkCard.visualHeight` (optional `double?`, default `null`) that confines both the card's painted content and its swipe reveal(s) to an exact band, independently, via `Align(center)+SizedBox+ClipRect+OverflowBox` — the mechanism that lets a break's hit-test box exceed its painted slot without violating SKIPBREAK-02.
- Grew the break arm of `today_screen.dart`'s `_buildPositionedRow`: a sub-`kMinBreakDragTarget` break's own `Positioned`/`Dismissible` box grows by `kBreakHitSlop` on both sides; every break (not just slop-bearing ones) now routes through this arm, per PD-31-04, so the non-slop case is an exact identity transform.
- Added the Layer 1b Stack pass — slop-bearing breaks render in their own pass after the normal row loop and before the now-line overlay, so their grown box is always `lastChild`-ward of both chronological neighbours. This is the fix for the z-order gap `31-RESEARCH.md` Pitfall 1 identified in the UI-SPEC's original mechanism (without it, the bottom slop band would silently lose to the following work chunk).

## Task Commits

Each task was committed atomically:

1. **Task 1: Wave 0 — the first drag-simulation test in this repo, proven RED** - `6d300a7` (test)
2. **Task 2: End-to-end "a thumb-sized break skips" — one path only** - `d888c19` (feat)

_No plan-metadata commit yet — this plan runs inside a git worktree; the orchestrator commits SUMMARY.md/STATE.md/ROADMAP.md centrally after the wave merges (per this executor's worktree-mode instructions)._

## Files Created/Modified

- `lib/screens/today/timeline_geometry.dart` - added `kBreakHitSlop`/`kMinBreakDragTarget` constants with PD-31-01's rationale
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` - promoted to one unconditional `Dismissible`; added `visualHeight` confinement parameter
- `lib/screens/today/today_screen.dart` - break arm grows its hit-test envelope; new `_needsSlop` predicate; new Layer 1b Stack pass
- `test/screens/today_screen_test.dart` - new `Phase 31 — SKIPBREAK` test group (tracer + vacuity guard)
- `.planning/phases/31-breaks-you-can-skip/31-RED-tracer.txt` - captured RED output (Task 1)

## Decisions Made

- **Reused `_FakeScheduleNotifierWithSchedule` instead of adding a new fake class.** The plan's Task 1 action described adding a new `_FakeScheduleNotifierRecordingSkips` subclass, but `today_screen_test.dart`'s existing `_FakeScheduleNotifierWithSchedule` already overrides `markSkipped`/`markComplete` to record `lastSkippedId`/`lastCompletedId` without calling `super` — exactly the recording shape the tracer needed. Using it directly avoided a redundant subclass; no test coverage or intent was lost.
- **Changed the tracer's simulated clock from 18:00 to 09:00.** Both times are `DayComplete` for the fixture (last chunk ends 8:55 AM), satisfying the plan's requirement of "no row is live." But at 18:00, `TodayScreen`'s CAL-03 centre-on-open auto-scroll targets a point nine hours past this tiny fixture's content, scrolling the entire day — break included — off the `SingleChildScrollView`'s viewport. `tester.getRect` still returns geometrically correct (but off-screen) coordinates, so a `dragFrom` computed from them silently misses every widget in the real hit-test pass. This is a Rule 1 auto-fix (a genuine test-environment bug, not a code defect) — documented inline at the call site.
- Every `31-01-PLAN.md` planner decision (PD-31-01 through PD-31-06) was implemented exactly as specified — no relitigation, no silent deviation. PD-31-06 (a live break's skip affordance stays out of scope) required no code change in this plan since `showActions: chunk.chunkType == ChunkType.work` was left byte-for-byte unchanged, verified by grep (count still 1).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Tracer test's simulated clock produced an off-screen drag target**
- **Found during:** Task 2, Step 4 (turning Task 1's RED green)
- **Issue:** The plan specified `now: () => DateTime(2026, 8, 7, 18, 0)`. At that clock, `TodayScreen`'s CAL-03 auto-scroll (centre-on-open, keyed to `now`) scrolls the Stack far past the fixture's 8:00–8:55 AM content, so the break row is not actually painted within the test viewport's visible bounds at drag time — even though `tester.getRect` still returns its (off-screen) geometric coordinates. `tester.dragFrom` at those coordinates silently misses every widget, so `fake.lastSkippedId` stayed `null` for both the intended break AND a diagnostic direct-key drag on the unrelated preceding work chunk.
- **Fix:** Changed the pumped clock to `DateTime(2026, 8, 7, 9, 0)` — still past the fixture's last chunk end (8:55 AM), so `DayComplete`/no-live-row still holds exactly as the plan requires, but close enough that CAL-03's auto-scroll keeps the break within the default test viewport.
- **Files modified:** test/screens/today_screen_test.dart
- **Verification:** Test A (`SKIPBREAK-01 tracer`) now passes; confirmed via a diagnostic `tester.getRect` print showing the confined `ClipRect` and grown `Dismissible` rects both correctly bounded (painted 466–486, hit-test box 450–502) before removing the debug print.
- **Committed in:** d888c19 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug/test-environment)
**Impact on plan:** No production code changed as a result — this was purely a test-fixture clock choice. All of PD-31-01 through PD-31-06's implementation decisions landed exactly as specified.

## Issues Encountered

None beyond the deviation documented above — diagnosed via a `tester.getRect` print statement, confirmed the geometry mechanism was correct (painted extent 20.0dp, hit-test box 52.0dp, both landing at the arithmetically-predicted offsets), and traced the failure to viewport visibility rather than the production code.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The tracer slice is wired end-to-end and committed: constants → gesture wrapper → screen layout/Stack ordering → existing `markSkipped` mutation, all on one path.
- Plan 31-02 can now extend the skipped-break rendering (D-31-04) to every density tier and add its own `Semantics` accessibility gap fix, knowing the underlying gesture/hit-test mechanism is proven.
- Plan 31-03's negative/no-theft drag test and plan 31-04's D-31-05 guard fix are both unblocked — this plan touched neither `schedule_notifier.dart` (confirmed via empty `git diff --stat`) nor added a second `Dismissible` construction site.
- **Not yet covered by any automated test in this plan:** the bottom slop band specifically (only the top band was exercised by Test A) and the real-thumb touch-target claim — both are explicitly scoped to plans 31-03 and 31-05 respectively (see coverage entry D4).
- No blockers.

---
*Phase: 31-breaks-you-can-skip*
*Completed: 2026-08-25*
