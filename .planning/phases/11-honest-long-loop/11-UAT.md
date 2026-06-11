---
status: testing
phase: 11-honest-long-loop
source: [11-VERIFICATION.md]
started: 2026-06-11
updated: 2026-06-11
---

## Current Test

number: 1
name: Donut chart visual correctness with real Hive data
expected: |
  Open the quarterly review on a device/emulator with real history that includes
  commitment-block completions and at least one archived goal. The donut renders
  visible slices (no blank chart), a "Commitments" slice appears, archived goals
  show with an "(archived)" legend suffix, any unmatched time falls into "Other",
  and the legend percentages read up to ~100% with no invisible slice. Colors are legible.
awaiting: user response

## Tests

### 1. Donut chart visual correctness with real Hive data
expected: Donut renders visible slices with Commitments + archived "(archived)" + Other catch-all; legend percentages sum to ~100%; colors legible; no blank chart.
result: [pending]

### 2. Priority adjustment end-to-end (Hive write → read → generate)
expected: In the review's adjustments section, drag a low goal to the top and tap "Finish review". Trigger the next morning's schedule generation. That goal's chunks appear earlier/more prominently than before — proving the persisted priorityWeight drives generation across the full Hive write→read cycle.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
