---
status: testing
phase: 14-goals-screen-and-priority-end-to-end
source: [14-VERIFICATION.md]
started: 2026-06-13
updated: 2026-06-13
---

## Current Test

number: 1
name: Goals screen reads as a prioritization view
expected: |
  The Goals screen shows the "Your goals" heading + "Drag to prioritize. Tap to edit."
  subhead, and reads to a first-time user as the place to decide what to focus on.
awaiting: user response

## Tests

### 1. Goals screen reads as a prioritization view
expected: Heading "Your goals" + subhead "Drag to prioritize. Tap to edit." communicate purpose; the screen reads as a focus/prioritization view.
result: [pending]

### 2. Priority visual language is distinct and consistent
expected: High and Low priority chips/badges are clearly distinguishable from each other and from Normal (no chip), and look consistent between the Goals list and the schedule chunk cards (Home + schedule).
result: [pending]

### 3. Drag-to-reorder affordance is obvious
expected: The Icons.drag_indicator handle reads as draggable on both desktop (hover/tooltip) and mobile (always-visible, long-press to drag) — not an ambiguous two-slash icon.
result: [pending]

### 4. End-to-end priority → schedule change is observable
expected: Elevating a goal from Low to High and regenerating produces visibly more/earlier chunks for that goal; lowering High to Low and regenerating produces fewer/later chunks. The change is observable without inspecting code.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
