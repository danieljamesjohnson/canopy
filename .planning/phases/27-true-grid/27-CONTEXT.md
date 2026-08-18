# Phase 27: True Grid - Context

**Gathered:** 2026-08-18
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Every hour on the Today timeline occupies the same vertical distance, always —
an hour is an hour, whatever is happening inside it.

**The defect.** `TimelineGeometry.yFor()` (`lib/screens/today/timeline_geometry.dart`)
is linear except for one term: `offset += liveExtraPx` once the minute passes
`liveEndMinutes`, where `liveExtraPx = kLiveRowReservedHeight − (liveDuration ×
kPixelsPerMinute)` = `232 − 100` = **132dp** for a standard 25-minute chunk. The
hour containing the live chunk's end therefore renders 372dp against every other
hour's 240dp. Exactly one hour per day is wrong, and only while a chunk is live.

Confirmed to the pixel by spike 001 (2026-08-18): hour-label centres measured
221.0 / 461.0 / 833.0 in a real browser — 240.0 then 372.0, spread exactly
132.0.

**Requirements:** GRID-01 (uniform hour spacing), GRID-02 (live-row prominence
without variable height).

**Depends on:** Phase 26 (The Day Has a Shape) — owns `TimelineGeometry` and the
now-line.

</domain>

<decisions>
## Implementation Decisions

Discuss was skipped, but this phase is **not** at Claude's discretion. The one
open question — what the live row becomes once its slot stops growing — was
settled ahead of planning by `/gsd-spike`, on real-browser evidence, and pinned
into the ROADMAP phase entry. **That entry is the spec. Read it before
planning:** `.planning/ROADMAP.md`, "Phase 27: True Grid" → "DECIDED — option
(a), on spike evidence (2026-08-18)".

### Settled — do not re-litigate

- **Option (a): the live card is compacted to fit its duration-exact slot.**
  Option (b) (delete the term and let the card clip) was built and measured and
  is **rejected on evidence**: it clips 110px off the card, slicing the
  countdown mid-glyph and deleting both Complete and Skip, so the current
  activity becomes the one row in the day you cannot act on. A live 5-minute
  break renders as 8px of blank fill with no text at all. Option (c)
  (won't-fix) is not on the table — the phase exists to fix this.
- **In-house, not `kalender`.** Settled 2026-08-18; flips only if
  drag-to-reschedule, week/multi-day views, or timezones enter scope.
- **The live row keeps its prominence through fill, square corners, elevation
  and the now-line** — CAL-01's exception survives in every respect except
  height. This is what Google Calendar does, now measured rather than asserted.

### Spike evidence available to planning

`.planning/spikes/001-live-row-in-a-true-grid/` holds the full trail: the
measured comparison table, `variants.patch` (the exact `lib/` diff all three
builds came from — an artefact for reference, **not** a patch to apply),
`tools/drive.cjs` (headless-Chromium driver), `tools/measure_hours.py` (the
pixel measurer), and 7 evidence screenshots including a three-up comparison.

</decisions>

<code_context>
## Existing Code Insights

- `lib/screens/today/timeline_geometry.dart` — `TimelineGeometry.forDay()`
  computes `liveExtraPx`; `yFor()` applies it. Deleting the term is the
  one-line part of this phase. Also holds `kLiveRowReservedHeight` (232.0),
  which becomes dead once the term goes, and `kFullTierMinHeight` /
  `kFullBreakMinHeight` (88.0), the slot-height-picks-density rule the live row
  must start obeying.
- `lib/screens/today/today_screen.dart` — the `ChunkRow` arm's `isLive` branch
  positions the live row with **no** `height:`, deliberately, so it can swell.
  Every non-live row uses `Positioned(height: slot)` + `ClipRect` +
  `OverflowBox`. The live row moves onto that same path.
- `lib/screens/today/widgets/live_row_card.dart` — `LiveRowCard`, currently
  ~198px of fill for the work variant. Gains density tiers.
- Tests: `test/screens/today_timeline_model_test.dart` pins
  `kLiveRowReservedHeight` (a `G-02` test asserts it stays within
  `[measured, measured+16]`) and several tests reference the constant. Those
  tests encode the behaviour being removed and must be updated, not worked
  around.

**Measurement discipline (three prior corrections say this matters).** Never
derive a layout constant from `flutter test` — its placeholder font has no real
Roboto metrics. This project has been burned three times: `kGutterWidth`
46→75→52, `kPixelsPerMinute` 4.0→5.5→4.0, `kLiveRowReservedHeight` 240→232.
Real browser or it does not count. Recipe in `CLAUDE.md` and
`.planning/spikes/CONVENTIONS.md`.

</code_context>

<specifics>
## Specific Ideas

Six concrete requirements, carried verbatim from the ROADMAP's DECIDED block:

1. Delete the `liveExtraPx` term from `TimelineGeometry` — `yFor()` becomes
   purely linear.
2. Render the live row through the same `Positioned(height: slot)` +
   `ClipRect`/`OverflowBox` path every other row uses.
3. Give `LiveRowCard` density tiers driven by slot height, as
   `kFullTierMinHeight` already does for `ChunkCard`. **Required, not
   optional** — a live 5-minute break has a 20dp slot and no single layout
   serves both 100dp and 20dp.
4. Re-derive the compact tier's minimum height **in a real browser**. The
   spike's `60.0` was a placeholder that was never validated; measured natural
   height is 90dp, so the threshold is ≥ 90.0. Decide deliberately what happens
   to live chunks in the 60–90dp band.
5. Consider dropping the progress bar from the compact tier — once the card is
   duration-exact, the now-line's position within it **is** the fraction
   elapsed, so the bar is a redundant second rendering, and the two overlap at
   the card's bottom edge late in a chunk.
6. Resolve the now-line striking through the card's text. A shorter card has no
   whitespace for the rule to land in, so the collision goes from occasional to
   routine.

**Verification is a pixel measurement, not a test run.** 240dp and 372dp both
satisfy all 560 existing tests, because those tests assert `yFor()` against the
same arithmetic the implementation performs — the grid is verified against
itself. Use `tools/measure_hours.py` from the spike. Separately, **add a test
that closes that hole**: assert equidistance (`yFor(h+60) − yFor(h)` constant
across every hour boundary, with a live chunk present), which is the assertion
the suite has always been missing.

</specifics>

<deferred>
## Deferred Ideas

Three items the ROADMAP lists as "also open on this surface" — planning decides
whether to fold in or split out. None is required by GRID-01/GRID-02:

- The schedule screen's `detailed` tier was never compacted (only Today's
  `full` tier was).
- Free regions and break rows render near-identical dashed outlines,
  distinguished only by label — deliberate, but unreviewed.
- `kGutterWidth` at 40dp leaves ~4dp of text-scale slack ("11 AM" measures
  36dp); large accessibility text sizes clip there first.

</deferred>
