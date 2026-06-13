---
status: testing
phase: 13-check-in-and-goal-form
source: [13-VERIFICATION.md]
started: 2026-06-13
updated: 2026-06-13
---

## Current Test

number: 1
name: Mood 5 amber contrast
expected: |
  On the morning check-in, mood 5 (☀️ amber #E8C547) shows dark (#1A1A1A) AppBar title,
  "Let's go" label, and body text — clearly readable, no faint white wash.
awaiting: user response

## Tests

### 1. Mood 5 amber contrast
expected: Mood 5 (amber #E8C547) renders dark text/controls, clearly readable — no white-on-amber wash.
result: [pending]

### 2. Mood 4 sage contrast + moods 1-3
expected: Mood 4 (sage #7AAF6A) renders dark text and is legible; moods 1-3 render white text on the darker blues/teal.
result: [pending]

### 3. Emoji hover highlight (desktop/web)
expected: Moving the pointer over an unselected emoji circle shows a subtle highlight; moving off clears it.
result: [pending]

### 4. Emoji pressed state
expected: Press-and-hold an emoji shows a stronger pressed fill (alpha increase) before release.
result: [pending]

### 5. Lighter-day decision screen flow
expected: No inline "Want a lighter day?" toggle exists pre-commit. After tapping a mood then "Let's go", a decision screen slides in with heading "Ready to start?", two cards (Full day / Lighter day), and a "Go back" link.
result: [pending]

### 6. Go back resets to mood selection
expected: Tapping "Go back" on the decision screen returns to the mood + "Let's go" state; re-running and tapping "Lighter day" regenerates the schedule and shows the acknowledgment ("Swipe up to begin").
result: [pending]

### 7. Decision card press scale
expected: Pressing a decision card briefly scales it down (~0.97) on press.
result: [pending]

### 8. Goal form Priority + Save reachability
expected: On a phone-class viewport with the keyboard up, opening the Add goal sheet (time-target/habit type) shows the Priority Low/Normal/High control AND the "Add goal" button without in-sheet scrolling. Selected type card shows both a colored border and a bold title. Edit mode keeps Archive/Cancel/Save reachable.
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps
