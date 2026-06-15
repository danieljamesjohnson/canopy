# Phase 20: Valence-Aware Engine - Research

**Researched:** 2026-06-14
**Domain:** Dart scheduling engine (pure Dart service, no Flutter), deterministic rule-based
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None — discuss phase was skipped (workflow.skip_discuss=true). All implementation choices
are at Claude's discretion. Use ROADMAP phase goal, success criteria, and the engine
constraints carried in STATE.md.

### Claude's Discretion
- Design of the VSCHED-01 restorative floor: which goal types, eligibility rule, slot count
- Design of the VSCHED-02 bound: the precise max restorative-floor slots on a low day
- Design of the VSCHED-03 reservation: placement in the pipeline, tie-breaking when
  multiple energy-giving/high-priority goals are available
- Test naming and assertion granularity

### Deferred Ideas (OUT OF SCOPE)
- VSCHED-F1: per-type reservation of the mood cap / full cross-type interleave
- LLM-inferred valence
- Calendar sync
- Multi-user features
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VSCHED-01 | On low ("stormy") mood days, energy-giving discretionary goals are eligible for scheduling instead of required + habits only | Step 3 outcome gate (lines 317–349 of schedule_generator.dart) is where the include/exclude decision is made for time-target AND outcome goals on low mood; the same gate governs VSCHED-01 for time-target goals in Step 4 (FILL-01 demand cap at line 409). |
| VSCHED-02 | The low-day restorative inclusion is bounded (a small floor, not full time-target load) so low days stay light | The "restorativeFloor" cap (proposed: `min(1, cap - habitCount)`) sits on top of the existing FILL-01 demand=1 cap; the bound is expressed as a hard slot limit AND enforced by the inequality low-day-discretionary < medium-day-discretionary in the deterministic test. |
| VSCHED-03 | On high ("sunny") mood days, at least one slot is reserved for an energy-giving / high-value goal so good days aren't pure backlog throughput | A pre-FILL-02 reservation pass for high-mood days (moodIndex >= 4) that runs before the round-robin, selects the top energy-giving (or high-priority) time-target goal, and places exactly 1 reserved chunk — consuming 1 slot of discretionary cap before backlog fill runs. |
</phase_requirements>

---

## Summary

Phase 20 adds three behavioral changes to `ScheduleGeneratorService.generate()` in
`lib/services/schedule_generator.dart`. The file is 637 lines of pure Dart with no Flutter
imports, no async, and no side effects — the ideal environment for deterministic rule-based
changes covered by unit tests.

**EnergyValence is already fully available to the generator.** The `Goal` model (Phase 19)
carries `energyValenceIndex` (HiveField 12) with a `goal.energyValence` getter returning
`EnergyValence.gives`, `EnergyValence.neutral`, or `EnergyValence.costs`. The generator
receives a `List<Goal> goals` parameter — every goal object it processes already has its
valence populated. No plumbing changes are needed.

**Mood is a bare integer (moodIndex 1–5) threaded directly into the generator.** The
check-in screen collects it, the schedule notifier passes it to `generate()`. The generator
derives `isLowMood = moodIndex <= 2`. High mood is `moodIndex >= 4`. There is no mood enum
to import or extend.

**The three changes touch only the `generate()` method body.** No new parameters, no new
public API, no Hive migration. VSCHED-01/02 modify the time-target step; VSCHED-03 adds a
pre-fill reservation pass.

**Primary recommendation:** Add a restorative-floor sub-step inside Step 4 (time-target
allocation) that, when `isLowMood`, elevates energy-giving time-target goals to be
scheduled ahead of neutral/costs goals, bounded by a `restorativeFloor` count of 1 (at
most 1 such chunk per day). For VSCHED-03, add a reservation sub-step before the FILL-02
round-robin (high mood only) that places 1 chunk for the top energy-giving or
high-priority time-target goal before throughput fill runs.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| VSCHED-01 low-day restorative floor selection | ScheduleGeneratorService (Dart service) | — | Pure allocation logic; no UI, no persistence |
| VSCHED-02 restorative bound (slot count limit) | ScheduleGeneratorService | — | Arithmetic cap applied inside generate(); enforced by unit test |
| VSCHED-03 high-day slot reservation | ScheduleGeneratorService | — | Pre-fill-round-robin pass inside generate() |
| EnergyValence data source | Goal model (lib/data/models/) | — | Persisted as int index via Hive; getter already implemented in Phase 19 |
| Mood input | ScheduleNotifier (caller of generate()) | CheckinScreen (UI) | moodIndex already threaded through; no change needed |
| Unit test coverage | test/services/schedule_generator_test.dart | — | All new behavior is deterministic → pure unit tests |

---

## Standard Stack

### Core

No new packages required. The change is entirely within existing Dart code.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_test (test harness) | bundled with Flutter 3.44.1 | Unit testing | Already used by the 47-test suite; `flutter test` is the test runner |
| dart:math | SDK | `max()` / `min()` | Already imported in schedule_generator.dart line 1 |

### Supporting

No supporting packages needed.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Modifying generate() in-place | Subclassing ScheduleGeneratorService | Subclassing would require callers to swap the instance; in-place is correct for a minimally-invasive change |
| A restorative-floor for all discretionary goal types | Time-target goals only | Habits already go through Step 2 unconditionally on low days. Outcome goals on low mood only appear on deadline==today (lighterDay=ON) or with any deadline (lighterDay=OFF). The FILL-01/02 Step 4 is where the "open capacity" concept lives — this is the correct injection point for a restorative floor on time-target goals. |

**Installation:** None. No packages to install.

---

## Package Legitimacy Audit

Not applicable — this phase installs no external packages.

---

## Architecture Patterns

### Generation Pipeline (current, annotated for Phase 20)

```
generate(goals, blocks, moodIndex, date, ...)
  │
  ├─ cap = _effectiveCap(moodIndex, lighterDay)      // mood 1=4, 2=6, 3=8, 4=9, 5=11 @ 80%
  ├─ isLowMood = moodIndex <= 2
  ├─ longBreakEvery = isLowMood ? 3 : 4
  │
  ├─ Step 1: Commitment blocks (anchored, not against cap)
  ├─ Step 2: Habits (due weekday only; habitCeiling = ceil(cap/2); PRIORITY-02 double on good mood)
  ├─ Step 3: Outcome goals
  │     isLowMood + lighterDay ON  → only deadline==today
  │     isLowMood + lighterDay OFF → all with deadlines
  │     !isLowMood                 → all outcomes
  ├─ Step 4: Time-target goals (FILL-01/02)
  │     PRIORITY-03 surplus: high-priority (≥0.75) gets +1 chunk before round-robin
  │     FILL-01: demand capped at 1 per goal on isLowMood
  │     FILL-02: round-robin until cap or all demands satisfied
  │
  │   ← VSCHED-01/02 inject HERE (inside Step 4, before PRIORITY-03 surplus)
  │   ← VSCHED-03 injects HERE (before FILL-02, after PRIORITY-03, high mood only)
  │
  ├─ CLOSE-02: Deferred carry-in injection
  └─ Ordering + break insertion pass
```

### System Architecture Diagram

```
CheckinScreen (moodIndex 1-5)
         │ moodIndex
         ▼
ScheduleNotifier.generateToday()
         │ goals (with .energyValence), moodIndex, blocks
         ▼
ScheduleGeneratorService.generate()
  ├─ [Step 2] Habits ──────────────────────────────────── always (isLowMood: demand=1)
  ├─ [Step 3] Outcomes ────────────── isLowMood: deadline gate / !isLowMood: all
  ├─ [Step 4a] VSCHED-01/02] Restorative floor ◄────────  NEW: isLowMood only
  │    filter: goal.energyValence == EnergyValence.gives
  │    sort: by composite score descending
  │    cap: restorativeFloor = 1 (bounded, VSCHED-02)
  ├─ [Step 4b] PRIORITY-03 surplus (high-priority bonus chunk)
  ├─ [Step 4c] VSCHED-03 Reservation ◄─────────────────  NEW: !isLowMood (high mood only)
  │    filter: goal.energyValence == EnergyValence.gives || priorityWeight >= 0.75
  │    sort: gives first, then by score
  │    cap: 1 reserved chunk before round-robin
  └─ [Step 4d] FILL-02 round-robin
         │
         ▼
    List<ScheduledChunk>
```

### Recommended Project Structure

No new files needed. All changes go in:
```
lib/services/schedule_generator.dart      # The only file that changes
test/services/schedule_generator_test.dart # New tests appended here
```

---

## Concrete Design: Three Behavioral Changes

### VSCHED-01 + VSCHED-02: Restorative Floor on Low Days

**Location in pipeline:** Inside Step 4, BEFORE the PRIORITY-03 surplus pass.

**Current behavior (Step 4, low mood):**

```dart
// FILL-01 caps demand at 1 per goal on low mood — this already fills open
// capacity with time-target goals, but it does not distinguish by valence.
final demand = isLowMood ? rawDemand.clamp(0, 1) : rawDemand;
```

The FILL-01/02 round-robin already places time-target goals on low-mood days (see
FILL-01 test at line 1302 in schedule_generator_test.dart). VSCHED-01 is NOT about making
time-target goals eligible — they already are. VSCHED-01 is specifically about the outcome
goal gate (Step 3) for energy-giving outcomes, AND about making the restorative intention
explicit by placing energy-giving time-targets FIRST (before neutral/costs goals consume the
limited open capacity).

**VSCHED-01 requires two micro-changes:**

**Change A — Step 3 (Outcomes, isLowMood gate):** Add `EnergyValence.gives` as an
additional eligibility condition. Currently on low mood + lighterDay only deadline-today
outcomes are included. Change: also include outcome goals with
`goal.energyValence == EnergyValence.gives` (regardless of deadline).

```dart
// CURRENT (line 324-333 in schedule_generator.dart):
final bool include;
if (!isLowMood) {
  include = true;
} else if (lighterDay) {
  include = deadlineToday;
} else {
  include = goal.deadline != null;
}

// PROPOSED:
final bool include;
if (!isLowMood) {
  include = true;
} else if (lighterDay) {
  // VSCHED-01: energy-giving outcomes always eligible on low-mood days.
  include = deadlineToday || goal.energyValence == EnergyValence.gives;
} else {
  include = goal.deadline != null || goal.energyValence == EnergyValence.gives;
}
```

**Change B — Step 4 (Time-targets, restorative floor sub-pass):** Before the PRIORITY-03
surplus pass, run a "restorative floor" pass that pulls energy-giving time-target goals to
the front. The floor is bounded by `restorativeFloor = 1` (VSCHED-02).

```dart
// VSCHED-01/02: Restorative floor — on low-mood days, guarantee at least
// 1 chunk goes to an energy-giving time-target goal (if one has demand)
// before the standard PRIORITY-03/FILL-02 passes run.
// VSCHED-02 bound: restorativeFloor = 1 keeps low days light.
const int restorativeFloor = 1;
int restorativeCount = 0;
if (isLowMood) {
  for (final goal in timeTargetGoals) {
    if (discretionaryCount >= cap) break;
    if (restorativeCount >= restorativeFloor) break;
    if (goal.energyValence != EnergyValence.gives) continue;
    final rawDemand = _demandForTimeTarget(goal, completionLogs, date);
    if (rawDemand <= 0) continue;
    workChunks.add(ScheduledChunk(
      chunkTypeIndex: ChunkType.work.index,
      goalId: goal.id,
      durationMinutes: 25,
      rationale: _timeTargetRationale(goal, completionLogs, date),
    ));
    discretionaryCount++;
    placedCountPerGoal[goal.id] = 1;
    restorativeCount++;
  }
}
```

**VSCHED-02 bound enforcement:** The `restorativeFloor = 1` constant is the bound. A test
asserts `lowDayDiscretionaryCount < mediumDayDiscretionaryCount` for identical goal inputs
(same goals, mood 1 vs mood 3).

**Important:** The existing `placedCountPerGoal` tracking must be initialized BEFORE both
the restorative floor pass and the PRIORITY-03 surplus pass (it already is at line 380).
The restorative pass writes into `placedCountPerGoal` so the FILL-02 round-robin correctly
accounts for the pre-placed chunk and does not double-place.

---

### VSCHED-03: Energy-Giving Slot Reservation on High Days

**Location in pipeline:** AFTER the PRIORITY-03 surplus pass, BEFORE the FILL-02
round-robin.

**Trigger condition:** `!isLowMood` (but most meaningful at moodIndex >= 4 where the backlog
fill risk is real; the condition `!isLowMood` = mood 3-5 is fine and keeps it simple).

**Definition of "energy-giving or high-priority":** A goal qualifies if
`goal.energyValence == EnergyValence.gives || (goal.priorityWeight ?? 0.5) >= 0.75`.
The energy-giving signal is primary; high-priority is the fallback when no gives-valence
goal has demand.

**Sort order for selection:** Sort qualifying goals by energyValence first (gives before
others), then by composite score (`_remainingHours * priorityWeight`) descending. Pick the
first goal with demand > 0 after already-placed deductions.

```dart
// VSCHED-03: On good-mood days, reserve 1 slot for an energy-giving /
// high-priority time-target goal before the backlog round-robin runs.
// Prevents high-backlog days from becoming pure throughput with zero
// restorative chunks.
if (!isLowMood) {
  // Qualify: gives-valence OR high-priority. Sort: gives first, then score.
  final reserveCandidates = timeTargetGoals
      .where((g) =>
          g.energyValence == EnergyValence.gives ||
          (g.priorityWeight ?? 0.5) >= 0.75)
      .toList()
    ..sort((a, b) {
      // gives before others; tie → composite score descending
      final aGives = a.energyValence == EnergyValence.gives ? 0 : 1;
      final bGives = b.energyValence == EnergyValence.gives ? 0 : 1;
      if (aGives != bGives) return aGives.compareTo(bGives);
      return score(b).compareTo(score(a));
    });

  for (final goal in reserveCandidates) {
    if (discretionaryCount >= cap) break;
    final placed = placedCountPerGoal[goal.id] ?? 0;
    final rawDemand = _demandForTimeTarget(goal, completionLogs, date);
    if (rawDemand <= 0 || placed >= rawDemand) continue;
    // Reserve exactly 1 slot.
    workChunks.add(ScheduledChunk(
      chunkTypeIndex: ChunkType.work.index,
      goalId: goal.id,
      durationMinutes: 25,
      rationale: _timeTargetRationale(goal, completionLogs, date),
    ));
    discretionaryCount++;
    placedCountPerGoal[goal.id] = placed + 1;
    break; // only 1 reserved slot
  }
}
```

**Determinism:** The sort is fully deterministic given the same inputs: energyValence index
(stored int), priorityWeight (stored double), remainingHours (computed from fixed
completionLogs), and goal.id as the secondary tiebreak (same as the existing FILL-02 sort
pattern). No randomness introduced.

**Does not break FILL-02:** The `placedCountPerGoal` update ensures the round-robin
correctly sees that the reserved goal already has 1 chunk and won't double-count it.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Goal sorting by composite criteria | Custom sort + comparator | Dart `List.sort` with inline comparator (already used everywhere in the generator) | Sort is stable in Dart; tiebreak on goal.id gives determinism |
| Valence storage | New field/migration | `goal.energyValence` getter (Phase 19 already delivers this) | Phase 19 shipped HiveField 12 + the getter; zero migration cost |
| Restorative slot counting | A new data structure | `int restorativeCount` local var (same pattern as `int habitCount`) | Mirrors the existing habitCeiling guard; minimal surface area |
| Test data construction | Custom fixtures | Extend existing `makeTimeTarget()` / `makeHabit()` / `makeOutcome()` helpers with `energyValenceIndex` param | Every test helper already exists; just add optional `energyValenceIndex` param |

**Key insight:** The generator already has all the building blocks — valence data on goals,
a composite score function, placedCountPerGoal tracking, and a round-robin loop. The change
is inserting two small guarded passes into the existing pipeline at exactly the right
positions.

---

## Common Pitfalls

### Pitfall 1: Double-placing a goal in the restorative pass AND FILL-02

**What goes wrong:** The restorative floor (VSCHED-01) places a chunk for an energy-giving
goal. FILL-02 then runs and places another chunk for the same goal, giving it 2 chunks on a
low-mood day that should only have 1 (demand cap = 1 per FILL-01).

**Why it happens:** If `placedCountPerGoal` is not written during the restorative pass, the
FILL-02 round-robin sees `placed == 0` for that goal and places a second chunk even though
demand on low mood is capped at 1.

**How to avoid:** Always write `placedCountPerGoal[goal.id] = 1` in the restorative pass
(shown in the design above). The FILL-01 `demand = isLowMood ? rawDemand.clamp(0, 1) : rawDemand`
check then sees `placed (1) >= demand (1)` and skips the goal.

**Warning signs:** A low-mood test that counts chunks for a gives-valence goal returns 2.

---

### Pitfall 2: VSCHED-02 bound check using discretionaryCount not restorativeCount

**What goes wrong:** The bound "low day discretionary count < medium day discretionary
count" sounds like a check on `discretionaryCount`, but it's about the total cap being
lower — not about a specific counter per goal type. The `restorativeFloor = 1` is the
per-pass cap; the overall cap (`moodCap[1]=4` vs `moodCap[3]=8`) enforces the day-level
inequality automatically.

**How to avoid:** The deterministic test (same goals, mood 1 vs mood 3) will catch any
violation. The `restorativeFloor = 1` constant is the only VSCHED-02 knob.

---

### Pitfall 3: VSCHED-03 reservation consuming the only remaining slot then PRIORITY-03 surplus can't fire

**What goes wrong:** PRIORITY-03 surplus runs before VSCHED-03 in the pipeline. If the
order is swapped (VSCHED-03 first), the reservation consumes a slot that PRIORITY-03 was
counting on, potentially breaking existing PRIORITY-03 tests.

**How to avoid:** Keep the pipeline order: PRIORITY-03 surplus → VSCHED-03 reservation →
FILL-02 round-robin. This is the order shown in the design above. Run the full existing
test suite after the change to catch any regression.

---

### Pitfall 4: Including only time-target goals in VSCHED-01 and missing outcome goals

**What goes wrong:** The requirements say "energy-giving discretionary goals" — that
includes outcome goals too, not just time-target goals. The outcome gate (Step 3) is
separate from the time-target step (Step 4).

**How to avoid:** Apply the valence eligibility check in BOTH Step 3 (outcome include
gate) AND Step 4 (restorative floor sub-pass). The design above addresses both.

---

### Pitfall 5: Over-engineering VSCHED-03 as a cross-type selector

**What goes wrong:** Trying to reserve a slot from habits or outcomes for VSCHED-03, not
just time-targets. This creates complex interactions with `habitCeiling`, the outcome sort,
and the CLOSE-02 carry-in.

**How to avoid:** Scope VSCHED-03 to time-target goals only, which are the goals that
participate in the open-capacity FILL-01/02 round-robin (the "backlog throughput" risk).
Habits are already always scheduled when due; outcomes are always included on good-mood
days. The "backlog throughput" problem is specifically about time-target goals, not habits
or outcomes.

---

## Code Examples

### Existing test helper pattern to extend [ASSUMED — code read directly]

```dart
// From test/services/schedule_generator_test.dart
Goal makeTimeTarget({
  String name = 'Time-target goal',
  double? weeklyHourBudget,
  double? priorityWeight,
}) => Goal(
  name: name,
  goalTypeIndex: GoalType.timeTarget.index,
  weeklyHourBudget: weeklyHourBudget,
  priorityWeight: priorityWeight,
);
```

**Extended for Phase 20:**

```dart
Goal makeTimeTarget({
  String name = 'Time-target goal',
  double? weeklyHourBudget,
  double? priorityWeight,
  EnergyValence valence = EnergyValence.neutral,
}) => Goal(
  name: name,
  goalTypeIndex: GoalType.timeTarget.index,
  weeklyHourBudget: weeklyHourBudget,
  priorityWeight: priorityWeight,
  energyValenceIndex: valence.index,
);
```

Same extension applies to `makeOutcome()`:

```dart
Goal makeOutcome({
  String name = 'Outcome goal',
  DateTime? deadline,
  double? priorityWeight,
  EnergyValence valence = EnergyValence.neutral,
}) => Goal(
  name: name,
  goalTypeIndex: GoalType.outcome.index,
  deadline: deadline,
  priorityWeight: priorityWeight,
  energyValenceIndex: valence.index,
);
```

### EnergyValence access in the generator [VERIFIED: code read from lib/data/models/]

```dart
// EnergyValence.gives = index 1 (not 0)
// neutral = 0, gives = 1, costs = 2
// The generator accesses via: goal.energyValence == EnergyValence.gives
import 'package:canopy/data/models/energy_valence.dart';
// (energy_valence.dart is already imported transitively through goal.dart;
// a direct import of energy_valence.dart may be needed in schedule_generator.dart)
```

**Note:** `schedule_generator.dart` imports `goal.dart` which imports `energy_valence.dart`.
The `EnergyValence` enum type is accessible via `goal.energyValence` without a direct
import — but to use `EnergyValence.gives` as a bare identifier in schedule_generator.dart,
a direct `import 'package:canopy/data/models/energy_valence.dart';` must be added at the
top of the file. [ASSUMED — needs verification during implementation; the import may or may
not be re-exported through goal.dart's part mechanism]

### isLowMood gating in schedule_generator.dart [VERIFIED: code read from lib/services/]

```dart
// Line 222 of schedule_generator.dart:
final bool isLowMood = moodIndex <= 2;
// "High mood" is implicitly moodIndex >= 4; the generator uses !isLowMood for mood 3-5.
// For VSCHED-03, !isLowMood (mood 3-5) is the correct trigger.
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Low mood = required + habits only | Low mood = required + habits + bounded restorative floor | Phase 20 (this phase) | Low days become livable without becoming high-demand |
| High mood = raise cap + fill backlog | High mood = raise cap + reserve 1 energy-giving slot + fill backlog | Phase 20 (this phase) | Good days stay purposeful, not just high-throughput |

**Deprecated/outdated:**

None — no existing behavior is removed, only extended at specific gated code paths.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `EnergyValence` is accessible in schedule_generator.dart via `goal.energyValence` without a separate direct import | Code Examples | If wrong: add `import 'package:canopy/data/models/energy_valence.dart';` to schedule_generator.dart — a trivial one-line fix, zero risk |
| A2 | Restricting VSCHED-03 to time-target goals (not habits/outcomes) fully satisfies the "pure backlog throughput" requirement | Architecture Patterns | If wrong: extend to outcomes as well — low additional complexity |
| A3 | `restorativeFloor = 1` (a single restorative chunk) is the correct VSCHED-02 bound | Concrete Design | If dogfooding shows the bound feels too restrictive, raise to 2 — a single constant change |
| A4 | The test for VSCHED-02 bound (low-day-discretionary < medium-day-discretionary) will pass given FILL-01 already caps per-goal demand at 1 on low mood | Validation Architecture | Low risk: moodCap[1]=4 vs moodCap[3]=8; even with restorativeFloor=1 extra, total low-mood discretionary stays well below medium |

---

## Open Questions

1. **Should VSCHED-03 apply at mood 3 or only mood 4-5?**
   - What we know: The "high day" / "sunny" framing from the CONTEXT suggests moodIndex >= 4. The generator currently uses `!isLowMood` (mood 3-5) for all "good mood" logic.
   - What's unclear: Whether a mood-3 day (medium) is considered "high" for the purposes of VSCHED-03.
   - Recommendation: Use `!isLowMood` (mood >= 3) for now, consistent with the existing generator convention. The cost is one extra reserved slot on mood-3 days, which is harmless.

2. **Should outcome goals with `energyValence == gives` also get a restorative floor treatment in Step 3?**
   - What we know: The design above adds valence to the outcome include gate (Change A). But there is no "floor" — an energy-giving outcome competes with other outcomes in the sort.
   - What's unclear: Whether an explicit floor for gives-valence outcomes is needed.
   - Recommendation: The Change A (include gate) is sufficient for VSCHED-01. The outcome step already places the goal if eligible; there is no cap to work around for outcomes the way there is for time-targets.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — this is a pure Dart service file change
with no new tools, runtimes, or services required beyond the existing Flutter toolchain).

Flutter 3.44.1 (confirmed installed at `/home/dan/development/flutter/bin`).
Test runner: `flutter test test/services/schedule_generator_test.dart` [VERIFIED].

---

## Validation Architecture

> `workflow.nyquist_validation` is not explicitly `false` in `.planning/config.json` — section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter 3.44.1) |
| Config file | none — uses default `flutter test` discovery |
| Quick run command | `flutter test test/services/schedule_generator_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VSCHED-01 | Low/stormy day with a gives-valence time-target goal → that goal appears in the generated schedule alongside required+habits | unit | `flutter test test/services/schedule_generator_test.dart --name "VSCHED-01"` | ❌ Wave 0 |
| VSCHED-01 | Low/stormy day with a gives-valence outcome goal (no deadline) → that goal appears in the schedule | unit | `flutter test test/services/schedule_generator_test.dart --name "VSCHED-01-outcome"` | ❌ Wave 0 |
| VSCHED-02 | Low day discretionary chunk count < medium day discretionary count for identical goal inputs | unit | `flutter test test/services/schedule_generator_test.dart --name "VSCHED-02"` | ❌ Wave 0 |
| VSCHED-02 | A neutral/costs time-target goal does NOT get a restorative floor slot on a low day | unit | `flutter test test/services/schedule_generator_test.dart --name "VSCHED-02-neutral-excluded"` | ❌ Wave 0 |
| VSCHED-03 | High/sunny day under heavy backlog still reserves ≥1 chunk for an energy-giving/high-priority goal | unit | `flutter test test/services/schedule_generator_test.dart --name "VSCHED-03"` | ❌ Wave 0 |
| VSCHED-03 | High day with no gives-valence time-target goals: high-priority goal gets the reservation | unit | `flutter test test/services/schedule_generator_test.dart --name "VSCHED-03-highpri-fallback"` | ❌ Wave 0 |
| Determinism | Same inputs produce same schedule (two identical calls) | unit | `flutter test test/services/schedule_generator_test.dart --name "determinism"` | ❌ Wave 0 |

### Exact Assertions (for Planner Reference)

**VSCHED-01 (time-target):**
```dart
// mood=1, gives-valence time-target + habits only
// expected: gives-valence goal appears in schedule
final givesGoal = makeTimeTarget(name: 'Yoga', weeklyHourBudget: 3,
    valence: EnergyValence.gives);
final habitGoal = makeHabit(name: 'Meditation');
final result = sut.generate(goals: [givesGoal, habitGoal], blocks: [],
    moodIndex: 1, date: monday, lighterDay: true);
final givesChunks = result.where((c) => c.chunkType == ChunkType.work
    && c.goalId == givesGoal.id).length;
expect(givesChunks, greaterThanOrEqualTo(1),
    reason: 'VSCHED-01: energy-giving time-target must appear on a low-mood day');
```

**VSCHED-01 (outcome, no deadline):**
```dart
// mood=1, gives-valence outcome (no deadline) + lighterDay=true
// currently excluded (no deadline → exclude); VSCHED-01 changes this
final givesOutcome = makeOutcome(name: 'Read', deadline: null,
    valence: EnergyValence.gives);
final result = sut.generate(goals: [givesOutcome], blocks: [],
    moodIndex: 1, date: monday, lighterDay: true);
final chunks = result.where((c) => c.chunkType == ChunkType.work
    && c.goalId == givesOutcome.id).length;
expect(chunks, greaterThanOrEqualTo(1),
    reason: 'VSCHED-01: gives-valence outcome with no deadline must appear on low day');
```

**VSCHED-02 bound:**
```dart
// Same goals, mood=1 vs mood=3 → low < medium discretionary count
final givesGoal = makeTimeTarget(name: 'Yoga', weeklyHourBudget: 10,
    valence: EnergyValence.gives);
final neutralGoal = makeTimeTarget(name: 'Work', weeklyHourBudget: 10,
    valence: EnergyValence.neutral);
final lowResult = sut.generate(goals: [givesGoal, neutralGoal], blocks: [],
    moodIndex: 1, date: monday, lighterDay: true);
final medResult = sut.generate(goals: [givesGoal, neutralGoal], blocks: [],
    moodIndex: 3, date: monday, lighterDay: true);
final lowCount = lowResult.where((c) => c.chunkType == ChunkType.work).length;
final medCount = medResult.where((c) => c.chunkType == ChunkType.work).length;
expect(lowCount, lessThan(medCount),
    reason: 'VSCHED-02: low day must have fewer discretionary chunks than medium day');
```

**VSCHED-03 reservation:**
```dart
// mood=4 (high), heavy backlog (many time-target goals saturating cap),
// one gives-valence goal → gives-valence goal must appear in schedule
final givesGoal = makeTimeTarget(name: 'Yoga', weeklyHourBudget: 10,
    valence: EnergyValence.gives);
final neutralGoals = List.generate(5, (i) =>
    makeTimeTarget(name: 'Backlog $i', weeklyHourBudget: 10,
        valence: EnergyValence.neutral));
final result = sut.generate(
    goals: [givesGoal, ...neutralGoals], blocks: [],
    moodIndex: 4, date: monday, lighterDay: true);
final givesChunks = result.where((c) => c.chunkType == ChunkType.work
    && c.goalId == givesGoal.id).length;
expect(givesChunks, greaterThanOrEqualTo(1),
    reason: 'VSCHED-03: energy-giving goal must be reserved even under heavy backlog');
```

**Determinism:**
```dart
// Two identical calls → identical chunk sequences
final goals = [makeTimeTarget(name: 'T', weeklyHourBudget: 5,
    valence: EnergyValence.gives)];
final r1 = sut.generate(goals: goals, blocks: [], moodIndex: 3, date: monday);
final r2 = sut.generate(goals: goals, blocks: [], moodIndex: 3, date: monday);
expect(r1.map((c) => c.goalId).toList(),
    equals(r2.map((c) => c.goalId).toList()),
    reason: 'determinism: same inputs must produce same schedule');
```

### Sampling Rate
- **Per task commit:** `flutter test test/services/schedule_generator_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/services/schedule_generator_test.dart` — new VSCHED-01/02/03 and determinism tests (append to existing file; file already exists at ✅)

*(The existing test file exists and has the correct harness. Wave 0 only adds new `test()` blocks — no new files, no new fixtures.)*

---

## Security Domain

This phase adds no authentication, session management, input from external sources,
cryptography, or network calls. The scheduling engine is a pure synchronous Dart function
with no I/O. ASVS categories V2, V3, V4, V6 do not apply.

**V5 Input Validation:** `EnergyValence.values[idx]` out-of-range is already guarded in
`goal.energyValence` getter (Phase 19, with safe-default return of `EnergyValence.neutral`
on out-of-range index). The generator uses the getter, not the raw index. No additional
validation needed.

---

## Sources

### Primary (HIGH confidence)
- `/home/dan/CodeProjects/canopy/lib/services/schedule_generator.dart` — read end-to-end;
  all pipeline steps, mood gating, cap logic, FILL-01/02 round-robin documented from source
- `/home/dan/CodeProjects/canopy/lib/data/models/goal.dart` — EnergyValence field (HiveField 12),
  energyValence getter, GoalType enum confirmed
- `/home/dan/CodeProjects/canopy/lib/data/models/energy_valence.dart` — enum order confirmed:
  `neutral=0, gives=1, costs=2`
- `/home/dan/CodeProjects/canopy/test/services/schedule_generator_test.dart` — all 47 tests
  read; harness pattern (makeHabit/makeOutcome/makeTimeTarget helpers, fixed testDate monday,
  inline assertions) confirmed
- `/home/dan/CodeProjects/canopy/lib/providers/schedule_notifier.dart` — mood threading
  confirmed: `moodIndex` int from check-in passed directly to `_generator.generate()`

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` — Engine Constraints section; carry-forward rules confirmed against source
- `.planning/phases/20-valence-aware-engine/20-CONTEXT.md` — phase boundary and decisions

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; existing stack confirmed in code
- Architecture: HIGH — pipeline read directly from source; injection points exact
- Pitfalls: HIGH — derived from actual code structure (placedCountPerGoal tracking,
  isLowMood gate, Step 3 vs Step 4 separation)
- Test assertions: HIGH — derived from actual test harness patterns in existing test file

**Research date:** 2026-06-14
**Valid until:** 2026-07-14 (stable code; low risk of change before planning executes)
