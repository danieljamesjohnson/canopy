---
phase: 20-valence-aware-engine
plan: 02
subsystem: scheduling-engine
tags: [flutter, dart, schedule_generator, energy_valence, vsched, deterministic, tdd-green]

# Dependency graph
requires:
  - phase: 20-01
    provides: RED test suite (7 VSCHED+determinism tests), extended makeTimeTarget/makeOutcome helpers with EnergyValence valence param
  - phase: 19-energy-valence
    provides: EnergyValence enum, energyValenceIndex HiveField 12 on Goal model, goal.energyValence getter
provides:
  - GREEN implementation: all 7 VSCHED-01/02/03 + determinism tests pass
  - Restorative floor sub-pass (isLowMood, gives-valence time-targets only, restorativeFloor=1)
  - VSCHED-03 reservation pass (!isLowMood, gives-or-highpri, 1 slot before FILL-02)
  - VSCHED-01 outcome gate (gives-valence outcomes eligible on low days regardless of deadline)
affects: [schedule screen, schedule_notifier, future valence features]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pipeline sub-pass injection: insert guarded pass at exact position within generate() Step 4"
    - "Hoisted shared state map (placedCountPerGoal) before all passes that consume it"
    - "Gives-first sort with score-descending tiebreak (deterministic via stored int/double fields)"
    - "restorativeFloor=1 constant as VSCHED-02 bound knob"

key-files:
  created: []
  modified:
    - lib/services/schedule_generator.dart

key-decisions:
  - "Pipeline order: restorative floor (isLowMood) → PRIORITY-03 → VSCHED-03 (!isLowMood) → FILL-02 — prevents reservation from consuming PRIORITY-03's slot"
  - "placedCountPerGoal hoisted before restorative floor so all three passes share one anti-double-place map"
  - "restorativeFloor=1: single restorative chunk on low days is sufficient; day-level mood cap (4 vs 8) enforces low < medium automatically"
  - "VSCHED-03 guard is !isLowMood (mood 3-5, not mood 4-5) — consistent with all existing good-mood logic in the generator; mood-3 cost is one harmless extra reserved slot"
  - "VSCHED-03 reservation: gives-first sort by (0 if gives else 1, then score desc); break after first qualified goal placed"

# Metrics
duration: 3min
completed: 2026-06-15
---

# Phase 20 Plan 02: Valence Engine Summary

**4 surgical edits to `lib/services/schedule_generator.dart` implement all three VSCHED behaviors — energy_valence import, gives-valence outcome gate, hoisted placedCountPerGoal + restorative floor pass, VSCHED-03 reservation pass — turning all 7 RED VSCHED tests GREEN with zero regressions across 288 total tests**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-06-15T03:32:40Z
- **Completed:** 2026-06-15T03:35:35Z
- **Tasks:** 3
- **Files modified:** 1

## Accomplishments

### Task 1: VSCHED-01 — import + outcome-gate valence eligibility (Change A)
- Added `import 'package:canopy/data/models/energy_valence.dart';` to schedule_generator.dart (confirmed absent)
- Extended the Step 3 low-mood outcome include gate with `|| goal.energyValence == EnergyValence.gives` on both low-mood branches (lighterDay=ON and lighterDay=OFF), while leaving the `!isLowMood` branch (`include = true`) untouched
- `VSCHED-01-outcome` (the sole RED test from Phase 20-01) now GREEN: gives-valence outcome with `deadline: null` appears on a low/lighterDay day

### Task 2: VSCHED-01/02 — hoist placedCountPerGoal + restorative floor sub-pass
- Moved `final placedCountPerGoal = <String, int>{};` declaration out of PRIORITY-03 preamble to before all three passes (restorative floor, PRIORITY-03, VSCHED-03) so no goal is ever double-placed
- Inserted `if (isLowMood)` restorative floor pass (`const int restorativeFloor = 1; int restorativeCount = 0;`) before PRIORITY-03: loops timeTargetGoals, skips non-gives-valence goals, places at most 1 work chunk for first qualifying gives-valence goal with demand > 0, writes `placedCountPerGoal[goal.id] = 1` (critical anti-double-place)
- VSCHED-01 time-target, VSCHED-02 bound, and VSCHED-02-neutral-excluded tests all confirmed GREEN

### Task 3: VSCHED-03 — high-day reservation pass + full-suite regression gate
- Inserted `if (!isLowMood)` VSCHED-03 reservation pass after PRIORITY-03, before FILL-02: builds `reserveCandidates` from timeTargetGoals filtered to gives-valence or priorityWeight >= 0.75, sorts gives-first then score-descending, iterates and places exactly 1 chunk for the first qualifying goal with remaining demand, `break` after success
- `dart format` applied (whitespace-only reformatting, no logic change)
- Full `flutter test`: 288 tests all GREEN, zero regressions

## Task Commits

1. **Task 1: VSCHED-01 outcome gate** - `c3f1d49` (feat) — import + both low-mood outcome-gate branches
2. **Task 2: VSCHED-01/02 restorative floor** - `5686dda` (feat) — hoisted map + isLowMood restorative pass
3. **Task 3: VSCHED-03 reservation + format** - `237ec15` (feat) — !isLowMood reservation pass + dart format

## Files Created/Modified

- `lib/services/schedule_generator.dart` — 4 edits: import added, outcome gate modified (2 branches), placedCountPerGoal hoisted, restorative floor pass inserted, VSCHED-03 reservation pass inserted, dart format applied. Net: +81 lines

## Decisions Made

- Pipeline order (PRIORITY-03 before VSCHED-03) prevents the reservation from consuming the surplus slot PRIORITY-03 needs — this is Pitfall 3 from 20-RESEARCH.md; verified by existing PRIORITY-03 tests remaining GREEN
- `restorativeFloor = 1` is the VSCHED-02 bound; low-day cap (4) vs medium-day cap (8) guarantees `lowCount < medCount` even after adding 1 restorative chunk
- `!isLowMood` (not `moodIndex >= 4`) chosen for VSCHED-03 guard — consistent with all existing good-mood logic in the file (Research Open Question 1 resolved)
- VSCHED-03 sort is deterministic: uses stored int/double fields only (energyValence index via 0/1 mapping, priorityWeight, remainingHours via completionLogs); Dart List.sort is stable so goal.id provides the final deterministic tiebreak via the pre-existing timeTargetGoals sort order

## Deviations from Plan

None — plan executed exactly as written. All 4 edits applied as specified in the pipeline_order block and PATTERNS.md. `dart format` introduced minor whitespace reformatting (not a logic deviation).

## Issues Encountered

None.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes. This is a pure in-memory scheduling logic change within an existing synchronous Dart function. No threat flags.

## Known Stubs

None — all three VSCHED behaviors are fully wired. No placeholder values or hardcoded empty returns introduced.

## Self-Check

- [x] lib/services/schedule_generator.dart modified (commits c3f1d49, 5686dda, 237ec15)
- [x] All 7 VSCHED+determinism tests GREEN: `flutter test --name "VSCHED|determinism"` → 7/7 passed
- [x] Zero regressions: `flutter test` → 288/288 passed
- [x] `flutter analyze lib/services/schedule_generator.dart` → No issues found
- [x] `dart format lib/services/schedule_generator.dart` → applied (whitespace only)
- [x] Pipeline order verified: restorative floor → PRIORITY-03 → VSCHED-03 → FILL-02
- [x] placedCountPerGoal hoisted before all passes; anti-double-place writes in all three new passes

## Self-Check: PASSED

---
*Phase: 20-valence-aware-engine*
*Completed: 2026-06-15*
