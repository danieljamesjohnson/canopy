# Phase 9: An Engine That Budgets — Research

**Researched:** 2026-06-11
**Domain:** Pure-Dart scheduling engine rewrite (Flutter/Dart, Provider, Hive)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Capacity fill:** Fill mood cap with per-goal demand. Leave unfilled if demand < cap — no bonus/overflow chunks. Owner decision, binding.
- **Time-target chunk count:** `ceil(remaining weekly hours ÷ days left this week ÷ 25min)`, capped at 4/day. "Behind budget" = this week's completed time-target chunks from CompletionLog (week start → today); most-behind first. Skips do not count as elapsed budget.
- **Outcome ordering:** Deadline-pressure only — `urgency = priority × 1/daysRemaining`. Remove `chunksRemaining = 2.0` placeholder. No new "estimated chunks" form field.
- **Priority control (ENGINE-06):** SegmentedButton Low/Normal/High → 0.25/0.5/0.75. Default Normal (null→0.5). Acts as weight + tiebreaker, not a hard gate. Placed in goal form under name/type, shown for all goal types.
- **Habit frequency:** Even spread via floor-div: day set = `{i * 7 ~/ freq + 1 | i in [0..freq)}`. Gives Mon/Wed/Fri for freq=3, Mon/Thu for freq=2. User-pinned days deferred.
- **Streak:** Consecutive scheduled-and-due days completed, frequency-aware. A due day skipped or missed resets streak to 0. Not-due days do not break streak. Recomputed from CompletionLog at completion time and cached to `Goal.streakCount`.
- **Lighter day (ENGINE-05):** Mood 3–5: drop one mood tier (next-lower cap). Mood 1–2 lighter ON: habits only (deadline-today outcome included). Mood 1–2 lighter OFF: habits + deadline-sorted outcome goals. Default ON. Toggle must be visible for all moods 1–5 (UI-SPEC.md: change condition from `<= 2` to `!= null`). Breaks unchanged.

### Claude's Discretion

- Exact method signatures and where per-goal demand/streak computation lives (helper methods on the service vs. small pure helpers).
- Precise SegmentedButton styling (follows existing form conventions per UI-SPEC.md).
- How dynamic rationale strings are phrased (must follow existing terse one-line format in `rationale_mapper.dart`).
- Threshold for "deadline-critical" at mood 1–2 lighter OFF: implementation may treat all outcome goals with deadlines (urgency sort de-prioritizes far ones naturally).

### Deferred Ideas (OUT OF SCOPE)

- User-pinned specific days/times for habits and commitments.
- "Bonus" overflow chunks when capacity exceeds demand.
- LLM-assisted scheduling / conversational re-planning.
- End-of-day/deferral (Phase 10) and quarterly-review wiring (Phase 11).
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENGINE-01 | Schedule generation fills mood capacity with multiple chunks per goal up to the mood cap, rather than one chunk per goal. | Per-goal demand loop with multi-chunk allocation replaces the current "one chunk per goal" pattern. |
| ENGINE-02 | Time-target goals receive chunks proportional to how far behind their weekly hour budget they are (CompletionLog; most-behind first; capped per allocation policy). | `ceil(remaining_hrs × 60 / 25 / daysLeft).clamp(0, 4)` per goal; sort goals by remaining hours descending. |
| ENGINE-03 | Habits respect `frequencyPerWeek` (scheduled on right days) and accrue real `streakCount` from completion history. | Floor-div weekday spread + walk-backward log scan for streak. |
| ENGINE-04 | Outcome goals scheduled by deadline pressure, replacing hardcoded `chunksRemaining = 2.0`. | `urgency = priority × 1/daysRemaining`; `chunksRemaining = 2.0` line removed entirely. |
| ENGINE-05 | "Want a lighter day?" toggle measurably reduces the discretionary schedule. | Cap reduction by one mood tier; plumb `lighterDay` parameter through `generateToday` → `generate`. |
| ENGINE-06 | User can set goal priority (low/normal/high) in goal form; priority influences scheduling. | SegmentedButton in `goal_form_sheet.dart`; priority as urgency multiplier and allocation tiebreaker. |
</phase_requirements>

---

## Summary

Phase 9 rewrites the allocation steps of `ScheduleGeneratorService.generate()` to honor five fields that Goal already stores but the engine currently ignores: `weeklyHourBudget`, `frequencyPerWeek`, `streakCount`, `deadline`, and `priorityWeight`. The Phase 8 ordering/break pass (Steps A–E in the method) is completely intact and must not be touched; only Steps 1–4 (commitment, habit, outcome, time-target allocation) are replaced.

The central challenge is threading `List<CompletionLog>` (pre-fetched by `ScheduleNotifier.generateToday`) into the pure-Dart generator without coupling the service to async I/O or repositories. The solution is to extend the `generate()` signature with `List<CompletionLog> completionLogs` and `bool lighterDay` parameters. The notifier fetches all logs for the relevant goalIds, passes them in, and the engine filters in-memory. This preserves the "pure Dart, injectable" test seam that already exists.

Three pure helper functions belong on the service (or as private methods): `_computeDueWeekdays(int freq)` for deterministic habit spread, `_completedChunksThisWeek(String goalId, List<CompletionLog> logs, DateTime date)` for budget computation, and `_computeStreak(String goalId, Set<int> dueWeekdays, List<CompletionLog> logs)` for streak. All three are pure and deterministic — testable directly against fake log lists with no Hive or Flutter.

**Primary recommendation:** Extend `generate()` with `completionLogs` and `lighterDay`; rewrite Steps 1–4 in-place; add a shared `InMemoryCompletionLogRepository` to `lib/data/repositories/` for test reuse; write 6 new deterministic unit tests in `schedule_generator_test.dart` (one per ENGINE requirement) before touching engine code.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Weekly budget computation | Service (pure Dart) | — | Must be deterministic, tested; no Flutter/async |
| Streak computation | Service (pure Dart) | — | Same — derived from completion logs, no side effects |
| Habit weekday spread | Service (pure Dart) | — | Deterministic function of frequencyPerWeek and date.weekday |
| Completion log fetch before generation | Provider (ScheduleNotifier) | — | Notifier owns async I/O; passes data into pure service |
| Streak write-back after completion | Provider (ScheduleNotifier) | GoalRepository | Notifier has both logRepo and must gain goalRepo access |
| Priority SegmentedButton | Widget (GoalFormSheet) | — | Pure UI state already wired to _priorityWeight; only control missing |
| Lighter-day flag plumbing | Widget (CheckinScreen) → Provider (ScheduleNotifier) → Service | — | Flag originates in UI, passes through notifier into service |
| Dynamic rationale strings | Utility (rationale_mapper.dart) | — | Phase 8 explicitly handed this off to Phase 9 |

---

## Standard Stack

### Core (no new packages)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_test` (built-in) | SDK | Pure-Dart unit tests for service | Already used in `schedule_generator_test.dart` |
| `intl` | ^0.20.2 | `DateFormat('yyyy-MM-dd')` for date strings | Already in pubspec; used by ScheduleNotifier |
| `dart:math` | SDK | `max(1, ...)` in urgency formula | Already imported in schedule_generator.dart |

**No new packages required for Phase 9.** [VERIFIED: pubspec.yaml] All needed libraries (`hive_ce`, `provider`, `intl`, `flutter_test`) are already declared. `SegmentedButton` is a Material 3 built-in available since Flutter 3.3; the project runs Flutter 3.44.1. [VERIFIED: flutter --version]

### Package Legitimacy Audit

Not applicable — Phase 9 installs zero new packages. All computation is pure Dart using the existing project stack.

---

## Architecture Patterns

### System Architecture Diagram

```
CheckinScreen (_lighterDay bool, _selectedMood int)
    │  _generate()
    ▼
ScheduleNotifier.generateToday(moodIndex, goals, blocks, lighterDay)
    │  await _logRepo.getByGoalId(goalId) per goal → completionLogs list
    ▼
ScheduleGeneratorService.generate(
    goals, blocks, moodIndex, date,
    completionLogs: List<CompletionLog>,
    lighterDay: bool
)
    │
    ├── Step 1: Commitment blocks (unchanged — anchored, no cap)
    │
    ├── Step 2: Habits
    │       │ _computeDueWeekdays(freq) → Set<int>
    │       │ date.weekday ∈ dueWeekdays? → include
    │       │ _computeStreak(goalId, dueWeekdays, logs) → int
    │       └── add chunk with rationale "Streak: N days" or "Due Nx/week"
    │
    ├── Step 3: Outcome goals (mood 3–5, or lighterDay=false at mood 1–2)
    │       │ urgency = (priorityWeight ?? 0.5) / max(1, daysRemaining)
    │       │ sort by urgency desc
    │       └── add 1 chunk each (urgency order, up to cap)
    │
    ├── Step 4: Time-target goals (mood 3–5 only)
    │       │ completedHrs = completedChunksThisWeek * 25/60
    │       │ remaining = max(0, weeklyHourBudget - completedHrs)
    │       │ demand = ceil(remaining * 60 / 25 / daysLeft).clamp(0, 4)
    │       │ sort by remaining descending (most behind first)
    │       │ allocate demand chunks per goal until cap reached
    │       └── tiebreaker: priorityWeight when remaining hours equal
    │
    └── Steps A–E: Phase 8 ordering/break pass (UNCHANGED)
            ├── Split commitment vs discretionary
            ├── Assign synthetic start times
            ├── Interleave breaks
            ├── Sort by effective start time
            └── Trim trailing break
```

### Recommended Project Structure (changes only)

```
lib/
├── services/
│   └── schedule_generator.dart   # Rewrite Steps 1-4; Steps A-E unchanged
├── providers/
│   └── schedule_notifier.dart    # Add lighterDay param; fetch logs before generate()
│                                  # Add GoalRepository injection for streak write-back
├── data/repositories/
│   └── in_memory_completion_log_repository.dart  # NEW — shared test seam (moved from test-local)
├── screens/
│   ├── goals/
│   │   └── goal_form_sheet.dart  # Add SegmentedButton priority control
│   └── schedule/
│       └── checkin_screen.dart   # Plumb _lighterDay; show toggle for all moods
└── utils/
    └── rationale_mapper.dart     # Update static strings; add budget/streak/deadline patterns
```

### Pattern 1: Multi-chunk demand allocation (ENGINE-01, ENGINE-02, ENGINE-04)

**What:** Replace the one-chunk-per-goal loops with a demand loop that computes how many chunks each goal needs today, then fills capacity in priority order.

**When to use:** Steps 2, 3, and 4 of `generate()`.

```dart
// Source: CONTEXT.md allocation policy (binding owner decision)
// Time-target demand per goal
int _demandForTimeTarget(Goal goal, List<CompletionLog> logs, DateTime date) {
  if (goal.weeklyHourBudget == null) return 0;
  final completedHrs = _completedChunksThisWeek(goal.id, logs, date) * 25.0 / 60.0;
  final remaining = (goal.weeklyHourBudget! - completedHrs).clamp(0.0, goal.weeklyHourBudget!);
  final daysLeft = 7 - date.weekday + 1; // Monday=1, so Mon→7, Sun→1
  if (daysLeft <= 0 || remaining <= 0) return 0;
  return (remaining * 60.0 / 25.0 / daysLeft).ceil().clamp(0, 4);
}

// Allocation loop: fill cap with per-goal demand, most-behind first
final sorted = timeTargetGoals
    ..sort((a, b) {
      final remA = _remainingHours(a, logs, date);
      final remB = _remainingHours(b, logs, date);
      if ((remA - remB).abs() > 0.01) return remB.compareTo(remA); // most behind first
      return (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5); // tiebreaker
    });

for (final goal in sorted) {
  final demand = _demandForTimeTarget(goal, logs, date);
  for (int i = 0; i < demand; i++) {
    if (discretionaryCount >= cap) break;
    workChunks.add(ScheduledChunk(
      chunkTypeIndex: ChunkType.work.index,
      goalId: goal.id,
      durationMinutes: 25,
      rationale: _timeTargetRationale(goal, logs, date),
    ));
    discretionaryCount++;
  }
}
```

### Pattern 2: Deterministic habit weekday spread (ENGINE-03)

**What:** A pure function that maps `frequencyPerWeek` to a fixed set of weekdays (Monday=1 through Sunday=7), using integer floor-division to guarantee even distribution and unique days.

**Verified algorithm:** `dueWeekdays = { i * 7 ~/ freq + 1 | i ∈ [0, freq) }` [VERIFIED: local Dart execution]

```dart
// Source: CONTEXT.md — "even weekday spread derived from frequency (3x → Mon/Wed/Fri)"
// Verified by running: freq=3 → {1, 3, 5} = Mon, Wed, Fri ✓
// freq=5 → {1, 2, 3, 5, 6} = Mon–Wed, Fri–Sat ✓
// freq=7 → {1,2,3,4,5,6,7} = daily ✓
Set<int> _computeDueWeekdays(int freq) {
  assert(freq >= 1 && freq <= 7);
  return { for (int i = 0; i < freq; i++) i * 7 ~/ freq + 1 };
}

// Usage in Step 2:
final effectiveFreq = goal.frequencyPerWeek ?? 7;
final dueWeekdays = _computeDueWeekdays(effectiveFreq);
if (!dueWeekdays.contains(date.weekday)) continue; // skip — not due today
```

**Critical:** The `round()`-based approach (`(i * step).round() % 7 + 1`) gives WRONG results — freq=3 → {1,3,6} = Mon/Wed/SAT instead of Mon/Wed/Fri. Use floor-div only. [VERIFIED: local Dart execution]

### Pattern 3: Streak computation from CompletionLog (ENGINE-03)

**What:** Walk completion logs backward from the most recent due date, counting consecutive completed due-day entries until a skip, miss, or the start of history.

```dart
// Source: CONTEXT.md — "consecutive scheduled-and-due days completed, frequency-aware"
int _computeStreak(String goalId, Set<int> dueWeekdays, List<CompletionLog> allLogs) {
  final relevant = allLogs
      .where((l) => l.goalId == goalId && l.event == CompletionEvent.completed)
      .toList()
    ..sort((a, b) => b.dateYmd.compareTo(a.dateYmd)); // most recent first

  // Build sorted list of completed due-dates (descending)
  final allGoalLogs = allLogs
      .where((l) => l.goalId == goalId)
      .toList()
    ..sort((a, b) => b.dateYmd.compareTo(a.dateYmd));

  int streak = 0;
  for (final log in allGoalLogs) {
    final parts = log.dateYmd.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    if (!dueWeekdays.contains(dt.weekday)) continue; // not a due day — skip without breaking
    if (log.event == CompletionEvent.completed) {
      streak++;
    } else {
      break; // skipped or missed due day → streak resets
    }
  }
  return streak;
}
```

**Note:** The `allLogs` passed in should be pre-filtered by goalId before calling this helper to avoid O(n×goals) scans.

### Pattern 4: Lighter day cap reduction (ENGINE-05)

**What:** Before entering allocation, compute the effective cap based on `lighterDay` and `moodIndex`.

```dart
// Source: CONTEXT.md — "drop one mood tier (next-lower mood's cap)"
static const Map<int, int> _moodCap = {1: 4, 2: 6, 3: 8, 4: 9, 5: 11};

int _effectiveCap(int moodIndex, bool lighterDay) {
  if (!lighterDay) return _moodCap[moodIndex] ?? 8;
  // Drop one tier: mood 1 lighter has no lower tier → same cap
  final lowerMood = (moodIndex - 1).clamp(1, 5);
  return _moodCap[lowerMood] ?? _moodCap[moodIndex]!;
}
// Results: mood=3 lighter → uses mood=2 cap=6; mood=5 lighter → cap=9
// mood=1 lighter → cap unchanged=4 (already minimum)
```

**Mood 1–2 lighter OFF behavior:** At `moodIndex <= 2 && !lighterDay`, include outcome goals in urgency order (the full urgency sort). At `moodIndex <= 2 && lighterDay`, exclude outcome goals except `deadlineToday`. Time-target goals are excluded at mood 1–2 regardless of `lighterDay`.

### Pattern 5: Priority SegmentedButton (ENGINE-06)

**What:** Add a `SegmentedButton<double>` to `goal_form_sheet.dart` after the goal name field.

```dart
// Source: UI-SPEC.md approved design contract
// Placement: after TextField for name + its SizedBox(height:16), before type-specific fields
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

`_priorityWeight` state already exists in `_GoalFormSheetState` and is already wired to save via `..priorityWeight = _priorityWeight`. No save-path change needed. [VERIFIED: goal_form_sheet.dart lines 27, 87]

### Anti-Patterns to Avoid

- **Touching Steps A–E:** The Phase 8 ordering/break pass is correct and tested by 13 tests. Do not modify `_assignSyntheticStartTimes()` or the commitment/discretionary split. Allocation results slot in as the `workChunks` list that Steps A–E already consume.
- **Fetching CompletionLog inside the service:** The service is pure Dart/synchronous. Do not add `async` or repository access to the service. Fetch logs in `ScheduleNotifier.generateToday()` and pass them as a parameter.
- **Using `getAll()` for log fetching:** This is expensive. Use `getByGoalId(id)` per goal. Phase 9 has at most ~10 active goals; O(10 × log_count) is fine.
- **Sorting habits by round-based weekday spread:** The `(i * step).round() % 7 + 1` formula gives wrong results for freq=3 (Mon/Wed/SAT). Use floor-div: `i * 7 ~/ freq + 1`. [VERIFIED: local Dart execution]
- **Letting `daysLeft` reach 0:** `7 - date.weekday + 1` is always ≥ 1 (Sunday weekday=7 → daysLeft=1). No `max(1, ...)` guard needed, but a `clamp(1, 7)` is defensive.
- **Writing `streakCount` in `generate()`:** The service returns chunks only — it reads logs to build rationale strings, but does not mutate any goal. Streak write-back happens in `markComplete`/`markSkipped` in `ScheduleNotifier`, which also needs a `GoalRepository` injection.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Week start date | Custom week-boundary parser | `date.subtract(Duration(days: date.weekday - 1))` | `DateTime.weekday` is 1 (Mon) to 7 (Sun) — built-in |
| Date string comparison | Manual parsing | String comparison of `dateYmd` (ISO-8601 YYYY-MM-DD sorts lexicographically) | String sort == chronological sort for this format |
| Priority segmented control | Custom widget | `SegmentedButton<double>` (Material 3 built-in, Flutter ≥3.3) | Already in SDK; handles touch target, dark mode, semantics |
| Streak database | Separate Hive box | Walk existing `CompletionLog` backward | Append-only log is already the source of truth; `Goal.streakCount` is a cached projection |

**Key insight:** Every algorithm in this phase is arithmetic over a sorted list — no tree structures, no graph algorithms, no external APIs. The complexity budget is O(goals × log_entries_per_goal).

---

## Current Engine State — Gap Inventory

These are the confirmed defects (read directly from `lib/services/schedule_generator.dart`) [VERIFIED: direct file read]:

| Location | Current Behavior | Required Behavior |
|----------|-----------------|------------------|
| Line 74–86 (Step 2, habits) | One chunk per habit, every day | Frequency-filtered by weekday; streak from log |
| Line 91–126 (Step 3, outcomes) | One chunk per outcome; `chunksRemaining = 2.0` placeholder | 1 chunk per outcome (no multi-chunk needed per CONTEXT); `urgency = priority / daysRemaining`; remove constant |
| Line 101–102 | `return (g.priorityWeight ?? 0.5) * 2.0 / daysRemaining` | `return (g.priorityWeight ?? 0.5) / daysRemaining` (constant 2.0 gone) |
| Line 131–149 (Step 4, time-target) | One chunk per goal; sorted by `priorityWeight` | Multi-chunk per goal; sorted by remaining hours (most behind first); `priorityWeight` as tiebreaker |
| Lines 35–39 (signature) | `generate({goals, blocks, moodIndex, date})` | Add `completionLogs`, `lighterDay` parameters |
| Line 41 | `final int cap = _moodCap[moodIndex] ?? 8` | Apply `_effectiveCap(moodIndex, lighterDay)` |
| CheckinScreen line 56–59 | `generateToday` called without `lighterDay` | Pass `lighterDay: _lighterDay` |
| CheckinScreen line 193 | Toggle only shown for `_selectedMood! <= 2` | Show for all moods (`_selectedMood != null`) |
| `generateToday` signature | No `lighterDay` parameter | Add `bool lighterDay = true` |
| `ScheduleNotifier` | No `GoalRepository` for streak write-back | Inject optional `GoalRepository` in constructor |

The `chunksRemaining = 2.0` constant is at line 102. It must be completely removed — no renamed placeholder. [VERIFIED: schedule_generator.dart direct read, line 102]

---

## Completion Log Fetch Strategy (ENGINE-02, ENGINE-03)

### How `generateToday` must fetch logs

The notifier holds `_logRepo` (already injected). Before calling `generate()`, it fetches all completion logs for active goals:

```dart
// In ScheduleNotifier.generateToday():
Future<void> generateToday({
  required int moodIndex,
  required List<Goal> goals,
  required List<CommitmentBlock> blocks,
  bool lighterDay = true,           // NEW
}) async {
  final now = _now();
  final date = DateTime(now.year, now.month, now.day);

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
  // ... rest unchanged
}
```

### Why not pass logs per-goal as a Map?

Passing `List<CompletionLog>` is simpler and preserves the test seam — tests can inject a flat list of fake logs with any goalId mix. The service filters by goalId internally. [ASSUMED — design choice at Claude's discretion]

### Archived goal log attribution

`CompletionLog` entries for archived goals remain in the repository (append-only). The `getByGoalId` calls in `generateToday` only iterate `goals.where((g) => !g.isArchived)`, so archived goals' logs are never fetched. This means:
- Budget computation: correct (only active goals considered).
- Streak computation: correct (only active goals scheduled).
- Historical aggregation (quarterly review): out of scope for Phase 9. [ASSUMED — consistent with REQUIREMENTS.md scope]

---

## Streak Write-Back Architecture

`streakCount` on the `Goal` model is a cached projection — the CompletionLog is the source of truth. The write-back path is:

1. User swipes to complete/skip → `ScheduleNotifier.markComplete()` / `markSkipped()`
2. After appending to `CompletionLog`, recompute `goal.streakCount` from logs
3. Save updated goal via `GoalRepository`

**Current problem:** `ScheduleNotifier` has no `GoalRepository`. It needs to be injected (optional, for tests).

```dart
// ScheduleNotifier constructor addition:
ScheduleNotifier({
  DateTime Function() now = DateTime.now,
  DailyScheduleRepository? repo,
  CompletionLogRepository? logRepo,
  GoalRepository? goalRepo,         // NEW — for streak write-back
})  : _now = now,
      _repo = repo ?? HiveDailyScheduleRepository(),
      _logRepo = logRepo ?? HiveCompletionLogRepository(),
      _goalRepo = goalRepo ?? HiveGoalRepository();  // NEW
```

The streak recomputation in `markComplete` needs the goal's `frequencyPerWeek` to know which days are "due days". It calls `_computeStreak(goalId, dueWeekdays, updatedLogs)` with fresh logs including the just-appended entry.

**In-memory test seam:** The existing `_InMemoryLogRepository` in `schedule_notifier_defer_test.dart` is test-local. Phase 9 should add `lib/data/repositories/in_memory_completion_log_repository.dart` (mirrors `in_memory_app_settings_repository.dart` pattern) so all test files can import it without cross-test-file imports. [ASSUMED — follows established project pattern]

---

## Common Pitfalls

### Pitfall 1: Week boundary — "this week" vs. "7 rolling days"

**What goes wrong:** Using the last 7 days as the budget window instead of Monday-to-today. A goal completed last Saturday gets counted in "this week" if you roll 7 days back from today (Thursday).

**Why it happens:** `DateTime.now().subtract(Duration(days: 7))` is not a week start; it's 7 days ago. The CONTEXT specifies Monday start.

**How to avoid:**
```dart
// CORRECT — Monday-start week
DateTime _weekStart(DateTime date) {
  return date.subtract(Duration(days: date.weekday - 1));
  // weekday=1 (Mon) → subtract 0; weekday=4 (Wed) → subtract 3 → Monday
}

bool _isThisWeek(String dateYmd, DateTime date) {
  final weekStart = _weekStart(date);
  final logDate = DateTime.parse(dateYmd);
  return !logDate.isBefore(weekStart) && !logDate.isAfter(date);
}
```

**Warning signs:** Budget test shows wrong chunk count on Tuesday/Wednesday.

---

### Pitfall 2: The round-based weekday spread gives wrong results

**What goes wrong:** `(i * 7.0 / freq).round() % 7 + 1` for freq=3 produces {1,3,6} = Mon/Wed/SAT, not Mon/Wed/Fri.

**Root cause:** Floating-point rounding in the intermediate calculation.

**How to avoid:** Use integer floor-division exclusively: `i * 7 ~/ freq + 1`. This gives {1,3,5} = Mon/Wed/Fri for freq=3. [VERIFIED: local Dart execution — both algorithms confirmed]

**Warning signs:** A 3x/week habit appears on Saturday instead of Friday.

---

### Pitfall 3: Modifying Steps A–E while rewriting Steps 1–4

**What goes wrong:** The Phase 8 ordering pass is delicate — it has 13 tests and documented pitfalls (WR-01, WR-02, WR-03). Any change to `_assignSyntheticStartTimes` or the commitment/discretionary split would require re-validating all 13 existing tests.

**How to avoid:** Steps A–E in `generate()` receive `workChunks` from Steps 1–4. Replace what fills `workChunks`; do not touch the code that consumes it. The method boundary is the `// Ordering + break insertion pass (READ-02)` comment at line 154.

**Warning signs:** Any of the 13 existing tests in `schedule_generator_test.dart` fail after the rewrite.

---

### Pitfall 4: `daysLeft` overcounts remaining capacity on Monday

**What goes wrong:** On Monday (weekday=1), `7 - 1 + 1 = 7` days left. If the budget is per-week and the goal has 5 hours budgeted, Monday gets `ceil(5 * 60 / 25 / 7) = ceil(1.71) = 2` chunks — very conservative. By Wednesday (daysLeft=4) with no completions: `ceil(5 * 60 / 25 / 4) = ceil(3.0) = 3`.

**Why this matters:** This is the correct, intended behavior (CONTEXT: "remaining budget ÷ remaining days capped 4/day"). It does NOT mean Monday is broken — it means the schedule correctly distributes load over the week. Do not "fix" it. The schedule on Monday looks light because there are 7 days to distribute work.

**Warning signs:** The urge to change the formula because Monday produces fewer chunks than expected.

---

### Pitfall 5: Streak increments in `generate()` instead of `markComplete()`

**What goes wrong:** Computing and persisting the streak in the generator means it increments every time a schedule is generated (or regenerated), not when the user actually completes a chunk.

**How to avoid:** The generator reads `streakCount` from `goal.streakCount` (for rationale display) but does NOT write it. Write-back happens only in `ScheduleNotifier.markComplete()` and `markSkipped()` after appending to the log.

**Warning signs:** `streakCount` increments after tapping "Let's go" (regeneration) without completing any work.

---

### Pitfall 6: Commitment chunks attributed as `goalId: ''` inflate budget/streak computation

**What goes wrong:** `markComplete` logs commitment chunks with `goalId: chunk.goalId ?? ''`. If the budget computation calls `getByGoalId('')`, it gets all commitment logs.

**How to avoid:** The budget computation only queries active goals' IDs (which are UUIDs, never `''`). This is safe. No change needed; just don't call `getByGoalId('')` anywhere in the engine.

---

### Pitfall 7: Lighter-day toggle invisible for mood 3–5

**What goes wrong:** The current `checkin_screen.dart` line 193 shows the toggle only when `_selectedMood! <= 2`. After Phase 9, the toggle is meaningful for moods 3–5 too (it drops the cap one tier). If the condition isn't updated, the toggle is dead for the most common moods.

**How to avoid:** Change the condition from `_selectedMood! <= 2` to `_selectedMood != null`. [VERIFIED: checkin_screen.dart line 193; UI-SPEC.md confirmed this change]

---

## Code Examples

### Week start calculation

```dart
// Source: ScheduleNotifier.hasScheduleToday pattern (same date arithmetic)
DateTime weekStart(DateTime date) =>
    date.subtract(Duration(days: date.weekday - 1));
// Monday=1: subtract 0 → same day
// Sunday=7: subtract 6 → prior Monday
```

### Completed chunks this week for budget

```dart
// Source: CONTEXT.md allocation policy
int _completedChunksThisWeek(String goalId, List<CompletionLog> logs, DateTime today) {
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  return logs.where((l) {
    if (l.goalId != goalId) return false;
    if (l.event != CompletionEvent.completed) return false; // skips don't count
    final logDate = DateTime.parse(l.dateYmd);
    return !logDate.isBefore(weekStart) && !logDate.isAfter(today);
  }).length;
}
```

### Dynamic rationale strings (replaces static `rationale_mapper.dart` strings)

```dart
// Source: CONTEXT.md Claude's Discretion + UI-SPEC.md copywriting contract
// Generated in the service and stored on ScheduledChunk.rationale
// These replace the static mapping in rationale_mapper.dart for engine-generated rationale

String _timeTargetRationale(Goal goal, List<CompletionLog> logs, DateTime date) {
  final completed = _completedChunksThisWeek(goal.id, logs, date);
  final completedHrs = completed * 25.0 / 60.0;
  final remaining = ((goal.weeklyHourBudget ?? 0.0) - completedHrs).clamp(0.0, double.infinity);
  if (remaining < 0.1) return 'On track this week';
  return '${remaining.toStringAsFixed(1)}h behind this week';
}

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
```

Note: `rationale_mapper.dart`'s static switch-case mapping can be left in place for backward compatibility with any existing rationale strings, but the engine will now emit dynamic strings that don't match the static cases — they fall through to `default: return rationale` which is correct. [VERIFIED: rationale_mapper.dart line 19]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| One chunk per goal loop | Multi-chunk demand allocation | Phase 9 | Fills mood capacity |
| `priorityWeight` sort for time-target | Remaining-hours sort (priority as tiebreaker) | Phase 9 | Honors weekly budget |
| `frequencyPerWeek` ignored | Floor-div weekday gate | Phase 9 | Habits appear correct days only |
| `chunksRemaining = 2.0` constant | `urgency = priority / daysRemaining` | Phase 9 | Actual deadline pressure |
| `_lighterDay` dead state | Plumbed through `generateToday` → `generate` | Phase 9 | Toggle has observable effect |
| No priority UI | SegmentedButton Low/Normal/High | Phase 9 | Priority exists in product |
| Static rationale strings | Dynamic budget/streak/deadline strings | Phase 9 | Rationale matches real data |

**Removed:** `chunksRemaining = 2.0` literal constant at `schedule_generator.dart:102`. No renamed equivalent — the formula changes entirely to `priority / daysRemaining`. [VERIFIED: schedule_generator.dart line 102]

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (built-in SDK) |
| Config file | none — `flutter test` discovers automatically |
| Quick run command | `flutter test test/services/schedule_generator_test.dart` |
| Full suite command | `flutter test` |

Note: `/home/dan/development/flutter/bin/flutter` must be used directly (not on shell PATH — see MEMORY.md).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ENGINE-01 | Mood 4+, 3 goals → more than 3 discretionary chunks | Unit | `flutter test test/services/schedule_generator_test.dart` | ✅ (add test T-09-01) |
| ENGINE-02 | Most-behind time-target goal gets more chunks than ahead one | Unit | `flutter test test/services/schedule_generator_test.dart` | ✅ (add test T-09-02) |
| ENGINE-03a | Habit set 3x/week does NOT appear on non-due day | Unit | `flutter test test/services/schedule_generator_test.dart` | ✅ (add test T-09-03a) |
| ENGINE-03b | Streak increments only on scheduled+completed days | Unit | `flutter test test/providers/schedule_notifier_engine_test.dart` | ❌ Wave 0 |
| ENGINE-04 | Outcome near deadline scheduled before far deadline; `chunksRemaining=2.0` gone | Unit | `flutter test test/services/schedule_generator_test.dart` | ✅ (add test T-09-04) |
| ENGINE-05 | Lighter day reduces discretionary chunks (cap drops one tier) | Unit | `flutter test test/services/schedule_generator_test.dart` | ✅ (add test T-09-05) |
| ENGINE-06 | High-priority goal wins 1-slot competition over low-priority | Unit | `flutter test test/services/schedule_generator_test.dart` | ✅ (add test T-09-06) |

All ENGINE-01–06 service-layer tests add directly to the existing `test/services/schedule_generator_test.dart`. The new `generate()` signature requires updating the 13 existing tests to pass `completionLogs: []` and `lighterDay: false` (or a new default) — this is a mechanical change.

### Sampling Rate

- **Per task commit:** `flutter test test/services/schedule_generator_test.dart`
- **Per wave merge:** `flutter test` (full suite — currently 105 tests pass)
- **Phase gate:** Full suite green (105+ tests) before `/gsd-verify-work`

### Wave 0 Gaps (tests to create before implementation)

- [ ] `test/services/schedule_generator_test.dart` — add T-09-01 through T-09-06 (6 new tests for ENGINE-01–06); update 13 existing tests for new `generate()` signature
- [ ] `test/providers/schedule_notifier_engine_test.dart` — ENGINE-03b streak write-back via `markComplete`; ENGINE-05 lighterDay plumbing through `generateToday`
- [ ] `lib/data/repositories/in_memory_completion_log_repository.dart` — shared test seam (mirrors `in_memory_app_settings_repository.dart`)

---

## Security Domain

No security-sensitive surfaces in this phase. The engine is a pure-Dart computation service with no network I/O, no authentication, no user credential handling, and no external API calls. ASVS categories V2/V3/V4/V6 do not apply. V5 (input validation): the service receives `List<Goal>` and `List<CompletionLog>` from trusted in-process providers — no external input validation needed.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All `flutter test` runs | ✓ | 3.44.1 | — |
| Dart SDK | Dart analysis | ✓ | 3.12.1 (embedded) | — |
| `flutter test` | Test suite | ✓ | bundled with Flutter | — |
| `SegmentedButton` widget | ENGINE-06 UI | ✓ | Available since Flutter 3.3 | — |

Path: `/home/dan/development/flutter/bin/flutter` [VERIFIED: flutter --version]

**Missing dependencies with no fallback:** None.

---

## Open Questions

1. **Lighter-day threshold at mood 1–2 OFF ("heavier"):**
   - What we know: CONTEXT says "adds back deadline-critical outcome work"
   - What's unclear: is "deadline-critical" = any outcome with a deadline, or deadlines within N days?
   - Recommendation: Treat as "all outcome goals with deadlines, sorted by urgency" — the urgency formula already de-prioritizes distant deadlines. This matches the spirit of the policy and requires no new configuration. Tag as Claude's Discretion.

2. **`generate()` default for `lighterDay` parameter:**
   - What we know: `_lighterDay = true` is the default in `checkin_screen.dart`
   - What's unclear: should the `generate()` parameter also default to `true`?
   - Recommendation: Default `lighterDay = true` in `generate()` signature so existing tests don't break when they don't pass the parameter. Then update test assertions for the 13 existing tests.

3. **Streak computation efficiency:**
   - What we know: `getByGoalId` returns all history for a goal (could be large after months of use)
   - What's unclear: is an in-memory walk of potentially hundreds of log entries per goal acceptable?
   - Recommendation: Yes — the streak walk stops at the first non-completed due day. In practice, streaks rarely exceed 30 entries. [ASSUMED — no performance data available]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Passing all logs as `List<CompletionLog>` (flat) rather than a `Map<String, List<CompletionLog>>` is the simpler design | Completion Log Fetch Strategy | Low — either works; planner can choose Map if preferred |
| A2 | Streak write-back needs `GoalRepository` injected into `ScheduleNotifier` | Streak Write-Back Architecture | Medium — alternative: GoalsNotifier calls back (messier coupling); injectable repo is cleaner |
| A3 | Archived goals' log history should not be fetched during generation | Completion Log Fetch Strategy | Low — archived goals aren't scheduled anyway; fetching their logs wastes I/O |
| A4 | `generate()` `lighterDay` defaults to `true` so existing tests don't need `lighterDay` added | Open Questions | Low — 13 tests need updating regardless for `completionLogs: []` |
| A5 | "Deadline-critical" at mood 1–2 lighter OFF = any outcome goal with a deadline | Open Questions | Low — urgency sort naturally handles priority; a "critical" cutoff would add complexity with minimal UX gain |
| A6 | In-memory streak walk is acceptable performance | Open Questions | Low — history rarely exceeds 100 entries per goal; walk stops at first gap |

---

## Sources

### Primary (HIGH confidence)
- `lib/services/schedule_generator.dart` — full read; all current behavior gaps confirmed by direct inspection [VERIFIED: direct file read]
- `lib/providers/schedule_notifier.dart` — constructor signature, `generateToday` call site confirmed [VERIFIED: direct file read]
- `lib/data/models/goal.dart` — all 12 HiveFields confirmed; `priorityWeight`, `weeklyHourBudget`, etc. already exist [VERIFIED: direct file read]
- `lib/data/models/completion_log.dart` — `CompletionEvent` enum; `dateYmd` string format confirmed [VERIFIED: direct file read]
- `lib/screens/goals/goal_form_sheet.dart` — `_priorityWeight` state and save-path confirmed [VERIFIED: direct file read]
- `lib/screens/schedule/checkin_screen.dart` — `_lighterDay` dead state at line 41; toggle at lines 193–211 [VERIFIED: direct file read]
- `test/services/schedule_generator_test.dart` — 13 existing tests confirmed; test structure and helper patterns [VERIFIED: direct file read]
- Local Dart execution — floor-div vs round-based weekday spread; time-target formula; week boundary math [VERIFIED: `/home/dan/development/flutter/bin/dart /tmp/spread_test.dart`]
- Flutter version — 3.44.1 confirms SegmentedButton availability [VERIFIED: flutter --version]
- `flutter test` — 105/105 tests pass as of research date [VERIFIED: local test run]

### Secondary (MEDIUM confidence)
- `.planning/phases/09-an-engine-that-budgets/09-CONTEXT.md` — binding owner decisions, locked allocation policy [CITED: project file]
- `.planning/phases/09-an-engine-that-budgets/09-UI-SPEC.md` — approved SegmentedButton design contract [CITED: project file]

### Tertiary (LOW confidence)
- Performance estimate for in-memory streak walk: assumed acceptable based on typical log volume [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all libraries verified in pubspec.yaml
- Architecture: HIGH — all interfaces confirmed from source; formulas verified by local execution
- Pitfalls: HIGH — confirmed by direct code inspection of the current engine gaps
- Test strategy: HIGH — existing test structure confirmed; 13 tests' signatures known

**Research date:** 2026-06-11
**Valid until:** 2026-07-11 (stable domain — pure Dart algorithms, no external APIs)
