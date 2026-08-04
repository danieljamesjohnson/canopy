---
sketch: 001
name: unified-today
question: "Within an inline timeline, how does 'now' stay findable while the day stays scannable?"
winner: null
tags: [layout, today, live-state, phase-22]
---

# Sketch 001: Unified Today Screen

## Design Question

Phase 22 merges Home and Schedule into one screen. Dan chose the **inline** direction —
no separate hero card; the day is one list and the current row is the alive thing — and
**named free time** ("Free until 8:00") rather than collapsed whitespace.

That settles the shape but leaves the risk inline carries: *"now" can scroll off.* These
variants differ in how they answer that.

## How to View

    open .planning/sketches/001-unified-today/index.html

Or served over the tailnet: `http://danserver:8101/001-unified-today/index.html`

## Variants

- **A: Pure inline** — one list, nothing sticky. The current row swells into a live card in
  place, and the list auto-scrolls it to centre on open. Quietest; trusts the scroll position.
- **B: Sticky recall** — identical list, plus a pill that slides down *only* when the live row
  scrolls out of view. Tap it to jump back. Costs a floating element that's usually absent.
- **C: Time rail** — a time gutter and a vertical rail down the left. Done segments fill,
  the current segment carries a progress line, free time is a dashed rail. Most structural;
  reads as a real timeline rather than a list of cards.

All three share: a **live countdown ticking in real seconds**, named free time, struck-through
completed chunks, a skipped chunk (9:00), an anchored commitment block, and the four states
(before 8am / on a break / mid-chunk / day done) plus the three mood palettes.

## What to Look For

1. **Does the seconds countdown feel calm or anxious?** This is the open LIVE-02 decision the
   roadmap deliberately left for phase planning — per-minute is cheaper and quieter, per-second
   is alive. Judge it here rather than in code.
2. **"Taking a break" as a first-class state** — a break names itself and offers no
   Complete/Skip buttons, because there's nothing to complete. Check that reads right.
3. **Whether the rail (C) earns its width** — 68px of gutter and rail buys structure; on a
   phone that's real estate taken from the activity names.
4. **The empty states** — hit "Before 8am" and "Day done". "Nothing until 8:00am — the time
   is yours" is the tone check for the no-nagging requirement (TONE-01).

## Finding before you even look

With a normal steady day at phone height, the whole timeline nearly fits — so the live row
rarely scrolls out of view and **B's recall bar seldom fires**. It earns its keep on long
(sunny, 11-chunk) days and short viewports, not on typical ones. If B wins it should be for
the long-day case specifically, not as general insurance.
