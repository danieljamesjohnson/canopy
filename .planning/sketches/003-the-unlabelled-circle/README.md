---
sketch: 003
name: the-unlabelled-circle
question: "What should an unresolved work row show where the unlabelled circle is now — and should free time stay dashed while breaks are filled cards?"
winner: "B"
tags: [today, timeline, chunk-card, legibility, phase-33]
---

# Sketch 003: The unlabelled circle

## Outcome — ★ Variant B wins, and free time becomes FILLED (Dan, 2026-09-01)

**B · Says its state.** One vocabulary, three words — `To do` / `Done` / `Skipped`. No glyph on a
chunk row carries meaning on its own any more, which is the whole of OBVIOUS-01.

**A was not chosen, and the reason matters for the build:** deleting the circle would have removed
the *wrong* thing. The complaint was never "there is something on the right of the row", it was
"that something does not say what it is." B answers the complaint; A dodges it.

**C was rejected on a known failure shape** — it was the only variant that added a second way to
complete a chunk, and its tick is itself an unlabelled glyph. Phase 32 already spent a round
learning that two arrangements of one vocabulary is a defect.

**Free time: FILLED.** The Phase 22 match is restored — free time is a filled card like a break,
not a dashed outline. Unscheduled time being visibly *yours* is part of the product's promise, and
an outline reads as absence. The locked copy is unchanged: `Free until 8:30 AM` / `Free · 1h 5m`.


## Design Question

`chunk_card.dart:769`, inside `_buildTrailingStatus()`. Every **unresolved** work row renders
`Icon(Icons.radio_button_unchecked)` in `onSurfaceVariant`. The same method renders
`Icons.check_circle` when the chunk is completed and the word `skipped` when it is skipped — so the
two resolved states say what they are, and the unresolved state does not.

Dan, verbatim, **2026-06-12**: *"there's a little circle next to it — really unclear UI for a
human."*

It looks tappable. It is not. It sits inches from a labelled **Complete** button that does exactly
the job it appears to offer. It has been on screen for **2.5 months** — not because it is hard, but
because no phase since has aimed at it.

**So: is it a control, a status glyph that earns its place, or nothing?**

Riding along, because it is the same judgment at the same altitude: **free time still renders as a
dashed outline while breaks are now filled cards.** Phase 22 deliberately made them match; Phase 32
pulled them apart and the divergence is more visible at 6.0 px/min. There is a Dashed / Filled
toggle in the toolbar that applies to every variant.

## How to View

    http://danserver:8103/003-the-unlabelled-circle/index.html

Or locally: `open .planning/sketches/003-the-unlabelled-circle/index.html`

## Variants

- **A: Nothing** — delete the glyph on unresolved rows outright. State is carried by the fact that
  **Complete** and **Skip** are still there to press; resolved rows keep their check and their
  `skipped`. Smallest diff by a distance — it is a deletion.
- **B: Says its state** — one vocabulary, three words: `To do` / `Done` / `Skipped`. No glyph
  anywhere carries meaning on its own. Display-only; nothing about the chip invites a tap.
- **C: A real checkbox** — the circle stays and finally does something. 40dp tap target, tick to
  complete, and the now-redundant **Complete** button comes off the tall card, leaving **Skip**.
- **As shipped** — the reference column. What is on screen today.

## What to Look For

1. **Scroll the whole day in A before judging it.** A is a deletion, and deletions are easy to
   approve in the abstract and regret at altitude. The honest question is whether a column of work
   cards with nothing on the right still reads as *unfinished*, or just as cards.
2. **Count the chips in B.** Three visible `TO DO` chips in one screen is three more things
   competing with the goal name. Naming the state is only worth it if the name is worth saying —
   check whether "To do" states the obvious.
3. **C is the only variant that adds a second way to complete a chunk.** Phase 32 spent a round
   discovering that two arrangements of one vocabulary is a defect. Tick a card, then look at the
   150dp cards and decide whether losing the labelled **Complete** is a trade you want — a tick
   is faster, but it is also unlabelled again, which is the complaint this sketch exists to answer.
4. **Dashed vs Filled on free time, at the top and bottom of the day.** The 8:00–8:30 block and the
   11:25 block are the two real cases. Dashed says "nothing is here"; filled says "this is yours."
   Note that the copy is locked either way (`Free until 8:30 AM` / `Free · 1h 5m`) — only the
   treatment is open.

## Grounding — what is real here and what is not

**Real:** every row is absolutely positioned at `(start − dayStart) × 6.0` and is exactly
`duration × 6.0` tall — `kPixelsPerMinute = 6.0`, the rule `timeline_geometry.dart` enforces. A
25-minute work chunk is 150dp, a 5-minute break 30dp, a 30-minute long break 180dp. The goal/duration
line appears only above `kRoomyWorkMinHeight` (120dp), as it does in the shipped build. The day is
the real generator's shape for mood 3 — work 25, short break 5, a long break every third chunk,
and the boundary pair where a short break is immediately followed by a long one. The completed and
skipped rows are there so all three states can be compared in one screen rather than described.

**Not real:** Flutter's Roboto metrics, and the short break's rail is drawn at its measured 64×30dp
but is not under test here — **D-32-03 is settled at 5/5 and this sketch must not reopen it.**
