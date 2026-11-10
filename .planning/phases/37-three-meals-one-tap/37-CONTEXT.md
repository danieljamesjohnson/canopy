# Phase 37: Three Meals, One Tap — Context (DECIDED 2026-11-10)

**Status:** decided. The draft below was written by the agent on 2026-11-09 at the owner's request; the owner
approved it on **2026-11-10** ("full send") and ruled every OPEN item. The rulings are recorded under
**DECIDED** below, replacing the OPEN section. PROPOSED items not contradicted by a ruling are adopted as written.

## The ask, in the owner's words (2026-11-09)

> "add breakfast / lunch / dinner to onboarding. assume some times, some lengths, etc. allow the person
> to edit but have the default be one button press and they go. ie: breakfast 7-7:30, lunch 12-1,
> dinner 6-7. they can easily adjust or disable a meal (that they skip)."

**Goal:** a new user's day has room to eat, with one tap. The common case is three pre-filled meals and a
single button; the uncommon cases are a quick time change or switching a meal off.

## What already exists (so this is small)

- **Onboarding** (`lib/screens/onboarding/onboarding_screen.dart`) is a four-beat `PageView`: Goals →
  Recharge → Energy → Job. The Job beat is the closest analogue: it opens fully pre-filled (M–F 9–5) and
  one tap saves it. That is exactly the "default is one button press" pattern asked for.
- **Commitments are already the right primitive.** A `CommitmentBlock` is a fixed window the engine
  schedules around.
- **The engine already has "one solid block, no breaks inside"** for calendar meetings (D-36-06), and as of
  WINDOWS entry 19 (2026-11-05) **a hand-entered block yields to a meeting**. Meals want both behaviours.
- `commitmentWindowTooShort` rejects windows under 25 min, because a lattice needs one chunk. A meal is
  one block with no lattice, so that floor does not apply to it (see OPEN-4).

## PROPOSED design

1. **A fifth onboarding beat, "When do you eat?"**, placed after Job.
   - Three rows: 🍳 Breakfast 7:00–7:30, 🥪 Lunch 12:00–1:00, 🍝 Dinner 6:00–7:00.
   - Each row has an on/off switch and tappable start and end times, using the same time picker the Job
     beat uses.
   - Primary button: **"Looks good"**, which saves the switched-on meals and finishes onboarding.
2. **Meals are `CommitmentBlock`s with a new `kind` field** (`HiveField(9)`, additive; null means a
   hand-entered commitment). This is not a new model.
   - Each meal is recurring on all seven days.
   - It is placed like a meeting: **one solid block covering its own window, with no 25+5 lattice inside**
     (reuses the D-36-06 branch in `buildCommitmentChunks`).
   - It has its own fixed colour in the schedule palette, kept clear of Work (tertiaryContainer) and of
     meetings (orange). Per D-36-07, mood never colours the timeline.
   - It shows a meal glyph rather than Complete/Skip, or a simple "Eaten" tick (see OPEN-3).
3. **A meal inside Work carves Work**, exactly as a meeting does: the entry 19 `yieldTo` path, extended to
   meals. A 9–5 Work block with lunch 12–1 becomes 9–12 and 1–5, each with its own lattice, so lunch is
   never drawn under Work's breaks.
4. **Existing users** have already finished onboarding, and the owner is one of them. They get a
   **Settings → Meals** screen with the same three rows. **PROPOSED:** no one-time prompt; Settings only
   (see OPEN-5).
5. **Day window.** Discretionary packing starts at 08:00 (`ScheduleGeneratorService.dayStartMinutes`), so
   a 7:00 breakfast lands before it. Anchored commitments can sit outside that window, and the timeline
   renders from the first chunk, but this must be **proven with a test and on the emulator**, not assumed.
   It is the phase's riskiest assumption.
6. **Check-in timing.** If you check in at 7:45, breakfast is already past. **PROPOSED:** it still shows,
   like any past commitment, and mood capacity is unchanged, because a meal is not counted against the
   chunk cap.

## DECIDED — the owner's rulings (2026-11-10)

- **D-37-01 — Meeting vs meal: the MEETING wins.** The meal is carved by the meeting window with the
  same `subtractWindows` the entry 19 path uses. Leftover pieces shorter than **10 minutes** are dropped;
  if nothing is left, the meal does not appear that day. No "slide lunch to a free hour" — that is smart,
  and the engine stays dumb and predictable.
- **D-37-02 — Same times all seven days.** No per-day editing in this phase.
- **D-37-03 — Meals are NOT tracked.** No Complete/Skip, no effect on streaks, history, the chunk cap or
  mood capacity. A meal is a block on the timeline with a meal glyph, nothing more.
- **D-37-04 — Minimum meal length is 10 minutes.** The 25-minute lattice floor stays for ordinary
  commitments.
- **D-37-05 — Existing users get Settings → Meals only** (the same three rows); no one-time prompt card on
  Today. The owner is an existing user, so this screen is how he will test the feature.
- **D-37-06 — Snacks and extra meals are out of scope.**
- **D-37-07 — PROPOSED design adopted as written:** a fifth onboarding beat after Job; defaults Breakfast
  7:00–7:30, Lunch 12:00–13:00, Dinner 18:00–19:00, each with an on/off switch and editable start/end;
  the primary button **"Looks good"** saves and finishes in one tap. Meals are `CommitmentBlock`s with an
  additive `kind` field; one solid block, no 25+5 lattice; their own fixed colour, apart from Work and
  meetings (mood never colours the timeline, D-36-07); hand-entered commitments (Work) yield to meals
  exactly as they yield to meetings. The riskiest assumption — a 7:00 breakfast against
  `dayStartMinutes` = 480 — must be proven by a test **and** on the emulator.

### Implementation choices made by the agent within those rulings (recorded, not owner rulings)

- **`kind` is `HiveField(9)` on `CommitmentBlock`** — verified free (fields 0–8 are used, generated
  adapter writes 9 fields). Values `breakfast` / `lunch` / `dinner`; null = an ordinary commitment.
  Nullable, so old records read it as null with no migration step; a round-trip test writes the
  pre-37 9-field binary and reads it back.
- **A meal's chunk is a new `ChunkType.meal`** (index 3, appended — existing persisted indices 0–2 are
  unchanged). This is how D-37-03 is enforced structurally rather than by remembering to check a flag:
  every "count the work chunks" site (end-of-day, progress bar, check-in, focus, Complete/Skip, swipe)
  already filters on `ChunkType.work`, so a meal is excluded by construction.
- **Switching a meal off deletes its block.** Settings → Meals with no meal blocks at all shows the three
  defaults switched on, so an existing user's first visit is the same one tap as onboarding.
- **Meals are hidden from the Commitments screen** — they are edited in Settings → Meals, where the
  10-minute floor applies, not in the commitment form, where the 25-minute floor would reject them.
- **Today is not rebuilt on save** (trap #4): Settings → Meals says so in its confirmation and the UAT
  makes ⟳ Re-check-in the mandatory first step.

## Verification shape (for the planner)

- Engine:
  - generate() with Work 9–5 and lunch 12–1 leaves nothing of Work under lunch (mutation-proven, reusing
    the entry 19 test shape);
  - a meal is one chunk;
  - a switched-off meal produces nothing;
  - breakfast at 7:00 survives the 08:00 day start.
- Onboarding:
  - one tap on "Looks good" persists exactly three blocks with the default times;
  - switching dinner off persists two;
  - editing lunch to 12:30–1:15 persists that window.
- Device: the emulator loop in CLAUDE.md (screenshots of the onboarding beat and of Today with the meals),
  then the owner's iPhone.

## Not this phase

- Meal suggestions, nutrition, or anything "smart". CLAUDE.md's product position applies.
- The watch milestone (v1.7), planned separately.
