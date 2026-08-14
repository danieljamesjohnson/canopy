# Phase 21: Mood-Scaled Breaks & Honest Rationale - Pattern Map

**Mapped:** 2026-08-07
**Files analyzed:** 2 (1 modified production file, 1 modified test file — no new files this phase)
**Analogs found:** 2 / 2 (both are in-file self-analogs; see scope note)

This phase creates no new files. The "analog" for each change is the file's own existing
sibling pattern — the executor should match the surrounding idiom exactly rather than
import a foreign style. Both patterns live in the same two files that get modified.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `lib/services/schedule_generator.dart` (edit: `_moodBreakCadence` table + `longBreakEvery` lookup) | service (pure Dart, deterministic engine) | transform (in-memory list → in-memory list) | `_moodCap` table + `_effectiveCap` lookup, same file, lines 24-38 | exact — identical shape, same file, same class |
| `lib/services/schedule_generator.dart` (edit: `_timeTargetRationale` return string) | service (string-building helper) | transform | `_outcomeRationale`, same file, lines 170-176 | exact — sibling rationale helper, same call convention |
| `test/services/schedule_generator_test.dart` (new cadence + structure tests) | test | request-response (generate() call → assert on returned `List<ScheduledChunk>`) | `Test 6` (lines 190-216) and `WR-01` (lines 497-546), same file | exact — same test file, same `sut.generate()` call shape |

## Pattern Assignments

### `lib/services/schedule_generator.dart` — BREAK-01 (mood-scaled `longBreakEvery`)

**Analog:** `_moodCap` table, same file, lines 24-38.

**Existing table pattern to mirror** (lines 24-28):
```dart
/// Capacity table: maps moodIndex → max discretionary work chunks at 80%.
///
/// Raw max:  mood 1=6, 2=8, 3=10, 4=12, 5=14
/// 80% cap:  mood 1=4, 2=6, 3=8,  4=9,  5=11
static const Map<int, int> _moodCap = {1: 4, 2: 6, 3: 8, 4: 9, 5: 11};
```

**Existing lookup-with-fallback pattern to mirror** (lines 34-38, `_effectiveCap`):
```dart
int _effectiveCap(int moodIndex, bool lighterDay) {
  if (!lighterDay) return _moodCap[moodIndex] ?? 8;
  final lowerMood = (moodIndex - 1).clamp(1, 5);
  return _moodCap[lowerMood] ?? _moodCap[moodIndex]!;
}
```
Note the `?? 8` defensive default matches `_moodCap[3]` (the neutral/middle value) — the new
table should default the same way (`?? 4`, since 4 is `_moodBreakCadence[3]` under the
recommended mapping).

**Exact site being replaced** (lines 218-220, inside `generate()`):
```dart
final int cap = _effectiveCap(moodIndex, lighterDay);
final bool isLowMood = moodIndex <= 2;
final int longBreakEvery = isLowMood ? 3 : 4;
```
Replace only the third line. Do **not** touch `isLowMood` — it is read again at multiple other
sites in the same method (habit demand, outcome inclusion, restorative floor, FILL-01/FILL-02
clamps — see RESEARCH.md "Anti-Patterns to Avoid"). New code should read:
```dart
final int longBreakEvery = _moodBreakCadence[moodIndex] ?? 4;
```
with `_moodBreakCadence` declared as a `static const Map<int, int>` field alongside `_moodCap`
(lines 24-28), using the same doc-comment style (a table in the comment, then the map literal).

**Class-level doc comment also needs updating** (lines 21-22 — stale after this change):
```dart
/// After allocation, a break insertion pass interleaves shortBreak / longBreak
/// chunks between every work chunk. longBreakEvery = 3 for mood 1-2, 4 for 3-5.
```
Rewrite this sentence to describe the new 5-point table, mirroring how `_moodCap`'s own
doc comment (lines 24-27) states its full table inline.

**Consumption site — do not touch, cadence value flows straight through** (`_assignSyntheticStartTimes`, lines 649-742; the modulus itself at lines 716-723):
```dart
int discIdx = 0;
int breakCount = 0;
for (final slot in slots) {
  cursor = slot.start;
  while (cursor + 25 <= slot.end && discIdx < discretionaryChunks.length) {
    discretionaryChunks[discIdx].syntheticStartMinutes = cursor;
    cursor += 25;
    breakCount++;
    final isLong = breakCount % longBreakEvery == 0;
    final breakDur = isLong ? 25 : 5;
    if (cursor + breakDur <= slot.end &&
        discIdx + 1 < discretionaryChunks.length) {
      discretionaryChunks[discIdx].reservedBreakMinutes = breakDur;
      cursor += breakDur;
    }
    discIdx++;
  }
}
```
`longBreakEvery` is passed into this method as a parameter (declared at line 652,
`required int longBreakEvery`) and used only as a modulus divisor — no special-casing by
value, so changing the source table is sufficient with no changes here. The `25`/`5`
duration literals at line 723 are BREAK-02's boundary — they must not move.

---

### `lib/services/schedule_generator.dart` — TONE-01 (rationale reframe)

**Analog:** `_outcomeRationale`, same file, immediately above, lines 170-176 — the sibling
rationale helper whose voice/format the TONE-01 replacement should match:
```dart
String _outcomeRationale(Goal goal, DateTime date) {
  if (goal.deadline == null) return 'Working toward your goal';
  final days = goal.deadline!.difference(date).inDays.clamp(0, 9999);
  if (days == 0) return 'Deadline today';
  if (days == 1) return 'Deadline tomorrow';
  return 'Deadline in $days days'; // days is always >= 2 here
}
```
Note the "Working toward ..." phrasing already exists as this sibling's neutral-progress
string (line 171) — this is the voice TONE-01's replacement is explicitly modeled on
(per RESEARCH.md's locked replacement, which reuses "Working toward").

**Exact site being edited** (lines 178-191, full existing helper):
```dart
String _timeTargetRationale(
  Goal goal,
  List<CompletionLog> logs,
  DateTime date,
) {
  final completed = _completedChunksThisWeek(goal.id, logs, date);
  final completedHrs = completed * 25.0 / 60.0;
  final remaining = ((goal.weeklyHourBudget ?? 0.0) - completedHrs).clamp(
    0.0,
    double.infinity,
  );
  if (remaining < 0.1) return 'On track this week';
  return '${remaining.toStringAsFixed(1)}h behind this week';
}
```
Only line 190 (the final `return`) changes, to:
```dart
return 'Working toward ${remaining.toStringAsFixed(1)}h this week';
```
Everything above it (the `completed`/`completedHrs`/`remaining` computation and the
`< 0.1` branch on line 189) is unchanged. This helper is called from 4 sites, all within
this same file (lines 424, 456, 497, 523 per RESEARCH.md) — editing the single return
line covers every call site; no other file needs to change.

---

### `test/services/schedule_generator_test.dart` — new cadence and structure tests

**Analog A — a cadence/structure test template:** `Test 6` (lines 190-216), the closest
existing "assert exact chunk-type sequence from `sut.generate()`" test:
```dart
test(
  'Test 6: mood=3 break pattern with 4 work chunks (trailing break trimmed)',
  () {
    // Use 4 habits to generate exactly 4 work chunks.
    // lighterDay: false → cap=8, habitCeiling=4 (CAP-01), so all 4 habits fit.
    final goals = List.generate(4, (i) => makeHabit(name: 'Habit $i'));
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 3,
      date: monday,
      completionLogs: [],
      lighterDay: false,
    );
    // Verify chunk order: W SB W SB W SB W (trailing long break trimmed)
    expect(result.length, 7);
    expect(result[0].chunkType, ChunkType.work);
    expect(result[1].chunkType, ChunkType.shortBreak);
    expect(result[2].chunkType, ChunkType.work);
    expect(result[3].chunkType, ChunkType.shortBreak);
    expect(result[4].chunkType, ChunkType.work);
    expect(result[5].chunkType, ChunkType.shortBreak);
    expect(result[6].chunkType, ChunkType.work);
    // Trailing break was trimmed (READ-02)
    expect(result.last.chunkType, ChunkType.work);
  },
);
```
New cadence-low (mood 1), cadence-sunny (mood 5), and mood-2/3/4 tests should follow this
exact shape: build `goals` via the existing helpers, call `sut.generate(...)` with the
target `moodIndex`, then assert the exact `result[i].chunkType` sequence (with a `longBreak`
appearing at the position implied by the new cadence table, e.g. `result[2]` for mood 1's
cadence of 2).

**Analog B — asserting durations/no-overlap, for the BREAK-02 structure-preserved test:**
`WR-01` test (lines 497-546):
```dart
test(
  'WR-01: emitted long break matches reserved slot — no overlapping synthetic times',
  () {
    final goals = [
      ...List.generate(4, (i) => makeHabit(name: 'Habit $i')),
      makeTimeTarget(name: 'Regular', weeklyHourBudget: 5),
    ];
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 3,
      date: monday,
      completionLogs: [],
      lighterDay: false,
    );

    for (int i = 0; i + 1 < result.length; i++) {
      final a = result[i];
      final b = result[i + 1];
      final aStart = a.anchoredStartMinutes ?? a.syntheticStartMinutes ?? 9999;
      final bStart = b.anchoredStartMinutes ?? b.syntheticStartMinutes ?? 9999;
      expect(
        aStart + a.durationMinutes,
        lessThanOrEqualTo(bStart),
        reason: 'chunk $i (${a.chunkType}, dur ${a.durationMinutes}) at '
            '$aStart must not overlap chunk ${i + 1} at $bStart — reserved '
            'slot must match emitted break duration (WR-01)',
      );
    }

    final longBreaks = result.where((c) => c.chunkType == ChunkType.longBreak).toList();
    expect(longBreaks, isNotEmpty, reason: 'longBreakEvery=4 with 6 chunks must emit at least one long break');
    expect(longBreaks.first.durationMinutes, 25);
  },
);
```
For the BREAK-02 "structure preserved" test, adapt this shape but instead assert every
non-final `shortBreak`/`longBreak` chunk's `durationMinutes` is exactly `5` or `25` (no
third value) — e.g.:
```dart
for (final c in result) {
  if (c.chunkType == ChunkType.shortBreak) expect(c.durationMinutes, 5);
  if (c.chunkType == ChunkType.longBreak) expect(c.durationMinutes, 25);
}
```

**Builder helpers available (lines 25-78 of the test file) — reuse as-is, no new fixtures needed:**
```dart
Goal makeHabit({String name = 'Habit goal', double? priorityWeight}) => Goal(
  name: name,
  goalTypeIndex: GoalType.habit.index,
  priorityWeight: priorityWeight,
);

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

CommitmentBlock makeBlock({
  String name = 'Block',
  List<int> daysOfWeek = const [1, 2, 3, 4, 5],
  int startMinutes = 540, // 09:00
  int endMinutes = 600, // 10:00 — 60-min window → 2 slots
}) => CommitmentBlock(
  name: name,
  daysOfWeek: daysOfWeek,
  startMinutes: startMinutes,
  endMinutes: endMinutes,
);

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
Also available: `workChunksOf(result)` and `hasTrailingBreak(result)` (lines 80-84) —
small predicate helpers already used by several tests; reuse rather than re-deriving inline.

For the `_timeTargetRationale` new-string test, there is no existing test that asserts this
helper's exact return value (it's currently untested — confirmed in RESEARCH.md). Build one
using `makeTimeTarget(weeklyHourBudget: ...)` + `makeLog(...)` to control `remaining`, call
`sut.generate(...)`, and assert on the surfaced rationale field of the resulting chunk (the
one carrying the time-target's rationale text) rather than calling the private helper
directly — same integration-style approach `WR-01` and `Test 6` already take (nothing in
this file unit-tests private helpers in isolation).

**Setup boilerplate (top of file, lines 9-19) — reuse verbatim, do not duplicate:**
```dart
void main() {
  late ScheduleGeneratorService sut;

  // Monday 2026-03-23 — weekday == 1
  final monday = DateTime(2026, 3, 23);
  // Saturday 2026-03-28 — weekday == 6
  final saturday = DateTime(2026, 3, 28);

  setUp(() {
    sut = ScheduleGeneratorService();
  });
```

## Shared Patterns

### Mood-indexed lookup table
**Source:** `_moodCap`, `lib/services/schedule_generator.dart:24-28`
**Apply to:** The new `_moodBreakCadence` table (BREAK-01) — same `static const Map<int, int>`
shape, same doc-comment style (a small table in the comment above the literal), same
`?? <neutral-default>` fallback convention used at its call site.

### Rationale-helper string convention
**Source:** `_outcomeRationale`, `lib/services/schedule_generator.dart:170-176`
**Apply to:** `_timeTargetRationale`'s replacement return string (TONE-01) — short, present-tense,
"Working toward ..." framing register; no "behind"/deficit language anywhere in this file's
rationale helpers after this change.

### Integration-style test assertions (no private-helper unit tests)
**Source:** `Test 6` and `WR-01`, `test/services/schedule_generator_test.dart:190-216, 497-546`
**Apply to:** All new tests in this phase — assert against `sut.generate(...)`'s returned
`List<ScheduledChunk>` (chunk type sequence, `durationMinutes`, or surfaced rationale text),
never against a private method directly. This is the only test style present in the file.

## No Analog Found

None — every change in this phase has a direct, same-file sibling pattern to copy (see
File Classification above). No file in this phase lacks a close analog.

## Metadata

**Analog search scope:** `lib/services/schedule_generator.dart`, `test/services/schedule_generator_test.dart` (both files read in full/targeted sections this session; no other files needed — this phase's own scope note and RESEARCH.md confirmed no other production or test file is touched)
**Files scanned:** 2
**Pattern extraction date:** 2026-08-07
