---
phase: 23-live-activity-tracking
plan: 07
subsystem: ui
tags: [flutter, material3, today-screen, chunk-card, ui-spec]

# Dependency graph
requires:
  - phase: 23-live-activity-tracking (plan 05)
    provides: today_screen.dart's centre-on-open / edge-state-line changes this plan rebased on
provides:
  - "TimelineRowTile owns the row's 16dp horizontal inset (gutter aligns with header) — G-04"
  - "kGutterWidth widened 46.0 -> 75.0 with a widest-label fit test pinning it"
  - "ChunkCard._buildBreak scales visual weight for ChunkType.longBreak (padding/title/icon/stroke) — G-02"
  - "_DashedBorderPainter gains an optional strokeWidth field"
  - "TodayScreen's mood chip no longer duplicates the chunk count — G-06"
  - "22-UI-SPEC.md amended to match the shipped, count-free mood chip"
affects: [23-live-activity-tracking, 22-unified-today-screen]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Row-owns-inset: a parent row/tile owns shared horizontal padding so children carry vertical-only margins, keeping one source of truth for horizontal position"
    - "One derived isLong bool drives padding/typography/icon/stroke-weight branching inside a single _buildBreak method, no widget duplication"

key-files:
  created: []
  modified:
    - lib/screens/today/widgets/timeline_row_tile.dart
    - lib/screens/today/widgets/free_time_row.dart
    - lib/screens/today/widgets/live_row_card.dart
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/today/today_screen.dart
    - test/screens/today_row_widgets_test.dart
    - test/screens/today_screen_test.dart
    - .planning/phases/22-unified-today-screen/22-UI-SPEC.md

key-decisions:
  - "Bumped kGutterWidth 46.0 -> 75.0 rather than leaving it at 46: the plan's own widest-label fit test (TextPainter measuring the resolved gutter style) failed at 46dp under `flutter test`. Probed and confirmed the cause: flutter test's default text rendering has no real Roboto metrics loaded — every glyph renders as a fixed fontSize-wide box (verified: '1', 'i', 'W', ':', 'p' all measured exactly 12.0px at fontSize 12) — so the measured 74.4px for '12:45p' is a conservative, test-harness-driven bound, not a real-device measurement. Rounded up to 75.0 and documented the caveat in kGutterWidth's own doc comment so a future agent doesn't 'correct' it back down without re-reading why, and flagged it for a real-browser recheck per this project's CLAUDE.md guidance."
  - "The G-02 height/icon test and the width-bump both live in test/screens/today_row_widgets_test.dart per the plan's file list, alongside a new explicit no-new-interaction guard test (GestureDetector/ExpansionTile findsNothing on the break row) to keep the standing collapse/accordion prohibition test-enforced, not just documented."

requirements-completed: [UNIFY-01, G-02, G-04, G-06]

# Metrics
duration: ~35min
completed: 2026-08-08
---

# Phase 23 Plan 07: Gap closure — aligned gutter, weighted long break, single chunk count Summary

**Relocated the Today screen's 16dp horizontal inset from four child widgets onto TimelineRowTile itself (gutter now lines up with the header instead of sitting at x=0), scaled ChunkCard's long-break treatment to read visibly heavier than a short break within the same dashed vocabulary, and removed the chunk count's duplicate appearance in the mood chip.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-08-08
- **Tasks:** 3/3 completed
- **Files modified:** 8

## Accomplishments

- **G-04 fixed:** `TimelineRowTile` now wraps its `Row` in `Padding(EdgeInsets.symmetric(horizontal: 16))`; the four children that previously carried their own 16dp horizontal inset (`FreeTimeRow`, `LiveRowCard`, `ChunkCard._buildBreak`'s `Container`, `_WorkChunkContent`'s `Card`) now carry vertical-only margin/padding. Verified via grep that each of `TimelineRowTile`, `FreeTimeRow`, `LiveRowCard`, and `SwipeableChunkCard`/`ChunkCard` has exactly one production call site (all inside `today_screen.dart`, with `ChunkCard` itself called only from `swipeable_chunk_card.dart`) before relocating. A new alignment test pins the gutter label's `dx` equal to the "Today" heading's `dx`.
- **kGutterWidth widened 46.0 → 75.0**, forced by a new widest-label fit test ("12:45p", `formatMinutesCompact`'s 6-character worst case). See Decisions for why the bump is larger than the gap analysis's "a few dp" guess — it's a `flutter test`-harness artifact (no real font metrics loaded), documented in the constant's own doc comment.
- **G-02 fixed:** `_buildBreak` derives `isLong` from `ChunkType.longBreak` and scales four properties: vertical padding (12→24), title style (`bodyMedium` → `titleMedium`/`w500`), a leading `Icons.self_improvement` (20dp, `onSurfaceVariant`, long-only), and dash stroke width (1→1.5, via a new optional `strokeWidth` field on `_DashedBorderPainter`). Measured: short-break `ChunkCard` height 52.0dp, long-break 80.0dp (+28dp, well over the required +16dp bar). No `onTap`/`GestureDetector`/`ExpansionTile` added — verified by grep and a new dedicated test.
- **G-06 fixed:** `_buildHeader`'s mood chip dropped its `· $workChunkCount $chunkWord` suffix (now `'$moodEmoji $moodLabel'`); the now-unused locals were removed. `ScheduleProgressBar` (already shown above the header) remains the single source of the count. `22-UI-SPEC.md`'s "Structure" example was amended with a dated note (`**Amended 2026-08-08 (UAT G-06)**`) rather than left contradicting the shipped chip.
- Full suite: 479 tests green (474 pre-plan baseline + 5 new tests across the three tasks), `flutter analyze` clean throughout.

## Task Commits

Each task was committed atomically:

1. **Task 1: Align the time gutter with the header without moving a single card (G-04)** - `891a36b` (fix)
2. **Task 2: Make a long break read long (G-02)** - `2ba0d70` (feat)
3. **Task 3: One chunk count, in one place — and amend the Phase 22 spec to match (G-06)** - `ae23577` (docs)

**Plan metadata:** commit pending (this SUMMARY + STATE/ROADMAP update)

_No TDD tasks — this is a `type: execute` plan, not `type: tdd`._

## Files Created/Modified

- `lib/screens/today/widgets/timeline_row_tile.dart` — owns the row's 16dp horizontal inset; `kGutterWidth` 46.0 → 75.0 with rationale in the doc comment
- `lib/screens/today/widgets/free_time_row.dart` — padding drops its own `horizontal: 16` (vertical-only now)
- `lib/screens/today/widgets/live_row_card.dart` — `Card` margin drops its own `horizontal: 16`
- `lib/screens/schedule/widgets/chunk_card.dart` — break Container/Card margins drop `horizontal: 16`; `_buildBreak` scales weight for long breaks; `_DashedBorderPainter` gains `strokeWidth`
- `lib/screens/today/today_screen.dart` — mood chip drops the duplicated chunk-count suffix
- `test/screens/today_row_widgets_test.dart` — widest-label fit test, updated `kGutterWidth` pin, long-break height/icon test, renamed "same dashed treatment" test, no-new-interaction guard test
- `test/screens/today_screen_test.dart` — gutter/heading alignment test (G-04), count-appears-once test (G-06)
- `.planning/phases/22-unified-today-screen/22-UI-SPEC.md` — mood-chip example amended, dated G-06 amendment note added

## Decisions Made

See `key-decisions` in frontmatter — summarized: `kGutterWidth` was bumped to 75.0 (not a small "few dp" correction) because `flutter test`'s placeholder font inflates measured text width; this is documented as a test-harness caveat rather than a real-device requirement, with a note to recheck in a real browser per this project's CLAUDE.md guidance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug in test methodology] kGutterWidth fit test required a larger-than-expected bump due to a flutter-test-only font substitution artifact**
- **Found during:** Task 1 (widest-label fit test)
- **Issue:** The plan's TextPainter-based fit test, run exactly as specified, measured "12:45p" at 74.4px against a 46.0dp `kGutterWidth` — a far larger overflow than the gap analysis's "probably not the dominant cause... bump a few dp" expectation. Probed with an isolated test: single characters ('1', 'i', 'W', ':', 'p') all measured exactly 12.0px (== fontSize) under `flutter test`, confirming the harness has no real Roboto metrics loaded and substitutes a fixed-width glyph box per character — not representative of real-device rendering.
- **Fix:** Bumped `kGutterWidth` to 75.0 (smallest whole number that satisfies the harness's own measurement), updated the pinned `expect(kGutterWidth, ...)` assertion in lockstep, and documented the test-harness caveat prominently in both the constant's doc comment and the test's own comment, so a future reader doesn't misread 75.0 as a real-device requirement.
- **Files modified:** `lib/screens/today/widgets/timeline_row_tile.dart`, `test/screens/today_row_widgets_test.dart`
- **Verification:** Full suite green, `flutter analyze` clean; alignment test (which doesn't depend on `kGutterWidth`'s absolute value) still passes.
- **Committed in:** `891a36b` (Task 1 commit)

**2. [Rule 1 - Bug] UI-SPEC amendment text accidentally repeated the exact string it was removing**
- **Found during:** Task 3 (amending 22-UI-SPEC.md)
- **Issue:** The first draft of the amendment note quoted "Steady day · 9 chunks" verbatim to describe what was being changed, which caused the acceptance criterion `grep -n "9 chunks" 22-UI-SPEC.md` (asserting the string is gone) to still find a hit — in the amendment note itself.
- **Fix:** Reworded the amendment note to describe the change ("a '· N chunks' suffix with the day's work-chunk total") without literally containing "9 chunks".
- **Files modified:** `.planning/phases/22-unified-today-screen/22-UI-SPEC.md`
- **Verification:** `grep -n "9 chunks" 22-UI-SPEC.md` returns no hit; `grep -n "G-06" 22-UI-SPEC.md` returns one hit.
- **Committed in:** `ae23577` (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — test/doc correctness issues surfaced while satisfying the plan's own acceptance criteria)
**Impact on plan:** No scope creep; both fixes were required to make the plan's own stated acceptance criteria pass truthfully.

## Issues Encountered

None beyond the two deviations above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- G-02, G-04, G-06 are closed. Remaining open UAT gaps from `23-UAT.md` (G-01, G-03, G-05, G-07) are tracked separately — G-01/G-07 were closed by plan 23-08 (per its SUMMARY); G-03/G-05 status should be confirmed against `23-04-PLAN.md`'s incomplete state before considering Phase 23 fully closed.
- Worth a real-browser visual check of the widened (75dp) time gutter — the bump was forced by a `flutter test` font-metrics limitation, not a real-device measurement; it may read as roomier than necessary once seen live.

---
*Phase: 23-live-activity-tracking*
*Completed: 2026-08-08*

## Self-Check: PASSED

All 8 modified files and this SUMMARY.md confirmed present on disk; all 3 task commits (`891a36b`, `2ba0d70`, `ae23577`) confirmed in `git log`.
