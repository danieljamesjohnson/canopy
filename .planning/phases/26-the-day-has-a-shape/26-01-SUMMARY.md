---
phase: 26-the-day-has-a-shape
plan: 01
subsystem: ui
tags: [flutter, material3, layout-arithmetic, timeline, colorscheme]

# Dependency graph
requires:
  - phase: 24-where-am-i
    provides: "NowMarker widget and its Semantics-wrapping convention (24-REVIEW.md WR-01), which this plan's NowLineOverlay doc comment carries forward"
  - phase: 23-live-activity-tracking
    provides: "LiveRowCard's content-driven 'let now break the grid' contract, measured here as the source of kLiveRowReservedHeight"
provides:
  - "TimelineGeometry — the pure minute-to-pixel authority for Phase 26's proportional Today surface (yFor, heightFor, totalHeight, hourBoundaries, the live-row liveExtraPx exception)"
  - "NowLineOverlay and HourAxisLine — additive, unreferenced overlay widgets ready for wiring in plans 03-05"
  - "floorToHour, ceilToHour, hourBoundariesIn, formatHourLabel — pure hour-range helpers in time_format.dart"
  - "kPixelsPerMinute=5.5, kLiveRowReservedHeight=240.0, kFullTierMinHeight=132.0, kFullBreakMinHeight=88.0, kNowLineHeight=28.0, kHourAxisHeight=20.0"
affects: [26-02-density-tiers, 26-03-timeline-rework, 26-04-stack-wiring, 26-05-scroll-on-open, 26-06-real-browser-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure geometry class (TimelineGeometry) with a factory constructor deriving invariant-preserving state (rangeStart/rangeEnd always contain nowMinutes) — no widget-tree or clock access"
    - "liveExtraPx: a single additive term folded into yFor at and after liveEndMinutes, so every consumer (rows, hour axis, now-line, future scroll target) stays in register with the live row's swelled height without a second layout pass"
    - "Overlay widgets carry no Semantics of their own — the call site wraps the whole positioned element, outside IgnorePointer, per 24-REVIEW.md WR-01"

key-files:
  created:
    - lib/screens/today/timeline_geometry.dart
    - lib/screens/today/widgets/now_line.dart
    - lib/screens/today/widgets/hour_axis.dart
  modified:
    - lib/utils/time_format.dart
    - test/utils/time_format_test.dart
    - test/screens/today_timeline_model_test.dart
    - test/screens/today_row_widgets_test.dart
    - .planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md

key-decisions:
  - "PD-1: kPixelsPerMinute corrected to 5.5 (was 4.0) — a measured 126px Full-tier ChunkCard overflows a 4.0-scale 25min slot by 26px"
  - "PD-2: kLiveRowReservedHeight=240.0, a fixed estimate (not a two-pass GlobalKey/RenderBox measurement) — measured LiveRowCard height is 230px"
  - "PD-3: density tiers (kFullTierMinHeight/kFullBreakMinHeight) expressed in pixels, not minutes, so they don't rot if the scale changes again"
  - "floorToHour(545) implemented as 540 (not the plan prose's '480'), matching PATTERNS.md's exact formula and every downstream range assertion — the plan's own worked example was an isolated typo"

patterns-established:
  - "Doc-comment-with-worked-numeric-example convention extended to the new hour-range helpers, matching the file's existing formatters"
  - "kPixelsPerMinute's doc comment explicitly flags itself as flutter-test-harness-derived and provisional pending plan 06's real-browser check"

requirements-completed: [CAL-01, CAL-02, CAL-03]

# Metrics
duration: 41min
completed: 2026-08-10
---

# Phase 26 Plan 01: Timeline Geometry & Overlay Widgets Summary

**Pure minute-to-pixel arithmetic (`TimelineGeometry`) plus two additive, unreferenced overlay widgets (`NowLineOverlay`, `HourAxisLine`) — nothing wired into `TodayScreen`, corrected `kPixelsPerMinute` from 4.0 to 5.5 against a measured `ChunkCard` overflow.**

## Performance

- **Duration:** 41 min
- **Started:** 2026-08-10T14:15:00Z (approx.)
- **Completed:** 2026-08-10T14:56:29Z
- **Tasks:** 3/3 completed
- **Files modified:** 8 (3 created, 5 modified)

## Accomplishments
- `TimelineGeometry` — a pure, immutable class mapping any minute-of-day to a pixel offset, with `forDay()` deriving `rangeStart`/`rangeEnd` so "now" is always inside the rendered range by construction (PreStart/Active/DayComplete all covered), and the live-row exception folded into a single `liveExtraPx` term applied consistently everywhere
- `NowLineOverlay` and `HourAxisLine` — render-only widgets sourcing all color from `ColorScheme` slots, carrying no `Semantics` node of their own, isolated-widget-tested
- Four new pure hour helpers (`floorToHour`, `ceilToHour`, `hourBoundariesIn`, `formatHourLabel`) in `time_format.dart`
- Corrected and documented `kPixelsPerMinute` (4.0 → 5.5) against a live measurement, with a dated amendment appended to `26-UI-SPEC.md`
- Zero wiring into `today_screen.dart` — confirmed via grep; the running app is visually unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Hour-range helpers in time_format.dart** - `8ad18f0` (feat)
2. **Task 2: TimelineGeometry — the minute-to-pixel authority** - `7f3441e` (feat)
3. **Task 3: NowLineOverlay and HourAxisLine widgets** - `e455e42` (feat)

_No TDD tasks in this plan (autonomous, type=auto, no tdd="true" markers)._

## Files Created/Modified
- `lib/screens/today/timeline_geometry.dart` - `TimelineGeometry` class + six geometry constants (kPixelsPerMinute, kLiveRowReservedHeight, kFullTierMinHeight, kFullBreakMinHeight, kNowLineHeight, kHourAxisHeight)
- `lib/screens/today/widgets/now_line.dart` - `NowLineOverlay`: full-content-width 2dp primary rule + "Now · <time>" chip
- `lib/screens/today/widgets/hour_axis.dart` - `HourAxisLine`: hour label in a kGutterWidth column + outlineVariant hairline
- `lib/utils/time_format.dart` - added `floorToHour`, `ceilToHour`, `hourBoundariesIn`, `formatHourLabel`
- `test/utils/time_format_test.dart` - 19 new tests (4 groups)
- `test/screens/today_timeline_model_test.dart` - 12 new tests (`TimelineGeometry` group)
- `test/screens/today_row_widgets_test.dart` - 7 new tests (`NowLineOverlay`, `HourAxisLine` groups)
- `.planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md` - dated amendment recording the 4.0 → 5.5 correction

## Decisions Made
- **PD-1/PD-2/PD-3** (the plan's own locked planner decisions) were implemented exactly as specified: `kPixelsPerMinute = 5.5`, `kLiveRowReservedHeight = 240.0` as a fixed estimate, density tiers in pixels not minutes.
- `floorToHour(545)` implemented as `540`, not the plan prose's stated `480` — see Deviations below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected `floorToHour`'s worked example from the plan's inconsistent prose**
- **Found during:** Task 1 (Hour-range helpers)
- **Issue:** The plan's `<action>` text states `floorToHour(545) → 480`, but this directly contradicts (a) `26-PATTERNS.md`'s exact specified formula for the function (`(minutes ~/ 60) * 60`, which computes `540` for input `545`), (b) the plan's own adjacent example (`540 → 540`, confirming idempotent hour-alignment, incompatible with `545` skipping all the way back to `480`), and (c) this same plan's Task 2 acceptance criteria, which rely on the standard floor semantics (e.g. `floorToHour(390) == 360` for the PreStart range case). `545 → 480` is mathematically impossible for a floor-to-hour function (545 minutes = 9:05 AM; the correct floor is 9:00 AM = 540, not 8:00 AM = 480).
- **Fix:** Implemented `floorToHour` per `26-PATTERNS.md`'s exact formula (`(minutes ~/ 60) * 60`), verified consistent with every other worked example in the plan and with `TimelineGeometry.forDay`'s downstream range assertions. Wrote the test to expect `540`, with an inline comment explaining the correction.
- **Files modified:** `test/utils/time_format_test.dart` (test expectation and explanatory comment); `lib/utils/time_format.dart`'s implementation was never at risk of the bug — it always matched the PATTERNS.md formula.
- **Verification:** `flutter test test/utils/time_format_test.dart` passes (31/31); `TimelineGeometry`'s PreStart/DayComplete range tests in Task 2 (which depend on `floorToHour`/`ceilToHour` behaving consistently) also pass.
- **Committed in:** `8ad18f0` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — plan documentation bug, not a code defect)
**Impact on plan:** No scope creep. The fix keeps `floorToHour` internally consistent with its own formula spec and with every downstream consumer in this same plan; had the literal `480` example been implemented instead, `TimelineGeometry.forDay`'s own acceptance criteria (e.g. `PreStart: rangeStart == 360` from `floorToHour(390)`) would have been unimplementable without a second, contradictory floor rule.

## Issues Encountered

`grep -rn "resolveNowState" lib/ | wc -l` returns `13`, not the `2` stated in this execution's `<critical_invariants>`. Investigated: this count is entirely pre-existing (doc-comment cross-references in `time_format.dart`, `timeline.dart`, `today_screen.dart`, `now_state.dart`, `schedule_notifier.dart`, plus the one real definition and one real call site) — confirmed via `git diff --stat -- lib/screens/today/today_screen.dart` returning empty, and this plan never touches `now_state.dart` or `schedule_notifier.dart` at all. Not caused by this plan's changes and out of this plan's stated file scope (`files_modified` in the frontmatter lists only `time_format.dart`, `timeline_geometry.dart`, `now_line.dart`, `hour_axis.dart`, and their test files/`26-UI-SPEC.md`) — logged here per the SCOPE BOUNDARY rule rather than "fixed."

## Known Stubs

None — this plan produces pure functions and self-contained render-only widgets, none of which have a data-wiring seam to stub. `NowLineOverlay`/`HourAxisLine` are unreferenced by any screen (deliberately, per this plan's objective); they render correctly in isolation when given a `nowMinutes`/`hourMinutes` value directly, which the widget tests confirm.

## Threat Flags

None. This plan is pure local arithmetic and render-only widgets on already-trusted `int` inputs — consistent with `26-01-PLAN.md`'s own threat register (T-26-01, the defensive `yFor`/`heightFor` clamp, is implemented as specified; T-26-SC is a documented no-op, no packages installed).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

`TimelineGeometry`, `NowLineOverlay`, and `HourAxisLine` are ready for wiring in plans 02-05. Plan 02 (density tiers) can consume `kFullTierMinHeight`/`kFullBreakMinHeight` directly. Plans 04-05 can consume `TimelineGeometry.forDay()`, `yFor`, `heightFor`, and `hourBoundaries` for the `Stack`/`Positioned` migration. `kPixelsPerMinute`'s doc comment explicitly flags itself as `flutter-test`-harness-derived and provisional — plan 06's real-browser check via `tools/serve-uat.py` is the stated authority, not this plan's measurement, and should not be skipped.

No blockers. `now_marker.dart` deliberately still exists and is still referenced by `today_screen.dart` — its deletion is explicitly plan 26-03's responsibility, not this plan's.

---
*Phase: 26-the-day-has-a-shape*
*Completed: 2026-08-10*
