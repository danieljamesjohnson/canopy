# Phase 34 UAT — Adding a Goal Feels Like Onboarding

> ## ✅ ACCEPTED BY THE OWNER — 2026-09-09
>
> He ran the flow on the build and said: *"i ran throught hte prcess. i'm satisfied with teh flow.
> close it out."* **Phase 34 is closed on that verdict.**
>
> **Recorded as what it is: a blanket acceptance of the flow, not six itemised verdicts.** That is
> real evidence — he is the person the phase is for, and he used the thing — but it is not the same
> as a per-item round, and two specific things it does NOT contain are worth carrying forward rather
> than burying under a green tick:
>
> **1. The thumb count was never given. Again.** Item 2 asked for a digit (n/5). It has now been
> asked across Phases 32, 33 and 34 and has never been answered as a number. **Do not cite this
> phase as having established that preset chips are thumb-hittable.** What we DO have is the target
> measurement taken in the agent round: **34dp tall against Material's 48dp minimum** — clears the
> guideline on area, 14dp short on height. If chip mis-taps are ever reported, that number is the
> first place to look and no further investigation is needed to know where to start.
>
> **2. Finding B was not ruled on.** `_newDefaultGoal` assigns `weeklyHourBudget: 3.0`, both
> onboarding paths use it, and `onboarding_screen.dart` renders a budget nowhere — so onboarding
> still creates goals carrying a commitment the user was never shown at the moment they made it. The
> amended GOALADD-03 says "no add path". Onboarding is one. This is **carried to `SEED-007`**, not
> silently accepted: the owner's "satisfied with the flow" was about the Goals screen he was asked
> to judge, and reading it as a ruling on an onboarding defect he was not walked through would be
> putting words in his mouth.
>
> Items 1, 3, 4 and 5 are fairly covered by the blanket acceptance — they are all "does this flow
> feel right", which is exactly what he answered.

> ## Agent round, 2026-09-09 — structural half closed, two findings raised
>
> The owner said "run the uat". A UAT of this phase splits into questions a browser can settle and
> questions it cannot, and the split is a property of the QUESTION, not of the item — this project
> established that in Phase 32, where "is the button there" was routed to a human three times and
> returned three non-answers, while a driver answered it in one run.
>
> Driven with `.planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs` against the served
> bundle (`b479e2c449f0b0bf`, wire hash re-confirmed identical at run time). Screenshots in `shots/`.
>
> **Closed by driving (do not re-judge):**
>
> | Item | Question | Result |
> |---|---|---|
> | 1 (structural half) | Does the sheet have chips + add-your-own + Done, in onboarding's shape? | **YES** — `shots/05-item1-side-by-side.png` puts the two screens side by side |
> | 3b | Does tapping the Just-added card open the full form? | **YES** — Edit Goal opens pre-filled (`shots/06`) |
> | 4 (structural half) | Does "Add your own" open the real blank form, not a bare field? | **YES** — blank Add Goal, name focused, nothing pre-selected (`shots/07`) |
> | 6 | Did onboarding's restorative wording change to the shared list? | **YES** — "🚶 Walk outside", all nine with emoji (`shots/08`) |
> | — | Does the picker filter goals you already have? | **YES** — Exercise absent once it exists |
>
> **Measured, because item 2 deserves a number from BOTH ends.** The owner supplies the thumb; the
> driver can at least supply the target. Preset chips render **34dp tall** (widths 80–160dp).
> Material's minimum touch target is **48dp**. The chips clear the guideline on *area*
> (2 720–5 440dp² vs 2 304dp²) but are **14dp short on height**, which is the dimension that matters
> for a thumb on a wrapped grid — vertical precision, with only 8dp of gap between rows.
> **This predicts item 2 may come back badly, and says exactly what to change if it does.** It is
> also the same 34dp on the restoratives screen now, so item 2's answer finally covers the nine
> restorative chips whose count has been open since Phase 32.
>
> ### Finding A — the second half of the sentence is NOT the same as onboarding
>
> The ask was *"the pre chosen options **plus an easy way for you to add your own**."* The side-by-side
> shows the chips match and the add-your-own does **not**: onboarding gives you an inline text field
> with a ↵; the Goals screen gives you a button into the full form. That is deliberate — a bare
> quick-add field on the Goals screen is the exact control deleted on 2026-09-08 — but it means
> **item 4 is a real open question, not a formality.** Typing your own on the Goals screen is now
> `Add goal → door → Add your own → form`, versus onboarding's `type → ↵`.
>
> ### Finding B — GOALADD-03 is met on the Goals screen and NOT met in onboarding
>
> Verified in code, not inferred. `GoalsNotifier._newDefaultGoal` (`goals_notifier.dart`) assigns
> `goalTypeIndex: timeTarget` and **`weeklyHourBudget: 3.0`**, and BOTH onboarding paths use it — the
> chip tap via `addPresetGoal` and the typed field via `quickAddGoals`. **`onboarding_screen.dart`
> never renders a budget anywhere** (grep for `hrs/week` returns only a doc comment). So a user
> finishing onboarding has goals carrying a 3.0 hrs/week commitment that was never shown at the
> moment it was made.
>
> The amended GOALADD-03 reads *"**no add path** creates a goal with attributes that are hidden from
> the user."* Onboarding is an add path. The phase's `must_haves` were scoped to the Goals screen and
> were written **before** the amendment, which is why 12/12 verified and this still slipped through.
>
> **Mitigating, and the reason this is a question rather than a defect call:** the value is not
> hidden *permanently* — the Goals screen shows `3.0 hrs/week` on every row the moment onboarding
> ends. And onboarding is a one-time flow where the user is actively laying out a slate, not a
> control they will hit absent-mindedly later, which is what made the deleted quick-add field
> dangerous. **Owner's call whether that is close enough.**
>
> **Still genuinely open and untouched by this round: items 1 (feel), 2 (the digit), 3a (is the
> number *noticed*), 4 (is the trade acceptable), 5 (accept/reject onboarding's new chips).**


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
