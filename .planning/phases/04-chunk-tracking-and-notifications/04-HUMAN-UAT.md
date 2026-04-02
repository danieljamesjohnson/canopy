---
status: partial
phase: 04-chunk-tracking-and-notifications
source: [04-VERIFICATION.md]
started: 2026-04-02T00:00:00Z
updated: 2026-04-02T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Swipe gesture feel on device
expected: Green reveal with check icon on right swipe; orange reveal with forward arrow on left swipe; haptic feedback fires; cards remain in place and re-render in done/skipped state; skipped chunk moves to "Skipped today" at bottom.
result: [pending]

### 2. Morning notification fires and navigates correctly
expected: App opens to /schedule/checkin if no schedule exists for today, or /schedule if one already exists. Notification fires at configured time.
result: [pending]

### 3. Export produces a valid JSON file on Android
expected: Share sheet appears; selecting "Save to Files" produces a canopy_export_YYYYMMDD_HHMMSS.json file containing an array of objects each with id, chunkId, goalId, dateYmd, event, recordedAt fields.
result: [pending]

### 4. "View your day" overflow menu visibility threshold
expected: Three-dot overflow menu appears in the AppBar when 50%+ work chunks resolved; tapping "View your day" navigates to the summary screen.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
