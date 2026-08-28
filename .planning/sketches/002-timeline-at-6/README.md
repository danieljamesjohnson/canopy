---
sketch: 002
name: timeline-at-6
question: "How should a card occupy a duration-exact slot it under-fills by ~67dp?"
winner: null
tags: [layout, today, timeline, breaks, phase-32]
---

# Sketch 002: The timeline at 6.0 px/min

## Design Question

Phase 32 raised `kPixelsPerMinute` 4.0 → 6.0 (D-32-01) so a 5-minute break would stop being a
hairline. It worked. It also made the whole screen look worse, and the owner said so on
2026-08-28: *"there's huge gaps and the long break has too big of a skip. this should all be
designed to be pretty."*

**The gaps are not a styling problem.** `today_screen.dart:840` wraps every row in
`OverflowBox(alignment: Alignment.topCenter, maxHeight: infinity)` — the card lays out at its
**natural** height and is top-aligned inside the slot. A 25-minute work card is ~83dp of content
in a 150dp slot, so ~67dp of dead background trails every work chunk. At 4.0 the same mechanism
left ~17dp and read as ordinary card spacing. **D-32-01 didn't create this; it made a
pre-existing flaw visible everywhere at once.**

So the real question is the one nobody asked before shipping: **what is a card supposed to do
with a slot taller than its content?**

## How to View

    http://danserver:8102/002-timeline-at-6/index.html

Or locally: `open .planning/sketches/002-timeline-at-6/index.html`

## Variants

- **A: Filled calendar** — the card stretches to its slot, actions pinned to the bottom. The
  67dp hole becomes card. Reads as solid blocks of time; the only white left is time that is
  genuinely free. Path of least resistance in Flutter (`OverflowBox` → stretch).
- **B: Spine** — cards keep their natural height, but a continuous rail down the left carries
  the duration, so leftover slot reads as *time passing* rather than a hole. Breaks shrink to a
  pill on the rail. Smallest change to the current look; least calendar-like.
- **C: Adaptive fill** — fills the slot like A, but the content responds to the height it gets:
  a 150dp work chunk earns a bigger title and a goal line, a 30dp break stays one line, and the
  180dp long break turns its rail into a centred pill.

## Controls in the sketch

- **px/min toggle (4.0 / 5.0 / 6.0)** — the important one. D-32-01 was argued in arithmetic and
  never looked at. Flip between 4.0 and 6.0 in each variant and judge the trade directly.
- **Mood 1 / 3 / 5** — the locked `ColorScheme.fromSeed` seeds, since break fills are
  `secondaryContainer` and change with mood.
- **Tap any Skip** — it actually resolves the break, so the skipped state is judgeable too.

## Grounding — what is real here and what is not

**Real:** every row is absolutely positioned at `(start − dayStart) × ppm` and is exactly
`duration × ppm` tall, the same rule `timeline_geometry.dart` enforces — **no variant is allowed
to buy a better look by making a row lie about its duration.** The day is the real generator's
output for mood 3 (`longBreakEvery = 3`, work always 25 min, short break 5, long break 30,
and the boundary shape where a short break is immediately followed by a long one).
Constants are real: gutter 40dp, row inset 16dp, `kFullBreakMinHeight` 88dp.

**Not real:** Flutter's exact Roboto metrics. The ~83dp natural work-card height is measured off
the shipped build's own screenshot, not computed.

## What to Look For

1. **Does A's filled card read as calm, or as hollow?** This is the honest cost of A and C: at
   150dp the card is filled, but the middle is empty and the actions float at the bottom. It
   removes the gap between cards by moving it *inside* the card. Whether that's better is
   exactly the judgment call this sketch exists to get.
2. **Does B's spine actually make the whitespace feel intentional** — or is it still just the
   gap you complained about, with a line next to it? B is the variant most likely to fail on
   your original complaint.
3. **The long break's Skip.** A gives it a fixed 64×44 pill on the right edge; C gives it a
   centred 120×40 pill; B reduces it to a small outline button on a pill row. All three exist
   because the shipped full-height 64dp `errorContainer` slab was rejected. None of them is red
   any more — check whether losing the error colour loses the meaning.
4. **4.0 vs 6.0 with your own eyes.** If 6.0 still looks wrong once the gaps are handled, that
   is worth knowing now — but note that dropping back to 4.0 returns the 5-minute break to 20dp,
   the hairline Phases 29 and 31 both existed to remove.

## Finding before you even look

**A defect was caught in this sketch and fixed before it was served, and it is worth recording
because the shipped app may have the same one.** At every cadence boundary the generator emits a
short break *immediately followed by* a long break (`schedule_generator.dart:247` reserves
`5 + 30`). In the first draft of variants A and C both filled with the same flat
`secondaryContainer` and shared an edge — so 10:25→11:00 rendered as **one indistinct green mass
with two floating Skip buttons**, with no way to see where one break ended and the other began.
Fixed here by giving each break its own border and shading the long break a step deeper.

This is a guaranteed shape, not an edge case — it happens every third chunk on a steady day.
**Worth checking whether the shipped build has the same problem**, since it has the same flat
fill and the same adjacency; nobody has looked at that pair on a real device.
