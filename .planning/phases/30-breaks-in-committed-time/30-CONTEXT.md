# Phase 30: Breaks In Committed Time - Context

**Gathered:** 2026-08-24
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

A break lands between work chunks inside a committed block, the same as it does anywhere else in
the day — without the commitment's own start or end time moving by a minute.

**In scope:** `lib/services/schedule_generator.dart` only. Step 1's commitment-window walk (the
bare `cursor += 25`) and STEP C's pass-through of `commitmentChunks`. Plus the test file that
should have caught this.

**Out of scope:** anything in `lib/screens/`. Phase 29's sub-compact tier already renders a
5-minute break correctly — that is what makes the break this phase emits *visible*. Do not touch
`chunk_card.dart`, `timeline_geometry.dart`, or `today_screen.dart`.

**Hard boundary — Phase 28's D-01 stays intact.** Never round `block.startMinutes` or
`block.endMinutes`. A user's fixed commitment keeps its own wall-clock time. The lattice inside the
window is seeded from the block's own unrounded start (a 09:10 block gets cells at
09:10/09:40/10:10), never from the global :00/:30 grid.

</domain>

<decisions>
## Implementation Decisions

The ROADMAP entry for this phase is unusually specific and is the spec. It names the root cause
with file and line-level precision, names four things the phase must build, and names the D-01
constraint that must survive. Planning should treat it as binding rather than re-deriving it.

### Claude's Discretion — with one decision that must be argued, not defaulted

Discuss was skipped per `workflow.skip_discuss=true`, so implementation choices are at Claude's
discretion. **One exception, called out by the ROADMAP itself (item 2):**

> Does a commitment block's work count toward the same `longBreakEvery` counter the discretionary
> loop maintains, or does it run its own?

Today `breakCount` lives entirely inside `_assignSyntheticStartTimes` and never sees a commitment
chunk. Both answers are defensible and both have a visible failure mode: a 6-hour meeting block
silently accruing four long breaks is as wrong as it accruing none. **Whichever way this goes, the
reasoning goes in the plan and in the SUMMARY's `key-decisions`** — not a comment, not an
assumption. Prefer deciding it on a simulation of the real packing loop, the way Phase 28 settled
D-04, rather than on an estimate.

### Carried-forward constraints that bound the solution space

- Rule-based only — no LLM, no adaptivity. N is set once from the morning check-in mood; Dan
  declined adaptivity explicitly on 2026-08-19 (STATE.md). Do not re-open it here.
- The cadence table is locked: `{1:2, 2:3, 3:4, 4:4, 5:5}` keyed on `moodIndex` (Phase 21 / BREAK-01).
- Hive migrations are additive-only. This phase should need none — it is pure generator arithmetic.

</decisions>

<code_context>
## Existing Code Insights

Root cause, already located and reproduced (ROADMAP, 2026-08-24):

- **Step 1** walks a commitment window with a bare `cursor += 25` — no break reserved, no lattice
  alignment.
- **STEP C** then passes those chunks straight through:
  `final List<ScheduledChunk> result = [...commitmentChunks];`, under a comment that states the
  behaviour outright ("commitment chunks (no breaks between them)").
- **Phase 28's lattice was only ever applied to the discretionary packing loop.**

The reproduction (commitment block `Work` 09:00–11:40 + one discretionary goal) is in the ROADMAP
entry verbatim and matches the owner's screenshot exactly. Re-derive it as the first act of
planning rather than trusting this file.

**The tail interacts with break insertion.** Step 1 stretches the final chunk to `block.endMinutes`
so a sub-25 remainder is covered. A window whose remainder is under 30 minutes has no room for a
full cell. Two failure modes to design against explicitly: the last break pushing past
`endMinutes`, and the stretch swallowing a break that should have been emitted.

Further code context will be gathered during plan-phase research.

</code_context>

<specifics>
## Specific Ideas

Requirements (from ROADMAP):

- **COMMITBREAK-01** — a break is emitted between consecutive work chunks inside a commitment
  block, on the 25+5 lattice.
- **COMMITBREAK-02** — the commitment's own start and end times are unchanged (D-01 preserved).

**The test gap is the actual defect behind the defect.** The existing suite's `makeBlock` fixture
(540–600, two chunks) would have caught this on day one, and no test asserted break placement for
it. A regression test built from a **commitment block, not a goal**, is a first-class deliverable
here, not a formality.

**Verification shape.** This is arithmetic, not glyph metrics, so geometric assertions in
`flutter test` are trustworthy (STATE.md carry-forward invariant) — a real-browser step is *not*
required to prove break placement. It IS required before closing, for one reason: the owner has now
reported this symptom twice, and a generated-day screenshot is what closes it credibly. Reuse port
8143 (debug builds only, per CLAUDE.md).

**Trap #4, data layer — must appear in the UAT's own instructions.** `ScheduleNotifier._loadToday()`
reads today's schedule from Hive and `generate()` runs only at check-in, so an already-generated day
is never regenerated on load. Any engine change is invisible in the running app until ⟳ Re-check-in.
A UAT that tests generator output and omits this will produce a false failure — it already did once,
on 2026-08-21.

**The methodological lesson, which the phase's own verification must honour.** This defect was
missed twice because both prior probes covered only the discretionary half of the code path. Phase
28 verified the lattice against discretionary days only; Phase 29's diagnosis swept all five moods
and both goal types but never built a commitment block, saw breaks everywhere, and wrongly concluded
the engine was clean. **A probe that only covers the half of a code path you already suspect is not
evidence.** Verification for this phase must exercise a day built from a commitment block as its
*primary* fixture, not as an afterthought.

</specifics>

<deferred>
## Deferred Ideas

- **Phase 31 — Breaks You Can Skip** already owns break interactivity (swipe-to-skip is blocked by
  an explicit early return at `swipeable_chunk_card.dart:75`). Do not widen this phase into it.
- **Phase 29's human UAT** is blocked on this phase landing and is judged after it, not here.
- Promoting trap #4 into `CLAUDE.md` is worth doing but is documentation, not this phase's engine
  change — fold it in only if a plan is already touching CLAUDE.md.

</deferred>
