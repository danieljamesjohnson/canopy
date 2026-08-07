---
status: testing
phase: 21-mood-scaled-breaks-honest-rationale
source: [21-VERIFICATION.md]
started: 2026-08-07T19:35:00Z
updated: 2026-08-07T19:35:00Z
---

## Current Test

number: 1
name: Time-target rationale reads as help, not as a deficit report
expected: |
  The rationale must not imply the user has failed or is behind — it should read as what the
  schedule is doing for the user (e.g. "Working toward 5.0h this week").
awaiting: user response

## Tests

### 1. Time-target rationale reads as help, not as a deficit report

expected: The rationale must not imply the user has failed or is behind — it should read as what the schedule is doing for the user (e.g. "Working toward 5.0h this week")
result: [pending]

**Repro steps:**
1. Create a time-target goal with a weekly hour budget.
2. Complete fewer chunks than the weekly pace (so the goal is under pace).
3. Generate today's schedule via the morning check-in.
4. Read the rationale badge on the resulting chunk card.

**Why human:** Tone is a judgment call. A unit test pins the exact string (done — verified on both
branches) but cannot confirm the string *reads* right to a person. This is the single manual-only
item listed in `21-VALIDATION.md`.

**Already verified by automation (do not re-check by hand):**
- `grep -rn "behind this week" lib/` → 0 matches
- Deficit branch returns `'Working toward ${remaining.toStringAsFixed(1)}h this week'`
- On-track sibling branch still reads `'On track this week'`
- Both branches pinned by tests; full suite 348/348 green

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
