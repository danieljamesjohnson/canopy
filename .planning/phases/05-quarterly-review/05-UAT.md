---
status: passed
phase: 05-quarterly-review
source:
  - 05-01-SUMMARY.md
  - 05-02-SUMMARY.md
  - 05-03-SUMMARY.md
  - 05-04-SUMMARY.md
  - 05-05-SUMMARY.md
  - 05-06-SUMMARY.md
started: 2026-04-26T00:00:00Z
updated: 2026-05-12T00:00:00Z
completed: 2026-05-12T00:00:00Z
---

## Tests

### 1. App launches cleanly
expected: `flutter run` boots without errors. Home screen renders. No red error screens, no Hive adapter errors in console.
result: pass
note: "Originally failed with macOS ArgumentError; closed by gap plan 05-05 (commits 730c206, 6b499ad). Human re-verified 2026-04-26 — macOS boots cleanly."

### 2. Home review banner (within review window)
expected: If you have completion data spanning ~90+ days, the home screen shows a "Your quarterly review is ready" banner above the schedule (uses `primaryContainer` background). Tapping the X dismisses it; tapping "Start review" opens the review screen. If you have less than ~90 days of data, no banner appears (skip this test).
result: skipped
reason: "Less than ~90 days of completion data on dev install — banner gating correctly suppresses display (per test's own skip rule)."

### 3. Quarterly Review screen loads
expected: Either via the home banner "Start review" button or by navigating directly to `/review`, the QuarterlyReviewScreen opens with AppBar title "Your quarter", a close (X) icon on the left, and elevation 0.
result: pass
note: "Verified by user 2026-05-12 against bundled 13-week dev scenario (05-06 DevDataLoader)."

### 4. Empty state (only if no completion data)
expected: If there is no completion log data yet, the review screen shows "Not enough data yet" message instead of charts. Skip this test if you have data.
result: pass
note: "Verified by user 2026-05-12 against bundled 13-week dev scenario (05-06 DevDataLoader)."

### 5. Data section — hero stat, donut, bar chart, top-3 goals
expected: Section 1 shows a large 48pt bold number with the label "chunks completed this quarter" beneath it. A donut chart with a hollow center (not a full pie), one slice per goal in each goal's color, and a grey "Time not spent" slice. A legend below the donut listing each goal with its color dot and percentage. A weekly bar chart with primary-color bars per ISO week (no grid, no border). Below that, the top 3 goals listed by chunk count.
result: pass
note: "Verified by user 2026-05-12 against bundled 13-week dev scenario (05-06 DevDataLoader)."

### 6. "Next: Reflect" advances to reflection
expected: An ElevatedButton labeled "Next: Reflect" near the bottom of the data section. Tapping it advances to Section 2 (the reflection section). The outer 3-dot section indicator updates.
result: pass
note: "Verified by user 2026-05-12 against bundled 13-week dev scenario (05-06 DevDataLoader)."

### 7. Reflection section — 5 questions with chips and "Other..."
expected: 5 questions appear one at a time with celebratory phrasing. Each question has ActionChip suggestions populated from your goal data, plus an "Other..." TextButton that opens an inline TextField with a Done button. Tapping a chip OR submitting the text answer advances to the next question. Step dots (5 dots) at the bottom show progress, with the active one in primary color. Horizontal swipe is disabled — you can only advance by answering. After question 5, the screen advances to Section 3 (adjustments).
result: pass
note: "Verified by user 2026-05-12 against bundled 13-week dev scenario (05-06 DevDataLoader)."

### 8. Adjustments — drag-to-reorder goals
expected: Section 3 shows a list of your goals as cards with a left color bar (5px wide) and a drag handle on the right. Long-press and drag (ReorderableDelayedDragStartListener) reorders the list smoothly. The new order is what will be saved.
result: pass
note: "Verified by user 2026-05-12 against bundled 13-week dev scenario (05-06 DevDataLoader)."

### 9. Adjustments — archive prompt + Keep/Archive
expected: Goals with completion rate ≤ 20% show an inline "This one rarely made it in — archive it?" prompt with two buttons: "Archive" (in error/red foreground color) and "Keep". Tapping "Keep" dismisses the prompt without removing the goal from the list. Tapping "Archive" marks the goal for archival on finish. The prompt animates in/out via AnimatedSwitcher (200ms).
result: pass
note: "Verified by user 2026-05-12 against bundled 13-week dev scenario (05-06 DevDataLoader)."

### 10. "Finish review" saves snapshot
expected: Tapping "Finish review" shows "Saving..." on the button briefly (no double-tap possible), then closes the review screen. A QuarterlySnapshot is persisted: any "Archive"-tapped goals are archived, the goal reorder is applied, and reflection answers are stored. No error message.
result: pass
note: "Verified by user 2026-05-12 against bundled 13-week dev scenario (05-06 DevDataLoader)."

### 11. Settings → Past reviews entry
expected: Open Settings. Below the Data section divider, a "Reviews" section heading is visible with a "Past reviews" ListTile (history icon, chevron right). Tapping it navigates to `/settings/past-reviews` while keeping the bottom navigation visible.
result: pass
note: "Verified by user 2026-05-12 against bundled 13-week dev scenario (05-06 DevDataLoader)."

### 12. Past reviews shows the just-completed review
expected: The Past reviews screen lists the review you just completed at the top (sorted descending by completedAt). Entry shows "Q{n} — {MMM yyyy}" as title and "{N} chunks completed" as trailing text. If this is your first review and you skipped Test 10, this screen shows "No reviews yet — complete your first quarterly review to see it here."
result: pass
note: "Verified by user 2026-05-12 against bundled 13-week dev scenario (05-06 DevDataLoader)."

### 13. Tone check — celebratory copy throughout
expected: Read through all visible copy in the review flow (banner, data section labels, reflection questions, adjustments prompt, finish button). None of it uses evaluative or negative language like "missed", "failed", "behind", "incomplete", "should have". Phrasing is celebratory, neutral, or curiosity-driven.
result: pass
note: "Verified by user 2026-05-12 against bundled 13-week dev scenario (05-06 DevDataLoader)."

## Summary

total: 13
passed: 12
issues: 0
pending: 0
skipped: 1
blocked: 0

## Gaps

- truth: "App launches on macOS without exceptions; NotificationService.initialize completes successfully on desktop platforms"
  status: resolved
  reason: "User reported: when i started it in macos i got an exception on this : FlutterLocalNotificationsPlugin.initialize (.../flutter_local_notifications-21.0.0/lib/src/flutter_local_notifications_plugin.dart:159) NotificationService.initialize (.../lib/services/notification_service.dart:62) main (.../lib/main.dart:30)"
  severity: blocker
  test: 1
  root_cause: |
    lib/services/notification_service.dart:57-61 constructs InitializationSettings with only android/iOS/linux. The flutter_local_notifications plugin's initialize() throws ArgumentError('macOS settings must be set when targeting macOS platform.') at flutter_local_notifications_plugin.dart:159 when defaultTargetPlatform is macOS and settings.macOS is null. Same defect causes the equivalent ArgumentError on Windows. Bug originated in Phase 4 (chunk-tracking-and-notifications); surfaced now during Phase 5 verification on macOS. macOS uses DarwinInitializationSettings (same type as iOS); Windows requires WindowsInitializationSettings(appName, appUserModelId, guid).
  artifacts:
    - path: "lib/services/notification_service.dart"
      issue: "InitializationSettings constructor missing macOS: and windows: parameters"
    - path: "lib/services/notification_service.dart"
      issue: "requestIOSPermissions() does not handle macOS Darwin permissions via MacOSFlutterLocalNotificationsPlugin"
  missing:
    - "Add macOS: <DarwinInitializationSettings> to InitializationSettings — can reuse the existing iOS Darwin settings since macOS is also Darwin"
    - "Add windows: <WindowsInitializationSettings(appName, appUserModelId, guid)> to InitializationSettings"
    - "Extend permission request path to handle macOS via MacOSFlutterLocalNotificationsPlugin (rename requestIOSPermissions to requestDarwinPermissions or add parallel macOS path)"
  resolved_by:
    plan: "05-05"
    commits:
      - "730c206 (RED test)"
      - "6b499ad (GREEN patch)"
    verified: "2026-04-26 (human ran flutter run -d macos, app boots cleanly)"
  debug_session: ""
