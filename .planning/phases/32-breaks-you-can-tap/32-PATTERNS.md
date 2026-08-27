# Phase 32: Breaks You Can Tap - Pattern Map

**Mapped:** 2026-08-27
**Files analyzed:** 7 (1 new, 6 modified) — test files tracked separately in "Test Patterns"
**Analogs found:** 6 / 7 (constant-only file has no single analog; it's an arithmetic edit)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/widgets/break_skip_button.dart` (NEW) | component (shared button) | request-response (tap → notifier call) | `chunk_card.dart:869-902` `_buildActionRow`'s Skip `OutlinedButton.icon` | role-match (button chrome differs — `Material`/`InkWell` vs `OutlinedButton` — but the `onPressed`/`markSkipped` wiring is identical) |
| `lib/screens/schedule/widgets/chunk_card.dart` (`_buildBreak`) | component | transform (density → widget tree) | `chunk_card.dart:596-670` `_WorkChunkContent.build`'s `Card` container (the "discretionary-goal Card") | exact (container shape/color/clipBehavior is the stated analog to copy) |
| `lib/screens/today/widgets/live_row_card.dart` (`_buildSingleLine`) | component | transform | `live_row_card.dart:158-249` `_buildCompact`'s `showActions`-gated action row | exact (same file, sibling tier — this is the canonical "what single-line must gain" analog) |
| `lib/screens/today/today_screen.dart` (`_buildPositionedRow`, `_needsSlop`, Layer 1b pass) | controller/screen-wiring | transform | The file's own unchanged work-chunk arm (`today_screen.dart:948-969`, `:859-878`) | exact (break arm collapses to literally the same shape) |
| `lib/screens/schedule/widgets/swipeable_chunk_card.dart` | component | event-driven (gesture) | Git history / `32-UI-SPEC.md`'s quoted restoration snippet (pre-Phase-31 early return) | exact (this is a revert, not a new pattern) |
| `lib/screens/today/timeline_geometry.dart` | utility (pure constants) | transform (arithmetic) | itself — no external analog needed, this is a value-and-comment edit per the RESEARCH.md reachability table | n/a (arithmetic migration) |
| `test/screens/*_test.dart` (multiple) | test | transform (widget/geometry assertions) | `test/screens/today_timeline_model_test.dart:479-501` (SEEBREAK-02) | exact (this is the canonical "derive vs. bare-literal-with-comment" style to copy) |

## Pattern Assignments

### `lib/widgets/break_skip_button.dart` (NEW component, request-response)

**Analog:** `lib/screens/schedule/widgets/chunk_card.dart:869-902` (`_buildActionRow`, the work-chunk Skip button)

**The exact call to replicate** (`chunk_card.dart:886-899`):
```dart
Tooltip(
  message: 'Skip',
  child: OutlinedButton.icon(
    icon: const Icon(Icons.skip_next_outlined),
    label: const Text('Skip'),
    onPressed: () =>
        context.read<ScheduleNotifier>().markSkipped(chunk.id),
    style: OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      foregroundColor: theme.colorScheme.error,
      side: BorderSide(color: theme.colorScheme.error),
    ),
  ),
),
```
Reuse: the bare `onPressed: () => context.read<ScheduleNotifier>().markSkipped(chunkId)` call verbatim, the `Icons.skip_next_outlined` icon (don't invent a second skip glyph), and the visible label `'Skip'` (don't invent new copy — UI-SPEC's copywriting contract locks this).

Do NOT copy the `OutlinedButton` chrome itself — `32-UI-SPEC.md`'s widget tree (already fully specified, see below) uses `Material`/`InkWell` with `errorContainer`/`onErrorContainer` fill instead, because the button must fill the entire 64×slot rail rather than size to its own content the way `OutlinedButton` does.

**Full target widget tree (already specified, copy verbatim from `32-UI-SPEC.md` "The Skip rail"):**
```dart
class BreakSkipButton extends StatelessWidget {
  const BreakSkipButton({super.key, required this.chunkId, required this.accessibleTitle});
  final String chunkId;
  final String accessibleTitle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: 'Skip $accessibleTitle',
      child: Material(
        color: colorScheme.errorContainer,
        child: InkWell(
          onTap: () => context.read<ScheduleNotifier>().markSkipped(chunkId),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.skip_next_outlined, color: colorScheme.onErrorContainer, size: 18),
                Text('Skip', style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onErrorContainer, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Imports pattern** (match `chunk_card.dart:1-6` convention — relative imports, no path aliases):
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/schedule_notifier.dart';
```

**Error handling:** none needed in this widget — `markSkipped`'s own revert-and-rethrow (WR-05, `schedule_notifier.dart:687-745`) already handles failure; the button just calls it and lets the notifier's `notifyListeners()` drive the rebuild. Do not add a try/catch here.

---

### `chunk_card.dart`'s `_buildBreak` (redesigned compact/full tiers)

**Analog — the exact `Card` shape to copy (`_WorkChunkContent.build`, `chunk_card.dart:600-604`):**
```dart
child: Card(
  margin: const EdgeInsets.symmetric(vertical: 4),
  color: cardColor,
  shape: cardShape,
  clipBehavior: Clip.antiAlias,
  ...
```
The UI-SPEC's break card mirrors this exactly: `RoundedRectangleBorder(borderRadius: 12, side: BorderSide(color: colorScheme.outlineVariant))`, `color: colorScheme.surfaceContainer`, `clipBehavior: Clip.antiAlias` — same three properties (color, shape, clipBehavior), different color role and no left accent bar (breaks have no goal color — `!isCommitment` bar logic at `chunk_card.dart:607-624` is explicitly NOT copied).

**What to delete alongside this rewrite** (verified references, `chunk_card.dart`):
- `_SubCompactRow` class (`:384-498+`) and its `subCompact` enum arm (`:34-52`, `:161-169` reachable branch, `:648-661` dead work-chunk fallback arm)
- `kSubCompactGripSize` (`:348`)
- `_DashedBorderPainter` (`:290-338`) — both call sites in the old `_buildBreak` (`:184-216` compact, `:233-282` full)

**Current `_buildBreak` compact tier being replaced** (`chunk_card.dart:174-217`, for reference — the `Semantics(excludeSemantics: true, ...)` wrapper pattern here must NOT be copied onto the new card per `32-UI-SPEC.md`'s explicit warning, since the new card contains a real focusable `BreakSkipButton` child that `excludeSemantics: true` would swallow):
```dart
if (density == ChunkCardDensity.compact) {
  return Semantics(
    label: '$title, ${chunk.durationMinutes} min${chunk.isSkipped ? ", skipped" : ""}',
    excludeSemantics: true,   // <-- DO NOT carry this forward; see UI-SPEC warning
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Opacity(
        opacity: chunk.isSkipped ? 0.5 : 1.0,
        child: CustomPaint(painter: _DashedBorderPainter(...), ...),
      ),
    ),
  );
}
```

**The `'skipped'` trailing-text vocabulary to reuse verbatim** (`chunk_card.dart:857-862`, `_buildTrailingStatus`):
```dart
: chunk.isSkipped
    ? Text(
        'skipped',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      )
```
This is the exact string/style the new rail's resolved-state `_SkippedIndicator` must reuse (per UI-SPEC: "verbatim reuse of D-31-04's existing 'skipped' string").

---

### `live_row_card.dart`'s `_buildSingleLine` (gains action rail)

**Analog — the compact tier's `showActions`-gated action row (`live_row_card.dart:214-232`):**
```dart
if (showActions) ...[
  if (showComplete)
    _buildActionIcon(
      icon: Icons.check_circle_outline,
      color: colorScheme.primary,
      tooltip: 'Complete',
      onPressed: () =>
          context.read<ScheduleNotifier>().markComplete(chunkId),
    ),
  _buildActionIcon(
    icon: Icons.skip_next_outlined,
    color: colorScheme.error,
    tooltip: 'Skip',
    onPressed: () =>
        context.read<ScheduleNotifier>().markSkipped(chunkId),
  ),
],
```
`_buildSingleLine` (`live_row_card.dart:303-345`) currently ignores `showActions`/`showComplete` entirely — this is the exact regression `32-UI-SPEC.md` names. The fix is NOT to copy `_buildActionIcon`'s `IconButton` chrome (that's sized for the compact tier's own inline icon-pair layout) — it's to wrap `_buildSingleLine`'s existing `Row` in `crossAxisAlignment: stretch` and add a trailing `SizedBox(width: kBreakSkipButtonWidth, child: BreakSkipButton(...))`, gated on `showActions` the same way the compact tier gates its icons.

**Current single-line body to modify** (`live_row_card.dart:317-345`):
```dart
child: Row(
  crossAxisAlignment: CrossAxisAlignment.center,   // change to .stretch
  children: [
    Expanded(child: Text(title, ...)),
    Text(' · $remainingLabel', maxLines: 1, style: style),
  ],
),
```

---

### `today_screen.dart`'s break arm of `_buildPositionedRow`

**Analog — the file's OWN unchanged work-chunk arm** is the pattern to collapse the break arm into. Grep confirms the shapes at `today_screen.dart:948-969` (non-live work) and `:859-878` (live work) are the plain `Positioned(height: slot)` → `ClipRect` → `OverflowBox` chain with no slop and no `SwipeableRowShell` wrap. The break arm (`:776-841` live, `:931-946` non-live) must become structurally identical, differing only in which card widget (`ChunkCard` vs `LiveRowCard`) and parameters it passes.

**Restore this early return** (already quoted verbatim in `32-UI-SPEC.md`, confirmed as a revert of Phase 31's `promote` decision, `swipeable_chunk_card.dart:255-282` currently has NO such early return):
```dart
if (chunk.chunkType != ChunkType.work) {
  return ChunkCard(
    chunk: chunk,
    goalColor: goalColor,
    density: density,
    showStartTime: showStartTime,
  );
}
// ...existing work-chunk SwipeableRowShell path, unchanged below this line
```

**Delete alongside:** `_needsSlop(...)` (`today_screen.dart:697-706`), the Layer 1b `Stack` pass (`:1555-1599`), `kBreakHitSlop`/`kMinBreakDragTarget` (`timeline_geometry.dart:243,249`), and `SwipeableRowShell`'s now-dead `visualHeight`/`_confineReveal`/`_confineContent` (`swipeable_chunk_card.dart:30-92`) — see RESEARCH.md's "retirement surface" table for the exhaustive reference list per item; do not re-derive that list, it is already file:line verified.

---

## Test Patterns

### The house style for pixel-derived assertions (the single most important pattern in this phase)

**Analog:** `test/screens/today_timeline_model_test.dart:479-501` (SEEBREAK-02)

```dart
test(
    'SEEBREAK-02: heightFor returns the ground-truth pixel height for '
    'every break duration the lattice emits', () {
  // Expected values are bare double literals, per this file's own
  // GRID-01 test's discipline: they must NOT re-derive any
  // implementation-internal quantity (kPixelsPerMinute included), or
  // this test inherits the same self-referential blindness.
  final geometry = TimelineGeometry.forDay(
    nowMinutes: 550, firstStartMinutes: 480, lastEndMinutes: 1020,
  );
  expect(geometry.heightFor(540, 5), 20.0);   // -> update to 30.0 at 6.0
  expect(geometry.heightFor(600, 30), 120.0); // -> update to 180.0 at 6.0
});
```

**The rule to copy exactly, not paraphrase:** most test assertions should read `n * kPixelsPerMinute` symbolically (38 of the ~41 assertions in this suite already do this and need zero edits at the new 6.0). Only the 2-3 "canary" assertions whose entire purpose is to catch `kPixelsPerMinute` itself silently drifting should stay bare numeric literals — and each one MUST carry a comment stating that it is deliberately not derived from the constant (exactly as the comment above does). New tests this phase adds (the Skip-button-triggers-`markSkipped` tests, the live single-line regression test) should default to the symbolic style; only touch the 3 already-identified bare literals (`today_timeline_model_test.dart:499,500`, `today_screen_test.dart:2372`) and update their values, keeping them bare with the same style of comment.

**Anti-pattern, explicitly named in RESEARCH.md and must not be repeated:** a find-and-replace of literal values without re-deriving from the constant, or without checking whether the enclosing test's premise (e.g. a `subCompact`-tier test, or a swipe-gesture test) still holds at all post-migration. Classify each literal as "re-derive" (grid-honesty canary, survives) or "delete" (retired-mechanism test, e.g. anything with "drag"/"swipe"/"slop"/"D-31-06" in its title) before touching it.

### Tests to DELETE outright (gesture-dependent — do not migrate, remove)
`today_screen_test.dart` "Phase 31 — SKIPBREAK" group (~lines 2377-2840): the 7 `testWidgets` driving `tester.dragFrom(...)`. `today_screen_now_state_test.dart`'s live-break `Case A` (swipe) and `Case C` (re-swipe-after-resolved) — both drive `dragFrom`.

### Tests to KEEP, rewrite trigger only (assertions are correct, mechanism changes)
`today_screen_now_state_test.dart`'s `Case B — truth #14's composition, proven` — does not use `dragFrom`, constructs the fixture directly; keep as-is. Recommendation from RESEARCH.md: rewrite Case A/C in place (same `fake.lastSkippedId`/`fake.lastCompletedId` assertions, swap `dragFrom` for `tester.tap()` on the new button) rather than deleting and writing from scratch — the assertions themselves are valuable and correct.

### New test this phase must add (the regression this document exists to prevent)
A widget test asserting the live 5-minute break's single-line tier renders a tappable `BreakSkipButton` — per `32-UI-SPEC.md`'s own framing: "A test asserting this row is NOT skip-less is the single most important new test this phase adds."

## Shared Patterns

### Skip action wiring (cross-cutting: `BreakSkipButton`, `chunk_card.dart`, both call sites)
**Source:** `schedule_notifier.dart:687-745`, `markSkipped(String chunkId)` — already exists, type-agnostic, already carries the WR-05 revert-and-rethrow contract.
**Apply to:** every new Skip affordance in this phase. No new business logic — every call site is `onPressed: () => context.read<ScheduleNotifier>().markSkipped(chunkId)`, copied verbatim from `chunk_card.dart:891-892`.

### Density-driven tier selection (existing pattern, reused not invented)
**Source:** `today_screen.dart:891-899` (density ternary), `live_row_card.dart:136-138` (`LiveRowCard.build`'s two-way split)
```dart
final density = isBreak
    ? (slot >= kFullBreakMinHeight ? ChunkCardDensity.full : ChunkCardDensity.compact)
    : (slot >= kFullTierMinHeight ? ChunkCardDensity.full : ChunkCardDensity.compact);
```
**Apply to:** the post-phase break ternary collapses to this exact two-way shape (matching the work ternary), once `subCompact` is deleted.

### Icon reuse — do not invent a second Skip glyph
**Source:** `Icons.skip_next_outlined`, already used at `chunk_card.dart:889` and (as the color-family precedent) `swipeable_chunk_card.dart:101-110`'s retired `_skipReveal` (`colorScheme.error`).
**Apply to:** `BreakSkipButton`. New usage of an existing role (`errorContainer`/`onErrorContainer` instead of bare `error`) — not a new color, per `32-UI-SPEC.md`'s Color table.

### `Icons.drag_indicator` name collision — do not touch unrelated usage
**Source:** `lib/screens/goals/goals_screen.dart:254,276` (goal-reordering drag handle) and its test `test/screens/goal_card_drag_handle_test.dart`.
**Apply to:** any retirement/deletion pass touching `chunk_card.dart`'s `_SubCompactRow` grip glyph — scope the deletion to that class specifically, never a bare project-wide grep-and-replace of `drag_indicator`.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/screens/today/timeline_geometry.dart` (constant edits) | utility | transform | Pure value/comment migration against a fully-specified reachability table (RESEARCH.md "Constant re-derivation and reachability"); there is no comparable prior in-file analog to copy from — copy the table's values directly instead. |

## Metadata

**Analog search scope:** `lib/screens/schedule/widgets/`, `lib/screens/today/`, `lib/screens/today/widgets/`, `lib/widgets/`, `test/screens/`
**Files read this session:** `chunk_card.dart` (imports, enum, `_buildBreak`, `_DashedBorderPainter`, `_SubCompactRow`, `_WorkChunkContent.build`, `_buildActionRow`, `_buildTrailingStatus`), `live_row_card.dart` (`_buildCompact`, `_buildActionIcon`, `_buildSingleLine`), `today_timeline_model_test.dart` (SEEBREAK-02)
**Pattern extraction date:** 2026-08-27
