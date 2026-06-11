# Phase 8: A Schedule You Can Read — Research

**Researched:** 2026-06-10
**Domain:** Flutter schedule UI — chunk card legibility, schedule ordering, bottom sheets, focus mode timer
**Confidence:** HIGH (all findings grounded in codebase reads + Flutter framework knowledge)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Chunk Card & Rationale (READ-01)**
- Card title is the goal's real name, looked up by `goalId` via `GoalsNotifier`. Commitment-anchored chunks (no `goalId`) show the block name. Break cards keep "X min break".
- Secondary text is a readable static rationale ("Daily habit", "Toward your deadline", "Weekly time goal", commitment name) — replacing current generic `rationale` strings. Remain static in Phase 8; Phase 9 replaces them.
- Goal name is resolved in the screen (mirroring `_lookupGoalColor` pattern in `schedule_screen.dart`) and passed into `ChunkCard` as a parameter — keeping `ChunkCard` a pure presentational widget.
- Break cards are visually unchanged.

**Ordering & Breaks (READ-02)**
- Discretionary chunks are assigned synthetic clock times that fill the gaps around anchored commitment windows; the whole chunk list is then sorted by start time so the schedule reads top-to-bottom in day order.
- No dangling trailing break — trim any break that would follow the final work chunk.
- No breaks inside a commitment window — a commitment block chunked into contiguous 25-min pieces gets no short/long breaks injected between those pieces.
- All ordering/break logic lives in `ScheduleGeneratorService` (pure Dart, no Flutter imports).

**Detail Sheet (READ-03)**
- Presented via `showModalBottomSheet`, matching Phase 2 goal-form sheet pattern.
- Shows goal name, "why scheduled" rationale, and Complete / Skip / Defer action buttons.
- Defer is present and minimal: removes chunk from today's view (like skip) in Phase 8; next-day carryover in Phase 10 (CLOSE-02).
- Only work chunks are tappable / open a sheet; break chunks are not tappable.
- Sheet complements existing swipe/hover input; tap is the discoverable explicit path.

**Focus Mode (READ-04)**
- Entry from "Start focus" button in the detail sheet, plus a current-chunk entry affordance on the schedule screen.
- Presented as full-screen route `/focus` outside the StatefulShell.
- "Current chunk" = the first unresolved work chunk in day order.
- Optional 25-minute countdown; on finish or explicit "Done" it calls `markComplete` and surfaces a break suggestion. Auto-advance deferred to Phase 10.

### Claude's Discretion
- Exact rationale wording, focus-mode visual styling, timer controls layout, and how synthetic discretionary start times are computed — at Claude's discretion within the decisions above. Follow the brand/UI conventions surfaced by the UI-SPEC.

### Deferred Ideas (OUT OF SCOPE)
- Budget-/deadline-/priority-driven dynamic rationale strings → Phase 9.
- Full defer-to-tomorrow carryover into next morning's generated schedule → Phase 10 (CLOSE-02).
- Closed focus loop (auto-advance, evening reminders, completion logging beyond markComplete) → Phase 10.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| READ-01 | Each scheduled chunk displays its goal's name as the title, with the rationale as secondary text | `_lookupGoalName` pattern mirrors existing `_lookupGoalColor` at `schedule_screen.dart:129`; `ChunkCard` needs `goalName` param and title/rationale hierarchy inversion at line 188 |
| READ-02 | Chunks ordered in day order around anchored commitment blocks; no breaks inside commitment window; no trailing break | New `_assignSyntheticStartTimes` + sort pass in `ScheduleGeneratorService`; break-insertion pass refactored to separate commitment vs discretionary streams |
| READ-03 | Tapping a chunk opens a detail sheet with goal, rationale, and complete/skip/defer actions | New `ChunkDetailSheet` widget; `showModalBottomSheet`; new `markDeferred` method in `ScheduleNotifier`; `isDeferred` HiveField(8) in `ScheduledChunk` |
| READ-04 | Minimal companion focus mode with optional 25-min countdown → completion + break suggestion | New `FocusScreen` with `Timer.periodic` StatefulWidget; `/focus` GoRoute outside StatefulShell at `router.dart:110`-area |
</phase_requirements>

---

## Summary

Phase 8 makes the existing generated schedule legible and actionable without changing the number or types of chunks generated. All changes are UI-layer additions on top of an already-working generator — the primary risk surfaces in the ordering pass (READ-02), which requires restructuring the break-insertion pass in `ScheduleGeneratorService`, and in the Hive schema addition (HiveField 8 `isDeferred`) required for the minimal defer action.

The existing codebase patterns are consistent and well-established. `schedule_screen.dart` already resolves goal colors via `_lookupGoalColor` at line 129 — the exact same pattern resolves goal names. `ChunkCard._HoverableChunkContent` at line 188 currently uses `chunk.rationale` as the primary title; inverting the hierarchy to `goalName` primary + readable rationale secondary is a targeted, low-risk change. The break-insertion pass in `schedule_generator.dart` (lines 154-187) currently appends a break after every work chunk including the last; READ-02 requires three corrections: (a) don't insert breaks between consecutive commitment-block pieces, (b) trim the trailing break, and (c) sort the flat list by effective start time after assigning synthetic times to discretionary chunks.

The migration pattern is well-established: `currentSchemaVersion` is currently `3` in `migrations.dart:3`; adding `isDeferred` as HiveField(8) on `ScheduledChunk` requires bumping to version `4` with a no-op `_migration3to4` function and regenerating `scheduled_chunk.g.dart` via build_runner.

**Primary recommendation:** Implement READ-01, READ-02, READ-03, READ-04 in four sequential plans, starting with the data layer (generator ordering + schema), then the UI components, then routing.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Goal name resolution for cards | Frontend (screen widget) | — | Mirrors existing `_lookupGoalColor` pattern; `ChunkCard` stays a pure presentational widget |
| Synthetic start-time assignment | Service layer (`ScheduleGeneratorService`) | — | Pure Dart, no Flutter; already unit-tested in `schedule_generator_test.dart` |
| Break insertion logic | Service layer (`ScheduleGeneratorService`) | — | Same location as existing break pass; keeps generator testable in isolation |
| Chunk ordering (sort by start time) | Service layer (`ScheduleGeneratorService`) | — | Output contract of the generator; consumed by notifier and screen |
| Defer state (isDeferred field) | Data model (`ScheduledChunk`) + Notifier | Hive schema | Matches isCompleted/isSkipped pattern at HiveFields 6/7 |
| markDeferred notifier method | Provider (`ScheduleNotifier`) | — | Mirrors `markSkipped` pattern at line 143; saves schedule + notifyListeners |
| Detail sheet UI | Screen widget (`ChunkDetailSheet`) | — | `showModalBottomSheet` — Flutter presentation layer |
| Focus mode countdown timer | Screen widget (`FocusScreen`) StatefulWidget | — | Local state only; Timer.periodic in StatefulWidget; no cross-screen state needed |
| Focus route registration | Router (`router.dart`) | — | Outside StatefulShell like `/summary` at line 109 |

---

## Standard Stack

### Core (all already in pubspec.yaml — no new packages required)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/material.dart | SDK | `showModalBottomSheet`, `FilledButton`, `Timer` (via dart:async) | Built-in |
| provider ^6.1.5 | already in pubspec | `context.read<ScheduleNotifier>()` / `context.read<GoalsNotifier>()` | Project-established pattern |
| go_router ^17.1.0 | already in pubspec | `context.push('/focus', extra: chunk.id)` for focus route | Project-established pattern |
| hive_ce ^2.19.3 | already in pubspec | Hive schema addition (HiveField 8) | Project-established pattern |
| hive_ce_generator ^1.11.1 | already in dev_dependencies | build_runner regeneration of `scheduled_chunk.g.dart` | Project-established pattern |
| dart:async (Timer) | SDK built-in | `Timer.periodic` for focus countdown | Built-in; no dependency needed |

**No new pub packages are required for Phase 8.** [VERIFIED: UI-SPEC.md "Registry Safety" section]

---

## Package Legitimacy Audit

> Not applicable — Phase 8 introduces no new pub packages. All capabilities use Flutter SDK built-ins and existing project dependencies.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
User Tap (work chunk card)
        |
        v
SwipeableChunkCard (Dismissible outer) --> horizontal swipe → markComplete/markSkipped
        |
        v
ChunkCard._HoverableChunkContent (GestureDetector inner)
        |
        v
onTap callback → showModalBottomSheet → ChunkDetailSheet
        |                                       |
        |                          [Complete]   [Skip]   [Defer]   [Start focus]
        |                              |           |        |            |
        |                    markComplete  markSkipped  markDeferred   context.push('/focus', extra: chunkId)
        |                              |           |        |            |
        v                              v           v        v            v
ScheduleNotifier                  saves + notifyListeners              FocusScreen (StatefulWidget)
        |                                                                    |
        v                                                              Timer.periodic (dart:async)
schedule_screen.dart ListView rebuilds                                       |
(chunks sorted by effectiveStartMinutes)                           _secondsRemaining-- every 1s
                                                                             |
                                                            [timer hits 0 / "Done early"]
                                                                             |
                                                                  markComplete(chunkId)
                                                                  show break suggestion inline
```

### Recommended Project Structure (additions only)

```
lib/
├── screens/
│   ├── schedule/
│   │   └── widgets/
│   │       ├── chunk_card.dart          # modified: add goalName param, tap callback
│   │       ├── swipeable_chunk_card.dart # modified: pass goalName, wire onTap
│   │       └── chunk_detail_sheet.dart  # NEW
│   └── focus/
│       └── focus_screen.dart            # NEW
├── data/models/
│   ├── scheduled_chunk.dart             # modified: add isDeferred HiveField(8)
│   └── scheduled_chunk.g.dart           # regenerated
├── providers/
│   └── schedule_notifier.dart           # modified: add markDeferred method
├── services/
│   └── schedule_generator.dart          # modified: ordering + break fixes
└── router.dart                          # modified: add /focus GoRoute
```

---

### Pattern 1: Goal Name Resolution (READ-01)

Mirrors the existing `_lookupGoalColor` pattern at `schedule_screen.dart:129-135`. Add `_lookupGoalName` alongside it:

```dart
// Source: schedule_screen.dart:129 pattern — add immediately below _lookupGoalColor
String? _lookupGoalName(BuildContext context, ScheduledChunk chunk) {
  if (chunk.goalId == null) return null; // commitment chunk: use rationale as title
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.name;
}
```

`ChunkCard` receives already-resolved strings. The updated `_buildSwipeableCard` passes both:

```dart
Widget _buildSwipeableCard(BuildContext context, ScheduledChunk chunk) {
  final goalColor = _lookupGoalColor(context, chunk);
  final goalName = _lookupGoalName(context, chunk);
  return SwipeableChunkCard(chunk: chunk, goalColor: goalColor, goalName: goalName);
}
```

`ChunkCard` constructor gains `String? goalName`. At line 188, the work variant title becomes:

```dart
// Old (line 188-191 of chunk_card.dart):
chunk.rationale.isNotEmpty ? chunk.rationale : 'Work block'
// NEW primary line:
goalName ?? chunk.rationale  // goalName is the goal's real name; fallback is the commitment block name stored in rationale
// NEW secondary line (below primary):
_readableRationale(chunk.rationale)  // helper maps 'Habit' → 'Daily habit', etc.
```

Rationale mapping is a pure helper function, injected into the card via a pre-resolved `String? displayRationale` parameter to keep `ChunkCard` free of logic.

---

### Pattern 2: READ-02 Ordering Algorithm

The current generator at `schedule_generator.dart:154-188` uses a single break-insertion loop over `workChunks` in allocation order (commitments first, then discretionary). The three bugs to fix:

1. **Breaks between commitment pieces** — commitment chunks are added as adjacent 25-min slices in lines 52-67; the break loop doesn't know they're from the same block, so it inserts breaks between them.
2. **Trailing break** — the loop always appends a break after every work chunk including the last (line 160-185).
3. **No start-time assignment / sort** — discretionary chunks have `anchoredStartMinutes: null` and are returned in allocation order, not day order.

**Revised algorithm (pure Dart, no Flutter imports):**

```dart
// STEP A: Separate commitment and discretionary work chunks
// Commitment chunks already have anchoredStartMinutes set.
final List<ScheduledChunk> commitmentChunks = workChunks
    .where((c) => c.anchoredStartMinutes != null)
    .toList()
  ..sort((a, b) => a.anchoredStartMinutes!.compareTo(b.anchoredStartMinutes!));

final List<ScheduledChunk> discretionaryChunks = workChunks
    .where((c) => c.anchoredStartMinutes == null)
    .toList();

// STEP B: Assign synthetic start times to discretionary chunks.
// Build list of commitment windows: [{start, end}] sorted by start.
// Free slots: [dayStart..firstCommitment.start], gaps between windows,
//             [lastCommitment.end..dayEnd].
// Pack discretionary chunks + their breaks into free slots in sequence.
// Each discretionary work chunk: 25 min. Short break: 5 min. Long break: 25 min.
// Step = 30 min normally (25+5), 50 min after every `longBreakEvery`th chunk (25+25).

const int dayStart = 480; // 8:00 AM
_assignSyntheticStartTimes(
  discretionaryChunks: discretionaryChunks,
  commitmentWindows: commitmentChunks
      .fold<List<({int start, int end})>>([], (acc, c) {
        // Merge into block windows: commitment chunks within same block share same startMinutes block
        final blockStart = /* look up block.startMinutes */ c.anchoredStartMinutes!;
        final blockEnd = blockStart + c.durationMinutes;
        if (acc.isNotEmpty && acc.last.end == blockStart) {
          // extend existing window
          return [...acc.sublist(0, acc.length - 1), (start: acc.last.start, end: blockEnd)];
        }
        return [...acc, (start: blockStart, end: blockEnd)];
      }),
  dayStart: dayStart,
  longBreakEvery: longBreakEvery,
);

// STEP C: Interleave breaks for DISCRETIONARY chunks only.
// Commitment chunks within one block get NO breaks between them.

// STEP D: Sort final flat list by effectiveStartMinutes.
result.sort((a, b) => a.effectiveStartMinutes.compareTo(b.effectiveStartMinutes));

// STEP E: Trim trailing break.
while (result.isNotEmpty && result.last.chunkType != ChunkType.work) {
  result.removeLast();
}
```

**`effectiveStartMinutes` getter:** Add a non-stored getter to `ScheduledChunk` for sorting:

```dart
// In ScheduledChunk — NOT a HiveField, just a computed getter
int get effectiveStartMinutes => anchoredStartMinutes ?? _syntheticStartMinutes ?? 0;
```

Since `_syntheticStartMinutes` is only needed transiently during generation, the simplest approach is to set `anchoredStartMinutes` on discretionary chunks too (with the synthetic value) so the sort uses the same field. The UI-SPEC confirms commitment secondary text shows `_formatMinutes(anchoredStartMinutes)` — discretionary chunks don't show a time label, so populating `anchoredStartMinutes` on them has no visible side-effect as long as the `ChunkCard` check `if (chunk.anchoredStartMinutes != null)` is changed to check `chunk.goalId == null` for the "show anchored time as secondary text" logic.

**Simpler alternative (recommended):** Add a transient (non-Hive) field `int? syntheticStartMinutes` to `ScheduledChunk`, use `anchoredStartMinutes ?? syntheticStartMinutes ?? 9999` for sort key, and check `chunk.goalId == null` (not `anchoredStartMinutes != null`) to decide whether to show the time label on the card. This avoids polluting `anchoredStartMinutes` on discretionary chunks.

**Free-slot filling algorithm (detail):**

```
dayStart = 480
cursor = dayStart
discIdx = 0
breakCounter = 0  // counts discretionary work chunks placed so far
result_disc = []  // (chunk, syntheticStartMinutes) pairs

for each free slot [slotStart, slotEnd]:
  cursor = max(cursor, slotStart)
  while cursor + 25 <= slotEnd and discIdx < discretionaryChunks.length:
    assign discretionaryChunks[discIdx].syntheticStartMinutes = cursor
    result_disc.add(discretionaryChunks[discIdx])
    cursor += 25
    discIdx++
    breakCounter++
    isLong = (breakCounter % longBreakEvery == 0)
    breakDur = isLong ? 25 : 5
    if cursor + breakDur <= slotEnd and discIdx < discretionaryChunks.length:
      // add break with syntheticStartMinutes = cursor
      cursor += breakDur
    else:
      // no room for break in this slot, or no more chunks — skip break
      pass
```

**Edge cases the planner must address in tasks:**

| Edge Case | Behavior |
|-----------|----------|
| Empty schedule (no goals, no blocks) | Generator returns `[]` at line 155; no change needed |
| All-commitment day (no discretionary chunks) | Commitment chunks already have `anchoredStartMinutes`; interleave pass skips (empty discretionary list); trailing-break trim runs on commitment-only list; result is commitment chunks without any breaks between them |
| Discretionary chunks that don't fit before first commitment | Slot before first commitment may be 0 minutes; packer skips to next slot (gap between commitments or after last) |
| Discretionary chunks that don't fit in any gap | They remain unscheduled (discarded from result). This is already the current behavior for overflow beyond mood cap; the packer simply doesn't add a chunk it can't fit |
| Multiple commitment blocks on same day | Sort commitment blocks by `startMinutes` first; build gap list; pack discretionary into gaps in order |
| Single commitment chunk (block with one 25-min slice) | Window = [start, start+25]; gaps are [dayStart..start] and [start+25..dayEnd] |

---

### Pattern 3: Hive Schema Addition — isDeferred (HiveField 8)

**Exact steps:**

1. In `scheduled_chunk.dart`, add after HiveField(7):

```dart
@HiveField(8)
bool isDeferred = false;
```

2. Increment `currentSchemaVersion` from `3` to `4` in `migrations.dart:3`.

3. Add `_migration3to4` to the `_migrations` list and define it:

```dart
// migrations.dart — append to _migrations list
_migration3to4,

// No data transformation needed — Hive binary reader returns false (default
// for bool) for missing HiveField(8) in existing ScheduledChunk records.
Future<void> _migration3to4() async {}
```

4. Regenerate `scheduled_chunk.g.dart`:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

5. Verify `flutter analyze` passes (no new lint errors from generated code).

**Why additive-only is safe:** Hive CE binary serialization stores fields by index. A missing field at read time returns the field declaration default. `bool isDeferred = false` at HiveField(8) will be `false` for all pre-existing `ScheduledChunk` records. [ASSUMED — consistent with the well-established pattern used in `_migration1to2` and `_migration2to3` comments in the codebase]

**Alternative: reuse isSkipped for Phase 8 defer** — The CONTEXT.md and UI-SPEC both explicitly require an `isDeferred` field. The UI-SPEC `## Hive Schema Change` section mandates HiveField(8) `isDeferred`. The "Deferred" badge in the skipped section also requires distinguishing deferred from skipped. Do not reuse `isSkipped`. [VERIFIED: UI-SPEC.md "Hive Schema Change" section]

---

### Pattern 4: markDeferred Notifier Method

Mirrors `markSkipped` at `schedule_notifier.dart:143-163`. Add:

```dart
/// Marks the chunk with [chunkId] as deferred (Phase 8: visual skip only;
/// full cross-day carryover wired in Phase 10 CLOSE-02).
Future<void> markDeferred(String chunkId) async {
  if (_todaySchedule == null) return;
  final chunk = _todaySchedule!.chunks
      .where((c) => c.id == chunkId)
      .firstOrNull;
  if (chunk == null || chunk.isDeferred) return;

  chunk.isDeferred = true;
  chunk.isSkipped = true;   // treat as skipped for partitioning in schedule_screen.dart
  await _repo.save(_todaySchedule!);

  final dateYmd = _todaySchedule!.dateYmd;
  await _logRepo.append(
    CompletionLog(
      chunkId: chunkId,
      goalId: chunk.goalId ?? '',
      dateYmd: dateYmd,
      eventIndex: CompletionEvent.skipped.index, // Phase 8: log as skipped; Phase 10 adds deferred event
    ),
  );

  notifyListeners();
}
```

Setting `isSkipped = true` alongside `isDeferred = true` means the existing `schedule_screen.dart` partition logic at line 38-39 (`!c.isSkipped`) automatically moves the deferred chunk into the skipped section without any further screen changes. The "Deferred" badge in the skipped section is added by checking `chunk.isDeferred` when rendering skipped chunks.

---

### Pattern 5: ChunkDetailSheet (READ-03)

`showModalBottomSheet` with `isScrollControlled: true`, matching Phase 2 goal form pattern from `schedule_screen.dart`. Open from `schedule_screen.dart`'s `_buildSwipeableCard`:

```dart
// In _buildSwipeableCard or the onTap callback wired through SwipeableChunkCard
void _openDetailSheet(BuildContext context, ScheduledChunk chunk) {
  final goalColor = _lookupGoalColor(context, chunk);
  final goalName = _lookupGoalName(context, chunk);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ChunkDetailSheet(
      chunk: chunk,
      goalColor: goalColor,
      goalName: goalName,
    ),
  );
}
```

`ChunkDetailSheet` is a `StatelessWidget` (no local state needed — all actions delegate to `ScheduleNotifier`). It receives `context` for `context.read<ScheduleNotifier>()` calls and `context.push('/focus', extra: chunk.id)`. Since `showModalBottomSheet` creates a new route context, the sheet must use `context.read` with `Provider.of` or pass the notifier reference in. The standard pattern is to use `Builder` inside the sheet or pass the notifier:

```dart
// ChunkDetailSheet receives notifier as a parameter to avoid context scoping issues
class ChunkDetailSheet extends StatelessWidget {
  const ChunkDetailSheet({
    super.key,
    required this.chunk,
    required this.notifier,
    this.goalColor,
    this.goalName,
    this.displayRationale,
  });
  // ...
}
```

Alternatively, since `showModalBottomSheet` builder receives a context that IS a descendant of the Provider tree (go_router routes are wrapped), `context.read<ScheduleNotifier>()` works directly inside the builder. Both patterns are valid; passing via constructor is simpler and more testable.

---

### Pattern 6: Focus Mode Timer (READ-04)

`FocusScreen` is a `StatefulWidget`. Timer lives entirely in local state:

```dart
class _FocusScreenState extends State<FocusScreen> {
  Timer? _timer;
  int _secondsRemaining = 1500; // 25 * 60
  bool _isRunning = false;
  bool _isDone = false;

  void _start() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining <= 0) {
        t.cancel();
        setState(() { _isDone = true; _isRunning = false; });
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _doneEarly() {
    _timer?.cancel();
    setState(() { _isDone = true; _isRunning = false; });
  }

  @override
  void dispose() {
    _timer?.cancel();  // CRITICAL: prevent setState after dispose
    super.dispose();
  }
}
```

**Why `Timer.periodic` in a StatefulWidget vs a Ticker:**
- `Ticker` (via `SingleTickerProviderStateMixin`) fires on every vsync frame (~60/s) and is designed for animations; it would call `setState` 60 times per second for a 1-second countdown — wasteful.
- `Timer.periodic(Duration(seconds: 1), ...)` fires exactly once per second, triggering exactly one `setState` per second. This is the correct tool for a countdown clock. [ASSUMED — consistent with standard Flutter timer patterns]
- No `TickerProvider` mixin needed; no `AnimationController` needed.
- The timer is throwaway: it does not survive hot reload and does not need to (no background execution requirement per CONTEXT.md).

**Timer display:**

```dart
String get _timerDisplay {
  final m = _secondsRemaining ~/ 60;
  final s = _secondsRemaining % 60;
  return '${m}:${s.toString().padLeft(2, '0')}';
}
```

**Break suggestion derivation:**

```dart
String _breakSuggestion(ScheduleNotifier notifier) {
  final chunks = notifier.todaySchedule?.chunks ?? [];
  final idx = chunks.indexWhere((c) => c.id == widget.chunkId);
  if (idx == -1 || idx + 1 >= chunks.length) return "You're done for now.";
  final next = chunks[idx + 1];
  if (next.chunkType == ChunkType.shortBreak) return 'Nice work. Take a 5 min break.';
  if (next.chunkType == ChunkType.longBreak) return 'Great focus block. Take a 25 min break.';
  return "You're done for now.";
}
```

**Focus route registration** in `router.dart` (after line 113, inside the top-level `routes` list, outside `StatefulShellRoute`):

```dart
// Focus mode is outside the shell — no bottom nav shown (same pattern as /summary at line 109).
GoRoute(
  path: '/focus',
  builder: (context, state) => FocusScreen(chunkId: state.extra as String),
),
```

Navigate to it: `context.push('/focus', extra: chunk.id)`. Use `context.push` (not `context.go`) so the back button pops to the detail sheet or schedule screen.

---

### Anti-Patterns to Avoid

- **Don't put timer logic in a ChangeNotifier.** A `Timer.periodic` in a notifier would call `notifyListeners()` 1500 times for a 25-min countdown and trigger full subtree rebuilds on every tick. The timer is screen-local state only.
- **Don't use `context.go` to navigate to `/focus`.** Use `context.push` so the back button pops correctly back to the schedule screen. `context.go` would replace the navigation stack.
- **Don't insert breaks between consecutive commitment chunks** by relying on `anchoredStartMinutes` presence alone. The fix requires separating the commitment stream from the discretionary stream before the break-insertion pass, not just checking a field at break-insertion time.
- **Don't set `anchoredStartMinutes` on discretionary chunks** to synthetic values — this pollutes the commitment-vs-discretionary distinction used by the card to decide whether to show the time label. Use a separate `syntheticStartMinutes` field or a dedicated sort key.
- **Don't call `Navigator.pop(context)` directly in the detail sheet.** Use `context.pop()` from go_router — they're interchangeable in most cases, but `context.pop()` is consistent with the rest of the project's navigation patterns (all routes use go_router).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bottom sheet presentation | Custom overlay/dialog | `showModalBottomSheet` | Built-in, handles keyboard avoidance, scrim, drag-to-dismiss |
| Countdown timer | AnimationController / Ticker | `dart:async Timer.periodic(Duration(seconds:1))` | 1 tick/second; Ticker fires at 60fps (wasteful for a clock) |
| Goal color lookup | Inline map/where in ChunkCard | `_lookupGoalColor` pattern already in `schedule_screen.dart:129` | Pattern already established; ChunkCard stays presentational |
| Circular progress ring on timer | CustomPainter arc | `CircularProgressIndicator(value: _secondsRemaining / 1500)` | Built-in Material widget; `value` parameter accepts 0.0–1.0 |

---

## Common Pitfalls

### Pitfall 1: Timer leaks after widget dispose

**What goes wrong:** `Timer.periodic` continues firing after the `FocusScreen` is popped, calling `setState()` on a disposed widget, throwing `setState() called after dispose()`.

**Why it happens:** `Timer` is not automatically cancelled when a widget is removed from the tree.

**How to avoid:** Always cancel in `dispose()`:

```dart
@override
void dispose() {
  _timer?.cancel();
  super.dispose();
}
```

**Warning signs:** `setState() called after dispose()` exception in debug console after navigating away from focus screen.

---

### Pitfall 2: Break inserted between commitment-block chunks

**What goes wrong:** A 60-minute commitment block generates 2 anchored work chunks (at :540 and :565). After the READ-02 fix, if the break-insertion logic still runs over the flat `workChunks` list without distinguishing commitment from discretionary, a short break is inserted at :565 between the two commitment pieces.

**Why it happens:** The current break-insertion loop at `schedule_generator.dart:160-185` iterates over all `workChunks` uniformly.

**How to avoid:** Separate the commitment and discretionary streams before break insertion. Only run the break-insertion pass on the discretionary stream. Merge the two streams and sort by start time at the end.

**Warning signs:** A break card appearing between two commitment-block work cards when viewing the schedule.

---

### Pitfall 3: Trailing break on schedule

**What goes wrong:** The last chunk in the schedule is a break card, making the list end on a non-actionable element.

**Why it happens:** The current break-insertion pass at line 164 always appends a break after every work chunk, including the last one.

**How to avoid:** After all chunks are assembled and sorted, trim any trailing break:

```dart
while (result.isNotEmpty && result.last.chunkType != ChunkType.work) {
  result.removeLast();
}
```

**Warning signs:** Schedule list ends with "5 min break" or "25 min break" card.

---

### Pitfall 4: Gesture conflict — GestureDetector inside Dismissible

**What goes wrong:** Adding a `GestureDetector` for tap inside `Dismissible` may cause horizontal swipes to be interpreted as taps.

**Why it happens:** Flutter gesture arena: `Dismissible` wins horizontal drags; `GestureDetector(onTap)` wins taps. They don't conflict because `onTap` fires only on a tap (no significant movement), not on a swipe.

**How to avoid:** Place `GestureDetector` (or `onTap` in `InkWell`) as the direct child of the `Dismissible` child widget (`ChunkCard`'s work variant). This is already how `_HoverableChunkContent` is structured at `chunk_card.dart:141-275`. Add an `onTap` callback parameter to `_HoverableChunkContent` and wire it.

**Warning signs:** Taps not registering, or swipes accidentally opening the detail sheet. [ASSUMED — based on standard Flutter gesture arena behavior]

---

### Pitfall 5: `showModalBottomSheet` context and Provider access

**What goes wrong:** `context.read<ScheduleNotifier>()` fails inside the `ChunkDetailSheet` widget because the sheet's `BuildContext` is not a descendant of the Provider root.

**Why it happens:** `showModalBottomSheet` creates a new route that IS mounted under the same root `MaterialApp`, which is also the Provider root. This typically works, but passing the notifier directly to the sheet is more explicit and avoids any scoping edge cases.

**How to avoid:** Pass `ScheduleNotifier` (and `GoalsNotifier`) as constructor parameters to `ChunkDetailSheet`, resolved from the calling context before `showModalBottomSheet` is called.

**Warning signs:** `ProviderNotFoundException` or `Could not find correct Provider<ScheduleNotifier>` at runtime.

---

### Pitfall 6: schemaVersion downgrade assertion

**What goes wrong:** If `currentSchemaVersion` in `migrations.dart` is incremented to 4 but a device already has version 4 stored (e.g., from a failed hot reload), the `assert(storedVersion <= currentSchemaVersion)` at line 46 fires in debug mode.

**Why it happens:** The migration system at `migrations.dart:36-57` stores the version in SharedPreferences. If the version was bumped and migration ran, then the code was reverted, the stored version would be higher than the code version.

**How to avoid:** During development, clear app data or uninstall-reinstall if schema version errors appear. Never decrement `currentSchemaVersion`. [VERIFIED: migrations.dart:46-52]

---

## Code Examples

### Verified: `_lookupGoalColor` pattern to mirror for `_lookupGoalName`

```dart
// Source: schedule_screen.dart:129-135 (verified read)
Color? _lookupGoalColor(BuildContext context, ScheduledChunk chunk) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  if (goal?.color != null) return hexToColor(goal!.color!);
  return null;
}
// Add immediately below — same structure:
String? _lookupGoalName(BuildContext context, ScheduledChunk chunk) {
  if (chunk.goalId == null) return null;
  final goals = context.read<GoalsNotifier>().goals;
  final goal = goals.where((g) => g.id == chunk.goalId).firstOrNull;
  return goal?.name;
}
```

### Verified: `markSkipped` pattern to copy for `markDeferred`

```dart
// Source: schedule_notifier.dart:143-163 (verified read)
// markDeferred mirrors this structure exactly, adding chunk.isDeferred = true
// and setting chunk.isSkipped = true for screen partitioning compatibility.
```

### Verified: Outside-shell GoRoute pattern

```dart
// Source: router.dart:109-113 (verified read)
GoRoute(
  path: '/summary',
  builder: (context, state) => const EndOfDaySummaryScreen(),
),
// /focus follows the same pattern; receives chunkId via state.extra:
GoRoute(
  path: '/focus',
  builder: (context, state) => FocusScreen(chunkId: state.extra as String),
),
```

### Verified: Hive migration no-op pattern

```dart
// Source: migrations.dart:27-33 (verified read)
Future<void> _migration2to3() async {
  // Additive nullable fields — no data transformation needed.
}
// _migration3to4 follows exact same pattern for isDeferred bool.
```

### Verified: existing break-insertion loop that must be replaced

```dart
// Source: schedule_generator.dart:154-188 (verified read)
// This loop runs over ALL workChunks uniformly — must be refactored
// to separate commitment (no breaks) from discretionary (with breaks).
if (workChunks.isEmpty) return [];
final List<ScheduledChunk> result = [];
int workChunkCounter = 0;
for (final chunk in workChunks) {
  result.add(chunk);
  workChunkCounter++;
  if (workChunkCounter % longBreakEvery == 0) { /* long break */ }
  else { /* short break */ }
}
// Bugs: (1) inserts breaks after commitment chunks, (2) no trailing trim,
// (3) no start-time assignment or sort.
```

---

## Runtime State Inventory

> Rename/refactor phase: NOT applicable. This is a greenfield UI + schema addition phase.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Break after every work chunk (including last) | Trim trailing break; no break inside commitment window | Phase 8 | Schedule reads cleanly without dangling break |
| `chunk.rationale` as primary title | Goal name as primary title; rationale as secondary | Phase 8 | Cards are legible — user sees goal names |
| No tap action on chunk cards | Tap opens detail sheet with full action set | Phase 8 | Discoverable explicit path for complete/skip/defer |
| No focus mode | `/focus` route with optional 25-min countdown | Phase 8 | Minimal "current chunk" companion mode |

**Deprecated/outdated in Phase 8:**
- `rationale: 'Habit'` display string → replaced with `'Daily habit'` in UI (rationale field value unchanged in data; only display mapping changes)
- `rationale: 'Outcome goal'` → `'Working toward your goal'`
- `rationale: 'Weekly goal'` → `'Your weekly time goal'`

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Hive CE binary reader returns `false` for a missing `bool` field (HiveField 8) in existing records, making the migration a true no-op | Hive Schema Addition | If wrong, existing ScheduledChunk records would fail to deserialize — would need data migration loop |
| A2 | `Timer.periodic(Duration(seconds:1))` is the idiomatic Flutter pattern for a countdown timer (vs. Ticker/AnimationController) | Focus Mode Timer | If wrong, could use AnimationController with 1500ms total; result is same but AnimationController is heavier for this use case |
| A3 | `context.read<ScheduleNotifier>()` works inside `showModalBottomSheet` builder because the sheet is mounted under the same MaterialApp/Provider root | Detail Sheet | If wrong, pass notifier as constructor parameter to ChunkDetailSheet — easy fix |
| A4 | Setting `isSkipped = true` alongside `isDeferred = true` is sufficient for Phase 8 screen partitioning without changing `schedule_screen.dart`'s partition logic | markDeferred Pattern | If wrong, add `|| c.isDeferred` to the skipped partition predicate — minimal fix |

---

## Open Questions (RESOLVED)

1. **Discretionary chunks that overflow available gaps** — RESOLVED
   - What we know: packer assigns synthetic start times greedily; chunks that don't fit in any gap are left without a start time.
   - RESOLVED: drop unfit chunks from the output entirely (recommendation adopted; implemented in Step B of `_assignSyntheticStartTimes`). The mood cap already limits chunk count; a day with many commitments naturally reduces discretionary capacity. Consistent with current behavior and avoids artificial late-night times.

2. **Gesture conflict on resolved work chunks opened via tap** — RESOLVED
   - What we know: resolved chunks (isCompleted/isSkipped) have `DismissDirection.none` on `SwipeableChunkCard` (line 37 of swipeable_chunk_card.dart).
   - RESOLVED: keep resolved chunks tappable; the detail sheet renders in read-only mode per the UI-SPEC "Resolved chunks" section — goal name + rationale + status badge, no action buttons (`isResolved` state in the sheet builder).

---

## Environment Availability

> Step 2.6: All capabilities are pure Flutter/Dart SDK + already-installed pub packages. No external tools, databases, or services required beyond the existing build pipeline.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| flutter SDK | All | ✓ | ≥3.18.0-18.0.pre.54 | — |
| hive_ce_generator | build_runner regen | ✓ | ^1.11.1 (pubspec.yaml) | — |
| build_runner | HiveField(8) regen | ✓ | ^2.4.13 (pubspec.yaml) | — |
| dart:async Timer | Focus countdown | ✓ | SDK built-in | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

---

## Validation Architecture

> `workflow.nyquist_validation` key is absent from `.planning/config.json` — treat as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK built-in) |
| Config file | none (flutter test runs from project root) |
| Quick run command | `flutter test test/services/schedule_generator_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| READ-01 | Goal name appears as primary text; rationale as secondary | Widget test | `flutter test test/screens/chunk_card_goal_name_test.dart` | ❌ Wave 0 |
| READ-02 | Discretionary chunks get synthetic start times; sorted by start; no break after commitment chunk; no trailing break | Unit test | `flutter test test/services/schedule_generator_test.dart` | ✅ (extend existing) |
| READ-02 | Edge: all-commitment day has no breaks in result | Unit test | `flutter test test/services/schedule_generator_test.dart` | ✅ (extend existing) |
| READ-02 | Edge: trailing break trimmed | Unit test | `flutter test test/services/schedule_generator_test.dart` | ✅ (extend existing) |
| READ-03 | Detail sheet opens on work chunk tap; shows goal name, rationale, 3 action buttons | Widget test | `flutter test test/screens/chunk_detail_sheet_test.dart` | ❌ Wave 0 |
| READ-03 | markDeferred sets isDeferred=true, isSkipped=true, notifies | Unit test | `flutter test test/providers/schedule_notifier_defer_test.dart` | ❌ Wave 0 |
| READ-04 | FocusScreen renders with chunkId; timer starts on tap; displays MM:SS | Widget test | `flutter test test/screens/focus_screen_test.dart` | ❌ Wave 0 |
| READ-04 | Timer.cancel called in dispose (no leak) | Widget test | `flutter test test/screens/focus_screen_test.dart` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/services/schedule_generator_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green (`flutter test`) before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/screens/chunk_card_goal_name_test.dart` — covers READ-01 (goal name as primary title)
- [ ] `test/screens/chunk_detail_sheet_test.dart` — covers READ-03 (sheet content + action buttons)
- [ ] `test/providers/schedule_notifier_defer_test.dart` — covers READ-03 (markDeferred behavior)
- [ ] `test/screens/focus_screen_test.dart` — covers READ-04 (timer widget rendering + dispose)

**Extend existing:** `test/services/schedule_generator_test.dart` needs new test cases:

- Test 10: commitment block + 2 habits → no breaks between commitment chunks; breaks between discretionary chunks only
- Test 11: 2 habits only → trailing break trimmed (last chunk is work)
- Test 12: commitment block + 1 habit → discretionary chunk gets `syntheticStartMinutes` after commitment window; result sorted by start time
- Test 13: all-commitment day (no discretionary) → commitment chunks only, no breaks between them

---

## Security Domain

> `security_enforcement` key is absent from `.planning/config.json` — treat as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (local-only app, no auth) |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes (minimal) | `state.extra as String` cast for chunkId — add null-safe guard in FocusScreen |
| V6 Cryptography | no | — |

### Known Threat Patterns for Flutter/Hive local-only app

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unsafe `state.extra as String` cast | Tampering | Add `if (state.extra is! String) return` guard in FocusScreen builder |
| Timer running after widget dispose | Availability (app crash) | `_timer?.cancel()` in `dispose()` — documented above |

---

## Sources

### Primary (verified in codebase — line numbers cited)
- `lib/services/schedule_generator.dart` — complete read; lines 1-189 inform READ-02 algorithm design
- `lib/data/models/scheduled_chunk.dart` — HiveField indices 0-7; HiveField(8) gap confirmed
- `lib/data/models/goal.dart` — Goal.name/color/goalType; HiveField indices 0-11
- `lib/providers/schedule_notifier.dart` — markComplete/markSkipped patterns (lines 117-163); markDeferred pattern
- `lib/screens/schedule/schedule_screen.dart` — `_lookupGoalColor` at line 129; partition logic at lines 38-39
- `lib/screens/schedule/widgets/chunk_card.dart` — `_HoverableChunkContent`; rationale-as-title at line 188; `hexToColor`/`_formatMinutes` helpers
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — Dismissible gesture pattern; DismissDirection.none for resolved
- `lib/router.dart` — StatefulShellRoute; outside-shell GoRoute pattern at lines 95-113
- `lib/data/database/migrations.dart` — `currentSchemaVersion = 3`; `_migrations` list; `runMigrations` at line 36
- `lib/data/database/hive_database.dart` — TypeAdapter registration order; ScheduledChunkAdapter at typeId 3
- `.planning/phases/08-a-schedule-you-can-read/08-CONTEXT.md` — all locked decisions
- `.planning/phases/08-a-schedule-you-can-read/08-UI-SPEC.md` — component specs, typography, spacing, copy contract
- `test/services/schedule_generator_test.dart` — existing test structure; Wave 0 gap analysis

### Secondary (inferred from established patterns in codebase)
- `Timer.periodic` vs Ticker — standard Flutter pattern for countdown clocks
- `showModalBottomSheet` context and Provider scoping — consistent with Phase 2 goal form sheet pattern

### Tertiary (LOW confidence — not verified in this session)
- Hive CE binary reader behavior for missing bool fields (confirmed by migration comment in codebase but not by Hive CE docs)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already in pubspec.yaml; no new dependencies
- Architecture: HIGH — all patterns grounded in real codebase line numbers
- Generator ordering algorithm: HIGH — detailed analysis of existing code; edge cases enumerated
- Timer implementation: MEDIUM — standard Flutter pattern; not verified against Flutter docs in this session
- Hive schema migration: HIGH — exact pattern in codebase at migrations.dart:27-33

**Research date:** 2026-06-10
**Valid until:** 2026-07-10 (stable Flutter + Hive CE stack)
