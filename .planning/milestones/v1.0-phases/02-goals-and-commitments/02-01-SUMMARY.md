---
phase: 02-goals-and-commitments
plan: 01
subsystem: database
tags: [hive_ce, dart, model, migration, build_runner, TypeAdapter]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: "Goal HiveObject entity with fields 0-3; migrations runner at schemaVersion 1"
provides:
  - "Expanded Goal entity with @HiveField 4-11 (color, priorityWeight, sortOrder, weeklyHourBudget, deadline, outcomeDescription, frequencyPerWeek, streakCount)"
  - "Regenerated GoalAdapter TypeAdapter covering 12 field slots (0-11)"
  - "Migration runner at schemaVersion 2 with no-op _migration1to2"
affects: [02-02, 02-03, notifiers, UI]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "HiveField indices are append-only — never reuse or renumber"
    - "Nullable fields degrade gracefully for existing Hive records on adapter upgrade"
    - "No-op migration function is required whenever schema version is bumped, even with additive-only changes"

key-files:
  created: []
  modified:
    - lib/data/models/goal.dart
    - lib/data/models/goal.g.dart
    - lib/data/database/migrations.dart

key-decisions:
  - "New Goal fields typed as nullable (String?, double?, DateTime?, int?) so existing Hive records return null for missing fields without corruption"
  - "sortOrder and streakCount typed as non-nullable int with =0 default; Hive returns 0 for missing int fields — safe for backward compat"
  - "No-op _migration1to2 added to _migrations list so migration runner increments schemaVersion atomically"

patterns-established:
  - "GoalType enum ORDER IS FIXED — values stored as int index; enum values must never be reordered"
  - "Phase-specific optional fields (weeklyHourBudget, deadline, etc.) stored as nullable on shared Goal entity — null means 'not applicable to this GoalType'"

requirements-completed: [goal-types]

# Metrics
duration: 2min
completed: 2026-02-26
---

# Phase 02 Plan 01: Goal Model Expansion Summary

**Hive Goal entity expanded from 4 to 12 fields (@HiveField 0-11) with regenerated TypeAdapter and schema version bumped to 2 via no-op migration**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-26T12:54:10Z
- **Completed:** 2026-02-26T12:56:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added 8 new @HiveField annotations (4-11) to Goal class covering color, priorityWeight, sortOrder, weeklyHourBudget, deadline, outcomeDescription, frequencyPerWeek, and streakCount
- Updated Goal constructor to accept all new fields as optional named parameters with appropriate defaults
- Regenerated GoalAdapter via build_runner; adapter now serializes all 12 field slots with writeByte(12)
- Bumped currentSchemaVersion to 2 with _migration1to2 (no-op) appended to _migrations list
- flutter analyze zero issues; all 6 existing tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Expand Goal model with Phase 2 fields and bump schema version** - `44917a6` (feat)
2. **Task 2: Regenerate GoalAdapter TypeAdapter covering fields 0-11** - `5b4abee` (feat)

## Files Created/Modified

- `lib/data/models/goal.dart` - Added @HiveField 4-11 with type-appropriate nullability and constructor params
- `lib/data/models/goal.g.dart` - Regenerated GoalAdapter covering fields 0-11 (writeByte 12)
- `lib/data/database/migrations.dart` - currentSchemaVersion = 2; _migration1to2 no-op added

## Decisions Made

- Nullable fields (color, priorityWeight, weeklyHourBudget, deadline, outcomeDescription, frequencyPerWeek) degrade gracefully for existing records — Hive binary reader returns null for missing nullable slots
- Non-nullable int fields (sortOrder=0, streakCount=0) use field declaration defaults; Hive returns 0 for missing int slots, matching the defaults
- No-op migration is the correct approach for additive-only Hive schema changes since the adapter handles the null/default case automatically

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Goal entity is fully ready for Phase 2 notifiers and UI
- GoalsNotifier can safely read color, priorityWeight, sortOrder from existing Goal records (returns null/0 defaults)
- Type-specific fields (weeklyHourBudget, deadline, frequencyPerWeek) accessible for commitment UI per GoalType

---
*Phase: 02-goals-and-commitments*
*Completed: 2026-02-26*

## Self-Check: PASSED

- FOUND: lib/data/models/goal.dart
- FOUND: lib/data/models/goal.g.dart
- FOUND: lib/data/database/migrations.dart
- FOUND: .planning/phases/02-goals-and-commitments/02-01-SUMMARY.md
- Commit 44917a6 verified
- Commit 5b4abee verified
