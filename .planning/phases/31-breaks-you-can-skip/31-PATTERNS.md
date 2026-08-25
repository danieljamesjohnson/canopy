# Phase 31: Breaks You Can Skip - Pattern Map

**Mapped:** 2026-08-25
**Files analyzed:** 7 (5 source + 2 test files with new cases; a 3rd test file is a new-territory addition)
**Analogs found:** 7 / 7 — every file this phase touches is a modification of an existing file with a
directly-adjacent, already-shipped pattern to extend. There are no wholly new files in this phase.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `lib/screens/schedule/widgets/swipeable_chunk_card.dart` | component (gesture wrapper) | event-driven (drag → state mutation) | itself — the work-chunk `Dismissible` branch already in this file, lines 84-136 | exact (self-analog: extend the existing bidirectional branch into a new one-directional branch) |
| `lib/screens/schedule/widgets/chunk_card.dart` (`_WorkChunkContent`, `_buildBreak`, `_SubCompactRow`) | component (presentational, density-tiered) | transform (chunk state → visual) | itself — `_WorkChunkContent`'s existing `isResolved`/`contentOpacity`/`lineThrough`/`_buildTrailingStatus` vocabulary, lines 450-451, 647-650, 757-771 | exact (reuse the same resolved-state vocabulary across the break branches) |
| `lib/screens/today/today_screen.dart` (`_buildPositionedRow` break arm + Stack children) | component (layout/dispatch) | transform (row model → positioned widget) + event-driven (hosts the gesture) | the existing **live-row third Stack pass**, lines 1449-1488 (PD-10 z-order pattern) | exact — this is the direct structural template for the new slop-bearing-break third pass |
| `lib/screens/today/timeline_geometry.dart` | config (constants module) | n/a (pure constants) | `kSubCompactBreakMinHeight`/`kFullBreakMinHeight` cluster, lines 55-170 | exact (same file, same "one file owns every Today-timeline threshold" convention) |
| `lib/providers/schedule_notifier.dart` (`_absorbReclaimedTimeIntoNextBreak`) | service (business-logic guard) | transform (guard chain, early-return style) | itself — Guards 5/6 in the same function, lines 564-570 | exact (add a ninth guard in the same style, same location) |
| `test/screens/today_screen_test.dart` (new drag-simulation group) | test | event-driven (simulated gesture) | **no existing analog in this codebase** — `grep -rn "tester.drag\|dragFrom\|fling("` returns zero results; nearest structural analog is the file's own `buildDayFixture`/`pumpDay` helpers | no analog for the drag mechanics themselves; strong analog for fixture scaffolding |
| `test/screens/today_row_widgets_test.dart` (extend `break densities` group) | test | transform (widget-tree assertion) | the file's own existing `_FakeScheduleNotifier` + chunk-factory pattern, lines 1-60 | exact |
| `test/providers/schedule_notifier_break_extension_test.dart` (extend `G-05 no-op guards` group) | test | transform (unit assertion on guard function) | the file's own existing `G-05 no-op guards` group, lines 204-236 (`makeNotifier`/`_InMemoryScheduleRepository` fixture) | exact |

## Pattern Assignments

### `lib/screens/schedule/widgets/swipeable_chunk_card.dart` (component, event-driven)

**Analog:** itself (this file, work-chunk branch)

**The early return to delete** (lines 74-82):
```dart
// Break cards are not swipeable and do not receive goal name or tap.
if (chunk.chunkType != ChunkType.work) {
  return ChunkCard(
    chunk: chunk,
    goalColor: goalColor,
    showStartTime: showStartTime,
    density: density,
  );
}
```

**The `Dismissible` template to narrow for breaks** (lines 84-136, verbatim — this is what a new
`endToStart`-only branch derives from):
```dart
return Dismissible(
  key: ValueKey(chunk.id),
  // Resolved chunks cannot be re-swiped.
  direction: chunk.isCompleted || chunk.isSkipped
      ? DismissDirection.none
      : DismissDirection.horizontal,
  confirmDismiss: (direction) async {
    final notifier = context.read<ScheduleNotifier>();
    if (direction == DismissDirection.startToEnd) {
      await notifier.markComplete(chunk.id);
      HapticFeedback.lightImpact();
    } else {
      await notifier.markSkipped(chunk.id);
      HapticFeedback.lightImpact();
    }
    return false;
  },
  background: Container(
    color: colorScheme.primary,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.only(left: 20),
    child: Icon(Icons.check_circle, color: colorScheme.onPrimary, size: 28),
  ),
  secondaryBackground: Container(
    color: colorScheme.error,
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    child: Icon(Icons.arrow_forward, color: colorScheme.onError, size: 28),
  ),
  child: ChunkCard(/* ... */),
);
```

**What to copy for the break branch (per `31-UI-SPEC.md` D-31-01/D-31-02):**
- `direction:` narrowed to `chunk.isSkipped ? DismissDirection.none : DismissDirection.endToStart`
  (never `isCompleted` — a break can never be completed, D-31-01).
- Only `background:` is needed (the `endToStart` reveal) — `secondaryBackground` is omitted since
  there is no `startToEnd` direction enabled for a break. **Note the naming**: for a
  `secondaryBackground` used as the *only* enabled reveal, it must be supplied as `secondaryBackground`
  (shown for `endToStart`), not `background` (shown for `startToEnd`) — verify against the exact
  `Dismissible` field/direction pairing before wiring, since this file's existing work-chunk branch
  pairs `background`↔`startToEnd`/`check_circle`/`primary` and `secondaryBackground`↔`endToStart`/
  `arrow_forward`/`error`.
- Icon reveal reuses `colorScheme.error`/`onError`/`Icons.arrow_forward` verbatim (same as the
  work-chunk skip reveal) but the icon `size` is **not** the fixed `28` — UI-SPEC specifies
  `min(20.0, slot - 4.0)` clamped to a minimum of `12.0` to fit inside a confined `slot`-height band.
- `confirmDismiss` always calls `notifier.markSkipped(chunk.id)` + `HapticFeedback.lightImpact()` +
  `return false` — identical shape to the existing `else` arm above, just without the `if` branch.
- Per `31-UI-SPEC.md`, this file may optionally gain a `visualHeight` parameter (default `null`) that
  wraps `child`/`background` each independently in `Align(center) + SizedBox(height: visualHeight)`
  for the slop case — or the confinement can live entirely in `today_screen.dart` instead. Either
  split is acceptable per the UI-SPEC; state which one the plan picks.

---

### `lib/screens/schedule/widgets/chunk_card.dart` (component, transform)

**Analog:** itself — `_WorkChunkContent`'s existing resolved-state vocabulary

**Opacity precedent** (line 450-451):
```dart
final isResolved = chunk.isCompleted || chunk.isSkipped;
final contentOpacity = isResolved ? 0.5 : 1.0;
```

**Strikethrough precedent** (line 647-650):
```dart
final titleStyle = theme.textTheme.titleMedium?.copyWith(
  fontWeight: FontWeight.w600,
  decoration: isResolved ? TextDecoration.lineThrough : null,
);
```

**Trailing-status swap precedent, 'skipped' string is VERBATIM reuse, not new copy** (lines 757-771):
```dart
Widget _buildTrailingStatus(ThemeData theme) {
  return chunk.isCompleted
      ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
      : chunk.isSkipped
      ? Text('skipped', style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant))
      : Icon(Icons.radio_button_unchecked, color: theme.colorScheme.onSurfaceVariant);
}
```

**Current `_SubCompactRow` call site — the exact place to add an `isSkipped` param** (lines 161-166,
pre-phase state):
```dart
if (density == ChunkCardDensity.subCompact) {
  return _SubCompactRow(
    label: title,
    semanticsLabel: '$title, ${chunk.durationMinutes} min',
  );
}
```
`_SubCompactRow`'s constructor (lines 343-352) currently takes only `label`/`semanticsLabel` — no
resolved-state param exists yet. Add `isSkipped` (`bool`, default `false`), and when true: wrap the
row's `Row` in `Opacity(opacity: 0.5)`, add `decoration: TextDecoration.lineThrough` to the label
`Text`, and append `', skipped'` to the caller-supplied `semanticsLabel`.

**What to copy, per tier (D-31-04, exact acceptance already spelled out in UI-SPEC):**
- **Full/detailed** `_buildBreak` branch: wrap the existing icon+title+Spacer+trailing `Row` in
  `Opacity(opacity: chunk.isSkipped ? 0.5 : 1.0)`; add the same `lineThrough` decoration to the title
  style; change the trailing `Text('${chunk.durationMinutes} min')` to
  `Text(chunk.isSkipped ? 'skipped' : '${chunk.durationMinutes} min')` — copying `_buildTrailingStatus`'s
  exact string, not re-authoring it.
- **Compact**: same `Opacity`/`lineThrough` wrap around the dashed-border `CustomPaint` + centered
  title; **also add a `Semantics` wrapper that does not exist today** —
  `Semantics(label: '$title, ${chunk.durationMinutes} min${chunk.isSkipped ? ", skipped" : ""}')`.
- **Sub-compact**: as above, `isSkipped` param threaded through `_SubCompactRow`.

---

### `lib/screens/today/today_screen.dart` (`_buildPositionedRow` + Stack children)

**Analog:** the existing live-row third Stack pass (PD-10 z-order pattern) — this is the load-bearing
excerpt for D-31-02's fix, per the research's explicit instruction.

**Current three-pass Stack structure** (`today_screen.dart:1355-1488`), verbatim:

```dart
Stack(
  children: [
    // Layer 2 — hour axis, painted behind every row's content.
    for (final hourMinutes in geometry.hourBoundaries)
      Positioned(/* ... HourAxisLine ... */),

    // Layer 1 — the rows (26-03-PLAN.md), unchanged.
    // Non-live rows first, the live row's Positioned
    // appended last (PD-10).
    for (final row in timelineRows)
      if (!(row is ChunkRow && row.isLive) &&
          !(row is ChunkRow && row.chunk.displayStartMinutes == null))
        _buildPositionedRow(context, row, geometry, nowState, liveSecondsLeft),

    // Layer 3 — the now-line (CAL-02), topmost in the Stack, above every
    // card's elevation/shadow. Unconditional: no `if`, no ternary, no
    // state check.
    Positioned(
      top: geometry.yFor(nowMinutes) - kNowLineHeight / 2,
      left: 0, right: 0, height: kNowLineHeight,
      child: Semantics(
        label: 'Now — ${formatMinutes(nowMinutes)}',
        excludeSemantics: true,
        child: IgnorePointer(child: NowLineOverlay(nowMinutes: nowMinutes)),
      ),
    ),

    // The live row, painted LAST — above the now-line rule (UAT, 2026-08-19).
    // Order is the whole fix. Painting the card over the rule stops the line
    // at the card's edges, which is what Google Calendar does with its
    // current event.
    for (final row in timelineRows)
      if (row is ChunkRow && row.isLive)
        _buildPositionedRow(context, row, geometry, nowState, liveSecondsLeft),
  ],
)
```

**Why this is the exact template to mirror (research's own words, Pitfall 1):** `Stack` resolves
overlapping siblings by walking `lastChild` → first and stopping at the first hit
(`RenderStack`/`RenderBox.defaultHitTestChildren`). The live row is deliberately the *last* Stack
child specifically so a grown/overrunning box always wins z-order priority over its chronological
neighbors — this is the identical problem a slop-bearing break's grown `Positioned` now has (it
overlaps its *own* chronological neighbors for the first time in this codebase), and it needs the
identical fix: **its own dedicated pass, added after the normal Layer-1 loop and before the now-line
overlay**, so it is `lastChild`-ward of BOTH its preceding and following neighbor regardless of
`timelineRows` iteration order.

**Concrete new pass to add** (from `31-RESEARCH.md`'s Code Examples section, the load-bearing sketch):
```dart
// Layer 1a: every NON-live, NON-slop-bearing row — unchanged loop, unchanged order.
for (final row in timelineRows)
  if (!(row is ChunkRow && row.isLive) &&
      !(row is ChunkRow && row.chunk.displayStartMinutes == null) &&
      !(row is ChunkRow && _needsSlop(row.chunk, geometry)))   // NEW predicate
    _buildPositionedRow(context, row, geometry, nowState, liveSecondsLeft),

// Layer 1b (NEW): every NON-live, slop-bearing break — added AFTER layer 1a
// so its Positioned always wins Stack hit-test priority against BOTH
// chronological neighbors, regardless of iteration order.
for (final row in timelineRows)
  if (row is ChunkRow && !row.isLive &&
      row.chunk.displayStartMinutes != null &&
      _needsSlop(row.chunk, geometry))
    _buildPositionedRow(context, row, geometry, nowState, liveSecondsLeft),

// ... now-line overlay, then live row, unchanged (PD-10).
```
Insert this new pair of loops in place of the current single Layer-1 loop
(`today_screen.dart:1387-1397`), immediately before the now-line `Positioned` at line 1421 — i.e. the
new "Layer 1b" pass sits between the current Layer 1 and Layer 3, exactly where a fourth documented
Layer would naturally go in this file's own comment numbering scheme (Layer 2 = hour axis, Layer 1 =
rows, Layer 3 = now-line, live row last). Follow this file's convention of a load-bearing doc comment
explaining *why* the ordering matters (see the live-row comment at lines 1449-1479 for the house style
to match — this file treats z-order comments as mandatory, not optional).

**Current break-arm `Positioned` to modify for the grown envelope** (lines 812-827, the un-modified
break/work-chunk arm — this is what gains `topSlop`/`bottomSlop` per `31-UI-SPEC.md`):
```dart
return Positioned(
  top: geometry.yFor(start),
  left: 0,
  right: 0,
  height: slot,
  child: ClipRect(
    child: OverflowBox(
      alignment: Alignment.topCenter,
      minHeight: 0,
      maxHeight: double.infinity,
      child: TimelineRowTile(child: _buildChunkCard(context, chunk, density)),
    ),
  ),
);
```
Per the UI-SPEC's ⚠ CORRECTION block, this must become — for a sub-`kMinBreakDragTarget` break only —
`Positioned(height: slot + topSlop + bottomSlop, child: Dismissible(...))` with `ClipRect` relocated
*inside* the `Dismissible`'s child, confined to `slot` via `Align(center) + SizedBox(height: slot)`.
See UI-SPEC lines 107-130 for the full target shape (already copy-paste-ready Dart in that document —
reproduced there, not duplicated here to avoid drift between two copies).

**Density-dispatch context immediately above (lines 786-805)** — read, don't modify; this is what
computes `slot`/`density`/`isBreak` that the new envelope logic consumes:
```dart
final isBreak = chunk.chunkType == ChunkType.shortBreak || chunk.chunkType == ChunkType.longBreak;
final density = isBreak
    ? (slot >= kFullBreakMinHeight ? ChunkCardDensity.full
        : slot >= kSubCompactBreakMinHeight ? ChunkCardDensity.compact
        : ChunkCardDensity.subCompact)
    : (slot >= kFullTierMinHeight ? ChunkCardDensity.full : ChunkCardDensity.compact);
```

---

### `lib/screens/today/timeline_geometry.dart` (config)

**Analog:** the existing threshold-constant cluster, same file (lines 55-170) — this file's own
documented convention is "one file owns every Today-timeline threshold," so the two new constants
join this cluster, not a new file.

**Precedent constant to match style/doc-comment weight** (line 170, with its full rationale comment
above it — read lines 142-170 for the doc-comment density this file expects for every constant):
```dart
const double kSubCompactBreakMinHeight = 32.0;
```

**New constants to add, per `31-UI-SPEC.md` exactly:**
```dart
/// Extra invisible hit-test reach added above AND below a break's own slot
/// (D-31-02, phase 31), before any clamp against a short neighbor. On-grid
/// (multiple of 4). Not a visual/paint value — confines nothing that paints.
const double kBreakHitSlop = 16.0;

/// Slop (kBreakHitSlop) is applied only while `slot < kMinBreakDragTarget` —
/// a break already at or above this height clears both Material's 48dp and
/// iOS's 44pt touch-target minimums on its own painted slot alone.
const double kMinBreakDragTarget = 48.0;
```

---

### `lib/providers/schedule_notifier.dart` (`_absorbReclaimedTimeIntoNextBreak`, D-31-05)

**Analog:** itself — the existing eight-guard early-return chain in the same function.

**Full guard chain, exact insertion point marked** (lines 529-592, verbatim per research):
```dart
({ScheduledChunk chunk, int? previousStart, int previousDuration})?
_absorbReclaimedTimeIntoNextBreak(ScheduledChunk completed) {
  final schedule = _todaySchedule;
  if (schedule == null) return null;

  if (completed.chunkType != ChunkType.work) return null;          // Guard 1
  final completedStart = completed.displayStartMinutes;
  if (completedStart == null) return null;                          // Guard 2

  final nowDt = _now();
  final nowMinutes = nowDt.hour * 60 + nowDt.minute;

  if (nowMinutes < completedStart) return null;                     // Guard 3
  if (nowMinutes >= completedStart + completed.durationMinutes) {    // Guard 4
    return null;
  }

  final byClock = schedule.chunks.where((c) => c.displayStartMinutes != null).toList()
    ..sort((a, b) => a.displayStartMinutes!.compareTo(b.displayStartMinutes!));
  final idx = byClock.indexOf(completed);
  if (idx == -1 || idx + 1 >= byClock.length) return null;
  final next = byClock[idx + 1];

  if (next.chunkType != ChunkType.shortBreak &&                      // Guard 5
      next.chunkType != ChunkType.longBreak) {
    return null;
  }
  if (next.anchoredStartMinutes != null) return null;                // Guard 6
  final breakStart = next.displayStartMinutes;
  if (breakStart == null) return null;

  // ← D-31-05's fix belongs HERE, after Guard 6, before Guard 7:
  //   if (next.isSkipped) return null;

  if (nowMinutes >= breakStart) return null;                         // Guard 7
  final newDuration = (breakStart + next.durationMinutes) - nowMinutes;
  if (newDuration <= 0) return null;                                 // Guard 8

  final previousStart = next.syntheticStartMinutes;
  final previousDuration = next.durationMinutes;
  next.syntheticStartMinutes = nowMinutes;
  next.durationMinutes = newDuration;
  return (chunk: next, previousStart: previousStart, previousDuration: previousDuration);
}
```

**Exact one-line fix, same guard style as Guards 1-8 (no braces, single early return):**
```dart
if (next.isSkipped) return null;
```
Insert immediately after the `breakStart == null` check and before Guard 7 (`nowMinutes >= breakStart`).

---

## Shared Patterns

### Resolved-state visual vocabulary (opacity + strikethrough + trailing text)
**Source:** `lib/screens/schedule/widgets/chunk_card.dart` lines 450-451, 647-650, 757-771 (work-chunk
`_WorkChunkContent`)
**Apply to:** every break density tier in `chunk_card.dart` (`_buildBreak` full/compact branches,
`_SubCompactRow`)
```dart
final isResolved = chunk.isCompleted || chunk.isSkipped;  // for a break: equivalent to chunk.isSkipped
final contentOpacity = isResolved ? 0.5 : 1.0;
// ...
decoration: isResolved ? TextDecoration.lineThrough : null,
// ...
Text('skipped', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
```

### Dismissible skip gesture (confirmDismiss → markSkipped → haptic → return false)
**Source:** `lib/screens/schedule/widgets/swipeable_chunk_card.dart` lines 92-101 (the `else` arm of
the existing work-chunk `confirmDismiss`)
**Apply to:** the new break-only `Dismissible` branch in the same file
```dart
confirmDismiss: (_) async {
  final notifier = context.read<ScheduleNotifier>();
  await notifier.markSkipped(chunk.id);
  HapticFeedback.lightImpact();
  return false;
},
```

### Stack z-order "later pass wins contested overlap" (PD-10)
**Source:** `lib/screens/today/today_screen.dart` lines 1347-1351, 1449-1479 (the live-row pass and
its doc comments)
**Apply to:** the new slop-bearing-break third pass in the same file's Stack — same reasoning, same
comment-density expectation, inserted between the existing Layer 1 (rows) and Layer 3 (now-line).

### `markSkipped` itself — needs NO modification, already type-agnostic
**Source:** `lib/providers/schedule_notifier.dart` lines 678-739
**Apply to:** nothing — cited here only so the planner does not accidentally schedule a change to
this function. Verified: `chunk.isSkipped = true`, `_repo.save`, `CompletionLog.append`, and the
streak guard `chunk.goalId != null && chunk.goalId!.isNotEmpty` (line 706) is provably inert for
every break (`goalId` is documented and typed nullable-always-null for break types,
`scheduled_chunk.dart:8-9,31-33`).

### Guard-chain style for business-logic early returns
**Source:** `lib/providers/schedule_notifier.dart` `_absorbReclaimedTimeIntoNextBreak`, Guards 1-8
(lines 534-580)
**Apply to:** D-31-05's new guard — single-line `if (cond) return null;`, no braces, grouped with the
semantically-adjacent guards (break-eligibility checks), not appended at the end out of grouping order.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `test/screens/today_screen_test.dart` (new drag-simulation group for the hit-test-envelope claim) | test | event-driven (simulated `Dismissible` drag) | `grep -rn "tester.drag\|dragFrom\|fling(" test/` returns zero results project-wide — no existing test in this codebase simulates a `Dismissible` drag at all; every existing `SwipeableChunkCard`/`Dismissible` test only asserts widget-tree structure (`expect(find.byType(Dismissible), findsOneWidget)`). Use `31-RESEARCH.md`'s "Code Examples" sketch (drag-simulation pattern) as the starting point — reproduced below — and this file's own `buildDayFixture`/`pumpDay` helpers (grep-verified to exist) for fixture scaffolding, since those *do* have a direct analog. |

**Sketch to build from (no existing verbatim analog, from `31-RESEARCH.md`, adapted to this file's own
`_FakeScheduleNotifier` convention already shown above under `today_row_widgets_test.dart`):**
```dart
testWidgets(
  'a drag starting kBreakHitSlop above a sub-48dp break\'s painted top edge '
  'still resolves to that break\'s Dismissible',
  (tester) async {
    final fake = _FakeScheduleNotifier();
    // ... pump a day fixture with a 5-minute break at a known geometry.yFor() offset ...
    final startPoint = tester.getTopLeft(find.byKey(ValueKey('b1')))
        .translate(40, -kBreakHitSlop + 2); // 2px inside the grown envelope, above painted top
    await tester.dragFrom(startPoint, const Offset(-400, 0)); // leftward, past dismissThreshold
    await tester.pumpAndSettle();
    expect(fake.lastSkippedId, 'b1');
  },
);
```
Pair with a negative case (drag starting inside the *neighbor's* own painted content still resolves
to the neighbor) — see `31-UI-SPEC.md` "Verification" item 2 for the exact acceptance wording.

## Metadata

**Analog search scope:** `lib/screens/schedule/widgets/`, `lib/screens/today/`,
`lib/providers/schedule_notifier.dart`, `test/screens/`, `test/providers/` — all directories this
phase's file list falls under, per `31-CONTEXT.md`/`31-RESEARCH.md`/`31-UI-SPEC.md`'s own file lists.
**Files scanned:** `swipeable_chunk_card.dart` (full, 138 lines), `chunk_card.dart` (targeted reads,
lines 1-770 per research + this session's targeted verification), `today_screen.dart` (lines 680-990,
1340-1490), `timeline_geometry.dart` (constant cluster + grep), `schedule_notifier.dart` (lines
500-750 per research), `today_row_widgets_test.dart` (lines 1-60), `schedule_notifier_break_extension_test.dart`
(G-05 group, lines 204-236).
**Pattern extraction date:** 2026-08-25
