---
status: complete
phase: 15-engine-honesty
source: [15-VERIFICATION.md]
started: 2026-06-13T22:30:00Z
updated: 2026-06-14T17:35:00Z
---

## Current Test

All 3 tests passed (browser-verified on the hosted debug web build, 2026-06-14). No tests awaiting.

## Tests

### 1. CAP-01 in UI — outcome goal appears on a low-mood day with 4+ habits
expected: Generate a low-mood schedule with 4+ daily habits + at least one outcome goal; the outcome goal appears in the schedule with at least one chunk.
result: [pass] — Verified on hosted debug web build (danserver:8097, software-WebGL headless capture, 2026-06-14). Seeded a scenario with 4 daily habits (Morning run, Meditate, Read 10 pages, Stretch) + outcome "Ship side project" (deadline +15d) + time-target "Learn Spanish" via dev-data ingest, reloaded, then mood-1 (stormy) check-in. The 4-chunk schedule shows exactly 2 habit chunks (Meditate, Read 10 pages) — habitCeiling = ceil(4/2) = 2 — leaving the outcome "Ship side project" (5:10–5:35 PM, High) AND time-target "Learn Spanish" (6:00–6:25 PM) each a chunk. Habits did not monopolize the cap; the outcome chunk renders in the schedule list with no display filter hiding it.

### 2. STREAK-01 in UI — displayed streak matches backward walk
expected: Open a habit goal card after generation; the displayed streak number matches a manual backward walk over due-days (e.g., completed Mon + Wed, today Thu non-due → shows 2).
result: [pass] — Verified on hosted debug web build (danserver:8097, software-WebGL headless capture, 2026-06-14). Seeded habit "Morning run" (due Mon–Fri) with completed logs for this week's Mon–Fri (06-08…06-12) and a gap before (no 06-05). Backward walk from Sunday 06-14 over due-days = 5 (Fri,Thu,Wed,Tue,Mon), breaking at the uncompleted prior Friday. After generation + reload, the Morning run goal card displays "5-day streak" — matching the computed backward walk exactly, confirming the generation-time write-back persists streakCount to Hive and the card reads the persisted field (not a stale cache). Note: the displayed value only refreshes after the GoalsNotifier reloads (cold launch / day boundary) — within the same session after a mid-session dev-ingest it shows the pre-write value until reload; this is the cold-launch sync the fix targets, not a regression.

### 3. FILL-01 in UI — time-target goal appears on a low-mood open-capacity day
expected: On a low-mood day (mood 1–2) with open capacity after habits, at least one chunk from a time-target goal appears in the generated schedule.
result: [pass] — Verified on hosted debug web build (danserver:8097, software-WebGL headless capture, 2026-06-14). Created a time-target ("regular time") goal "Reading", did a mood-1 (stormy) check-in, generated the schedule: intro card reads "Stormy day — keeping it light. 1 chunk. Starting with Reading." and Home shows the Reading chunk (25 min). The time-target goal surfaces on a low-mood day rather than leaving it empty — confirms the removed `!isLowMood` gate works through the UI. (Tested with a single time-target goal; the "open capacity after habits" multi-goal contention case is covered by the FILL-01 unit test.)

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
