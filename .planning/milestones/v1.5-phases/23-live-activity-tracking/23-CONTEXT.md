# Phase 23: Live Activity Tracking - Context

**Gathered:** 2026-08-07
**Status:** Ready for planning
**Mode:** Design agreed with Dan via sketch 001 (`.planning/sketches/001-unified-today/`). The
countdown-granularity question the ROADMAP deliberately left open is now **decided** — see below.

<domain>
## Phase Boundary

The unified Today screen (Phase 22) always tells the truth about what is happening right now,
including breaks, with a live countdown.

Requirements in scope:
- **LIVE-01**: The screen always names what the user is doing right now, including breaks — a running break reads as a break, never as empty time
- **LIVE-02**: Time remaining in the current activity is shown and counts down while the screen is open
- **LIVE-03**: The honest edge states survive the merge — before the day starts, between activities, and day-complete each read truthfully

Depends on Phase 22 (the merged screen this behaviour lands on).

</domain>

<decisions>
## Implementation Decisions

### LOCKED by design review (Dan, 2026-08-07)

1. **Countdown granularity — resolves the ROADMAP's open question.**
   Show **whole minutes** while more than one minute remains ("3 min left"), then switch to a
   **seconds countdown** in the final minute ("42s left"). Rationale from review: a per-second
   clock running all day reads as pressure; in the last minute it reads as "about to change".
   Consequence for implementation: the screen does **not** need a 1-second repaint for most of a
   chunk. A per-minute tick suffices until the current activity has <60s left, at which point a
   faster tick may run. Do not blanket-replace the existing 1-minute `Timer.periodic`
   (`home_screen.dart:263`) with a 1-second timer — that is the lazy version of this decision and
   costs battery on a screen that is open all day.
   Minutes should round **up** (`ceil`) so a running activity never reads "0 min left".

2. **Breaks are a first-class current activity.** `resolveNowState`
   (`home_screen.dart:115`) currently filters to **work chunks only** — this is the root cause
   of the reported bug: during a break it returns `GapBeforeNext` ("next chunk at 8:00") instead
   of "on a break". Break chunks must participate in now-resolution.
   - Copy: "Taking a break" for a short break, "Taking a long break" for a long one, under a
     "RIGHT NOW — RESTING" kicker.
   - **A break shows no Complete/Skip actions.** There is nothing to complete about a break.
     Work chunks keep their labelled Complete/Skip affordances (SCHED-03, v1.2).

3. **Edge-state copy (LIVE-03).** Each state reads distinctly and without nagging:
   - *Before the day starts*: "Nothing until 8:00am — the day starts with Exercise. Until then
     the time is yours." Dan explicitly liked seeing "nothing until 8"; keep that feeling.
   - *In a gap*: named as free time inline (Phase 22 decision 5).
   - *Day complete*: "That's the day. Everything scheduled is behind you." — a finish line, not
     a score.

4. **Progress bar** on the current activity, filling left-to-right across its window. Present in
   the winning sketch; keep it.

### Care with the existing state machine

`resolveNowState` carries a documented KEY INVARIANT — *the clock window is found FIRST by time,
THEN resolution is checked* — which exists to prevent regressing to the old "first unresolved
chunk" bug (Phase 17, NOW-01). Extending it to breaks must preserve that ordering. Its five
subtypes (PreStart / Active / Overdue / GapBeforeNext / DayComplete) are the extension point;
adding break-awareness should not collapse or bypass them.

Its unit tests live in `test/screens/active_chunk_card_test.dart` (the `resolveNowState` group,
with injectable `now` suppliers) — extend them rather than replacing the pattern. The injectable
clock is what makes this testable without sleeping; keep it and use it for the <60s branch.

</decisions>

<code_context>
## Existing Code Insights

- `resolveNowState` + the `NowState` sealed class: `lib/screens/home/home_screen.dart:28-115`.
- Tick: `Timer.periodic(const Duration(minutes: 1))` at `home_screen.dart:263`, lifecycle-managed
  (started/cancelled around app pause) — follow that pattern for any faster tick, and cancel it
  when the current activity is not in its last minute.
- `lib/screens/home/widgets/active_chunk_card.dart` — today's "now" card; the merged screen's
  live row descends from it.
- Break chunk types: `ChunkType.shortBreak` / `ChunkType.longBreak`; chunks carry
  `displayStartMinutes` / `syntheticStartMinutes` / `anchoredStartMinutes` and
  `reservedBreakMinutes` (see `schedule_generator.dart` STEP C).
- Frame-of-reference note in the `resolveNowState` doc comment: `displayStartMinutes` is compared
  against LOCAL wall-clock minutes-from-midnight, never `.toUtc()`. Do not "fix" that here.

</code_context>

<specifics>
## Specific Ideas

The reference behaviour is running in the sketch — `.planning/sketches/001-unified-today/`,
variant A, toolbar state **"Last minute"** demonstrates the minutes→seconds switch
(verified: "3 min left" → "41s left").

</specifics>

<deferred>
## Deferred Ideas

- Start/stop focus timer per chunk (clock-in tracking). "Active tracking" here means *the app
  tells you where you are*, not *you clock in and out* — confirmed with Dan. `/focus` already
  exists; leave it alone.
- Notification that fires when a break ends — not in v1.5 scope.

</deferred>
