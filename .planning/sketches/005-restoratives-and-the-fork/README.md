---
sketch: 005
name: restoratives-and-the-fork
question: "How is adding a restorative one tap — and where does 'this energizes me but isn't a goal' get decided?"
winner: "B"
tags: [restoratives, goals, energy-valence, entry-points, phase-33]
---

# Sketch 005: Restoratives, and the guitar fork

## Outcome — ★ Variant B wins (Dan, 2026-09-01)

**B · Fork at the front door.** The kind is asked *first* — *something to make time for* or
*something that restores you* — before any form exists. Choosing the second never shows a goal form
at all: name, emoji, done.

**Why the front door and not the cheaper options.** A's nudge and C's fourth option both put the
fork somewhere you have to already be *inside a goal* to find, which is the exact shape of the
original friction: the app assumes goal, and the escape hatch is a correction. B makes the two kinds
peers at the moment of entry rather than making restoratives a special case of a goal.

**The cost is real and accepted:** one extra tap on every add, including the common case where you
did just want a goal.

**The nine quick-pick restoratives ship in every variant** and are unaffected by this choice.


## Design Question

Two items, one flow, so one sketch. Both were raised on the live build on **2026-07-02**.

**Adding a restorative is all typing.** FAB → `AlertDialog` → type a name → optionally type an
emoji → Add. Nine of them is nine round trips. Meanwhile the Goals screen next door already has the
frictionless counterpart — `QuickAddField`: type, Enter, keep going.

**Energizing ≠ a goal.** Declaring something energy-giving is reachable *only from inside a goal* —
`EnergyValence.gives` lives at `goal_form_sheet.dart:277` and `onboarding_screen.dart:395`. So
"guitar energizes me" forces guitar to become a goal, with a type, a weekly budget and a priority,
or it doesn't get recorded at all.

**The model is already right; the UI never offers the fork.** `RestorativeItem` (Hive typeId 7)
exists for exactly this and its own class doc says so: *"a goal that also restores stays a goal; a
pure restorative (e.g. 'listen to music') lives here instead."* **This is an entry-point fix, not a
new aggregate** — no variant here adds one.

## How to View

    http://danserver:8103/005-restoratives-and-the-fork/index.html

Or locally: `open .planning/sketches/005-restoratives-and-the-fork/index.html`

Two phones, side by side: **① adding a restorative** and **② the guitar moment**. Every variant
shows both, because a fork you can only see from one side is not a fork.

## Variants

- **A: Chips + inline nudge** — ① nine common restoratives as tappable chips; one tap adds, tap
  again removes. ② The fork is a *reaction*: pick **Gives energy** in the goal form and a panel
  slides in offering "save as a restorative instead." Ignorable.
- **B: Fork at the front door** — ① same chip grid. ② The question is asked *first*, before any
  form: *something to make time for* or *something that restores you*. Pick the second and you never
  see a goal form.
- **C: A third energy option** — ① chip grid plus a Goals-style quick-add field, so both lists are
  entered the same way. ② The energy control becomes four options; the fourth is **Restores me — not
  a goal**, and picking it collapses the form to name + emoji. Smallest diff, one entry point.
- **As shipped** — the reference column.

## What to Look For

1. **Tap five chips in a row on ①.** That is the whole point of the item — the common case should
   cost taps, not typing. Then check the "Yours" list underneath actually reflects them, and that
   removing is as cheap as adding.
2. **When the fork arrives, in each variant.** A catches you *after* you have started building a
   goal — helpful, or naggy? B catches you *before* anything — impossible to miss, but it taxes the
   90% case where you did just want a goal. C hides it inside a control you must scroll to — the
   smallest change and the easiest to never find.
3. **Whether the "not a goal" promise is legible.** Every variant states it somewhere — the blurb
   under the app bar, the fork panel, the confirmation. The promise is load-bearing: restoratives
   are never scheduled and never counted toward budgets or streaks, and if that isn't believed the
   feature doesn't work. Check you'd believe it.
4. **Nine is a guess.** Walk outside, Music, Nap, Stretch, Shower, Read, Tea or coffee, Call
   someone, Sit in the sun. Say if any are wrong or missing — they're a hard-coded list, so changing
   them is free. (Hard-coded on purpose: Canopy is dumb on purpose, so there is no suggestion
   engine here and won't be.)

## Grounding — what is real here and what is not

**Real:** `RestorativeItem`'s field set (`id`, `name`, `emojiTag`, `sortOrder`) and its default `🌿`
when no emoji is set. The shipped empty-state copy is verbatim. The three current `EnergyValence`
options and the fact that they live inside the goal form. The restoratives screen's existing route
(Goals → ⋮ → "What restores you").

**Not real:** nothing persists across a variant switch; the goal form is abbreviated to the fields
the fork actually touches; Flutter's Roboto metrics.
