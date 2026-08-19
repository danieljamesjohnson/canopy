# Phase 28: The Day Is a Lattice - Pattern Map

**Mapped:** 2026-08-19
**Files analyzed:** 3 (1 production file modified, 1 test file modified, 1 model verified unchanged)
**Analogs found:** N/A — this phase is a narrow, deep edit to existing files, not new-file creation.
The "pattern map" here is the current-state excerpt of each edit site plus the closest existing
test to model new tests on.

## File Classification

| File | Role | Data Flow | Change Type | Notes |
|------|------|-----------|-------------|-------|
| `lib/services/schedule_generator.dart` | service | transform (pure arithmetic, no I/O) | modify (2 methods: `generate()`, `_assignSyntheticStartTimes`) | 761 lines total; all excerpts below quoted verbatim with line numbers as of commit `0cba546` |
| `test/services/schedule_generator_test.dart` | test | request-response (unit, sync `sut.generate(...)`) | modify (rewrite ~10 tests) + add (2 new assertion groups + 1 cardinality regression test) | 2165 lines, 62 tests; house style extracted below |
| `lib/data/models/scheduled_chunk.dart` | model | CRUD (Hive-backed, but `reservedBreakMinutes` is NOT persisted) | read-only reference (no change expected) | Confirms `reservedBreakMinutes` has no `@HiveField` — no migration needed |
| Widget test for D-06 smoke check | test | request-response | analog only, may add | `test/screens/cold_launch_morning_loop_test.dart` is the closest harness that renders a generated day end-to-end |

## Pattern Assignments

### `lib/services/schedule_generator.dart` — internal structure map

The whole phase lives inside `generate()`'s STEP A–E pipeline (lines 590–658) and
`_assignSyntheticStartTimes` (lines 660–759). Quoting every named site verbatim so the executor
edits the real current text, not a remembered version.

#### Site 1 — Defect 1 & 2: `breakDur` computation (packing loop)

**Current form**, `_assignSyntheticStartTimes`, lines 731–750:
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
        // Reserve the break footprint only when it fits AND more discretionary
        // chunks remain to be placed. Record the reserved duration so STEP C
        // emits the matching break; leaving it null means STEP C emits none.
        if (cursor + breakDur <= slot.end &&
            discIdx + 1 < discretionaryChunks.length) {
          discretionaryChunks[discIdx].reservedBreakMinutes = breakDur;
          cursor += breakDur;
        }
        discIdx++;
      }
    }
```
- Line 740 `final breakDur = isLong ? 25 : 5;` is **Defect 1** (should be 30, not 25) combined with
  **Defect 2** (replaces the short break instead of following it — RESEARCH.md's recommended fix
  is `5 + (isBoundary ? 30 : 0)`, additive).
- Lines 744–745 `if (cursor + breakDur <= slot.end && discIdx + 1 < discretionaryChunks.length)` —
  the `discIdx + 1 < discretionaryChunks.length` guard is **Defect 3** (silently suppresses the
  long break when it would land last). RESEARCH.md's recommendation: remove this guard entirely
  (STEP E's narrowed trim, below, becomes the only trim mechanism, and it explicitly preserves a
  trailing long break).

#### Site 2 — STEP C: break-chunk emission, threshold decode

**Current form**, `generate()`, lines 612–643:
```dart
    // STEP C: Build result — commitment chunks (no breaks between them),
    // then interleave breaks for discretionary chunks only.
    //
    // WR-01: the break for each discretionary chunk is driven entirely by the
    // reservedBreakMinutes recorded during packing — the single source of truth
    // for the cadence. We do NOT recompute the long-break cadence here with an
    // independent counter (which could diverge from the reserved slot and emit
    // a 25-min long break where only 5 minutes were reserved, overlapping the
    // next chunk after the sort). A null reservation means the packing pass
    // reserved no break room after this chunk, so no break is emitted.
    final List<ScheduledChunk> result = [...commitmentChunks];
    for (final chunk in discretionaryChunks) {
      result.add(chunk);
      final reserved = chunk.reservedBreakMinutes;
      if (reserved == null) continue; // no break room was reserved
      final isLong = reserved >= 25;
      final breakChunk = ScheduledChunk(
        chunkTypeIndex: isLong
            ? ChunkType.longBreak.index
            : ChunkType.shortBreak.index,
        goalId: null,
        durationMinutes: reserved,
        rationale: '',
      );
      // Position the break immediately after its preceding work chunk so the
      // Step D sort keeps it adjacent (and within the reserved footprint).
      if (chunk.syntheticStartMinutes != null) {
        breakChunk.syntheticStartMinutes =
            chunk.syntheticStartMinutes! + chunk.durationMinutes;
      }
      result.add(breakChunk);
    }
```
- Line 627 `final isLong = reserved >= 25;` — this threshold interpretation must change entirely
  once `reservedBreakMinutes` becomes a *footprint* (5 = ordinary, 35 = cadence boundary) rather
  than a single duration. Per RESEARCH.md Pitfall 4: do not patch `>= 25` in place — replace the
  whole block with a decode that emits **one or two** break chunks (short, then long, each with
  its own `syntheticStartMinutes`) when `reserved > 5`.
- The existing WR-01 doc comment (lines 615–621) is a load-bearing invariant: STEP C must keep
  reading `reservedBreakMinutes` as the single source of truth and must NOT recompute
  `breakCount % longBreakEvery` independently. Preserve this comment's intent when rewriting.

#### Site 3 — STEP E: trailing-chunk trim (D-05)

**Current form**, `generate()`, lines 652–655:
```dart
    // STEP E: Trim trailing non-work chunks (no dangling break at end).
    while (result.isNotEmpty && result.last.chunkType != ChunkType.work) {
      result.removeLast();
    }
```
Per D-05 / RESEARCH.md's recommended fix, narrow to short-breaks-only so a trailing long break
survives:
```dart
    while (result.isNotEmpty && result.last.chunkType == ChunkType.shortBreak) {
      result.removeLast();
    }
```
This must land together with Site 1's Defect 3 fix — see RESEARCH.md Pitfall 2: fixing the packing
guard without narrowing this trim reproduces Defect 3 by a different path.

#### Site 4 — `startFloorMinutes` rounding (D-03)

**Current form**, `_assignSyntheticStartTimes`, lines 672–679:
```dart
    const int defaultDayStart = 480; // 8:00 AM
    const int dayEnd = 1320; // 10:00 PM
    // Start packing at "now" when generating mid-day so the plan doesn't lay
    // chunks down in already-passed morning hours. Never earlier than 8:00 AM,
    // and round up to the next 5-minute boundary for tidy start times.
    final int dayStart = startFloorMinutes == null
        ? defaultDayStart
        : (((startFloorMinutes + 4) ~/ 5) * 5).clamp(defaultDayStart, dayEnd);
```
Per D-03, change the rounding granularity from 5 to 30:
```dart
    final int dayStart = startFloorMinutes == null
        ? defaultDayStart
        : (((startFloorMinutes + 29) ~/ 30) * 30).clamp(defaultDayStart, dayEnd);
```
The doc comment ("round up to the next 5-minute boundary") must be updated to say 30-minute — stale
comments here are exactly what misled this bug into existing in the first place.

#### Site 5 — Post-commitment free-slot start rounding (D-02)

**Current form**, `_assignSyntheticStartTimes`, lines 710–722:
```dart
    // Derive free slots from dayStart to dayEnd around commitment windows.
    // Clamp the cursor so it never moves backward (WR-02): with merged windows
    // this is already monotonic, but the clamp is defensive against any future
    // window source and guarantees no negative-width slot is ever emitted.
    final slots = <({int start, int end})>[];
    int cursor = dayStart;
    for (final w in windows) {
      if (cursor < w.start) {
        slots.add((start: cursor, end: w.start));
      }
      cursor = cursor > w.end ? cursor : w.end;
    }
    slots.add((start: cursor, end: dayEnd));
```
Per D-02, the line `cursor = cursor > w.end ? cursor : w.end;` must round the post-window cursor
up to the next 30-minute boundary (e.g. `cursor = _roundUpTo30(cursor > w.end ? cursor : w.end);`
or inline the `((x + 29) ~/ 30) * 30` expression — reuse whatever helper Site 4 introduces rather
than duplicating the rounding formula a third time). Note this only applies to the *free-slot*
start, never to `w.start`/`w.end` themselves (those come from `anchoredStartMinutes`, which stays
unrounded per D-01/A1 — commitment chunks are never moved).

#### `_moodCap` / day-end — explicitly NOT touched (D-04)

No excerpt needed as a change site — `_moodCap` (line 29) and `dayEnd` (line 673, `1320`) are
**not modified** by this phase. Do not let a diff touch these constants; if a plan task appears to
require it, D-04 is the deliberate answer: no.

---

### `lib/data/models/scheduled_chunk.dart` — `reservedBreakMinutes` field

**Verbatim, lines 73–77:**
```dart
  // Duration (minutes) of the break reserved AFTER this discretionary work
  // chunk during the packing pass; NOT stored in Hive. Single source of truth
  // for the long-break cadence so the break emitted in STEP C matches the slot
  // room reserved during packing (WR-01). null = no break reserved.
  int? reservedBreakMinutes;
```
**Confirmed: this field carries no `@HiveField(n)` annotation** (contrast with every other field
on this class, e.g. `@HiveField(10) int? syntheticStartMinutes;` immediately above it at lines
62–64). It is plain Dart scratch state on a `HiveObject` subclass — Hive's code generator
(`scheduled_chunk.g.dart`) never serializes it. **No Hive migration is needed** for changing what
this field's integer value *means* (single duration → footprint encoding). If a future phase ever
needs to persist it, the project's Hive migration convention lives in `lib/data/database/` (not
read in this pass — no migration is needed here, so it was not required as an analog).

---

### `reservedBreakMinutes` — every read/write site (for the D-06 cardinality risk)

Exhaustive grep across `lib/` and `test/`:

| Site | File:Line | What it assumes |
|------|-----------|------------------|
| Declaration | `lib/data/models/scheduled_chunk.dart:77` | Single nullable `int`; not persisted. No change needed to the model. |
| Write | `lib/services/schedule_generator.dart:746` | Writes one value per chunk during packing — this is Site 1 above. Becomes the footprint value (5 or 35). |
| Read (comment only) | `lib/services/schedule_generator.dart:616` | Doc comment describing WR-01 invariant — update wording if the "one break" framing changes to "one or two breaks." |
| Read | `lib/services/schedule_generator.dart:625` | `final reserved = chunk.reservedBreakMinutes;` — this is Site 2 above, the only real *consumer* in production code. |
| Read (comment only) | `lib/services/schedule_generator.dart:728` | Doc comment above the packing loop — update to describe footprint encoding. |

**No other production file reads `reservedBreakMinutes`.** Grep across all of `lib/` and `test/`
found exactly these 5 matches, all inside `schedule_generator.dart` and its own model. This means
the D-06 cardinality risk (two consecutive break chunks at a boundary) is **not** a
`reservedBreakMinutes`-consumer risk — no other file inspects that field. The actual risk surface
for D-06 is downstream code that assumes the **emitted chunk sequence** never has two consecutive
non-work chunks (`ChunkType.shortBreak` immediately followed by `ChunkType.longBreak`). The
existing `BREAK-02` test (see below) already has an assertion of exactly this shape — "every break
must be preceded by a work chunk" — which will need to become "every break is preceded by a work
chunk OR a short break that is itself part of a cadence-boundary pair," i.e. this exact assertion
in `BREAK-02` (lines 2084–2094) is the one existing guard that actively encodes the "no two
adjacent breaks" assumption D-06 is now deliberately breaking. It must be rewritten, not just
left to go red.

No `ScheduledChunk` consumer outside `schedule_generator.dart`/its test file was found to branch on
chunk-adjacency/cardinality (confirmed by RESEARCH.md's own grep of the presentation layer —
`ChunkType` is rendered generically). Treat `BREAK-02`'s adjacency assertion as the one concrete
site to fix; no other production file needs changes for D-06.

---

### `test/services/schedule_generator_test.dart` — house style

**Imports** (lines 1–7):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:canopy/data/models/completion_log.dart';
import 'package:canopy/data/models/energy_valence.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/services/schedule_generator.dart';
```

**Fixture builders** (lines 9–84) — reuse these, do not redefine:
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

  Goal makeHabit({String name = 'Habit goal', double? priorityWeight}) => Goal(
    name: name,
    goalTypeIndex: GoalType.habit.index,
    priorityWeight: priorityWeight,
  );
  // ...makeOutcome, makeBlock, makeTimeTarget, makeLog — same shape, named-param
  // factories over the real Goal/CommitmentBlock/CompletionLog constructors.

  int workChunksOf(List<ScheduledChunk> result) =>
      result.where((c) => c.chunkType == ChunkType.work).length;

  bool hasTrailingBreak(List<ScheduledChunk> result) =>
      result.isNotEmpty && result.last.chunkType != ChunkType.work;
```
There is no mood-fixture helper — every test passes `moodIndex:` directly to `sut.generate(...)`.
New LATTICE-01/LATTICE-02 assertion groups should follow the `BREAK-02` pattern of a `for (int
mood = 1; mood <= 5; mood++)` loop over one call each, not five separate `test(...)` blocks,
since the assertion is identical across moods (see BREAK-02 excerpt below as the template).

**Naming/requirement-tag convention:** `'REQID-NN: description'` as the `test()` name string, e.g.
`'BREAK-01: mood=1 places a long break after every 2 work chunks'`, `'BREAK-02: only 5-min short
breaks...'`. Use `'LATTICE-01: ...'` / `'LATTICE-02: ...'` for the new tests to match.

**Representative full test #1 — single-fixture-sequence style** (`Test 6`, lines 190–216, WILL go
RED and needs rewriting per Blast Radius — quoted here as the template for the shape of a
sequence-assertion test):
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
Under the fixed lattice, mood=3/N=4 with exactly 4 discretionary chunks means chunk 4 is the
cadence boundary AND the last chunk — per D-05/D-06 the long break now survives. New expected
sequence: `W SB W SB W SB W SB LB` (`result.length == 9`, `result.last.chunkType ==
ChunkType.longBreak`, `result[7].durationMinutes == 5`, `result[8].durationMinutes == 30`).

**Representative full test #2 — cadence-pinning style** (`BREAK-01: mood=1`, lines 1842–1876 —
also WILL go RED, quoted as the template for a single-mood cadence test):
```dart
  test('BREAK-01: mood=1 places a long break after every 2 work chunks', () {
    // lighterDay: false -> cap=4, habitCeiling=ceil(4/2)=2 (CAP-01).
    // 2 habits fill the habitCeiling exactly (2 chunks). mood=1 is low-mood,
    // so FILL-01 clamps each time-target to 1 chunk: 2 time-targets -> 2
    // chunks. Total discretionary = 2 + 2 = 4 work chunks (== cap).
    final goals = [
      ...List.generate(2, (i) => makeHabit(name: 'Habit $i')),
      ...List.generate(
        2,
        (i) => makeTimeTarget(name: 'Regular $i', weeklyHourBudget: 5),
      ),
    ];
    final result = sut.generate(
      goals: goals,
      blocks: [],
      moodIndex: 1,
      date: monday,
      completionLogs: [],
      lighterDay: false,
    );
    expect(result.length, 7);
    expect(result[0].chunkType, ChunkType.work);
    expect(result[1].chunkType, ChunkType.shortBreak);
    expect(result[2].chunkType, ChunkType.work);
    expect(result[3].chunkType, ChunkType.longBreak);
    expect(result[4].chunkType, ChunkType.work);
    expect(result[5].chunkType, ChunkType.shortBreak);
    expect(result[6].chunkType, ChunkType.work);
    expect(
      result[3].durationMinutes,
      25,
      reason: 'mood=1 must reach a long break after 2 work chunks (BREAK-01)',
    );
    expect(result[1].durationMinutes, 5);
  });
```
Note the goal-count arithmetic comment convention ("lighterDay: false -> cap=N, habitCeiling=...")
— every test in this file explains *why* its fixture produces the exact chunk count it does. New
tests must carry the same style of comment; do not add a fixture without deriving its expected
count in a comment.

**Representative full test #3 — mood-loop assertion style** (`BREAK-02`, lines 2042–2103, WILL go
RED at the adjacency check — quoted as the direct template for the new LATTICE-01/LATTICE-02
assertion groups, which should loop moods 1–5 the same way):
```dart
  test(
    'BREAK-02: only 5-min short breaks and 25-min long breaks are ever emitted, at every mood',
    () {
      final goals = [
        ...List.generate(6, (i) => makeHabit(name: 'Habit $i')),
        ...List.generate(
          2,
          (i) => makeTimeTarget(name: 'Regular $i', weeklyHourBudget: 5),
        ),
      ];
      for (int mood = 1; mood <= 5; mood++) {
        final result = sut.generate(
          goals: goals,
          blocks: [],
          moodIndex: mood,
          date: monday,
          completionLogs: [],
          lighterDay: false,
        );

        for (final chunk in result) {
          expect(
            [ChunkType.work, ChunkType.shortBreak, ChunkType.longBreak],
            contains(chunk.chunkType),
            reason: 'mood=$mood: unexpected chunkType ${chunk.chunkType}',
          );
          if (chunk.chunkType == ChunkType.shortBreak) {
            expect(chunk.durationMinutes, 5, reason: 'mood=$mood: short break must always be 5 minutes');
          }
          if (chunk.chunkType == ChunkType.longBreak) {
            expect(chunk.durationMinutes, 25, reason: 'mood=$mood: long break must always be 25 minutes');
          }
        }

        for (int i = 0; i + 1 < result.length; i++) {
          final aIsBreak = result[i].chunkType != ChunkType.work;
          final bIsBreak = result[i + 1].chunkType != ChunkType.work;
          expect(
            aIsBreak && bIsBreak,
            isFalse,
            reason: 'mood=$mood: two adjacent non-work chunks at index $i/${i + 1} '
                '— every break must be preceded by a work chunk',
          );
        }

        expect(result.last.chunkType, ChunkType.work,
            reason: 'mood=$mood: schedule must never end on a break chunk');
      }
    },
  );
```
Three sub-parts of this test go RED under the fix and must be rewritten (not just supplemented):
1. `chunk.durationMinutes, 25` for `longBreak` → must become `30`.
2. The adjacency loop's blanket "no two adjacent non-work chunks" invariant → must allow
   exactly the `shortBreak` immediately followed by `longBreak` shape (D-06's new cardinality),
   while still forbidding any other adjacent-break combination.
3. `expect(result.last.chunkType, ChunkType.work, ...)` → no longer universally true — per D-05, a
   trailing long break is now allowed to survive as the last chunk. This assertion must be
   dropped or changed to "last chunk is `work` or `longBreak`, never `shortBreak`."

**The `startFloorMinutes` rounding test that WILL go RED** (lines 1399–1412, quoted verbatim,
D-03's proof-RED-first target):
```dart
    test(
      'a 15:42 floor starts the chunk at 15:45 (rounded up to 5), not 8 AM',
      () {
        final chunks = sut.generate(
          goals: [habit],
          blocks: [],
          moodIndex: 3,
          date: monday,
          startFloorMinutes: 942, // 15:42
        );
        final work = chunks.firstWhere((c) => c.chunkType == ChunkType.work);
        expect(work.syntheticStartMinutes, 945); // 15:45
      },
    );
```
Per D-03, this must be rewritten to expect rounding to the next 30-minute boundary: 15:42 (942)
rounds up to 16:00 (960), not 945. New test name/body: `'a 15:42 floor starts the chunk at 16:00
(rounded up to 30), not 8 AM'`, `expect(work.syntheticStartMinutes, 960);`. This is inside the
existing `group('startFloorMinutes places discretionary work near "now"', ...)` (starts line
1385) alongside two sibling tests (`null floor keeps 480 default`, `floor earlier than 8:00 AM is
clamped to 480`) which are unaffected and should NOT be touched.

**Verified acceptance-test shapes** (RESEARCH.md's own recommended assertions, reproduced here so
the plan can lift them directly):
```dart
// LATTICE-01 — every discretionary chunk's start is on a 30-minute boundary.
for (final chunk in result) {
  if (chunk.anchoredStartMinutes != null) continue; // D-01: commitments exempt
  final start = chunk.displayStartMinutes; // scheduled_chunk.dart:71
  if (start != null) {
    expect(start % 30, 0, reason: 'chunk at $start is off-lattice');
  }
}

// LATTICE-02 — exactly floor(workCount / N) long breaks of exactly 30 minutes.
final workCount = result.where((c) => c.chunkType == ChunkType.work).length;
final longBreaks = result.where((c) => c.chunkType == ChunkType.longBreak).toList();
expect(longBreaks.length, workCount ~/ longBreakEvery);
for (final lb in longBreaks) {
  expect(lb.durationMinutes, 30);
}
```

---

### D-06 widget-test analog: `test/screens/cold_launch_morning_loop_test.dart`

Closest existing widget test that renders a day generated by the real
`ScheduleGeneratorService` end-to-end (not a hand-built fixture). If the plan includes an
automated widget-level smoke check for the new two-break cardinality (Open Question 3 /
RESEARCH.md's "Wave 0 Gaps" optional item), this is the harness to copy.

**Imports** (lines 13–28):
```dart
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/data/repositories/goal_repository.dart';
import 'package:canopy/data/repositories/in_memory_app_settings_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/goals_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/theme_notifier.dart';
import 'package:canopy/screens/schedule/checkin_screen.dart';
import 'package:canopy/services/schedule_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
```

**Harness pattern** (lines 81–136): an `_InMemoryScheduleNotifier extends ScheduleNotifier` that
overrides `init()` (no-op, skips Hive) and `generateToday(...)` to call the real
`ScheduleGeneratorService().generate(...)` and store the result in a plain in-memory field —
avoiding any real persistence I/O while still exercising the actual generator. Pair with
`_InMemoryGoalRepository` and `_InMemoryCommitmentBlockRepository` (lines 34–72) to seed exactly
the goal count needed to force a cadence boundary (e.g. reuse the `BREAK-01: mood=1` fixture
shape — 2 habits + 2 time-targets at `moodIndex: 1` — to deterministically produce the two
adjacent break chunks D-06 requires).

**Pump/assert pattern** (lines 191–230): `tester.pumpWidget(MultiProvider(providers: [...],
child: const MaterialApp(home: CheckinScreen())))`, tap the mood emoji, tap "Let's go", then
inspect the resulting `DailySchedule.chunks` (via the notifier, not by scraping widget text) for
the two-consecutive-break shape. This test does not scrape pixel/geometry — it is purely a
"nothing throws, sequence is as expected" render+data check, consistent with RESEARCH.md's
instruction that no browser/pixel step is needed for this phase.

## Shared Patterns

### Rounding-up-to-N formula (used at two, possibly three, sites)
**Source:** the existing `(((startFloorMinutes + 4) ~/ 5) * 5)` idiom at
`schedule_generator.dart:679` — the project's established "round up to N" shape. Reuse the same
idiom with `N=30` (`+29`, `~/30`, `*30`) at Site 4, and reuse it again (ideally via one small
private helper, e.g. `_roundUpTo30(int m) => ((m + 29) ~/ 30) * 30;`, to avoid a third inline
duplication) at Site 5 (post-commitment slot start). Introducing a shared private helper here is a
reasonable in-scope refactor — the two sites currently duplicate no such helper, but they will
duplicate the identical formula twice once both are fixed, and this file already has a house
style of small private helper methods (`_effectiveCap`, `_weekStart`, `_completedChunksThisWeek`,
etc.) to follow.

### "Proven RED first" convention
**Source:** `28-CONTEXT.md` D-03 and `28-RESEARCH.md`'s Blast Radius section both invoke this
project's carried-forward STATE.md convention: rewritten regression tests must be run against the
*unfixed* code first to confirm they fail (RED) before the fix lands, then confirmed to pass
(GREEN) after. Apply this to all ~10 rewritten tests, not just new ones.

### WR-01 "single source of truth" invariant
**Source:** `schedule_generator.dart:615-621` doc comment. Any rewrite of STEP C must preserve the
rule that break emission reads `reservedBreakMinutes` only — it must never independently recompute
`breakCount % longBreakEvery`. This is an existing anti-pattern warning already encoded in the
file; do not regress it while reshaping the footprint-decode logic.

## No Analog Found

Not applicable in the usual sense — every file in this phase already exists and is the direct
subject of the change (no genuinely new file/role is being introduced). The one candidate "new
file" — a dedicated widget test for D-06 — has a strong analog
(`cold_launch_morning_loop_test.dart`, above), so nothing is unmapped.

## Metadata

**Analog search scope:** `lib/services/schedule_generator.dart`,
`lib/data/models/scheduled_chunk.dart`, `test/services/schedule_generator_test.dart`,
`test/screens/cold_launch_morning_loop_test.dart`; `grep -rn reservedBreakMinutes lib/ test/`
(exhaustive, 5 matches, all accounted for above).
**Files scanned:** 4 read in full/targeted, plus 1 grep across the whole `lib/`+`test/` tree.
**Pattern extraction date:** 2026-08-19
