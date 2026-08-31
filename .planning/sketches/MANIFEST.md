# Sketch Manifest

## Design Direction

Canopy's Today screen should read as **one continuous day you are currently inside of**, not a
dashboard about your day. The current activity is not a separate widget — it's the row you're
standing on, alive and counting down. Empty stretches are named as free time rather than hidden,
because unscheduled time being visibly *yours* is part of the product's promise (control over
your own time). Nothing on the screen reports a deficit; the schedule absorbs the catching-up.

Visual language inherits the app as built: Material 3, mood-seeded `ColorScheme.fromSeed`
(seeds locked in `theme_notifier.dart`, `1: #4A6275` … `5: #E8C547`), mobile-first with a 720dp
desktop constraint.

## Reference Points

None supplied — direction came from Dan's 2026-08-04 dogfood pass on the hosted debug build
and from the app's existing locked design tokens.

## Sketches

| # | Name | Design Question | Winner | Tags |
|---|------|----------------|--------|------|
| 001 | unified-today | Within an inline timeline, how does "now" stay findable while the day stays scannable? | **A · Pure inline** | layout, today, live-state, phase-22 |
| 002 | timeline-at-6 | How should a card occupy a duration-exact slot it under-fills by ~67dp? | **C · Adaptive fill** | layout, today, timeline, breaks, phase-32 |
| 003 | the-unlabelled-circle | What should an unresolved work row show where the unlabelled circle is now — and should free time stay dashed while breaks are filled? | _pending_ | today, timeline, chunk-card, legibility, phase-33 |
| 004 | goals-as-priority | How does the Goals screen say it IS the priority order, when identity colour is the loudest signal on the card? | _pending_ | goals, priority, legibility, phase-33 |
| 005 | restoratives-and-the-fork | How is adding a restorative one tap — and where does "energizing but not a goal" get decided? | _pending_ | restoratives, goals, energy-valence, entry-points, phase-33 |

## Locked Decisions

- **Inline timeline, no separate now-card** — the day is one list; the current row swells into a
  live card in place and auto-centres on open. (Sketch 001, variant A.)
- **Countdown granularity** — whole minutes until under one minute remains, then seconds.
  Settles LIVE-02. (Sketch 001 review, 2026-08-07.)
- **Free time is named** — "Free until 8:00am", "Free · 1h 40m" — never collapsed to whitespace.
- **Breaks are a first-class current activity** — a running break names itself and offers no
  Complete affordance, because there is nothing to complete. *(Amended by D-31-07: it does now
  offer **Skip**, Skip only. The no-Complete half stands.)*

- **A row fills its slot; its content adapts to the height** — a card is sized by its duration,
  never by its content, and the height it receives changes what it shows (a 150dp work chunk
  earns a goal line, a 30dp break stays one line). This retires top-aligned natural-height rows
  and the dead band they leave. (Sketch 002, variant C, 2026-08-28.)

- **A tall break's Skip is a centred pill, a short break's is a side rail** — one shape does not
  fit both tiers. Width is the only place a 30dp row can find touch area; a 180dp row has no such
  constraint and a full-height rail there reads as a slab. (Sketch 002, variant C.)

- **Two adjacent breaks must read as two** — every break carries its own border, and the long
  break is shaded a step deeper than the short one. The generator emits a short break immediately
  followed by a long one at every cadence boundary, so this pair is guaranteed, not an edge case.
  (Sketch 002, found while building.)
