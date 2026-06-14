---
status: testing
phase: 15-engine-honesty
source: [15-VERIFICATION.md]
started: 2026-06-13T22:30:00Z
updated: 2026-06-13T22:30:00Z
---

## Current Test

number: 1
name: CAP-01 in UI — outcome goal appears on a low-mood day with 4+ habits
expected: |
  Generate a schedule for a low-mood day with 4+ daily habits and at least one outcome goal.
  The outcome goal appears in the generated schedule with at least one chunk, confirming habits
  did not monopolize the discretionary cap.
awaiting: user response

## Tests

### 1. CAP-01 in UI — outcome goal appears on a low-mood day with 4+ habits
expected: Generate a low-mood schedule with 4+ daily habits + at least one outcome goal; the outcome goal appears in the schedule with at least one chunk.
result: [pending]

### 2. STREAK-01 in UI — displayed streak matches backward walk
expected: Open a habit goal card after generation; the displayed streak number matches a manual backward walk over due-days (e.g., completed Mon + Wed, today Thu non-due → shows 2).
result: [pending]

### 3. FILL-01 in UI — time-target goal appears on a low-mood open-capacity day
expected: On a low-mood day (mood 1–2) with open capacity after habits, at least one chunk from a time-target goal appears in the generated schedule.
result: [pass] — Verified on hosted debug web build (danserver:8097, software-WebGL headless capture, 2026-06-14). Created a time-target ("regular time") goal "Reading", did a mood-1 (stormy) check-in, generated the schedule: intro card reads "Stormy day — keeping it light. 1 chunk. Starting with Reading." and Home shows the Reading chunk (25 min). The time-target goal surfaces on a low-mood day rather than leaving it empty — confirms the removed `!isLowMood` gate works through the UI. (Tested with a single time-target goal; the "open capacity after habits" multi-goal contention case is covered by the FILL-01 unit test.)

## Summary

total: 3
passed: 1
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
