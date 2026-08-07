---
phase: 23
slug: live-activity-tracking
status: approved
shadcn_initialized: false
preset: none
created: 2026-08-07
reviewed_at: 2026-08-07
source: sketch 001 (variant A), reviewed and chosen by Dan
---

# Phase 23 — UI Design Contract

> Behaviour and copy contract for Phase 23: Live Activity Tracking.
> **Not agent-generated.** Derived from `.planning/sketches/001-unified-today/` variant A.
> The layout is Phase 22's contract; this document covers what the live row *says* and how
> often it changes.
>
> **Framework note:** Flutter / Material 3, mood-seeded `ColorScheme`. Semantic slots only.

---

## Countdown granularity (LOCKED — resolves LIVE-02)

| Time remaining | Readout | Example |
|---|---|---|
| ≥ 60s | Whole minutes, rounded **up** | `3 min left · until 10:50am` |
| < 60s | Seconds | `42s left · until 10:50am` |

Rounding up means a running activity never reads "0 min left".

**Tick cost is part of this decision.** Do not replace the existing 1-minute
`Timer.periodic` (`home_screen.dart:263`) with a blanket 1-second timer — this screen is open
all day. Run the coarse tick normally and only escalate to a fast tick while the current
activity has under a minute left, then drop back. The existing timer is already
lifecycle-managed (cancelled on pause, restarted on resume); any faster tick must be too.

Verified in the sketch: toolbar state **"Last minute"** demonstrates the switch
(`3 min left` → `41s left`).

## Break as a current activity (LIVE-01)

A running break is named, never rendered as empty or idle time.

| Element | Break | Work chunk |
|---|---|---|
| Kicker | `RIGHT NOW — RESTING` | `RIGHT NOW` |
| Title | "Taking a break" / "Taking a long break" | The goal's title |
| Remaining | Same rule as above | Same rule as above |
| Progress bar | Yes | Yes |
| Complete / Skip | **Absent** | Present, labelled |
| "Next · …" line | Yes | Yes |

The absence of Complete/Skip on a break is deliberate: there is nothing to complete about a
break, and offering the action would imply the user is meant to work through it.

## Edge states (LIVE-03)

Each reads distinctly, and none nag:

- **Before the day's first activity** — "Nothing until 8:00am" as the heading, then "The day
  starts with Exercise. Until then the time is yours."
- **In a gap between activities** — handled inline by Phase 22's named free-time rows; the
  screen does not claim an activity is running when none is.
- **Day complete** — "That's the day." then "Everything scheduled is behind you." A finish
  line, not a score. No totals, no percentage, no comparison to plan.

## Copywriting Contract

- No deficit language anywhere: not "behind", "missed", "overdue to you", "you still owe".
  (The chunk-level `Overdue` state may exist in the state machine; its user-facing copy must
  not shame — prefer naming the activity and letting the user resolve it.)
- Rest is described as rest.
- Free time belongs to the user.

## Checker Sign-Off

Behaviour chosen by the product owner from a working sketch. `gsd-ui-checker` should verify
conformance — especially the tick-cost rule, which is the one place a correct-looking
implementation can quietly be wrong.
