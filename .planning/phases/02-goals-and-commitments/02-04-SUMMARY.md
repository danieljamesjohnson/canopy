---
phase: 02-goals-and-commitments
plan: 04
subsystem: ui
tags: [flutter, commitments, provider, go_router, hive, material3]

# Dependency graph
requires:
  - phase: 02-goals-and-commitments/02-02
    provides: CommitmentsNotifier with loadBlocks/saveBlock/deleteBlock and CommitmentBlock model

provides:
  - CommitmentsScreen at /commitments with ListView, FAB, delete confirm, empty state
  - CommitmentFormSheet with DraggableScrollableSheet, FilterChip day selection (ISO 1-7), showTimePicker
  - /commitments GoRoute outside StatefulShellRoute (no bottom nav)
  - Goals screen overflow menu item linking to /commitments

affects: [03-schedule-generation, phase-3-planning]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - CommitmentsScreen follows same StatefulWidget + ChangeNotifier Consumer pattern as GoalsScreen
    - DraggableScrollableSheet scrollController passed into sheet widget (same pattern as GoalFormSheet)
    - Hard delete with confirm dialog vs archive-only for goals (established in 02-02)

key-files:
  created:
    - lib/screens/commitments/commitments_screen.dart
    - lib/screens/commitments/commitment_form_sheet.dart
  modified:
    - lib/router.dart
    - lib/screens/goals/goals_screen.dart

key-decisions:
  - "CommitmentsScreen placed outside StatefulShellRoute so no bottom nav bar shown — settings-style focused experience"
  - "Goals overflow menu uses context.push('/commitments') (not go) so back navigation returns to Goals"
  - "_formatDays handles three cases: Daily (7 days), Mon-Fri (exactly weekdays 1-5), comma-separated abbreviations"
  - "CommitmentFormSheet color defaults to #607D8B (blue-grey) per plan spec; CommitmentBlock.color field assigned post-construction"

patterns-established:
  - "Outside-shell routes: /onboarding, /review, /commitments all use top-level GoRoute outside StatefulShellRoute"
  - "Confirm-delete dialog pattern: showDialog returning bool, guarded by context.mounted check before async notifier call"
  - "Time formatting: minutes-from-midnight to 12-hour display string shared between screen and form sheet"

requirements-completed: [commitment-blocks]

# Metrics
duration: 4min
completed: 2026-02-26
---

# Phase 2 Plan 04: CommitmentsScreen and CommitmentFormSheet Summary

**CommitmentsScreen and CommitmentFormSheet with ISO day-chip selection, showTimePicker, hard delete, and /commitments GoRoute accessible from Goals overflow menu**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-26T13:30:04Z
- **Completed:** 2026-02-26T13:34:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- CommitmentsScreen shows all commitment blocks as cards with color swatch, name, and formatted days + time range (e.g. "9am-5pm · Mon-Fri")
- CommitmentFormSheet uses DraggableScrollableSheet scrollController, FilterChip day selection using ISO weekday ints 1-7, showTimePicker
- /commitments GoRoute wired outside StatefulShellRoute; Goals overflow menu navigates via context.push for correct back navigation

## Task Commits

1. **Task 1: Build CommitmentsScreen and CommitmentFormSheet** - `26b006f` (feat)
2. **Task 2: Wire /commitments route and add link from Goals screen** - `ae70b2a` (feat)

## Files Created/Modified

- `lib/screens/commitments/commitments_screen.dart` - Commitment blocks list with FAB, delete confirm dialog, empty state, format helpers
- `lib/screens/commitments/commitment_form_sheet.dart` - Add/Edit sheet with FilterChip days, showTimePicker, name field, save button guard
- `lib/router.dart` - Added /commitments GoRoute outside shell, imported CommitmentsScreen
- `lib/screens/goals/goals_screen.dart` - PopupMenuButton extended with "Commitment blocks" item using context.push

## Decisions Made

- CommitmentsScreen placed outside StatefulShellRoute so no bottom nav bar is shown (settings-style focused experience)
- Goals overflow menu uses context.push('/commitments') so back navigation returns to Goals correctly
- _formatDays handles three cases: Daily (all 7), Mon-Fri (exactly days 1-5), or comma-separated abbreviations
- CommitmentBlock.color field assigned post-construction since it has a default value with no constructor parameter

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Commitment blocks CRUD is fully operational with persistence via CommitmentsNotifier + HiveCommitmentBlockRepository
- Phase 3 schedule generation can read CommitmentsNotifier.blocks to find fixed time obligations
- All Phase 2 goals-and-commitments screens are complete

---
*Phase: 02-goals-and-commitments*
*Completed: 2026-02-26*
