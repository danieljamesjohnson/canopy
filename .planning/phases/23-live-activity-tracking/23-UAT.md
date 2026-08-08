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

### 4. Should rest look different from work? (raised by the 23 UI audit)

expected: A verdict from Dan — keep the shared treatment, or give rest its own container role.
result: [pending]

**Context:** A break live row and a work live row currently share the same `primaryContainer` swell.
The only differences are the kicker suffix (`RIGHT NOW — RESTING` vs `RIGHT NOW`) and the absence of
the Complete/Skip row. The UI audit's view: that contrast is legible if you *read* it, but not at a
glance — and for an app whose pitch is quick-glance control over your time, two semantically opposite
states looking near-identical undercuts the copy that works hard to distinguish them. Suggested
alternative: give rest a distinct container role (e.g. `secondaryContainer`).

Compare `warp-plus70.png` (break) against `sec-plus82p6.png` (work) — sent to you above.

**Why human:** This is spec-locked (`23-UI-SPEC.md` chose the shared treatment) and it is a taste call,
not a defect. Changing it unilaterally would override a locked design decision. Scored 2/4 on Visuals
for this reason; everything else in the audit passed.

## Summary

total: 4
passed: 0
issues: 0
pending: 4
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

Reported by Dan at the 23-04 sign-off gate, 2026-08-08. Verbatim, then interpretation.

> Minor: lifts should be right, drains should be left on the onboarding. Long breaks should look big
> and stand out (25 minutes). I had to refresh the browser page to get the timer to start at 9:15
> (opened the app at 9:13). Time clips the edge. Once I've completed a task I should be in "break".
> 8 chunks is repeated twice at the top, when sunny day. If you choose a day type, it should tell you
> what that means (high chunk count, low break chunk count) or vice versa on a hard day

| # | Gap | Kind | Surface | Status |
|---|-----|------|---------|--------|
| G-01 | Onboarding valence segmented control is ordered `Lifts / Neutral / Drains`; should be `Drains / Neutral / Lifts` (drains left, lifts right) | polish | onboarding screen 3 (Phase 19 surface) | open |
| G-02 | A 25-min long break renders at the same visual weight as a 5-min short break — it should look big and stand out proportionate to its length | design | `chunk_card.dart` `_buildBreak` | open |
| G-03 | **Opened the app at 9:13 with a chunk starting 9:15; the live row did not appear until a manual page refresh.** The minute tick did not carry PreStart → Active | **bug** | `today_screen.dart` tick / `resolveNowState` | open |
| G-04 | Time gutter labels clip at the edge | bug | timeline gutter | open |
| G-05 | Completing a chunk should put the user *in the following break*, not in a gap/next-up state | behaviour | `resolveNowState` resolved-advance path | open |
| G-06 | Chunk count appears twice at the top ("0 of 9 Chunks" progress bar + "Sunny day · 9 chunks" mood chip) | polish | `today_screen.dart` header | open |
| G-07 | Choosing a day type doesn't explain what it means — a sunny day should say it means more chunks / fewer long breaks, a low day the reverse | design | check-in / acknowledgment copy | open |

G-03 is the only one that is straightforwardly a defect and it is the highest priority: the app
silently failed to start tracking, which is the core promise of Phase 23. G-05 and G-07 are
behaviour/design changes beyond what v1.5 specified. G-01 touches a Phase 19 surface, not v1.5's.
