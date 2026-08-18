# Spike Manifest

## Idea

Phase 27, "True Grid": make every hour on the Today timeline occupy the same
vertical distance, always. The blocker was never the deletion — `yFor()`'s
`liveExtraPx` term is one line — it was the tension the term exists to serve.
CAL-01 grants exactly one named exception, "let now break the grid," and a
25-minute slot is 100dp while the shipped live card needs ~200dp. A true grid
and a variable-height live row cannot both hold. These spikes decide which.

## Requirements

Design decisions that emerged from spiking. Non-negotiable for Phase 27's build.

- **The live row obeys the grid.** `liveExtraPx` is deleted; the live chunk
  takes a duration-exact slot like every other row. (Spike 001)
- **The live row stays actionable.** Complete and Skip must remain reachable
  while a chunk is live. Any treatment that clips them away is rejected —
  this is what killed variant (b). (Spike 001)
- **The live row uses the same slot-height-picks-density rule as every other
  row.** No new concept: a compact tier above the threshold, a single-line tier
  below it, exactly as `kFullTierMinHeight` already works. A live 5-minute
  break gets 20dp and must still say it is a break. (Spike 001)
- **Grid uniformity is verified in pixels, never in `flutter test`.** 240dp and
  372dp both satisfy all 560 existing tests, because the tests check `yFor()`
  against the implementation's own arithmetic. (Spike 001)

## Spikes

| # | Name | Type | Validates | Verdict | Tags |
|---|------|------|-----------|---------|------|
| 001 | live-row-in-a-true-grid | comparison | Given a duration-exact 100dp live slot, when the live card is compacted (a) vs. left to clip (b), then one keeps the row prominent AND actionable with every hour equidistant | **a ✓ WINNER · b ✗ INVALIDATED** | flutter, layout, today-timeline, phase-27, ui |
