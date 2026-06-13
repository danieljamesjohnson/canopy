# Phase 15: Engine Honesty - Research

**Researched:** 2026-06-13
**Domain:** Dart scheduling engine (pure logic, no Flutter dependencies)
**Confidence:** HIGH — all findings are from direct codebase inspection

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None — discuss phase was skipped per workflow.skip_discuss.

### Claude's Discretion
All implementation choices are at Claude's discretion. Use ROADMAP phase goal, success criteria, and codebase conventions.

### Deferred Ideas (OUT OF SCOPE)
None — discuss phase skipped.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAP-01 | Capacity shared across goal types on scarce (low-mood) days — habits cannot consume the entire cap before outcomes and time-targets are considered. | Engine Step 2 runs first and exhausts cap; fix: per-type cap reservation or interleaved allocation. |
| STREAK-01 | Displayed streak equals the actual computed backward due-day walk — no divergence possible. | `goal.streakCount` is written on markComplete/markSkipped; UI reads `goal.streakCount`; but it is NOT recomputed at schedule generation time. Divergence window exists between mark actions. |
| PRIORITY-02 | Raising a habit's or outcome's priority changes allocation (more/earlier chunks), not just sort order — observable for all three goal types. | Habits get exactly 1 chunk regardless of priority; outcomes also get exactly 1 chunk; only time-targets can receive multiple chunks. Priority must change chunk counts for habits/outcomes too. |
| FILL-01 | When open capacity remains after required work and habits, regular-time (time-target) goals claim leftover slots on low-mood days. | Step 4 (time-target allocation) is gated `if (!isLowMood)` — it never runs on mood 1–2. Low-mood days leave open capacity empty. |
| FILL-02 | Open-capacity fill distributed across regular-time goals by priority; no single goal swallows the open day. | The existing Step 4 greedy loop fills one goal to its full demand before moving to the next. When demand exceeds cap, high-priority wins the whole surplus rather than sharing it. |
</phase_requirements>

---

## Summary

Phase 15 fixes five concrete correctness problems in `lib/services/schedule_generator.dart` and one streak-display synchronization gap. All five requirements map to specific lines and logic branches in the engine — this is a focused engine-only phase with no UI rework beyond what is needed to surface the truthful streak value.

The scheduling engine (`ScheduleGeneratorService.generate()`) allocates work in four sequential steps: commitment blocks (Step 1, anchored), habits (Step 2, discretionary), outcomes (Step 3, discretionary), time-target goals (Step 4, discretionary). A single `discretionaryCount` counter advances through all steps against a per-mood cap. The fundamental problems are: (a) earlier steps can exhaust the cap before later steps run (CAP-01, PRIORITY-02, FILL-01); (b) Step 4 is hard-gated off for mood 1–2 even when cap room remains (FILL-01); (c) the per-goal habit/outcome demand is hardcoded to exactly 1 chunk so priority can only reorder, not reallocate (PRIORITY-02); (d) streak written at mark-time is consistent inside a session but a generation-time divergence window exists (STREAK-01); and (e) the Step 4 greedy loop hands all open capacity to one goal before moving on (FILL-02).

**Primary recommendation:** Introduce per-type cap reservations in Step 2 (habits) so habits cannot exhaust the entire discretionary cap; extend FILL-01 by lifting the `!isLowMood` gate on Step 4 to also run when capacity is available on low-mood days; and upgrade habits/outcomes to support multi-chunk demand (capped at a small per-type max) so priority weight influences chunk counts, not only sort order.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Scheduling / allocation | `ScheduleGeneratorService` (pure Dart service) | `ScheduleNotifier` (caller) | Engine owns algorithm; notifier owns persistence and log integration |
| Streak computation | `ScheduleGeneratorService.computeStreak()` (static) | `ScheduleNotifier.markComplete/markSkipped/markDeferred` (write-back) | Single canonical formula in engine; notifier triggers write-back |
| Streak display | `GoalCard._secondaryLine()` (UI) | `goal.streakCount` (persisted field) | UI reads persisted field; correctness depends on write-back being timely |
| Mood cap | `ScheduleGeneratorService._moodCap` + `_effectiveCap()` | — | Pure engine concern |
| Priority scheduling | `ScheduleGeneratorService.generate()` Steps 2–4 | — | Sort order and chunk demand both live in the engine |

---

## Standard Stack

No new external packages. This phase is pure Dart logic changes to existing files.

| File | Role | Changes in This Phase |
|------|------|-----------------------|
| `lib/services/schedule_generator.dart` | Scheduling engine (pure Dart, no Flutter) | CAP-01, PRIORITY-02, FILL-01, FILL-02 fixes |
| `lib/providers/schedule_notifier.dart` | Notifier; triggers streak write-back | STREAK-01: ensure write-back path is complete |
| `lib/screens/goals/widgets/goal_card.dart` | Reads `goal.streakCount` for display | STREAK-01: verify display reads the persisted field (already does; no change likely needed) |
| `test/services/schedule_generator_test.dart` | Engine unit tests | New tests for CAP-01, PRIORITY-02, FILL-01, FILL-02 |
| `test/providers/schedule_notifier_engine_test.dart` | Notifier-level integration tests | STREAK-01 divergence test if needed |

---

## Architecture Patterns

### System Architecture Diagram

```
check-in → moodIndex ──────────────────────────────────────────┐
                                                                │
goals list ──────────────────────────────────────────────────┐ │
                                                             │ │
commitment blocks ──────────────────────────────────────────┐│ │
                                                            ││ │
                                                ┌───────────▼▼─▼──────────────┐
                                                │  ScheduleGeneratorService   │
                                                │                             │
                                                │  Step 1: commitment blocks  │
                                                │   (not counted against cap) │
                                                │                             │
                                                │  Step 2: habits             │
                                                │   (currently: exhausts cap) │
                                                │   [CAP-01 fix: reserve ≤X%] │
                                                │                             │
                                                │  Step 3: outcomes           │
                                                │   (currently: 1 chunk each) │
                                                │   [PRIORITY-02 fix: demand] │
                                                │                             │
                                                │  Step 4: time-targets       │
                                                │   (currently: mood 3–5 only)│
                                                │   [FILL-01 fix: always run] │
                                                │   [FILL-02 fix: round-robin]│
                                                │                             │
                                                │  Break insertion pass       │
                                                └──────────────┬──────────────┘
                                                               │
                                              List<ScheduledChunk>
                                                               │
                                        ┌──────────────────────▼──────────────────────┐
                                        │  ScheduleNotifier.generateToday()           │
                                        │  → persists DailySchedule                  │
                                        │  → markComplete/markSkipped triggers        │
                                        │    computeStreak() write-back               │
                                        └──────────────────────┬──────────────────────┘
                                                               │
                                                goal.streakCount (Hive persisted)
                                                               │
                                        ┌──────────────────────▼──────────────────────┐
                                        │  GoalCard._secondaryLine()                  │
                                        │  reads g.streakCount → "N-day streak"       │
                                        └─────────────────────────────────────────────┘
```

### Recommended Project Structure (unchanged)

```
lib/services/
└── schedule_generator.dart   # ALL engine changes land here

lib/providers/
└── schedule_notifier.dart    # STREAK-01 write-back verification here

test/services/
└── schedule_generator_test.dart   # New tests for each requirement

test/providers/
└── schedule_notifier_engine_test.dart   # Notifier-level streak tests
```

---

## Requirement-to-Code Mapping

This is the core of the research. Each requirement maps to a specific location in `schedule_generator.dart` and a specific mechanical fix.

---

### CAP-01: Capacity Monopolization by Habits

**Current behavior (the bug):**

```dart
// schedule_generator.dart lines 253–278
for (final goal in habitGoals) {
  if (discretionaryCount >= cap) break;   // ← single shared counter
  ...
  discretionaryCount++;
}

// Step 3 outcomes run AFTER Step 2 habits:
for (final goal in outcomeGoals) {
  if (discretionaryCount >= cap) break;   // ← counter may already == cap
```

On mood 1 (cap=4), four or more daily habits fill `discretionaryCount` to 4 before Step 3 even starts. Outcomes and time-targets receive zero chunks.

**Root cause:** The cap is shared across all steps with no per-type reservation. The processing order (habits first) acts as implicit priority: habits always win the scarce cap on low-mood days.

**Fix:** Reserve a maximum fraction of the cap for habits. A habit ceiling of `(cap / 2).ceil()` (i.e., half, rounded up) ensures at least floor(cap/2) slots remain for outcomes and time-targets after Step 2. This makes low-mood days still include outcomes without stripping habits entirely.

Implementation pattern:

```dart
// In generate(), after computing `cap`:
final int habitCeiling = (cap / 2).ceil(); // e.g. cap=4 → ceiling=2; cap=6 → ceiling=3

// Step 2 loop:
int habitCount = 0;
for (final goal in habitGoals) {
  if (discretionaryCount >= cap) break;
  if (habitCount >= habitCeiling) break;  // ← type-specific ceiling
  ...
  discretionaryCount++;
  habitCount++;
}
```

[ASSUMED] The exact fraction (50%) is a reasonable starting point — user should confirm via dogfooding. The ceiling logic is the mechanism; the value is discretionary.

**Test scenario:** mood=1, cap=4, 4 daily habits + 1 outcome goal → with fix, 2 habit chunks + 1 outcome chunk appear. Without fix, 4 habit chunks + 0 outcome chunks.

---

### STREAK-01: Streak Divergence Between Display and Computation

**Current behavior (the bug and its scope):**

`GoalCard._secondaryLine()` at line 60 reads `g.streakCount` directly:

```dart
// goal_card.dart line 60-62
case GoalType.habit:
  if (g.streakCount > 0) {
    return '${g.streakCount}-day streak';
```

`goal.streakCount` is a persisted Hive field (HiveField 11). It is written in two places:

1. `ScheduleNotifier.markComplete()` (line 201) — recomputes and persists after completion.
2. `ScheduleNotifier.markSkipped()` (line 269) — recomputes and persists after skip.
3. `ScheduleNotifier.markDeferred()` (line 342) — recomputes and persists after deferral.

**The divergence window exists at schedule generation time.** When `generateToday()` runs, it calls `computeStreak()` internally to produce the `rationale` string for the chunk (line 263–268), but it does **not** write the computed value back to `goal.streakCount`. The engine computes the authoritative streak at generation time but throws it away — only the rationale string survives. The goal card reads the older `streakCount` value from Hive until the user next marks the chunk complete/skipped.

Additionally, `goal.streakCount` is read at app start via `GoalsNotifier.loadGoals()` which calls `_repository.getActive()`. If the app is cold-launched the day after a completion without the user triggering a mark action, `streakCount` reflects the last mark-time value, not a fresh computation from today's perspective.

**Fix:** At the end of `generate()` in the engine (or in `generateToday()` in the notifier), recompute and write `goal.streakCount` for every habit goal. The notifier already has `allLogs` in scope during `generateToday()`:

```dart
// In ScheduleNotifier.generateToday(), after calling _generator.generate():
for (final goal in goals.where((g) => !g.isArchived && g.goalType == GoalType.habit)) {
  final due = ScheduleGeneratorService.computeDueWeekdays(goal.frequencyPerWeek ?? 7);
  final logsForGoal = allLogs.where((l) => l.goalId == goal.id).toList();
  final streak = ScheduleGeneratorService.computeStreak(goal.id, due, logsForGoal, today: date);
  if (goal.streakCount != streak) {
    goal.streakCount = streak;
    await _goalRepo.save(goal);
  }
}
```

This makes `goal.streakCount` match `computeStreak()` at schedule generation time, eliminating the divergence window.

**Note:** The write-back on mark actions (markComplete, markSkipped, markDeferred) already exists and is correct. The only gap is the generation-time sync.

**Test scenario:** Habit with 2 prior completed due-days. Generate schedule without marking anything. Goal card should show "2-day streak" matching what `computeStreak` would return — not the stale 0 from initial default. This test must exercise the generation path, not the mark path.

---

### PRIORITY-02: Priority Only Reorders Habits/Outcomes; Does Not Change Chunk Count

**Current behavior (the bug):**

```dart
// Step 2 — habits: sorted by priority, but each gets exactly 1 chunk
for (final goal in habitGoals) {         // one pass, one chunk per goal
  if (discretionaryCount >= cap) break;
  ...
  workChunks.add(ScheduledChunk(...));   // exactly 1 chunk unconditionally
  discretionaryCount++;
}

// Step 3 — outcomes: same pattern, exactly 1 chunk per outcome
for (final goal in outcomeGoals) {
  if (discretionaryCount >= cap) break;
  ...
  workChunks.add(ScheduledChunk(...));   // exactly 1 chunk unconditionally
  discretionaryCount++;
}
```

High-priority habits and outcomes get exactly the same number of chunks as low-priority ones (1). Priority only determines which goal appears first when cap is the binding constraint — it cannot increase a goal's chunk count.

**Fix for habits:** Give high-priority habits a demand of 2 chunks on higher-mood days (mood 3–5). A simple demand function: `habitDemand(priorityWeight) = (priorityWeight >= 0.75) ? 2 : 1`. This means a high-priority habit occupies 2 slots while normal/low habits occupy 1, making the allocation observably different.

Apply the demand ceiling (same as CAP-01 habit ceiling) so that a full slate of high-priority habits cannot monopolize via double-counting.

```dart
int habitDemand(Goal g) => (g.priorityWeight ?? 0.5) >= 0.75 && !isLowMood ? 2 : 1;

for (final goal in habitGoals) {
  if (discretionaryCount >= cap) break;
  if (habitCount >= habitCeiling) break;
  final demand = habitDemand(goal);
  for (int i = 0; i < demand; i++) {
    if (discretionaryCount >= cap) break;
    if (habitCount >= habitCeiling) break;
    workChunks.add(ScheduledChunk(...));
    discretionaryCount++;
    habitCount++;
  }
}
```

**Fix for outcomes:** Give high-priority outcomes 2 chunks (mood 3–5). On low-mood days outcomes remain 0 or 1 per the lighter-day rules, so the priority count-effect is mood-gated.

**Constraint (from SEED-003):** Outcome/habit priority currently reorders within the type. The success criterion (SC3) says "raising a habit's priority increases the number of chunks it receives relative to a lower-priority habit." The 1→2 chunk difference satisfies this. The urgency sort for outcomes remains; high-priority boosts the score AND adds a second chunk.

**Test scenario:**
- Two habits, high priority (0.75) vs normal (0.5), mood=3, cap ≥ 3: high-priority habit gets 2 chunks, normal gets 1.
- Two outcomes, high priority (0.75) vs normal (0.5), mood=3, both with same deadline: high gets 2 chunks, normal gets 1.

---

### FILL-01: Low-Mood Days Leave Open Capacity Empty

**Current behavior (the bug):**

```dart
// schedule_generator.dart lines 332–355
if (!isLowMood) {                        // ← hard gate: NEVER runs on mood 1-2
  ...time-target allocation...
}
```

On mood 1 (cap=4, habit ceiling = 2 after CAP-01 fix), after habits place 2 chunks, 2 slots remain. No mechanism fills them. The day ends with 2 work chunks when it could have 4.

**Fix:** Lift the `if (!isLowMood)` gate on Step 4 (time-target allocation). Instead, time-target demand on low-mood days is capped at 1 chunk per goal (not the full `_demandForTimeTarget` which can return up to 4). This lets regular-time goals fill open capacity without overwhelming a low-mood day.

```dart
// Replace: if (!isLowMood) {
// With: always run Step 4, but limit demand on low-mood days

final int maxDemandPerGoal = isLowMood ? 1 : _demandForTimeTarget(goal, completionLogs, date);
// (or define inside the loop)

for (final goal in timeTargetGoals) {
  if (discretionaryCount >= cap) break;
  final demand = isLowMood ? 1 : _demandForTimeTarget(goal, completionLogs, date);
  for (int i = 0; i < demand; i++) {
    if (discretionaryCount >= cap) break;
    workChunks.add(ScheduledChunk(...));
    discretionaryCount++;
  }
}
```

This satisfies "on a day with open capacity after required work and habits, regular-time goals appear in the schedule" (SC4) while respecting the low-mood spirit: each regular-time goal gets 1 chunk (not 4), and the demand limit naturally distributes across multiple goals.

**Test scenario:** mood=1, cap=4, 2 daily habits (normal priority → 1 chunk each with CAP-01 fix), 2 time-target goals with open hours. After the fix, 2 time-target chunks fill the remaining 2 slots.

---

### FILL-02: Single Regular-Time Goal Can Swallow All Open Capacity

**Current behavior (the bug):**

```dart
// Step 4 greedy loop (schedule_generator.dart lines 340–354):
for (final goal in timeTargetGoals) {
  if (discretionaryCount >= cap) break;
  final demand = _demandForTimeTarget(goal, completionLogs, date);
  for (int i = 0; i < demand; i++) {         // ← fills goal fully before moving on
    if (discretionaryCount >= cap) break;
    workChunks.add(...);
    discretionaryCount++;
  }
}
```

If `demand` for the first goal is 4 and the open capacity is 4, the first goal fills all slots. The second goal receives 0 chunks.

**Fix:** Replace the fully-greedy inner loop with a round-robin / proportional pass. Distribute one chunk per goal per round until cap is full:

```dart
// After sorting timeTargetGoals by composite score:
bool anyPlaced = true;
final placedCountPerGoal = <String, int>{};  // goalId → chunks placed this day

while (anyPlaced && discretionaryCount < cap) {
  anyPlaced = false;
  for (final goal in timeTargetGoals) {
    if (discretionaryCount >= cap) break;
    final placed = placedCountPerGoal[goal.id] ?? 0;
    final demand = isLowMood ? 1 : _demandForTimeTarget(goal, completionLogs, date);
    if (placed >= demand) continue;  // goal's demand satisfied
    workChunks.add(ScheduledChunk(...));
    discretionaryCount++;
    placedCountPerGoal[goal.id] = placed + 1;
    anyPlaced = true;
  }
}
```

The round-robin naturally distributes slots by priority (higher-priority goals appear first in the sorted list, so when cap is tight the first round favors them) while ensuring no single goal monopolizes the open day.

**FILL-02 + FILL-01 interact:** The same round-robin loop serves both requirements — the `isLowMood ? 1` demand cap implements FILL-01's "1 chunk per low-mood time-target goal," and the round-robin implements FILL-02's "no single goal claims the entire open day."

**Test scenario (SC5):** mood=3, 3 time-target goals with equal priority and equal open hours, cap has 6 open slots. Each goal gets 2 chunks (round-robin distributes evenly). Without fix, goal 1 gets 4 chunks (full demand), goal 2 gets 2 chunks, goal 3 gets 0.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| New collection type for round-robin | Custom queue/ring | Dart `List` + `Map<String, int>` counter (see FILL-02 pattern) |
| Per-type cap arithmetic | Float-based reservation | `int` ceiling division: `(cap / 2).ceil()` |
| Streak computation | Custom date math | Existing `ScheduleGeneratorService.computeStreak()` — already correct, reuse at generation time |

---

## Common Pitfalls

### Pitfall 1: Cap Ceiling Interaction with Deferred Carry-In (CLOSE-02)

**What goes wrong:** After the CAP-01 habit ceiling is applied, the deferred carry-in step (CLOSE-02, lines 365–393) injects additional chunks for deferred goals without checking the type-specific ceiling. A deferred habit re-injected after the ceiling could push habit count past the ceiling.

**How to avoid:** CLOSE-02 inject checks `discretionaryCount >= cap` but not `habitCount >= habitCeiling`. Either: (a) apply the ceiling check inside the CLOSE-02 loop for habit-type goals, or (b) accept that deferred carry-in bypasses the type ceiling as an intentional override (the user explicitly deferred it — re-entry should be honored). Option (b) is simpler and probably correct.

**Recommendation:** Accept deferred carry-in bypass (it's one slot per deferred goal and already cap-checked). Document in code comment.

---

### Pitfall 2: Round-Robin Order Stability

**What goes wrong:** The round-robin (FILL-02) iterates `timeTargetGoals` in priority-sorted order each round. If priority weights are equal (e.g., all goals at 0.5), the sort is not stable across rounds, and goals in the middle of the list could be systematically under-served.

**How to avoid:** Dart's `List.sort()` is not guaranteed stable. Use `sortBy` idiom with a stable secondary key (e.g., `goal.id` for tiebreaking):

```dart
timeTargetGoals.sort((a, b) {
  final scoreA = score(a);
  final scoreB = score(b);
  final cmp = scoreB.compareTo(scoreA);
  if (cmp != 0) return cmp;
  return a.id.compareTo(b.id); // stable secondary key
});
```

---

### Pitfall 3: Streak Write-Back at Generation Time Calling goalRepo.save() for Many Goals

**What goes wrong:** `generateToday()` already iterates over all active goals for log fetching. Adding a `goalRepo.save()` per habit-type goal creates N additional async writes at generation time. On a device with slow Hive I/O (older Android), this could delay schedule display.

**How to avoid:** Only save when the computed streak differs from the stored value (`if (goal.streakCount != computed) { goal.streakCount = computed; await _goalRepo.save(goal); }`). Most days this is a no-op. The existing mark-time write-back already handles the common case; generation-time write-back is for day-boundary divergence only.

---

### Pitfall 4: Low-Mood FILL-01 Conflicts with "Low Days Stay Required + Habits Only" Scope Decision

**What goes wrong:** SEED-001 #2 ("low-mood restorative floor") was explicitly deferred by the owner: "low days stay required + habits only." FILL-01 adds time-target goals on low-mood days, which may appear to contradict the deferred decision.

**Clarification from REQUIREMENTS.md:** FILL-01 is explicitly listed as a Phase 15 requirement. The deferred item (SEED-001 #2) was specifically about a "restorative floor" concept; FILL-01 is about filling genuinely open capacity after the type-specific reservation. These are compatible if phrased as: "after habits fill their ceiling, open slots are filled with regular-time goals, capped at 1 chunk each on low-mood days." This is capacity filling, not a restorative floor.

**How to avoid:** The implementation comment should reference FILL-01 and note that the 1-chunk-per-goal low-mood limit honors the spirit of lighter days (no multi-chunk regular-time pileup) while filling genuinely open capacity.

---

### Pitfall 5: Test Fixture Reuse Leading to Brittle Tests

**What goes wrong:** The existing test suite uses concrete `DateTime(2026, 3, 23)` Monday dates. New tests that add habit priority counts interact with `frequencyPerWeek` and due-weekday logic. A test using Saturday accidentally gets 0 habit chunks and misreads the priority result.

**How to avoid:** Always use `monday = DateTime(2026, 3, 23)` (already established in `schedule_generator_test.dart`) for tests involving habits. Set `frequencyPerWeek = 7` (daily) in test habits unless testing due-weekday behavior specifically. The existing `makeHabit()` helper defaults to `frequencyPerWeek = null` which the engine treats as 7 — this is correct.

---

## Code Examples

### Existing Pattern: Habit Allocation (current, to be modified for CAP-01 + PRIORITY-02)

```dart
// schedule_generator.dart lines 253–278 [ASSUMED: line numbers approximate]
final habitGoals =
    activeGoals.where((g) => g.goalType == GoalType.habit).toList()..sort(
      (a, b) =>
          (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5),
    );

for (final goal in habitGoals) {
  if (discretionaryCount >= cap) break;
  ...
  workChunks.add(ScheduledChunk(...));
  discretionaryCount++;
}
```

### Pattern to Introduce: Per-Type Ceiling + Multi-Chunk Habit Demand

```dart
// Compute habit ceiling — habits may not consume more than ceil(cap/2) slots.
// This ensures outcomes and time-targets receive capacity on low-mood days (CAP-01).
final int habitCeiling = (cap / 2).ceil();
int habitCount = 0;

// habitDemand: high-priority habits get 2 chunks on good-mood days (PRIORITY-02).
int habitDemand(Goal g) =>
    (!isLowMood && (g.priorityWeight ?? 0.5) >= 0.75) ? 2 : 1;

for (final goal in habitGoals) {
  if (discretionaryCount >= cap) break;
  if (habitCount >= habitCeiling) break;
  final demand = habitDemand(goal);
  for (int i = 0; i < demand; i++) {
    if (discretionaryCount >= cap) break;
    if (habitCount >= habitCeiling) break;
    workChunks.add(ScheduledChunk(
      chunkTypeIndex: ChunkType.work.index,
      goalId: goal.id,
      durationMinutes: 25,
      rationale: _habitRationale(goal, streak),
    ));
    discretionaryCount++;
    habitCount++;
  }
}
```

### Pattern to Introduce: Round-Robin Time-Target Allocation (FILL-01 + FILL-02)

```dart
// Step 4: Time-target goals — runs always (mood 1-2 demand capped at 1).
// Round-robin ensures no single goal monopolizes open capacity (FILL-02).
// On low-mood days, each goal gets at most 1 chunk (FILL-01).
double score(Goal g) =>
    _remainingHours(g, completionLogs, date) * (g.priorityWeight ?? 0.5);
final timeTargetGoals =
    activeGoals.where((g) => g.goalType == GoalType.timeTarget).toList()
      ..sort((a, b) {
        final cmp = score(b).compareTo(score(a));
        return cmp != 0 ? cmp : a.id.compareTo(b.id); // stable secondary key
      });

final placedCountPerGoal = <String, int>{};
bool anyPlaced = true;
while (anyPlaced && discretionaryCount < cap) {
  anyPlaced = false;
  for (final goal in timeTargetGoals) {
    if (discretionaryCount >= cap) break;
    final placed = placedCountPerGoal[goal.id] ?? 0;
    final demand = isLowMood
        ? 1
        : _demandForTimeTarget(goal, completionLogs, date);
    if (demand <= 0 || placed >= demand) continue;
    workChunks.add(ScheduledChunk(
      chunkTypeIndex: ChunkType.work.index,
      goalId: goal.id,
      durationMinutes: 25,
      rationale: _timeTargetRationale(goal, completionLogs, date),
    ));
    discretionaryCount++;
    placedCountPerGoal[goal.id] = placed + 1;
    anyPlaced = true;
  }
}
```

### Pattern to Introduce: Generation-Time Streak Sync (STREAK-01, in notifier)

```dart
// In ScheduleNotifier.generateToday(), after _generator.generate() returns:
// Sync streakCount for all active habit goals so the displayed value matches
// computeStreak() at generation time (STREAK-01 divergence fix).
for (final goal in goals.where((g) => !g.isArchived && g.goalType == GoalType.habit)) {
  final due = ScheduleGeneratorService.computeDueWeekdays(goal.frequencyPerWeek ?? 7);
  final logsForGoal = allLogs.where((l) => l.goalId == goal.id).toList();
  final computed = ScheduleGeneratorService.computeStreak(
    goal.id, due, logsForGoal, today: date,
  );
  if (goal.streakCount != computed) {
    goal.streakCount = computed;
    await _goalRepo.save(goal);
  }
}
```

---

## Existing Test Patterns (for New Test Authoring)

The engine test file (`test/services/schedule_generator_test.dart`) establishes these conventions:

1. **Test date:** `monday = DateTime(2026, 3, 23)` — always use this constant for habit-involving tests.
2. **Goal factories:** `makeHabit()`, `makeOutcome()`, `makeTimeTarget()` — take named params; use `priorityWeight:` explicitly in priority tests.
3. **Count helper:** `workChunksOf(result)` counts only `ChunkType.work` chunks.
4. **Log factory:** `makeLog(goalId:, dateYmd:, event:)` — for streak and demand tests.
5. **Assertion style:** `expect(count, greaterThan(other))` for "gets more than" comparisons; always include a `reason:` string.
6. **Section separator comments:** Tests are delimited by `// ---` banners with test name and requirement ID.
7. **Test naming convention:** Requirement-ID prefix where applicable (e.g., `'CAP-01: habit ceiling prevents monopolization'`).

**Test infrastructure:** `ScheduleGeneratorService` is pure Dart — no Flutter test binding needed. Tests use `test()` directly, not `testWidgets()`. No fake repos required for engine tests; only for notifier-level tests.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | none — `flutter test` discovers tests by convention |
| Quick run command | `/home/dan/development/flutter/bin/flutter test test/services/schedule_generator_test.dart` |
| Full suite command | `/home/dan/development/flutter/bin/flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAP-01 | mood=1, 4 daily habits + 1 outcome → outcome receives ≥1 chunk | unit | `flutter test test/services/schedule_generator_test.dart --name CAP-01` | ❌ Wave 0 |
| CAP-01 | mood=1, total chunks do not exceed cap | unit | same | ❌ Wave 0 |
| STREAK-01 | After generateToday(), goal.streakCount matches computeStreak() | unit (notifier) | `flutter test test/providers/schedule_notifier_engine_test.dart --name STREAK-01` | ❌ Wave 0 |
| PRIORITY-02 (habit) | High-priority habit (0.75) gets 2 chunks; normal (0.5) gets 1, mood=3 | unit | `flutter test test/services/schedule_generator_test.dart --name PRIORITY-02` | ❌ Wave 0 |
| PRIORITY-02 (outcome) | High-priority outcome gets 2 chunks; normal gets 1, mood=3 | unit | same | ❌ Wave 0 |
| FILL-01 | mood=1, open capacity after habits → time-target goals appear | unit | `flutter test test/services/schedule_generator_test.dart --name FILL-01` | ❌ Wave 0 |
| FILL-02 | mood=3, 3 time-target goals, limited cap → no single goal gets all open chunks | unit | `flutter test test/services/schedule_generator_test.dart --name FILL-02` | ❌ Wave 0 |

### Wave 0 Gaps

- [ ] `test/services/schedule_generator_test.dart` — add CAP-01, PRIORITY-02, FILL-01, FILL-02 test cases
- [ ] `test/providers/schedule_notifier_engine_test.dart` — add STREAK-01 generation-time sync test

*(Existing test infrastructure covers all other engine behavior — 20+ tests already pass)*

### Sampling Rate

- **Per task commit:** `flutter test test/services/schedule_generator_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

---

## Security Domain

This phase has no security surface. Changes are pure scheduling logic in an offline personal app. No network calls, no auth, no user input parsing beyond what Hive already persists. ASVS categories: N/A.

---

## Package Legitimacy Audit

No external packages are added in this phase. All changes are to existing Dart files.

---

## Runtime State Inventory

This phase is a behavior fix phase, not a rename/migration. No stored data, service configs, OS registrations, secrets, or build artifacts embed engine algorithm behavior. The only persisted state touched is `goal.streakCount` (HiveField 11), which is a numeric field already present and writable — no migration required.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|---------|
| Flutter / Dart SDK | All compilation and tests | ✓ | `/home/dan/development/flutter/bin/flutter` | — |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single shared `discretionaryCount` against whole cap | Same (to be fixed by CAP-01) | Phase 15 | Multi-type fairness on scarce days |
| `if (!isLowMood)` gate on time-targets | Lift gate, use demand=1 on low-mood (FILL-01) | Phase 15 | Low days get filled |
| 1 chunk per habit/outcome regardless of priority | Demand function gated on priorityWeight (PRIORITY-02) | Phase 15 | Priority affects count, not just order |
| Greedy inner loop fills one goal fully before next | Round-robin across sorted goals (FILL-02) | Phase 15 | Open capacity distributed fairly |
| Streak written at mark time only | Also written at generation time (STREAK-01) | Phase 15 | UI always shows truthful streak |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Habit ceiling of `(cap / 2).ceil()` is the right fraction for CAP-01 | CAP-01 fix | Too low: habits lose slots they deserve. Too high: outcomes still starved. Tune by dogfooding. |
| A2 | High-priority habits get 2 chunks (not 3 or more) on mood 3–5 (PRIORITY-02) | PRIORITY-02 fix | 2 may feel like too few to show "obviously more." Could go to 3 or use `ceil(demand × priorityBoost)`. |
| A3 | FILL-01 demand cap of 1 chunk/goal on low-mood days is appropriate | FILL-01 fix | 1 may be too few (user wants 2 hrs of family time even on a low day). Adjust after dogfooding. |
| A4 | Deferred carry-in (CLOSE-02) intentionally bypasses the habit ceiling (Pitfall 1) | Pitfall 1 | If carry-in causes habit monopolization in edge cases, add ceiling check to CLOSE-02 loop. |

---

## Open Questions (RESOLVED)

1. **Outcome multi-chunk demand (PRIORITY-02)**
   - What we know: success criterion says "raising an outcome's priority increases its chunk allocation relative to a lower-priority outcome."
   - What's unclear: outcomes currently get 1 chunk with no concept of "demand" (unlike time-targets which have `_demandForTimeTarget`). Should high-priority outcomes get a flat +1 chunk, or should outcomes have a demand model based on deadline proximity?
   - RESOLVED: flat +1 for high priority (same as habits) — keeps it simple and observable. A deadline-aware demand model is over-engineering for Phase 15.

2. **Interaction: CAP-01 ceiling + PRIORITY-02 double-chunks**
   - What we know: habit ceiling is `(cap/2).ceil()`. A high-priority habit takes 2 slots. With cap=4 and ceiling=2, two high-priority habits would hit the ceiling immediately, leaving 0 slots for more habits.
   - What's unclear: is it acceptable that only 1 high-priority habit fits in a ceiling=2 slot budget?
   - RESOLVED: yes, acceptable. The ceiling exists precisely to ensure outcomes get slots. A user with 3 high-priority habits on a mood=1 day should expect a constrained schedule.

---

## Sources

### Primary (HIGH confidence — direct codebase inspection)
- `lib/services/schedule_generator.dart` — full read; allocation algorithm, cap logic, streak, demand
- `lib/providers/schedule_notifier.dart` — full read; mark-time write-back, generation call
- `lib/data/models/goal.dart` — full read; `streakCount` field location
- `lib/screens/goals/widgets/goal_card.dart` — full read; streak display path
- `test/services/schedule_generator_test.dart` — full read; existing test patterns and conventions
- `test/providers/schedule_notifier_engine_test.dart` — full read; notifier-level test infrastructure

### Secondary (MEDIUM confidence)
- `.planning/seeds/SEED-001-engine-product-critique.md` — original bug descriptions with file:line citations
- `.planning/seeds/SEED-003-v1.2-adversarial-gaps.md` — PRIORITY-02 root cause analysis
- `.planning/REQUIREMENTS.md` — formal requirement statements

---

## Metadata

**Confidence breakdown:**
- CAP-01 fix: HIGH — root cause confirmed in source, fix is a straightforward ceiling check
- STREAK-01 fix: HIGH — divergence path confirmed; fix is adding write-back to existing generate path
- PRIORITY-02 fix: HIGH — 1-chunk-per-goal loop confirmed; fix is adding demand function
- FILL-01 fix: HIGH — hard `!isLowMood` gate confirmed at line 332; fix is lifting the gate
- FILL-02 fix: HIGH — greedy inner loop confirmed; fix is round-robin replacement

**Research date:** 2026-06-13
**Valid until:** Stable (pure logic changes; no external dependencies)
