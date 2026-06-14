---
created: 2026-06-14T19:21:05Z
title: Home "Up next" gap state should name the upcoming task
area: ui/home
surfaced_during: v1.2 Phase 12 UAT (scenario 5, NAV-02)
severity: minor
files:
  - lib/screens/home/home_screen.dart
---

## Problem

On Home, when the current chunk is resolved **ahead of the next chunk's window**
(you complete it early), the NOW area enters the gap-before-next state and shows
only:

> **Up next**
> Starts at 2:25 PM   *(or "Starting soon")*

It never names the upcoming task/goal, so it reads as blank — the header says
something is up next, but not *what*. Confirmed in UAT: chunks were back-to-back,
user completed early, landed in the gap state at "Starts at 2:25 PM" with no task
name. User: "later should probably still show what it's gonna be anyways."

The non-gap **Next** section (Active/Overdue states) already shows the goal name
+ rationale + clock-time range (`home_screen.dart` ~L393–453). The gap state
(`_buildGapBeforeNextContent`, ~L570) only shows heading + time.

## Solution

In `_buildGapBeforeNextContent`, include the upcoming chunk's title (and
optionally rationale subtitle), mirroring the Next-section row:
- title = `_lookupGoalName(context, next)` ?? rationale ?? 'Work block'
- keep the "Starts at <time>" / "Starting soon" line as the time detail.

Keep the calm/no-accent treatment per UI-SPEC; this is additive text, not a new
accent.

## Acceptance

The gap-before-next "Up next" state names the upcoming task (goal name), not just
its start time — so the user knows what's coming, consistent with the Next
section.
