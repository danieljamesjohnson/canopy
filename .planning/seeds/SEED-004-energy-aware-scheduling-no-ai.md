---
id: SEED-004
status: harvested
planted: 2026-06-13
planted_during: v1.2 dogfooding (regular-time / family-time friction session)
trigger_when: designing energy-aware scheduling, or the next milestone after "regular time fills open days" lands
scope: medium-large
---

# SEED-004: Energy-aware scheduling for a "dumb" (no-AI) app

The app is a **time-budgeting app with no AI** — a deliberate constraint. It can't *infer* that "family time" is restorative and "tax paperwork" is draining. But the lived insight from dogfooding is real: **on low-energy days, the schedule should lean toward activities that *give* energy, not just strip everything down to required-work + habits.** The question this seed holds: how does a dumb app get that right without an LLM?

## Why This Matters

Today the engine treats every discretionary goal through one productivity lens — chunks, streaks, hour-budgets, urgency. It has no concept of *valence* (does this activity create or cost energy?). So:

- On low ("stormy") days it suppresses time-target goals entirely (`schedule_generator.dart:315`), which strips out exactly the family/wellness/restorative things that might recharge the user. (See also SEED-001 #2.)
- On high ("sunny") days it just raises the cap and grinds the highest-urgency backlog — it doesn't bias toward "spend this good day on what matters."

The app can't know which activities are restorative **unless the user tells it.** That's the whole design move: push the intelligence into a one-time, low-friction user declaration, then let dumb rules act on it.

## The Idea: user-declared energy valence

When a user creates a goal/habit, capture a cheap signal of *what kind of activity this is*:

- **"Does this give you energy or cost you energy?"** — a simple 3-way pick at creation (gives / neutral / costs). Dumb, explicit, no inference.
- Possibly a **text + image categorizer** — let the user tag with a word/emoji/image so the activity reads as restorative-vs-draining at a glance, and so a future rules layer has a coarse category to switch on. (Open question: is the image categorizer worth the build, or does a 3-way valence pick get 90% of the value? Lean toward the pick first.)
- A standalone **"what gives you energy?"** prompt during onboarding — seed a couple of restorative activities up front so low days have something good to schedule.

Then the dumb rules become possible:

- **Low day:** required/commitments + habits + *energy-giving* discretionary goals (instead of zeroing all time-targets). Rest/family is often the right call on a stormy day.
- **High day:** still grind the backlog, but reserve at least one slot for a high-value/energy-giving goal so good days aren't 100% throughput.

## Relationship to what shipped in this session

- **Regular-time goals now default to 3 hrs/week** (editable) so they actually schedule — DONE, not part of this seed.
- **"Regular time fills open days"** (claim leftover capacity for time-target goals when nothing else is due) — proposed, likely the immediate next build; this seed assumes that lands first.
- Low-day policy confirmed as **required + habits only** *for now* — this seed is the path to making low days smarter (energy-giving) later, without AI.

## Scope Estimate

**Medium-large** — a new `Goal` field (energy valence) + Hive migration, creation-flow UI (the pick, optionally the categorizer/onboarding prompt), and an engine pass that switches allocation on valence per mood tier. The image categorizer, if pursued, is the biggest and most optional piece.

## Open Questions

1. Is a 3-way valence pick enough, or is the text+image categorizer worth it?
2. How does valence interact with priority and the mood cap — override, tiebreak, or reserved slots?
3. Does "energy-giving on low days" risk letting users avoid hard-but-required work? (Required/commitments still run regardless, so probably fine.)

---

## HARVESTED — 2026-08-31

The core design move — **user-declared valence rather than inference** — shipped, and the "dumb app"
constraint held throughout: no LLM was added.

- **The 3-way gives/neutral/costs pick → shipped** as ENERGY-02/ENERGY-04b (Phase 19 Energy
  Valence), with the engine acting on it in Phase 20 (Valence-Aware Engine).
- **The standalone "what gives you energy?" capture → shipped** as the `RestorativeItem` aggregate
  (Hive typeId 7, schema 8→9) via the Mission Control JTBD loop, deliberately separate from goals:
  never scheduled, never counted toward budgets or streaks. Surfaces as chips on the Today screen
  when mood ≤ 2 — which is exactly this seed's "low days should have something good to schedule."
- **The image categorizer → not built, and the seed's own lean was correct**: the 3-way pick got
  the value.

**Remaining: two entry-point frictions the owner found while using it** — quick-pick common
restoratives, and "energizing ≠ goal" (the guitar friction). **Both carried into Phase 33.**
The scheduling model itself needs nothing further.
