---
status: testing
phase: 17-time-anchored-home
source: [17-VERIFICATION.md]
started: 2026-06-13T23:30:00Z
updated: 2026-06-13T23:30:00Z
---

## Current Test

number: 1
name: Live Now/Next transition at a real minute boundary
expected: |
  With Home open on a device, as wall-clock time crosses a chunk's window boundary,
  Now/Next update on their own (within ~1 minute) without any manual interaction.
awaiting: user response

## Tests

### 1. Live Now/Next transition at a real minute boundary
expected: With Home open, Now/Next advance on their own as the clock crosses a chunk window boundary (≤1 min lag), no manual refresh.
result: [pending]

### 2. Pre-start state visuals on device
expected: Before the first chunk's window, Home shows the pre-start state ("Your day starts at [TIME]") with correct typography/color — not a stale "Now."
result: [pending]

### 3. Day-complete state visuals on device
expected: After the last chunk's window passes, Home shows the calm day-complete state ("That's a wrap") with correct typography/color — not the last chunk stuck as "Now."
result: [pending]

### 4. Background/foreground lifecycle on a physical device
expected: Backgrounding the app pauses the 1-minute timer; foregrounding resumes it and Now/Next reflect the current time. No duplicate-timer jank or battery issues.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
