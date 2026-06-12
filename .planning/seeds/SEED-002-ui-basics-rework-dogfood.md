---
id: SEED-002
status: dormant
planted: 2026-06-12
planted_during: v1.1 "Actually Daily" (post-milestone dogfood)
trigger_when: planning the next milestone — this is the dominant signal from the first real dogfood; likely becomes a "UI basics" milestone
scope: large
---

# SEED-002: UI-basics rework — first dogfood findings (Dan, web debug build)

Source: Dan's 6.5-min narrated walkthrough of the Canopy web debug build (feedback-drop
2026-06-12_13-09-45). His verdict, verbatim: *"The basics just aren't here yet… we still
need quite a bit of rework on just the basics of the UI."* This is the first time the app
was driven end-to-end by a real user, and the dominant signal is **UI/UX foundations**,
not engine logic. Most items below are NOT in [[SEED-001-engine-product-critique]]; the
overlaps are called out.

## Why This Matters

v1.1 shipped 21/21 requirements "complete on paper and in code." The first real walkthrough
says the lived product needs foundational UI rework before daily use. This **strongly
confirms SEED-001 finding #7** (the tracker isn't a mirror of the lived product). These are
not nitpicks — Dan wants them addressed "decisively, head-on."

## When to Surface

**Trigger:** Next milestone planning. Strong candidate to *be* the next milestone ("UI
basics / make it usable"). Surface alongside SEED-001.

## Scope Estimate

**Large** — a full milestone. Touches onboarding flow, goals screen, goal form sheet,
check-in screen, home/schedule information architecture, and chunk row UI.

## Findings (grouped)

### A. Information architecture
1. **Landing page is wrong.** After onboarding the app lands on **Goals**. Dan: *"Home
   should be the landing page,"* not Goals.
2. **Home vs Schedule feel redundant.** Home's "Up next" card duplicates the Schedule; Dan
   cares about the schedule and isn't sure Home and Schedule should be separate pages at
   all. *"I don't know why this shouldn't look like the schedule."*

### B. Goals screen
3. **Purpose is unclear.** *"I don't know about this goals page."* The drag handles (the
   "two slashes," ≡) imply reordering but it's not obvious it works or that the page IS a
   prioritization view. → Make the prioritization purpose explicit; show "what my goals are
   and how focused I am."
4. **Priority colors are confusing.** Setting a goal high turned it purple; low didn't
   visibly change; *"the colors are changing, it's not making a ton of sense."* → Priority
   needs a legible, meaningful visual language. (Adjacent to SEED-001 #4, but Dan's
   complaint here is legibility, not the engine inertness — the inertness was not tested.)

### C. Goal form sheet (Add/Edit goal)
5. **Sheet is too tall → forces awkward scrolling; Priority + Save fall below the fold.**
   *"It's taller… this UI isn't gonna work because you've got to scroll like this… we
   should rethink the UI on this."* (Frame 0027 confirms the cutoff.) → Redesign the
   add/edit goal sheet to fit the viewport.

### D. Check-in screen
6. **Low-contrast yellow.** The warmed amber check-in background makes text/icons *"really
   hard to read."* (Frame 0049.) → Fix contrast/legibility of the mood theme.
7. **No hover states** on the mood options.
8. **"Want a lighter day?" toggle is broken UX — DIRECTLY CONFIRMS SEED-001 #1.**
   - It appears *"no matter what I click"* (regardless of mood selected).
   - Its on/off state is unreadable: *"I can't tell if it's on or off… it doesn't look like
     if it's on or off to me."*
   - Suggested flow: don't show it inline; after picking a day and hitting "Let's go," *then*
     ask *"do you want to push forward or a lighter day?"*
   → This is the SEED-001 #1 default-lighter-day concern, now confirmed AND compounded by a
   toggle whose state can't be read.

### E. Schedule / chunk rows
9. **Discretionary chunks show frequency, not a time — PARTIALLY CONFIRMS SEED-001 #5.**
   Commitment ("Work") chunks show real clock times (9:00 AM, 9:25 AM…), but discretionary
   goals (Vibe coding, Cleaning) show *"5x/week"* as the subtitle. Dan: *"I see 5x a week
   instead of the time I'm supposed to be doing it. I want the current time, what I'm doing,
   when it ends, how long… what am I doing right now, what's next, what time am I done."*
   → Show real times on discretionary chunks; reframe Home/Schedule around now/next + clock.
10. **Chunk action affordance is unclear.** *"There's a mark-complete button and a skip, but
    there's a little circle next to it — really unclear UI for a human."* (Frames 0061/0071:
    each row has an unlabeled circle; "Mark complete" only shows on hover.) → Make
    complete/skip obvious and labeled.

### F. Onboarding (mostly fine, one ghost)
11. Commitment setup, weekday picker, and goal naming all worked — *"this part is fine."*
12. **Unreproduced first-run bug:** on his very first pass, something after onboarding
    *"didn't"* behave right and he *"had feedback,"* but it didn't recur on the second run.
    Couldn't reproduce. Flag to watch — possibly an onboarding→landing redirect or
    first-cold-launch timing issue.

## SEED-001 cross-reference (what this dogfood did/didn't test)
- **#1 lighter-day default → CONFIRMED** (item 8), plus a legibility defect.
- **#5 synthetic times / silent drop → PARTIALLY CONFIRMED** (item 9: wants real times;
  silent-drop not specifically hit).
- **#4 priority inert → NOT directly tested** (item 4 is about color legibility).
- **#2 low-mood zeroing time-targets, #3 habits monopolize cap, #6 streaks → NOT reached**
  (he didn't test a low mood or multi-day history).
- **#7 "looks done on paper, isn't in practice" → STRONGLY CONFIRMED** (his whole verdict).

## Breadcrumbs
- **In-repo walkthrough package:** `.planning/research/dogfood-2026-06-12/` — see `INDEX.md`.
  Includes `transcript.txt`, `annotated.md`, all 70 `frames/`, and 5 legible
  `key-frames-cropped/` (0027 goal sheet, 0049 check-in, 0058 home, 0061 schedule, 0071
  chunk hover). **Start with the cropped key frames + INDEX.md.**
- Original drop: `~/feedback-drop/canopy/inbox/2026-06-12_13-09-45/` (recording.mp4).
- Likely files: `lib/screens/goals/goal_form_sheet.dart` (D5), `lib/screens/goals/goals_screen.dart`
  (B3/B4), `lib/screens/schedule/checkin_screen.dart` (D6-8), `lib/screens/home/` +
  `lib/screens/schedule/schedule_screen.dart` (A/E9), `lib/screens/schedule/widgets/chunk_card.dart`
  (E10), `lib/router.dart` (A1 landing).

## Notes
First real-use signal. Points hard at a UI-foundations milestone. Pair with SEED-001 when
scoping next.
