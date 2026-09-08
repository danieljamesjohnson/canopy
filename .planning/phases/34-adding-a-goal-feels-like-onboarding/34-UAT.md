# Phase 34 UAT — Adding a Goal Feels Like Onboarding

**URL:** **http://danserver:8143/**
**Bundle sha256:** `b479e2c449f0b0bf…` — identical on disk and on the wire
**Suite:** `flutter analyze` clean · `flutter test` **740 passing** (706 before this phase)

---

## Step 0 — do NOT press ⟳ Re-check-in. Here is the reason, not the rule.

Phase 33's script required Re-check-in. **This one does not**, and the reason is specific rather
than habitual: CLAUDE.md's trap #4 binds only when a phase's diff touches
`schedule_generator.dart`, because an already-generated day is never regenerated on load. **Phase
34 does not touch the generator at all** — it changes how a goal is *added*, not how a day is
*built*. Your existing day will render this phase's changes correctly.

If you happen to judge scheduling output while you are in here, the rule binds again and you would
need Re-check-in first — but nothing below asks you to.

---

## What you are actually judging

You ruled **(a)**: tapping a preset creates the goal on the spot. The thing to judge is whether that
feels right *and* whether the safety net holds — that a goal created in one tap still tells you what
it committed you to.

**Items 1–4 need your eyes or thumb.** Item 5 and 6 are the two changes you did not ask for, and
they need a yes/no from you specifically because you did not ask for them.

**Already settled, do not re-judge:** the goal gets created (13 widget tests), the emoji reaches the
model (asserted, and visible as "🏃 Exercise" on the Today timeline), the concurrent-tap races are
fixed (9 regression tests, both defects reproduced before fixing), and the picker renders correctly
on a 390×844 phone viewport (driven and screenshotted). None of that needs your time.

---

## Item 1 — the flow itself · **does adding a goal now feel like onboarding?**

**Goals tab → `+ Add goal` → "Something to make time for".**

You should get a sheet titled **Add a goal** with a **Common** row of emoji chips, an **Add your
own** button under it, and **Done** at the bottom.

The question is the one you raised: *"i wish the goal screen worked easily like the onboarding.
where there were options and emojis and such."*

**Does it?** — PASS / FAIL, and if FAIL say what is missing rather than what is wrong.

---

## Item 2 — the thumb count. **Give me a number, not an impression.**

Still in that sheet: **tap five different preset chips in a row**, at normal speed, one thumb, no
aiming.

**How many landed on the first try? ___ / 5**

**Why this is phrased as a number.** It has been asked five times across Phases 32 and 33 and
returned five variations of "it seems to work" — which describes the mechanism firing, not the
target being hittable. It was finally closed in Phase 32 only by asking for a count. A wrong number
is far more useful here than a right adjective.

---

## Item 3 — the safety net · **does a one-tap goal tell you what it cost you?**

This is the whole reason (a) was safe to build. You chose one-tap creation knowing it assigns a type,
a weekly budget and a priority you never picked. The deal was that it would not *hide* them.

Tap one preset chip. A card appears under **Just added**.

1. **Without hunting for it — does that card tell you the weekly commitment you just made?**
   It should read `3.0 hrs/week` on its face.
2. **Tap that card.** It should open the full goal form, ready to change any of it.

**PASS / FAIL.** If you have to look for the number, that is a FAIL even though it is on screen —
the "help" goal became a three-hour commitment because nobody *noticed*, not because nothing was
rendered.

---

## Item 4 — "add your own" · **is typing your own still as easy as tapping one?**

In the same sheet, tap **Add your own**. It opens the normal goal form, blank.

**Deliberately NOT a text box.** The bare quick-add field was deleted on 2026-09-08 because it
created goals with a 3.0 hrs/week budget nobody chose — the "help" defect. Putting a field back on
this screen would have re-created it. So "add your own" is a button into the real form instead.

**Is that an acceptable trade, or does it feel like a step backwards from just typing?** This is a
genuine question, not a leading one — if it feels worse, say so and we will look at it again.

---

## Item 5 — a change you did NOT ask for: **onboarding's chips look different**

Onboarding and the Goals screen now share one chip widget, which is the point — there were two
private copies of the same idea and a third would have been worse. But sharing one widget means
**onboarding's chips changed shape and gained emoji.**

You can see it at **Settings → (re-run onboarding)**, or take my word from the screenshot in
`shots/`.

**Accept / Reject.** Rejecting is cheap and does not undo the phase — it means onboarding keeps its
old chip look and we accept two rendering paths.

---

## Item 6 — a second change you did NOT ask for: **"Walk" became "Walk outside"**

Onboarding had its own hard-coded restorative list and the restoratives screen had another, and they
disagreed — onboarding said `Walk`, the restoratives screen said `Walk outside`. They now share one
list, so onboarding shows the restoratives screen's wording.

**Accept / Reject.** Same as above — this is a wording change on a screen you did not ask about, so
it should be your call rather than a silent tidy-up.

---

## Open, and honestly still open

- **The preset words and emoji are a first pass.** 🏃 Exercise · 📚 Reading · 👨‍👩‍👧 Family time ·
  💻 Side project · 🌱 Learn something · 🌲 Outdoors · 🎨 Creative time · 😴 Rest. It is one const in
  one file — rewrite any of it on sight, it is cheap.
- **The nine restorative chips' thumb count was never taken.** It was asked five times and closed
  unmeasured when you accepted Phase 33 by review. Phase 34 changed the widget those chips render
  through, so if item 2 goes badly, that is the first place to look.

---

## How to answer

Item numbers and a verdict each is plenty. For item 2 I need the digit.
