---
phase: 26-the-day-has-a-shape
plan: 02
subsystem: ui
tags: [flutter, material3, chunk-card, density, timeline-row]

# Dependency graph
requires:
  - phase: 26-the-day-has-a-shape (plan 01)
    provides: "kFullTierMinHeight/kFullBreakMinHeight pixel thresholds and TimelineGeometry, which plan 04 will pair with this plan's ChunkCardDensity to pick a density per row"
provides:
  - "ChunkCardDensity enum (detailed/full/compact) on ChunkCard and SwipeableChunkCard, defaulting to detailed — today's card, byte-for-byte, on every existing call site"
  - "A parameterised _DashedBorderPainter (dashWidth/dashGap/radius, defaulting to the prior hardcoded 4/4/12) reused for the Compact-tier break's tighter 2/2/6 geometry"
  - "TimelineRowTile as a pure 16dp-inset + kGutterWidth-reserved-blank-column wrapper — startMinutes deleted outright (PD-5)"
  - "FreeTimeRow centring its rule+label within whatever height its parent allocates, instead of intrinsic top-aligned padding"
affects: [26-03-timeline-rework, 26-04-stack-wiring, 26-05-scroll-on-open, 26-06-real-browser-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Density-as-enum-parameter, not a second widget: ChunkCard/SwipeableChunkCard both carry a ChunkCardDensity field defaulting to today's behaviour, so every existing caller is unaffected until plan 04 explicitly opts a call site into full/compact"
    - "Shared outer wrapper, density-branched inner content: _WorkChunkContent's Card/Stack/coloured-bar/Opacity(0.5)/commitment-tertiaryContainer wrapper is identical across all three densities — only the Column passed into the content padding changes, so D-02 (no box-height clamping) is enforced by construction, not by convention"
    - "Reserved-but-blank layout column: TimelineRowTile keeps kGutterWidth's SizedBox for horizontal alignment but its child is now always SizedBox.shrink() — a persistent overlay (the hour axis, plan 01) owns what's drawn in that column instead of a per-row widget"

key-files:
  created: []
  modified:
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart
    - lib/screens/today/widgets/timeline_row_tile.dart
    - lib/screens/today/widgets/free_time_row.dart
    - lib/screens/today/today_screen.dart
    - test/screens/today_row_widgets_test.dart
    - test/screens/today_screen_test.dart

key-decisions:
  - "PD-4 (implemented as specified): ChunkCardDensity has three values with detailed as the default byte-for-byte-unchanged card, so the four standalone chunk_card_*_test.dart files needed zero edits"
  - "PD-5 (implemented as specified): TimelineRowTile's startMinutes parameter deleted outright, not left dead; the kGutterWidth column stays reserved but renders nothing"
  - "PD-6 confirmed by re-verification: no task was written to 'remove break tap targets' — breaks still have no onTap anywhere in the tree"
  - "Reworded one kGutterWidth doc-comment line that named formatMinutesCompact by identifier, replacing it with a prose description of the same fact — resolves an internal conflict between the plan's 'keep the doc comment verbatim' instruction and its own 'grep formatMinutesCompact == 0' acceptance criterion without losing any of the historical 46->75->52 correction story"

requirements-completed: [CAL-01]

# Metrics
duration: ~45min
completed: 2026-08-10
---

# Phase 26 Plan 02: Density Tiers & Gutter Strip Summary

**ChunkCard gained a three-value ChunkCardDensity (detailed/full/compact, default detailed) with content-only degradation at small sizes, and TimelineRowTile was stripped down to a pure inset+reserved-column wrapper — TodayScreen renders identically to before this plan.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-08-10 (approx, following 26-01)
- **Completed:** 2026-08-10T15:11:05Z
- **Tasks:** 2/2 completed
- **Files modified:** 7 (0 created, 7 modified)

## Accomplishments
- `ChunkCardDensity` enum (`detailed`/`full`/`compact`) added to `ChunkCard` and `SwipeableChunkCard`, both defaulting to `detailed` — today's card, unchanged
- `_buildBreak` and `_WorkChunkContent` branch on density; every branch changes CONTENT only — no box height is ever floored, ceilinged, or clamped (D-02), verified by grep (zero `height:` additions) and by construction (the Card/Stack/coloured-bar wrapper is shared across all three densities)
- `_DashedBorderPainter` parameterised with `dashWidth`/`dashGap`/`radius` (defaults 4/4/12 preserve the existing Full-tier call site byte-for-byte); the Compact-tier break uses 2/2/6
- `SwipeableChunkCard` forwards `density` on both the break early-return path and the work path — regression-guarded by a new test that pumps a compact break through the wrapper and confirms the density survives
- `TimelineRowTile` is now a pure 16dp-inset + `kGutterWidth`-reserved-blank-column wrapper; `startMinutes` deleted outright, along with the `formatMinutesCompact` call and the `time_format.dart` import
- `FreeTimeRow` centres its dotted-rule + label within whatever height its parent allocates, instead of an intrinsic `Padding(vertical: 8)`
- All four `TimelineRowTile(` call sites in `today_screen.dart` updated to the new signature; the four standalone `chunk_card_*_test.dart` files needed zero edits (`git diff --stat` confirms)
- 555/555 tests passing, `flutter analyze` clean

## Task Commits

Each task was committed atomically:

1. **Task 1: ChunkCardDensity — three render densities and a parameterised dashed painter** - `8e5fd19` (feat)
2. **Task 2: Inset-only TimelineRowTile and a vertically-centring FreeTimeRow** - `5fb7c57` (refactor)

_No TDD tasks in this plan (autonomous, type=auto, no tdd="true" markers)._

## Files Created/Modified
- `lib/screens/schedule/widgets/chunk_card.dart` - `ChunkCardDensity` enum; density-aware `_buildBreak` and `_WorkChunkContent` (split into `_buildDetailedContent`/`_buildFullContent`/`_buildCompactContent` sharing `_buildTrailingStatus`/`_buildActionRow`); parameterised `_DashedBorderPainter`
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` - `density` field forwarded on both the break early-return and work paths
- `lib/screens/today/widgets/timeline_row_tile.dart` - `startMinutes` deleted; gutter `SizedBox` always renders `SizedBox.shrink()`; doc comments updated to explain the hour axis now owns that column
- `lib/screens/today/widgets/free_time_row.dart` - outer `Padding(vertical: 8)` replaced with `Center`; inner `Row` gets `mainAxisSize: MainAxisSize.min`
- `lib/screens/today/today_screen.dart` - four `TimelineRowTile(` call sites drop `startMinutes:`; `NowMarkerRow` arm's stale doc comment corrected to describe the new blank-gutter reality
- `test/screens/today_row_widgets_test.dart` - new `ChunkCardDensity` group (detailed/full/compact assertions, break density sub-group, `SwipeableChunkCard` forwarding regression guard); `TimelineRowTile` group rewritten for the new signature; `NowMarker`-wrapped-in-`TimelineRowTile` test updated to assert the gutter renders no time text
- `test/screens/today_screen_test.dart` - deleted the gutter-compact-time test; updated the G-04 alignment test, the WR-01 double-announcement test, and four now-marker NowState tests (PreStart/GapBeforeNext/DayComplete/Single-sample-agreement) to stop asserting gutter text that no longer renders

## Decisions Made
- **PD-4/PD-5/PD-6** (the plan's own locked planner decisions) implemented exactly as specified.
- Reworded one line of `kGutterWidth`'s doc comment (see Deviations) to resolve an internal plan conflict without losing any information.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Plan documentation bug] Resolved a conflict between "keep the doc comment verbatim" and the `formatMinutesCompact` grep acceptance criterion**
- **Found during:** Task 2 (Inset-only TimelineRowTile)
- **Issue:** The plan's `<action>` text says "Keep `kGutterWidth` and its entire doc comment verbatim," but that doc comment's own prose names `formatMinutesCompact` by identifier (as part of the 46→75→52 correction story). The plan's own acceptance criteria separately requires `grep -c 'formatMinutesCompact' lib/screens/today/widgets/timeline_row_tile.dart` to equal `0`. Both instructions cannot be satisfied literally at once — verbatim retention of the comment guarantees a nonzero grep hit.
- **Fix:** Reworded the single sentence that named the function ("`formatMinutesCompact`'s 6-character maximum" → "the compact time-format's 6-character maximum"), preserving 100% of the historical information (the 46→75→52 correction story, the real-browser measurement, the reasoning) while satisfying the literal grep gate. No functional code was affected — the actual `formatMinutesCompact` call site, its `time_format.dart` import, and the ternary that used it were already deleted per the plan's explicit instruction, unrelated to this wording fix.
- **Files modified:** `lib/screens/today/widgets/timeline_row_tile.dart` (one doc-comment line)
- **Verification:** `grep -c 'formatMinutesCompact' lib/screens/today/widgets/timeline_row_tile.dart` returns `0`; the doc comment's substance (readable by any future agent) is unchanged.
- **Committed in:** `5fb7c57` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — plan documentation bug, not a code defect)
**Impact on plan:** No scope creep. The fix is a single doc-comment wording change that satisfies both of the plan's own conflicting instructions without dropping any of the institutional knowledge the comment exists to carry forward.

## Issues Encountered

Task 2's declared file scope (`today_screen_test.dart`) named exactly one test to delete ("the gutter shows the compact start time for timed rows," ~line 411), but removing `TimelineRowTile`'s gutter-time rendering also broke five other pre-existing tests in the same file that asserted the now-marker's gutter-rendered compact time as a side channel: the G-04 alignment test (asserted `find.text('8:00')`'s x-position), the WR-01 double-announcement test's explanatory comment, and three `NowState` marker tests (PreStart/GapBeforeNext/DayComplete) plus the "Single-sample agreement" test that all asserted a literal gutter time string (`'6:00'`, `'9:30'`, `'6:00p'`). These were fixed as Rule 1/Rule 3 (blocking issue directly caused by this task's own change, same file already in declared scope): the G-04 test now checks the reserved `SizedBox`'s x-position instead of a text node; the three `NowState` tests now assert the gutter text's *absence* (`findsNothing`) alongside the pre-existing `NowMarker` widget-presence assertion; the "Single-sample agreement" test now proves clock-sample agreement via the marker's own `Semantics` label (`bySemanticsLabel('Now — 9:30 AM')`) rather than a since-removed gutter `Text` comparison. All five were verified green after the fix; none of these changes touch `today_screen_now_state_test.dart` (confirmed untouched via `git diff --name-only`).

## Known Stubs

None — every branch added renders real content from data already passed in (`chunk.durationMinutes`, `goalName`, `displayRationale`, etc.); no new empty-array/empty-string/placeholder-text stub was introduced.

## Threat Flags

None. This plan is render-only widget work on already-trusted local data, consistent with `26-02-PLAN.md`'s own threat register (T-26-02, the completed/skipped indicator retained at Compact density, is implemented as specified; T-26-SC is a documented no-op, no packages installed).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

`ChunkCardDensity.full`/`.compact` and the now-blank `TimelineRowTile` gutter are ready for plan 04's `Stack`/`Positioned` wiring, which will be the first caller to actually pass `density: full`/`compact` based on a row's pixel height. `FreeTimeRow`'s centring is inert until a plan gives it a real proportional height to centre within (plan 04). No blockers.

`now_marker.dart` and its `TimelineRowTile`-wrapped `NowMarkerRow` switch arm deliberately still exist, per this plan's explicit scope boundary — their deletion/rewrite into an absolutely-positioned overlay is plan 03's job, not this plan's.

---
*Phase: 26-the-day-has-a-shape*
*Completed: 2026-08-10*
