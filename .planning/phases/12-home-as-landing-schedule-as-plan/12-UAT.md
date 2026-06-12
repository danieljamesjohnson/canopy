---
status: testing
phase: 12-home-as-landing-schedule-as-plan
source: [12-VERIFICATION.md]
started: 2026-06-12T14:51:26Z
updated: 2026-06-12T14:51:26Z
---

## Current Test

number: 1
name: Cold-start lands on Home (NAV-01)
expected: |
  App opens to Home screen (title 'Canopy') showing the Now/Next layout or empty state, not the Goals screen.
awaiting: user response

## Tests

### 1. Cold-start lands on Home (NAV-01)
expected: App opens to Home screen (title 'Canopy') showing the Now/Next layout or empty state, not the Goals screen.
result: [pending]

### 2. Clock-time range on ActiveChunkCard (SCHED-01)
expected: ActiveChunkCard renders a clock-time range (e.g. "9:25 AM – 9:50 AM") when the current chunk has a syntheticStartMinutes or anchoredStartMinutes value.
result: [pending]

### 3. NowMarker placement (SCHED-02)
expected: NowMarker divider sits immediately above the chunk you should be working on right now, not at the top of the list or before a past chunk.
result: [pending]

### 4. Always-visible Complete/Skip on touch and mouse (SCHED-03)
expected: Labeled 'Complete' (filled) and 'Skip' (outlined, error-colored) buttons appear immediately without any mouse interaction on both desktop and touch surfaces.
result: [pending]

### 5. Complete from Home updates Now section (NAV-02)
expected: After tapping Complete, the Now section updates — the next unresolved chunk becomes the new current chunk (or 'All done today!' if none remain).
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
