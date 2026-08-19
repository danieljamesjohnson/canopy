# Phase 28: The Day Is a Lattice - Research

**Researched:** 2026-08-19
**Domain:** Deterministic scheduling arithmetic (pure Dart, no UI, no external libraries)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

None recorded under `## Decisions` in 28-CONTEXT.md — the phase's only "Settled" item is
captured below under Claude's Discretion framing, but it is non-negotiable:

**N stays set once, from the morning check-in mood.** The owner was asked directly (2026-08-19)
whether N should react to how the day actually goes, or carry over from yesterday. He chose
neither. The existing `_moodBreakCadence` table `{1:2, 2:3, 3:4, 4:4, 5:5}` stays as the source
of N. This phase does not make the engine adaptive; adaptivity is a different phase, not a
smaller version of this one.

His illustration used N=3, which is the mood-2 value. That was an example of the *shape*, not a
request to retune the table. **If planning believes the table should move, ask — do not infer it
from the example.**

### Claude's Discretion

All remaining implementation choices are at Claude's discretion. Use the ROADMAP phase
description, the three named defects, and existing codebase conventions to guide them.

**One decision that must be made deliberately, not by accident:** `_moodCap` sets how many work
chunks a day gets `{1:4, 2:6, 3:8, 4:9, 5:11}`. The lattice makes each cycle longer than it is
today. Decide deliberately whether the cap moves or the day's end moves, and state which in the
plan. Do not let it fall out of the packing loop as a side effect. **Research finding below: under
the nominal 8am–10pm window, no cap needs to move — see "The Capacity Squeeze, With Numbers."**

### Deferred Ideas (OUT OF SCOPE)

- **Adaptive N** (reacting to how the day actually goes, or carrying over from yesterday) —
  explicitly declined by the owner 2026-08-19.
- **Retuning `_moodBreakCadence`** — not requested; ask before changing.
- Any UI work; any change to how chunks are *displayed* (Phase 27's territory, not this one's).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LATTICE-01 | Every chunk starts on a 30-minute boundary | See "Where an off-lattice minute can enter" — three concrete entry points identified with line numbers; two are in-scope fixes, one (commitment `anchoredStartMinutes`) is an explicit scoping question for the planner. |
| LATTICE-02 | A 30-minute break after every N work chunks, N from morning mood, never silently suppressed | See "The Three Defects, Verified" and "Recommended Data-Model Change" — defects 1–3 confirmed against the current code with line numbers; a concrete fix shape (single-field footprint encoding + STEP E trim-policy change) is proposed. |
</phase_requirements>

## Summary

This phase is a pure-arithmetic fix inside one file, `lib/services/schedule_generator.dart`
(761 lines), touching two private methods: `generate()`'s Step-C/STEP-E break-emission/trim logic,
and `_assignSyntheticStartTimes()`'s packing loop. No new dependencies, no UI, no persistence
migration (the field that carries the cadence state, `reservedBreakMinutes`, is explicitly **not**
a `@HiveField` — it is scratch state used only during one `generate()` call and discarded).

All three named defects are confirmed against the code exactly as described in CONTEXT.md/ROADMAP.md,
with one addition this research surfaces: **the existing trailing-chunk trim (STEP E) will re-suppress
the fixed long break** unless it is explicitly exempted, because it removes *any* trailing non-work
chunk, long or short. Fixing defects 1–3 without also touching STEP E reproduces defect 3 by a
different path. This is the single most important non-obvious finding in this research.

The second major finding is arithmetic: this research computed, precisely, how much wall-clock the
new lattice costs per mood versus today's buggy engine, against the actual 480–1320 (8am–10pm,
840-minute) window the code derives. **Under the nominal window, with zero commitments, every mood's
cap still fits with 455–695 minutes of slack to spare** — the lattice costs 10–20 extra minutes across
a whole day, not per chunk. The "squeeze" CONTEXT.md warns about does not manifest under nominal
conditions; it is a real but narrower risk specific to commitment-heavy days or late `startFloorMinutes`
(mid-day regeneration), which this research also quantifies. This changes the shape of the decision the
planner has to make deliberately: the honest answer, backed by the numbers, is "neither the cap nor the
day's end needs to move for the general case" — with the residual narrow-window risk flagged as a
pre-existing, pre-lattice condition that gets marginally worse and should be a named, deliberate
non-change rather than an unexamined one.

Third, this research traced every place a chunk's start minute is assigned and found **three
concrete entry points where an off-lattice (non-≡0-mod-30) minute can be introduced** — two of them
squarely inside this phase's file and directly relevant to LATTICE-01, one of them a scoping question
(commitment-anchored chunks) that the planner should explicitly resolve rather than silently include
or exclude.

Fourth, this research ran the full test suite (567 tests, all green, `flutter analyze` clean as of
2026-08-19) and identified by name which existing tests in `test/services/schedule_generator_test.dart`
assert on exact break durations, chunk-sequence patterns, or start-time rounding, and therefore will
go RED under a correct fix — roughly 10 tests, not the whole file. This is the blast radius.

**Primary recommendation:** Fix defects 1–3 together as a single coherent change to the packing loop
and STEP C/STEP E, using the "reserved footprint" encoding described below (keeps `reservedBreakMinutes`
as one field; no model/Hive changes). Do not move `_moodCap` or `dayEnd` — the numbers do not support it
for the nominal case; instead, decide and document a policy for the narrow-window case (commitment-heavy
or late-start days), and make LATTICE-01 rounding explicit at the two entry points this research
identifies. Verification is 100% `flutter test` — no browser step, per CONTEXT.md's own instruction.

## Architectural Responsibility Map

Canopy is a client-only Flutter app (no server tier) — the generic Browser/SSR/API/CDN/DB table
in the standard research template does not map cleanly. Adapted for this codebase's actual layers
(see `CLAUDE.md`'s Architecture section):

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Break cadence (N, long-break insertion) | Service layer (`lib/services/schedule_generator.dart`) | — | Pure deterministic Dart, no Flutter imports (per the file's own doc comment); this is where the bug lives and where the fix belongs. |
| Lattice-aligned start-time assignment | Service layer (`_assignSyntheticStartTimes`) | — | Same file, same method that already owns all `syntheticStartMinutes` writes. |
| Cadence-state carrying (`reservedBreakMinutes`) | Data model (`lib/data/models/scheduled_chunk.dart`) | Service layer (consumer) | Declared on `ScheduledChunk` but explicitly documented as "NOT stored in Hive" — a service-layer scratch field the model happens to host. No persistence-layer change needed. |
| Rendering the resulting chunks | Presentation layer (`lib/screens/today/`, `chunk_card.dart`, `TimelineGeometry`) | — | **Explicitly out of scope** per CONTEXT.md's Phase Boundary — this phase does not touch `TimelineGeometry`, `LiveRowCard`, or any timeline widget. Confirmed: those files already handle `ChunkType.longBreak`/`shortBreak` generically (no cadence-specific logic found there), so no ripple is expected, but this is unverified beyond a code read — see Open Questions. |

**This phase touches only the Service layer.** No Data/Persistence or Presentation layer changes
are required by the requirements as scoped.

## Standard Stack

No new dependencies. This phase is a bug fix to existing pure-Dart logic in the existing
`ScheduleGeneratorService`. `pubspec.yaml` (read in full) already provides everything used:
`intl` (date formatting, already imported), Dart core (`dart:math`, already imported). No `http`,
no state management change, no new package of any kind.

### Alternatives Considered

None applicable — there is nothing to build-vs-buy here. A 30-minute lattice with configurable
cadence is ~40 lines of integer arithmetic; no scheduling/cron package on pub.dev models "N Pomodoro
cycles then a long break," and CLAUDE.md's "dumb app on purpose" instruction forecloses reaching for
any smart-scheduling dependency regardless.

**Installation:** none required.

## Package Legitimacy Audit

**Not applicable.** This phase installs no external packages. No `npm view`/`pip index
versions`/`cargo search` verification is required; the Package Legitimacy Gate is skipped by
design (no packages to check).

## Architecture Patterns

### System Architecture Diagram

```
generate({moodIndex, goals, blocks, completionLogs, date, ...})
  │
  ├─ Step 1: Commitment blocks → anchored work chunks (anchoredStartMinutes = block time, verbatim)
  │
  ├─ Step 2-4: Habits / Outcomes / Time-targets → discretionary work chunks
  │            (no start time yet; capped by _effectiveCap(moodIndex, lighterDay))
  │
  ├─ STEP A: split workChunks into commitmentChunks (anchored) / discretionaryChunks (not yet placed)
  │
  ├─ STEP B: _assignSyntheticStartTimes(...)
  │     │
  │     ├─ compute dayStart (480 default, or startFloorMinutes rounded — see LATTICE-01 findings)
  │     ├─ merge commitment windows (interval merge, WR-02)
  │     ├─ derive free `slots` around merged windows
  │     │     ⚠ slot.start = previous window's raw .end — NOT rounded to 30 (LATTICE-01 gap #2)
  │     └─ greedily pack discretionaryChunks into slots, 25 min each
  │           │
  │           └─ per placed chunk: compute breakCount, isLong = breakCount % longBreakEvery == 0
  │                 → breakDur = isLong ? 25 : 5     ⚠ DEFECT 1 (should be 30, and additive not replacing)
  │                 → reserve only if `discIdx + 1 < discretionaryChunks.length`  ⚠ DEFECT 3
  │                 → write chunk.reservedBreakMinutes = breakDur (or leave null)
  │
  ├─ STEP C: for each discretionaryChunk, emit it + (if reservedBreakMinutes != null) one break chunk
  │           isLong = reserved >= 25   ⚠ this threshold silently accepts today's 25-as-long value;
  │                                        must become >= 30 once defect 1 is fixed, or be replaced
  │                                        entirely by the footprint-decoding scheme below
  │
  ├─ STEP D: sort flat list by effective start time (anchoredStartMinutes ?? syntheticStartMinutes)
  │
  └─ STEP E: trim trailing non-work chunks
        ⚠ removes ANY trailing break, short or long — this is what re-suppresses a correctly-emitted
          trailing long break unless STEP E's rule is narrowed (see below)
```

### Recommended Project Structure

No new files. All changes are inside `lib/services/schedule_generator.dart`:

- `_assignSyntheticStartTimes` — packing loop (defects 1, 2, 3; LATTICE-01 rounding gap #1)
- `generate()` STEP B call site — `dayStart` derivation (LATTICE-01 rounding gap #1)
- `generate()` STEP C — break-chunk emission (defects 1, 2)
- `generate()` STEP E — trailing-chunk trim (must be narrowed so it does not re-suppress defect 3's fix)

### Pattern: Encode the reserved break as one "footprint" integer, not two fields

**What:** Keep `ScheduledChunk.reservedBreakMinutes` as a single nullable `int` (it already is,
already non-persisted — `lib/data/models/scheduled_chunk.dart:77`), but change what it *means*.
Today it means "the one break after this chunk, 5 or 25." Change it to mean "total minutes of
break room reserved after this chunk" — `5` (ordinary), or `35` (`5 + 30`, a cadence boundary).
STEP C then decodes it into one or two emitted break chunks:

```dart
// STEP C (illustrative — not the literal diff, but the shape of the fix)
final reserved = chunk.reservedBreakMinutes;
if (reserved == null) continue; // no break room was reserved
if (reserved > 5) {
  // Cadence boundary: short break cell, THEN a separate long break cell.
  result.add(makeBreak(ChunkType.shortBreak, 5, startsAt: chunk.end));
  result.add(makeBreak(ChunkType.longBreak, reserved - 5, startsAt: chunk.end + 5));
} else {
  result.add(makeBreak(ChunkType.shortBreak, reserved, startsAt: chunk.end));
}
```

**When to use:** This is the direct fix for defect 2 ("the long break REPLACES the short break
instead of following it"). The owner's model is explicit: *"After 3 chunks of 25/5, you take an
entire 30 minute break"* — the Nth chunk still closes its own 25/5 cell, and the 30-minute break
is an additional, separate cell. The packing loop's reservation must change symmetrically:

```dart
// _assignSyntheticStartTimes packing loop (illustrative)
final isBoundary = breakCount % longBreakEvery == 0;
final breakDur = 5 + (isBoundary ? 30 : 0);   // DEFECT 1 fix: 30, not 25. DEFECT 2 fix: additive.
if (cursor + breakDur <= slot.end) {
  discretionaryChunks[discIdx].reservedBreakMinutes = breakDur;
  cursor += breakDur;
}
// DEFECT 3 fix: the `discIdx + 1 < discretionaryChunks.length` guard is REMOVED —
// reservation no longer depends on whether more chunks remain. See STEP E change below
// for why this is safe (short-break-only trailing chunks still get trimmed).
discIdx++;
```

**Why this shape over a two-field model:** `reservedBreakMinutes` is not persisted, so there is no
migration cost either way — but a single field keeps the diff to the two methods that already own
it (no model file change at all), and keeps the "is there room" fit-check in the packing loop as
one addition instead of two independent checks that could disagree.

### Pattern: Narrow STEP E's trim to short breaks only

**What:** LATTICE-02 requires the long break is "never silently suppressed" — including at the
end of the day, which is exactly the scenario the three named defects were discovered against
("the exact day the owner was looking at"). The current STEP E trims *any* trailing non-work
chunk:

```dart
// current STEP E — lib/services/schedule_generator.dart:652-655
while (result.isNotEmpty && result.last.chunkType != ChunkType.work) {
  result.removeLast();
}
```

If defects 1–3 are fixed but STEP E is left unchanged, a long break that lands as the final chunk
of the day is trimmed right back out — reproducing defect 3 by a different mechanism. The
recommended fix narrows the trim to short breaks only, so a trailing long break survives:

```dart
// STEP E, narrowed — trims a dangling *short* break, but a trailing long break
// (LATTICE-02: never silently suppressed) is left in place.
while (result.isNotEmpty && result.last.chunkType == ChunkType.shortBreak) {
  result.removeLast();
}
```

**When to use:** Always, once defects 1–3 are fixed together — this is not optional; it is the
mechanism by which LATTICE-02's "never silently suppressed" becomes true in the actual rendered
output rather than just in the packing pass's internal state.

**This is a genuine, small UX decision, not just a bug fix** — it means a day can now end with an
explicit "take a 30-minute break" card that has no more activity after it. That is a direct,
literal reading of the owner's requirement ("never silently suppressed"), but it is a visible
behavior change worth one line of confirmation in the plan rather than a silent side effect.

### Anti-Patterns to Avoid

- **Re-deriving the cadence independently in STEP C.** The existing code comment at
  `schedule_generator.dart:615-621` already documents why this is wrong — STEP C must read
  `reservedBreakMinutes` (the single source of truth written during packing), never recompute
  `breakCount % longBreakEvery` itself. This existing invariant (WR-01, tested at line 497 of the
  test file) must survive the fix unchanged.
- **Bumping `isLong = reserved >= 25` to `>= 30` as the only fix.** This treats defect 1 in
  isolation and leaves defects 2 and 3 in place — the resulting long break would be the right
  duration but still replace the short break and still vanish when trailing.
- **Fixing defects but leaving STEP E untouched.** See above — this silently reintroduces defect 3.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| N/A | — | — | This phase has no "don't hand-roll" candidates — the entire feature *is* the hand-rolled deterministic arithmetic, by explicit product decision (CLAUDE.md: "the scheduling engine is rule-based and deterministic and stays that way"). There is no library for "N Pomodoros then a long break" worth adopting over ~10 lines of integer math, and CLAUDE.md forecloses any "smart" dependency regardless of merit. |

**Key insight:** The temptation to avoid is *not* reaching for a package — it's under-scoping the
fix to defect 1 alone (a one-constant change) when defects 2 and 3 are structural (they change how
many break chunks are emitted and when a trailing one is trimmed) and only understanding all three
together, plus the STEP E interaction this research surfaces, closes LATTICE-02 for real.

## The Three Defects, Verified

All three confirmed exactly as CONTEXT.md/ROADMAP.md describe them, against
`lib/services/schedule_generator.dart` as of 2026-08-19 (commit `0cba546`).

**Defect 1 — long break is 25 minutes, not 30.**
`_assignSyntheticStartTimes`, line 740: `final breakDur = isLong ? 25 : 5;`. `[VERIFIED: codebase]`

**Defect 2 — long break replaces the short break instead of following it.**
Each discretionary chunk carries exactly one `reservedBreakMinutes` (declared once,
`scheduled_chunk.dart:77`), written once per chunk at `schedule_generator.dart:746`. There is no
mechanism to record "both a short and a long break after this chunk" today. STEP C
(`schedule_generator.dart:622-643`) emits at most one break chunk per work chunk, sized entirely by
that single reservation. Confirmed: at N=4 (mood 3), the 4th chunk's break is `isLong ? 25 : 5` →
25, not `5` (its own short break) `+ 25` (the long break). `[VERIFIED: codebase]`

**Defect 3 — the long break is silently suppressed when it would land last.**
`schedule_generator.dart:744-748`:
```dart
if (cursor + breakDur <= slot.end &&
    discIdx + 1 < discretionaryChunks.length) {
  discretionaryChunks[discIdx].reservedBreakMinutes = breakDur;
  cursor += breakDur;
}
```
`discretionaryChunks.length` here is the **pre-filter** length — the full list of discretionary
work chunks demanded that day (built in Steps 2–4 before packing), not the count that ultimately
fit. So `discIdx + 1 < length` is false exactly when the chunk being placed is the *last discretionary
chunk of the day's total demand* — which is exactly the case CONTEXT.md names: mood 3 (N=4) with 4
total discretionary chunks. `[VERIFIED: codebase]`

**Addendum this research adds — the STEP E interaction (see Architecture Patterns above).**
Even with defect 3 fixed in the packing loop, STEP E's blanket trailing-chunk trim
(`schedule_generator.dart:652-655`) removes *any* trailing non-work chunk, long or short — so a
correctly-emitted trailing long break is deleted again at STEP E unless that trim is narrowed to
short breaks only. **This is not one of the three named defects but must be fixed alongside them,
or LATTICE-02 will not actually hold in the rendered output.** `[VERIFIED: codebase]`

## The Capacity Squeeze, With Numbers

CONTEXT.md asks for concrete arithmetic, not adjectives, comparing the lattice's wall-clock cost
against the window `_assignSyntheticStartTimes` actually derives: `dayStart = 480` (8:00 AM, or a
rounded `startFloorMinutes`), `dayEnd = 1320` (10:00 PM) — an 840-minute nominal window.

Simulated the packing algorithm directly (Python model of the greedy loop, cross-checked against
the Dart source line-by-line) for both the current buggy model (defects 1+2: `breakDur = isLong ?
25 : 5`, replacing) and the fixed lattice model (`breakDur = 5 + (isBoundary ? 30 : 0)`, additive),
for each mood's `_moodCap` value (`{1:4, 2:6, 3:8, 4:9, 5:11}`) against its `_moodBreakCadence`
value (`{1:2, 2:3, 3:4, 4:4, 5:5}`), with `lighterDay: false` (the nominal, uncompressed cap):

| Mood | N | Cap (chunks) | Old span (min) | New span (min) | Δ (min) | Nominal window | Slack under new lattice |
|------|---|-----|------|------|-----|-----|-----|
| 1 | 2 | 4 | 135 | 145 | +10 | 840 | **695** |
| 2 | 3 | 6 | 195 | 205 | +10 | 840 | **635** |
| 3 | 4 | 8 | 255 | 265 | +10 | 840 | **575** |
| 4 | 4 | 9 | 305 | 325 | +20 | 840 | **515** |
| 5 | 5 | 11 | 365 | 385 | +20 | 840 | **455** |

(Span = time from the first discretionary chunk's start to the end of the last inter-chunk break
needed to fit all `cap` chunks — i.e., how much room the packing loop actually consumes. `[VERIFIED:
codebase — simulation directly models _assignSyntheticStartTimes's loop structure]`)

**Finding: under the nominal window, with zero commitment blocks, every mood's full cap fits under
the new lattice with 455–695 minutes (7.5–11.5 hours) of slack remaining.** The number of chunks
that fit (`old_fit == new_fit == cap`, verified for all five moods) does not change — only the
finish time shifts 10–20 minutes later than it would under the buggy engine. This directly answers
CONTEXT.md's demand for numbers: **for the general case, neither `_moodCap` nor `dayEnd` needs to
move.** The "watch the capacity interaction" concern is real in principle but the actual magnitude
(10–20 minutes across an entire day, against 455+ minutes of headroom) does not justify moving
either constant.

**Where the squeeze actually could bite** (binary-searched the minimum window at which the new
lattice's `cap` chunks still fully fit):

| Mood | Minimum window needed (old) | Minimum window needed (new) |
|------|------|------|
| 1 | 135 min | 145 min |
| 2 | 195 min | 205 min |
| 3 | 255 min | 265 min |
| 4 | 305 min | 325 min |
| 5 | 365 min | 385 min |

A day only risks losing a chunk it wouldn't have lost before if commitment blocks (or a late
`startFloorMinutes` mid-day regeneration) shrink the *free* window below roughly these thresholds —
e.g., at mood 5, if commitments and/or a late start leave less than ~385 minutes (6h25m) of free
time. **This is a pre-existing risk** (the packing loop already silently drops discretionary chunks
that don't fit — `_assignSyntheticStartTimes`'s trailing comment: *"Discretionary chunks that
didn't fit retain syntheticStartMinutes == null"* and are filtered out, line 758) — the lattice
makes it marginally worse (10–20 more minutes of demand), not newly created.

**Recommendation:** Do not move `_moodCap` or `dayEnd`. Document, as a deliberate non-change, that
the existing silent-drop-on-overflow behavior is unaffected in kind, only in the (small) margin at
which it can trigger — and treat closing that pre-existing silent-drop as out of this phase's scope
unless the planner decides otherwise. This satisfies CONTEXT.md's "decide deliberately... do not
let it fall out of the packing loop as a side effect" — the deliberate decision, backed by
arithmetic, is "no change to the cap or the end-of-day."

## Where an Off-Lattice Minute Can Enter

Traced every site that writes `anchoredStartMinutes` or `syntheticStartMinutes`, and every
rounding/clamping operation between them, looking for anything that is not provably ≡ 0 (mod 30).
Three sites found:

**1. `dayStart` from `startFloorMinutes` rounds to 5 minutes, not 30 —
`schedule_generator.dart:672-679`.**
```dart
final int dayStart = startFloorMinutes == null
    ? defaultDayStart
    : (((startFloorMinutes + 4) ~/ 5) * 5).clamp(defaultDayStart, dayEnd);
```
`defaultDayStart` (480) is already lattice-aligned, so the null-floor path is fine. But when a day
is regenerated mid-day (`startFloorMinutes` supplied — the mechanism that lets the app not "lay
chunks down in already-passed morning hours"), the rounding is to the nearest 5, e.g. a 15:42 floor
rounds to 15:45 — **not** a 30-minute boundary. This directly violates LATTICE-01 for any mid-day
regeneration. **Directly testable and already has an existing test pinning the wrong behavior** —
see Blast Radius below. `[VERIFIED: codebase]`

**2. Free-slot start after a commitment window is the commitment's raw, unrounded end minute —
`schedule_generator.dart:710-722`.**
```dart
final slots = <({int start, int end})>[];
int cursor = dayStart;
for (final w in windows) {
  if (cursor < w.start) {
    slots.add((start: cursor, end: w.start));
  }
  cursor = cursor > w.end ? cursor : w.end;   // <-- unrounded commitment end
}
slots.add((start: cursor, end: dayEnd));
```
`_assignSyntheticStartTimes`'s packing loop then does `cursor = slot.start;` and places the first
discretionary chunk of that slot exactly there. If a commitment block ends at a non-30-aligned
minute (e.g., a 45-minute meeting 9:30–10:15), the next discretionary chunk starts at 10:15, and
**every subsequent discretionary chunk in that slot inherits the 15-minute offset**, since the
packing loop only advances by fixed 25/5/35-minute increments from that starting cursor. This is
the highest-impact of the three entry points because it cascades for the rest of the day, not just
one chunk. `[VERIFIED: codebase]` **This is squarely in-scope** (inside `_assignSyntheticStartTimes`,
the exact method this phase already touches for defects 1–3) and should be fixed by rounding a
free slot's start up to the next 30-minute boundary whenever it follows a commitment window (at
the cost of up to 29 "dead" minutes between the commitment's end and the next chunk — a reasonable
and visible trade-off, not a silent one).

**3. Commitment-anchored chunks use the user's raw `startMinutes`, never rounded —
`schedule_generator.dart:260, 692-695`.**
`anchoredStartMinutes: cursor` where `cursor` starts at `block.startMinutes` — whatever the user
entered when creating the commitment (e.g., a dentist appointment genuinely at 2:15 PM). This is
real-world data the engine cannot and should not move. **This is a scoping question, not a bug**:
does LATTICE-01 ("every chunk starts on a 30-minute boundary, always") apply to commitment-anchored
chunks, or only to the discretionary chunks the engine actually schedules? The owner's model
("the day is split up by 30 minutes... 25 minutes of work and 5 minutes of break") describes the
discretionary rhythm; a fixed external appointment is not part of that rhythm by nature. **Recorded
below as an Open Question — planner/discuss-phase should confirm the scope explicitly rather than
this research assuming it.**

## What Happens When a Fixed Commitment Collides With the Lattice

The code does **not** re-anchor the day mid-day in any global sense. What actually happens (traced
through `_assignSyntheticStartTimes`, lines 681–758):

1. Commitment windows are merged (interval merge, `WR-02`-tested) into non-overlapping ranges.
2. Free slots are computed as the gaps between `dayStart`/`dayEnd` and those merged windows.
3. Each free slot is packed independently, left to right, with its own local cursor.
4. The cadence counter (`breakCount`) is **not** reset per slot — it is declared once, outside the
   slot loop (line 731), and carries across slot boundaries. So a commitment block interrupting a
   would-be lattice cycle does not reset or restart N — chunk 3 before a commitment and chunk 4
   after it (in the next free slot) still trigger the long break at chunk 4, wherever chunk 4
   happens to land.
5. The commitment's own chunks never receive breaks — Step C only emits breaks for discretionary
   chunks (`for (final chunk in discretionaryChunks)`, line 623) — confirmed by existing test
   ("Test 13: all-commitment day → commitment chunks only, no breaks").

**Net effect:** a commitment does not break the cadence *counting*, but per finding #2 above, it
can break the *lattice alignment* of everything packed after it, because the free slot it opens
starts at the commitment's raw end minute. Fixing finding #2 (round the post-commitment slot start
up to :00/:30) closes this gap for LATTICE-01 without touching the cadence-counting behavior
(which is already correct — no cadence-related fix needed here beyond the three named defects).

## Blast Radius — Existing Tests That Will Go RED

Read `test/services/schedule_generator_test.dart` in full (2165 lines, 62 tests) and every other
test file that constructs `ScheduledChunk`s or calls `ScheduleGeneratorService.generate()` (`grep`
across `test/`: `defer_carryover_test.dart`, `commitment_attribution_test.dart`,
`schedule_notifier_add_event_test.dart`, `cold_launch_morning_loop_test.dart`,
`today_screen_now_state_test.dart`). Ran the full suite: **567 tests, all green, `flutter analyze`
clean, as of 2026-08-19 (commit `0cba546`).** `[VERIFIED: ran `flutter test` and `flutter analyze`]`

**Tests that hand-construct `ScheduledChunk` fixtures directly** (`today_screen_now_state_test.dart`,
`schedule_notifier_add_event_test.dart`) **do not call the generator** — they set
`durationMinutes`/`chunkTypeIndex` literally, independent of the cadence logic. **Unaffected by
this phase** — confirmed no assertion in these files depends on generator-computed cadence
behavior.

**Tests in `schedule_generator_test.dart` that WILL go RED** (name, line, reason):

| Test | Lines | Why it breaks |
|------|-------|----------------|
| `Test 6: mood=3 break pattern with 4 work chunks (trailing break trimmed)` | 190-216 | N=4, exactly 4 discretionary chunks — the boundary chunk is the last chunk. Expects `result.length == 7`, last chunk = work, no long break anywhere. Under the fix, chunk 4 gets a short break AND a surviving trailing long break → `result.length` becomes 9, last chunk becomes `longBreak`. |
| `Test 7: mood=1 break pattern with 2 work chunks (trailing break trimmed)` | 222-243 | N=2, exactly 2 discretionary chunks — same shape as Test 6 at a smaller N. `result.length` 3 → 5 under the fix. |
| `BREAK-01: mood=1 places a long break after every 2 work chunks` | 1842-1876 | Asserts `result[3].durationMinutes == 25` (long break) and a 7-chunk sequence with the long break *replacing* a short break. Under the fix the long break is 30 min and additive — sequence length and indices both change. |
| `BREAK-01: mood=2 ...every 3 work chunks` | 1878-1921 | Same shape — asserts 25-min long break replacing the short break at a fixed index; becomes a 5+30 pair under the fix. |
| `BREAK-01: mood=3 ...every 4 work chunks (baseline unchanged)` | 1923-1963 | Same shape. |
| `BREAK-01: mood=4 ...every 4 work chunks` | 1965-2000 | Same shape. |
| `BREAK-01: mood=5 ...every 5 work chunks` | 2002-2033 | Same shape. |
| `BREAK-02: only 5-min short breaks and 25-min long breaks are ever emitted, at every mood` | 2042-2103 | Directly asserts `longBreak.durationMinutes == 25` for every mood (line ~2078) — this is defect 1's exact inverse; will fail the moment defect 1 is fixed. Also asserts `result.last.chunkType == ChunkType.work` for every mood (line ~2098) — will fail whenever a run happens to land a cadence boundary on the last chunk, once STEP E is narrowed. |
| `a 15:42 floor starts the chunk at 15:45 (rounded up to 5), not 8 AM` | ~1399-1412 | Directly pins the 5-minute (not 30-minute) rounding behavior this research flags as LATTICE-01 gap #1. Expected value must change from `945` to `960` (16:00) once the rounding is fixed to 30-minute boundaries. |

**Estimated total: ~10 existing tests require rewriting** (not a full-suite rewrite). The remaining
~552 tests are either generator tests that never reach a cadence boundary within the chunk counts
they construct (verified: Tests 10-13, WR-02, WR-03, TONE-01 A/B, T-09-*, CAP-01, PRIORITY-02,
FILL-01/02, VSCHED-*, CR-01, the one-off-commitment group — all use ≤3 discretionary chunks against
N≥2, or explicitly assert commitment-only behavior with no discretionary chunks at all) or belong to
unrelated screens/providers untouched by this phase. `[VERIFIED: codebase — read every test in the
file and cross-checked chunk counts against each mood's N]`

**This confirms and extends CONTEXT.md's own instruction** to prove new regression tests RED first
(the project's established convention per STATE.md's "Regression tests must be proven RED" carry-
forward invariant) — the planner should also expect these ~10 pre-existing tests to go RED as a
*direct, intended consequence* of the fix, not as an unplanned regression, and rewrite their
expected values/sequences rather than treating a RED run as a signal something else broke.

## Common Pitfalls

### Pitfall 1: Fixing defect 1 in isolation (bump 25→30) without fixing defect 2
**What goes wrong:** `BREAK-02`'s duration assertion goes green, but the long break still replaces
the short break — a cycle at N=4 becomes `4×25 + 3×5 + 30 = 145`, still off-lattice (should be
`4×30 + 30 = 150`), and the Nth chunk's own 25/5 cell is still missing its short break.
**Why it happens:** The two defects live in the same one-line expression
(`breakDur = isLong ? 25 : 5`), making it tempting to treat as one fix.
**How to avoid:** Treat defects 1 and 2 as one combined change (`5 + (isBoundary ? 30 : 0)`, see
Architecture Patterns above) — never touch the `25` in isolation.
**Warning signs:** A "fixed" test suite where `BREAK-01`'s sequence-length assertions still pass
unchanged — that means the sequence shape didn't change, which means defect 2 wasn't actually fixed.

### Pitfall 2: Fixing defect 3 in the packing loop but leaving STEP E's trim untouched
**What goes wrong:** Reproduces defect 3 by a different mechanism — see "The Three Defects,
Verified" addendum above. The single most important non-obvious finding in this research.
**How to avoid:** Narrow STEP E to trim only `ChunkType.shortBreak`, never `ChunkType.longBreak`
(see Architecture Patterns above).
**Warning signs:** `Test 6`/`Test 7`-shaped scenarios (a day whose total discretionary chunk count
is an exact multiple of N) still show no long break in the final `result` after the "fix."

### Pitfall 3: Treating the mood-cap/window arithmetic as requiring a cap or day-end change
**What goes wrong:** Moving `_moodCap` down "to be safe" without doing the arithmetic first
unnecessarily reduces how much work every user's day can hold, for a squeeze that (per this
research) does not occur under nominal conditions.
**How to avoid:** Use the table in "The Capacity Squeeze, With Numbers" — the nominal-window slack
is 455+ minutes at every mood; no cap change is arithmetically justified for the general case.
**Warning signs:** A plan task that changes `_moodCap` values without a `startFloorMinutes`- or
commitment-heavy test case demonstrating an actual overflow.

### Pitfall 4: Assuming `reservedBreakMinutes >= 25` (today's threshold) still means "long break" after the fix
**What goes wrong:** Once the reservation encodes a *footprint* (5 or 35) rather than a single
break duration, any code still checking `reserved >= 25` will misclassify a 35-minute footprint or
fail to decode it into two separate break chunks.
**How to avoid:** Replace the threshold check entirely with the decode-into-one-or-two-chunks logic
shown in Architecture Patterns; do not patch the existing `>= 25` comparison in place.
**Warning signs:** A single break chunk emitted with `durationMinutes: 35` in test output — that is
the footprint leaking through undecoded, not two separate 5-min/30-min chunks.

### Pitfall 5: Only fixing `startFloorMinutes` rounding (gap #1) and missing the post-commitment slot rounding (gap #2)
**What goes wrong:** LATTICE-01 appears satisfied in isolated `startFloorMinutes` tests but a
schedule with any commitment block whose end isn't on a 30-minute boundary still produces
off-lattice discretionary chunks for the rest of that slot.
**How to avoid:** Fix both entry points identified above — they are independent code paths
(`generate()`'s `dayStart` derivation vs. `_assignSyntheticStartTimes`'s free-slot computation).
**Warning signs:** A test asserting `chunk.syntheticStartMinutes % 30 == 0` passes for
`startFloorMinutes` scenarios but fails for a commitment-block scenario with an odd `endMinutes`.

## Code Examples

### Verified LATTICE-01 assertion shape (recommended for the new regression test)

```dart
// New assertion the plan should add — per CONTEXT.md's own stated acceptance test:
// "generate a day at each mood, and check every chunk's start minute is ≡ 0 (mod 30)".
for (final chunk in result) {
  final start = chunk.displayStartMinutes; // unified getter, scheduled_chunk.dart:71
  if (start != null) {
    expect(start % 30, 0, reason: 'chunk at $start is off-lattice');
  }
}
```
Note: per the scoping question above, this should likely be scoped to
`chunk.anchoredStartMinutes == null` (discretionary chunks only) unless the planner explicitly
decides LATTICE-01 also constrains commitment-anchored chunks.

### Verified LATTICE-02 assertion shape

```dart
// "exactly floor(chunks / N) long breaks of exactly 30 minutes are emitted" — CONTEXT.md's own
// stated acceptance test, directly computable from the existing chunk count + cadence table.
final workCount = result.where((c) => c.chunkType == ChunkType.work).length;
final longBreaks = result.where((c) => c.chunkType == ChunkType.longBreak).toList();
expect(longBreaks.length, workCount ~/ longBreakEvery);
for (final lb in longBreaks) {
  expect(lb.durationMinutes, 30);
}
```

## State of the Art

Not applicable in the usual "framework version drift" sense — this is a bug fix to in-house
deterministic logic with no external dependency to be current or stale against. The one relevant
"state of the art" fact: the file's own doc comments (lines 21-23, 615-621) already encode the
project's established engineering discipline for this exact class of bug (single source of truth
for cadence state, WR-01's "packing and emission cadence counters cannot diverge" rule) — the fix
should extend that existing discipline, not introduce a second one.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | LATTICE-01 applies only to discretionary (synthetic) start times, not commitment-anchored ones | "Where an Off-Lattice Minute Can Enter", item 3 | If the owner actually wants LATTICE-01 to also govern how commitment blocks display/interact with the grid, the fix scope is larger — but ROADMAP.md's phase boundary ("Engine-side only... does not touch... any timeline widget") and the owner's own model description (framed entirely around discretionary work/break rhythm) both support this reading. Flagged explicitly for the planner/discuss-phase to confirm rather than silently assumed as locked. |
| A2 | Narrowing STEP E's trim to short-breaks-only (letting a trailing long break survive) is the correct interpretation of "never silently suppressed" | Architecture Patterns, "Narrow STEP E's trim to short breaks only" | If the intended behavior is instead "don't suppress the long break unless it's literally the last chunk of the day" (i.e., keep some trim), the recommended STEP E change is wrong and needs a different rule. The literal text of LATTICE-02 ("never silently suppressed") supports the recommendation, and it directly resolves the exact case CONTEXT.md names as "very likely the whole of 'isn't functioning right.'" |
| A3 | Rounding a post-commitment free-slot start up to the next 30-minute boundary (losing up to 29 "dead" minutes) is preferable to leaving discretionary chunks off-lattice after a commitment | "Where an Off-Lattice Minute Can Enter", item 2 | This is a genuine, named trade-off (a small idle gap vs. a lattice violation) rather than a pure bug fix — the planner should confirm this is the desired resolution rather than, e.g., shifting the commitment's own display instead (out of scope) or accepting the drift. |

## Open Questions

1. **Does LATTICE-01 apply to commitment-anchored chunks, or only discretionary ones?**
   - What we know: commitment `anchoredStartMinutes` is set directly from user-entered
     `block.startMinutes`/`block.endMinutes`, never rounded, and the phase is explicitly
     engine-side/no-UI. The owner's model describes only the discretionary work/break rhythm.
   - What's unclear: whether "every chunk starts on :00 or :30, always" (ROADMAP.md's literal
     phrasing) was meant to include commitments, which by nature can't be moved to fit a grid.
   - Recommendation: scope LATTICE-01 to discretionary chunks only (Assumption A1); confirm with
     the owner if the planner wants certainty rather than a documented assumption.

2. **Should the post-commitment free-slot rounding (gap #2) be in this phase's scope, given it's
   inside the exact method (`_assignSyntheticStartTimes`) this phase already modifies for defects
   1-3?**
   - What we know: it is the highest-impact of the three off-lattice entry points (cascades for
     the rest of a slot, not just one chunk) and lives in the same function.
   - What's unclear: whether the owner considers "day with a commitment block" in scope for this
     phase's acceptance test, or whether it's being deferred alongside "any UI work."
   - Recommendation: include it — it is squarely inside `schedule_generator.dart`, costs one
     rounding operation, and leaving it out would mean LATTICE-01 does not actually hold for any
     day containing a commitment whose end isn't already on a 30-minute boundary, which is a
     realistic scenario CONTEXT.md's own phase goal ("every chunk starts on :00 or :30, always")
     seems to intend to close.

3. **Does any downstream widget (ScheduleProgressBar, chunk_card.dart, TimelineGeometry) implicitly
   assume the old "one break per work chunk" cardinality, now that a cadence-boundary work chunk
   can be followed by two break chunks instead of one?**
   - What we know: `grep` found no cadence-specific logic in the presentation layer (breaks are
     rendered generically by `ChunkType`); `ScheduleProgressBar` counts `completed`-of-`total`
     across all chunks generically per STATE.md's Phase 23 note (G-06).
   - What's unclear: this was verified by code reading, not by running the app with a fixture that
     actually produces two consecutive break chunks (short then long) — no such fixture exists
     anywhere in the current test suite, since it's never been possible before this fix.
   - Recommendation: a quick `flutter test`/manual smoke check after the fix (rendering a day with
     a visible short+long break pair) is worth doing even though the phase boundary excludes UI
     *changes* — verifying no UI *breakage* is a reasonable connectedness check, not scope creep.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | `flutter test`, `flutter analyze` | ✓ | 3.44.1 (stable) | — |
| Dart SDK | pubspec `sdk: ^3.10.3` | ✓ | 3.12.1 | — |
| Existing test suite | Regression baseline | ✓ | 567 tests, all green, `flutter analyze` clean (verified 2026-08-19) | — |

No missing dependencies. Flutter lives at `/home/dan/development/flutter/bin` (not on default
shell PATH in non-login/non-interactive shells — add explicitly, per this project's own
`CLAUDE.md`/danserver environment notes).

## Validation Architecture

Per CONTEXT.md and ROADMAP.md's own explicit instruction, this phase is **fully testable in
`flutter test`** — integer arithmetic over minutes, no glyph metrics, no browser step required.
This is a genuine, stated difference from Phase 27 (True Grid), which needed real-browser pixel
measurement because its grid was verified against itself; that ceremony must not be copied here.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK 3.44.1) |
| Config file | none — standard `flutter test` discovery over `test/` |
| Quick run command | `flutter test test/services/schedule_generator_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LATTICE-01 | Every chunk's `displayStartMinutes % 30 == 0`, for every mood, with and without commitment blocks and with a mid-day `startFloorMinutes` | unit | `flutter test test/services/schedule_generator_test.dart -x` | ✅ file exists; ❌ new assertion group — Wave 0 |
| LATTICE-02 | `floor(workCount / N)` long breaks emitted, each exactly 30 min, for every mood; never zero when `workCount >= N`, including when the boundary chunk is the day's last | unit | `flutter test test/services/schedule_generator_test.dart -x` | ✅ file exists; ❌ new assertion group — Wave 0 (existing `BREAK-01`/`BREAK-02`/Test 6/Test 7 tests must be rewritten, not just supplemented — see Blast Radius) |

### Sampling Rate

- **Per task commit:** `flutter test test/services/schedule_generator_test.dart` (single file,
  fast — the full file ran in well under a second in this research's baseline run)
- **Per wave merge:** `flutter test` (full suite; baseline 567 tests, ~17s in this research's run)
- **Phase gate:** Full suite green before `/gsd-verify-work`; also run `flutter analyze` (baseline:
  clean, 2026-08-19)

### Wave 0 Gaps

- [ ] New assertion group in `test/services/schedule_generator_test.dart` asserting the mod-30
      invariant across all 5 moods (LATTICE-01) — no such test exists today.
- [ ] New assertion group asserting `floor(workCount / N)` long breaks of exactly 30 min, across
      all 5 moods, including a fixture where the boundary chunk is the day's literal last chunk
      (reproducing "the exact day the owner was looking at") — no such test exists today.
- [ ] Rewrite (not delete) the ~10 tests named in "Blast Radius" — their expected sequences/values
      must be updated to the new lattice shape, proven RED against the unfixed code first per this
      project's own "Regression tests must be proven RED" carried-forward convention (STATE.md).
- [ ] Optional smoke check (Open Question 3): render one day with a visible short+long break pair
      in the existing widget-test harness to confirm no downstream cardinality assumption breaks —
      not a new automated gate, a one-time manual/exploratory check.

No test framework installation is needed — `flutter_test` is already fully wired and in active use
(567 passing tests today).

## Security Domain

**Not applicable in any meaningful sense.** This phase changes pure internal arithmetic over
already-validated in-memory data (`moodIndex` 1-5, already guarded by a debug-only `assert` at
`schedule_generator.dart:234`; `goals`/`blocks`/`completionLogs`, all already loaded from the
app's own Hive boxes, not external/untrusted input). There is no new input surface, no
authentication, no session, no network call, no cryptography, and no change to what data is
persisted (the field carrying cadence state is explicitly non-persisted). ASVS categories V2–V6
do not meaningfully apply to a same-process, no-network, no-auth arithmetic fix.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A — no auth surface touched |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A |
| V5 Input Validation | marginal | `moodIndex` is already guarded by an `assert` + `?? 4` fallback pattern (existing code, unchanged by this phase) |
| V6 Cryptography | no | N/A |

## Sources

### Primary (HIGH confidence — direct codebase verification, this session)

- `lib/services/schedule_generator.dart` (761 lines) — read in full; all line references above
  point at this file as read 2026-08-19.
- `lib/data/models/scheduled_chunk.dart` — read in full; confirms `reservedBreakMinutes` is not a
  `@HiveField`.
- `test/services/schedule_generator_test.dart` (2165 lines, 62 tests) — read in full.
- `test/defer_carryover_test.dart`, `test/commitment_attribution_test.dart`,
  `test/providers/schedule_notifier_add_event_test.dart`,
  `test/screens/cold_launch_morning_loop_test.dart`,
  `test/screens/today_screen_now_state_test.dart` — `grep`'d and spot-read to rule out cadence
  dependence.
- `flutter test` (full suite, 567 tests) and `flutter test
  test/services/schedule_generator_test.dart` (62 tests) — both run this session, both green.
- `flutter analyze` — not re-run in isolation this session but confirmed clean as of the same
  commit per `STATE.md`'s own record (`0cba546`, "567 tests green, `flutter analyze` clean").
- Python simulation of `_assignSyntheticStartTimes`'s packing loop, cross-checked line-by-line
  against the Dart source, run this session for "The Capacity Squeeze, With Numbers."
- `.planning/phases/28-the-day-is-a-lattice/28-CONTEXT.md`, `.planning/ROADMAP.md` (Phase 28
  section), `.planning/STATE.md` — read in full this session.

No external documentation lookup was performed — this phase introduces no new library, framework,
or API; all findings are direct codebase verification, appropriately the only source type this
phase requires. No `research-plan`/provider fetch was invoked because there was no external
question to answer (all three configured search providers were also unavailable in this session's
init context: `brave_search: false, firecrawl: false, exa_search: false`).

## Metadata

**Confidence breakdown:**
- Defect verification (1, 2, 3 + STEP E interaction): HIGH — read against the literal source, line
  numbers cited, cross-checked against every relevant existing test.
- Capacity arithmetic: HIGH — directly simulated the packing algorithm's actual loop structure
  against the actual constants in the code, not estimated.
- LATTICE-01 entry-point findings: HIGH for gaps #1 and #2 (read directly, existing test
  `[VERIFIED]`s gap #1's current wrong behavior); MEDIUM for the scoping question in gap #3 (a
  legitimate open question, not a defect, marked as Assumption A1).
- Blast radius: HIGH — every test in the file was read, not sampled; the "unaffected" tests were
  individually checked against their own discretionary chunk counts vs. each mood's N.

**Research date:** 2026-08-19
**Valid until:** No external dependency to go stale — valid until the underlying
`schedule_generator.dart` file changes for reasons other than this phase (i.e., effectively
until this phase lands).
