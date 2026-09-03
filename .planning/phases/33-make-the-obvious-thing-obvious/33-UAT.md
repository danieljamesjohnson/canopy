# Phase 33 UAT — Make The Obvious Thing Obvious

**Build:** debug, `--source-maps --pwa-strategy=none`, served with `tools/serve-uat.py`
**URL:** **http://danserver:8143/**
**Served bundle sha256:** `e46e1a4eb1941984…` — identical on disk and on the wire, checked at serve time
**Suite at build time:** `flutter analyze` clean · `flutter test` **678 passing** (621 at the end of Phase 32, +57 this phase)

---

## Step 0 — ⟳ Re-check-in is NOT required this round, and here is the reason

CLAUDE.md trap #4 binds any UAT that judges **scheduling-engine output**. It does not bind this one.

Nothing in Phase 33 touches `lib/services/schedule_generator.dart` — the diff is `chunk_card.dart`,
`free_time_row.dart`, `goal_card.dart`, `goals_screen.dart`, `restoratives_screen.dart`,
`goal_form_sheet.dart`, one new pure service and one new fork widget. A previously-generated day
renders through the new code on load, so the screen you open is already produced by this build.

**The rule returns the moment a plan touches the generator.** It did not this time.

**The day has been pre-seeded for you** (see "How the fixture was built" at the bottom) so that every
state you need to judge is already on screen. **Do not press ⟳ Re-check-in** — it would regenerate
the day and wipe the completed and skipped chunks that items 1 and 4 depend on.

> **Superseded 2026-09-03.** SEED-006 is now fixed, so this phase's diff DOES touch
> `schedule_generator.dart`. Trap #4 binds any future round that judges scheduling output — see the
> SEED-006 section below. It did not bind the rounds already judged, which were UI-only.

---

## Already answered — do not spend your time on these

Six structural questions were settled by driving the running app with
`.planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs` and reading the semantics tree.
They are recorded here so they are visibly answered rather than quietly assumed, and so you are not
asked something a browser can settle. Phase 32 burned three rounds asking a human questions of
exactly this kind.

| # | Question | Answer |
|---|---|---|
| S1 | Is `Icons.radio_button_unchecked` gone? | **Yes.** Zero occurrences in `lib/` outside two comments explaining the removal. |
| S2 | Does every unresolved row carry a labelled chip? | **Yes.** `To do` present on every unresolved work row in the semantics tree. |
| S3 | Do the resolved states carry words too? | **Yes.** `Done` and `Skipped` both present as text nodes. |
| S4 | Is there still exactly one way to complete a chunk? | **Yes.** One `Complete` button per row; the chip exposes no tap target. |
| S5 | Are all three colour bands actually rendering? | **Yes.** Pixel-checked; re-measured after item 4 on `shots/15-progress-line-item4.png`: red 8×12px, amber 8×23px, green 8×46px. |
| S6 | Is the fork reachable before any form, and does each door state its consequence? | **Yes.** `"What are you adding?"` with both doors and both consequence lines. |
| S7 | Does tapping a restorative chip add it, and tapping again remove it? | **Yes.** Covered by `restoratives_quick_pick_test.dart` cases 2–4 and confirmed live. |

---

## What I want your eyes on

### Item 1 — the unlabelled circle *(the 2026-06-12 item — this is the one)*

Open **Today**. Scroll the day.

You complained on **2026-06-12**: *"there's a little circle next to it — really unclear UI for a
human."* It shipped for 2.5 months. Every work row now says its state in a word instead:
**To do** / **Done** / **Skipped**.

- Does a row's state read at a glance now?
- Is a chip on every single row too much furniture? There is one on every work row, and you will see
  several at once.
- The chip is deliberately not tappable — **Complete** and **Skip** stay the only controls. Does it
  nonetheless look like a button to you?

### Item 2 — free time is a filled card again

Same screen, the **"Free until 10:30 AM"** block at the top of the day.

Phase 22 made free time and breaks match; Phase 32 pulled them apart and free time stayed a dashed
outline. It is now a filled card like a break.

- Does free time read as *time that is yours*, or does it now read as something scheduled?
- Sitting next to a break card, are the two still distinguishable?

### Item 3 — the Goals screen says what it is

Open **Goals**.

It is now one list headed **Priority order**, numbered 1–3, most important first, with the type as a
chip on the card. The three type sections are gone.

- Does the page now answer *"I don't know about this goals page"*?
- You lose "all my Regular time goals together". Do you miss it?

### Item 4 — the progress line, and the thing I am least happy with

Same screen, the coloured line at the **left edge** of each card. Red under 20%, yellow under 70%,
green at 70% and above, no key on screen — your rule, verbatim.

The fixture is deliberate: **Exercise 0.139 (red) · Reading 0.417 (amber) · Side project 0.833
(green)**, each from one completed 25-minute chunk against a different weekly budget.

**Three things I found by looking at it, which I would rather you heard from me than discovered:**

1. **The lines are small.** The track is 5dp wide and 40dp tall, so Exercise's 13.9% is about a
   **6-pixel speck**. It is technically red and practically invisible. Green reads fine; red barely
   registers.
2. **There are now two colour systems on one card.** The line on the left means progress. The dot on
   the right is the goal's identity colour and means nothing — and it is the *louder* of the two.
   Exercise shows a **green dot** next to a **red line**. That is arguably the original complaint
   (*"the colors are changing, it's not making a ton of sense"*) reappearing in a new place, and it
   is the single thing most likely to make you reject this screen.
3. **"Red when just started" is currently invisible at exactly just-started.** A budgeted goal with
   nothing done is 0.0 — zero height — so it renders as nothing, identical to a goal that has no
   weekly target at all. The distinction is real in the data and unit-tested; it just does not reach
   the screen.

So: does the scale read without a key, and do you want (a) a wider or taller track, (b) the identity
dot gone or muted, (c) a minimum visible nub so 0% is a red mark rather than nothing?

### Item 5 — nine restoratives, one tap each

**Goals → ⋮ → What restores you.**

Nine tappable chips: Walk outside · Music · Nap · Stretch · Shower · Read · Tea or coffee · Call
someone · Sit in the sun.

- **Tap five in a row.** Do all five land under your thumb? This is the count Phase 32 asked for
  three times and never got, so a number is worth more than "seems fine".
- Are any of the nine wrong, or is anything obviously missing? They are a hard-coded list, so
  changing them is free.

### Item 6 — the fork at the front door

**Goals → the "Add goal" button (bottom right).**

Before any form you now get *"What are you adding?"* with two doors:

- **Something to make time for** — *"Gets a type, a weekly budget and a priority. Canopy schedules it."*
- **Something that restores you** — *"Never scheduled. Never counted toward a budget or a streak."*

This is the guitar friction: marking something energizing no longer forces it to become a goal.

- Do you believe the promise on the second door? It is load-bearing — if you do not believe
  restoratives are truly never scheduled, the feature does not work.
- It costs one extra tap on every add, including the times you did just want a goal. Worth it?

**6b — one thing was deliberately narrowed and nobody had said so out loud.** The fork sits in front
of the **button only**. Typing "guitar" into the **"Add another…"** field at the top still silently
creates a *goal*. That was a scope call, not an oversight. Is it acceptable, or does the quick-add
need the fork too?

---

## SEED-006 — was "not a defect you should report"; now fixed

**When this script was written, this section told you to ignore a live engine bug.** It is closed as
of 2026-09-03 ("take it"), so the warning is replaced rather than left to mislead.

`_weekStart` did not normalise time-of-day, so **a chunk completed on a Monday never counted toward
that week's budget** — every day of the week, at every time except exactly `00:00:00`. Goals and the
scheduler could legitimately disagree about Monday. They no longer can: there is now **one** week
boundary (`ScheduleGeneratorService.weekStart`), and `WeeklyProgressService` and
`QuarterlyAggregationService` both delegate to it.

**CLAUDE.md trap #4 is live again for this phase.** The diff now includes
`lib/services/schedule_generator.dart`, so **any future UAT that judges scheduling output must
⟳ Re-check-in first** — the "Step 0 is not required" note at the top of this file was true for the
UI-only rounds and is **no longer true** for engine-facing ones.

---

## Verdict — 2026-09-02 (owner)

**Where it came from.** Excalidraw, `canopy` board (`mc-read-tool excalidraw`) — a screenshot of the
Today screen from his own instance, marked up in red, plus this note:

> check out excalidraw. i wanted the breaks to have the diagonal lines in them like the sketch. i
> crossed out the text, i don't think it should be there. in addition, i think side projecjt should
> have a color not the hsame as a break

The board render is committed as `shots/07-owner-annotation-2026-09-02.png` (the pasted screenshot is
clean; the red is 10 freedraw strokes on the board, drawn over it). **What he actually marked, stroke
by stroke, so nobody has to re-interpret it later:**

- one strike through **"Nothing until 8:00 AM"**;
- one stroke through/under **"The day starts with Side project. Until then the time is yours."**;
- **seven diagonal strokes filling the "Free until 8:00 AM" block**, top-left to bottom-right;
- one zigzag scribble across the **Side project** work card.

His screenshot is his own instance, not the seeded fixture — `0 of 13 Chunks`, nothing completed or
skipped, the day starting at 8:00 AM. **That is why most of the six items below are unjudged rather
than passed: the states they ask about were not on his screen.**

### Item 1 — the unlabelled circle · **NOT JUDGED**

No words on the chip either way. He saw exactly one of them — the `To do` on the Side project row —
and did not mark it. The 2026-06-12 circle is gone and undisputed, but "does a row's state read at a
glance", "is a chip on every row too much furniture" and "does it look like a button" are all still
unanswered. **Not recorded as a PASS.** He scribbled over that card, but his sentence about it is
about its colour, not its chip.

### Item 2 — free time is a filled card again · **FAIL, with the fix drawn in**

> i wanted the breaks to have the diagonal lines in them like the sketch

Filled was right; **flat filled is not what he picked.** The sketch he chose has the hatch in it —
`.planning/sketches/003-the-unlabelled-circle/index.html:131`,
`repeating-linear-gradient(135deg, …)` on `.free.filled`. The shipped `FreeTimeRow` copied the break
card's `color`/`shape`/`clipBehavior` verbatim and **dropped the hatch**, which nobody noticed
because the sketch's own hatch is 2% black and barely visible on a laptop. He drew his over the whole
block in red, which is a fair signal about the weight he expects.

**He says "breaks" and marked free time.** No Short/Long break card was on his screen to mark — the
day hadn't started. Treated as "the grey non-work block", i.e. the language covers both. Routed
below as one decision, not two.

### Item 3 — the Goals screen says what it is · **NOT JUDGED**

### Item 4 — the progress line · **NOT JUDGED**

Nothing was completed in his instance, so every goal sits at 0.0 and **there were no coloured lines
on screen to look at.** The three things I flagged — the 6px speck, the two colour systems on one
card, the invisible 0% — are all still open and all still mine. Note that his one colour sentence
("side project should have a color not the same as a break") is about the *timeline card*, not this
screen's line or dot; do not read it as an answer to (a)/(b)/(c).

### Item 5 — nine restoratives · **NOT JUDGED — no tap count, third phase running**

Phase 32 asked for this number three times and never got it; this is the fourth ask, still unanswered.

### Item 6 — the fork at the front door · **NOT JUDGED** (6b likewise)

### New — the PreStart banner should not be there · **his own item**

> i crossed out the text, i don't think it should be there

Both lines, struck separately: the `Nothing until 8:00 AM` heading and
`The day starts with Side project. Until then the time is yours.` That is the whole PreStart branch
of `_buildEdgeStateLine` (`today_screen.dart:459-479`). **This copy is LOCKED by D-03** (23-CONTEXT.md
decision 3 / 23-UI-SPEC.md "Edge states"), so removing it reverses a standing decision rather than
tidying a string — it needs to be recorded as one. He struck **PreStart only**; `Up next`
(GapBeforeNext) and the DayComplete line were not on his screen and are not covered by this.

The likely reason it reads as clutter: the timeline directly beneath it already says
**"Free until 8:00 AM"** in the block itself, and the first card already says **Side project ·
8:00 AM**. The banner is a third statement of both facts, above the fold.

### New — work and break are literally the same colour · **his own item**

> in addition, i think side projecjt should have a color not the hsame as a break

Correct, and it is exact rather than approximate: the work card
(`chunk_card.dart:415-426`), the break card (`chunk_card.dart:196`) and the free-time card
(`free_time_row.dart:63`) all render `colorScheme.surfaceContainer` with the same
`outlineVariant` border and the same 12dp radius. The **only** thing separating a work chunk from a
break today is the 4dp goal-colour bar on its left edge — which in his screenshot is a thin green
strip he did not mention. Three different kinds of time, one fill.

### What this verdict does not settle

Items 1, 3, 4, 5, 6 and 6b are **unjudged, not passed**, and the six structural questions in the
table above remain the only things actually answered about them. Item 4's three findings still need
an owner ruling. The Item 5 tap count is still outstanding after four asks.

---

## What shipped against this verdict — 2026-09-02, same day

All three of his marks are closed, plus two follow-up rulings on how breaks and free time separate,
plus item 4's three findings. `flutter analyze` clean, **701 tests green** (678 before, +23). Rebuilt
and re-served on `http://danserver:8143/` — bundle sha `2458bade94de6b7c…`, identical on disk and on
the wire.

| His words | What changed | Seen |
|---|---|---|
| *"i wanted the breaks to have the diagonal lines in them like the sketch"* | New `HatchFill` (`lib/widgets/hatch_fill.dart`) — free time only, after three passes | `shots/13…` |
| *"i crossed out the text, i don't think it should be there"* | PreStart branch of `_buildEdgeStateLine` deleted — **D-33-01**, reversing D-03's LOCKED copy | `shots/13…` |
| *"side project should have a color not the same as a break"* | Work card moves to `surfaceContainerLowest` | `shots/13…` |
| *"i still feel like free time and break look too similar"* (2026-09-03) | A break becomes a **tinted** `secondaryContainer` card and drops the hatch entirely | `shots/14…` |

**The day's three kinds of time now read three different ways.** Measured on the rendered page at
mood 3: work rgb(255,255,255) flat · free time rgb(233,239,235) + neutral diagonals · break
rgb(205,233,222) flat and tinted.

**It took three passes, and the two dead ends are the useful part of this record.**

1. Free time and breaks got the *identical* neutral hatch. Only the label and the Skip rail told them
   apart — which made the pair *less* separable than before this phase touched them, the exact
   question item 2 asks out loud.
2. Both stayed hatched, and the break's lines got their own hue (`tertiary` at 0.45; free time
   rgb(228,234,230) vs break rgb(180,195,199), measured on screen). Verdict: *"i still feel like free
   time and break look too similar."*
3. The difference moved off TEXTURE and onto FILL. A break is a tinted card; the hatch goes back to
   meaning free time and nothing else — which is what he asked for in the first place.

**The lesson, promoted into `hatch_fill.dart`'s own doc so it survives this file:** two cards of the
same colour with different stripes are a spot-the-difference puzzle. Texture is a weak channel for
"these are different kinds of thing"; fill is a strong one. **Do not answer a future "these look
alike" report by re-tuning a hatch.**

`secondaryContainer` is the one accent surface this app had not spent — `primaryContainer` is the
live row, `tertiaryContainer` a commitment, `errorContainer` the Skip rail inside these very cards.
The break's label moved to `onSecondaryContainer` with it, since M3's contrast guarantees are per
pair. `HatchFill.breakLines` was **deleted, not left unreferenced.**

The work/break colour half was deliberately solved on the **neutral** ramp rather than with a hue:
item 4 already flags one card carrying two colour systems, and a new hue would have re-opened
*"the colors are changing, it's not making a ton of sense"* on the screen next door.

**Mutation-tested, per this project's own rule.** Seven mutations were applied across the three
passes and each observed RED before its test was accepted — work fill reverted to `surfaceContainer`,
the free-time hatch removed, `hatchSegments` stepped by `spacing` instead of `spacing × √2` (the
error that would draw the lines 1.41× too close, which no "is it hatched?" assertion could catch),
the break tone reverted to `secondary`, the break tone set equal to the free-time tone, the break
FILL reverted to `surfaceContainer`, and the hatch re-added to the compact break. Tree restored green
after each.

**Two assertions caught real mistakes before they shipped, and one of them was mine about the test
itself.**

- The hue-distance check failed on the first implementation of pass 2 and is why that tone was
  `tertiary` rather than `secondary`: in `ColorScheme.fromSeed`, `secondary` is the neutral-VARIANT
  hue, within 2-4° of `onSurfaceVariant` at every mood seed here (208/210, 160/156, 45/43). Two
  colours in the source, one grey on the screen.
- That same hue check was then **wrong for pass 3** and had to be replaced rather than satisfied. At
  mood 1 the two container tokens sit 9.3° apart yet are plainly different — rgb(235,238,243), a
  near-white grey, against rgb(211,229,245), a pale blue — because the difference is carried by
  saturation and lightness, not hue. Keeping the hue threshold would have rejected a pair that works
  and pushed the design toward a number instead of a look. It is now a plain RGB distance, which is
  blind to which channel does the work. **A metric that was right for a line was wrong for a
  surface.**

The colour assertions read the live `Card.color` and the live `HatchPainter`, not constructor
arguments — the free-time call site passes `null` and resolves its tone inside `build`.

**Two banner assertions were DELETED rather than repointed.** `find.textContaining('Nothing until')`
→ `findsNothing` in the active and day-complete states now passes because that string renders
*nowhere*, so it no longer discriminates anything — exactly the "assertion that cannot fail" this
project has been bitten by five times. The two `findsOneWidget` probes that used the banner to detect
pre-start were repointed to the leading free block (`Free until 8:00 AM`), which is a stronger probe:
it is the row a user actually reads.

### Item 4 — all three findings closed, 2026-09-03 ("go ahead and fix the remaining things")

He delegated the three rulings rather than answering (a)/(b)/(c) one by one. What was decided, and
on what basis:

- **(a) the ~6px speck** → track **40 → 56dp tall, 5 → 8dp wide**. Height is the channel that carries
  a low value; widening alone would only make a short speck a fatter one. 56 is bounded by the card
  (~92dp of content, track centred), not chosen for looks.
- **(c) 0% invisible** → a **12dp minimum fill**, and the render condition changed from `p > 0` to
  `p != null`. A budgeted goal with nothing done now paints a red stub; **no weekly target is the
  only thing an empty track means.** This deliberately breaks proportionality below ~21% — the trade
  is sound because the line is a three-band traffic light with no key and no number (item 15), so the
  band is the message and the fraction never was.
- **(b) two colour systems** → the identity swatch is **deleted, not muted.** `goal.color` is
  auto-assigned by `GoalsNotifier.autoColor()` and there is no colour control anywhere in the goal
  form, so the dot stated an identity the user never chose, louder than the line that states
  something true. Muting would keep a meaningless mark and just make it quieter. **Known
  consequence:** the goal colour still paints the timeline's 4dp left bar, and this card was the only
  place to see which colour belonged to which goal. That legend is gone; every timeline card carries
  the goal's name anyway.

Measured on the rendered page (`shots/15…`, `shots/16…`): red 8×12px · amber 8×23px · green 8×46px,
against the old 5×6px speck. **The 12dp floor was itself chosen by looking** — at 10dp the mark
paints a near-perfect circle on a 4dp-radius track, i.e. a red dot, one screen after (b) deleted a
coloured dot from this same card.

**Two mutation-testing findings worth more than the fix.**

1. **Reverting the track to its old 40×5 produced ZERO failures** across the whole file. Every
   assertion derived its expected value from `kGoalProgressTrackHeight` / `kGoalProgressTrackWidth`,
   so it moved with the constant — a symbolic expectation cannot fail a symbol. This is the same trap
   STATE.md records for `kBreakHitSlop` in Phase 31, recurring inside one phase. Fixed with two bare
   literal bounds that encode the legibility claim (`width >= 8`; amber clears the floor by >= 10dp)
   rather than the numbers that satisfy it today.
2. The rendered-width assertion caught a **half-applied change**: the track's `Positioned(width: 5)`
   and the content `Padding(left: 5)` had not moved with the constant, so the widened track rendered
   at the old width no matter what `_ProgressLine` asked for. Not visible in the diff; visible in the
   pixels.

Five mutations were applied and each observed RED: no minimum fill (3 failures), `0.0` back to
painting nothing (2), track height back to 40 (1), track width back to 5 (1), identity swatch
restored (2).

**Still unjudged:** items 1, 3, 5, 6 and 6b — nothing in any of this touches the restoratives or the
fork. **Item 5's tap count remains the one open question no agent can close**; it needs a thumb, and
it has now been asked four times.

---

## For whoever picks this up next (session handoff, 2026-09-02)

- **The gate is CLOSED — the verdict is above and the fix is shipped.** The build now serving on
  `http://danserver:8143/` is the post-verdict one (sha `da89487a9bdf90a4…`), not the one he judged.
  The judged bundle was `e46e1a4eb1941984…`; it is superseded, not lost — `git show 3896e78` is the
  tree it was built from.
- **The seeded Chromium profile is at `~/.cache/canopy-uat-profile-33`, and it lives on the
  `localhost:8143` ORIGIN — not `danserver:8143`.** This line used to say only "drive it with that
  path", which is a trap: Hive is IndexedDB, IndexedDB is per-origin, and the fixture was seeded
  through `localhost`. Opening the *documented* UAT URL with that profile therefore lands on an
  **empty** instance, the driver silently onboards a blank one, and the fixture looks destroyed when
  it is sitting untouched one hostname away. That happened on 2026-09-02; both origins now exist
  inside the profile (`Default/IndexedDB/http_localhost_8143…` is the real one, 60 KB, the other is
  the accidental blank).
  **Drive the fixture at `http://localhost:8143/`.** Verified intact after the closure: Exercise
  3.0 / Side project 0.5 / Reading 1.0 with their completions — `shots/10-progress-lines-fixture-intact.png`.
- **The seeded DAY expired on its own overnight.** It was generated 2026-09-01; `_loadToday()` reads
  *today's* schedule, so on 2026-09-02 the app offers "Start check-in" again. The goals, budgets and
  completed chunks survive (they are what the weekly progress lines are computed from) — only the
  timeline is regenerated. Nobody pressed ⟳ Re-check-in; date rollover did it.
- **The owner's verdict goes in this file**, under a new `## Verdict` section, item by item.

## How the fixture was built (reproducible)

Profile: a fresh persistent Chromium profile, onboarded with Exercise + Side project, then:

1. Quick-added a third goal, **Reading**.
2. **⟳ Re-check-in** to regenerate the day so all three goals had chunks (6 chunks).
3. Completed one chunk each of Exercise, Reading and Side project; skipped one Side project chunk.
4. Edited weekly budgets so one completion lands in each band: Exercise **3.0** → 0.139 red,
   Reading **1.0** → 0.417 amber, Side project **0.5** → 0.833 green.

Driven with `drive.cjs`, which gained `--tap` / `--tapbig` / `--tapxy` / `--type` / `--key` /
`--wheel` this phase (all additive; existing invocations are unchanged).

**Two driver traps found and fixed while building this, both recorded in the tool's own comments:**
a `mouse.click` without a dwell never focuses a Flutter text field (so `--type` silently typed into
nothing), and a semantic node scrolled out of the viewport still reports coordinates, so tapping it
"succeeds" and does nothing — six Complete/Skip taps all reported hits while only the two above the
fold actually did anything.

Evidence: `.planning/phases/33-make-the-obvious-thing-obvious/shots/`
`01-today-status-chips.png` · `02-today-skipped-and-todo.png` · `03-today-skipped-chip.png` ·
`04-goals-progress-lines.png` · `05-restoratives-quick-pick.png` · `06-add-kind-fork.png`
