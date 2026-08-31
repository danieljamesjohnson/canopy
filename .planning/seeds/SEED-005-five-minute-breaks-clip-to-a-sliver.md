# SEED-005 — A 5-minute break renders as a 20dp sliver and reads as a divider

**Raised:** 2026-08-20, by the owner, during Phase 28 UAT on `danserver:8142`
(fresh origin, new day, so this is not stale serialized data).

**Report, verbatim:** "when i click 8142 there's no 5 minute breaks in between."

## What's actually happening

The breaks are there. The engine is correct — this is a *rendering* problem, and it is
**pre-existing, not a Phase 28 regression**. Phase 28 touched exactly one file
(`lib/services/schedule_generator.dart`); `timeline_geometry.dart` and `chunk_card.dart` were last
changed in Phase 27.

Probed the real generator on a 4-habit onboarding day: every mood emits its short breaks on the
lattice, e.g. mood 4 →

```
08:00 work 25min   08:25 shortBreak 5min   08:30 work 25min   08:55 shortBreak 5min
09:00 work 25min   09:25 shortBreak 5min   09:30 work 25min   09:55 shortBreak 5min
10:00 longBreak 30min
```

Then rendered that day through the real `ChunkCard` / `TimelineRowTile` / `TimelineGeometry` with
today_screen's own PD-10 `ClipRect` + `OverflowBox` wrapper:

| chunk | slot | natural height | result |
|---|---|---|---|
| work 25min | 100dp | 126dp | clipped 26dp |
| **shortBreak 5min** | **20dp** | **52dp** | **clipped 32dp — only 38% survives** |
| longBreak 30min | 120dp | 80dp | fits |

Without the `ClipRect`, the same render throws **four** RenderFlex overflow errors — one per short
break. In production the ClipRect swallows the error and silently clips instead, which is why this
has never surfaced as a crash or a log line.

So a 5-minute break paints only the top ~20dp of its dashed card: the top edge of the outline and a
sliced-off label. Between two 100dp work cards that reads as a **divider**, not as a break. The
30-minute long break, at 120dp, renders correctly — which is why the long break is visible and the
short ones are not.

**Caveat on the "natural height" column:** `flutter test`'s placeholder font inflates glyph metrics
(STATE.md carry-forward invariant), so 52dp and 126dp are harness bounds, not device requirements.
The **slot** heights are pure arithmetic (`durationMinutes × kPixelsPerMinute`, `kPixelsPerMinute =
4.0`) and are exact. The qualitative conclusion is safe either way: a card with a label row and
padding cannot fit in 20dp.

## The tension this sits on

This is the direct cost of Phase 27's decision (GRID-01): slots are **duration-exact**, so an hour
is always an hour. A 5-minute chunk is therefore *always* 20dp. Phase 27 solved this for the live
row by giving `LiveRowCard` density tiers driven by slot height — but the **non-live** break card
never got the equivalent treatment. `kFullBreakMinHeight = 88.0` picks `compact` for a 20dp break,
and compact still needs more than 20dp.

Any fix has to not re-break the true grid. Options, roughly cheapest first:

1. **A sub-compact tier for short chunks** — below ~24dp, render the break as a single centered
   hairline-with-label rather than a card. Matches Phase 27's own precedent (tiers driven by slot
   height) and keeps the grid exact.
2. **Render short breaks as the gap between work cards** rather than as a card — i.e. the break is
   the visible space, with the label only on hover/tap. Cheapest, but loses the "you're on a break"
   affordance the Phase 27 spike explicitly valued.
3. **Raise `kPixelsPerMinute`** so 5 minutes buys more room (at 8.0 a break is 40dp). Doubles the
   day's scroll length — Phase 27 fought hard to make the day *shorter*, so this trades directly
   against that.

Option 1 is the recommendation; 3 is the one to avoid without new evidence.

## Not yet decided

Whether this is worth a phase at all. It is cosmetic in the sense that the schedule is correct and
the times are right — but the whole point of Phase 28 was the owner being able to *see* the 25/5
rhythm, so a break you cannot see arguably defeats it. Owner's call.

---

## HARVESTED — 2026-08-31

**Closed by four phases, because the first three fixes each turned out to be the wrong shape.**

- **Phase 29 (Breaks You Can See)** gave the 20dp break a sub-compact hairline-with-label tier so
  it stopped reading as a divider — the literal fix for this seed as written.
- **Phase 31 (Breaks You Can Skip)** made it skippable via swipe with an invisible 68dp hit band.
  The owner's thumb failed it twice; the grip glyph turned out to mean the wrong verb.
- **Phase 32 (Breaks You Can Tap)** raised `kPixelsPerMinute` 4.0 → 6.0 so a 5-minute break is a
  real 30dp card with a visible Skip rail, and retired the swipe machinery outright.
- **Phase 32's gap closure** fixed what the scale change exposed: rows were sized by their content,
  not their duration, leaving ~67dp of dead space under every work chunk.

**Final state, measured not assumed:** a 5-minute break renders as a 30dp bordered card with a
64×30dp visible Skip rail, and the owner's thumb skipped **5 of 5** on 2026-08-31 (`32-UAT-R2.md`).

**The durable lesson is not about breaks.** This seed took four phases because the first three were
reasoned about in arithmetic and never looked at — the fix that finally worked came from serving
three whole-screen mockups and having the owner pick one (`sketches/002-timeline-at-6/`).

**No open work. This seed is closed.**
