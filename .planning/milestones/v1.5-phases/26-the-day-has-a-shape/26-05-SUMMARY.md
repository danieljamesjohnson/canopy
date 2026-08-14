---
phase: 26-the-day-has-a-shape
plan: 05
subsystem: ui
tags: [flutter, material3, timeline, scroll-position, animateTo, devclock]

# Dependency graph
requires:
  - phase: 26-the-day-has-a-shape (plan 03)
    provides: "The timeline Stack surface (_timelineStackKey on the SizedBox-wrapped Stack) this plan's scroll arithmetic targets"
  - phase: 26-the-day-has-a-shape (plan 04)
    provides: "The now-line overlay (geometry.yFor(nowMinutes)) — the position this plan's scroll-on-open centres the viewport on, in every NowState"
provides:
  - "One _didCentreOnOpen flag and one arithmetic animateTo path (CAL-03), replacing Phase 24's two flags, two GlobalKeys and two Scrollable.ensureVisible blocks"
  - "The timeline Stack's leading offset resolved via RenderAbstractViewport.getOffsetToReveal (PD-17), so a mood<=2 day's restoratives card no longer throws off the scroll target"
  - "A CAL-03 widget-test suite (7 tests, nested 'Phase 26 — CAL-03 elapsed time recedes' group) — five-state table, arithmetic target recompute, past-off-screen proof, centres-once, DevClock re-arm, PD-19 no-re-centre-on-transition, empty-state hasClients guard"
affects: [26-06-real-browser-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Stack-top-via-getOffsetToReveal: the scroll target is the timeline Stack's own leading offset (found via RenderAbstractViewport.getOffsetToReveal on the Stack's RenderBox) plus geometry.yFor(nowMinutes), never geometry.yFor alone — because the restoratives card can precede the Stack in the scroll content"
    - "maxScrollExtent read exactly once, inside the post-frame callback, never in build() — the clamp line is the ONLY place it may appear"
    - "hasClients guard before touching ScrollController.position — the empty state renders no scroll view, and a schedule can also empty out between the frame that scheduled the callback and the frame it runs in"

key-files:
  created: []
  modified:
    - lib/screens/today/today_screen.dart
    - test/screens/today_screen_test.dart

key-decisions:
  - "PD-15 through PD-19 (the plan's own locked planner decisions) implemented exactly as specified: never construct ScrollController with a computed offset (flutter/flutter#96924); maxScrollExtent read only inside the post-frame callback; the Stack's leading offset resolved via getOffsetToReveal, not assumed zero; landing alignment stays centred; a state transition on an already-mounted tree does not re-centre (PD-19) — only a new day or a DevClock jump re-arms the flag"
  - "Deviation: the '_didCentreOnOpen' grep-count acceptance criterion (expected 4) undercounts by one — the necessary one-shot boolean CHECK ('if (!_didCentreOnOpen)') is a fifth textual occurrence alongside declaration/set/two resets; implemented the standard check-then-set idiom (same shape as the pre-existing _didCentreLiveRow code and 26-PATTERNS.md's own sample) rather than contort the code to hit a literal count"
  - "Deviation: the 'ensureVisible' grep-count-zero criterion for the TEST file collides with two pre-existing, out-of-scope tester.ensureVisible calls (a WidgetTester helper, unrelated to the removed Scrollable.ensureVisible production API) in the Task 2/CAL-02 groups — left untouched, since removing them would break unrelated tap-target-scrolling assertions"

requirements-completed: [CAL-03]

# Metrics
duration: ~30min
completed: 2026-08-10
---

# Phase 26 Plan 05: Arithmetic Scroll-on-Open Replaces the Two-Flag Centre-on-Open Summary

**Phase 24's two centre-on-open flags, two `GlobalKey`s and two `Scrollable.ensureVisible` blocks collapsed into one `_didCentreOnOpen` flag and one post-frame `animateTo`, whose target is the timeline Stack's own leading offset (`RenderAbstractViewport.getOffsetToReveal`) plus `geometry.yFor(nowMinutes)`, clamped against `maxScrollExtent` read only post-layout — closing the DayComplete UAT gap by construction, not by a fallback branch.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-08-10T15:45:00Z (approx., following plan 04's completion)
- **Completed:** 2026-08-10T16:15:00Z (approx.)
- **Tasks:** 2/2 completed
- **Files modified:** 2 (0 created, 2 modified)

## Accomplishments

- `_liveRowKey`, `_didCentreLiveRow`, the `hasLiveRow` local, the live-row `addPostFrameCallback`/`Scrollable.ensureVisible` block, and the `KeyedSubtree(key: _liveRowKey, ...)` wrapper around the live row in `_buildPositionedRow` are all gone — the live row is now an ordinary `Positioned` child with no scroll-lookup key
- One `_didCentreOnOpen` flag replaces both of Phase 24's flags. It is set synchronously in `build()` before the post-frame callback is scheduled (T-22-08), and reset only on a new `dateYmd` or a `DevClock.offset` jump (Phase 25) — never on a tick
- The scroll target is computed entirely from `TimelineGeometry` and the Stack's own measured leading offset — no parallel offset arithmetic: `stackTop (via RenderAbstractViewport.getOffsetToReveal) + geometry.yFor(nowMinutes) - viewportHeight / 2`, clamped to `[0, maxScrollExtent]` with `maxScrollExtent` read exactly once, inside the callback (PD-16)
- `hasClients` guards the callback body before any `.position` access — the empty state renders no scroll view, and this is a regression-tested guard (T-26-08), not a defensive no-op
- Never passes a computed offset to `ScrollController`'s constructor (PD-15) — a one-line comment above the field names `flutter/flutter#96924`, the documented hard iOS crash this avoids
- New `Phase 26 — CAL-03 elapsed time recedes` test group (7 widget tests, nested inside the renamed `Task 3 — scroll-on-open + edge-state copy` group): a five-state table proving centre-on-open works unconditionally in every `NowState` (with `DayComplete` as the literal Phase 24 UAT regression guard), an arithmetically-recomputed target-equality assertion, a literal "past is off-screen" proof (the 8am chunk's rendered top sits above the viewport's own top edge at a mid-afternoon `Active` clock), a "centres once" tick-invariance test, a `DevClock` jump re-arm test (offset restored via a group-level `tearDown`), a rewrite of the retired 24-04 two-flag regression test proving PD-19 (a transition on an already-mounted tree does not re-centre, but a fresh mount always does, regardless of state), and an empty-state `hasClients` regression guard
- 555/555 tests passing (up from 551 baseline: −3 retired tests, +7 new tests), `flutter analyze` clean
- `resolveNowState` remains the single now-detector — this plan added no new call site
- `test/screens/today_screen_now_state_test.dart` untouched — confirmed via `git diff --name-only`

## Task Commits

Each task was committed atomically:

1. **Task 1: One flag, one arithmetic animateTo** - `37dd524` (feat)
2. **Task 2: CAL-03 assertion suite — the past is behind you, and stays there** - `c4fe0e9` (test)

_No TDD tasks in this plan (autonomous, type=auto, no tdd="true" markers)._

## Files Created/Modified

- `lib/screens/today/today_screen.dart` — `_liveRowKey`/`_didCentreLiveRow`/`hasLiveRow`/the live-row `ensureVisible` block/the `KeyedSubtree` wrapper all deleted; `_didCentreOnOpen` added with a rewritten field doc comment; the dateYmd reset and DevClock re-arm both flip to the new flag; the unconditional centre-on-open block replaced with the `getOffsetToReveal`-based arithmetic `animateTo`; `package:flutter/rendering.dart` imported for `RenderAbstractViewport`
- `test/screens/today_screen_test.dart` — Task 3's group renamed from `'Task 3 — centre the live row on open + edge-state copy'` to `'Task 3 — scroll-on-open + edge-state copy'`; the three old centre-on-open tests (including the `// REWRITTEN IN 26-05` placeholder) replaced by a nested `Phase 26 — CAL-03 elapsed time recedes` group (7 tests); `package:canopy/dev/dev_clock.dart` imported

## Decisions Made

- **PD-15 through PD-19** (the plan's own locked planner decisions) implemented exactly as specified — see key-decisions above for the two literal-grep-count deviations, both documented below.
- All five `NowState` table rows reuse the existing `longDayFixture()` (10 work chunks, 40 min apart, 8:00–13:20, first 7 completed) purely by varying the injected clock — no per-row resolution changes needed, since `resolveNowState`'s classification for this fixture is fully clock-driven. This kept the new group's fixture surface identical to the pre-existing `Task 3` fixture rather than introducing a second one.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug, doc/grep collision] `_didCentreOnOpen` grep count is 5, not the acceptance criterion's stated 4**

- **Found during:** Task 1
- **Issue:** The acceptance criterion states `grep -c '_didCentreOnOpen'` should equal 4, itemized as "declaration, synchronous set, dateYmd reset, DevClock reset." A correct one-shot flag needs a fifth textual occurrence: the boolean READ in `if (!_didCentreOnOpen) {`, which is distinct from the WRITE (`_didCentreOnOpen = true;`) on the next line. This is not avoidable without either (a) an unidiomatic single-line `assignment-inside-boolean-expression` trick (`!_didCentreOnOpen && (_didCentreOnOpen = true)`) to fold the check and the set onto one grep-matched line, or (b) leaving the count at 5. This is the exact same shape the pre-existing `_didCentreLiveRow` code already had (`if (!_didCentreLiveRow && hasLiveRow) { _didCentreLiveRow = true; ... }` — also 5 total occurrences counting its own field decl/dateYmd-reset/DevClock-reset), and 26-PATTERNS.md's own "Replacement shape" sample code shows the identical `if (!_didCentreOnOpen) { _didCentreOnOpen = true; ...}` two-line shape.
- **Fix:** Kept the standard, readable `if (check) { set; ... }` idiom rather than obscuring the logic to satisfy a literal count the plan's own reference sample doesn't itself satisfy either.
- **Files modified:** `lib/screens/today/today_screen.dart` (no additional change beyond the already-planned code — this is a documentation-of-mismatch entry, not a fix)
- **Verification:** `grep -c '_didCentreOnOpen' lib/screens/today/today_screen.dart` returns `5`; every other literal-grep acceptance criterion in the task (addPostFrameCallback==1, initialScrollOffset==0, maxScrollExtent==1 inside the callback, hasClients==1, getOffsetToReveal==1) passes exactly as specified.
- **Committed in:** `37dd524` (Task 1 commit)
- **Note:** Mirrors the precedent set by `26-03-SUMMARY.md` (deviation 1, a `TimelineGeometry.forDay` doc-comment/grep collision) and `26-04-SUMMARY.md` (deviation 1, an `IgnorePointer`/`is! Active` collision) — this plan's own acceptance criteria occasionally undercounts a necessary code shape. Flagged here per the deviation-rules' documentation requirement rather than silently accepted or silently "fixed" by obscuring the code.

**2. [Rule 1 - Bug, doc/grep collision] `ensureVisible` grep count in the TEST file is 2, not the acceptance criterion's stated 0**

- **Found during:** Task 2
- **Issue:** The acceptance criterion `grep -c 'ensureVisible' test/screens/today_screen_test.dart` equals `0` collides with two pre-existing, out-of-scope calls: `tester.ensureVisible(find.text('Reading'))` (Task 2 group, line ~492) and `tester.ensureVisible(completeButton)` (the CAL-02 hit-testing test, line ~978). Both are calls to `WidgetTester.ensureVisible` — a test-harness helper that scrolls a widget into view before tapping it — entirely unrelated to the production `Scrollable.ensureVisible` API this plan removes from `today_screen.dart`. Neither test is part of this plan's declared scope (Task 2 and the CAL-02 group were written in plans 03/04).
- **Fix:** Left both calls untouched — removing them would break the "tapping an unresolved non-live work row opens ChunkDetailSheet" test and the CAL-02 "hit-testing" test, since both need to scroll their target widget above the fold at the default test viewport before tapping it. No code change made.
- **Files modified:** none (documentation-of-mismatch entry only)
- **Verification:** `grep -n 'ensureVisible' test/screens/today_screen_test.dart` shows exactly these two `tester.ensureVisible` call sites, confirmed unrelated to this plan's diff via `git diff` (neither line is touched by this plan's commits).
- **Committed in:** n/a (no code change)
- **Note:** Same category as deviation 1 — an acceptance criterion phrased as a literal substring match that doesn't distinguish between the production API being removed and an unrelated test-harness method sharing the same name.

---

**Total deviations:** 2 auto-fixed (Rule 1 — both are literal-grep-count acceptance-criterion collisions with necessary/pre-existing code, not functional defects)
**Impact on plan:** No scope creep. Both deviations are pure documentation of an acceptance-criterion mismatch; no code was altered to chase either count, since doing so would have meant either obscuring readable code (deviation 1) or breaking unrelated tests (deviation 2). All other literal-grep acceptance criteria in both tasks pass exactly.

## Issues Encountered

None beyond the two deviations above — both were understood, isolated, and did not require iteration (the code was correct on the first implementation; only the acceptance-criteria wording didn't anticipate them).

## Known Stubs

None — every code path added renders or computes from real, already-loaded data (`geometry`, `nowMinutes`, the Stack's own measured `RenderBox`); no placeholder or hardcoded-empty value was introduced.

## Threat Flags

None beyond `26-05-PLAN.md`'s own threat register (T-26-07, the `initialScrollOffset` hard-crash guard — implemented via PD-15 and the `grep -c 'initialScrollOffset' == 0` gate, which passes; T-26-08, the `hasClients` clientless-controller guard — implemented and covered by the new empty-state regression test; T-26-SC accepted, no packages installed).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

CAL-01, CAL-02, and CAL-03 are all now implemented and asserted. Plan 06 (real-browser verification via `tools/serve-uat.py`) can proceed — this plan changes no visual/text content, only scroll-position arithmetic, so plan 06's checks (harness-bound text-fit assertions, `kPixelsPerMinute`'s provisional-value real-browser recheck) are unaffected by this plan's scope. No blockers.

---
*Phase: 26-the-day-has-a-shape*
*Completed: 2026-08-10*

## Self-Check: PASSED

Both modified files confirmed present on disk (`lib/screens/today/today_screen.dart`,
`test/screens/today_screen_test.dart`); SUMMARY.md itself confirmed present; both task commit
hashes (`37dd524`, `c4fe0e9`) confirmed present in `git log --oneline --all`.
