# Phase 11: Honest Long Loop — Research

**Researched:** 2026-06-11
**Domain:** Flutter/Dart — quarterly review aggregation wiring, donut chart slice construction, priority-weight write-back, cold-launch data loading
**Confidence:** HIGH — all findings from direct codebase inspection

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Honest Aggregation (REVIEW-01)**
- Commitment-block time is shown as one dedicated "Commitments" slice (neutral color), aggregating all commitment chunks — counted and labeled, distinct from goals.
- Archived goals' historical completions render as their own slices using each goal's stored name and color, with an "(archived)" suffix in the legend.
- No invisible slice: donut sections are built from the aggregated chunk totals (every counted id — active goal, archived goal, commitment, or fallback — gets a drawn slice). Any id that resolves to nothing falls into a catch-all "Other" slice. The percentage denominator is the sum of all drawn slices, so percentages add up to 100%.
- "Time not spent" (skipped + deferred) remains its own slice (existing D-02 honest behavior) and is included in the 100% total.

**Priority Adjustments Drive Schedule (REVIEW-02)**
- Drag-to-reorder in the adjustments section maps the resulting order to each goal's `priorityWeight` — the field the schedule generator already reads. `sortOrder` continues to be persisted for display ordering.
- Drag position maps to `priorityWeight` via a linear spread over the existing range (top of list = highest weight), so reordering always produces distinct, monotonic weights and a real change in generation input.
- The change takes effect in the next morning's schedule generation: priorities persist on "Finish review", and the next generate run picks them up. Today's already-generated schedule is not regenerated.
- "Demonstrably changes" is proven with a test: set a goal to top priority, regenerate, and assert its chunk ordering/position differs from the pre-change baseline.

**Independent Cold-Launch Loading (REVIEW-03)**
- The review loads all goals it needs, including archived, so every logged goalId resolves regardless of which tabs were visited: active goals come from GoalsNotifier (already loaded at startup per Phase 7 / LOOP-01) and archived goals are loaded via the goals repository (`loadArchivedGoals` / repo `getAll`).
- Commitment labels for the "Commitments" slice load from CommitmentsNotifier / the commitment repository in `_loadData` (CommitmentsNotifier is also loaded at startup per Phase 7).
- The "has data" empty-state guard is based on the review's own data (completion logs + snapshots), not on whether provider goal lists happen to be populated.
- A cold-launch regression test pumps the review without visiting other screens and asserts the chart and goal list are populated.

### Claude's Discretion
- Exact neutral color for the "Commitments" slice and the "Other" catch-all color.
- The precise linear-spread formula and weight bounds for drag→priorityWeight mapping, within the constraint that the mapping is monotonic and yields distinct weights.
- Legend ordering and any minor layout adjustments needed to fit added slices.
- Whether archived-goal resolution reuses an existing repository call or adds a thin combined lookup, as long as it stays append-only and read-only for archived data.

### Deferred Ideas (OUT OF SCOPE)
- Reworking the reflection question set or making questions configurable (v2, per Phase 5 D-08).
- Per-commitment breakdown slices (chose a single aggregated "Commitments" slice instead).
- Calendar-driven commitment data (v2, out of milestone scope).
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REVIEW-01 | The quarterly review's aggregation and charts count all logged time correctly, including commitment time and archived goals' history, with correct donut totals. | Donut fix: expand slice loop in `donut_chart.dart` to include archived-goal, commitment, and Other slices; update totalValue denominator; commit-attributed logs identified by matching log.goalId against CommitmentBlock.id set. |
| REVIEW-02 | Priority adjustments made during the review demonstrably change subsequent schedule generation. | Fix: extend `GoalsNotifier.reorderAll` (or add `reorderAllWithPriority`) to write `priorityWeight` using linear-spread formula; `schedule_generator.dart` already reads `priorityWeight` — no generator change needed. |
| REVIEW-03 | The review loads its own data independently, with no dependency on a previously-visited tab. | Fix: `_loadData()` must load archived goals via `GoalRepository.getAll()` (not GoalsNotifier.goals) and commitments via `CommitmentsNotifier.blocks`; fix empty-state guard to `allLogs.isEmpty`. |
</phase_requirements>

---

## Summary

Phase 11 is a pure bug-fix and wiring phase on the existing quarterly review screen (built in Phase 5). There are no new libraries, no new screens, and no schema changes. The three bugs are cleanly localized:

**REVIEW-01 (Invisible slices):** `donut_chart.dart` iterates only the `goals` list (active goals). Logs attributed to commitment blocks (stored as `log.goalId = block.id` per Phase 10-01) and archived goals are silently ignored — their chunks never appear in any slice. The fix is to classify each key in `completedByGoal` against three lookup sets (active goal ids, archived goal ids, commitment block ids) and build slices for each resolved category plus a catch-all. The `totalValue` denominator must cover all drawn slices so percentages sum to 100%.

**REVIEW-02 (Priority not wired):** `adjustments_section.dart`'s `_finish()` calls `GoalsNotifier.reorderAll(orderedIds)` which writes only `sortOrder`. The schedule generator (`schedule_generator.dart` lines 267–313) uses `priorityWeight` exclusively and never reads `sortOrder`. These two fields are entirely disconnected — reordering in the review has zero effect on schedule generation. The fix is a one-line addition inside `reorderAll` (or a new `reorderAllWithPriority` method) that applies the linear spread `high - (high - low) * i / (n - 1)` where high=0.75 and low=0.25 to produce distinct, monotonic weights.

**REVIEW-03 (Cold-launch dependency):** `_loadData()` reads `context.read<GoalsNotifier>().goals` for the active goal list and has no path to load archived goals or commitments. If GoalsNotifier happens to be populated (because the user visited the Goals tab), the chart works; on a true cold launch direct to `/review`, archived-goal and commitment resolution both fail silently. Additionally the empty-state guard checks `totalCompleted == 0 && goals.isEmpty` — if goals is empty (GoalsNotifier not yet primed), the screen falsely shows "Not enough data". The fix: load archived goals via `GoalRepository.getAll()`, read commitments from `CommitmentsNotifier.blocks` (already loaded at startup), and change the guard to `allLogs.isEmpty`.

**Primary recommendation:** Three targeted edits to `donut_chart.dart` (slice construction), `goals_notifier.dart` (reorderAll + priorityWeight), and `quarterly_review_screen.dart` (_loadData + guard), each backed by a unit/widget test.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Aggregation — classify log IDs | Service (`QuarterlyAggregationService`) | — | Pure Dart, no Flutter, already unit-tested |
| Donut slice construction | Widget (`DonutChart`) | — | Presentation logic driven by pre-aggregated totals passed in |
| Archived goal resolution | Screen state (`QuarterlyReviewScreen._loadData`) | Repository (`GoalRepository`) | _loadData owns the loading phase; repository owns data access |
| Commitment ID resolution | Screen state (`QuarterlyReviewScreen._loadData`) | Notifier (`CommitmentsNotifier`) | CommitmentsNotifier already loaded at startup |
| Priority weight write-back | Notifier (`GoalsNotifier.reorderAll`) | — | Notifier owns goal mutation; generator reads from persisted model |
| Cold-launch data guard | Screen state (`QuarterlyReviewScreen._loadData`) | — | Guard based on repo data, not provider state |

---

## Standard Stack

No new packages. All work uses existing dependencies.

| Library | Version | Purpose | Already In pubspec |
|---------|---------|---------|-------------------|
| `fl_chart` | existing | Donut/bar charts | Yes — since Phase 5 |
| `provider` | existing | ChangeNotifier access | Yes |
| `hive_ce` | existing | Hive data access | Yes |
| `flutter_test` | SDK | Widget + unit tests | Yes |

**No new dependencies. No pubspec changes required.**

---

## Package Legitimacy Audit

> No new packages are introduced in this phase.

**Packages removed due to SLOP verdict:** none
**Packages flagged as suspicious:** none

---

## Architecture Patterns

### Data Flow for REVIEW-01 (Donut Fix)

```
QuarterlyReviewScreen._loadData()
  │
  ├─ HiveCompletionLogRepository.getAll()     → allLogs
  ├─ GoalRepository.getAll()                  → allGoals (active + archived)
  ├─ CommitmentsNotifier.blocks               → commitmentBlocks (already loaded)
  │
  ▼
QuarterlyAggregationService.completedByGoal(allLogs)
  → Map<String, int>   (key = whatever goalId was stored)
  │
  ▼
DonutChart(
  activeGoals: goals,
  archivedGoals: archivedGoals,
  commitmentBlocks: commitmentBlocks,
  goalChunkTotals: _goalChunkTotals,   ← keys may be goal ids, block ids, or unknown
  notSpentCount: _notSpentCount,
)
  │
  ├─ For each key in goalChunkTotals:
  │     1. Match against active goal ids        → goal slice
  │     2. Else match against archived goal ids → archived slice (name + "(archived)")
  │     3. Else match against commitment ids    → accumulate into commitmentTotal
  │     4. Else                                 → accumulate into otherTotal
  │
  ├─ Add commitmentTotal slice  (if > 0)
  ├─ Add otherTotal slice       (if > 0)
  ├─ Add notSpentCount slice    (always, same as today)
  │
  totalValue = sum of ALL drawn slice values
  pct = each slice value / totalValue * 100    (sums to 100%)
```

### Data Flow for REVIEW-02 (Priority Write-back)

```
AdjustmentsSection._finish()
  │
  ▼
orderedIds = [goal.id, ...]   (drag order, top = index 0)
  │
  ▼
GoalsNotifier.reorderAllWithPriority(orderedIds)
  │
  ├─ sortOrder[i] = i                             (existing behavior, preserved)
  ├─ priorityWeight[i] = 0.75 - 0.5 * i / (n-1) (NEW: linear spread 0.75→0.25)
  │     Special case n==1: priorityWeight[0] = 0.75
  │
  ▼
goal.save() → Hive persists priorityWeight
  │
  ▼
Next ScheduleNotifier.generate()
  reads goal.priorityWeight → urgencyScore() uses it → ordering changes
```

### Data Flow for REVIEW-03 (Cold-Launch Fix)

```
QuarterlyReviewScreen.initState()
  │
  addPostFrameCallback → _loadData()
  │
  ├─ BEFORE (bug): goals = context.read<GoalsNotifier>().goals (active only, may be empty)
  │                empty guard: totalCompleted == 0 && goals.isEmpty  ← WRONG
  │
  └─ AFTER (fix):  archivedGoals = await _repository.getAll()  (all goals)
                   commitmentBlocks = context.read<CommitmentsNotifier>().blocks  (loaded at startup)
                   empty guard: allLogs.isEmpty                 ← CORRECT
```

### Recommended Edit Sites (complete list)

```
lib/
├── data/models/
│   └── (no changes)
├── providers/
│   └── goals_notifier.dart               ← add reorderAllWithPriority() or extend reorderAll()
├── screens/quarterly_review/
│   ├── quarterly_review_screen.dart      ← _loadData() + _hasData guard
│   ├── sections/
│   │   ├── adjustments_section.dart      ← call reorderAllWithPriority instead of reorderAll
│   │   └── data_section.dart             ← pass archivedGoals + commitmentBlocks to DonutChart
│   └── widgets/
│       └── donut_chart.dart              ← primary edit: new constructor params + slice loop
└── services/
    └── quarterly_aggregation_service.dart  ← no change needed (already correct by design)
```

### Anti-Patterns to Avoid

- **Re-using `GoalsNotifier.goals` for archived resolution in _loadData:** `GoalsNotifier.goals` is active-only (see `loadGoals()` which calls `getActive()`). Using it for archived lookup silently misses all archived goal logs. Must call `_repository.getAll()` and filter `g.isArchived == true`.
- **Calling `context.read<GoalsNotifier>().getArchivedGoals()` in _loadData:** `getArchivedGoals()` calls `_repository.getAll()` internally, which is correct, but the repository is private to the notifier. The cleaner approach is a new `loadArchivedGoals()` call or direct repo injection. However, `getArchivedGoals()` is already public on GoalsNotifier — use it (it does not call notifyListeners, per source line 69).
- **Adding a separate `commitmentId` field to CompletionLog:** Phase 10-01 deliberately stored commitment attribution in the `goalId` field via `chunk.commitmentId ?? chunk.goalId ?? ''`. Do not add a new Hive field — that would require a migration and breaks the append-only log contract. Instead resolve by checking if the goalId matches a CommitmentBlock.id.
- **Regenerating today's schedule on "Finish review":** REVIEW-02 success criterion is "next day's schedule". Do not call `ScheduleNotifier.generate()` inside `_finish()`. Write the weights to Hive and let the next cold launch pick them up.
- **Using `goals.isEmpty` as the only empty-state guard:** The screen currently uses `totalCompleted == 0 && goals.isEmpty`. On cold launch, `goals` (from GoalsNotifier) will be non-empty (it's loaded before runApp), so this guard won't false-positive in v1.1. But the correct semantic for "no review data" is `allLogs.isEmpty` — that is independent of provider state entirely.
- **Zero-value slices in PieChart:** fl_chart's `PieChart` with a `value: 0` section produces a 0dp arc that can cause layout artifacts. Omit zero-value slices from both `sections` and `legendEntries` per UI-SPEC.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Commitment ID detection | Manual string heuristics | Set lookup: `commitmentIds.contains(log.goalId)` | O(1), deterministic, no parsing needed |
| Weight calculation | Custom interpolation | `high - (high - low) * i / max(1, n - 1)` | One-liner, already decided in CONTEXT.md/UI-SPEC |
| Archived goal resolution | Separate network/DB call | `GoalsNotifier.getArchivedGoals()` already exists | No new code needed; it calls `_repository.getAll()` and filters isArchived |

**Key insight:** All three bugs are attribution/wiring gaps, not algorithmic problems. The data is already stored correctly; the read paths just don't traverse it.

---

## REVIEW-01: Detailed Slice Construction Logic

### How Commitment Logs Are Stored (VERIFIED in source)

Per `lib/data/models/completion_log.dart` and Phase 10-01 decision in STATE.md:
- `CompletionLog.goalId` is a required `String` (non-nullable, line 26)
- For commitment chunks, the log is written as: `chunk.commitmentId ?? chunk.goalId ?? ''`
- `ScheduledChunk.commitmentId` = the `CommitmentBlock.id`; `ScheduledChunk.goalId` = null for commitment chunks
- Therefore `log.goalId` == `CommitmentBlock.id` for all commitment-attributed logs
- A commitment ID is a UUID v4 string — same format as goal IDs — so you must match against actual CommitmentBlock IDs, not by string pattern

### Resolution Algorithm (per aggregation map keys)

```dart
// In DonutChart.build():
final commitmentIds = {for (final b in commitmentBlocks) b.id};
final activeGoalIds = {for (final g in activeGoals) g.id};
final archivedGoalMap = {for (final g in archivedGoals) g.id: g};

int commitmentTotal = 0;
int otherTotal = 0;

for (final entry in goalChunkTotals.entries) {
  final id = entry.key;
  final count = entry.value;
  if (count == 0) continue;

  if (activeGoalIds.contains(id)) {
    // existing active-goal slice logic (unchanged)
  } else if (archivedGoalMap.containsKey(id)) {
    final goal = archivedGoalMap[id]!;
    // archived slice: goal.name + ' (archived)', same color logic
  } else if (commitmentIds.contains(id)) {
    commitmentTotal += count;
  } else {
    otherTotal += count;
  }
}

// Add aggregated slices (only if > 0):
if (commitmentTotal > 0) { /* add Commitments slice */ }
if (otherTotal > 0)      { /* add Other slice */ }
// always add notSpent slice:
// add 'Time not spent' slice
```

### DonutChart Constructor Signature Change

Current:
```dart
const DonutChart({
  required this.goalChunkTotals,
  required this.notSpentCount,
  required this.goals,           // ← active goals only
});
```

Required after fix:
```dart
const DonutChart({
  required this.goalChunkTotals,
  required this.notSpentCount,
  required this.goals,           // active goals (unchanged parameter name for call-site compat)
  required this.archivedGoals,   // NEW
  required this.commitmentBlocks, // NEW
});
```

`DataSection` must also receive `archivedGoals` and `commitmentBlocks` and pass them through to `DonutChart`. `QuarterlyReviewScreen` must load these in `_loadData`.

### totalValue Denominator Fix

Current (line 36 of donut_chart.dart):
```dart
final totalValue =
    goalChunkTotals.values.fold<int>(0, (a, b) => a + b) + notSpentCount;
```

This is already the correct denominator IF every key in `goalChunkTotals` ends up in a drawn slice. With the new classification loop, `goalChunkTotals` keys that fall into commitment or other buckets are still part of the fold, so the denominator remains correct — the existing calculation need not change, as long as zero-value slices are excluded from the `sections` list but their values still contribute via the `fold`.

Actually: the fold includes ALL values from `goalChunkTotals` (active + archived + commitment + other) plus `notSpentCount`. Since every key's count is drawn into exactly one slice, the fold correctly represents the total. No change needed to the `totalValue` line.

---

## REVIEW-02: Schedule Generator Ordering (VERIFIED in source)

Lines 266–272 of `schedule_generator.dart`:
```dart
double urgencyScore(Goal g) {
  if (g.deadline == null) return (g.priorityWeight ?? 0.5) * 0.1;
  final daysRemaining = max(1, g.deadline!.difference(date).inDays);
  return (g.priorityWeight ?? 0.5) / daysRemaining.toDouble();
}
outcomeGoals.sort((a, b) => urgencyScore(b).compareTo(urgencyScore(a)));
```

Lines 307–313 (time-target tiebreaker):
```dart
return (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5);
```

Habits (step 2, lines 238–254): habits do NOT use `priorityWeight`; they are included if the weekday is due. Their ordering within the habit group is the order they appear in `activeGoals` — which comes from `GoalsNotifier.goals` (sorted by `sortOrder`). So for habits, `sortOrder` matters for ordering but `priorityWeight` affects inclusion/tie-breaking only indirectly.

**Conclusion:** Writing `priorityWeight` from the drag order will demonstrably change outcome goal ordering (primary scheduling impact) and time-target goal tie-breaking. The test must use outcome goals or time-target goals to exercise the changed ordering path.

### Linear-Spread Formula (from UI-SPEC)

```dart
double _priorityFromIndex(int i, int n) {
  const double high = 0.75;
  const double low  = 0.25;
  if (n <= 1) return high;
  return high - (high - low) * i / (n - 1);
}
```

For n=3: index 0 → 0.75, index 1 → 0.5, index 2 → 0.25 (exact Low/Normal/High sentinels).
For n=2: index 0 → 0.75, index 1 → 0.25.
For n=1: 0.75.

### GoalsNotifier Change

Add `reorderAllWithPriority(List<String> orderedIds)` that does what `reorderAll` does plus writes `priorityWeight`:

```dart
Future<void> reorderAllWithPriority(List<String> orderedIds) async {
  const double high = 0.75;
  const double low  = 0.25;
  final n = orderedIds.length;
  for (var i = 0; i < n; i++) {
    final goal = _goals.where((g) => g.id == orderedIds[i]).firstOrNull;
    if (goal != null) {
      goal.sortOrder = i;
      goal.priorityWeight = n <= 1 ? high : high - (high - low) * i / (n - 1);
      await _repository.save(goal);
    }
  }
  await loadGoals();
}
```

`AdjustmentsSection._finish()` replaces `notifier.reorderAll(orderedIds)` with `notifier.reorderAllWithPriority(orderedIds)`.

---

## REVIEW-03: Cold-Launch Loading (VERIFIED in source)

### Current _loadData() State

```dart
// Line 57 — reads from GoalsNotifier (active goals only):
final goals = context.read<GoalsNotifier>().goals;
```

GoalsNotifier.goals IS populated at startup (main.dart line 55-56: `await goalsNotifier.loadGoals()` before runApp). So the active-goals read is actually fine for REVIEW-03 purposes. The real problem is:
1. **No archived goals loaded** — logged commitment IDs and archived goal IDs cannot be resolved.
2. **Wrong empty-state guard** (line 84): `totalCompleted == 0 && goals.isEmpty` — `goals` from GoalsNotifier will be non-empty if user has any active goals, so the guard won't fire falsely when GoalsNotifier is pre-loaded. But the semantically correct guard for "no review data exists" is `allLogs.isEmpty`, not depending on the goal list state at all.

### Archived Goals Loading

`GoalsNotifier.getArchivedGoals()` (line 69–74) is already public and calls `_repository.getAll()` then filters. This is the cheapest path — no new method or repo injection needed:

```dart
// In _loadData():
final archivedGoals = await context.read<GoalsNotifier>().getArchivedGoals();
```

### Commitment Blocks Loading

`CommitmentsNotifier.blocks` is already populated at startup (main.dart line 58-59: `await commitmentsNotifier.loadBlocks()`). In `_loadData()`:

```dart
final commitmentBlocks = context.read<CommitmentsNotifier>().blocks;
```

No async call needed.

### Empty-State Guard Fix

```dart
// BEFORE (bug — ties empty-state to provider goal count):
if (totalCompleted == 0 && goals.isEmpty) { ... }

// AFTER (fix — only checks whether log data exists):
if (allLogs.isEmpty) { ... }
```

The `return` at line 73 (no logs at all) already handles the truly empty case. The second guard at line 84 is the false-positive risk. With the fix, the review shows the empty state only when there are literally no completion logs.

### State Variables to Add in QuarterlyReviewScreen

```dart
List<Goal> _archivedGoals = [];
List<CommitmentBlock> _commitmentBlocks = [];
```

These are passed to `DataSection` → `DonutChart`.

---

## Common Pitfalls

### Pitfall 1: goalId == '' (empty string) in older logs
**What goes wrong:** Some older logs (before Phase 10-01) may have `goalId = ''` (the `?? ''` fallback in the attribution). This empty string won't match any active goal, archived goal, or commitment block — it falls into the "Other" bucket. This is the correct and intended behavior per the locked decision.
**How to avoid:** The catch-all "Other" slice handles this correctly. No special treatment needed.

### Pitfall 2: Zero-value slices crash fl_chart
**What goes wrong:** Adding a `PieChartSectionData(value: 0.0, ...)` to `sections` can produce a zero-width arc rendering artifact.
**How to avoid:** Guard every slice addition with `if (count > 0)`. The existing "Time not spent" slice has no such guard — check if notSpentCount == 0 should also skip it. Per UI-SPEC: "Slices with value == 0 are OMITTED". The existing code unconditionally adds the notSpent slice; this should be fixed too.

### Pitfall 3: reorderAll vs reorderAllWithPriority — which gets called
**What goes wrong:** If `AdjustmentsSection._finish()` still calls `reorderAll` (the old method), `sortOrder` gets written but `priorityWeight` does not. Test must verify priorityWeight was written, not just sortOrder.
**How to avoid:** Replace the call site. Do not just extend `reorderAll` with a default parameter for priorityWeight — the signature change would break the existing test `AdjustmentsSection 'renders "Finish review" button'` if it asserts the method signature. A new `reorderAllWithPriority` is safer and more explicit.

### Pitfall 4: DonutChart test — existing test assumes 2 goals + notSpent = 3 legend rows
**What goes wrong:** `quarterly_review_test.dart` line 109: `expect(find.text('Exercise'), findsOneWidget)` — the existing test passes `goals: goals` (active only). After the constructor change adds `archivedGoals` and `commitmentBlocks`, the old call sites must be updated to pass the new required parameters.
**How to avoid:** Plan must include updating existing quarterly_review_test.dart call sites to pass `archivedGoals: const []` and `commitmentBlocks: const []` (empty defaults satisfy the new contract and keep old tests green).

### Pitfall 5: DataSection constructor change cascades to test
**What goes wrong:** `DataSection` currently receives `goals` only. If its constructor changes to also require `archivedGoals` and `commitmentBlocks`, existing widget tests that pump `DataSection` break.
**How to avoid:** Add the new params as required params and update all call sites in `quarterly_review_screen.dart` and `quarterly_review_test.dart`.

### Pitfall 6: _loadData reads GoalsNotifier.goals synchronously but archived goals asynchronously
**What goes wrong:** `context.read<GoalsNotifier>().goals` is sync; `getArchivedGoals()` is async. Both are called inside the async `_loadData()` — no ordering problem since `_loadData` is already `async`. But `context.read` inside an async gap (after an `await`) is a Flutter anti-pattern that can throw if the widget is unmounted.
**How to avoid:** Read `context.read<GoalsNotifier>()` and `context.read<CommitmentsNotifier>()` at the start of `_loadData()` before any `await`, store as local variables, then call async methods on the stored notifier reference:
```dart
final goalsNotifier = context.read<GoalsNotifier>();
final commitmentsNotifier = context.read<CommitmentsNotifier>();
final allLogs = await HiveCompletionLogRepository().getAll();
final archivedGoals = await goalsNotifier.getArchivedGoals();
final commitmentBlocks = commitmentsNotifier.blocks; // sync, already loaded
```

---

## Code Examples

### Verified: GoalsNotifier.getArchivedGoals() [VERIFIED: lib/providers/goals_notifier.dart]

```dart
/// Returns archived goals sorted by name. Does NOT call notifyListeners.
Future<List<Goal>> getArchivedGoals() async {
  final all = await _repository.getAll();
  final archived = all.where((g) => g.isArchived).toList();
  archived.sort((a, b) => a.name.compareTo(b.name));
  return archived;
}
```

This is already implemented and does exactly what the review needs.

### Verified: Commitment attribution in logs [VERIFIED: lib/data/models/completion_log.dart + STATE.md Phase 10-01]

```dart
// From STATE.md Phase 10-01:
// All three mark* sites use chunk.commitmentId ?? chunk.goalId ?? ''
// → for a commitment chunk: log.goalId == CommitmentBlock.id
// → for a goal chunk: log.goalId == Goal.id
// → CompletionLog.goalId is String (non-nullable)
```

### Verified: Schedule generator priorityWeight usage [VERIFIED: lib/services/schedule_generator.dart lines 266-272, 307-313]

```dart
// Outcome urgency — READS priorityWeight:
double urgencyScore(Goal g) {
  if (g.deadline == null) return (g.priorityWeight ?? 0.5) * 0.1;
  final daysRemaining = max(1, g.deadline!.difference(date).inDays);
  return (g.priorityWeight ?? 0.5) / daysRemaining.toDouble();
}

// Time-target tiebreaker — READS priorityWeight:
return (b.priorityWeight ?? 0.5).compareTo(a.priorityWeight ?? 0.5);
```

### Verified: Linear-spread formula from UI-SPEC [VERIFIED: lib/screens/quarterly_review/11-UI-SPEC.md]

```
priorityWeight[i] = high - (high - low) * i / (n - 1)   when n > 1
priorityWeight[0] = high                                  when n == 1
high = 0.75, low = 0.25
```

### Verified: pumpWithMood test helper signature [VERIFIED: test/test_helpers/mood_pump.dart]

```dart
Future<void> pumpWithMood(
  WidgetTester tester,
  Widget child, {
  int moodIndex = 3,
  Iterable<ChangeNotifierProvider> extraProviders = const [],
}) async { ... }
```

Used by all existing quarterly_review_test.dart tests — new tests should follow the same pattern.

### Verified: In-memory GoalRepository pattern [VERIFIED: test/repositories/goal_repository_test.dart + test/screens/cold_launch_morning_loop_test.dart]

```dart
class _InMemoryGoalRepository implements GoalRepository {
  final Map<String, Goal> _store = {};
  @override Future<List<Goal>> getAll() async => _store.values.toList();
  @override Future<Goal?> getById(String id) async => _store[id];
  @override Future<void> save(Goal goal) async => _store[goal.id] = goal;
  @override Future<void> delete(String id) async => _store.remove(id);
  @override Future<List<Goal>> getActive() async =>
      _store.values.where((g) => !g.isArchived).toList();
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact for Phase 11 |
|--------------|------------------|---------------------|
| `donut_chart.dart` iterates only active goals | Must iterate all log keys, resolved against 3 lookup sets | Primary REVIEW-01 edit |
| `reorderAll` writes sortOrder only | `reorderAllWithPriority` writes sortOrder + priorityWeight | REVIEW-02 fix |
| `_loadData` reads active goals from provider only | Must also load archived goals and commitments | REVIEW-03 fix |
| Empty guard: `totalCompleted == 0 && goals.isEmpty` | Guard: `allLogs.isEmpty` | REVIEW-03 correctness |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (Flutter SDK built-in) |
| Config file | none — default Flutter test runner |
| Quick run command | `flutter test test/services/quarterly_aggregation_test.dart test/screens/quarterly_review_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REVIEW-01 | Donut slices sum to 100% with commitment + archived chunks | unit (pure Dart) | `flutter test test/services/quarterly_aggregation_test.dart` | Partially — aggregation tests exist; new donut-sum test needed |
| REVIEW-01 | DonutChart renders commitment slice label | widget | `flutter test test/screens/quarterly_review_test.dart` | Partially — chart tests exist; new commitment/archived slice tests needed |
| REVIEW-01 | DonutChart renders archived-goal slice with "(archived)" suffix | widget | `flutter test test/screens/quarterly_review_test.dart` | No — Wave 0 gap |
| REVIEW-02 | priorityWeight changes outcome goal ordering in generated schedule | unit (pure Dart) | `flutter test test/services/schedule_generator_test.dart` | Partially — generator tests exist; REVIEW-02 ordering-change test needed |
| REVIEW-02 | reorderAllWithPriority writes correct priorityWeight values | unit | `flutter test test/repositories/goal_repository_test.dart` | No — Wave 0 gap |
| REVIEW-03 | Cold-launch review loads correct data without prior tab visit | widget | `flutter test test/screens/quarterly_review_test.dart` or new file | No — Wave 0 gap |

### Wave 0 Gaps

- [ ] New test in `test/screens/quarterly_review_test.dart` — `DonutChart` with commitment logs renders "Commitments" slice (REVIEW-01)
- [ ] New test in `test/screens/quarterly_review_test.dart` — `DonutChart` with archived goal logs renders "{name} (archived)" slice (REVIEW-01)
- [ ] New test in `test/screens/quarterly_review_test.dart` — DonutChart percentages sum to 100 across all slice types (REVIEW-01)
- [ ] New test in `test/services/schedule_generator_test.dart` — setting top priorityWeight produces first position in outcome sort (REVIEW-02)
- [ ] New test asserting `reorderAllWithPriority` writes correct linear-spread weights (REVIEW-02) — can be a unit test in `test/repositories/goal_repository_test.dart` or a new provider test file
- [ ] New widget test: pump `QuarterlyReviewScreen` with pre-loaded in-memory providers (no GoalsScreen pumped first) and assert chart data appears (REVIEW-03)

### Sampling Rate
- **Per task commit:** `flutter test test/services/quarterly_aggregation_test.dart test/screens/quarterly_review_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 11 |
|-----------|-------------------|
| State management: Provider + ChangeNotifier | All notifier work stays in GoalsNotifier; no new state management library |
| Routing: single-screen MaterialApp with no routing library | Actually uses go_router (CLAUDE.md is slightly stale — router.dart exists). `/review` route unchanged. |
| Theme: Material 3, ColorScheme.fromSeed | Commitments slice `const Color(0xFF607D8B)`, Other slice `const Color(0xFFBDBDBD)` per UI-SPEC |
| Linting: `package:flutter_lints` | Run `flutter analyze` after edits |
| Code format: `dart format lib/` | Run before committing |
| Tests: `flutter test` | Full suite must pass |
| Dart SDK: `^3.10.3` | No version issues; all patterns used are stable Dart 3 |

---

## Open Questions (RESOLVED)

> Both questions are resolved in the Phase 11 plans: Q1 → 11-01 Task 2 guards the "Time not spent" slice with `if (notSpentCount > 0)` (omit zero-value slices consistently); Q2 → 11-01 Task 3 keeps `reorderAll` unchanged and adds `reorderAllWithPriority` alongside it.

1. **Should `notSpentCount == 0` also suppress the "Time not spent" slice?**
   - What we know: Current code unconditionally adds the slice. UI-SPEC says zero-value slices should be omitted.
   - What's unclear: Whether the "Time not spent" slice has special "always visible" semantic (honest reporting even when zero).
   - Recommendation: Omit zero-value slices consistently including Time not spent. Zero chunks skipped/deferred is a valid data state and doesn't need a visible slice.

2. **`reorderAll` backward compatibility — keep or replace?**
   - What we know: `reorderAll` is called from `AdjustmentsSection._finish()` only. No other call sites found in lib/ or test/.
   - What's unclear: Whether the old `reorderAll` should be kept (for any future use) or superseded.
   - Recommendation: Keep `reorderAll` as-is (it's tested in the existing AdjustmentsSection widget tests via the provider mock) and add `reorderAllWithPriority` as a new method. Update only the `_finish()` call site.

---

## Environment Availability

Step 2.6: Skipped. This is a code/config-only phase — no external services, databases, or CLI utilities beyond the existing Flutter/Dart toolchain are introduced. Flutter/Dart path: `/home/dan/development/flutter/bin` (per project memory).

---

## Assumptions Log

All claims in this research were verified by direct source file inspection. No WebSearch or training-knowledge-only claims are present.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | (none) | — | — |

**All claims in this research were verified from codebase source files — no user confirmation needed.**

---

## Sources

### Primary (HIGH confidence — codebase inspection)

- `lib/screens/quarterly_review/widgets/donut_chart.dart` — slice construction loop, totalValue calc, legend rendering
- `lib/screens/quarterly_review/quarterly_review_screen.dart` — `_loadData()` full body, `_hasData` guard at line 84
- `lib/screens/quarterly_review/sections/adjustments_section.dart` — `_finish()` body, `reorderAll` call site
- `lib/services/schedule_generator.dart` lines 266–272, 307–313 — `priorityWeight` usage confirmed
- `lib/providers/goals_notifier.dart` — `reorderAll`, `getArchivedGoals`, `goals` getter
- `lib/data/models/completion_log.dart` — `goalId` field is non-nullable String, no separate commitmentId
- `lib/data/models/goal.dart` — `priorityWeight` field (HiveField 5), `sortOrder` (HiveField 6)
- `lib/main.dart` — GoalsNotifier + CommitmentsNotifier loaded before runApp confirmed at lines 55–59
- `lib/providers/commitments_notifier.dart` — `blocks` getter, `loadBlocks()` pattern
- `.planning/phases/11-honest-long-loop/11-UI-SPEC.md` — slice color contract, linear-spread formula, constructor changes
- `.planning/phases/11-honest-long-loop/11-CONTEXT.md` — locked decisions
- `test/screens/quarterly_review_test.dart` — existing test structure, DonutChart call sites (constructor compat)
- `test/test_helpers/mood_pump.dart` — `pumpWithMood` helper signature
- `test/screens/cold_launch_morning_loop_test.dart` — in-memory provider test pattern

---

## Metadata

**Confidence breakdown:**
- Edit sites and bug causes: HIGH — read directly from source
- Fix approach: HIGH — follows patterns already established in codebase (reorderAll, getArchivedGoals, in-memory test repos)
- Test patterns: HIGH — existing test files provide exact templates

**Research date:** 2026-06-11
**Valid until:** 2026-07-11 (stable domain; no external dependencies)
