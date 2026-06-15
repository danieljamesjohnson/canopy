---
phase: 20-valence-aware-engine
fixed_at: 2026-06-15T04:10:00Z
review_path: .planning/phases/20-valence-aware-engine/20-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 20: Code Review Fix Report

**Fixed at:** 2026-06-15T04:10:00Z
**Source review:** `.planning/phases/20-valence-aware-engine/20-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (CR-01, WR-01, WR-02, WR-03, IN-01)
- Fixed: 5
- Skipped: 0

## Fixed Issues

### CR-01 + WR-03: PRIORITY-03 double-place + map overwrite

**Files modified:** `lib/services/schedule_generator.dart`, `test/services/schedule_generator_test.dart`
**Commit:** aa7f8fa
**Applied fix:**
- Added `alreadyPlaced = placedCountPerGoal[goal.id] ?? 0` at the top of the PRIORITY-03 loop body.
- Changed the skip condition from `if (demand <= 0) continue` to `if (demand <= 0 || alreadyPlaced >= demand) continue` — this is the "no double-place" guard required by VSCHED-02.
- Changed map write from `placedCountPerGoal[goal.id] = 1` (hard assign) to `placedCountPerGoal[goal.id] = alreadyPlaced + 1` (increment), fixing both CR-01 and WR-03 at the same code point.
- Added regression test `CR-01 regression: gives+high-priority time-target on low-mood day gets exactly 1 chunk (no double-place)` verifying the exact scenario: `moodIndex=1, lighterDay=true`, gives valence, `priorityWeight=0.9`, 3h budget → demand=1 → exactly 1 chunk placed (not 2).

**Status:** fixed: requires human verification (logic fix; tests cover the regression scenario)

### WR-01: VSCHED-03 reserve sort non-deterministic tiebreaker

**Files modified:** `lib/services/schedule_generator.dart`
**Commit:** aa7f8fa
**Applied fix:**
- Added `a.id.compareTo(b.id)` as the final sort key in the VSCHED-03 reserve sort, matching the pattern used in the primary `timeTargetGoals` sort.
- Updated sort comment: `// gives-valence first; tie → composite score descending; tie → id (SC-4 stable)`.

### WR-02: VSCHED-01 outcome eligibility on low-mood non-lighter days

**Files modified:** `lib/services/schedule_generator.dart`
**Commit:** aa7f8fa
**Decision: documented as intentional (no behavior change).**

The `lighterDay=false` low-mood branch (`include = goal.deadline != null || goal.energyValence == EnergyValence.gives`) is intentionally fuller than the `lighterDay=true` branch. Reasoning:
- `lighterDay=false` means the user explicitly opted out of a reduced day — so it is a harder, fuller day even though mood is low.
- On a harder-low day, any deadline pressure qualifies (not just imminent deadlines); this is the policy that existed before Phase 20.
- The Phase 20 `|| gives` addition mirrors the lighter-day branch so gives-valence goals are protected on both low-mood paths.
- Tightening to a near-deadline window (e.g. ≤ 7 days) would change behavior that existing tests (CAP-01) depend on and would contradict the "fuller day" semantic.

Added an explanatory block comment at the else branch documenting the intentional asymmetry.

### WR-03: PRIORITY-03 hard-assigns `= 1` to placedCountPerGoal

Covered by the CR-01 fix above (same code point — same line changed to `alreadyPlaced + 1`). No separate action needed.

### IN-01: Dead `days == 1` branch in `_outcomeRationale`

**Files modified:** `lib/services/schedule_generator.dart`
**Commit:** aa7f8fa
**Applied fix:**
- Changed `return 'Deadline in $days day${days == 1 ? "" : "s"}';` to `return 'Deadline in $days days'; // days is always >= 2 here`.
- The `days == 1` arm of the ternary was unreachable (the `if (days == 1)` guard above it already returned `'Deadline tomorrow'`). Output is unchanged for all reachable inputs.

## Test / Analyze Results

```
flutter analyze lib/services/schedule_generator.dart → No issues found.
flutter test → 289 passed, 0 failed (was 288 before; +1 CR-01 regression test).
```

All 7 VSCHED + determinism tests pass. The new CR-01 regression test (index 49) passes, confirming the double-place is eliminated. The determinism test still passes after the WR-01 sort change.

---

_Fixed: 2026-06-15T04:10:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
