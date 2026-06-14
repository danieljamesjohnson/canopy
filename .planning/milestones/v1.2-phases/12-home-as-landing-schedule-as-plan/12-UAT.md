---
status: complete
phase: 12-home-as-landing-schedule-as-plan
source: [12-VERIFICATION.md]
started: 2026-06-12T14:51:26Z
updated: 2026-06-14T19:21:05Z
---

## Current Test

number: 5
name: Complete from Home updates Now section (NAV-02)
expected: |
  After tapping Complete, the Now section updates — the next unresolved chunk becomes the new current chunk (or 'All done today!' if none remain).
awaiting: none — all 5 scenarios run (4 pass, 1 issue). See Gaps.

## Tests

### 1. Cold-start lands on Home (NAV-01)
expected: App opens to Home screen (title 'Canopy') showing the Now/Next layout or empty state, not the Goals screen.
result: pass — full reload lands on Home (verified 2026-06-14)

### 2. Clock-time range on ActiveChunkCard (SCHED-01)
expected: ActiveChunkCard renders a clock-time range (e.g. "9:25 AM – 9:50 AM") when the current chunk has a syntheticStartMinutes or anchoredStartMinutes value.
result: pass — Now card shows a clock-time range (verified 2026-06-14)

### 3. NowMarker placement (SCHED-02)
expected: NowMarker divider sits immediately above the chunk you should be working on right now, not at the top of the list or before a past chunk.
result: pass — marker sits immediately above the current chunk (verified 2026-06-14)

### 4. Always-visible Complete/Skip on touch and mouse (SCHED-03)
expected: Labeled 'Complete' (filled) and 'Skip' (outlined, error-colored) buttons appear immediately without any mouse interaction on both desktop and touch surfaces.
result: pass — Complete (filled) and Skip (outlined) visible immediately, no hover (verified 2026-06-14)

### 5. Complete from Home updates Now section (NAV-02)
expected: After tapping Complete, the Now section updates — the next unresolved chunk becomes the new current chunk (or 'All done today!' if none remain).
result: issue — Now section DOES update after Complete (transitions correctly), but when the next chunk is completed ahead of its window the gap-before-next state shows only "Up next / Starts at <time>" and never names the upcoming task. User wants the upcoming goal/chunk named here. (verified 2026-06-14) → see GapBeforeNext finding below.

## Summary

total: 5
passed: 4
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

### G1 — "Up next" gap state never names the upcoming task (NAV-02, minor)
When the current chunk is resolved ahead of the next chunk's window (completed
early), Home's NOW area enters the gap-before-next state and renders only an
"Up next" heading + "Starts at <time>" (or "Starting soon"). It omits the next
chunk's goal/task name, so it reads as blank — "it says something's up next but
not what." The non-gap "Next" section (Active/Overdue states) DOES show the goal
name; the gap state should match. Fix: include the next chunk's title in
`_buildGapBeforeNextContent` (lib/screens/home/home_screen.dart ~L570), mirroring
the Next-section row (goal name via `_lookupGoalName`, rationale subtitle).
Captured: .planning/todos/pending/2026-06-14-home-gap-up-next-name.md
