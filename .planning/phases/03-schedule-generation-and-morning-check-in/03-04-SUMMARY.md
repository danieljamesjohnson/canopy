---
phase: 03-schedule-generation-and-morning-check-in
plan: "04"
subsystem: ui
tags: [flutter, provider, go_router, schedule, chunk_card, progress_bar]

# Dependency graph
requires:
  - phase: 03-02
    provides: ScheduleNotifier with hasScheduleToday, todaySchedule, moodIndex
  - phase: 02-03
    provides: GoalsNotifier and goal color model; hexToColor pattern from GoalCard
provides:
  - ChunkCard widget: work/shortBreak/longBreak variants with left color bar
  - ScheduleProgressBar widget: 'X of Y Chunks' + mood-tinted LinearProgressIndicator
  - ScheduleScreen: empty state + populated chunk list with mood-tinted AppBar
  - HomeScreen: today summary (mood emoji, progress, next chunk) or empty state
affects:
  - phase 03-05
  - phase 04 (completion logging will mark chunks as isCompleted)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Stack + Positioned left-bar pattern (from GoalCard, replicated in ChunkCard)
    - hexToColor() helper co-located in chunk_card.dart, imported by schedule_screen.dart
    - Mood color map used in both ScheduleScreen and HomeScreen for consistent tinting

key-files:
  created:
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/schedule/widgets/schedule_progress_bar.dart
  modified:
    - lib/screens/schedule/schedule_screen.dart
    - lib/screens/home/home_screen.dart

key-decisions:
  - "hexToColor() copied into chunk_card.dart (not imported from goal_card.dart) to keep widget self-contained; schedule_screen.dart imports it from chunk_card.dart"
  - "Unused scheduled_chunk.dart import removed from schedule_screen.dart (ChunkType used only inside chunk_card.dart)"
  - "HomeScreen AppBar title is 'Canopy' (not 'Home') to match branding intent"

patterns-established:
  - "ChunkCard: three-variant switch on chunkType; work variant uses Stack+Positioned left bar at width 5"
  - "Mood color map declared as static const in each screen — copy is acceptable for two screens"
  - "context.read<GoalsNotifier>() inside ListView.builder for goal color lookup (read, not watch, to avoid rebuild cascade)"

requirements-completed: [SCHED-01, SCHED-02]

# Metrics
duration: 2min
completed: 2026-03-23
---

# Phase 3 Plan 04: Schedule Display Screens Summary

**ScheduleScreen and HomeScreen wired to ScheduleNotifier with ChunkCard (work/break variants + left color bar) and ScheduleProgressBar (mood-tinted progress) widgets**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-23T18:37:22Z
- **Completed:** 2026-03-23T18:39:31Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- ChunkCard renders three visual variants: work (Stack left bar, status icon, rationale, optional time label), shortBreak (compact 48dp row with pause icon), longBreak (full-height card with coffee emoji)
- ScheduleProgressBar computes work chunk completion ratio and displays 'X of Y Chunks' + mood-colored LinearProgressIndicator
- ScheduleScreen shows empty state with 'Start your day' → /schedule/checkin, or populated list with mood-tinted AppBar + ScheduleProgressBar + ChunkCard list
- HomeScreen shows today's progress bar, mood emoji + description, and next upcoming work chunk name/duration, or empty state with OutlinedButton to start check-in

## Task Commits

Each task was committed atomically:

1. **Task 1: ChunkCard widget and ScheduleProgressBar widget** - `eb15cb7` (feat)
2. **Task 2: ScheduleScreen and HomeScreen implementations** - `d89a3bf` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `lib/screens/schedule/widgets/chunk_card.dart` - ChunkCard StatelessWidget with work/shortBreak/longBreak variants; includes hexToColor() and _formatMinutes() helpers
- `lib/screens/schedule/widgets/schedule_progress_bar.dart` - ScheduleProgressBar with completed/total work chunk count and mood-tinted LinearProgressIndicator
- `lib/screens/schedule/schedule_screen.dart` - Replaced stub; reads ScheduleNotifier; empty state or full chunk list with mood-accented AppBar
- `lib/screens/home/home_screen.dart` - Replaced stub; reads ScheduleNotifier; summary or empty state

## Decisions Made
- `hexToColor()` copied into `chunk_card.dart` rather than imported from `goal_card.dart` to keep the schedule widgets self-contained. `schedule_screen.dart` imports it from `chunk_card.dart`.
- Removed unused `scheduled_chunk.dart` import from `schedule_screen.dart` (Rule 1 auto-fix: analyzer warning). `ChunkType` is only referenced inside `chunk_card.dart`.
- `HomeScreen` AppBar title is "Canopy" per plan discretion note.
- `context.read<GoalsNotifier>()` (not `watch`) used inside `ListView.builder` for goal color lookup to avoid unnecessary rebuilds.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused import in schedule_screen.dart**
- **Found during:** Task 2 verification (`flutter analyze`)
- **Issue:** `scheduled_chunk.dart` was imported but `ChunkType` is used only inside `chunk_card.dart`, making the import redundant
- **Fix:** Removed the import line
- **Files modified:** `lib/screens/schedule/schedule_screen.dart`
- **Verification:** `flutter analyze` clean after removal
- **Committed in:** `d89a3bf` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — unused import)
**Impact on plan:** Minimal; only import cleanup. No scope creep.

## Issues Encountered
None beyond the unused import auto-fix above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ScheduleScreen and HomeScreen are fully implemented and display schedule data from ScheduleNotifier
- ChunkCard `isCompleted` field is rendered (done state) but no interaction to mark complete yet — Phase 4 will wire completion logging
- All Phase 3 display screens are complete; remaining work is route wiring / E2E testing if planned
- `flutter analyze` clean; schedule_generator_test.dart all 10 passing

---
*Phase: 03-schedule-generation-and-morning-check-in*
*Completed: 2026-03-23*

## Self-Check: PASSED

- lib/screens/schedule/widgets/chunk_card.dart — FOUND
- lib/screens/schedule/widgets/schedule_progress_bar.dart — FOUND
- lib/screens/schedule/schedule_screen.dart — FOUND
- lib/screens/home/home_screen.dart — FOUND
- .planning/phases/03-schedule-generation-and-morning-check-in/03-04-SUMMARY.md — FOUND
- Commit eb15cb7 (Task 1) — FOUND
- Commit d89a3bf (Task 2) — FOUND
- Commit 027941f (docs) — FOUND
