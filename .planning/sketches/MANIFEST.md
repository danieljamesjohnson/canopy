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

## Locked Decisions

- **Inline timeline, no separate now-card** — the day is one list; the current row swells into a
  live card in place and auto-centres on open. (Sketch 001, variant A.)
- **Countdown granularity** — whole minutes until under one minute remains, then seconds.
  Settles LIVE-02. (Sketch 001 review, 2026-08-07.)
- **Free time is named** — "Free until 8:00am", "Free · 1h 40m" — never collapsed to whitespace.
- **Breaks are a first-class current activity** — a running break names itself and offers no
  Complete/Skip affordance, because there is nothing to complete.
