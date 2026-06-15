# Phase 20: Valence-Aware Engine - Pattern Map

**Mapped:** 2026-06-14
**Files analyzed:** 2 (1 production modification, 1 test file append)
**Analogs found:** 4 / 4 (all from the same files being modified)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/services/schedule_generator.dart` — Step 3 outcome gate (VSCHED-01 Change A) | service | transform | Lines 324–332 of same file: existing `isLowMood` + `lighterDay` + `deadlineToday` gate | exact |
| `lib/services/schedule_generator.dart` — Step 4 restorative floor sub-pass (VSCHED-01/02 Change B) | service | transform | Lines 399–423 of same file: FILL-02 round-robin loop + `placedCountPerGoal` tracking | role-match |
| `lib/services/schedule_generator.dart` — Step 4 VSCHED-03 reservation pass | service | transform | Lines 380–397 of same file: PRIORITY-03 surplus pass (single chunk placed per qualifying goal, `break` after 1) | exact |
| `test/services/schedule_generator_test.dart` — new VSCHED-01/02/03/determinism test blocks | test | N/A | Lines 24–62 of same file: `makeHabit` / `makeOutcome` / `makeTimeTarget` helpers + existing `test()` body pattern | exact |

---

## Pattern Assignments

### VSCHED-01 Change A — Step 3 outcome include gate (lines 324–332)

**Analog:** Existing gate in `lib/services/schedule_generator.dart` lines 324–332

**Current pattern to copy-and-extend:**

```dart
// lib/services/schedule_generator.dart lines 324-332
final bool include;
if (!isLowMood) {
  include = true; // mood 3–5: all outcomes
} else if (lighterDay) {
  include = deadlineToday; // mood 1–2 lighter ON: only deadline today
} else {
  include =
      goal.deadline != null; // mood 1–2 lighter OFF: all with deadlines
}
```

**VSCHED-01 modification — add `|| goal.energyValence == EnergyValence.gives` to the two low-mood branches:**

```dart
// MODIFIED for VSCHED-01:
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

**Required import (add at top of file, no equivalent exists yet):**

```dart
// Currently NOT present in schedule_generator.dart imports (lines 1–7).
// Must be added:
import 'package:canopy/data/models/energy_valence.dart';
```

The existing imports block for reference (lines 1–7):

```dart
import 'dart:math';

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:intl/intl.dart';
```

---

### VSCHED-01/02 Change B — Step 4 restorative floor sub-pass

**Analog:** PRIORITY-03 surplus pass in `lib/services/schedule_generator.dart` lines 380–397 (single-chunk-per-qualifying-goal pattern with `placedCountPerGoal` write and `discretionaryCount` guard). Also mirrors FILL-02 loop structure (lines 399–423) for the per-goal iteration pattern.

**PRIORITY-03 analog to copy structure from (lines 380–397):**

```dart
// lib/services/schedule_generator.dart lines 380-397
final placedCountPerGoal = <String, int>{};
for (final goal in timeTargetGoals) {
  if (discretionaryCount >= cap) break;
  if ((goal.priorityWeight ?? 0.5) < 0.75) continue;
  final rawDemand = _demandForTimeTarget(goal, completionLogs, date);
  final demand = isLowMood ? rawDemand.clamp(0, 1) : rawDemand;
  if (demand <= 0) continue;
  workChunks.add(
    ScheduledChunk(
      chunkTypeIndex: ChunkType.work.index,
      goalId: goal.id,
      durationMinutes: 25,
      rationale: _timeTargetRationale(goal, completionLogs, date),
    ),
  );
  discretionaryCount++;
  placedCountPerGoal[goal.id] = 1;
}
```

**FILL-02 analog (lines 399–423) for the outer loop + `placed >= demand` skip pattern:**

```dart
// lib/services/schedule_generator.dart lines 399-423
bool anyPlaced = true;
while (anyPlaced && discretionaryCount < cap) {
  anyPlaced = false;
  for (final goal in timeTargetGoals) {
    if (discretionaryCount >= cap) break;
    final placed = placedCountPerGoal[goal.id] ?? 0;
    final rawDemand = _demandForTimeTarget(goal, completionLogs, date);
    final demand = isLowMood ? rawDemand.clamp(0, 1) : rawDemand;
    if (demand <= 0 || placed >= demand) continue;
    workChunks.add(
      ScheduledChunk(
        chunkTypeIndex: ChunkType.work.index,
        goalId: goal.id,
        durationMinutes: 25,
        rationale: _timeTargetRationale(goal, completionLogs, date),
      ),
    );
    discretionaryCount++;
    placedCountPerGoal[goal.id] = placed + 1;
    anyPlaced = true;
  }
}
```

**Insertion point:** BEFORE the PRIORITY-03 surplus pass (before line 380), inside Step 4, after `timeTargetGoals` sort is computed (after line 370).

**VSCHED-01/02 new sub-pass to insert (copy structural pattern from PRIORITY-03):**

```dart
// VSCHED-01/02: Restorative floor — on low-mood days, guarantee at least
// 1 chunk goes to an energy-giving time-target goal (if one has demand)
// before the PRIORITY-03/FILL-02 passes run.
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
    workChunks.add(
      ScheduledChunk(
        chunkTypeIndex: ChunkType.work.index,
        goalId: goal.id,
        durationMinutes: 25,
        rationale: _timeTargetRationale(goal, completionLogs, date),
      ),
    );
    discretionaryCount++;
    placedCountPerGoal[goal.id] = 1; // CRITICAL: prevents FILL-02 double-place
    restorativeCount++;
  }
}
```

**Critical:** `placedCountPerGoal` must be declared BEFORE this pass. Move its declaration (`final placedCountPerGoal = <String, int>{};`) to before the restorative floor block, so it is visible to all three passes (restorative floor, PRIORITY-03, FILL-02). Currently it is declared at line 380 (start of PRIORITY-03). Move it to just before the `if (isLowMood)` restorative block.

---

### VSCHED-03 — Step 4 reservation pass before FILL-02

**Analog:** PRIORITY-03 surplus pass (lines 380–397) — same "place exactly 1 chunk for qualifying goal, `break` after first success" shape.

**Insertion point:** AFTER PRIORITY-03 surplus pass (after line 397), BEFORE FILL-02 while-loop (before line 399).

**VSCHED-03 new pass (structural copy of PRIORITY-03 with different filter, sort, and `break`):**

```dart
// VSCHED-03: On good-mood days, reserve 1 slot for an energy-giving /
// high-priority time-target goal before the backlog round-robin runs.
// Prevents high-backlog days from becoming pure throughput with zero
// restorative chunks.
if (!isLowMood) {
  final reserveCandidates = timeTargetGoals
      .where((g) =>
          g.energyValence == EnergyValence.gives ||
          (g.priorityWeight ?? 0.5) >= 0.75)
      .toList()
    ..sort((a, b) {
      // gives-valence first; tie → composite score descending
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
    workChunks.add(
      ScheduledChunk(
        chunkTypeIndex: ChunkType.work.index,
        goalId: goal.id,
        durationMinutes: 25,
        rationale: _timeTargetRationale(goal, completionLogs, date),
      ),
    );
    discretionaryCount++;
    placedCountPerGoal[goal.id] = placed + 1;
    break; // only 1 reserved slot
  }
}
```

Note: `score(Goal g)` is already declared at line 361 inside `generate()` and is in scope.

---

### Test file — new `test()` blocks appended to `test/services/schedule_generator_test.dart`

**Analog:** Existing test helpers and `test()` body pattern, lines 24–80 of the test file.

**Helper pattern to extend (lines 24–62):**

```dart
// test/services/schedule_generator_test.dart lines 24-62
Goal makeHabit({String name = 'Habit goal', double? priorityWeight}) => Goal(
  name: name,
  goalTypeIndex: GoalType.habit.index,
  priorityWeight: priorityWeight,
);

Goal makeOutcome({
  String name = 'Outcome goal',
  DateTime? deadline,
  double? priorityWeight,
}) => Goal(
  name: name,
  goalTypeIndex: GoalType.outcome.index,
  deadline: deadline,
  priorityWeight: priorityWeight,
);

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

**Extended helpers — add `energyValenceIndex` optional param to `makeTimeTarget` and `makeOutcome`:**

```dart
// EXTEND makeTimeTarget (replace existing helper):
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

// EXTEND makeOutcome (replace existing helper):
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

The default `valence: EnergyValence.neutral` means all 47 existing tests continue to pass unmodified (neutral is the zero-index default, matching the unset Hive field behavior).

**Required import for test file (add alongside existing imports):**

```dart
import 'package:canopy/data/models/energy_valence.dart';
```

**`test()` body pattern to copy (lines 84–93 — the simplest body shape):**

```dart
// test/services/schedule_generator_test.dart lines 84-93
test('Test 1: no goals, no blocks → empty list', () {
  final result = sut.generate(
    goals: [],
    blocks: [],
    moodIndex: 3,
    date: monday,
    completionLogs: [],
  );
  expect(result, isEmpty);
});
```

**Fixture variables already in scope for all new tests (lines 11–17):**

```dart
// test/services/schedule_generator_test.dart lines 11-17
final monday = DateTime(2026, 3, 23);   // weekday == 1

setUp(() {
  sut = ScheduleGeneratorService();
});
```

**`workChunksOf` helper already in scope (line 75–76):**

```dart
int workChunksOf(List<ScheduledChunk> result) =>
    result.where((c) => c.chunkType == ChunkType.work).length;
```

---

## Shared Patterns

### `isLowMood` gating
**Source:** `lib/services/schedule_generator.dart` line 218
**Apply to:** All three new code blocks (restorative floor, VSCHED-03 reservation)

```dart
final bool isLowMood = moodIndex <= 2;
```

High mood for VSCHED-03 is `!isLowMood` (mood 3–5), consistent with all existing good-mood logic in the file.

### ScheduledChunk construction
**Source:** `lib/services/schedule_generator.dart` lines 387–394 (PRIORITY-03 surplus chunk)
**Apply to:** All three new work-chunk placements

```dart
workChunks.add(
  ScheduledChunk(
    chunkTypeIndex: ChunkType.work.index,
    goalId: goal.id,
    durationMinutes: 25,
    rationale: _timeTargetRationale(goal, completionLogs, date),
  ),
);
discretionaryCount++;
placedCountPerGoal[goal.id] = 1;
```

### `placedCountPerGoal` tracking
**Source:** `lib/services/schedule_generator.dart` lines 380, 396, 420
**Apply to:** Restorative floor pass (must write `placedCountPerGoal[goal.id] = 1`) and VSCHED-03 reservation (must write `placedCountPerGoal[goal.id] = placed + 1`). Without these writes, FILL-02 will double-place the chunk.

---

## No Analog Found

None — all patterns have direct analogs in the files being modified.

---

## Pipeline Order (critical for correctness)

The three new sub-passes must be inserted in this exact order within Step 4:

```
[existing] timeTargetGoals sort (line 363–370)
[NEW]      placedCountPerGoal declaration (moved earlier, before restorative floor)
[NEW]      VSCHED-01/02 restorative floor pass (isLowMood only)
[existing] PRIORITY-03 surplus pass (lines 381–397, placedCountPerGoal already declared above)
[NEW]      VSCHED-03 reservation pass (!isLowMood only)
[existing] FILL-02 round-robin while-loop (lines 399–423)
```

Swapping PRIORITY-03 and VSCHED-03 would allow the reservation to consume a slot PRIORITY-03 was counting on and could break existing PRIORITY-03 tests.

---

## Metadata

**Analog search scope:** `lib/services/schedule_generator.dart` (637 lines, read in 4 targeted passes); `test/services/schedule_generator_test.dart` (read lines 1–160)
**Files scanned:** 2 source files + 2 model files (goal.dart, energy_valence.dart)
**Pattern extraction date:** 2026-06-14
