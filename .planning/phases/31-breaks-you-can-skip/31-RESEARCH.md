# Phase 31: Breaks You Can Skip - Research

**Researched:** 2026-08-25
**Domain:** Flutter gesture/hit-testing internals (`Dismissible`, `Stack`/`Positioned`, `ClipRect`/`OverflowBox`), and this codebase's existing swipe-to-resolve + schedule-mutation machinery.
**Confidence:** HIGH — every claim below with a `[VERIFIED: ...]` tag was checked by reading the cited file (this codebase or the Flutter SDK at `/home/dan/development/flutter`) this session; line numbers and verbatim quotes are given so the planner can re-check them directly.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Goal:** A break can be skipped the same way a work chunk can — at every density, including the
5-minute one — without the timeline lying about how long anything takes.

**In scope:**
1. Swipe-to-skip on break chunks at **every** density tier (not just sub-compact).
2. Resolving the 20dp grab-target problem for a 5-minute break's row, **without** growing the row.
3. Deciding and documenting what skipping a break MEANS in a duration-exact, time-anchored timeline.
4. A skipped-break visual state at every density, including Phase 29's `_SubCompactRow`, which
   currently has no completed/skipped state at all.

**Explicitly OUT of scope:**
- **Tappable break cards.** No `onTap`, no detail sheet. Owner's direct instruction, 2026-08-21.
- **Pulling the day forward when a break is skipped.** That is an engine change of a completely
  different size. If planning concludes it is required, **stop and ask** rather than widening
  scope unilaterally.
- **Raising `kPixelsPerMinute`.** Rejected in Phase 29 (D-03) and still rejected.

**Requirements:**
- **SKIPBREAK-01** — a break can be skipped at every density, by the same gesture that skips a work
  chunk.
- **SKIPBREAK-02** — the true grid is preserved: no break grows to accommodate its own gesture
  target. Rendered height never deviates from `durationMinutes × kPixelsPerMinute` (SEEBREAK-02
  still holds).

### Claude's Discretion (open questions the CONTEXT.md left unresolved before the UI-SPEC settled them)

- D-31-01 — Swipe direction(s) for a break. **Resolved by `31-UI-SPEC.md`: one-directional,
  `DismissDirection.endToStart` only.**
- D-31-02 — The 20dp grab target. **Resolved by `31-UI-SPEC.md`: grow the hit-test envelope, not
  the painted slot** — this research file's own centerpiece finding (below) corrects one part of
  that mechanism.
- D-31-03 — What skipping a break means. **Resolved: "mark it skipped and move on," no engine
  change.**
- D-31-04 — Skipped-break rendering at sub-compact. **Resolved: `Opacity(0.5)` +
  `TextDecoration.lineThrough`, reusing the work-chunk resolved-state vocabulary.**

### Deferred Ideas (OUT OF SCOPE)

- Tappable break cards / break detail sheet — ruled out by the owner, 2026-08-21.
- Pulling the day forward on a skipped break (reclaiming the 5 minutes) — out of scope; requires an
  explicit owner decision before it could be planned.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SKIPBREAK-01 | A break can be skipped at every density, by the same gesture that skips a work chunk | "Architecture Patterns" §1–2 below: `SwipeableChunkCard`'s existing `endToStart`/`markSkipped` wiring for work chunks, extended to breaks per `31-UI-SPEC.md` D-31-01; `markSkipped` is already type-agnostic (verified, `schedule_notifier.dart:678-739`) |
| SKIPBREAK-02 | The true grid is preserved — no break grows to accommodate its own gesture target | "Architecture Patterns" §3 below (the corrected hit-test-envelope mechanism) and "Common Pitfall 1" (the z-order gap this research found in the UI-SPEC's mechanism, which the plan must close for SKIPBREAK-02's touch-target claim to actually hold) |

</phase_requirements>

## Summary

The mechanism this phase needs is ~95% already built and this research confirms every load-bearing
claim in `31-UI-SPEC.md` against the actual source — with one important correction. `markSkipped`
(`schedule_notifier.dart:678-739`) is already fully type-agnostic and its streak write-back guard
(`chunk.goalId != null && chunk.goalId!.isNotEmpty`, line 706) is provably inert for breaks because
`ScheduledChunk.goalId` is documented `null` for break types (`scheduled_chunk.dart:8`).
`SwipeableChunkCard` (`swipeable_chunk_card.dart:74-82`) excludes breaks with one explicit early
return — deleting it and adding a one-directional (`endToStart`) `Dismissible` branch is the entire
SKIPBREAK-01 wiring task. The D-31-05 guard gap in `_absorbReclaimedTimeIntoNextBreak`
(`schedule_notifier.dart:529-592`) is real and exactly as described: none of its eight guards check
`next.isSkipped`, so once breaks can be skipped, an early-completed preceding work chunk can move or
extend an already-skipped break's start/duration out from under its own skipped state.

The centerpiece question — does the existing per-row `ClipRect` prevent a grown hit-test
envelope — resolves to **"yes, if `ClipRect` stays wrapped tightly around the row; no, if the
envelope is grown by enlarging the outer `Positioned`/`Dismissible` box itself and `ClipRect` is
pushed down to wrap only the confined, slot-sized paint content."** `31-UI-SPEC.md`'s proposed
widget arrangement does the latter, and this research independently verified — by reading Flutter's
`RenderBox.hitTest`, `RenderClipRect.hitTest`, and `Dismissible`'s `build()` — that the mechanism is
sound **in principle**.

**But there is a genuine, previously-unaddressed gap in the UI-SPEC's own "no theft" proof.** Its
proof is about *reach* (can a hit test propagate past a `ClipRect` boundary) — verified true. It
does not address *contested-overlap resolution*: once a break's grown `Positioned` box is taller than
its own slot, it geometrically **overlaps** the neighboring (unenlarged) work-chunk rows above and
below for the first time ever in this codebase, and `Stack`'s hit-test order (last-added child wins,
verified against Flutter's `defaultHitTestChildren`) decides which sibling wins that overlap — not
which one is "correct." Because `timelineRows`/`buildTimeline` preserves chronological order
(verified, `timeline.dart:67-70`) and `today_screen.dart`'s Layer-1 loop adds rows to the `Stack` in
that same order, the *later*-added sibling always wins a contested pixel. Concretely: **the top slop
band works as intended (the break, added later than its preceding work chunk, wins that overlap) but
the bottom slop band does not (the following work chunk, added later than the break, wins that
overlap and swallows the break's own bottom slop) — halving the break's effective grown target from
the claimed 52dp down to ~36dp, still short of both Material's 48dp and iOS's 44pt targets.** This is
fixable (render slop-bearing breaks in a dedicated later pass, mirroring the existing live-row PD-10
pattern) but it must be planned explicitly — it is not "already handled" by the widget tree
`31-UI-SPEC.md` describes.

**Primary recommendation:** Implement D-31-01/03/04 exactly as `31-UI-SPEC.md` specifies (all
independently verified against source below); implement D-31-02's grown-envelope mechanism with one
correction — render every sub-48dp break's `Positioned` in a **third Stack pass**, added after the
normal Layer-1 loop (and before the now-line overlay), so its z-order always wins both the top *and*
bottom slop bands against its chronological neighbors, regardless of iteration order. Fix D-31-05's
guard gap with one added `if (next.isSkipped) return null;` line, proven RED first.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Swipe gesture recognition (Dismissible/GestureDetector) | Browser/Client (Flutter widget/render tree) | — | Pure client-side gesture handling; no network or persistence involvement |
| Grown hit-test envelope geometry | Browser/Client (`today_screen.dart` row layout) | — | A pixel-geometry decision entirely inside the render tree; `TimelineGeometry` (the app's one minute→pixel authority) is consulted but not modified |
| `markSkipped` state mutation + persistence | API/Backend equivalent — `ScheduleNotifier` (app-local business logic) | Database/Storage (Hive box via `_repo.save`) | Flutter has no server tier; `ScheduleNotifier` is this app's business-logic layer, and Hive is its local persistence layer — both already handle work-chunk skipping, unchanged for breaks |
| Habit-streak recompute on skip | API/Backend equivalent — `ScheduleNotifier` (`_goalRepo`/`computeStreak`) | Database/Storage (Goal Hive box) | Already-shared code path with work-chunk skip; the `goalId` guard makes it inert for breaks, not a new capability |
| `_absorbReclaimedTimeIntoNextBreak` guard fix (D-31-05) | API/Backend equivalent — `ScheduleNotifier` | — | Pure business-logic guard addition; no UI or storage schema involvement |
| Skipped-break visual treatment (opacity/strikethrough/trailing text) | Browser/Client (`chunk_card.dart`) | — | Presentation only; reuses the existing work-chunk resolved-state vocabulary |

## Standard Stack

No new external packages. This phase is Flutter/Material 3 built-ins only:

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter` SDK `Dismissible` | bundled with Flutter (project pins `sdk: ^3.10.3`) | Swipe-to-dismiss gesture recognition, already used for work chunks | Already the project's own established pattern (`swipeable_chunk_card.dart`); no reason to hand-roll a second gesture mechanism |
| `flutter` SDK `Stack`/`Positioned`/`ClipRect`/`OverflowBox` | bundled | Absolute row positioning, overflow safety net (PD-10) | Already the project's one layout mechanism for the Today timeline (`26-03-PLAN.md` CAL-01) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Growing the `Dismissible`'s own hit-test box | A `GestureDetector` layered independently on top of the row, sized to the grown envelope, forwarding `onHorizontalDragEnd` to `markSkipped` manually | Would duplicate `Dismissible`'s swipe-reveal animation, threshold logic, and haptics by hand — exactly the kind of hand-rolled gesture machinery "Don't Hand-Roll" below argues against. `31-UI-SPEC.md`'s approach (grow `Dismissible` itself) reuses all of that for free. |
| A lower `dismissThresholds` value for short rows | Tuning `Dismissible.dismissThresholds` down from the default 0.4 | `31-UI-SPEC.md` already rejects this correctly (and this research independently verified why, see Architecture Patterns §2): the threshold is a fraction of **width**, not height, so a 20dp-tall row has an identical horizontal drag distance to a 120dp one. Tuning it would be an unforced, unevidenced deviation. |

**Installation:** none required — no `pubspec.yaml` changes.

## Package Legitimacy Audit

**Not applicable.** This phase installs no new packages — it wires existing Flutter SDK widgets
(`Dismissible`, `Stack`, `ClipRect`, `OverflowBox`) that are already imported and used elsewhere in
this codebase. `Package Legitimacy Gate` protocol is skipped per its own precondition (no external
package installs).

## Architecture Patterns

### System Architecture Diagram

```
User's finger (touch-down + horizontal drag, left-swipe)
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│ Stack (today_screen.dart's _timelineStackKey SizedBox)       │
│                                                                │
│  hit-test walks children last-added → first, STOPS at first  │
│  child whose own hitTest() succeeds (Flutter SDK              │
│  RenderBox.defaultHitTestChildren, box.dart:3337-3356)        │
│                                                                │
│  ┌──────────────┐  ┌──────────────────┐  ┌──────────────┐   │
│  │ preceding     │  │ break row         │  │ following     │   │
│  │ work chunk    │  │ Positioned        │  │ work chunk    │   │
│  │ Positioned    │  │ (grown envelope,  │  │ Positioned    │   │
│  │ (unenlarged)  │  │  D-31-02)         │  │ (unenlarged)  │   │
│  └──────────────┘  └──────────────────┘  └──────────────┘   │
│        added earlier      added ???           added later     │
│        in timelineRows    (this research's     in timelineRows│
│        order              key finding: MUST    order          │
│                            be added in a THIRD  │              │
│                            pass, after BOTH      │              │
│                            neighbors, or the     │              │
│                            bottom slop band is   │              │
│                            silently won by the   │              │
│                            following work chunk) │              │
└─────────────────────────────────────────────────────────────┘
        │ (touch resolves to exactly one row's Dismissible)
        ▼
Dismissible's own GestureDetector (behavior: opaque, dismissible.dart:117)
        │ drag crosses dismissThresholds[endToStart] (fraction of WIDTH,
        │ dismissible.dart:361-364) — row height is irrelevant to this axis
        ▼
confirmDismiss(endToStart) → ScheduleNotifier.markSkipped(chunk.id)
        │
        ├── chunk.isSkipped = true
        ├── _repo.save(schedule)               (Hive persistence)
        ├── _logRepo.append(CompletionLog(...))
        └── if chunk.goalId is non-null/non-empty: recompute streak
             (ALWAYS false for a break — scheduled_chunk.dart:8,
              "Break types have null goalId")
        │
        ▼
notifyListeners() → chunk_card.dart re-renders with isSkipped:true
        (Opacity(0.5) + TextDecoration.lineThrough, D-31-04)
```

### Pattern 1: `SwipeableChunkCard`'s existing work-chunk gesture wiring (the template to extend)

**What:** `swipeable_chunk_card.dart` wraps every chunk row. Its early return excludes breaks:

```dart
// swipeable_chunk_card.dart:74-82 — VERIFIED, read this session
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

The `Dismissible` for work chunks (lines 84-136) already does everything SKIPBREAK-01 needs, just
bidirectionally:

```dart
// swipeable_chunk_card.dart:84-102 — VERIFIED
Dismissible(
  key: ValueKey(chunk.id),
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
  background: /* colorScheme.primary, check_circle */,
  secondaryBackground: /* colorScheme.error, arrow_forward */,
  child: ChunkCard(...),
)
```

**When to use:** This is the direct template for the break branch — same `confirmDismiss` pattern
(call `markSkipped`, always return `false`), same `colorScheme.error`/`arrow_forward` reveal (reused
verbatim per `31-UI-SPEC.md`), `direction` narrowed to `endToStart` only (no `background`, since
there is no `startToEnd` direction to reveal it for — per the `Dismissible` API, only the
enabled direction(s)' backgrounds need be supplied).

### Pattern 2: `dismissThresholds` is a fraction of the drag axis's *extent*, not an absolute distance — VERIFIED against Flutter SDK source

```dart
// flutter/packages/flutter/lib/src/widgets/dismissible.dart:361-364 — VERIFIED, read this session
double get _overallDragAxisExtent {
  final Size size = context.size!;
  return _directionIsXAxis ? size.width : size.height;
}
```

For `DismissDirection.endToStart` (or `horizontal`/`startToEnd`), `_directionIsXAxis` is `true`
(`dismissible.dart:337-341`), so `_overallDragAxisExtent` is the Dismissible's own **width**. The
default `_kDismissThreshold = 0.4` (`dismissible.dart:22`) is a fraction of that width. **Row
height (20dp for a 5-minute break vs. 120dp for a 30-minute one) has zero effect on the drag
distance required to complete a skip swipe** — a break's `Dismissible` spans the same full row width
work chunks already use (`left: 0, right: 0` on the `Positioned`), so the horizontal travel distance
to reach threshold is identical to the shipped, working work-chunk swipe. This independently confirms
`31-UI-SPEC.md`'s claim that tuning `dismissThresholds` for short rows is unnecessary.

### Pattern 3: The corrected hit-test-envelope mechanism (D-31-02 / SKIPBREAK-02)

**The question this research was asked to resolve definitively:** does the existing per-row
`ClipRect` (Clip.hardEdge-style clip, wrapping every row today) prevent a grown hit-test envelope
from working at all?

**Answer, with the exact mechanism, verified against Flutter SDK source read this session:**

1. **`RenderBox.hitTest`'s base implementation already bounds every render box to its own `size`,
   independent of any `ClipRect`:**

   ```dart
   // flutter/packages/flutter/lib/src/rendering/box.dart:2952-2958 — VERIFIED
   if (_size!.contains(position)) {
     if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
       result.add(BoxHitTestEntry(this, position));
       return true;
     }
   }
   return false;
   ```

   This applies to EVERY `RenderBox`, including `ClipRect`'s own render object (`RenderClipRect`
   extends `_RenderCustomClip<Rect>` extends `RenderProxyBox` extends `RenderBox`, which does not
   override this method for the no-custom-clipper case). `ClipRect`'s own `hitTest` override
   (`proxy_box.dart:1627-1637`) *adds* a further clip-rect check **only if a custom `clipper` was
   supplied**:

   ```dart
   // flutter/packages/flutter/lib/src/rendering/proxy_box.dart:1627-1637 — VERIFIED
   @override
   bool hitTest(BoxHitTestResult result, {required Offset position}) {
     if (_clipper != null) {
       _updateClip();
       assert(_clip != null);
       if (!_clip!.contains(position)) {
         return false;
       }
     }
     return super.hitTest(result, position: position);
   }
   ```

   `today_screen.dart`'s row wrapper uses the PLAIN `ClipRect(child: OverflowBox(...))` — **no
   `clipper:` argument** — so this extra check never fires; the bound comes entirely from `ClipRect`'s
   own `size`, which base `RenderBox.hitTest` already enforces.

2. **Today's row structure gives `ClipRect` a tight `size` of exactly `slot`, because `Positioned`
   passes tight constraints:**

   ```dart
   // today_screen.dart:812-827 — VERIFIED (current, un-modified break/work-chunk arm)
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
         child: TimelineRowTile(
           child: _buildChunkCard(context, chunk, density),
         ),
       ),
     ),
   );
   ```

   `Positioned(top:, left:0, right:0, height: slot)` gives its child (`ClipRect`) **tight**
   constraints of `height: slot`, so `ClipRect.size == Size(width, slot)`. Per finding 1, this alone
   — with no custom clipper needed — already rejects any hit test whose local Y falls outside
   `[0, slot)` **before it ever reaches the `Dismissible` nested inside**.

   **Conclusion: yes, if `ClipRect` stays wrapped tightly around the whole row (as it is today),
   growing anything nested *inside* it (e.g. giving `Dismissible` its own larger internal hit box)
   is structurally impossible — the outer `ClipRect`'s own `size.contains()` check rejects the touch
   before `Dismissible` is ever reached.**

3. **`31-UI-SPEC.md`'s proposed arrangement avoids this by growing the `Positioned` itself (and
   therefore whatever is its DIRECT child's `size`) to `slot + topSlop + bottomSlop`, and moving
   `ClipRect` DOWN inside the confined, slot-sized content — not around the whole `Positioned`:**

   ```dart
   Positioned(
     top: geometry.yFor(start) - topSlop,
     left: 0, right: 0,
     height: slot + topSlop + bottomSlop,      // ← the Dismissible's OWN size
     child: Dismissible(
       key: ValueKey(chunk.id),
       direction: /* endToStart, unless resolved */,
       confirmDismiss: (_) async { await notifier.markSkipped(chunk.id); return false; },
       background: _confinedToSlot(slot, /* skip reveal */),
       child: _confinedToSlot(slot, ClipRect(child: OverflowBox(...))),  // ClipRect is now INSIDE, sized to `slot` only
     ),
   )
   ```

   Reading `Dismissible.build()` (`dismissible.dart:607-689`, verified this session) confirms this
   works: `Dismissible` wraps its `background`+`child` `Stack` in an outer
   `GestureDetector(behavior: widget.behavior, child: content)` where `behavior` defaults to
   `HitTestBehavior.opaque` (`dismissible.dart:117`). This `GestureDetector` is the OUTERMOST widget
   `Dismissible.build()` returns, so it inherits the FULL incoming constraints from the enclosing
   `Positioned` — i.e. its own render size is `slot + topSlop + bottomSlop`, **not** the size of its
   (now internally confined) `child`. Per `RenderProxyBoxWithHitTestBehavior.hitTest`
   (`proxy_box.dart:182-192`, verified):

   ```dart
   bool hitTest(BoxHitTestResult result, {required Offset position}) {
     var hitTarget = false;
     if (size.contains(position)) {
       hitTarget = hitTestChildren(result, position: position) || hitTestSelf(position);
       if (hitTarget || behavior == HitTestBehavior.translucent) {
         result.add(BoxHitTestEntry(this, position));
       }
     }
     return hitTarget;
   }
   @override
   bool hitTestSelf(Offset position) => behavior == HitTestBehavior.opaque;
   ```

   With `behavior == opaque`, `hitTestSelf` is unconditionally `true` for any `position` inside
   `size` — so a touch anywhere in the grown `slot + topSlop + bottomSlop` box registers a hit on
   this `GestureDetector`, **even in the slop band where the nested, confined `ClipRect` (now sized
   only to `slot`) would itself reject the touch** — because `hitTestSelf` short-circuits the `||`
   independent of `hitTestChildren`'s result. This is exactly the mechanism that lets a break's
   touch-target exceed its painted content: the OUTER box (Dismissible's GestureDetector) is grown;
   the INNER, confined box (ClipRect + `Align(center)+SizedBox(height:slot)`) stays exactly
   paint-accurate.

   **This confirms `31-UI-SPEC.md`'s mechanism is sound, provided the outer `ClipRect` currently
   wrapping the whole `Positioned` is removed/relocated exactly as it proposes — it cannot be left
   in place around the grown `Positioned`.**

4. **The gap this research additionally found and `31-UI-SPEC.md` does not address: `Stack`
   hit-test *resolution order* when a break's grown box now overlaps its neighbors.** See
   **Common Pitfall 1** below — this is the single most load-bearing correction in this document and
   the plan must resolve it explicitly, not inherit the UI-SPEC's widget tree unmodified.

### Pattern 4: `markSkipped` is already type-agnostic — verified line-exact

```dart
// schedule_notifier.dart:678-739 — VERIFIED, read in full this session
Future<void> markSkipped(String chunkId) async {
  if (_todaySchedule == null) return;
  final chunk = _todaySchedule!.chunks.where((c) => c.id == chunkId).firstOrNull;
  if (chunk == null || chunk.isSkipped) return;

  chunk.isSkipped = true;
  try {
    await _repo.save(_todaySchedule!);
    final dateYmd = _todaySchedule!.dateYmd;
    await _logRepo.append(CompletionLog(
      chunkId: chunkId,
      goalId: chunk.goalId ?? '',
      commitmentId: chunk.commitmentId,
      dateYmd: dateYmd,
      eventIndex: CompletionEvent.skipped.index,
    ));
    // line 706 — the streak guard:
    if (chunk.goalId != null && chunk.goalId!.isNotEmpty) {
      // ... streak recompute, only reachable for a non-null non-empty goalId
    }
  } catch (_) {
    chunk.isSkipped = false;   // WR-05 revert
    try { await _repo.save(_todaySchedule!); } catch (_) {}
    rethrow;
  } finally {
    notifyListeners();
  }
}
```

The guard at line 706 (`chunk.goalId != null && chunk.goalId!.isNotEmpty`) is provably inert for
every break because `ScheduledChunk.goalId` is documented and typed nullable, with an explicit
enum-level doc comment:

```dart
// scheduled_chunk.dart:8-9 — VERIFIED
/// Type of a scheduled chunk. Break types have null goalId.
enum ChunkType { work, shortBreak, longBreak }
```

and the field itself:

```dart
// scheduled_chunk.dart:31-33 — VERIFIED
/// null for break chunks
@HiveField(2)
String? goalId;
```

**No engine change is needed for D-31-03 to hold** — this confirms `31-UI-SPEC.md`'s claim exactly.
`markSkipped` needs zero modification; only the UI-layer gesture wiring (Patterns 1-3) is required to
make it reachable from a break row.

### Pattern 5: D-31-05's guard gap — verified line-exact, fix location identified

```dart
// schedule_notifier.dart:529-592 — VERIFIED, read in full this session
({ScheduledChunk chunk, int? previousStart, int previousDuration})?
_absorbReclaimedTimeIntoNextBreak(ScheduledChunk completed) {
  final schedule = _todaySchedule;
  if (schedule == null) return null;

  // Guard 1 (line 534): only a work chunk's early completion reclaims break time.
  if (completed.chunkType != ChunkType.work) return null;
  // Guard 2 (536-537): the completed chunk must itself have a clock position.
  final completedStart = completed.displayStartMinutes;
  if (completedStart == null) return null;

  final nowDt = _now();
  final nowMinutes = nowDt.hour * 60 + nowDt.minute;

  // Guard 3 (546): never move a break earlier than the work chunk's own start.
  if (nowMinutes < completedStart) return null;
  // Guard 4 (549-551): genuinely early — completing at/after scheduled end reclaims nothing.
  if (nowMinutes >= completedStart + completed.durationMinutes) return null;

  final byClock = schedule.chunks.where((c) => c.displayStartMinutes != null).toList()
    ..sort((a, b) => a.displayStartMinutes!.compareTo(b.displayStartMinutes!));
  final idx = byClock.indexOf(completed);
  if (idx == -1 || idx + 1 >= byClock.length) return null;
  final next = byClock[idx + 1];

  // Guard 5 (564-567): a following chunk exists and is a break.
  if (next.chunkType != ChunkType.shortBreak && next.chunkType != ChunkType.longBreak) {
    return null;
  }
  // Guard 6 (570): the break must be movable — a commitment-anchored chunk is never re-anchored.
  if (next.anchoredStartMinutes != null) return null;
  final breakStart = next.displayStartMinutes;
  if (breakStart == null) return null;

  // ← D-31-05's fix belongs HERE, after Guard 6, before Guard 7:
  //   if (next.isSkipped) return null;

  // Guard 7 (576): the break's window must not already be open.
  if (nowMinutes >= breakStart) return null;
  // Guard 8 (579-580): the reclaimed span must be strictly positive.
  final newDuration = (breakStart + next.durationMinutes) - nowMinutes;
  if (newDuration <= 0) return null;

  final previousStart = next.syntheticStartMinutes;
  final previousDuration = next.durationMinutes;
  next.syntheticStartMinutes = nowMinutes;
  next.durationMinutes = newDuration;
  return (chunk: next, previousStart: previousStart, previousDuration: previousDuration);
}
```

**No guard among the eight checks `next.isSkipped`** — verified by reading every line of the
function. Before this phase, a break could never be `isSkipped == true` (no UI path set it), so this
gap was inert. After this phase ships, it becomes reachable: skip break B, then complete the
immediately-*preceding* work chunk early, and this function will silently move/extend B's
`syntheticStartMinutes`/`durationMinutes` while `isSkipped` stays `true` — the row still *renders*
skipped (D-31-04) but its persisted position/duration silently changes underneath that rendering,
contradicting D-31-03 ("mark it skipped and move on. Every other chunk's start time is untouched").

**Fix, minimal:** one line, `if (next.isSkipped) return null;`, inserted after Guard 6 (line 570)
and before Guard 7 (line 576) — grouped with the other break-eligibility checks, before the
window-open check. `31-UI-SPEC.md`'s placement recommendation is confirmed correct against the
actual guard ordering.

### Pattern 6: Skipped-break rendering vocabulary — verified against `_WorkChunkContent`'s existing precedent

```dart
// chunk_card.dart:450-451 — VERIFIED (work-chunk precedent this phase's D-31-04 reuses)
final isResolved = chunk.isCompleted || chunk.isSkipped;
final contentOpacity = isResolved ? 0.5 : 1.0;
```

```dart
// chunk_card.dart:647-650 — VERIFIED (title decoration precedent)
final titleStyle = theme.textTheme.titleMedium?.copyWith(
  fontWeight: FontWeight.w600,
  decoration: isResolved ? TextDecoration.lineThrough : null,
);
```

```dart
// chunk_card.dart:757-771 — VERIFIED (trailing status precedent; 'skipped' string is VERBATIM,
// reused not re-authored)
Widget _buildTrailingStatus(ThemeData theme) {
  return chunk.isCompleted
      ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
      : chunk.isSkipped
      ? Text('skipped', style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant))
      : Icon(Icons.radio_button_unchecked, color: theme.colorScheme.onSurfaceVariant);
}
```

`_buildBreak`'s current sub-compact branch has NO `isSkipped` parameter at all — confirmed by reading
the full `_SubCompactRow` call site:

```dart
// chunk_card.dart:161-166 — VERIFIED (current state, before this phase)
if (density == ChunkCardDensity.subCompact) {
  return _SubCompactRow(
    label: title,
    semanticsLabel: '$title, ${chunk.durationMinutes} min',
  );
}
```

and `_SubCompactRow`'s own constructor (`chunk_card.dart:343-352`) takes only `label` and
`semanticsLabel` — no resolved-state parameter exists yet, confirming `31-UI-SPEC.md`'s claim that
this tier needs a new `isSkipped` param added (default `false`, so the one existing call site at line
560-564 for the dead work-chunk fallback arm is unaffected unless explicitly passed).

The `compact` tier (`chunk_card.dart:171-195`) currently has **no `Semantics` wrapper at all** —
confirmed by reading the full branch; `31-UI-SPEC.md`'s requirement to add one for the skipped state
is not optional cleanup, it closes a real, pre-existing accessibility gap this phase's own change
would otherwise make worse (a struck-through/half-opacity break with zero screen-reader signal).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Swipe-to-skip gesture recognition, threshold detection, spring-back animation, haptics | A custom `GestureDetector` + `AnimationController` replicating `Dismissible`'s drag/threshold/spring-back state machine | `Dismissible` (already used for work chunks) | `Dismissible` already solves fling detection, direction locking, spring-back-on-reject, and cross-axis offset — re-deriving this by hand for breaks would duplicate ~90 lines of stateful animation logic (`dismissible.dart:298-690`) that this project would then own two copies of |
| Growing a widget's touch target beyond its paint bounds | A custom `RenderBox` subclass overriding `hitTest` | `Positioned` sized larger than the confined paint content (`Align(center)+SizedBox(height: slot)`) inside it | Flutter's own `RenderBox.hitTest`/`RenderProxyBoxWithHitTestBehavior` machinery (verified above) already supports exactly this pattern — a grown outer box with confined inner paint — without any custom render object |
| Habit-streak recompute on skip | A break-specific streak no-op branch | The existing `goalId != null && isNotEmpty` guard (already present, already correct for breaks) | Building a new conditional would duplicate logic that's already provably correct; verified this session, not assumed |

**Key insight:** every piece of machinery this phase needs (gesture recognition, threshold detection,
hit-test-vs-paint separation, streak-write inertness) already exists in this codebase or the Flutter
SDK. The entire phase is *wiring* — extending an existing `Dismissible` branch, adding one guard
line, and reusing an existing resolved-state visual vocabulary — not building anything new. The one
genuinely new piece of logic (the grown hit-test envelope and its Stack z-order fix) is a
geometry/ordering decision, not a new gesture-handling mechanism.

## Common Pitfalls

### Pitfall 1: Stack hit-test z-order silently neutralizes half the grown envelope — THE load-bearing finding

**What goes wrong:** If the break's grown-envelope `Positioned` is added to the Stack's `children`
list in the same chronological-order loop as its neighbors (as `31-UI-SPEC.md`'s widget-tree snippet
implies, by not calling out any special ordering), the break's effective touch target is **not**
`slot + 2×kBreakHitSlop` — it is closer to `slot + kBreakHitSlop` (only the top slop band works).

**Why it happens:** `Flutter`'s `Stack` resolves hit tests among overlapping siblings by walking from
`lastChild` backward and stopping at the first hit (verified, `box.dart:3337-3356`,
`defaultHitTestChildren`). Before this phase, every row's `Positioned` box was exactly `height: slot`
with zero gap between rows (`workTop + workSlot == breakTop`), so no two siblings' hit-test boxes
ever overlapped — hit-test order was irrelevant. This phase is the first to introduce **overlap**: a
sub-48dp break's grown box now covers pixels that are *also* still geometrically inside its
unenlarged neighbors' own boxes (their own `Positioned` extent did not shrink). `timelineRows`
preserves chronological order (verified, `timeline.dart:67-70`, doc-quoted below), and
`today_screen.dart`'s Layer-1 loop (`today_screen.dart:1387-1397`) adds rows to the Stack's
`children` in that same order — so for the **top** slop band (shared with the *preceding* work
chunk), the break (added later, chronologically) wins the contested pixels correctly. But for the
**bottom** slop band (shared with the *following* work chunk), the *following* work chunk is added
**even later** than the break — so it wins that overlap, and touches in the break's bottom slop band
resolve to the following work chunk's own `Dismissible`, not the break's.

Quoted source confirming `timelineRows`' ordering guarantee:
```dart
// timeline.dart:67-70 — VERIFIED
/// INVARIANT 2: the incoming [chunks] order is preserved and never
/// re-sorted — the schedule generator already emits clock order
/// (schedule_generator.dart STEP D), and re-sorting here would silently
/// reposition untimed chunks.
```

**How to avoid:** render every sub-48dp break's grown-envelope `Positioned` in a **dedicated third
Stack pass** — added to the `children` list *after* the normal Layer-1 non-live loop (and before the
now-line overlay), mirroring the existing pattern this codebase already uses for the live row (PD-10,
`today_screen.dart` comment: "the live row's Positioned last... so a future content addition that
overruns its reservation paints over its neighbour rather than being clipped by one painted after
it"). This guarantees the break's `Positioned` is always `lastChild`-ward of BOTH its chronological
neighbors, so it wins hit-test priority in both the top and bottom slop bands regardless of iteration
order. (A `full`/`compact`-tier break never needs slop — `kMinBreakDragTarget` gates it — so this
third pass only ever needs to carry the rare sub-48dp break rows, not every break.)

**Warning signs:** a widget test that drags from a y-offset just below a break's painted bottom edge
and expects `markSkipped` to fire, but instead observes the *following* work chunk's
`markComplete`/`markSkipped` fire (or nothing, if the following chunk is already resolved and its
`direction` is `DismissDirection.none`).

### Pitfall 2: `dismissThresholds` intuition — do not assume row height matters

Verified above (Architecture Patterns §2): the threshold is a fraction of the Dismissible's own
**width**, computed fresh from `context.size!.width` at drag time. A 20dp-tall break row spans the
same width as any other row (`left: 0, right: 0`), so its horizontal swipe distance is unaffected by
the height problem D-31-02 solves. Do not conflate "the row is short" with "the row is hard to
swipe once started" — those are two independent axes (grab-target height vs. drag-completion width).

### Pitfall 3: `ClipRect`'s hit-test-clipping behavior is easy to misattribute

The correct mental model, verified this session: **every `RenderBox` bounds hit-testing to its own
`size` by default** (`box.dart:2952`) — this is not a `ClipRect`-specific behavior. `ClipRect`'s own
`hitTest` override only adds an *additional* check, and only when a custom `clipper:` is supplied
(`proxy_box.dart:1627-1637`), which this codebase's usage never does. Do not reason "removing
`ClipRect` will let the envelope grow" — removing `ClipRect` changes nothing about the hit-test bound
here (it was never the source of it); the bound comes from whatever `RenderBox` receives the tight
`height: slot` constraint from `Positioned`. The fix is to give that receiving box (now `Dismissible`,
not `ClipRect`) a *larger* height, and push `ClipRect` down to wrap only the confined inner content.

### Pitfall 4: A live break has no skip affordance today, and this phase does not obviously add one

`LiveRowCard`'s Complete/Skip icon buttons are explicitly work-chunk-only:

```dart
// live_row_card.dart:80-82 — VERIFIED
/// Complete/Skip are for work chunks only (UI-SPEC "Actions row"). False
/// hides both buttons entirely. Only the compact tier renders them.
final bool showActions;
```

```dart
// today_screen.dart:979 — VERIFIED (the one call site)
showActions: chunk.chunkType == ChunkType.work,
```

A break that is *currently live* (the now-line falls inside its slot) renders through `_buildLiveRow`
→ `LiveRowCard`, a completely different widget than the swipeable `ChunkCard` this phase's gesture
wiring targets — and `LiveRowCard` never shows Complete/Skip for a break, before or after this phase,
unless the plan explicitly widens `showActions`. `31-UI-SPEC.md` itself flags this exact composition
question as an unresolved "backstop" (E2 `partial`, "the exact live-row visual is owned by Phase 27's
now-line work and this document cannot settle the composition from a desk"). **This research
confirms the gap is real and pre-existing, not introduced by this phase** — but SKIPBREAK-01's "at
every density" wording does not literally cover the live-row overlay's own separate widget, only the
`ChunkCardDensity` tiers (full/compact/subCompact) rendered by the non-live arm. See Open Questions
below for the recommended scope reading.

### Pitfall 5: no existing widget test in this codebase simulates a `Dismissible` drag

`grep -rn "tester.drag\|dragFrom\|fling(" test/` returns **zero results** — verified this session.
Every existing `SwipeableChunkCard`/`Dismissible` test in `test/screens/today_row_widgets_test.dart`
asserts widget-tree *structure* (`expect(find.byType(Dismissible), findsOneWidget)`), not simulated
drag behavior. This phase's hit-test-envelope claim (SKIPBREAK-02, Verification item 2 in
`31-UI-SPEC.md`) requires a genuinely new kind of test in this codebase — see "Code Examples" below
for the pattern, and budget planning time accordingly (there is no existing test to copy structurally
for the drag itself, only for the fixture/fake-notifier scaffolding around it).

### Pitfall 6: `flutter test` cannot model finger size — carried forward, not new

Per `CLAUDE.md`/`31-CONTEXT.md`/`31-UI-SPEC.md`, all consistent and independently confirmed by this
research: `WidgetTester.drag`/`dragFrom` fire synthetic drags at exact coordinates. They can prove the
*geometric* claim (a drag starting N px outside the painted card still resolves to the right
`Dismissible`), but cannot prove a real thumb's touch centroid reliably lands inside an *invisible*
band it cannot see the edges of. This phase MUST end in a `checkpoint:human-verify gate="blocking"`
task, per this project's own precedent (`27-04-PLAN.md` Task 3, `29-01-PLAN.md` D-07,
`30-05-PLAN.md`) — the task syntax is `<task type="checkpoint:human-verify" gate="blocking">`.

## Code Examples

### The corrected widget arrangement (Pattern 3 + Pitfall 1 fix combined)

```dart
// today_screen.dart — sketch of the corrected _buildPositionedRow arrangement.
// Illustrative; exact signature/threading is a planning decision (see Open Questions —
// _buildPositionedRow currently receives only `row`, not sibling context, so either the
// call sites or the signature need to gain access to `precedingRowSlot`/`followingRowSlot`
// and — Pitfall 1's fix — a way to defer slop-bearing breaks to a later Stack pass).

// Layer 1a: every NON-live, NON-slop-bearing row — unchanged loop, unchanged order.
for (final row in timelineRows)
  if (!(row is ChunkRow && row.isLive) &&
      !(row is ChunkRow && row.chunk.displayStartMinutes == null) &&
      !(row is ChunkRow && _needsSlop(row.chunk, geometry)))   // NEW predicate
    _buildPositionedRow(context, row, geometry, nowState, liveSecondsLeft),

// Layer 1b (NEW — Pitfall 1's fix): every NON-live, slop-bearing break — added AFTER
// layer 1a so its Positioned is always `lastChild`-ward of BOTH chronological neighbors,
// winning Stack hit-test priority in both the top and bottom slop bands.
for (final row in timelineRows)
  if (row is ChunkRow && !row.isLive &&
      row.chunk.displayStartMinutes != null &&
      _needsSlop(row.chunk, geometry))
    _buildPositionedRow(context, row, geometry, nowState, liveSecondsLeft),

// ... now-line overlay, then live row, unchanged (PD-10).
```

### Drag-simulation widget test pattern (Pitfall 5 — genuinely new territory)

```dart
// Sketch — no existing test in this codebase to copy verbatim; adapt the existing
// _FakeScheduleNotifier pattern from today_row_widgets_test.dart:31-46.
testWidgets(
  'a drag starting kBreakHitSlop above a sub-48dp break\'s painted top edge '
  'still resolves to that break\'s Dismissible',
  (tester) async {
    final fake = _FakeScheduleNotifier();
    // ... pump a day fixture with a 5-minute break at a known geometry.yFor() offset ...
    final breakTopPx = /* geometry.yFor(breakStart) */;
    final startPoint = tester.getTopLeft(find.byKey(ValueKey('b1')))
        .translate(40, -kBreakHitSlop + 2); // 2px inside the grown envelope, above painted top
    await tester.dragFrom(startPoint, const Offset(-400, 0)); // leftward, past dismissThreshold
    await tester.pumpAndSettle();
    expect(fake.lastSkippedId, 'b1');
  },
);

testWidgets(
  'a drag starting well inside the neighboring work chunk\'s own painted '
  'content still resolves to that work chunk, not the break',
  (tester) async {
    // Negative case — proves no theft of a touch that legitimately belongs
    // to the neighbor's own card content, not just its slop-adjacent edge.
  },
);
```

### D-31-05 regression test pattern (proven-RED-first, per this project's invariant)

```dart
// Extends test/providers/schedule_notifier_break_extension_test.dart's existing
// 'G-05 no-op guards' group (schedule_notifier_break_extension_test.dart:204+),
// using the same makeNotifier(repo:, now:, chunks:) fixture pattern already
// established there (verified, lines 205-236 read this session).
test('an already-skipped following break is never moved or extended by G-05', () async {
  final repo = _InMemoryScheduleRepository();
  final w1 = ScheduledChunk(
    id: 'w1', chunkTypeIndex: ChunkType.work.index, goalId: 'goal-1',
    durationMinutes: 25, syntheticStartMinutes: 600,
  );
  final b1 = ScheduledChunk(
    id: 'b1', chunkTypeIndex: ChunkType.shortBreak.index,
    durationMinutes: 5, syntheticStartMinutes: 625,
  )..isSkipped = true;   // pre-skipped, per D-31-03
  final notifier = makeNotifier(
    repo: repo,
    now: () => DateTime(2026, 6, 13, 10, 10),  // early — inside w1's window
    chunks: [w1, b1],
  );
  await notifier.init();
  await notifier.markComplete('w1');   // completing w1 early would normally absorb b1

  expect(b1.displayStartMinutes, 625, reason: 'D-31-05: a skipped break must not move');
  expect(b1.durationMinutes, 5, reason: 'D-31-05: a skipped break must not extend');
  expect(b1.isSkipped, true, reason: 'skipped state itself must be untouched');
});
```

Run this test against the **unfixed** guard list first to confirm it goes RED (fails: `b1` moves to
`syntheticStartMinutes: 610`, `durationMinutes: 20`), then add the one-line guard and confirm GREEN —
this project's carry-forward invariant ("Regression tests must be proven RED," `STATE.md`).

## State of the Art

Not applicable in the "old approach → new approach" sense — this phase extends an existing,
already-current pattern (`Dismissible` + `ScheduleNotifier.markSkipped`) rather than replacing
anything. The one genuinely new technique for this codebase is the grown-hit-test-envelope pattern
(Pattern 3) and its Stack-ordering correction (Pitfall 1) — both are new *applications* of existing
Flutter mechanisms, not new library adoption.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The recommended fix for Pitfall 1 (a third Stack pass for slop-bearing breaks) is sufficient and introduces no new z-order conflicts among *multiple* adjacent slop-bearing breaks (e.g. two 5-minute breaks separated only by a very short work chunk) | Common Pitfalls, Pitfall 1 | Under today's lattice this cannot occur — every break is sandwiched between work chunks of ≥25 minutes (per `STATE.md`'s Phase 28 lattice notes) — but if a future lattice change ever placed two short breaks back-to-back, the "later added wins both slop bands" rule would need re-verification. Flagged, not blocking, given today's evidence. |
| A2 | `_buildPositionedRow`'s current signature (only `row`, `geometry`, `nowState`, `secondsRemaining` — no sibling access) will need to gain either an ordered-list index or precomputed `precedingRowSlot`/`followingRowSlot` values to implement the defensive slop-halving clamp `31-UI-SPEC.md` specifies (`clamp(kBreakHitSlop, 0, precedingRowSlot / 2)`) | Code Examples, "corrected widget arrangement" | If the planner instead hard-codes `kBreakHitSlop` without the clamp (reasonable, since today's lattice never produces a neighbor under 32dp — confirmed dead per UI-SPEC's own "not producible by today's lattice" note), the simplification is defensible but should be a stated, deliberate choice, not a silent omission |

## Open Questions

1. **Does SKIPBREAK-01's "at every density" reach the live-row overlay, or only the non-live
   `ChunkCardDensity` tiers?**
   - What we know: a live break today renders through `LiveRowCard` with `showActions:
     chunk.chunkType == ChunkType.work` (verified, `today_screen.dart:979`) — meaning a live break
     has **zero** skip affordance, before and (if left alone) after this phase.
   - What's unclear: whether the owner's "make it skippable like the other ones" instruction
     (2026-08-21) was scoped to the non-live swipeable card only, or whether a live break should also
     gain a Complete/Skip-style icon (widening `showActions`).
   - Recommendation: `31-UI-SPEC.md` already defers this exact question as a "backstop" (E2
     `partial`) rather than deciding it — this research agrees that is the right call. Recommend the
     plan explicitly scope this phase to the non-live swipe gesture only (leave
     `showActions: chunk.chunkType == ChunkType.work` unchanged), and record the live-break gap as a
     documented, deliberate exclusion — not a silent one — so it surfaces in the mandatory human UAT
     rather than being assumed away.

2. **Exact mechanism for threading `precedingRowSlot`/`followingRowSlot` into `_buildPositionedRow`.**
   - What we know: `timelineRows` is available at the call site (`today_screen.dart:1387`,
     `:1480`) as a `List<TimelineRow>`, in guaranteed chronological order.
   - What's unclear: whether the planner should pass the full list + index into
     `_buildPositionedRow`, precompute a `Map<String, ({double? preceding, double? following})>`
     before the loop, or (per Assumption A2) skip the clamp entirely as dead code under today's
     lattice.
   - Recommendation: given the lattice-invariant noted in A2 (no neighbor is ever under 32dp today),
     a simple implementation that omits the defensive per-neighbor clamp and always applies the full
     `kBreakHitSlop` is defensible and lower-risk than threading extra list context through a
     load-bearing, heavily-commented dispatch function. If the planner instead wants the clamp for
     future-proofing, budget it as a small, separate task with its own test.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | building/testing the app | ✓ | Dart SDK `^3.10.3` per `pubspec.yaml`; Flutter toolchain at `/home/dan/development/flutter/bin` (not on default PATH — `~/.claude/CLAUDE.md` memory note) | — |
| `tools/serve-uat.py` | serving the debug build for human UAT | ✓ | present at project root, verified this session (`Cache-Control: no-store`, strips conditional-request headers) | — |
| A real touch device (phone/tablet) | the mandatory `checkpoint:human-verify` gate | not verifiable from this session | — | none — this is the one dependency with no automated fallback; it is the explicit reason the phase cannot close on `flutter test` alone (Pitfall 6) |
| Port 8143 | reusing the Phase 29/30 UAT harness | previously used for Phase 29/30's served builds (`STATE.md`: "judged in a single sitting against the same served build on port 8143") | — | — |

**Missing dependencies with no fallback:** none blocking — the real-device UAT step is a *required
human action*, not a missing tool; it is the reason this phase's plan must end in a blocking
checkpoint rather than something research can route around.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK, no separate install) |
| Config file | none — standard `flutter test` discovery over `test/**/*_test.dart` |
| Quick run command | `flutter test test/screens/today_row_widgets_test.dart test/providers/schedule_notifier_break_extension_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SKIPBREAK-01 | Break's `Dismissible` fires `markSkipped` on a completed leftward drag, at every density | widget | `flutter test test/screens/today_row_widgets_test.dart` (extend existing `ChunkCard row vocabulary` / `SwipeableChunkCard` groups) | ✅ file exists, new test cases needed |
| SKIPBREAK-01 | A drag starting inside a sub-48dp break's grown-envelope slop band still resolves to that break, not a neighbor | widget (NEW pattern, see Pitfall 5/Code Examples) | `flutter test test/screens/today_screen_test.dart` (new group, reusing `buildDayFixture`/`pumpDay` local helpers) | ❌ Wave 0 — no drag-simulation test exists anywhere in this codebase today |
| SKIPBREAK-01 | A negative-case drag starting inside the *neighbor's* own painted content still resolves to the neighbor (no theft) | widget | same file/group as above | ❌ Wave 0 |
| SKIPBREAK-02 | Painted extent of every break (every density, every resolved state) stays exactly `durationMinutes × kPixelsPerMinute` | widget (arithmetic-only, extends existing SEEBREAK-02 pattern) | `flutter test test/screens/today_screen_test.dart` | ✅ SEEBREAK-02's existing test is the template; extend for the skipped state |
| D-31-04 | Skipped-break visual treatment (opacity, strikethrough, trailing text/semantics) at each of full/compact/subCompact | widget | `flutter test test/screens/today_row_widgets_test.dart` (extend `break densities` group, `today_row_widgets_test.dart:629+`) | ✅ group exists, needs skipped-state cases added |
| D-31-05 | `_absorbReclaimedTimeIntoNextBreak` never moves/extends an already-skipped break | unit | `flutter test test/providers/schedule_notifier_break_extension_test.dart` (extend `G-05 no-op guards` group) | ✅ group exists, needs one new case, proven RED first |
| Streak inertness (Pattern 4, defensive re-confirmation) | Skipping a break never touches `Goal.streakCount` | unit | `flutter test test/providers/` (existing streak tests, or a small new assertion) | ✅ mechanism already covered by the existing `goalId` guard; a defensive assertion is cheap insurance, not required scope |

### Sampling Rate

- **Per task commit:** `flutter test test/screens/today_row_widgets_test.dart test/providers/schedule_notifier_break_extension_test.dart test/screens/today_screen_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green, `flutter analyze` clean, THEN the mandatory `checkpoint:human-verify` gate on a real device (this phase cannot close on automated verification alone — Pitfall 6).

### Wave 0 Gaps

- [ ] A new widget-test group in `test/screens/today_screen_test.dart` (or a new file) covering the
      grown hit-test envelope — no existing `tester.drag`/`dragFrom` pattern to copy in this
      codebase; the sketch in "Code Examples" above is the starting point, not a finished pattern.
- [ ] D-31-05's regression test, proven RED against the unfixed guard list first (extends
      `test/providers/schedule_notifier_break_extension_test.dart`'s existing `G-05 no-op guards`
      group — fixture pattern already established, no new helper needed).
- [ ] The `checkpoint:human-verify gate="blocking"` task itself, reusing port 8143 and
      `tools/serve-uat.py` per Phase 29/30 precedent — **must include the mandatory ⟳ Re-check-in
      first step** (CLAUDE.md trap #4) if any part of the UAT judges a freshly-generated day's break
      placement/timing (D-31-03's "nothing else moves" claim).

*(No framework install gap — `flutter_test` is already the project's test framework, already wired.)*

## Security Domain

`security_enforcement` is not set in `.planning/config.json` (absent = enabled per the verification
protocol), but this phase has essentially no attack surface: it is a local, single-user, offline-first
Flutter app with no new network calls, no new authentication surface, and no new user input beyond a
swipe gesture already exercised by work chunks. The applicable ASVS categories below are included for
completeness; none require a new control.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | app has no auth surface |
| V3 Session Management | no | app has no session/auth surface |
| V4 Access Control | no | single-user local app, no access-control boundary |
| V5 Input Validation | marginal | `markSkipped`'s `chunkId` is always sourced from `chunk.id` (a UUID generated by this app's own `ScheduledChunk` constructor, `scheduled_chunk.dart:6,22`), never from external/untrusted input — no new validation surface introduced |
| V6 Cryptography | no | no cryptographic operation involved |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| A malformed/duplicate `chunkId` reaching `markSkipped` | Tampering (theoretical only — no external input path) | Already mitigated: `markSkipped` no-ops on an unknown id (`chunk == null` early return, `schedule_notifier.dart:683`) — unchanged by this phase |

## Sources

### Primary (HIGH confidence — read this session, cited with exact line numbers above)
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` (full file, 138 lines)
- `lib/data/models/scheduled_chunk.dart` (full file, 80 lines)
- `lib/screens/today/today_screen.dart` (lines 600-840, 900-990, 1340-1520)
- `lib/providers/schedule_notifier.dart` (lines 500-750)
- `lib/screens/schedule/widgets/chunk_card.dart` (lines 1-770)
- `lib/screens/today/timeline_geometry.dart` (constants + `yFor`/`heightFor`)
- `lib/screens/today/timeline.dart` (full file, `buildTimeline`)
- `lib/screens/today/widgets/live_row_card.dart` (lines 1-115)
- `lib/screens/today/widgets/free_time_row.dart` (grep-verified: zero `GestureDetector`/`Dismissible`/`onTap`)
- `test/screens/today_row_widgets_test.dart` (existing fake/fixture patterns, lines 1-60)
- `test/providers/schedule_notifier_break_extension_test.dart` (existing G-05 test patterns, lines 1-280)
- `test/screens/today_screen_test.dart` (`buildDayFixture`/`pumpDay` helper existence, grep-verified)
- `tools/serve-uat.py` (no-cache serving mechanism)
- Flutter SDK `/home/dan/development/flutter/packages/flutter/lib/src/rendering/box.dart` (`RenderBox.hitTest`, `defaultHitTestChildren`)
- Flutter SDK `/home/dan/development/flutter/packages/flutter/lib/src/rendering/proxy_box.dart` (`RenderClipRect.hitTest`, `RenderProxyBoxWithHitTestBehavior.hitTest`, `_RenderCustomClip`)
- Flutter SDK `/home/dan/development/flutter/packages/flutter/lib/src/rendering/stack.dart` (`RenderStack.hitTestChildren`)
- Flutter SDK `/home/dan/development/flutter/packages/flutter/lib/src/widgets/dismissible.dart` (full file, `build()`, `_overallDragAxisExtent`, `_confirmStartResizeAnimation`)
- `.planning/phases/31-breaks-you-can-skip/31-CONTEXT.md`, `31-UI-SPEC.md` (this phase's own locked decisions)
- `.planning/STATE.md` (project history, carry-forward invariants, prior UAT precedent)
- `.planning/phases/29-breaks-you-can-see/tools/measure_card_extent.py` (existing UAT tooling to reuse for painted-extent measurement, not hit-testing)
- `.planning/phases/27-true-grid/27-04-PLAN.md`, `.planning/phases/29-breaks-you-can-see/29-01-PLAN.md`, `.planning/phases/30-breaks-in-committed-time/30-05-PLAN.md` (`checkpoint:human-verify` task syntax precedent)

### Secondary / Tertiary
None used — every claim in this document was verified directly against source rather than sourced
from search or training-data recall, given the domain (this codebase's own internals + Flutter SDK
internals) is fully available for direct reading.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages, pure Flutter SDK usage already established in this codebase
- Architecture (hit-test mechanism): HIGH — verified by reading Flutter SDK source directly (box.dart, proxy_box.dart, stack.dart, dismissible.dart) rather than relying on training-data recall of Flutter internals, which is exactly the kind of claim most likely to be subtly wrong from memory alone
- Pitfalls: HIGH for Pitfalls 1-5 (all verified against source this session); HIGH for Pitfall 6 (carried forward from this project's own established, repeatedly-proven precedent)

**Research date:** 2026-08-25
**Valid until:** Flutter SDK internals (hit-test mechanism) are stable across minor versions — treat as valid for this phase's lifetime. Codebase-specific line numbers will drift the moment any of the cited files are edited; re-verify line numbers (not the underlying mechanism) if this document is consulted more than a few days after a related file changes.
