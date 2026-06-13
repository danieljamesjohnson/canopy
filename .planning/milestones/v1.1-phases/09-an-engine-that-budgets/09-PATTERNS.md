# Phase 9: An Engine That Budgets — Pattern Map

**Mapped:** 2026-06-11
**Files analyzed:** 6 (5 modified, 1 new)
**Analogs found:** 6 / 6

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/services/schedule_generator.dart` | service | transform (pure Dart) | itself (same file) | exact — rewrite Steps 1–4, keep Steps A–E |
| `lib/providers/schedule_notifier.dart` | provider | request-response + CRUD | itself (same file) | exact — extend constructor + `generateToday` + `markComplete`/`markSkipped` |
| `lib/screens/goals/goal_form_sheet.dart` | widget | form | itself (Slider pattern at lines 241–258) | exact — Slider is the in-file model for SegmentedButton placement |
| `lib/screens/schedule/checkin_screen.dart` | widget | event-driven | itself (toggle at lines 193–211) | exact — dead `_lighterDay` state already present |
| `lib/data/repositories/in_memory_completion_log_repository.dart` | repository | CRUD | `lib/data/repositories/in_memory_app_settings_repository.dart` | role-match — same in-memory-fake pattern |
| `test/services/schedule_generator_test.dart` | test | transform | itself (existing 13 tests) | exact — same helper/fixture style |

---

## Pattern Assignments

### `lib/services/schedule_generator.dart` (service, pure-Dart transform)

**Analog:** Same file — rewrite Steps 1–4 in-place; Steps A–E untouched.

**Existing signature** (lines 35–40) — extend these named parameters:
```dart
List<ScheduledChunk> generate({
  required List<Goal> goals,
  required List<CommitmentBlock> blocks,
  required int moodIndex,
  required DateTime date,
  // NEW — add after date:
  List<CompletionLog> completionLogs = const [],
  bool lighterDay = true,
})
```

**Existing cap constant** (lines 25–31) — already present, reuse as-is:
```dart
static const Map<int, int> _moodCap = {
  1: 4,
  2: 6,
  3: 8,
  4: 9,
  5: 11,
};
```

**Existing cap usage** (line 41) — replace with `_effectiveCap()` call:
```dart
// BEFORE (line 41):
final int cap = _moodCap[moodIndex] ?? 8;
// AFTER:
final int cap = _effectiveCap(moodIndex, lighterDay);
```

**New private helper — effective cap** (copy location: after `_moodCap` declaration):
```dart
int _effectiveCap(int moodIndex, bool lighterDay) {
  if (!lighterDay) return _moodCap[moodIndex] ?? 8;
  final lowerMood = (moodIndex - 1).clamp(1, 5);
  return _moodCap[lowerMood] ?? _moodCap[moodIndex]!;
}
```

**Existing Step 1 (commitment blocks)** (lines 52–67) — copy unchanged, no modification needed.

**Existing Step 2 (habits) — REPLACE lines 70–86** with frequency-aware version:
```dart
// Step 2: Habits — scheduled on due weekdays only; streak from logs.
for (final goal in activeGoals) {
  if (discretionaryCount >= cap) break;
  if (goal.goalType != GoalType.habit) continue;
  final effectiveFreq = goal.frequencyPerWeek ?? 7;
  final dueWeekdays = _computeDueWeekdays(effectiveFreq);
  if (!dueWeekdays.contains(date.weekday)) continue; // not due today
  final streak = _computeStreak(goal.id, dueWeekdays, completionLogs);
  workChunks.add(ScheduledChunk(
    chunkTypeIndex: ChunkType.work.index,
    goalId: goal.id,
    durationMinutes: 25,
    rationale: _habitRationale(goal, streak),
  ));
  discretionaryCount++;
}
```

**New private helper — due weekdays** (pure, deterministic):
```dart
Set<int> _computeDueWeekdays(int freq) {
  assert(freq >= 1 && freq <= 7);
  return { for (int i = 0; i < freq; i++) i * 7 ~/ freq + 1 };
  // freq=3 → {1,3,5} = Mon/Wed/Fri ✓  (floor-div only — do NOT use round())
}
```

**New private helper — streak** (walk logs backward from most recent):
```dart
int _computeStreak(String goalId, Set<int> dueWeekdays, List<CompletionLog> allLogs) {
  final goalLogs = allLogs
      .where((l) => l.goalId == goalId)
      .toList()
    ..sort((a, b) => b.dateYmd.compareTo(a.dateYmd)); // most recent first
  int streak = 0;
  for (final log in goalLogs) {
    final dt = DateTime.parse(log.dateYmd);
    if (!dueWeekdays.contains(dt.weekday)) continue; // not a due day — skip without breaking
    if (log.event == CompletionEvent.completed) {
      streak++;
    } else {
      break; // skipped or missed due day → streak resets to 0
    }
  }
  return streak;
}
```

**Existing Step 3 (outcomes) — REPLACE lines 91–126**. Remove `chunksRemaining = 2.0` at line 102 entirely:
```dart
// Step 3: Outcome goals.
// Mood 3–5: all outcomes sorted by urgency.
// Mood 1–2 + lighterDay OFF: outcomes with deadlines, urgency sorted.
// Mood 1–2 + lighterDay ON: only deadline==today.
final outcomeGoals = activeGoals
    .where((g) => g.goalType == GoalType.outcome)
    .toList();

double urgencyScore(Goal g) {
  if (g.deadline == null) return (g.priorityWeight ?? 0.5) * 0.1;
  final daysRemaining = max(1, g.deadline!.difference(date).inDays);
  return (g.priorityWeight ?? 0.5) / daysRemaining.toDouble(); // chunksRemaining=2.0 REMOVED
}

outcomeGoals.sort((a, b) => urgencyScore(b).compareTo(urgencyScore(a)));

for (final goal in outcomeGoals) {
  if (discretionaryCount >= cap) break;
  final deadlineToday = goal.deadline != null &&
      goal.deadline!.year == date.year &&
      goal.deadline!.month == date.month &&
      goal.deadline!.day == date.day;
  final bool include;
  if (!isLowMood) {
    include = true; // mood 3–5: all outcomes
  } else if (lighterDay) {
    include = deadlineToday; // mood 1–2 lighter ON: only deadline today
  } else {
    include = goal.deadline != null; // mood 1–2 lighter OFF (heavier): all with deadlines
  }
  if (!include) continue;
  workChunks.add(ScheduledChunk(
    chunkTypeIndex: ChunkType.work.index,
    goalId: goal.id,
    durationMinutes: 25,
    rationale: _outcomeRationale(goal, date),
  ));
  discretionaryCount++;
}
```

**Existing Step 4 (time-target) — REPLACE lines 131–150** with multi-chunk demand loop:
```dart
// Step 4: Time-target goals (mood 3–5 only).
if (!isLowMood) {
  final timeTargetGoals = activeGoals
      .where((g) => g.goalType == GoalType.timeTarget)
      .toList()
    ..sort((a, b) {
      final remA = _remainingHours(a, completionLogs, date);
      final remB = _remainingHours(b, completionLogs, date);
      if ((remA - remB).abs() > 0.01) return remB.compareTo(remA); // most behind first
      return (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5); // tiebreaker
    });

  for (final goal in timeTargetGoals) {
    if (discretionaryCount >= cap) break;
    final demand = _demandForTimeTarget(goal, completionLogs, date);
    for (int i = 0; i < demand; i++) {
      if (discretionaryCount >= cap) break;
      workChunks.add(ScheduledChunk(
        chunkTypeIndex: ChunkType.work.index,
        goalId: goal.id,
        durationMinutes: 25,
        rationale: _timeTargetRationale(goal, completionLogs, date),
      ));
      discretionaryCount++;
    }
  }
}
```

**New private helpers — budget computation**:
```dart
DateTime _weekStart(DateTime date) =>
    date.subtract(Duration(days: date.weekday - 1));
// weekday=1 (Mon) → subtract 0; weekday=7 (Sun) → subtract 6 → prior Monday

int _completedChunksThisWeek(String goalId, List<CompletionLog> logs, DateTime today) {
  final weekStart = _weekStart(today);
  return logs.where((l) {
    if (l.goalId != goalId) return false;
    if (l.event != CompletionEvent.completed) return false; // skips don't count
    final logDate = DateTime.parse(l.dateYmd);
    return !logDate.isBefore(weekStart) && !logDate.isAfter(today);
  }).length;
}

double _remainingHours(Goal goal, List<CompletionLog> logs, DateTime date) {
  if (goal.weeklyHourBudget == null) return 0;
  final completedHrs = _completedChunksThisWeek(goal.id, logs, date) * 25.0 / 60.0;
  return (goal.weeklyHourBudget! - completedHrs).clamp(0.0, goal.weeklyHourBudget!);
}

int _demandForTimeTarget(Goal goal, List<CompletionLog> logs, DateTime date) {
  final remaining = _remainingHours(goal, logs, date);
  if (remaining <= 0) return 0;
  final daysLeft = (7 - date.weekday + 1).clamp(1, 7);
  return (remaining * 60.0 / 25.0 / daysLeft).ceil().clamp(0, 4);
}
```

**New private helpers — rationale strings** (replace static 'Habit'/'Outcome goal'/'Weekly goal' strings):
```dart
String _habitRationale(Goal goal, int streak) {
  if (streak > 0) return 'Streak: $streak day${streak == 1 ? "" : "s"}';
  final freq = goal.frequencyPerWeek ?? 7;
  return freq == 7 ? 'Daily habit' : '${freq}x/week';
}

String _outcomeRationale(Goal goal, DateTime date) {
  if (goal.deadline == null) return 'Working toward your goal';
  final days = goal.deadline!.difference(date).inDays.clamp(0, 9999);
  if (days == 0) return 'Deadline today';
  if (days == 1) return 'Deadline tomorrow';
  return 'Deadline in $days day${days == 1 ? "" : "s"}';
}

String _timeTargetRationale(Goal goal, List<CompletionLog> logs, DateTime date) {
  final completed = _completedChunksThisWeek(goal.id, logs, date);
  final completedHrs = completed * 25.0 / 60.0;
  final remaining = ((goal.weeklyHourBudget ?? 0.0) - completedHrs).clamp(0.0, double.infinity);
  if (remaining < 0.1) return 'On track this week';
  return '${remaining.toStringAsFixed(1)}h behind this week';
}
```

**Existing Steps A–E** (lines 154–311) — copy completely unchanged. The boundary comment at line 154 is the guard:
```dart
// Ordering + break insertion pass (READ-02).
```
Do not touch anything from this comment through the end of `_assignSyntheticStartTimes()`.

**Required import to add** (top of file):
```dart
import 'package:canopy/data/models/completion_log.dart';
```

---

### `lib/providers/schedule_notifier.dart` (provider, request-response + CRUD)

**Analog:** Same file.

**Existing constructor** (lines 22–28) — add `GoalRepository` parameter after `logRepo`:
```dart
// BEFORE:
ScheduleNotifier({
  DateTime Function() now = DateTime.now,
  DailyScheduleRepository? repo,
  CompletionLogRepository? logRepo,
})  : _now = now,
      _repo = repo ?? HiveDailyScheduleRepository(),
      _logRepo = logRepo ?? HiveCompletionLogRepository();

// AFTER — add goalRepo:
ScheduleNotifier({
  DateTime Function() now = DateTime.now,
  DailyScheduleRepository? repo,
  CompletionLogRepository? logRepo,
  GoalRepository? goalRepo,
})  : _now = now,
      _repo = repo ?? HiveDailyScheduleRepository(),
      _logRepo = logRepo ?? HiveCompletionLogRepository(),
      _goalRepo = goalRepo ?? HiveGoalRepository();
```

**Add field** after existing `_logRepo` field declaration (line 32):
```dart
final GoalRepository _goalRepo;
```

**Existing `generateToday` signature** (lines 92–96) — add `lighterDay` parameter and log fetch:
```dart
// BEFORE:
Future<void> generateToday({
  required int moodIndex,
  required List<Goal> goals,
  required List<CommitmentBlock> blocks,
}) async {

// AFTER:
Future<void> generateToday({
  required int moodIndex,
  required List<Goal> goals,
  required List<CommitmentBlock> blocks,
  bool lighterDay = true,                    // NEW
}) async {
  final now = _now();
  final date = DateTime(now.year, now.month, now.day);
  final dateYmd = DateFormat('yyyy-MM-dd').format(now);

  // Fetch completion logs for all active goals (for budget + streak)
  final allLogs = <CompletionLog>[];
  for (final goal in goals.where((g) => !g.isArchived)) {
    allLogs.addAll(await _logRepo.getByGoalId(goal.id));
  }

  final chunks = _generator.generate(
    goals: goals,
    blocks: blocks,
    moodIndex: moodIndex,
    date: date,
    completionLogs: allLogs,  // NEW
    lighterDay: lighterDay,   // NEW
  );
  // ... rest of method unchanged (lines 109–123)
```

**Streak write-back in `markComplete`** (after line 146, inside the try block, after `await _logRepo.append(...)`):
```dart
// Recompute and persist streakCount for habit goals.
// Pattern: same try-block position as the existing _logRepo.append call above.
if (chunk.goalId != null && chunk.goalId!.isNotEmpty) {
  final goal = /* retrieve from goals list passed via context or stored reference */;
  // Implementation note: requires access to the goal — GoalRepository.getById(goalId)
  final updatedLogs = await _logRepo.getByGoalId(chunk.goalId!);
  // _computeStreak is on the service; call via _generator or duplicate the logic here.
  // Simplest: store the updated streakCount on the goal and save.
  await _goalRepo.save(goal);
}
```
> Note: The exact mechanism for recomputing and persisting `streakCount` in `markComplete`/`markSkipped` is at implementation discretion per CONTEXT.md. The planner should specify the call path (e.g., `_goalRepo.getById` + `ScheduleGeneratorService._computeStreak` exposed as a public static method, or duplicated logic). The pattern for the write-back structure itself mirrors the existing `_logRepo.append(...)` + `rethrow` + `notifyListeners()` pattern at lines 139–157.

**Existing `markComplete` error-handling pattern** (lines 135–157) — copy this structure for streak write-back:
```dart
try {
  await _repo.save(_todaySchedule!);
  await _logRepo.append(CompletionLog(...));
  // NEW: streak write-back goes here, inside same try block
} catch (_) {
  chunk.isCompleted = false; // WR-05: revert on failure
  rethrow;
} finally {
  notifyListeners();
}
```

**Required imports to add**:
```dart
import '../data/repositories/goal_repository.dart';
import '../data/repositories/hive_goal_repository.dart';
```

---

### `lib/screens/goals/goal_form_sheet.dart` (widget, form)

**Analog:** Same file — the Slider for frequency (lines 241–258) is the exact model to copy for SegmentedButton placement and label pattern.

**Existing Slider pattern** (lines 241–258) — the SegmentedButton follows this same label-then-control structure:
```dart
// EXISTING (frequency Slider — the model to copy):
if (_selectedType == GoalType.habit) ...[
  Row(
    children: [
      Text(
        'Sessions per week: ${_frequencyPerWeek ?? 7}',
        style: theme.textTheme.bodyMedium,   // ← same style token for Priority label
      ),
    ],
  ),
  Slider(
    value: (_frequencyPerWeek ?? 7).toDouble(),
    min: 1,
    max: 7,
    divisions: 6,
    label: '${_frequencyPerWeek ?? 7}x/week',
    onChanged: (v) => setState(() => _frequencyPerWeek = v.round()),
  ),
  const SizedBox(height: 16),
],
```

**Insertion point:** After the goal name TextField + its `SizedBox(height: 16)` (after line 184), before the `if (_selectedType == GoalType.timeTarget)` block (line 187). The SegmentedButton is shown for ALL goal types, so it is NOT inside a `if (_selectedType == ...)` guard.

**SegmentedButton block to insert** (UI-SPEC.md approved contract):
```dart
// Priority control — shown for all goal types
Row(
  children: [
    Text('Priority', style: theme.textTheme.bodyMedium),
  ],
),
SegmentedButton<double>(
  segments: const [
    ButtonSegment(value: 0.25, label: Text('Low')),
    ButtonSegment(value: 0.5,  label: Text('Normal')),
    ButtonSegment(value: 0.75, label: Text('High')),
  ],
  selected: {_priorityWeight ?? 0.5},
  onSelectionChanged: (Set<double> val) =>
      setState(() => _priorityWeight = val.first),
),
const SizedBox(height: 16),
```

**State variable already exists** (line 26–27) — no new state needed:
```dart
double? _priorityWeight;
```

**Save path already wired** (line 87) — no change needed:
```dart
..priorityWeight = _priorityWeight
```

**initState already loads it** (line 41) — no change needed:
```dart
_priorityWeight = goal.priorityWeight;
```

No new imports needed — `SegmentedButton` is from `package:flutter/material.dart` which is already imported (line 1).

---

### `lib/screens/schedule/checkin_screen.dart` (widget, event-driven)

**Analog:** Same file.

**Change 1 — pass `lighterDay` to `generateToday`** (lines 56–60):
```dart
// BEFORE:
await context.read<ScheduleNotifier>().generateToday(
  moodIndex: _selectedMood!,
  goals: context.read<GoalsNotifier>().goals,
  blocks: context.read<CommitmentsNotifier>().blocks,
);

// AFTER — add lighterDay:
await context.read<ScheduleNotifier>().generateToday(
  moodIndex: _selectedMood!,
  goals: context.read<GoalsNotifier>().goals,
  blocks: context.read<CommitmentsNotifier>().blocks,
  lighterDay: _lighterDay,   // plumb dead state through
);
```

**Change 2 — toggle visibility condition** (line 193):
```dart
// BEFORE (line 193):
if (_selectedMood != null && _selectedMood! <= 2) ...[

// AFTER — show for all moods once selected:
if (_selectedMood != null) ...[
```

**Existing toggle widget** (lines 194–211) — copy unchanged, no modification:
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Text(
      'Want a lighter day?',
      style: TextStyle(color: onBg, fontSize: 16),
    ),
    const SizedBox(width: 12),
    Switch(
      value: _lighterDay,
      onChanged: (val) => setState(() => _lighterDay = val),
      activeThumbColor: Colors.white,
      activeTrackColor: Colors.white.withAlpha(102),
    ),
  ],
),
const SizedBox(height: 16),
```

No new imports needed.

---

### `lib/data/repositories/in_memory_completion_log_repository.dart` (repository, CRUD)

**Analog:** `lib/data/repositories/in_memory_app_settings_repository.dart` — copy this exact structure.

**Analog file in full** (for direct reference):
```dart
// in_memory_app_settings_repository.dart — the model:
import '../models/app_settings.dart';
import 'app_settings_repository.dart';

/// In-memory implementation of [AppSettingsRepository] for tests.
///
/// Mirrors the `HiveAppSettingsRepository` contract without disk I/O so
/// that unit tests can exercise ... without bootstrapping Hive boxes.
/// Published under `lib/` (rather than `test/`) so multiple test files
/// can share the same fake without test-to-test imports.
class InMemoryAppSettingsRepository implements AppSettingsRepository {
  AppSettings? _stored;

  @override
  Future<AppSettings?> getSettings() async => _stored;

  @override
  Future<void> saveSettings(AppSettings settings) async => _stored = settings;
}
```

**New file to create** — follow the same doc comment and class shape; implement `CompletionLogRepository`:
```dart
import '../models/completion_log.dart';
import 'completion_log_repository.dart';

/// In-memory implementation of [CompletionLogRepository] for tests.
///
/// Mirrors the [HiveCompletionLogRepository] contract without disk I/O.
/// Published under `lib/` (rather than `test/`) so multiple test files
/// can share the same fake without test-to-test imports.
class InMemoryCompletionLogRepository implements CompletionLogRepository {
  final List<CompletionLog> _logs = [];

  @override
  Future<void> append(CompletionLog log) async => _logs.add(log);

  @override
  Future<List<CompletionLog>> getByGoalId(String goalId) async =>
      _logs.where((l) => l.goalId == goalId).toList();

  @override
  Future<List<CompletionLog>> getAll() async => List.unmodifiable(_logs);
}
```

Verify `CompletionLogRepository` interface methods by reading `lib/data/repositories/completion_log_repository.dart` before writing this class.

---

### `test/services/schedule_generator_test.dart` (test, transform)

**Analog:** Same file — existing 13 tests are the model.

**Existing helper pattern** (lines 23–59) — add a `makeTimeTarget` and `makeLog` helper following the same factory style:
```dart
// EXISTING helpers (lines 23–53) — follow exactly:
Goal makeHabit({String name = 'Habit goal', double? priorityWeight}) =>
    Goal(
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

// NEW helpers to add — same style:
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

CompletionLog makeLog({
  required String goalId,
  required String dateYmd,
  CompletionEvent event = CompletionEvent.completed,
}) => CompletionLog(
      chunkId: 'chunk-$dateYmd',
      goalId: goalId,
      dateYmd: dateYmd,
      eventIndex: event.index,
    );
```

**Existing test call pattern** (lines 67–74) — all 13 existing tests must add `completionLogs: []` and can omit `lighterDay` (defaults to `true`):
```dart
// BEFORE (all 13 existing tests):
final result = sut.generate(
  goals: [...],
  blocks: [...],
  moodIndex: 3,
  date: monday,
);

// AFTER (mechanical update — add one named arg):
final result = sut.generate(
  goals: [...],
  blocks: [...],
  moodIndex: 3,
  date: monday,
  completionLogs: [],    // NEW — empty list for existing tests
);
// lighterDay omitted — defaults to true, existing assertions unchanged
```

**New test structure** (T-09-01 through T-09-06) — follow existing test layout (numbered comment header + single `test()` call + explicit assertions):

```dart
// ---------------------------------------------------------------------------
// T-09-01: ENGINE-01 — mood 4, 3 time-target goals → more than 3 chunks
// ---------------------------------------------------------------------------
test('T-09-01: mood 4, 3 time-target goals → more than 3 discretionary chunks', () {
  // 3 goals, each 10hr/week budget, Monday (daysLeft=7), 0 completions → demand=ceil(10*60/25/7)=4 each
  final goals = [
    makeTimeTarget(name: 'G1', weeklyHourBudget: 10),
    makeTimeTarget(name: 'G2', weeklyHourBudget: 10),
    makeTimeTarget(name: 'G3', weeklyHourBudget: 10),
  ];
  final result = sut.generate(
    goals: goals, blocks: [], moodIndex: 4, date: monday, completionLogs: [],
  );
  expect(workChunksOf(result), greaterThan(3));
});
```

---

## Shared Patterns

### Pure-Dart service constraint
**Source:** `lib/services/schedule_generator.dart` — class doc comment (lines 7–9)
**Apply to:** All new helper methods in `schedule_generator.dart`
```dart
/// Pure Dart service — no Flutter imports, no async, no side effects.
```
All new private methods (`_computeDueWeekdays`, `_computeStreak`, `_completedChunksThisWeek`, `_demandForTimeTarget`, `_remainingHours`) must remain synchronous, free of repository access, and have no side effects. Pass `List<CompletionLog>` in; return a value.

### Error-handling + revert pattern (WR-05)
**Source:** `lib/providers/schedule_notifier.dart` lines 135–157
**Apply to:** Streak write-back inside `markComplete` and `markSkipped`
```dart
try {
  await _repo.save(_todaySchedule!);
  await _logRepo.append(CompletionLog(...));
  // streak write-back goes here
} catch (_) {
  chunk.isCompleted = false; // revert in-memory flag
  rethrow;
} finally {
  notifyListeners();
}
```

### Hive enum-as-int-index pattern
**Source:** `lib/data/models/completion_log.dart` lines 9, 17, 41
**Apply to:** Any new enum usage in `schedule_generator.dart`
```dart
// Store as index; retrieve via .values[index]
eventIndex: CompletionEvent.completed.index,
// ...
CompletionEvent get event => CompletionEvent.values[eventIndex];
```
Never reorder enum values. `GoalType` and `CompletionEvent` follow this same pattern.

### Injectable repository constructor
**Source:** `lib/providers/schedule_notifier.dart` lines 22–28
**Apply to:** `ScheduleNotifier` constructor extension (adding `GoalRepository`)
```dart
ScheduleNotifier({
  DateTime Function() now = DateTime.now,
  DailyScheduleRepository? repo,
  CompletionLogRepository? logRepo,
})  : _now = now,
      _repo = repo ?? HiveDailyScheduleRepository(),
      _logRepo = logRepo ?? HiveCompletionLogRepository();
```
Pattern: optional named parameter + null-coalescing to production implementation. Extend this pattern for `GoalRepository`.

### In-memory fake pattern
**Source:** `lib/data/repositories/in_memory_app_settings_repository.dart` lines 1–22
**Apply to:** `lib/data/repositories/in_memory_completion_log_repository.dart`

Published under `lib/` not `test/` so multiple test files can import without cross-test-file imports. Class name: `InMemory<X>Repository implements <X>Repository`.

### Date arithmetic — week start
**Source:** `lib/providers/schedule_notifier.dart` line 44 (`DateFormat('yyyy-MM-dd').format(_now())`) + RESEARCH.md pattern
**Apply to:** `_weekStart()` helper in `schedule_generator.dart`
```dart
// weekday=1 (Mon)=subtract 0; weekday=7 (Sun)=subtract 6
DateTime _weekStart(DateTime date) =>
    date.subtract(Duration(days: date.weekday - 1));
```
Use string comparison for ISO-8601 date ordering (`dateYmd` lexicographic == chronological).

---

## No Analog Found

All files have analogs in the codebase. No files require falling back to RESEARCH.md patterns exclusively.

---

## Critical Anti-Patterns (do not introduce)

| Anti-Pattern | Where to Avoid | Why |
|--------------|---------------|-----|
| `(i * step).round() % 7 + 1` for weekday spread | `_computeDueWeekdays` | freq=3 → Mon/Wed/SAT (wrong); use `i * 7 ~/ freq + 1` |
| Touching `_assignSyntheticStartTimes` or Steps A–E | `schedule_generator.dart` lines 154–311 | 13 existing tests cover it; any change risks WR-01/02/03 regressions |
| `async` or repository access in `ScheduleGeneratorService` | Any new method in the service | Service is pure Dart; async lives in `ScheduleNotifier.generateToday` |
| `getAll()` for completion log fetch | `ScheduleNotifier.generateToday` | Use `getByGoalId(id)` per goal; `getAll()` is expensive |
| Writing `streakCount` in `generate()` | `schedule_generator.dart` | Service returns chunks only; write-back is in `markComplete`/`markSkipped` |
| Leaving any `chunksRemaining = 2.0` constant | `schedule_generator.dart` line 102 | Explicit acceptance criterion — must be completely removed |

---

## Metadata

**Analog search scope:** `lib/services/`, `lib/providers/`, `lib/screens/`, `lib/data/repositories/`, `test/services/`
**Files scanned:** 7 source files read directly
**Pattern extraction date:** 2026-06-11
