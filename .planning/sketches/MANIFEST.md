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
| 001 | unified-today | Within an inline timeline, how does "now" stay findable while the day stays scannable? | TBD | layout, today, live-state, phase-22 |
