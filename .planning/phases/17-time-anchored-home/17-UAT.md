---
status: testing
phase: 17-time-anchored-home
source: [17-VERIFICATION.md]
started: 2026-06-13T23:30:00Z
updated: 2026-06-13T23:30:00Z
---

## Current Test

> Verification target: **web debug build in a browser** (not a physical device — per Dan, 2026-06-14).

number: 1
name: Live Now/Next transition at a real minute boundary
expected: |
  With Home open in the browser, as wall-clock time crosses a chunk's window boundary,
  Now/Next update on their own (within ~1 minute) without any manual interaction.
awaiting: user response

## Tests

### 1. Live Now/Next transition at a real minute boundary
expected: With Home open in the browser, Now/Next advance on their own as the clock crosses a chunk window boundary (≤1 min lag), no manual refresh.
result: [pending]

### 2. Pre-start state visuals (browser)
expected: Before the first chunk's window, Home shows the pre-start state ("Your day starts at [TIME]") with correct typography/color — not a stale "Now."
result: [pass] — Verified on hosted debug web build (danserver:8097, software-WebGL headless capture, 2026-06-14). Low-mood schedule with a 3:55 PM first chunk shown before its window: Home "Now" zone reads "Your day starts at 3:55 PM" (calm dark titleMedium heading, no accent, no emoji in heading), names the upcoming task "Reading · 25 min", and shows "Low energy — keep it light today." No ActiveChunkCard, no stale "Now." Matches NOW-02 pre-start contract.

### 3. Day-complete state visuals (browser)
expected: After the last chunk's window passes, Home shows the calm day-complete state ("That's a wrap") with correct typography/color — not the last chunk stuck as "Now."
result: [pending]

### 4. Tab background/foreground lifecycle (browser, best-effort)
expected: Switching away from and back to the tab does not break Now/Next (no duplicate-timer jank). Note: browser tab visibility approximates app lifecycle; the no-double-timer invariant is also covered by the automated WR-03 test.
result: [pending]

## Summary

total: 4
passed: 1
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
