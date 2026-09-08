# Phase 33 UAT — Round 2 (the open items)

**URL:** **http://danserver:8143/**
**Bundle sha256:** `b046779cbf2a8b4c…` — identical on disk and on the wire
**Suite:** `flutter analyze` clean · `flutter test` **706 passing** (678 when round 1 was written)

Round 1's verdict closed everything you marked, plus item 4 and SEED-006; **item 6b closed on
2026-09-08** off the "help" report. **Four items are still unjudged** — not because they passed, but because your screenshot was a fresh instance where those
states never appeared. This is the script for those four, and nothing else.

---

## Step 0 — press ⟳ Re-check-in first. **This reverses round 1's instruction.**

`33-UAT.md` says *"Do not press ⟳ Re-check-in"*. That was correct then and is **wrong now**:

- What it protected — the seeded completed/skipped chunks items 1 and 4 depended on — is spent.
  Both items are closed.
- **The engine changed.** SEED-006 was fixed on 2026-09-03, so `schedule_generator.dart` is in this
  phase's diff. CLAUDE.md trap #4: an already-generated day is never regenerated on load, so a day
  built before that fix still renders through the old arithmetic. **Your current day predates it.**

So: open the app, tap **⟳ Re-check-in**, pick a mood. That regenerates today against the fixed
engine and gives you a full day of rows to judge items 1 and 3 against.

---

## Item 5 FIRST — nine restoratives, and the count nobody has taken

**This is deliberately at the top.** It has been asked four times — three in Phase 32, once in round
1 — and never answered, every single time because it sat behind items that ran long. Ordering is the
only thing that has ever fixed that in this project.

**Goals → ⋮ (top right) → What restores you.**

Nine chips: Walk outside · Music · Nap · Stretch · Shower · Read · Tea or coffee · Call someone ·
Sit in the sun.

1. **Tap five of them in a row, with your thumb, and tell me the number that landed.** "5 of 5" or
   "3 of 5" — a count, not an impression. Every previous round returned "seems fine", which is the
   mechanism firing, not the target being hittable.
2. Tapping one adds it; tapping it again removes it. Does that read as obvious, or did you expect a
   different behaviour?
3. Are any of the nine wrong, or is anything missing? Hard-coded list — changing them is free.

---

## Item 1 — the unlabelled circle *(the 2026-06-12 item)*

Open **Today** and scroll the day. Every work row says its state in a word: **To do** / **Done** /
**Skipped**.

**To see all three, resolve two rows:** tap **Complete** on one chunk and **Skip** on another. You
will then have one of each on screen at once, which is the only way to judge whether they read as a
set.

- Does a row's state read at a glance now?
- One chip on *every* work row — is that too much furniture when you see six at once?
- The chip is deliberately not tappable; Complete and Skip stay the only controls. **Does it
  nonetheless look like a button?**

---

## Item 3 — the Goals screen says what it is

Open **Goals**. One list headed **Priority order**, numbered 1–3, most important first, type as a
chip on the card. The three type sections are gone.

- Does it answer *"I don't know about this goals page"*?
- You lost "all my Regular time goals together". **Do you miss it?**
- New since you last looked: the coloured line at the left edge is taller and wider, and the goal's
  identity dot is gone. Worth a glance while you are here — you ruled on those without seeing them.

---

## Item 6 — the fork at the front door

**Goals → the "Add goal" button — now at the TOP of the list, where the text field used to be
(2026-09-08).** You get *"What are you adding?"* with two
doors:

- **Something to make time for** — *"Gets a type, a weekly budget and a priority. Canopy schedules
  it."*
- **Something that restores you** — *"Never scheduled. Never counted toward a budget or a streak."*

This is the guitar friction: marking something energising no longer forces it to become a goal.

- **Do you believe the promise on the second door?** It is load-bearing. If you do not believe
  restoratives are truly never scheduled, the feature does not work.
- It costs one extra tap on every add, including the times you did just want a goal. Worth it?

---

## Item 6b — **CLOSED 2026-09-08, and not by answering the question**

It was answered by use instead. He added a goal called "help" through the quick-add field, tried to
get rid of it, and reported both halves of the problem:

> *"i added one called help. i did discard and it didnt work."*
> *"it's the fact there's 2 'add goal' flows. one on the top with text, one on the bottom with
> guiding. i want the one on the bottom to be where the text one is."*

**The narrowing was not acceptable, and the fix is a move rather than an addition.** The guided path
(fork → form) now sits at the top of the list where the quick-add field was; the FAB is deleted.
There is exactly one way to add a goal and it asks what kind first. `shots/19…`, `shots/20…`

Separately, the **"Discard"** on the *Edit Goal* sheet now reads **"Cancel"** — it always discarded
the *edits*, never the goal, and the word said otherwise. **Archive goal** is what removes one.

---

## What is NOT in this round

- **Item 2** (free time vs break) — you judged it three times and it is closed: work is a flat white
  card, free time is a hatched grey one, a break is a flat tinted one.
- **Item 4** (the progress line) — closed 2026-09-03 on your "go ahead". Red now paints an 8×12px
  mark instead of a 5×6px speck, 0% shows a red stub instead of nothing, and the meaningless
  identity dot is gone.
- **SEED-006** — closed. Goals and the scheduler can no longer disagree about Monday.

## Evidence for what is already closed

`shots/13-three-kinds-of-time.png` · `14-tinted-breaks-timeline.png` ·
`15-progress-line-item4.png` · `16-progress-line-zoom.png` · `17-restoratives-current.png` ·
`19-one-add-path.png` · `20-fork-from-the-top.png`
