---
status: complete
phase: 17-time-anchored-home
source: [17-VERIFICATION.md]
started: 2026-06-13T23:30:00Z
updated: 2026-06-14T17:35:00Z
---

## Current Test

> Verification target: **web debug build in a browser** (not a physical device — per Dan, 2026-06-14).

All 4 tests passed (browser-verified on the hosted debug web build, 2026-06-14). The
timing-dependent tests (1, 3, 4) were verified by mocking the browser clock (Playwright
`page.clock.setFixedTime`) so the app's real `DateTime.now()` + 1-min `Timer.periodic`
could be driven across window boundaries without waiting on wall-clock. No tests awaiting.

## Tests

### 1. Live Now/Next transition at a real minute boundary
expected: With Home open in the browser, Now/Next advance on their own as the clock crosses a chunk window boundary (≤1 min lag), no manual refresh.
result: [pass] — Verified on hosted debug web build (danserver:8097, software-WebGL headless capture, 2026-06-14), clock mocked via Playwright setFixedTime. With Home open and the mocked clock at 07:55, Home showed pre-start ("Your day starts at 8:00 AM"). Without any reload or interaction, the clock was advanced to 08:10; after the app's own 1-min Timer.periodic fired (~60s), the Now zone autonomously flipped to the ActiveChunkCard "Meditate 8:00 AM – 8:25 AM" (Now badge + Complete/Skip) with Next "Read 10 pages 8:30–8:55 AM". Confirms timer-driven refresh across a window boundary with no manual action.

### 2. Pre-start state visuals (browser)
expected: Before the first chunk's window, Home shows the pre-start state ("Your day starts at [TIME]") with correct typography/color — not a stale "Now."
result: [pass] — Verified on hosted debug web build (danserver:8097, software-WebGL headless capture, 2026-06-14). Low-mood schedule with a 3:55 PM first chunk shown before its window: Home "Now" zone reads "Your day starts at 3:55 PM" (calm dark titleMedium heading, no accent, no emoji in heading), names the upcoming task "Reading · 25 min", and shows "Low energy — keep it light today." No ActiveChunkCard, no stale "Now." Matches NOW-02 pre-start contract.

### 3. Day-complete state visuals (browser)
expected: After the last chunk's window passes, Home shows the calm day-complete state ("That's a wrap") with correct typography/color — not the last chunk stuck as "Now."
result: [pass] — Verified on hosted debug web build (danserver:8097, software-WebGL headless capture, 2026-06-14), clock mocked via Playwright setFixedTime. With an 11-chunk day generated and the clock advanced to 23:30 (after the last window), Home's Now zone shows the calm day-complete state: "That's a wrap" heading + "You've reached the end of today's schedule." (no accent, no stuck chunk), plus the "How did today go? — Close the day" banner. Correctly NOT stuck on the 8 AM chunk as "Now" even with 0/11 completed — time-anchored per NOW-01.

### 4. Tab background/foreground lifecycle (browser, best-effort)
expected: Switching away from and back to the tab does not break Now/Next (no duplicate-timer jank). Note: browser tab visibility approximates app lifecycle; the no-double-timer invariant is also covered by the automated WR-03 test.
result: [pass] — Verified on hosted debug web build (danserver:8097, software-WebGL headless capture, 2026-06-14), clock mocked via Playwright setFixedTime + dispatched visibilitychange. Home was active at 08:10 (Meditate Now card). Backgrounded the tab (visibilitychange→hidden, timer pauses), advanced the mocked clock to 23:30 while hidden, then foregrounded (→visible). Within ~4s (well under the 60s timer interval) the Now zone refreshed straight to the day-complete state — confirming the resume path refreshes immediately on foreground rather than waiting for the next tick, with no stale "Now" and no crash/jank. The no-double-timer invariant is additionally covered by automated WR-03.

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
