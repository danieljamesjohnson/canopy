---
spike: 001
name: live-row-in-a-true-grid
type: comparison
validates: "Given a true grid gives the live chunk a duration-exact 100dp slot, when the live row is either compacted to fit that slot (a) or left as-is with the exception term simply deleted (b), then one of the two keeps the live row prominent AND actionable while every hour measures the same distance"
verdict: "VARIANT A — WINNER"
related: []
tags: [flutter, layout, today-timeline, phase-27, ui]
---

# Spike 001: The live row in a true grid

## What This Validates

**Given** `TimelineGeometry.yFor()`'s `liveExtraPx` term is deleted, so the live
chunk gets the same duration-exact slot as every other row (100dp for a
standard 25-minute chunk),
**when** the live card is either (a) compacted to fit that slot or (b) left
exactly as it is and allowed to clip,
**then** exactly one of those keeps the live row both prominent and actionable
while every hour on the timeline measures the same vertical distance.

This is the one open question Phase 27 was blocked on. The deletion itself is
one line; what the live row *becomes* afterwards is the decision.

## Research

No external research was needed and none was done. This is not a library
question — `26-ROADMAP`'s build-vs-buy call on
[`kalender`](https://pub.dev/packages/kalender) was settled 2026-08-18 and
nothing here disturbs it. The question is entirely about this app's own
`LiveRowCard` against its own geometry, and the only authority that can answer
it is a real browser rendering real Roboto, which is what this spike used.

The one piece of prior art carried forward is **26-08-SUMMARY.md's measurement
technique**: drive a headless Chromium persistent profile, set the simulated
clock by writing `localStorage['flutter.dev_clock_offset_micros']` directly
rather than clicking the debug UI's coarse +1h/-1h buttons, and pixel-count the
result. That is reused verbatim here (`tools/drive.cjs`).

## How to Run

```bash
# 1. Build a variant (baseline | a | b)
flutter build web --debug --source-maps --pwa-strategy=none --dart-define=SPIKE_VARIANT=a

# 2. Serve it
python3 tools/serve-uat.py 8134 --dir build/web

# 3. Drive it to an exact simulated instant and screenshot
export NVM_DIR=$HOME/.nvm && . $NVM_DIR/nvm.sh
NODE_PATH=$(npm root -g) node .planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs \
  http://localhost:8134/ /tmp/canopy-spike-profile /tmp/shot.png --at=09:10

# 4. Measure hour-to-hour spacing off the screenshot
python3 .planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py /tmp/shot.png
```

`variants.patch` holds the exact `lib/` diff all three builds came from — one
working tree, one `--dart-define`, so the screenshots differ only in the
variant. It is a spike artefact, **not** a patch to apply: Phase 27 implements
the winner properly and unconditionally.

## What to Expect

`measure_hours.py` prints `VERDICT: UNIFORM` or `NOT UNIFORM` and the
centre-to-centre pixel distance between consecutive hour labels. The baseline
build must print `NOT UNIFORM` (that is the bug); both variants must print
`UNIFORM`.

## Observability

`measure_hours.py` is the forensic layer, and it exists because **`flutter test`
structurally cannot see this bug.** No test asserts that consecutive hour
boundaries are equidistant — the tests assert `yFor(x)` against the same
arithmetic the implementation performs, `liveExtraPx` included, so the grid is
verified against itself. 240dp and 372dp both pass every one of the 560 tests.
The measurement therefore has to come from pixels.

Method: the hour labels are the only ink in the timeline's 40dp left gutter, so
the script scans that strip for bands of non-background rows and reports
band-centre spacing. Background colour is derived from the image rather than
hard-coded, so it works in either theme.

## Investigation Trail

**1. Reproduce the defect before touching anything.** Built the shipped code
unmodified, drove a fresh profile through onboarding + morning check-in
(2 goals, "partly cloudy" → 4 chunks), parked it at a simulated 9:10 AM inside
the live 8:50–9:15 chunk, and measured:

```
label band centre=221.0     ← 8 AM
label band centre=461.0     ← 9 AM
label band centre=833.0     ← 10 AM
  8→9:  240.0 px
  9→10: 372.0 px    spread=132.0    VERDICT: NOT UNIFORM
```

132.0 is `kLiveRowReservedHeight - (25 × kPixelsPerMinute)` = `232 − 100`
exactly — the roadmap's arithmetic, confirmed to the pixel rather than to
"within antialiasing". The harness was trusted only after it reproduced the
known-bad number.

**2. One working tree, three builds.** Rather than three branches, a
`String.fromEnvironment('SPIKE_VARIANT')` constant selects the treatment at
build time. Both variants share the *same* one-line change — the `liveExtraPx`
computation is skipped — and differ only in what the live row does with its
now-fixed slot. That isolates the variable being spiked.

**3. Variant (b) first, because it is the cheap answer.** If simply deleting
the term were acceptable, variant (a) would be wasted work. It is not
acceptable — see Results.

**4. Variant (a) needed a second tier, discovered mid-build.** The first design
for (a) was a single compact layout sized against a 25-minute chunk's 100dp.
That is wrong the moment a **break** is live: a 5-minute break's slot is 20dp,
and no card fits in 20dp. This is not an edge case — the generated day puts a
short break after every work chunk, so the live row is a break for a
meaningful slice of every day. Variant (a) was rebuilt with the same
slot-height-picks-density rule every other row already follows
(`kFullTierMinHeight`): compact tier above the threshold, single-line tier
below it. Captured at 9:17 (inside the live 9:15–9:20 break) to prove it.

**5. Probed the moment the now-line crosses the card**, at a simulated 8:55
(20% into the chunk) as well as 9:10 (80% in), because a shorter card means the
now-line has fewer places to land that are not text. It does strike through
text — see Residual Risks.

## Results

### Verdict: **VARIANT A — compact the live card to fit its slot.**

All measurements are real-browser, headless Chromium
(`--use-gl=swiftshader --enable-unsafe-swiftshader`), 430×930 viewport at DPR 1
so screenshot px = logical px, debug build served through `tools/serve-uat.py`
on port 8134. Same persistent profile, same generated day, same simulated
instants across all three builds — the only difference is the variant.

| | Hour spacing (8→9 / 9→10) | Grid | Live card fill, work chunk | Live card fill, 5-min break | Complete / Skip reachable while live? |
|---|---|---|---|---|---|
| **Baseline** (shipped) | **240.0 / 372.0** | ✗ NOT UNIFORM | 198px (needs a 232dp slot) | n/a — also 232dp | yes |
| **Variant a** — compact | **240.0 / 240.0** | ✓ UNIFORM | **86px** in its 100dp slot | **19px**, one legible line | **yes** |
| **Variant b** — delete only | **240.0 / 240.0** | ✓ UNIFORM | 88px of 198px — **110px clipped away** | **8px of blank fill, no text at all** | **no** |

Evidence: `shots/comparison-0910-three-up.png` is the whole comparison in one
image (baseline | a | b at the same instant). Per-variant full frames and the
break-live captures are alongside it.

**Why (b) loses, decisively.** Deleting the term without touching the card
guillotines it mid-sentence: at 9:10 the countdown line "5 min left · until
9:15 AM" is sliced horizontally through the glyphs, and the progress bar, the
Complete/Skip row, and the "Next ·" line — 110px of the card — are simply gone.
**The current activity becomes the one row in the day you cannot act on.** The
break case is worse: a live 5-minute break renders as 8px of blank mint with no
text whatsoever, so the app stops telling you you're on a break at exactly the
moment you are. That is not a cheaper version of the fix, it is a different and
worse bug traded for the first one.

**Why (a) wins.** The compact card measures **86px of fill + 4px of margin =
90px natural**, inside its 100dp slot with 10px of slack, and it keeps every
affordance: kicker with start time, title, live countdown, progress, and both
Complete and Skip (as icon buttons rather than labelled ones). Prominence
survives on exactly the terms `26-UI-SPEC.md` already names — `primaryContainer`
fill, square corners, elevation, and the now-line — none of which depend on
extra height. This is also what the roadmap's option (a) described as "what
Google Calendar does", now measured rather than asserted.

**An unbudgeted win, visible in the three-up:** the day gets 132dp shorter. In
the baseline the 9:50 chunk is falling off the bottom of the viewport; under
either variant the same day is fully visible with room to spare. The swell was
costing more than uniformity.

### Surprises

**The progress bar and the now-line now say the same thing.** Once the card is
duration-exact, the now-line's position *within* the card **is** the fraction
elapsed — geometrically, not approximately. The card's own `LinearProgressIndicator`
is a second, redundant rendering of it, and at 9:10 the two literally overlap at
the card's bottom edge. Dropping the progress bar from the compact tier would
free ~10dp and remove the duplication. Not built here — that is a design call
for Phase 27, flagged rather than silently taken.

**Density tiering was already the house rule.** Variant (a) did not need a new
concept; `kFullTierMinHeight` / `kFullBreakMinHeight` already say "slot height
picks the tier." The live row had been the one row exempt from a rule the rest
of the timeline follows. Making it obey is a *simplification* of the model, not
an addition to it — which is the strongest argument for (a) beyond the pixels.

### Residual risks — real, and Phase 27 must resolve them

1. **The compact tier's floor is ~90dp, and a 25-minute chunk clears it by only
   10dp.** The spike's `_kCompactLiveMinHeight = 60.0` is a placeholder that
   was **never validated** — the fixture's only chunk lengths were 25 min
   (100dp) and 5 min (20dp), so nothing exercised the 60–90dp band. At the
   measured 90dp natural height, a live chunk shorter than ~23 minutes would
   pick the compact tier and be clipped. The real threshold is ≥ 90.0 and must
   be re-measured in a browser, alongside a decision about what happens to
   chunks between the two tiers. Dropping the progress bar (above) buys back
   headroom here.
2. **The now-line strikes through the card's text.** At 8:55 the rule cuts
   through "RIGHT NOW · 8:50 AM"; on the single-line break tier it cuts through
   the only line there is. The baseline hides this by being tall enough that
   the line usually lands in whitespace. A shorter card has no whitespace to
   spare, so the collision becomes routine rather than occasional. Options for
   the phase: draw the live card above the now-line overlay, suppress the rule
   where it crosses the live card, or design the card around a line that will
   cross it.
3. **Long goal titles.** The compact tier gives the title one line with
   `TextOverflow.ellipsis`. The shipped card let it wrap to a second
   `headlineSmall` line — a documented residual risk there too, now traded for
   a truncation instead of an overflow.

## What This Does NOT Claim

Only the work-live (25 min) and break-live (5 min) states were measured, on one
viewport (430×930), in light theme, at DPR 1. Dark theme, desktop widths, large
accessibility text scales, and the `Overdue` live state were not captured. The
grid verdict is robust across all of them (it is arithmetic), but variant (a)'s
*fit* is a measured claim at one text scale and does not automatically survive a
larger one.
