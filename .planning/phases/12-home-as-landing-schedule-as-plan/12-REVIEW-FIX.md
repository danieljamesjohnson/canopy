---
phase: 12-home-as-landing-schedule-as-plan
fixed_at: 2026-06-12T14:47:24Z
review_path: .planning/phases/12-home-as-landing-schedule-as-plan/12-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 12: Code Review Fix Report

**Fixed at:** 2026-06-12T14:47:24Z
**Source review:** .planning/phases/12-home-as-landing-schedule-as-plan/12-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: NowMarker placement algorithm — untimed chunks used 9999 sentinel

**Files modified:** `lib/screens/schedule/schedule_screen.dart`
**Commit:** e5a9e6c
**Applied fix:** Restructured the NowMarker scan loop in `_buildActiveChunkItems`. The old
algorithm used `(c.displayStartMinutes ?? 9999) >= nowMinutes` which caused the very first
untimed chunk to satisfy the condition and anchor the marker there regardless of wall time.
The new loop explicitly checks whether `start == null || start < nowMinutes` and advances
`nowMarkerIndex` through past/untimed chunks, only breaking on the first future-anchored
chunk. The SCHED-02 invariant (no marker when all chunks are resolved) is preserved because
`nowMarkerIndex` stays null when no unresolved work chunks are found. Also collapsed the two
`DateTime.now()` calls to one to eliminate the minute-boundary jitter.

---

### WR-02: `BreathingPulseCta.onPressed` was a required but never-invoked field

**Files modified:** `lib/screens/home/home_screen.dart`
**Commit:** ec5fc09
**Applied fix:** Changed `required this.onPressed` to `this.onPressed` (optional, typed
`VoidCallback?`) and updated the field docstring accordingly. Wrapped the animated
`Container` in a `GestureDetector(onTap: widget.onPressed, ...)` inside the
`AnimatedBuilder` builder so the callback is actually fired when the glow ring is tapped.
The existing call site already passes the same callback to the inner `OutlinedButton`, so
both tap targets now work. No callers required changes — the field was already passed at the
only call site.

---

### WR-03: `didChangeDependencies` reset `_eodCardDismissed` without `setState`

**Files modified:** `lib/screens/home/home_screen.dart`
**Commit:** c419652
**Applied fix:** Wrapped both `_lastScheduleDateYmd = newDateYmd` and
`_eodCardDismissed = false` inside a `setState(() { ... })` call in
`_HomeScreenState.didChangeDependencies`. Previously the bare assignments updated memory
but did not mark the widget dirty, meaning the `EndOfDayCard` would not reappear after a
date transition until some unrelated `setState` happened to trigger a rebuild.

---

### WR-04: `hexToColor`, `_formatMinutes`, `_formatTimeRange` duplicated across 3+ files

**Files modified:** `lib/screens/schedule/widgets/chunk_card.dart`,
`lib/screens/goals/widgets/goal_card.dart`,
`lib/screens/schedule/schedule_screen.dart`,
`lib/screens/end_of_day/end_of_day_summary_screen.dart`,
`lib/screens/focus/focus_screen.dart`,
`lib/screens/quarterly_review/widgets/donut_chart.dart`,
`lib/screens/quarterly_review/sections/adjustments_section.dart`,
`lib/screens/quarterly_review/sections/data_section.dart`
**Commit:** 8a2f60e
**Applied fix:** Removed the duplicate top-level `hexToColor` function from both
`chunk_card.dart` (lines 6-23, which also included `_formatMinutes` and `_formatTimeRange`)
and `goal_card.dart` (lines 4-7). Added `import '../../../utils/time_format.dart'` to both.
Updated the single `_formatTimeRange(...)` call in `chunk_card.dart`'s `_WorkChunkContent`
to use the public `formatTimeRange(...)` name from `time_format.dart`.

For the five downstream files that imported `chunk_card.dart` solely to access `hexToColor`
(`end_of_day_summary_screen.dart`, `focus_screen.dart`, `donut_chart.dart`,
`adjustments_section.dart`, `data_section.dart`), replaced their `chunk_card.dart` import
with a direct import of `time_format.dart`. Added `time_format.dart` to
`schedule_screen.dart` as an explicit import since it uses `hexToColor` directly.

All 185 tests pass. `flutter analyze` reports no issues in any touched file (2 pre-existing
info warnings in test files are unrelated to these changes).

---

_Fixed: 2026-06-12T14:47:24Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

---

## UI Audit Fixes

**Applied at:** 2026-06-12
**Source review:** `.planning/phases/12-home-as-landing-schedule-as-plan/12-UI-REVIEW.md`

Three WARNING findings from the Phase 12 UI audit addressed in a follow-up polish commit.

### UI-WR-01: Next chunk compact row now shows clock-time range

**File modified:** `lib/screens/home/home_screen.dart`
**Applied fix:** The trailing cell in the "Next" compact row previously showed only
`'${nextChunk.durationMinutes} min'`. It now conditionally calls
`formatTimeRange(nextChunk.displayStartMinutes!, nextChunk.displayStartMinutes! + nextChunk.durationMinutes)`
when `displayStartMinutes != null`, falling back to the duration string when null.
Added `import '../../utils/time_format.dart'` to `home_screen.dart` (the function was
already available in `active_chunk_card.dart` via the same import). Trailing text style
updated from `bodyMedium` to `bodySmall` (matches the `onSurfaceVariant` secondary-text
role used in `active_chunk_card.dart` for the same clock-time string).

### UI-WR-02: Typography theme roles on "All done today!" and Next chunk title

**File modified:** `lib/screens/home/home_screen.dart`
**Applied fix:** Replaced `const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)`
on the "All done today!" `Text` with `Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)`.
Replaced `const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)` (w700) on the Next
chunk title with `Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)`,
bringing the weight from w700 to w600 per the UI-SPEC §Typography ("Chunk goal name: titleMedium at w600").
Both text widgets now use the Material 3 TextTheme role and will automatically respond to
theme changes and accessibility text-scaling.

### UI-WR-03: Schedule empty-state heading promoted from titleMedium to titleLarge

**File modified:** `lib/screens/schedule/schedule_screen.dart`
**Applied fix:** Changed the style on the "Plan your day in 30 seconds." heading in
`_buildEmptyState` from `Theme.of(context).textTheme.titleMedium` to
`Theme.of(context).textTheme.titleLarge` (22sp w400), matching the UI-SPEC §Typography
("Empty state heading: titleLarge at w400").

**Verification:** `flutter analyze` — no issues on touched files. `flutter test` — 185/185 passed.
