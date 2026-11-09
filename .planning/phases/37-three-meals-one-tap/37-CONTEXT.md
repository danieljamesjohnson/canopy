# Phase 37: Three Meals, One Tap — Context (DRAFT, awaiting owner discussion)

**Status:** pre-discussion draft written by the agent on 2026-11-09, at the owner's request: *"do some gsd
planning to get these ready to go when i come back then we'll discuss and kick it off"*. Nothing here is
ruled yet. Items marked **PROPOSED** are the agent's defaults. **OPEN** items need the owner's call before
`/gsd-plan-phase 37`.

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

## OPEN — the owner's calls

1. **When a meeting overlaps a meal, who wins?** (For example, a 12:30 meeting during a 12–1 lunch.)
   - **(a) The meeting wins:** lunch shrinks to what's left (12–12:30), or disappears if nothing is left.
   - **(b) Both show**, side by side.
   - **(c) The meal wins:** the meeting still imports, but is flagged as a clash.
   **Agent recommends (a):** a meeting is someone else's time, and a meal is yours to move. Better still,
   lunch could slide to the nearest free hour. That is "smart", though, and may cross the product line,
   so (a) is the dumb, predictable version.
2. **Same times every day, or different on weekends?** **PROPOSED:** same every day in onboarding, with
   per-day editing later in Settings → Meals if wanted.
3. **Is a meal trackable?** Does it get Complete/Skip like a work chunk (feeding streaks and history), or
   is it just a block on the timeline?
   **PROPOSED:** not tracked, just a block. It is not a goal, and Canopy does not need to know whether
   you ate.
4. **Minimum meal length.** **PROPOSED:** 10 minutes for meals; the 25-minute floor stays for lattice
   commitments.
5. **Existing users.** Show a one-time "Add your meals?" card on Today, or only add Settings → Meals?
6. **Snacks and other meals** (a 3pm snack, second breakfast): out of scope for this phase?
   **PROPOSED:** yes, out of scope. The three-row screen is the whole feature; anything else is a
   hand-entered commitment.

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
