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
| S5 | Are all three colour bands actually rendering? | **Yes.** Pixel-checked on `shots/04-goals-progress-lines.png`: red 17px, amber 72px, green 155px. |
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

## One thing that is not a defect, so you do not report it as one

Phase 33 also found a **live bug in the scheduling engine** and deliberately did not fix it, because
the ROADMAP fences this phase off from `schedule_generator.dart`. It is filed as
`.planning/seeds/SEED-006-week-start-carries-time-of-day.md`.

`_weekStart` does not normalise time-of-day, so **a chunk completed on a Monday never counts toward
that week's budget** — dropped every day of the week, at every time except exactly `00:00:00`.
Measured, not estimated.

The Goals progress line uses the **corrected** arithmetic. The scheduler still uses the buggy one. So
if you compare "how much have I done this week" between the Goals screen and how the day is being
scheduled, **they can legitimately disagree about Monday**. That is the known bug, not item 4.

---

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
