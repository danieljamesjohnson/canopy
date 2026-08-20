# Canopy — Roadmap

**Created:** 2026-02-24
**Last updated:** 2026-08-14 (v1.5 shipped and archived)

## Milestones

- ✅ **v1.0 — Core Product Loop** — Phases 1-6 (shipped)
- ✅ **v1.1 — Actually Daily** — Phases 7-11 (shipped)
- ✅ **v1.2 — Make It Usable** — Phases 12-14 (shipped 2026-06-13)
- ✅ **v1.3 — An Honest Day** — Phases 15-17 (shipped 2026-06-14)
- ✅ **v1.4 — Energy-Aware** — Phases 18-20 (shipped 2026-06-15)
- ✅ **v1.5 — Right Now** — Phases 21-26 (shipped 2026-08-14)

Full per-milestone detail (phase goals, success criteria, coverage maps) is archived in
`.planning/milestones/`: `v1.2-ROADMAP.md` carries the complete cumulative roadmap through v1.2;
`v1.3-ROADMAP.md`, `v1.3-REQUIREMENTS.md`, and `v1.3-MILESTONE-AUDIT.md` carry the v1.3
phase detail, requirements, and audit.

## Phases

<details>
<summary>✅ v1.0 Core Product Loop (Phases 1-6) — SHIPPED</summary>

- [x] Phase 1: Foundation
- [x] Phase 2: Goals and Commitments
- [x] Phase 3: Schedule Generation and Morning Check-in
- [x] Phase 4: Chunk Tracking and Notifications
- [x] Phase 5: Quarterly Review
- [x] Phase 6: Desktop and Web Polish

</details>

<details>
<summary>✅ v1.1 Actually Daily (Phases 7-11) — SHIPPED</summary>

- [x] Phase 7: Unbreak the Morning
- [x] Phase 8: A Schedule You Can Read
- [x] Phase 9: An Engine That Budgets
- [x] Phase 10: Close the Day
- [x] Phase 11: Honest Long Loop

</details>

<details>
<summary>✅ v1.2 Make It Usable (Phases 12-14) — SHIPPED 2026-06-13</summary>

- [x] Phase 12: Home as Landing, Schedule as Plan (3/3 plans) — NAV-01/02, SCHED-01/02/03
- [x] Phase 13: Check-in and Goal Form (2/2 plans) — CHECKIN-01/02, GOALFORM-01
- [x] Phase 14: Goals Screen and Priority End-to-End (2/2 plans) — GOALS-01/02, PRIORITY-01

</details>

<details>
<summary>✅ v1.3 An Honest Day (Phases 15-17) — SHIPPED 2026-06-14</summary>

**Milestone Goal:** Make the scheduling engine tell the truth and use the whole day — real time, real priority, filled capacity, honest streaks. Rule-based only (no LLM).

- [x] Phase 15: Engine Honesty (2/2 plans) — CAP-01, STREAK-01, PRIORITY-02, FILL-01, FILL-02
- [x] Phase 16: Priority Model Reconciliation (1/1 plan) — PRIORITY-03, GOALFORM-02
- [x] Phase 17: Time-Anchored Home (1/1 plan) — NOW-01, NOW-02

Full detail archived in `.planning/milestones/v1.3-ROADMAP.md`. 9/9 requirements satisfied,
browser-verified; 247/247 tests green. See `v1.3-MILESTONE-AUDIT.md`.

</details>

<details>
<summary>✅ v1.4 Energy-Aware (Phases 18-20) — SHIPPED 2026-06-15</summary>

**Milestone Goal:** Make Canopy fit the screen it's used on and schedule around how activities make you feel — so a fresh review can judge a more honest, more livable day.

- [x] Phase 18: Responsive Modals and Desktop Polish (5/5 plans) — RESP-01/02/03, POLISH-01/02
- [x] Phase 19: Energy Valence (5/5 plans) — ENERGY-01/02/03/04, ONBOARD-01
- [x] Phase 20: Valence-Aware Engine (2/2 plans) — VSCHED-01/02/03

Full detail archived in `.planning/milestones/v1.4-ROADMAP.md`. 13/13 requirements satisfied,
browser-verified; 289/289 tests green. See `v1.4-MILESTONE-AUDIT.md`.

</details>

<details>
<summary>✅ v1.5 Right Now (Phases 21-26) — SHIPPED 2026-08-14</summary>

**Milestone Goal:** Make Canopy answer "what am I doing right now?" in one place — and stop telling
the user they're behind.

- [x] Phase 21: Mood-Scaled Breaks & Honest Rationale (2/2 plans) — BREAK-01/02, TONE-01
- [x] Phase 22: Unified Today Screen (4/4 plans) — UNIFY-01/02
- [x] Phase 23: Live Activity Tracking (8/8 plans) — LIVE-01/02/03
- [x] Phase 24: Where Am I (4/4 plans) — NOW-01/02
- [x] Phase 25: Time Travel (1/1 plan) — DEV-01/02/03
- [x] Phase 26: The Day Has a Shape (10/10 plans) — CAL-01/02/03

Full detail archived in `.planning/milestones/v1.5-ROADMAP.md`. 16/16 requirements satisfied,
browser-verified; 560/560 tests green. See `v1.5-MILESTONE-AUDIT.md`.

</details>

### Standalone phases

None of these belongs to a milestone — the owner's call (2026-08-18, restated 2026-08-19) was
standalone phases rather than opening v1.6. Detail for each follows below.

- [x] Phase 27: True Grid (4/4 plans) — GRID-01, GRID-02 — complete 2026-08-19
- [x] Phase 28: The Day Is a Lattice — LATTICE-01, LATTICE-02 (completed 2026-08-19)
- [ ] Phase 29: Breaks You Can See — SEEBREAK-01, SEEBREAK-02

### Phase 27: True Grid

Standalone phase, no milestone. Raised during post-v1.5 UAT of the Today timeline; small enough
that it did not justify opening v1.6 (owner's call, 2026-08-18).

**Goal:** Every hour on the Today timeline occupies the same vertical distance, always — an hour is an hour, whatever is happening inside it.

**The defect.** `TimelineGeometry.yFor()` is linear except for one term
(`timeline_geometry.dart`): `offset += liveExtraPx` once the minute passes `liveEndMinutes`.
`liveExtraPx = kLiveRowReservedHeight − (liveDuration × kPixelsPerMinute)` = `232 − 100` = **132dp**
for a standard 25-minute chunk. So the hour containing the live chunk's end renders 240 + 132 =
**372dp against every other hour's 240dp — 55% taller.** Confirmed against a UAT screenshot
(2026-08-18): the 9→10 and 10→11 brackets measure 242.5dp and 377.5dp, matching the arithmetic to
within antialiasing. Exactly one hour per day is wrong, and only while a chunk is live.

**The tension to resolve.** That term exists to let `LiveRowCard` swell — CAL-01's one named
exception, "let now break the grid" (22-UI-SPEC.md), which the owner asked for in Phase 22 UAT
("makes it to where I am doesn't just jump off the page"). A 25-minute slot is 100dp; the live card
needs ~200dp. A true grid and a variable-height live row cannot both hold. **This phase decides
which, and that decision is the phase — not the deletion, which is one line.**

Options carried in: (a) live card fits its slot, distinguished by fill / square corners / the
now-line, as Google Calendar does — cleanest code, ends the swell; (b) shrink the live card toward
its slot so the exception is small rather than absent — half-measure, grid still not true;
(c) keep the swell, close this as won't-fix.

### DECIDED — option (a), on spike evidence (2026-08-18)

`/gsd-spike` built all three treatments from one working tree behind a `--dart-define`, served each
as a debug web build on port 8134, and pixel-measured hour-label spacing in headless Chromium at
430×930 / DPR 1. Full trail, tooling and 7 screenshots:
`.planning/spikes/001-live-row-in-a-true-grid/`.

| | Hour spacing 8→9 / 9→10 | Live card, 25-min work chunk | Live card, 5-min break | Complete/Skip reachable while live? |
|---|---|---|---|---|
| Baseline (shipped) | **240.0 / 372.0** ✗ | 198px fill, needs a 232dp slot | same 232dp slot | yes |
| **(a) compact** | **240.0 / 240.0** ✓ | **86px fill + 4px margin** in its 100dp slot | 19px, one legible line | **yes** |
| (b) delete only | 240.0 / 240.0 ✓ | 88px of 198px — **110px clipped off** | **8px of blank fill, no text** | **no** |

The baseline reproduced the defect to the pixel: 372.0 − 240.0 = **132.0**, exactly
`kLiveRowReservedHeight − 25 × kPixelsPerMinute`. Option (b) is rejected on evidence, not taste —
it slices the countdown mid-glyph and deletes both action buttons, making the current activity the
one row in the day you cannot act on, and it stops telling you you're on a break at the moment you
are. Option (a) keeps kicker, title, countdown, progress and both actions (as icon buttons) inside
the duration-exact slot, with prominence carried by `primaryContainer` fill, square corners,
elevation and the now-line — none of which need extra height. It also shortens the day by 132dp:
in the baseline the 9:50 chunk falls off the viewport, under (a) the same day fits.

**What (a) means concretely, and what the phase must build:**

1. Delete the `liveExtraPx` term from `TimelineGeometry` — `yFor()` becomes purely linear. This is
   the one-line part.

2. Render the live row through the same `Positioned(height: slot)` + `ClipRect`/`OverflowBox` path
   every other row already uses. The live row stops being a layout special case.

3. Give `LiveRowCard` **density tiers driven by slot height**, exactly as `kFullTierMinHeight`
   already works for `ChunkCard`. This is the part the spike proved is required rather than
   optional: a live 5-minute break has a 20dp slot, and there is no single card layout that serves
   both 100dp and 20dp. Making the live row obey the rule the rest of the timeline already follows
   is a *simplification* of the model, not an addition to it.

4. **Re-derive the compact tier's minimum height in a real browser.** The spike's placeholder
   (`60.0`) was never validated — the fixture only had 25-min (100dp) and 5-min (20dp) chunks, so
   nothing exercised the 60–90dp band. The measured natural height is **90dp**, so the threshold is
   ≥ 90.0 and a live chunk shorter than ~23 minutes falls to the single-line tier. Decide
   deliberately what happens in that band.

5. **Consider dropping the progress bar from the compact tier.** Once the card is duration-exact,
   the now-line's position *within* the card **is** the fraction elapsed — geometrically, not
   approximately — so the bar is a second rendering of the same fact, and at 9:10 the two literally
   overlap at the card's bottom edge. Removing it also buys back ~10dp against item 4.

6. **Resolve the now-line striking through the card's text.** A shorter card has no whitespace for
   the rule to land in, so the collision goes from occasional to routine (at 8:55 it cuts through
   "RIGHT NOW · 8:50 AM"; on the single-line break tier it cuts the only line there is). Options:
   draw the live card above the now-line overlay, suppress the rule where it crosses the live card,
   or design the card around a line that will cross it.

**Verify in pixels, never in `flutter test`.** 240dp and 372dp both satisfy all 560 existing tests,
because those tests assert `yFor()` against the same arithmetic the implementation performs,
`liveExtraPx` included — the grid is verified against itself. Use
`.planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py`, which scans the hour labels
in the 40dp gutter and prints `UNIFORM` / `NOT UNIFORM`. A new test asserting *equidistance*
(`yFor(h+60) − yFor(h)` constant across every boundary, with a live chunk present) is what closes
the hole in the suite, and is worth adding regardless.

**Build vs. buy — settled, revisit only on new evidence.** pub.dev was searched 2026-08-18.
[`kalender`](https://pub.dev/packages/kalender) is credible (MIT, all six platforms, 160/160 pub
points, 42.6k downloads, actively maintained, custom event model, uniform hour grid, replaceable
time indicator). Recommendation is still **in-house**: the defect is one term, and Canopy's
timeline is not an event list — free/gap regions are the *absence* of events, density tiers are
driven by slot height, and untimed chunks render outside the grid entirely. Adopting a 0.x calendar
package to fix a one-line special case trades a small defect for a large dependency. **This flips
if drag-to-reschedule, week/multi-day views, or timezones enter scope** — then `kalender` is doing
work we would otherwise write.

**Requirements:** GRID-01 (uniform hour spacing), GRID-02 (live-row prominence without variable
height)
**Depends on:** Phase 26 (The Day Has a Shape) — owns `TimelineGeometry` and the now-line
**Plans:** 4/4 plans executed — phase COMPLETE 2026-08-19 (`27-VERIFICATION.md`: 17/17 must-haves,
human checkpoint closed)

Plans:

- [x] 27-01-PLAN.md — Geometry: delete the `liveExtraPx` term, add the equidistance test (proven RED first)
- [x] 27-02-PLAN.md — `LiveRowCard`'s two density tiers; the live row joins the grid
- [x] 27-03-PLAN.md — Repair the screen-level live-row assertions the compaction breaks
- [x] 27-04-PLAN.md — Measure `kCompactLiveMinHeight` in a real browser; prove `UNIFORM`; UAT —
      constant measured in a real browser and set to `88.0` (84.0 first, re-measured after the
      touch-target fix raised the action row); `measure_hours.py` prints `UNIFORM` at both tiers.
      Task 3's human UAT returned its verdict 2026-08-19: item 3 passed as shipped, items 1 and 2
      failed and were fixed in `419aa7b` (Complete/Skip raised 36→44dp; the live row now paints
      above the now-line, so the rule stops at the card's edges).

**Also open on this surface, fold in or split as planning decides:**

- The schedule screen's `detailed` tier was never compacted (only Today's `full` tier was).
- Free regions and break rows now render near-identical dashed outlines, distinguished only by
  label — deliberate, but unreviewed.

- `kGutterWidth` at 40dp leaves ~4dp of text-scale slack ("11 AM" measures 36dp); large
  accessibility text sizes will clip there first.

### Phase 28: The Day Is a Lattice

Standalone phase, no milestone. Raised by the owner during Phase 27 UAT (2026-08-19): "the schedule
still isn't functioning right." Engine-side, not UI — Phase 27's grid is now honest about *rendering*
time, and this is about the times it is rendering.

**Goal:** The day is built on a 30-minute lattice — 25 minutes of work, 5 minutes of break — and
after every N of those, a full 30-minute break. Every chunk starts on :00 or :30, always.

**The owner's model, verbatim (2026-08-19):**

> The way it works is that the day is split up by 30 minutes. Where you do 25 minutes of work and 5
> minutes of break. After 3 chunks of 25/5, you take an entire 30 minute break.

So one cycle is `N × 30 + 30` minutes. At N=3: `3 × (25+5) + 30` = **120 minutes**, landing back on
a clean two-hour boundary. That lattice property is the point — it is what makes the day predictable
without the user doing arithmetic, and it is the acceptance test.

**What the engine does today** (`lib/services/schedule_generator.dart`), and the three ways it
misses:

1. **The long break is 25 minutes, not 30.** `_assignSyntheticStartTimes` sets
   `breakDur = isLong ? 25 : 5`.

2. **The long break REPLACES the short break instead of following it.** Each work chunk carries one
   `reservedBreakMinutes` — either 5 or 25, never both. So a cycle at N=4 is
   `4×25 + 3×5 + 25` = **140 minutes**, which is off-lattice and drifts the whole rest of the day
   off :00/:30. Under the owner's model the Nth chunk still closes its own 30-minute cell with a
   5-minute break, and the 30-minute break is a cell of its own.

3. **The long break is silently suppressed when it would land last.** The reservation is only
   recorded when `discIdx + 1 < discretionaryChunks.length`. At mood 3 (N=4) with a 4-chunk day —
   the exact day the owner was looking at — the long break falls after chunk 4, is dropped, and
   **no long break is ever emitted.** This is very likely the whole of "isn't functioning right":
   the cadence code is there and correct-ish, and the user has simply never seen it fire.
   Suppressing a *trailing* break is defensible; suppressing the one long break in the day is not.

**Settled — do not re-litigate.** The owner was asked directly (2026-08-19) whether N should react
to how the day actually goes, or carry over from yesterday. **He chose neither: N stays set once,
from the morning check-in mood.** The existing `_moodBreakCadence` table `{1:2, 2:3, 3:4, 4:4, 5:5}`
stays as the source of N. This phase does not make the engine adaptive, and adaptivity is not a
smaller version of this phase — it is a different one. (His illustration used N=3, which is the
mood-2 value; that was an example of the shape, not a request to retune the table. If planning
believes the table should move, ask — don't infer it from the example.)

**Watch the capacity interaction.** `_moodCap` sets how many work chunks a day gets
`{1:4, 2:6, 3:8, 4:9, 5:11}`, and the lattice makes each cycle longer than it is today (a 30-minute
long break in its own cell costs 30 minutes where a replaced 25-minute one cost 25). Fewer chunks
will fit in the same window. Decide deliberately whether the cap or the day's end moves, and say
which — do not let it fall out of the packing loop by accident.

**Requirements:** LATTICE-01 (every chunk starts on a 30-minute boundary), LATTICE-02 (a 30-minute
break after every N work chunks, N from morning mood, never silently suppressed)
**Depends on:** nothing in Phase 27 — this is `schedule_generator.dart`, a different file. Can be
planned immediately.

### OUTCOME — COMPLETE 2026-08-19 (`28-VERIFICATION.md`: passed, 10/10 must-haves)

**The capacity question, answered: neither the cap nor the day's end moved.** Research simulated the
real packing loop at every mood rather than estimating: the lattice costs 10-20 extra minutes across
a whole day, and every mood's cap still fits the 840-minute window with 455-695 minutes of slack. So
`_moodCap` and `_moodBreakCadence` are byte-identical to before the phase, verified by diff.

**The reported bug is fixed and proven.** The owner's exact day — mood 3, N=4, four work chunks —
now emits its 30-minute long break instead of silently dropping it. That day is a named regression
test, and the verifier reproduced it independently by calling `generate()` directly rather than
trusting the phase's own assertions.

**Research found a fourth defect the write-up above missed:** STEP E's trailing-chunk trim stripped
*any* trailing break, so fixing the three named defects alone would have re-suppressed the trailing
long break by a second path. Narrowed to trim only a trailing short break.

**RED-proof was structural, not aspirational.** All 20 tests were written in wave 1 and proven
failing against the unfixed engine (raw reporter output committed as `28-RED-unit.txt` and
`28-RED-d06.txt`); wave 2 changed only `lib/`. Git confirms wave 2 modified **no** test file — the
tests went RED→GREEN from the production change alone, never adjusted to fit it. That closes the
v1.5 failure mode where two defects shipped behind assertions that could not fail.

Final state: **579 tests green** (567 baseline + 8 unit + 4 D-06, none deleted), `flutter analyze`
clean, code review 0 critical / 2 warnings (both fixed). No human checkpoint — by design, per
`28-VALIDATION.md`.

**Plans:** 3/3 plans complete
Plans:

- [x] 28-01-PLAN.md — Rewrite the 10 blast-radius tests and add the LATTICE-01/LATTICE-02/D-04
      assertion groups (incl. the owner's-day regression); prove every one RED against the unfixed
      engine (wave 1, test file only)

- [x] 28-02-PLAN.md — D-06 downstream cardinality proof: the short+long break pair through
      `buildTimeline`, `TimelineGeometry` and the row widgets; also proven RED (wave 1, new test file)

- [x] 28-03-PLAN.md — The engine fix: footprint-encoded break reservation, one-or-two break decode,
      short-break-only trim, lattice-aligned slot starts; then the phase gate (wave 2)

**Verification note.** Unlike Phase 27, this one *is* fully testable in `flutter test` — it is
integer arithmetic over minutes with no glyph metrics anywhere near it. The assertion that matters:
generate a day at each mood, and check every chunk's start minute is `≡ 0 (mod 30)` and that exactly
`floor(chunks / N)` long breaks of exactly 30 minutes are emitted. No real-browser step is required,
which is a genuine difference from Phase 27 and worth stating so nobody copies that ceremony over.

### Phase 29: Breaks You Can See

Standalone phase, no milestone. Raised by the owner during Phase 28 UAT (2026-08-20) on a fresh
origin with a newly generated day: **"there's no 5 minute breaks in between."** Full evidence trail:
`.planning/seeds/SEED-005-five-minute-breaks-clip-to-a-sliver.md`.

**Goal:** Every break in the day is visible *as a break* — including a 5-minute one — without the
timeline ever lying about how long anything takes.

**The engine is not at fault, and this is not a Phase 28 regression.** Phase 28 changed exactly one
file (`schedule_generator.dart`); `timeline_geometry.dart` and `chunk_card.dart` were last touched in
Phase 27. Probing the real generator confirms the short breaks are emitted correctly and on the
lattice — a mood-4 day yields `W@08:00 SB@08:25 W@08:30 SB@08:55 W@09:00 SB@09:25 W@09:30 SB@09:55
LB@10:00`. The defect is downstream of that.

**The defect, measured.** Rendering that day through the real `ChunkCard` / `TimelineRowTile` /
`TimelineGeometry` with today_screen's own PD-10 `ClipRect` + `OverflowBox` wrapper:

| chunk | slot | natural height | result |
|---|---|---|---|
| work 25min | 100dp | 126dp | clipped 26dp |
| **shortBreak 5min** | **20dp** | **52dp** | **clipped 32dp — only 38% survives** |
| longBreak 30min | 120dp | 80dp | fits |

A 5-minute break gets `5 × kPixelsPerMinute` = **20dp**, but its card needs more, so only the top
edge of the dashed outline paints. Between two 100dp work cards that reads as a *divider*, not a
break — which is exactly what the owner reported. Remove the `ClipRect` and the same render throws
**four** RenderFlex overflow errors, one per short break; in production the ClipRect swallows the
error and clips silently, which is why this has never surfaced as a crash or a log line.

**Trust the slot column, discount the natural column.** Slot heights are pure arithmetic
(`durationMinutes × kPixelsPerMinute`, `kPixelsPerMinute = 4.0`) and are exact. The natural heights
come from `flutter test`, whose placeholder font inflates glyph metrics — a harness bound, not a
device requirement (STATE.md carry-forward invariant). Planning should **re-measure natural height in
a real browser** before fixing a threshold to a number. This is the same trap Phase 27 hit with
`kCompactLiveMinHeight` (placeholder `60.0`, measured `84.0`, re-measured `88.0`).

**The tension.** This is the direct, foreseeable cost of Phase 27's GRID-01: slots are
duration-exact, so an hour is always an hour — and therefore 5 minutes is *always* 20dp. Phase 27
solved this for the live row by giving `LiveRowCard` density tiers driven by slot height. The
**non-live break card never got the equivalent**: `kFullBreakMinHeight = 88.0` selects `compact` for
a 20dp break, and compact still needs far more than 20dp. There is no tier below it.

### DECIDED — option (1), sub-compact tier (owner's call, 2026-08-20)

Options carried in, cheapest first:

1. **A sub-compact tier for short chunks** — below a measured threshold (~24dp), render the break as
   a single hairline-with-label rather than a card. Follows Phase 27's own precedent exactly (tiers
   driven by slot height) and keeps the grid exact. **This is the chosen approach.**
2. **Render short breaks as the gap** between work cards, label on tap — cheapest, but loses the
   "you're on a break" affordance the Phase 27 spike explicitly valued when it rejected option (b).
3. **Raise `kPixelsPerMinute`** — at 8.0 a break is 40dp, but this doubles the day's scroll length.
   Phase 27 worked specifically to make the day *shorter* (it bought back 132dp). **Rejected; do not
   revisit without new evidence.**

**What the phase must build:**

1. A sub-compact density tier for chunks whose slot cannot hold the compact card, applied to the
   **non-live** break/chunk card — the live row already has its own tiers and is out of scope.
2. **Measure the threshold in a real browser, not in `flutter test`.** Decide deliberately what the
   cutoff is and what renders below it, and record the raw number, the method, and the conditions
   that would invalidate it — the doc-comment house style `kCompactLiveMinHeight` already uses.
3. A regression test asserting the grid is still true — no chunk's rendered height deviates from
   `durationMinutes × kPixelsPerMinute`. **This phase must not buy legibility with grid accuracy;
   that trade is what Phase 27 existed to eliminate.**
4. Decide whether the work card's own 26dp overflow (table above) is real on-device or a harness
   artifact, and fix or explicitly dismiss it — do not leave it unexamined.

**Verification note.** Unlike Phase 28, this one **does** need a real-browser step — it is glyph
metrics and painted rects, which is precisely the class of thing `flutter test` cannot settle here.
Phase 27's `.planning/spikes/001-live-row-in-a-true-grid/tools/` has a pixel-measurement harness to
crib from. Geometric assertions (heights computed from arithmetic) stay trustworthy in the widget
test and belong there; legibility does not.

**Requirements:** SEEBREAK-01 (every break is identifiable as a break at its duration-exact height,
with no clipped content), SEEBREAK-02 (the true grid is preserved — rendered height never deviates
from `durationMinutes × kPixelsPerMinute`)
**Depends on:** Phase 27 (owns `TimelineGeometry`, the density-tier pattern, and GRID-01, which
SEEBREAK-02 exists to protect). Nothing in Phase 28.
**Plans:** 0 plans

Plans:

- [ ] TBD (run `/gsd-plan-phase 29` to break down)

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-6 (Core Product Loop) | v1.0 | — | Complete | 2026-02 |
| 7-11 (Actually Daily) | v1.1 | — | Complete | — |
| 12-14 (Make It Usable) | v1.2 | 7/7 | Complete | 2026-06-13 |
| 15. Engine Honesty | v1.3 | 2/2 | Complete | 2026-06-13 |
| 16. Priority Model Reconciliation | v1.3 | 1/1 | Complete | 2026-06-13 |
| 17. Time-Anchored Home | v1.3 | 1/1 | Complete | 2026-06-14 |
| 18. Responsive Modals and Desktop Polish | v1.4 | 5/5 | Complete   | 2026-06-15 |
| 19. Energy Valence | v1.4 | 5/5 | Complete   | 2026-06-15 |
| 20. Valence-Aware Engine | v1.4 | 2/2 | Complete   | 2026-06-15 |
| 21-26 (Right Now) | v1.5 | 28/28 | Complete   | 2026-08-14 |
| 27. True Grid | — (standalone) | 4/4 | Complete | 2026-08-19 |
| 28. The Day Is a Lattice | — (standalone) | 3/3 | Complete   | 2026-08-19 |
| 29. Breaks You Can See | — (standalone) | 0/? | Not Started |  |
