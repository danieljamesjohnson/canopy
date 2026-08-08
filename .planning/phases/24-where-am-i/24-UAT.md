---
status: testing
phase: 24-where-am-i
source: [24-VERIFICATION.md]
started: 2026-08-08T23:35:00Z
updated: 2026-08-08T23:35:00Z
build: http://danserver:8123/ (debug, single bundle, no service worker)
build_commit: fa885c6
---

## Current Test

number: 1
name: DayComplete — the marker is visible on open, without scrolling
expected: |
  Opening the app when the whole day's schedule is already behind you (after the
  last chunk's end time) lands the list scrolled near the BOTTOM, with the "Now"
  row — a short rule, the word "Now", then a fading rule in the theme's primary
  colour — already on screen. You should not have to scroll up from the top of
  the day to find where you are.
awaiting: user response

## Tests

### 1. DayComplete — the marker is visible on open, without scrolling

expected: The page opens already scrolled near the bottom of the list, with the "Now" marker row visible without any manual scrolling.
why_human: This is the literal re-test of the defect Dan reported in 24-03 — *"now were 'done' and it's hard to tell"* — against the fix shipped in 24-04. The widget test proves `Scrollable.ensureVisible` fires against a synthetic fixture; only a real browser against real data can settle whether "now" is findable at a glance. This phase exists because a green suite once shipped with Dan still unable to answer that question.
result: [pending]

### 2. PreStart / GapBeforeNext — same fallback, spot check

expected: Before the day's first chunk, or during a gap between chunks, the marker is likewise visible on open with no manual scroll.
why_human: 24-04 applied the identical fallback to all three no-live-row states, but only `DayComplete` was explicitly regression-tested and only `DayComplete` was reported broken. Lower priority — worth a glance, not a blocker.
result: [pending]

### 3. Active — no regression to the mid-day case Dan already approved

expected: During a live activity, the live card still centres on open and there is NO "Now" rule duplicating it.
why_human: Dan approved this case in 24-03, before 24-04 added a second scroll path. The two one-shot flags are deliberately independent so a PreStart-open cannot suppress a later Active centring, and there is a regression test for exactly that — but the approved case is worth re-confirming since the scroll behaviour changed underneath it.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps

_None recorded yet._

## Notes

- Served from the established Canopy debug-UAT origin (port 8123, same as phases 22 and 23-04), so
  existing schedule data is present — no re-onboarding needed.
- Bundle rebuilt at commit `fa885c6`, i.e. after both post-hoc gate fixes (`a8966b4` end-of-day
  card clock, `159e45e` marker semantics + header clock).
- Test 1 can only be executed at a time of day when the schedule is genuinely complete.
