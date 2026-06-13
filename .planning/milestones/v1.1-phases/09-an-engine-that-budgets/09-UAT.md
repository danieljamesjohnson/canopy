---
status: deferred
phase: 09-an-engine-that-budgets
source: [09-VERIFICATION.md]
started: 2026-06-11
updated: 2026-06-11
---

## Current Test

number: 1
name: On-device render of the priority SegmentedButton (ENGINE-06 UI half)
expected: |
  On iOS/Android: Goals → "+" shows a "Priority" label with Low/Normal/High
  segments under the goal name field, for all goal types. A High-priority goal
  re-opened in Edit still shows "High". A legacy (null-priority) goal shows "Normal".
  The control persists priorityWeight on save.
awaiting: user response (deferred — no simulator on this Linux host)

## Tests

### 1. On-device render of the priority SegmentedButton (ENGINE-06 UI half)
expected: Renders for all goal types, defaults Normal, maps Low/Normal/High → 0.25/0.5/0.75, persists on edit, null coalesces to Normal.
result: [pending — deferred]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps

The scheduling-influence half of ENGINE-06 (priority as weight + tiebreaker) and
presence/default/mapping of the control are covered by automated widget + unit
tests (T-09-06, goal_form_priority_test.dart, 7 assertions). Only the literal
on-device visual render remains, deferred because this host has no iOS/Android
simulator.
