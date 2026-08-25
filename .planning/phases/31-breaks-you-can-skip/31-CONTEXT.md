# Phase 31: Breaks You Can Skip - Context

**Gathered:** 2026-08-25
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

**Goal:** A break can be skipped the same way a work chunk can — at every density, including the
5-minute one — without the timeline lying about how long anything takes.

Raised by the owner during Phase 29 UAT (2026-08-21): *"Breaks are fully functional features, with
timers, etc."* followed by the explicit scope call *"don't add tappable then. Just make it
skippable like the other ones."*

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

**Boundary vs Phase 29 (deliberate):** Phase 29's SEEBREAK-01/02 are about *visibility*;
skippability makes nothing more or less visible. This applies to every break tier, not just the
sub-compact one Phase 29 touched — scoping it inside 29 would have shipped a skippable 5-minute
break next to a non-skippable 30-minute one. Phase 29's approved UI-SPEC locks "non-interactive at
every density"; **this phase supersedes that clause explicitly**, and the supersession must be
recorded rather than left silent.

**Requirements:**
- **SKIPBREAK-01** — a break can be skipped at every density, by the same gesture that skips a work
  chunk.
- **SKIPBREAK-02** — the true grid is preserved: no break grows to accommodate its own gesture
  target. Rendered height never deviates from `durationMinutes × kPixelsPerMinute` (SEEBREAK-02
  still holds).

</domain>

<decisions>
## Implementation Decisions

Discuss was skipped per `workflow.skip_discuss=true`. Implementation choices are at Claude's
discretion **except** where the ROADMAP entry already constrains them (above). The following are
open questions planning must decide deliberately and record:

### D-31-01 — Swipe direction(s) for a break
The complete (right-swipe) direction is a separate question from skip. "Complete a break" may not
be a meaningful action, in which case breaks get a **one-directional** `Dismissible` (skip only)
while work chunks keep both directions. Decide and record the reasoning either way.

### D-31-02 — The 20dp grab target
A 5-minute break's row is 20dp (`5 × kPixelsPerMinute`) — well under a usable drag target — and
Phase 29's sub-compact tier renders it as a bare hairline with no card behind it. This is the same
duration-exact-slot tension Phase 27 created and Phase 29 met on the *legibility* axis; meet it
here on the *gesture* axis. The grid is not negotiable, so the answer cannot be "make the row
taller."

### D-31-03 — What skipping a break means
The honest default is counter-intuitive: the timeline is duration-exact and time-anchored, so
skipping a 5-minute break does **not** hand those 5 minutes back — the next work chunk still starts
when it always did. The cheap, consistent reading is **"mark it skipped and move on."** Adopt that
unless there is a strong reason not to; anything else is an engine change and requires asking the
owner first.

### D-31-04 — Skipped-break rendering at sub-compact
`_SubCompactRow` has no completed/skipped visual state. Check before assuming, then design one that
fits a 20dp hairline.

</decisions>

<code_context>
## Existing Code Insights

**The mechanism is already ~95% built.**

- `SwipeableChunkCard` (`lib/screens/schedule/widgets/swipeable_chunk_card.dart`) already wraps
  *every* chunk row — `today_screen.dart`'s `_buildChunkCard` has **no per-type branch**. Breaks are
  excluded by one explicit early return at `swipeable_chunk_card.dart:74-75`:

  ```
  // Break cards are not swipeable and do not receive goal name or tap.
  if (chunk.chunkType != ChunkType.work) { ... return plain ChunkCard ... }
  ```

- `ScheduleNotifier.markSkipped` (`schedule_notifier.dart:637`) is already **type-agnostic**: it
  sets `isSkipped`, saves, and appends a `CompletionLog`.

- Its streak write-back is already guarded by `chunk.goalId != null && isNotEmpty`, and a break's
  `goalId` is null — so the habit-streak path *should* already be inert for breaks. **Verify that
  guard rather than assuming it.** A break that resets a habit streak would be a serious regression.

- `_absorbReclaimedTimeIntoNextBreak` (Phase 23, G-05) already **moves** a break when work finishes
  early. Read it before designing D-31-03, so the two behaviours do not contradict each other.

- Phase 29 owns the sub-compact tier and `kSubCompactBreakMinHeight = 32.0`. Its UAT verdict is
  recorded (PASS, 2026-08-25), so the sub-compact layout is settled and this phase attaches to it
  as-is.

Further codebase context will be gathered during plan-phase research.

</code_context>

<specifics>
## Specific Ideas

**Verification must include a real-browser step.** A drag gesture on a 20dp row is exactly the class
of thing `flutter test` reports as working while a thumb cannot actually do it — `flutter test`
fires synthetic drags at exact coordinates and does not model finger size.

Reuse Phase 29's harness (`.planning/phases/29-breaks-you-can-see/tools/`); port **8143** is already
claimed and safe to reuse for this project's debug builds.

**This phase MUST end in a human UAT checkpoint.** Precedent: Phase 27 scored 16/17 automated and
then failed 2 of 3 human items; Phase 29's automated suite went 587-green and three pixel
measurements deep while the owner was looking at a screen that showed no breaks at all. *"Can a
thumb skip this break"* is a physical question no assertion settles.

**The UAT must begin with a mandatory ⟳ Re-check-in step** if it judges any scheduling-engine
output (CLAUDE.md trap #4).

</specifics>

<deferred>
## Deferred Ideas

- Tappable break cards / break detail sheet — ruled out by the owner, 2026-08-21.
- Pulling the day forward on a skipped break (reclaiming the 5 minutes) — out of scope; requires an
  explicit owner decision before it could be planned.

</deferred>
