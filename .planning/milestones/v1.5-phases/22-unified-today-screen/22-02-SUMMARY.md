---
phase: 22-unified-today-screen
plan: 02
subsystem: ui
tags: [flutter, widgets, tdd, colorscheme]

# Dependency graph
requires:
  - phase: 22-unified-today-screen
    plan: 01
    provides: lib/screens/today/now_state.dart, lib/screens/today/timeline.dart (import-only relationship; this plan's widgets take no now_state dependency)
provides:
  - "lib/screens/today/widgets/timeline_row_tile.dart — 46dp tabular-figure time gutter (TimelineRowTile, kGutterWidth)"
  - "lib/screens/today/widgets/free_time_row.dart — FreeTimeRow.until / FreeTimeRow.gap, locked copy, dotted rule, no Card"
  - "lib/screens/today/widgets/live_row_card.dart — LiveRowCard, the swelled in-place current-activity card, Phase 23 injection seam"
  - "lib/screens/schedule/widgets/chunk_card.dart — extended row vocabulary: showStartTime, strikethrough, 'skipped' label, dashed breaks, tertiaryContainer commitments, zero raw Colors.*"
  - "lib/screens/schedule/widgets/swipeable_chunk_card.dart — showStartTime pass-through"
affects: [22-03, 22-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Hand-rolled CustomPainter for dashed/dotted rules instead of a package dependency (_DashedBorderPainter, _DottedRulePainter) — no_new_packages constraint"
    - "Screen-injected display strings (kicker/remainingLabel) as the Phase 23 seam — LiveRowCard never reads the clock itself"
    - "showStartTime bool flag threaded through a widget + its private content class + its swipeable wrapper, defaulting true, to let one widget serve both the plain list (schedule_screen.dart) and the gutter-driven Today screen without duplicating layout"

key-files:
  created:
    - lib/screens/today/widgets/timeline_row_tile.dart
    - lib/screens/today/widgets/free_time_row.dart
    - lib/screens/today/widgets/live_row_card.dart
    - test/utils/time_format_test.dart
  modified:
    - lib/utils/time_format.dart
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart
    - test/screens/today_row_widgets_test.dart

key-decisions:
  - "_buildShortBreak/_buildLongBreak collapsed into a single _buildBreak on one _DashedBorderPainter — the Phase 21 UI review's 'pill vs elevated-Card' mismatch (short break 48px pill immediately followed by an elevated long-break Card) is resolved by giving both variants the same dashed, transparent, non-Card treatment. No collapse/accordion affordance added, per the explicit prohibition in the execution note."
  - "Added an outlineVariant BorderSide to the upcoming-work-chunk Card that the pre-existing code did not have, to satisfy the UI-SPEC's 'surfaceContainer card, outlined' row-type description — this was implicit in the plan's action text ('otherwise pass color surfaceContainer and a BorderSide coloured outlineVariant'), not a spontaneous addition."

requirements-completed: [UNIFY-01]

# Metrics
duration: 8min
completed: 2026-08-07
---

# Phase 22 Plan 02: Timeline Row Vocabulary Summary

**Built the row vocabulary the unified Today screen renders — a 46dp tabular-figure time gutter, a named free-time row, an extended chunk_card with strikethrough/skipped/dashed-break/tertiaryContainer treatments and zero hardcoded Colors, and LiveRowCard (the swelled in-place current-activity card) — as pure widgets that take no dependency on the clock or on which row is live.**

## Performance

- **Duration:** ~8 min (first commit 14:48:04 → last commit 14:52:19, plus context-loading time)
- **Completed:** 2026-08-07
- **Tasks:** 3 completed (all TDD: RED commit then GREEN commit per task)
- **Files modified:** 8 (4 created, 4 modified)

## Accomplishments

- `formatDurationShort` and `formatMinutesCompact` appended to `time_format.dart`, both matching every case in the plan's behavior table (5m/45m/1h/1h 40m/2h/3h 15m/0m; 8:00/10:45/1:00p/12:00p/12:00/10:30p) — `formatMinutes` left byte-identical so existing call sites are untouched.
- `TimelineRowTile` reserves a fixed 46dp gutter (`kGutterWidth`) with tabular-figure text and a monospace fallback chain, doc-commented to explicitly reject D-04's rejected vertical-rail variant (no connector line, no dot, no stroke).
- `FreeTimeRow` renders the two D-05-locked copy strings ("Free until 8:00 AM", "Free · 1h 40m") behind a hand-rolled dotted-rule `CustomPainter`, with no `Card` in either form — two named constructors (`.until` / `.gap`) so a call site can't mix the leading-gap and mid-day-gap forms.
- `chunk_card.dart` now carries the full D-06 row vocabulary: completed titles strike through with a `colorScheme.primary` check icon, skipped titles strike through with a literal "skipped" label, unresolved chunks are unchanged (SCHED-03 action row intact), `showStartTime` (threaded through `_WorkChunkContent` and `SwipeableChunkCard`) lets the gutter own the clock-time display without the card duplicating it, breaks render on a single dashed `_buildBreak` (both short and long, replacing the old pill-vs-elevated-Card pair), and commitment work chunks render `tertiaryContainer` with no outline and no left goal-color bar. The standing tech-debt item (`Colors.green.shade600` / `Colors.grey.shade400`) is fully closed — a grep gate confirms zero raw `Colors.*` literals remain in the file.
- `LiveRowCard` renders all six UI-SPEC live-row elements (kicker, title, remaining-time, progress bar, Complete/Skip actions, Next line) from screen-injected strings, wires Complete/Skip to `ScheduleNotifier` by `chunkId`, clamps progress to 0..1 before it reaches `LinearProgressIndicator`, and hides actions entirely when `showActions` is false. `active_chunk_card.dart` is untouched — still live in `HomeScreen` this wave, scheduled for deletion in plan 22-04.
- Full suite: 404 tests green (362 baseline + 42 new: 13 unit + 29 widget), `flutter analyze` clean throughout.

## Task Commits

Each task followed RED → GREEN:

1. **Task 1: Time gutter + named free time (D-04, D-05, D-06)**
   - RED: `63fe7f3` (test) — formatDurationShort/formatMinutesCompact + TimelineRowTile/FreeTimeRow cases, confirmed compile failure
   - GREEN: `d2a0fe8` (feat) — implementation, all cases pass
2. **Task 2: chunk_card row vocabulary + swipe pass-through + ColorScheme debt (D-06, D-07, P10)**
   - RED: `ef45fbd` (test) — ChunkCard row-vocabulary group, confirmed compile failure (`showStartTime` param didn't exist)
   - GREEN: `a97e6f0` (feat) — implementation, all 5 pre-existing chunk_card test files pass unchanged
3. **Task 3: LiveRowCard — the swelled in-place current activity (D-01, Phase 23 seam)**
   - RED: `9c7c647` (test) — LiveRowCard group, confirmed compile failure (class didn't exist)
   - GREEN: `c28e1c1` (feat) — implementation, all cases pass

## Files Created/Modified

- `lib/utils/time_format.dart` — added `formatDurationShort`, `formatMinutesCompact`
- `lib/screens/today/widgets/timeline_row_tile.dart` — new: `TimelineRowTile`, `kGutterWidth`
- `lib/screens/today/widgets/free_time_row.dart` — new: `FreeTimeRow` (`.until`/`.gap`), `_DottedRulePainter`
- `lib/screens/today/widgets/live_row_card.dart` — new: `LiveRowCard`
- `lib/screens/schedule/widgets/chunk_card.dart` — `showStartTime` flag, strikethrough/skipped label, `_buildBreak`/`_DashedBorderPainter` replacing `_buildShortBreak`/`_buildLongBreak`, `tertiaryContainer` commitment treatment, outlined upcoming-work-chunk card, zero raw `Colors.*`
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — `showStartTime` pass-through, including the break-card early-return path
- `test/utils/time_format_test.dart` — new unit suite for the two formatters
- `test/screens/today_row_widgets_test.dart` — new widget suite: TimelineRowTile, FreeTimeRow, ChunkCard row vocabulary, LiveRowCard groups

## Decisions Made

- Collapsed `_buildShortBreak`/`_buildLongBreak` into one `_buildBreak` on a single `_DashedBorderPainter`, which both resolves D-06's dashed/lighter break requirement and closes the Phase 21 UI review's flagged pill-vs-elevated-Card visual mismatch — without introducing the explicitly-prohibited collapse/accordion affordance.
- Added an `outlineVariant` `BorderSide` to the upcoming (unresolved, non-commitment) work-chunk `Card`, which the pre-existing card did not draw. This follows the plan's action text literally ("otherwise pass color surfaceContainer and a BorderSide coloured outlineVariant") and the UI-SPEC's "outlined" row-type description — flagged here because it's a visible change beyond a pure color-token swap.
- `dart format` was run scoped to only the files this plan touched (per the execution note's warning about repo-wide formatter-version drift), not tree-wide.

## Deviations from Plan

None — plan executed as written. The two decisions above are direct implementations of explicit plan instructions, not deviations.

## Known Stubs

None. All widgets are wired to real inputs (chunk data, `ScheduleNotifier`) or take screen-injected strings by design (LiveRowCard's `kicker`/`remainingLabel`, explicitly the Phase 23 seam per the plan).

## Threat Flags

None. All threat-register items (T-22-04 through T-22-07, T-22-SC) are mitigated exactly as specified — no new surface introduced beyond what the threat model already covers.

## Issues Encountered

None. All three tasks passed their widget/unit tests on the first implementation attempt after RED.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `TimelineRowTile`, `FreeTimeRow`, and `LiveRowCard` are ready for plan 22-03 to assemble into the unified Today screen's scrollable list.
- `chunk_card.dart`'s `showStartTime` flag is ready for 22-03 to pass `false` when wrapping a row in the gutter, and `true` (default) preserves `schedule_screen.dart`'s existing plain-list rendering unchanged.
- `active_chunk_card.dart` remains live and untouched; its deletion is plan 22-04's job once `HomeScreen` no longer references it.
- No blockers. The Phase 23 seam (LiveRowCard's injected `kicker`/`remainingLabel`) is in place and documented so LIVE-01/02/03 can land by changing what the screen passes in, not by rewriting the widget.

---
*Phase: 22-unified-today-screen*
*Completed: 2026-08-07*

## Self-Check: PASSED

All created files and commit hashes verified present on disk / in git log.
