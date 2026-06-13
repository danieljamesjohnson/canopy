# Phase 15: Engine Honesty - Pattern Map

**Mapped:** 2026-06-13
**Files analyzed:** 4 (2 modified, 1 extended, 1 new)
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/services/schedule_generator.dart` | service (pure Dart, stateless) | transform (batch allocation) | self — modify in-place; existing Steps 2–4 are the analog | exact |
| `lib/providers/schedule_notifier.dart` | provider / notifier | request-response + async write-back | self — modify `generateToday()` and the existing streak write-back in `markComplete` | exact |
| `test/services/schedule_generator_test.dart` | unit test | N/A | self — existing test file; new tests follow established conventions | exact |
| `test/providers/schedule_notifier_engine_test.dart` | integration test (notifier-level) | N/A | self — existing notifier test file; new STREAK-01 test follows same fake-repo pattern | exact |

---

## Pattern Assignments

---

### `lib/services/schedule_generator.dart` — Steps 2, 3, 4 (CAP-01, PRIORITY-02, FILL-01, FILL-02)

**Analog:** Same file, existing Step 2 (habits) and Step 4 (time-targets).

#### Current Step 2 loop — the section to replace (lines 252–278)

```dart
final habitGoals =
    activeGoals.where((g) => g.goalType == GoalType.habit).toList()..sort(
      (a, b) =>
          (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5),
    );

for (final goal in habitGoals) {
  if (discretionaryCount >= cap) break;
  final effectiveFreq = goal.frequencyPerWeek ?? 7;
  final dueWeekdays = computeDueWeekdays(effectiveFreq);
  if (!dueWeekdays.contains(date.weekday)) continue;
  final streak = computeStreak(
    goal.id,
    dueWeekdays,
    completionLogs,
    today: date,
  );
  workChunks.add(
    ScheduledChunk(
      chunkTypeIndex: ChunkType.work.index,
      goalId: goal.id,
      durationMinutes: 25,
      rationale: _habitRationale(goal, streak),
    ),
  );
  discretionaryCount++;
}
```

**CAP-01 + PRIORITY-02 replacement pattern for Step 2:**

```dart
// CAP-01: habits may not consume more than ceil(cap/2) slots so outcomes and
// time-targets always receive capacity on low-mood days.
final int habitCeiling = (cap / 2).ceil();
int habitCount = 0;

// PRIORITY-02: high-priority habits get 2 chunks on good-mood days.
// On low-mood days all habits get 1 chunk regardless of priority.
int habitDemand(Goal g) =>
    (!isLowMood && (g.priorityWeight ?? 0.5) >= 0.75) ? 2 : 1;

for (final goal in habitGoals) {
  if (discretionaryCount >= cap) break;
  if (habitCount >= habitCeiling) break;  // CAP-01 type ceiling
  final effectiveFreq = goal.frequencyPerWeek ?? 7;
  final dueWeekdays = computeDueWeekdays(effectiveFreq);
  if (!dueWeekdays.contains(date.weekday)) continue;
  final streak = computeStreak(goal.id, dueWeekdays, completionLogs, today: date);
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

#### Current Step 3 loop — outcome section to extend for PRIORITY-02 (lines 286–324)

Existing single-chunk-per-outcome pattern (lines 315–324):

```dart
workChunks.add(
  ScheduledChunk(
    chunkTypeIndex: ChunkType.work.index,
    goalId: goal.id,
    durationMinutes: 25,
    rationale: _outcomeRationale(goal, date),
  ),
);
discretionaryCount++;
```

**PRIORITY-02 replacement — multi-chunk demand for high-priority outcomes:**

```dart
// PRIORITY-02: high-priority outcomes get 2 chunks on good-mood days.
final outcomeDemand = (!isLowMood && (goal.priorityWeight ?? 0.5) >= 0.75) ? 2 : 1;
for (int i = 0; i < outcomeDemand; i++) {
  if (discretionaryCount >= cap) break;
  workChunks.add(ScheduledChunk(
    chunkTypeIndex: ChunkType.work.index,
    goalId: goal.id,
    durationMinutes: 25,
    rationale: _outcomeRationale(goal, date),
  ));
  discretionaryCount++;
}
```

#### Current Step 4 block — the section to replace (lines 332–355)

```dart
if (!isLowMood) {
  double score(Goal g) =>
      _remainingHours(g, completionLogs, date) * (g.priorityWeight ?? 0.5);
  final timeTargetGoals =
      activeGoals.where((g) => g.goalType == GoalType.timeTarget).toList()
        ..sort((a, b) => score(b).compareTo(score(a)));

  for (final goal in timeTargetGoals) {
    if (discretionaryCount >= cap) break;
    final demand = _demandForTimeTarget(goal, completionLogs, date);
    for (int i = 0; i < demand; i++) {
      if (discretionaryCount >= cap) break;
      workChunks.add(
        ScheduledChunk(
          chunkTypeIndex: ChunkType.work.index,
          goalId: goal.id,
          durationMinutes: 25,
          rationale: _timeTargetRationale(goal, completionLogs, date),
        ),
      );
      discretionaryCount++;
    }
  }
}
```

**FILL-01 + FILL-02 replacement — always run Step 4, round-robin, low-mood demand cap:**

```dart
// Step 4: Time-target goals.
// FILL-01: runs always (not gated on !isLowMood); on low-mood days demand is
//          capped at 1 chunk per goal so the day stays light.
// FILL-02: round-robin across sorted goals so no single goal monopolizes
//          the remaining open capacity.
double score(Goal g) =>
    _remainingHours(g, completionLogs, date) * (g.priorityWeight ?? 0.5);
final timeTargetGoals =
    activeGoals.where((g) => g.goalType == GoalType.timeTarget).toList()
      ..sort((a, b) {
        final cmp = score(b).compareTo(score(a));
        return cmp != 0 ? cmp : a.id.compareTo(b.id); // Pitfall 2: stable secondary key
      });

// FILL-02: one chunk per goal per pass until cap is full or demand is satisfied.
final placedCountPerGoal = <String, int>{};
bool anyPlaced = true;
while (anyPlaced && discretionaryCount < cap) {
  anyPlaced = false;
  for (final goal in timeTargetGoals) {
    if (discretionaryCount >= cap) break;
    final placed = placedCountPerGoal[goal.id] ?? 0;
    // FILL-01: cap demand at 1 per goal on low-mood days.
    final demand = isLowMood ? 1 : _demandForTimeTarget(goal, completionLogs, date);
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

---

### `lib/providers/schedule_notifier.dart` — `generateToday()` (STREAK-01)

**Analog:** Existing streak write-back in `markComplete` (lines 191–213). The generation-time sync follows the exact same pattern — `getById` → `computeDueWeekdays` → `computeStreak` → `save` — but iterates all active habit goals instead of one chunk's goal.

**Existing mark-time write-back pattern (lines 191–213) — copy this structure:**

```dart
if (chunk.goalId != null && chunk.goalId!.isNotEmpty) {
  try {
    final goal = await _goalRepo.getById(chunk.goalId!);
    if (goal != null && goal.goalType == GoalType.habit) {
      final due = ScheduleGeneratorService.computeDueWeekdays(
        goal.frequencyPerWeek ?? 7,
      );
      final updatedLogs = await _logRepo.getByGoalId(goal.id);
      goal.streakCount = ScheduleGeneratorService.computeStreak(
        goal.id,
        due,
        updatedLogs,
        today: DateTime.parse(_todaySchedule!.dateYmd),
      );
      await _goalRepo.save(goal);
    }
  } catch (_) {
    // Streak is stale until next generation — acceptable.
  }
}
```

**STREAK-01 generation-time sync to insert after `_generator.generate()` returns (lines 130–141), before `_repo.save(schedule)`:**

```dart
// STREAK-01: sync streakCount for all active habit goals at generation time.
// The engine computes the authoritative streak internally but does not write
// it back to goal.streakCount — the displayed value lags until a mark action.
// This write-back closes that divergence window.
// Only saves when the computed value differs (Pitfall 3: avoid N saves per day).
for (final goal in goals.where((g) => !g.isArchived && g.goalType == GoalType.habit)) {
  try {
    final due = ScheduleGeneratorService.computeDueWeekdays(goal.frequencyPerWeek ?? 7);
    final logsForGoal = allLogs.where((l) => l.goalId == goal.id).toList();
    final computed = ScheduleGeneratorService.computeStreak(
      goal.id, due, logsForGoal, today: date,
    );
    if (goal.streakCount != computed) {
      goal.streakCount = computed;
      await _goalRepo.save(goal);
    }
  } catch (_) {
    // Streak staleness is tolerable; generation must not be blocked.
  }
}
```

Note: `allLogs` is already in scope at this point (assembled at lines 111–114). `date` is also in scope (line 104). No new variables needed.

---

### `test/services/schedule_generator_test.dart` — New tests (CAP-01, PRIORITY-02, FILL-01, FILL-02)

**Analog:** All existing tests in the same file. New tests follow every established convention below verbatim.

#### Fixture pattern (lines 8–76) — reuse unchanged

```dart
// Imports (lines 1–6):
import 'package:flutter_test/flutter_test.dart';
import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/services/schedule_generator.dart';

// Date constants (lines 12–14) — always use monday for habit tests:
final monday = DateTime(2026, 3, 23);  // weekday == 1

// setUp (lines 16–18):
setUp(() { sut = ScheduleGeneratorService(); });

// Goal factories (lines 24–73) — use named params, set priorityWeight: explicitly:
Goal makeHabit({String name = 'Habit goal', double? priorityWeight}) => Goal(
  name: name,
  goalTypeIndex: GoalType.habit.index,
  priorityWeight: priorityWeight,
);
Goal makeOutcome({String name = 'Outcome goal', DateTime? deadline, double? priorityWeight}) => ...;
Goal makeTimeTarget({String name = 'Time-target goal', double? weeklyHourBudget, double? priorityWeight}) => ...;
CompletionLog makeLog({required String goalId, required String dateYmd, CompletionEvent event = CompletionEvent.completed}) => ...;

// Count helper (line 75–76):
int workChunksOf(List<ScheduledChunk> result) =>
    result.where((c) => c.chunkType == ChunkType.work).length;
```

#### New test structure to follow (use `// ---` banner + req-ID prefix in name):

```dart
// ---------------------------------------------------------------------------
// CAP-01: habit ceiling prevents monopolization on low-mood days
// ---------------------------------------------------------------------------
test('CAP-01: mood=1, 4 daily habits + 1 outcome → outcome receives ≥1 chunk', () {
  final habits = List.generate(4, (i) => makeHabit(name: 'Habit $i'));
  final outcome = makeOutcome(name: 'Outcome');
  final result = sut.generate(
    goals: [...habits, outcome],
    blocks: [],
    moodIndex: 1,
    date: monday,
    completionLogs: [],
  );
  final outcomeChunks = result
      .where((c) => c.chunkType == ChunkType.work && c.goalId == outcome.id)
      .length;
  expect(outcomeChunks, greaterThanOrEqualTo(1),
      reason: 'CAP-01: outcome must receive capacity even when 4 habits compete');
});

test('CAP-01: mood=1 total work chunks do not exceed cap', () {
  final goals = List.generate(4, (i) => makeHabit(name: 'Habit $i'))
    ..add(makeOutcome());
  final result = sut.generate(goals: goals, blocks: [], moodIndex: 1, date: monday);
  expect(workChunksOf(result), lessThanOrEqualTo(4),
      reason: 'CAP-01: mood=1 cap=4; total work chunks must not exceed cap');
});

// ---------------------------------------------------------------------------
// PRIORITY-02: priority changes chunk count, not just sort order
// ---------------------------------------------------------------------------
test('PRIORITY-02: high-priority habit (0.75) gets 2 chunks; normal (0.5) gets 1 at mood=3', () {
  final highHabit = makeHabit(name: 'High', priorityWeight: 0.75)
    ..frequencyPerWeek = 7;
  final normalHabit = makeHabit(name: 'Normal', priorityWeight: 0.5)
    ..frequencyPerWeek = 7;
  final result = sut.generate(
    goals: [normalHabit, highHabit],
    blocks: [],
    moodIndex: 3,
    date: monday,
    completionLogs: [],
    lighterDay: false,
  );
  final highCount = result.where((c) => c.chunkType == ChunkType.work && c.goalId == highHabit.id).length;
  final normalCount = result.where((c) => c.chunkType == ChunkType.work && c.goalId == normalHabit.id).length;
  expect(highCount, greaterThan(normalCount),
      reason: 'PRIORITY-02: high-priority habit must receive more chunks than normal-priority habit');
});

// ---------------------------------------------------------------------------
// FILL-01: time-target goals appear on low-mood days with open capacity
// ---------------------------------------------------------------------------
test('FILL-01: mood=1, open capacity after habits → time-target goals appear in schedule', () {
  // With CAP-01 fix: 2 daily habits fill ceil(4/2)=2 slots; 2 slots remain.
  // A time-target goal must fill those remaining slots.
  final habits = List.generate(2, (i) => makeHabit(name: 'Habit $i'));
  final tt = makeTimeTarget(name: 'Regular-time', weeklyHourBudget: 5);
  final result = sut.generate(
    goals: [...habits, tt],
    blocks: [],
    moodIndex: 1,
    date: monday,
    completionLogs: [],
  );
  final ttChunks = result
      .where((c) => c.chunkType == ChunkType.work && c.goalId == tt.id)
      .length;
  expect(ttChunks, greaterThanOrEqualTo(1),
      reason: 'FILL-01: regular-time goal must appear on a low-mood day with open capacity');
});

// ---------------------------------------------------------------------------
// FILL-02: open capacity distributed across multiple time-target goals
// ---------------------------------------------------------------------------
test('FILL-02: 3 time-target goals with limited cap — no single goal swallows all open slots', () {
  // mood=3, lighterDay=false → cap=8. No habits. 3 goals each with demand ≥ 4.
  // With round-robin: each goal gets ~2-3 chunks. Without: goal 1 gets 4, goal 3 gets 0.
  final goals = [
    makeTimeTarget(name: 'G1', weeklyHourBudget: 5, priorityWeight: 0.5),
    makeTimeTarget(name: 'G2', weeklyHourBudget: 5, priorityWeight: 0.5),
    makeTimeTarget(name: 'G3', weeklyHourBudget: 5, priorityWeight: 0.5),
  ];
  final result = sut.generate(
    goals: goals,
    blocks: [],
    moodIndex: 3,
    date: monday,
    completionLogs: [],
    lighterDay: false,
  );
  final g1 = result.where((c) => c.chunkType == ChunkType.work && c.goalId == goals[0].id).length;
  final g3 = result.where((c) => c.chunkType == ChunkType.work && c.goalId == goals[2].id).length;
  expect(g3, greaterThanOrEqualTo(1),
      reason: 'FILL-02: last goal in priority list must receive at least 1 chunk (no monopoly)');
  expect(g1, lessThanOrEqualTo(workChunksOf(result) - 1),
      reason: 'FILL-02: first goal must not swallow all capacity');
});
```

---

### `test/providers/schedule_notifier_engine_test.dart` — STREAK-01 test

**Analog:** Same file, existing `ENGINE-03b` group (lines 192–347). New STREAK-01 test goes in a new group following the identical fake-repo wiring pattern.

#### Fake-repo pattern to copy (lines 24–82):

```dart
// Same _InMemoryScheduleRepository and _InMemoryGoalRepository fakes already
// defined at top of file — do NOT redefine. Import InMemoryCompletionLogRepository.

// Test date pattern (line 94):
final testDate = DateTime(2026, 6, 8); // Monday
```

#### New STREAK-01 test group pattern:

```dart
// ---------------------------------------------------------------------------
// STREAK-01: generation-time streak sync
// ---------------------------------------------------------------------------
group('STREAK-01: generateToday() syncs goal.streakCount', () {
  test(
    'After generateToday(), habit streakCount matches computeStreak — not stale default',
    () async {
      // Habit with 2 prior completed due-days. goal.streakCount starts at 0 (default).
      // After generateToday(), goal.streakCount must equal 2 (the computed value),
      // not remain at 0. This exercises the generation-time write-back path,
      // not the mark-time path.
      final goal = Goal(
        id: 'streak-sync-goal',
        name: 'Run',
        goalTypeIndex: GoalType.habit.index,
        frequencyPerWeek: 3,   // due Mon/Wed/Fri
        streakCount: 0,        // stale default — must be updated at generation
      );

      final logRepo = InMemoryCompletionLogRepository();
      // Two consecutive prior due-day completions before testDate (Mon 2026-06-08).
      await logRepo.append(CompletionLog(
        chunkId: 'c-wed',
        goalId: goal.id,
        dateYmd: '2026-06-03', // Wed
        eventIndex: CompletionEvent.completed.index,
      ));
      await logRepo.append(CompletionLog(
        chunkId: 'c-fri',
        goalId: goal.id,
        dateYmd: '2026-06-05', // Fri
        eventIndex: CompletionEvent.completed.index,
      ));

      final goalRepo = _InMemoryGoalRepository([goal]);
      final scheduleRepo = _InMemoryScheduleRepository();

      final notifier = ScheduleNotifier(
        now: () => testDate,
        repo: scheduleRepo,
        logRepo: logRepo,
        goalRepo: goalRepo,
      );

      await notifier.generateToday(
        moodIndex: 3,
        goals: [goal],
        blocks: [],
      );

      // goalRepo.saved must contain the goal with streakCount == 2.
      expect(goalRepo.saved, isNotEmpty,
          reason: 'STREAK-01: GoalRepository.save must be called during generateToday for habit goals');
      final savedGoal = goalRepo.saved.last;
      expect(savedGoal.streakCount, equals(2),
          reason: 'STREAK-01: streakCount must equal 2 (two prior due-day completions) after generateToday, not the stale 0 default');
    },
  );
});
```

---

## Shared Patterns

### ScheduledChunk construction
**Source:** `lib/services/schedule_generator.dart` lines 269–276 (habit chunk) and 315–324 (outcome chunk)
**Apply to:** All new chunk-adding code in Steps 2–4
```dart
ScheduledChunk(
  chunkTypeIndex: ChunkType.work.index,
  goalId: goal.id,
  durationMinutes: 25,
  rationale: _someRationale(goal, ...),
)
```
Always use `ChunkType.work.index`, always `durationMinutes: 25`, always provide a `rationale:`.

### Streak write-back try/catch wrapper
**Source:** `lib/providers/schedule_notifier.dart` lines 191–213 (markComplete), 262–279 (markSkipped), 333–353 (markDeferred)
**Apply to:** STREAK-01 generation-time write-back loop
```dart
try {
  // computeDueWeekdays + computeStreak + goalRepo.save
} catch (_) {
  // Streak staleness is tolerable; do not rethrow.
}
```
Inner catch swallows the error. The outer generation flow must not be interrupted by a streak save failure.

### Test assertion style with `reason:`
**Source:** `test/services/schedule_generator_test.dart` throughout
**Apply to:** All new Phase 15 tests
```dart
expect(value, matcher, reason: 'REQ-ID: human-readable explanation of what this proves');
```
Every `expect` in new tests must include a `reason:` string prefixed with the requirement ID.

### Test section banner comment
**Source:** `test/services/schedule_generator_test.dart` lines 82–83, 96–97, etc.
**Apply to:** Each new test group / standalone test in both test files
```dart
// ---------------------------------------------------------------------------
// REQ-ID: short description of what this group covers
// ---------------------------------------------------------------------------
```

---

## No Analog Found

None. All files being modified already exist and are the direct analogs for the patterns they establish.

---

## Metadata

**Analog search scope:** `lib/services/`, `lib/providers/`, `test/services/`, `test/providers/`
**Files read:** `lib/services/schedule_generator.dart` (564 lines), `lib/providers/schedule_notifier.dart` (368 lines), `test/services/schedule_generator_test.dart` (1200 lines), `test/providers/schedule_notifier_engine_test.dart` (348 lines)
**Pattern extraction date:** 2026-06-13
