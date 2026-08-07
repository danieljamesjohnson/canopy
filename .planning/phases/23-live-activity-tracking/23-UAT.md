---
status: testing
phase: 23-live-activity-tracking
source: [23-VERIFICATION.md, 23-04-PLAN.md]
started: 2026-08-07T23:10:00Z
updated: 2026-08-07T23:10:00Z
---

## Current Test

number: 1
name: Countdown smoothness across the 60-second handover
expected: |
  In a real GPU-backed browser, the live row's remaining time counts down without stutter, and the
  handover from "1 min left" to "59s left" happens cleanly with no flicker or double-update.
awaiting: user response

## Tests

### 1. Countdown smoothness across the 60-second handover

expected: The countdown moves without stutter, and the minutes→seconds handover at 60s is clean — no flicker, no double-update, no visible jank on the ~900-line screen.
result: [pending]

**Repro:** Open `http://danserver:8123` in a real browser during a chunk or break with ~90 seconds
left. Watch the live row across the 60-second boundary.

**Why human:** Widget tests prove the string changes on a pumped tick. They cannot judge whether the
real render updates smoothly. Headless screenshots (which I used) capture single frames, not motion.

**Already verified by agent — do not re-check:** the seconds branch renders (`12s left · until 6:55 PM`
observed live), the minutes branch renders (`13 min left`), and the full suite has zero pending-timer
failures across 459 tests.

### 2. A running break genuinely reads as rest

expected: When a break is the current activity, the live row reads as intentional rest, not as dead or idle time, and not as an instruction.
result: [pending]

**Repro:** Open the app during a scheduled break (or shift the clock) and read the live row.

**Why human:** Tone judgment. Verified mechanically: kicker `RIGHT NOW — RESTING`, title "Taking a
long break", time remaining shown, Complete/Skip correctly suppressed, and "Next · <work chunk>"
naming what follows.

### 3. Decision P-1 — the gap banner

expected: An explicit keep-or-remove verdict from Dan.
result: [pending]

**Context:** `23-UI-SPEC.md` specified new copy for PreStart and DayComplete but said nothing about
the `GapBeforeNext` state. Planning decided **no change**, reasoning that `GapFreeRow` renders a
*duration* ("Free · 1h 40m") but never a *name*, so removing the banner would delete the only place
the screen says what is coming — making the gap read less truthfully, not more. The gap's one real
change is behavioural: it now names a break correctly when the next activity is one.

**Why human:** This is a design call the spec left open, not a defect. It needs your yes or no.

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Notes

Agent-verified live against the served debug build (clock shifted, real persisted schedule
re-resolved) — recorded here so these are not re-tested by hand:

| Requirement | Observed |
|---|---|
| LIVE-01 | `RIGHT NOW — RESTING` / "Taking a long break" / "13 min left · until 6:55 PM", no Complete/Skip, "Next · Reading at 6:55 PM" |
| LIVE-02 | `12s left · until 6:55 PM` — the sub-minute branch |
| LIVE-03 | PreStart "Nothing until 5:35 PM" / "The day starts with Exercise. Until then the time is yours."; DayComplete "That's the day." / "Everything scheduled is behind you." |

A BLOCKER was found and fixed mid-phase and is worth knowing about: an earlier review iteration added
a debug `assert` to `resolveNowState`; the next iteration proved with a reproduction that
`ScheduleNotifier.addEventToday` could leave a trailing break — which would have **crashed the debug
build**, i.e. the build hosted for UAT, on an ordinary Commitments edit. Fixed on both sides
(`_trimTrailingNonWork()` on write, assert removed on read after confirming the `DayComplete` boundary
check never depended on chunk type). The underlying `addEventToday` gap was pre-existing (since
2026-07-01) and previously caused a quietly-wrong result rather than a crash.

## Gaps
