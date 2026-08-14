---
phase: 26-the-day-has-a-shape
plan: 04
subsystem: ui
tags: [flutter, material3, timeline, stack-positioned, semantics, colorscheme]

# Dependency graph
requires:
  - phase: 26-the-day-has-a-shape (plan 01)
    provides: "NowLineOverlay, HourAxisLine, TimelineGeometry.yFor/hourBoundaries — the widgets and arithmetic this plan wires in"
  - phase: 26-the-day-has-a-shape (plan 03)
    provides: "The timeline Stack surface (SizedBox + Stack of Positioned rows) this plan layers Layer 2 and Layer 3 onto; NowMarkerRow already deleted"
provides:
  - "The now-line (CAL-02) rendering unconditionally in every NowState, as Layer 3 of the timeline Stack — Phase 24's Active-suppression rule deleted outright, not relocated"
  - "The hour axis (Layer 2) — one HourAxisLine per TimelineGeometry.hourBoundaries entry, painted behind row content"
  - "A CAL-02 widget-test suite (10 tests) covering all five NowState variants, mid-chunk positioning, motion, semantics, hit-testing, and colour"
affects: [26-05-scroll-on-open, 26-06-real-browser-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Semantics(excludeSemantics: true) wraps IgnorePointer at the call site, not the reverse (PD-13) — modern IgnorePointer also strips its subtree from the semantics tree, so nesting the label inside it would silently delete the announcement"
    - "Unconditional overlay rendering — no if/ternary/state-check guards a Positioned's presence — is how a suppression rule gets deleted rather than relocated"

key-files:
  created: []
  modified:
    - lib/screens/today/today_screen.dart
    - test/screens/today_screen_test.dart

key-decisions:
  - "PD-12/PD-13/PD-14 (the plan's own locked planner decisions) implemented exactly as specified: now-line unconditional in every NowState, Semantics outside IgnorePointer, tick cadence untouched"
  - "The CAL-02 hit-testing test targets the live row's own Complete button, not a separate non-live unresolved chunk's card — see Deviations for why the latter is structurally unreachable under resolveNowState"

requirements-completed: [CAL-02]

# Metrics
duration: ~45min
completed: 2026-08-10
---

# Phase 26 Plan 04: Wire the Hour Axis and Now-Line into the Timeline Stack Summary

**Layers 2 (hour axis) and 3 (now-line) wired as unconditional `Positioned` overlays into the timeline `Stack` — CAL-02's whole premise (the line can sit truthfully mid-chunk) now literally supersedes Phase 24's `Active`-suppression rule, which is deleted outright.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-08-10T14:56:29Z (approx., following plan 03's completion)
- **Completed:** 2026-08-10T15:43:25Z
- **Tasks:** 2/2 completed
- **Files modified:** 2 (0 created, 2 modified)

## Accomplishments
- `today_screen.dart`'s timeline `Stack` now renders three layers in the exact z-order the UI-SPEC specifies: Layer 2 (hour axis, behind row content, `IgnorePointer` + `ExcludeSemantics`), Layer 1 (rows, unchanged from plan 03), Layer 3 (the now-line, topmost, `Semantics` wrapping `IgnorePointer` wrapping `NowLineOverlay`)
- The now-line is unconditional — no `if`, no ternary, no state check gates its presence (PD-12). Phase 24's `nowState is! Active` suppression is gone from the render path entirely, not relocated
- `Semantics(label: 'Now — <time>', excludeSemantics: true)` sits OUTSIDE `IgnorePointer` at the call site (PD-13) — verified by a dedicated widget test asserting exactly one `Now — 9:12 AM` semantics node
- New `Phase 26 — CAL-02 the now-line` test group (10 widget tests, replacing the deleted Phase 24 now-marker suite): no-suppression across all five `NowState` variants (table-driven), mid-chunk truth (25-min chunk at 9:00, clock 9:12 — offset recomputed from `TimelineGeometry`'s own arithmetic, never a hard-coded pixel constant), motion (exactly `kPixelsPerMinute` per tick), PreStart/DayComplete representability at the rendered range's edges, locked chip copy (`'Now · 9:12 AM'`), semantics, hit-testing (a Complete tap lands through the line), and colour (`colorScheme.primary` for the rule, `colorScheme.outlineVariant` for the hour hairline)
- 551/551 tests passing (up from 541 baseline — 10 new CAL-02 assertions), `flutter analyze` clean
- `today_screen_now_state_test.dart` untouched — confirmed via `git diff --name-only`
- `resolveNowState` remains the single now-detector — no new call site added by this plan

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire the hour axis and the now-line into the timeline Stack** - `607c9a5` (feat)
2. **Task 2: CAL-02 assertion suite — the line is right in every state, including mid-chunk** - `544d302` (test)

_No TDD tasks in this plan (autonomous, type=auto, no tdd="true" markers)._

## Files Created/Modified
- `lib/screens/today/today_screen.dart` - Imports `widgets/hour_axis.dart` and `widgets/now_line.dart`; the timeline `Stack`'s `children` list gains Layer 2 (one `Positioned(IgnorePointer(ExcludeSemantics(HourAxisLine(...))))` per `geometry.hourBoundaries` entry) and Layer 3 (exactly one `Positioned(Semantics(IgnorePointer(NowLineOverlay(...))))`, unconditional)
- `test/screens/today_screen_test.dart` - Adds the `Phase 26 — CAL-02 the now-line` nested group (10 tests) inside the existing `Task 2` group, with its own dedicated two-chunk fixture (`twoChunkFixture`) distinct from `buildDayFixture()` — chosen specifically to hit all five `NowState` variants cleanly by clock alone and to match the plan's own worked example (25-minute chunk at 9:00, clock 9:12) verbatim

## Decisions Made
- **PD-12/PD-13/PD-14** implemented exactly as specified: the now-line is unconditional, `Semantics` wraps `IgnorePointer` (not the reverse), and the tick cadence (`Duration(minutes: 1)` / `Duration(seconds: 1)`) is byte-for-byte unchanged.
- Chose a dedicated `twoChunkFixture()` for the CAL-02 test group instead of stretching `buildDayFixture()` — `buildDayFixture()`'s chunks don't cleanly separate PreStart/Active/Overdue/GapBeforeNext/DayComplete by clock alone (its live chunk is only 5 minutes), and the plan's own worked example (a 25-minute chunk starting at 9:00, clock 9:12) needed an exact match. This mirrors the CAL-01 group's own precedent of building a small dedicated fixture for the 5-minute-break case rather than forcing one fixture to serve every assertion.
- The hit-testing test (`task 2, item 7`) targets the live row's `LiveRowCard` Complete button, not a separate non-live `ChunkCard`'s Complete button — see Deviations below for the reasoning; this is a plan-language interpretation, not a scope change, and is flagged prominently per the deviation-rules' documentation requirement.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Reworded two doc comments to avoid inflating literal grep-count acceptance gates**
- **Found during:** Task 1
- **Issue:** The plan's own acceptance criteria are exact literal `grep -c` counts: `grep -c 'IgnorePointer' lib/screens/today/today_screen.dart` must equal `2` (one hour-axis wrap, one now-line wrap), and `grep -c 'nowState is! Active\|is! Active' ...` must equal `0`. My first draft's explanatory doc comments above Layer 2/Layer 3 used the literal words "IgnorePointer" and the phrase "`nowState is! Active`" in prose to explain the design — which made the grep counts `5` and `1` (comment matches) respectively, failing both literal gates even though the actual code was correct (exactly 2 real `IgnorePointer(` widget instantiations, and the only real `is! Active` in the file is a pre-existing, unrelated line — see Issue below).
- **Fix:** Reworded the prose to describe the mechanism ("wrapped below so it never eats a tap", "the pointer-ignoring wrapper below", "the state-check suppression that used to hide it whenever the current moment fell outside an active chunk's window") without repeating the literal identifier/expression, preserving the same explanation.
- **Files modified:** `lib/screens/today/today_screen.dart` (two comment blocks, no functional code change)
- **Verification:** `grep -c 'IgnorePointer' lib/screens/today/today_screen.dart` → `2`. `grep -n 'is! Active' lib/screens/today/today_screen.dart` → only the pre-existing, unrelated line 847 (see Issues Encountered).
- **Committed in:** `607c9a5` (Task 1 commit)
- **Note:** This mirrors `26-03-SUMMARY.md`'s own deviation 1 (a doc comment reworded to avoid an identical literal-grep collision with `TimelineGeometry.forDay`) — same category of issue, same resolution.

**2. [Rule 1 - Bug] Scoped the hit-testing test's Complete-button finder to the live row**
- **Found during:** Task 2, first test run
- **Issue:** `find.widgetWithText(FilledButton, 'Complete')` (no scope) threw `Bad state: Too many elements` inside `tester.ensureVisible` — the fixture's `w2` (unresolved, non-live, Full-tier at 137.5px ≥ 132px threshold) also renders its own Complete/Skip action row via `ChunkCard`, so the finder matched two `FilledButton`s: the live row's and `w2`'s.
- **Fix:** Scoped the finder with `find.descendant(of: find.byType(LiveRowCard), matching: find.widgetWithText(FilledButton, 'Complete'))`, matching exactly the live row's own button.
- **Files modified:** `test/screens/today_screen_test.dart` (one finder, plus an explanatory comment)
- **Verification:** `flutter test test/screens/today_screen_test.dart` — 52/52 pass, including this test.
- **Committed in:** `544d302` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (Rule 1 — one plan-acceptance-gate/doc-comment collision, one test-finder ambiguity discovered while writing the new test)
**Impact on plan:** No scope creep. Both fixes are non-functional (comment wording, test finder specificity) and were necessary for the plan's own literal acceptance gates and for a genuinely passing test to both hold.

## Issues Encountered

`grep -n 'is! Active' lib/screens/today/today_screen.dart` returns one hit at line 847: `if (nowState is! Active) return null;`, inside `_liveSecondsRemaining` — a pre-existing, unrelated guard (it decides whether to compute the live row's countdown, nothing to do with now-line suppression). Confirmed via `git diff --unified=0 lib/screens/today/today_screen.dart` that this line is NOT part of this plan's diff — it predates this plan and this plan never touches `_liveSecondsRemaining`. This is the same class of pre-existing false-positive documented in `26-01-SUMMARY.md`'s "Issues Encountered" (the `resolveNowState` grep count of 13 vs. an expected 2) — logged per the SCOPE BOUNDARY rule rather than "fixed," since "fixing" a correct, unrelated method to satisfy an overly-broad grep pattern would itself be an out-of-scope change.

Separately, `grep -c 'Colors\.' lib/screens/today/today_screen.dart` returns `1` — a pre-existing doc comment at line 1004 (`// Colors.white\` — a raw Colors.white violates the UI-SPEC colour rule,`) explaining why the file does NOT use `Colors.white`, not an actual literal. Not part of this plan's diff. `now_line.dart` and `hour_axis.dart` both return `0`, matching the plan's actual intent (zero raw colour literals in code).

`resolveNowState` grep count is `13` (pre-existing since plan 01, documented there) — this plan added no new call site; `grep -rn 'resolveNowState' lib/ | wc -l` is unchanged from the value at the start of this plan.

## Known Stubs

None — both overlays render real, data-derived content (`geometry.yFor`/`hourBoundaries` computed from the day's actual chunks and clock sample); nothing is hardcoded to an empty or placeholder value.

## Threat Flags

None beyond `26-04-PLAN.md`'s own threat register (T-26-05, the `IgnorePointer` hit-testing mitigation — implemented and asserted by the new hit-testing test; T-26-06, the `Semantics`-outside-`IgnorePointer` accessibility guard — implemented per PD-13 and asserted by the new semantics test; T-26-SC accepted, no packages installed).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The now-line and hour axis are fully wired and asserted. Plan 05 (scroll-on-open) can proceed: `_liveRowKey`/`_didCentreLiveRow` were left untouched by this plan as instructed, and the now-line's position (`geometry.yFor(nowMinutes)`) is now a stable, tested quantity plan 05's arithmetic centre-on-open replacement can reference without re-deriving anything. No blockers.

`kPixelsPerMinute`'s doc comment still flags itself as `flutter-test`-harness-derived and provisional — plan 06's real-browser check via `tools/serve-uat.py` remains the stated authority, unaffected by this plan.

---
*Phase: 26-the-day-has-a-shape*
*Completed: 2026-08-10*

## Self-Check: PASSED

All modified files confirmed present on disk; both task commit hashes (607c9a5, 544d302) confirmed present in `git log --oneline --all`.
