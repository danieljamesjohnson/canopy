---
phase: 20-valence-aware-engine
reviewed: 2026-06-15T03:40:59Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - lib/services/schedule_generator.dart
findings:
  critical: 1
  warning: 3
  info: 1
  total: 5
status: issues_found
---

# Phase 20: Code Review Report

**Reviewed:** 2026-06-15T03:40:59Z
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed `lib/services/schedule_generator.dart` after the Phase 20 valence-aware engine
changes (VSCHED-01/02/03). The three new sub-passes (restorative floor, VSCHED-03 reserve,
shared `placedCountPerGoal` map) interact at their boundaries and one interaction is
incorrect: PRIORITY-03 bypasses the shared map's "already placed" guard, allowing a
gives+high-priority goal to receive two chunks on a low-mood day while the map records
only 1. One determinism gap was also found in the VSCHED-03 sort. Two additional
warnings cover a logical asymmetry in the outcome eligibility gate and a dead code
branch in a rationale helper.

---

## Critical Issues

### CR-01: PRIORITY-03 double-places a gives+high-priority goal on low-mood days; shared map value is then wrong

**File:** `lib/services/schedule_generator.dart:415-431`

**Issue:** On a low-mood day, the restorative floor pass (lines 385-405) places one chunk
for a `gives`-valence time-target goal with `priorityWeight >= 0.75` and writes
`placedCountPerGoal[goal.id] = 1`. PRIORITY-03 (lines 415-431) then runs unconditionally
(the `if (isLowMood)` block ended at line 405). PRIORITY-03 never checks
`placedCountPerGoal` before placing; it places a second chunk and then writes
`placedCountPerGoal[goal.id] = 1` — overwriting the existing value of 1 with 1 again,
not incrementing. The result:

1. Two `workChunks` entries exist for the same goal (double-placement).
2. `placedCountPerGoal[goal.id]` reads 1, not 2 — it no longer reflects actual placed count.
3. If this goal has `rawDemand >= 2`, FILL-02 sees `placed=1, demand_capped=1` and skips
   correctly. But if `rawDemand == 1`, FILL-02 sees `placed=1, demand=1` and also skips —
   so FILL-02 doesn't catch the double, it just stops. The user sees two chunks for the
   same goal on what should be a light restorative day.

The comment at line 374 says "no goal is double-placed" — this invariant is violated in
exactly the scenario the restorative floor was introduced for.

**Fix:** Add a `placedCountPerGoal` guard at the top of the PRIORITY-03 loop body, and
use `+=` not `= 1` when recording the placement:

```dart
for (final goal in timeTargetGoals) {
  if (discretionaryCount >= cap) break;
  if ((goal.priorityWeight ?? 0.5) < 0.75) continue;
  // Guard: if restorative floor already placed this goal, skip PRIORITY-03 for it.
  final alreadyPlaced = placedCountPerGoal[goal.id] ?? 0;
  final rawDemand = _demandForTimeTarget(goal, completionLogs, date);
  final demand = isLowMood ? rawDemand.clamp(0, 1) : rawDemand;
  if (demand <= 0 || alreadyPlaced >= demand) continue;
  workChunks.add(
    ScheduledChunk(
      chunkTypeIndex: ChunkType.work.index,
      goalId: goal.id,
      durationMinutes: 25,
      rationale: _timeTargetRationale(goal, completionLogs, date),
    ),
  );
  discretionaryCount++;
  placedCountPerGoal[goal.id] = alreadyPlaced + 1; // increment, not overwrite
}
```

---

## Warnings

### WR-01: VSCHED-03 reserve sort is non-deterministic when two gives-valence goals have identical composite scores

**File:** `lib/services/schedule_generator.dart:446-452`

**Issue:** The VSCHED-03 candidate sort (lines 446-452) tiebreaks on:
1. `gives` valence first (deterministic)
2. `score(b).compareTo(score(a))` — composite score descending

If two `gives`-valence candidates have identical composite scores (e.g., both have
`remainingHours=0` — fully satisfied — but still have demand, or both have the same
`weeklyHourBudget` and `priorityWeight` and same completion state), the sort has no final
tiebreaker. Dart's `List.sort` is not guaranteed stable. This violates SC-4 (determinism
is a hard requirement).

The primary `timeTargetGoals` sort at lines 367-372 does add `a.id.compareTo(b.id)` as a
stable final key, but that ordering is not carried into the VSCHED-03 re-sort. Two
identical inputs on two separate calls could pick different goals for the reserved slot.

**Fix:** Add `goal.id` as a final tiebreaker in the VSCHED-03 sort, matching the pattern
used at line 371:

```dart
..sort((a, b) {
  final aGives = a.energyValence == EnergyValence.gives ? 0 : 1;
  final bGives = b.energyValence == EnergyValence.gives ? 0 : 1;
  if (aGives != bGives) return aGives.compareTo(bGives);
  final scoreCmp = score(b).compareTo(score(a));
  if (scoreCmp != 0) return scoreCmp;
  return a.id.compareTo(b.id); // stable final key — SC-4
});
```

---

### WR-02: VSCHED-01 outcome eligibility on low-mood non-lighter days is more permissive than intended

**File:** `lib/services/schedule_generator.dart:328-334`

**Issue:** The VSCHED-01 outcome gate has two low-mood branches:

- `lighterDay=true` (line 330): `deadlineToday || gives` — tight: only today's deadline or gives.
- `lighterDay=false` (line 332-334): `goal.deadline != null || gives` — loose: **any** deadline,
  even 90 days out.

`lighterDay=false` is intended to be a harder/fuller day (the user opted out of the
lighter-day reduction), yet it admits far more outcome goals than `lighterDay=true`. On a
low-mood, non-lighter day a gives-valence outcome with a deadline three months out becomes
eligible — alongside every outcome that has any deadline at all. This directly contradicts
the VSCHED-02 bound that "low days stay light." The gives-valence addition at line 333 was
new in Phase 20 and makes this asymmetry more pronounced.

The likely intended reading for `lighterDay=false` on a low-mood day was: "deadline
pressure OR gives" (deadline imminent OR restorative), same spirit as the lighter branch
but without restricting to today-only deadlines. As-written, any deadline qualifies even
without gives valence, which predates Phase 20 — but the `|| gives` addition makes a
gives goal with a far-off deadline doubly eligible and highlights the asymmetry.

**Fix:** Confirm the intended behavior and document it explicitly. If "any deadline"
on a low non-lighter day is intentional, add a comment explaining why that is acceptable
despite the asymmetry. If the intent is "near deadline OR gives," tighten the condition:

```dart
} else {
  // low-mood, lighterDay=false: admit gives-valence goals or goals with
  // meaningful deadline pressure (e.g. <= 7 days).
  final daysRemaining = goal.deadline == null
      ? 9999
      : goal.deadline!.difference(date).inDays;
  include = daysRemaining <= 7 || goal.energyValence == EnergyValence.gives;
}
```

---

### WR-03: PRIORITY-03 assigns `placedCountPerGoal[goal.id] = 1` unconditionally, losing the increment

**File:** `lib/services/schedule_generator.dart:430`

**Issue:** Even ignoring the CR-01 double-placement scenario, line 430 writes
`placedCountPerGoal[goal.id] = 1` (hard assignment) rather than incrementing. On a
good-mood day (`!isLowMood`), PRIORITY-03 and VSCHED-03 can both run. If VSCHED-03 placed
a chunk for a high-priority goal first (`placed + 1` → correctly increments at line 468),
PRIORITY-03 then fires and overwrites `placedCountPerGoal[goal.id] = 1` — reverting to 1
even if VSCHED-03 had set it to 1 already, which happens to be the same value. But if
execution order were ever reversed or a second surplus-pass loop were introduced, a
hard-`= 1` would silently lose the accumulated count. 

More concretely: on a good-mood day, PRIORITY-03 runs before VSCHED-03 (code order lines
415 vs 437), so VSCHED-03's `placed = placedCountPerGoal[goal.id] ?? 0` at line 456 sees
the value PRIORITY-03 wrote. If PRIORITY-03 placed a chunk and wrote `= 1`, VSCHED-03
correctly reads `placed=1`. But the pattern is fragile — any reordering of the passes
breaks the accounting. Using `+= 1` (or the `alreadyPlaced + 1` pattern) is the robust
form.

**Fix:** Change line 430 to increment, not assign:

```dart
// Before:
placedCountPerGoal[goal.id] = 1;

// After:
placedCountPerGoal[goal.id] = (placedCountPerGoal[goal.id] ?? 0) + 1;
```

---

## Info

### IN-01: Dead branch in `_outcomeRationale` — singular guard on line 175 is unreachable

**File:** `lib/services/schedule_generator.dart:174-175`

**Issue:** Line 174 returns early when `days == 1` (`'Deadline tomorrow'`). Line 175 then
contains `'Deadline in $days day${days == 1 ? "" : "s"}'` where the `days == 1` arm of
the ternary is dead code — that case already returned. The output is still correct
(this branch is only reached for `days >= 2`), but the ternary is misleading.

**Fix:** Simplify to:

```dart
return 'Deadline in $days days'; // days is always >= 2 here
```

---

_Reviewed: 2026-06-15T03:40:59Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
