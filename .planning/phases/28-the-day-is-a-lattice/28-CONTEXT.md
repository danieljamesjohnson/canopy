# Phase 28: The Day Is a Lattice - Context

**Gathered:** 2026-08-19
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

**Goal:** The day is built on a 30-minute lattice — 25 minutes of work, 5 minutes of break — and
after every N of those, a full 30-minute break. Every chunk starts on :00 or :30, always.

Engine-side only. This is `lib/services/schedule_generator.dart`. Phase 27 made the timeline honest
about *rendering* time; this phase is about the times being rendered. It does not touch
`TimelineGeometry`, `LiveRowCard`, or any timeline widget.

**The owner's model, verbatim (2026-08-19):**

> The way it works is that the day is split up by 30 minutes. Where you do 25 minutes of work and 5
> minutes of break. After 3 chunks of 25/5, you take an entire 30 minute break.

One cycle is `N × 30 + 30` minutes. At N=3: `3 × (25+5) + 30` = 120 minutes, landing back on a clean
two-hour boundary. That lattice property is the point and the acceptance test.

**Out of scope:** making N adaptive (see Settled below); any UI work; any change to how chunks are
*displayed*.

</domain>

<decisions>
## Implementation Decisions

### Settled — do not re-litigate

**N stays set once, from the morning check-in mood.** The owner was asked directly (2026-08-19)
whether N should react to how the day actually goes, or carry over from yesterday. He chose neither.
The existing `_moodBreakCadence` table `{1:2, 2:3, 3:4, 4:4, 5:5}` stays as the source of N. This
phase does not make the engine adaptive; adaptivity is a different phase, not a smaller version of
this one.

His illustration used N=3, which is the mood-2 value. That was an example of the *shape*, not a
request to retune the table. **If planning believes the table should move, ask — do not infer it
from the example.**

### Resolved after research (2026-08-19)

`28-RESEARCH.md` confirmed all three named defects against the literal source, surfaced a fourth,
and closed the capacity question with a simulation of the real packing loop rather than an estimate.
These are the resulting calls. Every one must be visible in a plan.

- **D-01:** LATTICE-01 governs **generated (discretionary) chunks only.** A user's fixed commitment
  keeps its own wall-clock time and is never rounded onto :00/:30 — rounding it would move the
  user's actual appointment, which is the opposite of giving them control over their own time.
- **D-02:** The post-commitment free-slot start is rounded up to the next 30-minute boundary
  (`schedule_generator.dart` ~710-722, research gap #2). Today it starts at the commitment's raw end
  minute and that off-lattice offset cascades through the rest of the slot. **In scope** — it is the
  mechanism by which LATTICE-01 actually fails after a commitment, and it lives in the method
  already being changed.
- **D-03:** `startFloorMinutes` rounds up to the next 30-minute boundary, not to 5 minutes
  (~672-679, research gap #1). The existing test that pins the 5-minute value is rewritten, proven
  RED against the unfixed code first, per this project's carried-forward convention.
- **D-04:** **Neither `_moodCap` nor the day's end moves.** This is the deliberate answer to the
  capacity question, on simulated evidence: the lattice costs only 10-20 extra minutes across a
  whole day, and every mood's cap fits the nominal 8am-10pm (840-minute) window with 455-695 minutes
  of slack. The squeeze only bites on commitment-heavy or late-start days, where dropping trailing
  chunks is a pre-existing behavior, marginally worsened — not a new failure introduced here.
- **D-05:** STEP E's trailing-chunk trim (~652-655) is narrowed to trim only a trailing **short**
  break. Left as-is it strips *any* trailing break, so it would silently re-suppress the trailing
  long break by a second path and re-create defect 3 even after the packing loop is fixed.
- **D-06:** The new "two consecutive break chunks at a cadence boundary" cardinality (a 5-minute
  break immediately followed by a 30-minute break) gets a real automated test, not a one-off manual
  smoke check. Nothing downstream has ever seen that shape.

### Claude's Discretion

All remaining implementation choices are at Claude's discretion. Use the ROADMAP phase description,
the named defects below, `28-RESEARCH.md`, and existing codebase conventions to guide them.

</decisions>

<code_context>
## Existing Code Insights

`lib/services/schedule_generator.dart` — the three ways today's engine misses the model:

1. **The long break is 25 minutes, not 30.** `_assignSyntheticStartTimes` sets
   `breakDur = isLong ? 25 : 5`.

2. **The long break REPLACES the short break instead of following it.** Each work chunk carries one
   `reservedBreakMinutes` — either 5 or 25, never both. So a cycle at N=4 is `4×25 + 3×5 + 25` =
   140 minutes, which is off-lattice and drifts the whole rest of the day off :00/:30. Under the
   owner's model the Nth chunk still closes its own 30-minute cell with a 5-minute break, and the
   30-minute break is a cell of its own.

3. **The long break is silently suppressed when it would land last.** The reservation is only
   recorded when `discIdx + 1 < discretionaryChunks.length`. At mood 3 (N=4) with a 4-chunk day —
   the exact day the owner was looking at — the long break falls after chunk 4, is dropped, and no
   long break is ever emitted. This is very likely the whole of "isn't functioning right": the
   cadence code is there and roughly correct, and the user has simply never seen it fire.
   Suppressing a *trailing* break is defensible; suppressing the one long break in the day is not.

Further codebase context will be gathered during plan-phase research.

</code_context>

<specifics>
## Specific Ideas

**Requirements:**
- **LATTICE-01** — every chunk starts on a 30-minute boundary
- **LATTICE-02** — a 30-minute break after every N work chunks, N from morning mood, never silently
  suppressed

**Verification — genuinely different from Phase 27.** This phase *is* fully testable in
`flutter test`: it is integer arithmetic over minutes with no glyph metrics anywhere near it. The
assertion that matters: generate a day at each mood, and check every chunk's start minute is
`≡ 0 (mod 30)` and that exactly `floor(chunks / N)` long breaks of exactly 30 minutes are emitted.

**No real-browser step is required.** Do not copy Phase 27's pixel-measurement ceremony over — it
was necessary there because the grid was verified against itself, and it is not necessary here.

</specifics>

<deferred>
## Deferred Ideas

- **Adaptive N** (reacting to how the day actually goes, or carrying over from yesterday) —
  explicitly declined by the owner 2026-08-19.
- **Retuning `_moodBreakCadence`** — not requested; ask before changing.

</deferred>
