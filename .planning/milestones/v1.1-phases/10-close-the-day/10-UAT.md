---
status: testing
phase: 10-close-the-day
source: [10-VERIFICATION.md]
started: 2026-06-11T21:35:00Z
updated: 2026-06-11T21:35:00Z
---

## Current Test

number: 1
name: Evening reminder notification fires at 8:00pm on iOS
expected: |
  With the Evening reminder toggle enabled in Settings, the notification appears
  in the iOS notification tray at 8:00pm with title 'Canopy' and body
  'Time to close the day. See how your chunks went.'
awaiting: user response

## Tests

### 1. Evening reminder notification fires at 8:00pm on iOS
expected: On an iOS device, enable the Evening reminder toggle in Settings and wait for 8:00pm (or set device clock to 7:59pm). Notification appears in the tray at 8:00pm with title 'Canopy' and the close-the-day body.
result: [pending]

### 2. Tapping the evening notification routes correctly from a backgrounded app
expected: On an iOS device with the app backgrounded, tapping the fired evening notification opens the app to the /schedule (or /schedule/checkin) screen — not a crash.
result: [pending]

### 3. Deferred chunk carries into the next morning's schedule across a real Hive day boundary
expected: On iOS, after a day where one or more chunks were deferred, tap "Start your day" the next morning; a chunk for the deferred goal appears in the newly generated schedule (carried over from yesterday).
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
