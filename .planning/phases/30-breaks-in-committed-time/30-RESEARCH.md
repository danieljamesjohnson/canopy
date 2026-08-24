# Phase 30: Breaks In Committed Time - Research

**Researched:** 2026-08-24
**Domain:** Pure-Dart deterministic scheduling arithmetic (`lib/services/schedule_generator.dart`) — no external packages, no UI
**Confidence:** HIGH — every claim below (root cause, tail arithmetic, cadence recommendation, test-impact list) is verified by running the real `generate()` and the real `flutter test` suite this session, not estimated.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

**Carried-forward constraints that bound the solution space:**

- Rule-based only — no LLM, no adaptivity. N is set once from the morning check-in mood; Dan
  declined adaptivity explicitly on 2026-08-19 (STATE.md). Do not re-open it here.
- The cadence table is locked: `{1:2, 2:3, 3:4, 4:4, 5:5}` keyed on `moodIndex` (Phase 21 / BREAK-01).
- Hive migrations are additive-only. This phase should need none — it is pure generator arithmetic.

### Deferred Ideas (OUT OF SCOPE)

- **Phase 31 — Breaks You Can Skip** already owns break interactivity (swipe-to-skip is blocked by
  an explicit early return at `swipeable_chunk_card.dart:75`). Do not widen this phase into it.
- **Phase 29's human UAT** is blocked on this phase landing and is judged after it, not here.
- Promoting trap #4 into `CLAUDE.md` is worth doing but is documentation, not this phase's engine
  change — fold it in only if a plan is already touching CLAUDE.md.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMMITBREAK-01 | A break is emitted between consecutive work chunks inside a commitment block, on the 25+5 lattice | Prototyped and verified (see Code Examples) — Step 1's `while` loop now reserves a footprint after each work chunk exactly like `_assignSyntheticStartTimes` already does for discretionary chunks |
| COMMITBREAK-02 | The commitment's own start/end times are unchanged (D-01 preserved) | Verified: `block.startMinutes`/`block.endMinutes` are never written to in the prototype; only the chunk *composition* inside the window changes. Confirmed by running the exact ROADMAP repro fixture and 6 additional boundary fixtures — window bounds identical before/after in every case |
</phase_requirements>

## Summary

The defect is exactly as the ROADMAP describes it, and I reproduced it verbatim by calling the real
`generate()` — see Code Examples. The fix is a **direct structural mirror** of the pattern
`_assignSyntheticStartTimes` already uses for discretionary chunks: walk the commitment window,
after each 25-minute work chunk try to reserve a break footprint (5 for an ordinary cell, 35 for a
cadence-boundary cell), fall back to short-only if the full footprint doesn't fit, and do nothing if
even that doesn't fit. The window itself never gets touched — `block.startMinutes`/`endMinutes` are
read-only throughout.

I built this as a working prototype in `lib/services/schedule_generator.dart`, ran it against the
exact repro fixture and against the entire 587-test suite (`--concurrency=1`), and reverted it before
writing this document (the working tree is clean; nothing was left uncommitted). That is the source
for every "verified" claim below, not estimation.

**Primary recommendation:** Mirror `_assignSyntheticStartTimes`'s footprint-reservation pattern
inside Step 1's `while` loop, give the commitment block its **own, independent cadence counter**
(reasoning and simulation in the Cadence Decision section below), and — this is the one bug my
prototype surfaced that the ROADMAP did not name — **narrow STEP E's trailing-short-break trim to
discretionary-origin chunks only** (`commitmentId == null`), or a stretched trailing commitment break
can be silently deleted, erasing real covered time from inside the user's own committed window.
Exactly **4** existing tests need to change, not the whole file; a 5th test I expected to change
(WR-03) turned out to be cadence-insensitive once the STEP E fix is in place — verified by patching
and running, not assumed.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Break placement inside a commitment window | Backend (pure Dart service, `lib/services/schedule_generator.dart`) | — | Deterministic scheduling arithmetic; no Flutter imports, no async, no UI. Rule-based per CLAUDE.md product position (no LLM, no smart suggestions) |
| Break *rendering* (making an inserted break visible as a card) | Frontend Server / Client (`lib/screens/`) | — | Already built by Phase 29 (sub-compact tier) — out of scope for this phase, and correctly so: it already renders whatever the generator emits |
| Commitment window's own start/end (D-01) | Database / Storage (`CommitmentBlock` Hive record) | Backend | The user-entered fact; the generator only ever *reads* `startMinutes`/`endMinutes`, never writes them — this phase must preserve that read-only relationship |
| Mid-day "add event to today" chunk anchoring | Backend (`lib/providers/schedule_notifier.dart:addEventToday`) | — | **Not in this phase's declared scope, but see Pitfall 5 below** — it duplicates the exact same unbroken-`cursor += 25` defect in a second file |

## Standard Stack

Not applicable — this phase adds no new package. It is arithmetic inside an existing pure-Dart
service (`ScheduleGeneratorService`, no Flutter imports, no async, no side effects per its own class
doc comment). No `pubspec.yaml` change is expected.

## Package Legitimacy Audit

**Not applicable — no external packages are installed by this phase.** The fix is confined to
`lib/services/schedule_generator.dart` (and possibly `lib/providers/schedule_notifier.dart`, see
Pitfall 5) using only existing project types (`ScheduledChunk`, `CommitmentBlock`, `ChunkType`).

## Architecture Patterns

### System Architecture Diagram

```
CommitmentBlock (Hive record: startMinutes, endMinutes — user's real appointment)
        │  read-only (D-01/COMMITBREAK-02: never written by the generator)
        ▼
generate()
  Step 1: commitment-window walk  ─┐
    while cursor+25 <= endMinutes │  <- THE FIX LIVES HERE
      emit 25-min WORK chunk       │     mirrors _assignSyntheticStartTimes's
      reserve break footprint      │     footprint-reservation pattern
        (own cadence counter,      │     (5, or 35 at a boundary; short-only
         see Cadence Decision)     │     fallback; genuine omission if neither fits)
      emit SB / SB+LB as needed   ─┘
    stretch the LAST unit (work OR break) to cover any sub-lattice remainder
        │  all chunks — work AND break — carry anchoredStartMinutes + commitmentId
        ▼
  Steps 2-4: discretionary demand collection (habits/outcomes/time-targets) — UNCHANGED
        │
        ▼
  STEP A: split workChunks into commitmentChunks (anchoredStartMinutes != null)
          vs discretionaryChunks (anchoredStartMinutes == null)
          — commitmentChunks now includes the new break chunks too; this is
          load-bearing (see Pitfall 2: free-slot window merge)
        ▼
  STEP B: _assignSyntheticStartTimes — UNCHANGED. Builds `windows` from
          commitmentChunks' [anchoredStartMinutes, +durationMinutes) spans and
          merges touching/overlapping ones. Because the new break chunks are
          anchored and contiguous with their neighboring work chunks, the
          merged window now correctly covers the WHOLE occupied span,
          including internal breaks — no discretionary chunk can be packed
          into a commitment's internal break gap (verified empirically)
        ▼
  STEP C: result = [...commitmentChunks] then interleave discretionary breaks
          — UNCHANGED for discretionary; commitment breaks already fully
          formed by Step 1, just pass through
        ▼
  STEP D: sort by effective start time — UNCHANGED
        ▼
  STEP E: trim ONE trailing short break — MUST NARROW to commitmentId == null
          (Pitfall 1) or a stretched commitment-tail break can vanish
        ▼
  Rendered by Phase 29's sub-compact tier (lib/screens/) — UNTOUCHED, out of scope
```

### Recommended approach — mirror, don't reinvent

Do not write a second, independent break-insertion algorithm for commitment blocks. The
discretionary loop (`_assignSyntheticStartTimes`, lines 811-852) already solves this exact problem —
footprint reservation, boundary detection, short-only fallback, genuine omission when nothing fits —
and Phase 28 already fought through its edge cases (D-05's narrow-slot fallback, WR-01's footprint
decode). Step 1's `while` loop should apply the identical shape, using the same
`_shortBreakMinutes`/`_longBreakMinutes` constants and the same "footprint, not duration" pattern
documented at line 819-825's comment. The only structural difference: Step 1's cursor advances
against `block.endMinutes` (a fixed window) rather than a computed free slot, and the loop owns its
own tail-stretch.

### Pattern: footprint reservation (existing, to be mirrored)

```dart
// Source: lib/services/schedule_generator.dart:811-852 (existing, VERIFIED by Read this session)
// _assignSyntheticStartTimes's packing loop — the pattern Step 1 should mirror:
int discIdx = 0;
int breakCount = 0;
for (final slot in slots) {
  cursor = slot.start;
  while (cursor + 25 <= slot.end && discIdx < discretionaryChunks.length) {
    discretionaryChunks[discIdx].syntheticStartMinutes = cursor;
    cursor += 25;
    breakCount++;
    final isBoundary = breakCount % longBreakEvery == 0;
    final breakFootprint =
        _shortBreakMinutes + (isBoundary ? _longBreakMinutes : 0);
    if (cursor + breakFootprint <= slot.end) {
      discretionaryChunks[discIdx].reservedBreakMinutes = breakFootprint;
      cursor += breakFootprint;
    } else if (cursor + _shortBreakMinutes <= slot.end) {
      discretionaryChunks[discIdx].reservedBreakMinutes = _shortBreakMinutes;
      cursor += _shortBreakMinutes;
    }
    cursor = _roundUpToLattice(cursor);
    discIdx++;
  }
}
```

### Anti-Patterns to Avoid

- **Recomputing the cadence independently in STEP C**, the way the file's own WR-01 comment
  (lines 642-649) explicitly warns against for the discretionary path: "We do NOT recompute the
  long-break cadence here with an independent counter... A null reservation means the packing pass
  reserved no break room." Step 1's break chunks must be fully formed at emission time (own
  `anchoredStartMinutes`, own `commitmentId`), not decoded later from a footprint field the way
  discretionary chunks are — there is no reason to introduce that indirection for a loop that already
  knows its own cursor.
- **Rounding `block.startMinutes` or `block.endMinutes`** onto the lattice. D-01 is explicit and this
  phase's whole premise depends on it staying that way — verified: my prototype never mutates either
  field, only reads them.
- **Stretching a work chunk over a break that was already reserved.** This was the literal defect
  path I found and fixed (see Pitfall 1/2) — always stretch whichever unit (work or break) is
  actually LAST for that block, never retroactively grow a work chunk backward-in-intent over a
  break slot that already has its own chunk.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Break-footprint reservation with boundary detection and short-only fallback | A new algorithm for commitment windows | The existing pattern at `_assignSyntheticStartTimes:811-852`, copied structurally | Phase 28 already proved this shape correct (D-05 RED-PROOF 6); a second, differently-shaped implementation for the same rule is exactly the kind of drift the file's own WR-01 comment warns against |
| Break-chunk construction (fields, defaults) | A parallel `ScheduledChunk(...)` literal shape | The existing `_shortBreakChunk` helper's field pattern (lines 705-717) as a template — extend or share it rather than hand-writing a third break-construction site | WR-02 in the existing code explicitly calls out "so the break chunk's fields can't drift out of sync between them" — the same discipline applies to a third call site |

**Key insight:** every piece of this problem already has a correct, tested reference implementation
five lines above STEP C in the same file. The phase's actual difficulty is not inventing new
arithmetic — it's correctly wiring the commitment loop's break chunks into the two places that
implicitly assumed commitment chunks were always bare work chunks: the free-slot window merge (STEP
B) and the trailing-break trim (STEP E).

## Common Pitfalls

### Pitfall 1: STEP E's trailing-break trim can silently delete a stretched commitment break

**What goes wrong:** STEP E (line 733-741, current code) trims *any* trailing `shortBreak` chunk
from the whole day's flat result, regardless of origin. Once Step 1 can emit its own break chunks,
a commitment block's break can legitimately end up as the very last chunk of the entire day (e.g. a
commitment block with no discretionary goals, or one whose block is chronologically last). If that
break was the one that got tail-stretched to cover the window's remainder (Pitfall 3), trimming it
doesn't just remove "5 idle minutes" the way it harmlessly does for a discretionary day — it deletes
**however many minutes the stretch had absorbed**, silently shrinking the covered portion of the
user's own committed window.

**How I found it, concretely:** prototyped the fix, ran the existing `LATTICE-02/D-05` fixture
(commitment block 555-600, a 45-minute window, mood 1). Before narrowing STEP E, the test failed
`Expected: <45> Actual: <25>` — the tail-stretched break (which should have covered 580-600, 20
minutes) had been silently deleted, leaving the window's last 20 minutes with **no chunk at all**.
After narrowing STEP E to `commitmentId == null`, the same fixture failed differently (`Expected: <5>
Actual: <6>` — a stale chunk-*count* assumption, not a data-loss bug) and the WR-03 test (which
had ALSO failed before the STEP E fix) started passing again unchanged.

**Why it happens:** STEP E was written for exactly one case — a discretionary day whose last chunk
happens to be a short break with nothing after it (D-05: "a day can now end with an explicit
'take a 30-minute break' card with nothing after it" is fine, but a *short* break with nothing after
it reads as noise). It was never scoped against the possibility of an anchored break existing.

**How to avoid:** narrow the trim condition to
`result.last.chunkType == ChunkType.shortBreak && result.last.commitmentId == null`. Verified fix:
after this change, the LATTICE-01/D-01, LATTICE-02/D-05, Test 2, and Test 13 fixtures fail only on
their own stale numeric assumptions (Pitfall 4), never on a deleted chunk / data-loss shape.

**Warning signs:** any test asserting the LAST chunk in a commitment-only or commitment-tail-heavy
day is a specific duration — if that duration silently reads *shorter* than expected instead of
throwing an index error, this is almost certainly the mechanism.

### Pitfall 2: the free-slot window merge (STEP B) depends on break chunks being anchored, not just work chunks

**What goes wrong:** `_assignSyntheticStartTimes`'s `rawWindows` builder (lines 753-759) derives the
"occupied" span purely from `commitmentChunks`' `[anchoredStartMinutes, +durationMinutes)` spans. If
Step 1's new break chunks are added to `workChunks` WITHOUT `anchoredStartMinutes` set (e.g. only
`syntheticStartMinutes`), they will not appear in `commitmentChunks` (STEP A filters on
`anchoredStartMinutes != null`) and the merge will see two disjoint work-only windows with a gap
between them exactly where the break sits — and a discretionary chunk can then be packed straight
into that gap, double-booking the user's committed time.

**Why it happens:** `commitmentChunks` (the variable name is now slightly misleading — it really
means "everything Step 1 anchored," not "commitment work chunks") already flows into both STEP C's
pass-through AND STEP B's window computation. Getting the anchoring right on the break chunks is
what makes both of those keep working with zero further changes.

**How to avoid:** every chunk Step 1 emits — work, short break, and long break — must carry
`anchoredStartMinutes` (contiguous with its neighbor) so the interval-merge's touching condition
(`next.start <= current.end`) fires and the whole span merges into one window.

**Verified:** I built a dedicated fixture — a 6-hour commitment block saturated with 10 discretionary
habits at mood 5 (heaviest possible packing pressure) — and confirmed by inspecting every
discretionary chunk's `[start, start+25)` range that none overlaps any minute of the commitment
window, including its internal break gaps. The post-commitment discretionary chunk correctly resumes
at the next 30-minute boundary after the window's true end (12:00 after an 09:00-11:40 block), not
at the raw end minute and not inside an internal break gap.

### Pitfall 3: the tail-stretch must never target a break that hasn't been placed yet, and should prefer extending whatever unit is actually last

**What goes wrong:** the existing code's tail-stretch (`lastForBlock.durationMinutes = block.endMinutes - lastForBlock.anchoredStartMinutes!`) always targeted the work chunk, because under the old
algorithm the work chunk was always last (no breaks existed). Once breaks can be emitted, "the last
chunk placed for this block" can be either a work chunk (if no break fit after it) or a break chunk
(if one did, but a sub-lattice remainder is still left over). Stretching the WRONG one — e.g. always
stretching the last WORK chunk even when a break was already placed after it — would grow the work
chunk backward over the break's own time, effectively deleting a break that had already been
successfully reserved. This is the exact "stretch swallowing a break that should have been emitted"
failure mode the ROADMAP names.

**How to avoid:** track "the last chunk actually added for this block" (work or break) as a single
mutable reference, and extend THAT chunk's `durationMinutes` by `block.endMinutes - cursor` at the
end of the loop, never re-deriving which chunk should have been last from position alone.

**Worked examples (all four required cases, using `_moodBreakCadence[3] = 4`, i.e. mood 3, so the
commitment's own boundary chunk would be its 4th — none of these examples reach a boundary, so all
four exercise only the *short*-break-and-stretch path; the boundary/cadence interaction is covered
separately in the Cadence Decision section below):**

| Window | Minutes | Lattice cells that fit | What happens |
|---|---|---|---|
| Divides evenly on 30-min lattice | 540-600 (60 min) | 2 full 30-min cells | W@540(25) → SB@565(5) → W@570(25) → SB@595(5, reaches exactly 600 — no stretch needed, remainder is 0) |
| 10-minute remainder | 540-610 (70 min) | 2 full cells + 10 min left | W@540(25) → SB@565(5) → W@570(25) → SB@595(5) → remainder 10 min (600→610): **last unit is the SB just placed; stretch IT** from 5→15 min (595-610) |
| 27-minute remainder | 540-627 (87 min) | 2 full cells + 27 min left | W@540(25) → SB@565(5) → W@570(25) → SB@595(5) → W@600(25)→625: room check for a break: 625+5=630 > 627, so **no break fits at all** after the 3rd work chunk → remainder is 2 min (625→627): **last unit is that WORK chunk; stretch IT** from 25→27 min |
| Shorter than one 25-min cell | 540-560 (20 min) | 0 cells (25 > 20) | The `while (cursor+25 <= endMinutes)` loop body never executes once. `lastForBlock` stays null. **Zero chunks are emitted for this block on this day** — same as the pre-existing behavior for a sub-25 window, verified unchanged by running this exact fixture through both the old and prototyped code |

All four rows were run through the real `generate()` this session (not hand-derived); the table
above is the actual captured output, reformatted.

### Pitfall 4: four existing tests assert the pre-phase shape and must change; a fifth I expected to change does not

**Verified by patching `lib/services/schedule_generator.dart` and running `flutter test` — not
predicted.** STATE.md records a precedent (Phase 21) where an earlier "N tests must change" claim
was stale and wrong; this project has been burned by that exact mistake before, so I ran the real
suite rather than reasoning it out.

**Baseline: 587 tests green.** After prototyping the fix (footprint reservation in Step 1 + the STEP
E narrowing from Pitfall 1), exactly **4** tests in `test/services/schedule_generator_test.dart` fail
— all four fail because they assert the pre-phase "commitment chunks never contain breaks" shape,
which is precisely the shape this phase exists to change:

| Test | Current assertion | Why it fails | What it should assert post-fix |
|---|---|---|---|
| `Test 2: commitment block on Monday generates 2 anchored chunks` (line 104-121) | `workChunks[1].anchoredStartMinutes == 565` (i.e. `540+25`, back-to-back, no break) | The default `makeBlock()` fixture is 540-600 (60 min = 2 full lattice cells). Post-fix the 2nd work chunk starts at **570** (540+25+5, after the first short break), not 565 | `workChunks[1].anchoredStartMinutes == 570`; also worth asserting the short break at 565 explicitly |
| `Test 13: all-commitment day → commitment chunks only, no breaks` (line 407-429) | `hasAnyBreak == false` | This is the literal defect the phase fixes — an all-commitment day now legitimately contains breaks | Invert the assertion, or replace the whole test with one that asserts break *placement*, not absence |
| `LATTICE-01/D-01: a fixed commitment keeps its own wall-clock start, unrounded` (GUARD 7, line 2725-2761) | `anchored.length == 2` (only the 2 work chunks; comment states "D-01/D-02 only affect the free-slot start rounding, never the anchored chunks themselves") | The test's own comment enshrines the misreading of D-01 the ROADMAP calls out as the root cause. Post-fix, `anchored.length == 4` (2 work + 2 short breaks, since 540-600 is exactly 2 lattice cells) | Keep the "540 stays 540, unrounded" assertion (that part is still correct and load-bearing for D-01) but update the chunk count and rewrite the comment to stop asserting "never the anchored chunks themselves" |
| `LATTICE-02/D-05: a slot too narrow for the boundary footprint reserves the short break only...` (narrow fixture inside this test, line 2565-2722) | `narrow.length == 5` and `narrow[4].durationMinutes == 45` (a single work chunk stretched to cover the whole 45-min window, no break) | The 45-minute window (555-600) now fits one work chunk (25 min) **plus** a short break, tail-stretched: `narrow.length == 6`, `narrow[4].durationMinutes == 25` (unstretched work), and a new `narrow[5]` is the break, tail-stretched from 5→20 min | Update both the length and the per-index shape; this is the test that most directly demonstrates COMMITBREAK-01 working on a narrow window |

**One test I predicted would need to change and it did not — verify this claim before assuming
otherwise:** `WR-03: break never sorts between contiguous commitment chunks (narrow pre-gap)` (line
571-617) uses a block 540-590 (a 50-minute window — exactly 2×25 with **zero** slack for any break).
I initially expected this to fail, since its comment asserts commitment chunks are always adjacent —
but 2×25=50 leaves no room for a break to fit at all, so the *capacity-driven omission* path (not a
"no breaks in commitment blocks" rule) produces the same adjacency this test already asserts. It
passes unchanged, for a different underlying reason than its comment currently states — worth a
comment update, not a behavior change.

**Tests confirmed cadence-insensitive (grepped, read, and left running in the full suite) — do NOT
need to change:**
- `Test 10: commitment block + discretionary — no breaks between commitment chunks` (line 296-326) —
  passes, but only because `indexWhere(anchoredStartMinutes == 565)` happens to match the *break*
  chunk now sitting at 565 (since work1 ends exactly there) rather than a work chunk — the test's
  literal assertion (`idx565 == idx540 + 1`) still holds, but its comment ("no breaks between
  commitment chunks") is now false. Flag for a comment fix even though no assertion needs to change.
- `LATTICE-01/D-02: work resumes on the lattice after an off-boundary commitment` (line 2333-2397) —
  only inspects `anchoredStartMinutes == null` (discretionary) chunks, never the commitment portion's
  own composition — genuinely unaffected.
- All 4 one-off dated-commitment tests (line 1768-1849) — only check `workChunks.length` and the
  *first* work chunk's `anchoredStartMinutes`/`rationale`, never break composition.
- `WR-02: overlapping commitment blocks merge` — only checks that no discretionary work chunk
  overlaps the merged commitment range; unaffected by what's inside that range.

**The `makeBlock` fixture itself** (540-600, "60-min window → 2 slots", line 44-54) is exactly what
the ROADMAP names as the actual defect-behind-the-defect: it produces the cleanest possible
even-lattice case (2 full 30-minute cells) and yet no pre-existing test in the file asserted break
placement for it — every test using it either checked work-chunk-only properties or asserted the
explicit absence of breaks.

### Pitfall 5: `lib/providers/schedule_notifier.dart:addEventToday` duplicates this exact defect, outside this phase's declared file scope

**What goes wrong — new finding, not named in the ROADMAP.** `schedule_notifier.dart` (lines
277-303, `addEventToday`) builds a commitment block's anchored work chunks for the "add an event to
today without a full regenerate" flow, with its own copy of the identical `cursor += 25` /
tail-stretch logic, doc-commented as literally mirroring the generator: *"Build 25-minute anchored
work chunks across the block window — mirrors the commitment-anchoring step in
ScheduleGeneratorService.generate()."* It has the same defect: no break reservation, and the
mirrored tail-stretch comment even repeats the same "the human's committed time" framing this phase's
root cause report criticizes.

**Why this matters for planning, even though it's out of the declared boundary:** CONTEXT.md scopes
this phase to "`lib/services/schedule_generator.dart` only." That line is in `lib/providers/`, not
`lib/screens/` (which is explicitly out of scope) — so it is not covered by the stated exclusion, but
it is also not named by the ROADMAP's "root cause, two lines" framing, which only cites
`schedule_generator.dart`. **If this phase fixes only the generator, a day generated via check-in
will show commitment breaks, but a commitment added mid-day via "add event to today" will not** —
reproducing the owner's exact reported symptom by a second path, immediately after this phase closes.
This is a genuine planning decision (in scope vs. explicit fast-follow), not something research
should silently resolve — surfacing it is the deliverable.

**Recommendation:** the plan should explicitly decide (and record in SUMMARY key-decisions) whether
`addEventToday` is fixed in this phase or deliberately deferred with a named follow-up. If deferred,
the reasoning belongs in ROADMAP as a fast-follow note, the same way this phase itself was raised
from Phase 29's UAT.

### Pitfall 6: setting `commitmentId` on the new break chunks changes their rendered color, for free, via existing unrelated code

**What goes wrong:** `lib/screens/schedule/widgets/chunk_card.dart:449` reads
`chunk.commitmentId != null` to decide `tertiaryContainer` styling (`isCommitment`). This is
existing, unmodified code — out of this phase's file scope — but if Step 1 sets `commitmentId:
block.id` on the emitted break chunks (which Pitfall 2 requires for `anchoredStartMinutes`, but does
NOT require for `commitmentId` — they're independent fields), those breaks will silently pick up the
commitment's tertiary-container visual treatment instead of the ordinary break styling Phase 29 just
finished tuning.

**How to avoid / decide:** this is a genuine Claude's-discretion fork with a visible UI consequence
from a file this phase is not supposed to touch. Two options: (a) set `commitmentId` on commitment
breaks too — they get commitment-tinted styling, consistent with "this whole block belongs to your
meeting"; (b) leave `commitmentId` null on the break chunks (only work chunks get it) — they render
as ordinary breaks, visually indistinguishable from a discretionary break. Either is defensible; the
plan must pick one deliberately and say why, since it's an emergent effect of existing code, not
something a comment in `schedule_generator.dart` alone will make obvious.

## Cadence Decision (ROADMAP item 2 — settled by simulation, not estimate)

**Recommendation: give each commitment block its own independent cadence counter, starting fresh at
each block instance. Do not share `breakCount` with the discretionary loop.**

### Why sharing is structurally unsound here (not just more complex)

The two loops run at different times in `generate()` and in different order than wall-clock time:
Step 1 (commitment) executes and finishes *before* Steps 2-4 collect discretionary demand, which is
in turn *before* STEP B packs discretionary chunks with its own local `breakCount`. But a
discretionary chunk can land **chronologically before** a commitment block (verified: my repro
fixture places a discretionary chunk at 08:00 ahead of a 09:00 commitment). A single counter shared
across both loops would therefore count in **code-execution order** (commitment always first), not
**wall-clock order** (which varies day to day depending on where free slots land) — breaking the "the
Nth chunk of your day" mental model the cadence exists to serve, and doing so unpredictably, which
directly contradicts CLAUDE.md's "a schedule the user can't predict is one they won't trust."
Building genuine wall-clock-ordered sharing would require restructuring `generate()` into a single
interleaved pass — a materially larger change than the ROADMAP's four named deliverables, and outside
this phase's stated boundary (`schedule_generator.dart`'s Step 1 and STEP C only).

### Simulation: a 6-hour meeting block, mood 3 (N=4) — run against the real prototype, not hand-derived

```
work 09:00-09:25 (25m)                    breakCount=1
shortBreak 09:25-09:30 (5m)
work 09:30-09:55 (25m)                    breakCount=2
shortBreak 09:55-10:00 (5m)
work 10:00-10:25 (25m)                    breakCount=3
shortBreak 10:25-10:30 (5m)
work 10:30-10:55 (25m)                    breakCount=4  <- boundary
shortBreak 10:55-11:00 (5m)
longBreak 11:00-11:30 (30m)
work 11:30-11:55 (25m)                    breakCount=5
shortBreak 11:55-12:00 (5m)
work 12:00-12:25 (25m)                    breakCount=6
shortBreak 12:25-12:30 (5m)
work 12:30-12:55 (25m)                    breakCount=7
shortBreak 12:55-13:00 (5m)
work 13:00-13:25 (25m)                    breakCount=8  <- boundary
shortBreak 13:25-13:30 (5m)
longBreak 13:30-14:00 (30m)
work 14:00-14:25 (25m)                    breakCount=9
shortBreak 14:25-14:30 (5m)
work 14:30-14:55 (25m)                    breakCount=10 (short break at 895-900 fits exactly,
                                                          then trimmed by STEP E — see Pitfall 1's
                                                          note: this is the discretionary-day trim
                                                          rule, and correctly does NOT apply once
                                                          STEP E is narrowed per this phase's fix;
                                                          shown here with the narrowed fix NOT yet
                                                          applied for illustration)
```

**Result: 10 work chunks, 2 long breaks (30 min each), 10 short breaks.** Total time consumed:
10×25 + 10×5 + 2×30 = 250+50+60 = **360 minutes — exactly the block length, with zero remainder and
no stretch needed** (a coincidence of this specific window length, not a general property).

This directly answers the ROADMAP's own framing: **2 long breaks for a 6-hour meeting is neither
"four" (over-accrual, the shared-counter risk) nor "zero" (the current bug) — it's the same density
a 6-hour block of purely discretionary work would get at the same mood**, which is the intuitive,
predictable outcome the cadence exists to produce. This is the concrete simulation evidence requested
by CONTEXT.md in place of an estimate.

### Interaction with Phase 28's D-04 capacity concern — does NOT recur here

Phase 28's D-04 had to check whether the lattice's extra break time could push discretionary chunks
past the day's cap or end. That concern doesn't apply to commitment blocks: `block.startMinutes` and
`block.endMinutes` are **fixed, user-entered facts** (D-01) that the generator never moves — adding
internal breaks changes the window's *contents*, never its *boundaries*, and commitment chunks are
explicitly "not counted against cap" (the file's own top-of-class doc comment, line 16). There is no
capacity or day-end interaction to resolve here, and no `_moodCap`/`_moodBreakCadence` value needs to
change. Verified: my 6-hour-meeting fixture and the full 587-test suite both confirm mood caps and
day boundaries are untouched by this phase's change.

## Runtime State Inventory

Not applicable — this is not a rename/refactor/migration phase. No stored data, live service config,
OS-registered state, secrets, or build artifacts are affected. This phase is pure generator
arithmetic with no Hive schema change (confirmed: `ScheduledChunk`'s existing fields — `chunkTypeIndex`, `anchoredStartMinutes`, `commitmentId`, `durationMinutes` — already support everything this
phase needs; no new `@HiveField` is required).

## Code Examples

### The exact ROADMAP reproduction, captured from the real `generate()` this session

Fixture: commitment block `Work` 09:00-11:40 + one discretionary habit goal, mood 3, Monday.

**Before the fix (pre-phase code, captured this session):**
```
work       08:00-08:25 (25m)
shortBreak 08:25-08:30 (5m)
work       09:00-09:25 (25m) [ANCHORED: Work]
work       09:25-09:50 (25m) [ANCHORED: Work]
work       09:50-10:15 (25m) [ANCHORED: Work]
work       10:15-10:40 (25m) [ANCHORED: Work]
work       10:40-11:05 (25m) [ANCHORED: Work]
work       11:05-11:40 (35m) [ANCHORED: Work]   <- stretched tail, no breaks anywhere
```
This matches the ROADMAP's cited repro byte-for-byte (same clock times, same stretched 35m tail).

**After the prototyped fix (captured this session, same fixture):**
```
work       08:00-08:25 (25m)
shortBreak 08:25-08:30 (5m)
work       09:00-09:25 (25m) [ANCHORED: Work]
shortBreak 09:25-09:30 (5m) [ANCHORED]
work       09:30-09:55 (25m) [ANCHORED: Work]
shortBreak 09:55-10:00 (5m) [ANCHORED]
work       10:00-10:25 (25m) [ANCHORED: Work]
shortBreak 10:25-10:30 (5m) [ANCHORED]
work       10:30-10:55 (25m) [ANCHORED: Work]
shortBreak 10:55-11:00 (5m) [ANCHORED]
longBreak  11:00-11:40 (40m) [ANCHORED]         <- reserved at chunk 5 (own counter, N=4 boundary),
                                                    then tail-stretched from 30->40 to cover the
                                                    window's last 10 minutes (no remainder left over)
```
`block.startMinutes`/`endMinutes` (09:00/11:40) are unchanged in the `CommitmentBlock` record in
both runs — confirmed by inspecting the block object directly, not inferred from chunk output.

### The prototype patch (Step 1), as actually run this session

```dart
// PROTOTYPE — built, run against the full suite, then reverted this session.
// Source: this session's empirical work on lib/services/schedule_generator.dart Step 1.
int cursor = block.startMinutes;
ScheduledChunk? lastForBlock; // last chunk added for THIS block (work or break)
int blockBreakCount = 0;      // own cadence counter per block instance (see Cadence Decision)
while (cursor + 25 <= block.endMinutes) {
  final chunk = ScheduledChunk(
    chunkTypeIndex: ChunkType.work.index,
    goalId: null,
    commitmentId: block.id,
    durationMinutes: 25,
    anchoredStartMinutes: cursor,
    rationale: block.name,
  );
  workChunks.add(chunk);
  lastForBlock = chunk;
  cursor += 25;
  blockBreakCount++;
  final isBoundary = blockBreakCount % longBreakEvery == 0;
  final breakFootprint = _shortBreakMinutes + (isBoundary ? _longBreakMinutes : 0);
  if (cursor + breakFootprint <= block.endMinutes) {
    final sb = ScheduledChunk(
      chunkTypeIndex: ChunkType.shortBreak.index,
      goalId: null,
      commitmentId: block.id, // see Pitfall 6 — deliberate choice, argue it in the plan
      durationMinutes: _shortBreakMinutes,
      anchoredStartMinutes: cursor,
      rationale: '',
    );
    workChunks.add(sb);
    lastForBlock = sb;
    cursor += _shortBreakMinutes;
    if (isBoundary) {
      final lb = ScheduledChunk(
        chunkTypeIndex: ChunkType.longBreak.index,
        goalId: null,
        commitmentId: block.id,
        durationMinutes: _longBreakMinutes,
        anchoredStartMinutes: cursor,
        rationale: '',
      );
      workChunks.add(lb);
      lastForBlock = lb;
      cursor += _longBreakMinutes;
    }
  } else if (cursor + _shortBreakMinutes <= block.endMinutes) {
    final sb = ScheduledChunk(
      chunkTypeIndex: ChunkType.shortBreak.index,
      goalId: null,
      commitmentId: block.id,
      durationMinutes: _shortBreakMinutes,
      anchoredStartMinutes: cursor,
      rationale: '',
    );
    workChunks.add(sb);
    lastForBlock = sb;
    cursor += _shortBreakMinutes;
  }
  // else: no break reserved — genuine capacity-driven omission, mirrors D-05
}
if (lastForBlock != null && cursor < block.endMinutes) {
  lastForBlock.durationMinutes = lastForBlock.durationMinutes + (block.endMinutes - cursor);
}
```

And the required STEP E change (Pitfall 1):
```dart
// Source: this session's empirical work — narrows the existing trim (line 733-741)
while (result.isNotEmpty &&
    result.last.chunkType == ChunkType.shortBreak &&
    result.last.commitmentId == null) {
  result.removeLast();
}
```

**This is a prototype, not a prescribed final implementation** — the plan should design its own
task breakdown and RED-proof tests around this shape, but the arithmetic, the STEP E interaction, and
the window-merge dependency (Pitfall 2) are all empirically confirmed, not theoretical.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Step 1: `cursor += 25`, no break tracking | Step 1: mirrors `_assignSyntheticStartTimes`'s footprint-reservation loop | This phase | Commitment blocks get breaks on the same 25+5 lattice as discretionary time |
| STEP E trims any trailing short break | STEP E trims only discretionary-origin (`commitmentId == null`) trailing short breaks | This phase (Pitfall 1) | Prevents silent data loss of a stretched commitment-tail break |

**No third-party library or Flutter framework API is deprecated or changed here** — this is entirely
internal, hand-rolled scheduling logic; there is no upstream state-of-the-art to track.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Setting `commitmentId` on commitment-emitted break chunks (vs. leaving it null) is the right visual/data choice | Pitfall 6 | Low — either choice is internally consistent; wrong choice only costs a follow-up styling tweak, easily caught by the closing human-verify screenshot the ROADMAP already requires |
| A2 | `addEventToday`'s duplicate defect (Pitfall 5) should be a deliberate scope decision made in planning, not silently left unfixed or silently folded in | Pitfall 5 | Medium — if the plan doesn't address this explicitly, the owner will very likely hit the exact reported symptom again via a different entry point (adding an event mid-day), reopening a "third report of the same bug" |

Both items above are genuine open decisions for the plan to make explicitly (per this phase's own
CONTEXT.md instruction: "the reasoning goes in the plan... not a comment, not an assumption"), not
unverified facts — the underlying code behavior for each is verified by reading the source this
session (`chunk_card.dart:449`, `schedule_notifier.dart:277-303`).

## Open Questions

None remaining that block planning — the two items in the Assumptions Log are scope/design decisions
for the plan to make explicitly, not factual gaps.

## Environment Availability

Not applicable — no external dependencies beyond the existing Flutter/Dart toolchain, already
confirmed working this session (`flutter test` ran the full 587-test suite successfully with
`PATH="$PATH:/home/dan/development/flutter/bin"`, per CLAUDE.md).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter 3.44.1 / Dart 3.12.1 — confirmed this session via `flutter --version`) |
| Config file | none — standard `flutter test` convention, no custom config |
| Quick run command | `flutter test test/services/schedule_generator_test.dart --concurrency=1` |
| Full suite command | `flutter test --concurrency=1` (confirmed this session: default concurrency's expanded reporter drops/duplicates per-test-name lines at scale — Phase 28's precedent, `28-03-SUMMARY.md`; `--concurrency=1` is required for a trustworthy by-name RED→GREEN diff) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COMMITBREAK-01 | A break is emitted between consecutive work chunks inside a commitment block, on the 25+5 lattice | unit | `flutter test test/services/schedule_generator_test.dart --concurrency=1` | ✅ (file exists; needs new assertions per Pitfall 4 — this phase's regression test, built from a commitment block, is a first-class deliverable per CONTEXT.md, not a formality) |
| COMMITBREAK-02 | The commitment's own start/end are unchanged | unit | same file — assert `block.startMinutes`/`endMinutes` unchanged across the fixtures in the Pitfall 3 worked-examples table | ✅ (existing `LATTICE-01/D-01` GUARD 7 already asserts the unrounded-start half of this; extend rather than replace) |

### Sampling Rate

- **Per task commit:** `flutter test test/services/schedule_generator_test.dart --concurrency=1`
- **Per wave merge:** `flutter test --concurrency=1` (full suite — this phase's whole verified
  blast radius is 4 tests in one file, but the full suite is the only way to also re-confirm the
  D-06 render-layer tests, `lattice_break_pair_test.dart`, stay green now that commitment-block
  breaks flow through `buildTimeline`/`chunk_card.dart` for the first time)
- **Phase gate:** Full suite green before `/gsd-verify-work`, per this project's existing convention

### Wave 0 Gaps

None — `test/services/schedule_generator_test.dart` already exists with a rich fixture library
(`makeBlock`, `makeHabit`, etc.) that this phase's regression tests should extend directly, per
CONTEXT.md's explicit instruction to build the primary regression fixture "from a commitment block,
not a goal." A **new** primary fixture (not `makeBlock`'s default 60-min window, which produces the
degenerate zero-remainder case) is recommended — the ROADMAP's own repro (`Work` 09:00-11:40, a
160-minute window) already exercises the boundary/cadence interaction plus a non-trivial tail
stretch, and is the fixture the owner's own screenshot matched.

**Manual/human-verify requirement (per CONTEXT.md and ROADMAP):** unlike Phase 28 (fully
`flutter test`-verifiable arithmetic, no human checkpoint), this phase's own CONTEXT.md requires ONE
real-browser screenshot before closing — not because the assertions are untrustworthy (they are:
this is integer arithmetic, no glyph metrics, same category as Phase 28), but because the owner has
now reported this exact symptom twice and a generated-day screenshot is what closes it credibly.
Plan a `checkpoint:human-verify` task reusing port 8143, and the task's own instructions MUST include
CLAUDE.md trap #4 (re-check-in via ⟳ before judging — `ScheduleNotifier._loadToday()` never
regenerates an already-generated day) as CONTEXT.md explicitly requires ("must appear in the UAT's
own instructions").

## Security Domain

Not applicable — `security_enforcement` is not referenced in `.planning/config.json` and this phase
touches no authentication, session, input-validation-from-untrusted-source, or cryptography surface.
It is pure internal arithmetic over `int` minute values already validated elsewhere (commitment
window entry already enforces a >= 25-minute window per `schedule_notifier.dart`'s comment at line
279-280, and `moodIndex` is asserted 1-5 at the top of `generate()`).

## Sources

### Primary (HIGH confidence — read this session, or produced by running real code this session)
- `lib/services/schedule_generator.dart` (full file, 861 lines) — read in full this session
- `lib/data/models/scheduled_chunk.dart`, `lib/data/models/commitment_block.dart` — read in full this session
- `lib/providers/schedule_notifier.dart:200-330` — read this session (Pitfall 5)
- `lib/screens/schedule/widgets/chunk_card.dart:430-470` — read this session (Pitfall 6)
- `test/services/schedule_generator_test.dart` — read extensively this session (fixtures at
  lines 1-70, 100-260, 290-470, 560-650, 1760-1850, 2290-2760)
- `.planning/ROADMAP.md` §§ "Phase 28", "Phase 29", "Phase 30" — read in full this session
- `.planning/STATE.md` — read in full this session (Carry-Forward Invariants, Engine Constraints)
- `.planning/phases/30-breaks-in-committed-time/30-CONTEXT.md` — read in full this session
- `flutter test` output, this session, both before and after the prototype patch (baseline 587
  green; 4 failures after the fix, all identified and explained; full suite re-confirmed green
  after revert)
- `flutter --version` output, this session (Flutter 3.44.1, Dart 3.12.1)

### Secondary (MEDIUM confidence)
None used — every claim in this document is either read from source this session or produced by
running the actual code this session (Primary tier).

### Tertiary (LOW confidence)
None.

## Metadata

**Confidence breakdown:**
- Standard stack: N/A — no external packages
- Architecture: HIGH — verified by reading every consuming site (`STEP A`/`STEP B`/`STEP E`,
  `chunk_card.dart`, `schedule_notifier.dart`) and by running a prototype through the real suite
- Pitfalls: HIGH — all 6 pitfalls were either directly observed as test failures this session
  (Pitfalls 1, 3, 4) or confirmed by constructing and running a targeted fixture (Pitfall 2), or
  found by reading the actual consuming source this session (Pitfalls 5, 6)

**Research date:** 2026-08-24
**Valid until:** No expiry driver — this is internal arithmetic with no external dependency to go
stale; valid until the next change to `schedule_generator.dart`'s Step 1/STEP C/STEP E or to
`schedule_notifier.dart`'s `addEventToday`.
