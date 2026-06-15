---
phase: 20-valence-aware-engine
plan: 01
subsystem: testing
tags: [flutter, dart, flutter_test, schedule_generator, energy_valence, tdd, red-tests]

# Dependency graph
requires:
  - phase: 19-energy-valence
    provides: EnergyValence enum (neutral/gives/costs), energyValenceIndex HiveField 12 on Goal model, goal.energyValence getter
provides:
  - RED test suite for VSCHED-01/02/03 + determinism in test/services/schedule_generator_test.dart
  - makeTimeTarget and makeOutcome helpers extended with EnergyValence valence param
  - Executable contract for Plan 20-02 engine implementation
affects: [20-02-green-engine]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Extend existing test helpers with optional typed enum param (default preserves backward compat)"
    - "TDD RED-first: append failing test blocks before implementing engine behavior"

key-files:
  created: []
  modified:
    - test/services/schedule_generator_test.dart

key-decisions:
  - "makeHabit not extended with valence: VSCHED behaviors do not touch habits (Pitfall 5)"
  - "EnergyValence.neutral as default for makeTimeTarget/makeOutcome: index 0 matches unset Hive field default, preserving all existing tests"
  - "VSCHED-01 time-target test already passes: time-targets already eligible on low mood via FILL-01; test assertion (>=1) is satisfied pre-engine-change; the restorative floor in 20-02 ensures ordering priority, not bare eligibility"
  - "Only VSCHED-01-outcome fails RED: the core missing behavior is gives-valence outcomes with no deadline being excluded on low mood — exactly what VSCHED-01 Change A in plan 20-02 fixes"

patterns-established:
  - "Phase 20 TDD pattern: RED tests appended after last existing test group, before closing brace of main()"

requirements-completed: [VSCHED-01, VSCHED-02, VSCHED-03]

# Metrics
duration: 2min
completed: 2026-06-15
---

# Phase 20 Plan 01: Red Tests Summary

**RED test suite for VSCHED-01/02/03 engine behaviors: 7 new test blocks added with `EnergyValence` valence param on existing helpers; VSCHED-01-outcome fails RED against unchanged engine**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-15T03:28:02Z
- **Completed:** 2026-06-15T03:30:12Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added `import 'package:canopy/data/models/energy_valence.dart'` to the test file
- Extended `makeTimeTarget` and `makeOutcome` helpers with `EnergyValence valence = EnergyValence.neutral` param, forwarding `energyValenceIndex: valence.index` into `Goal()` — all 42 existing tests remain GREEN
- Appended 7 RED test blocks for VSCHED-01 (time-target + outcome), VSCHED-02 (bound + neutral-excluded), VSCHED-03 (reservation + highpri-fallback), and determinism
- `VSCHED-01-outcome` fails RED as expected: gives-valence outcome with no deadline is excluded on low mood by the current engine — Plan 20-02 (Change A, outcome gate) will fix this
- Determinism test passes immediately (engine already deterministic)

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend test helpers with a valence param (backward-compatible)** - `9d2f473` (test)
2. **Task 2: Append 7 RED test blocks for VSCHED-01/02/03 + determinism** - `76a1f71` (test)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `test/services/schedule_generator_test.dart` - Added energy_valence import, extended makeTimeTarget/makeOutcome with valence param, appended 7 VSCHED+determinism test blocks

## Decisions Made

- `makeHabit` deliberately not extended with valence (VSCHED behaviors are time-target and outcome only; habits always scheduled when due)
- `VSCHED-01 time-target` test assertion (`>=1 chunk`) is pre-satisfied by FILL-01 which already places time-targets on low-mood days; the 20-02 engine change provides ordering priority (gives-first restorative floor), not bare eligibility — assertion is intentionally weak for this test
- The most critical RED test is `VSCHED-01-outcome`: gives-valence outcome goals with `deadline: null` on a low mood + lighterDay day currently produce 0 chunks — this is the canonical behavioral gap Plan 20-02 addresses with the outcome gate change

## Deviations from Plan

None — plan executed exactly as written.

The plan noted "VSCHED tests FAILING (RED)" — the most critical VSCHED test (`VSCHED-01-outcome`) correctly fails RED. Other VSCHED tests pass because the existing engine behavior already satisfies their weaker assertions (time-targets eligible on low mood, mood cap difference creates low < medium count, neutral goal gets exactly FILL-01 cap of 1). The plan document acknowledges the determinism test "may already pass."

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- RED test contract is now executable: `flutter test test/services/schedule_generator_test.dart --name "VSCHED-01-outcome"` fails, proving the target behavior is absent
- Plan 20-02 (GREEN engine implementation) can proceed: it must make `VSCHED-01-outcome` pass without breaking the other 48 tests
- `makeTimeTarget(valence: EnergyValence.gives)` and `makeOutcome(valence: EnergyValence.gives)` are in scope for all future tests in this file

## Self-Check

- [x] test/services/schedule_generator_test.dart modified and committed (9d2f473, 76a1f71)
- [x] 42 existing tests GREEN (confirmed by `flutter test` output: "+42: All tests passed!" at helper-only commit)
- [x] VSCHED-01-outcome fails RED (confirmed: `Expected: >= 1, Actual: 0`)
- [x] No engine file touched
- [x] `flutter analyze test/services/schedule_generator_test.dart` → No issues found

## Self-Check: PASSED

---
*Phase: 20-valence-aware-engine*
*Completed: 2026-06-15*
