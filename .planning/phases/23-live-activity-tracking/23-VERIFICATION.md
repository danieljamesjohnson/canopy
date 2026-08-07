---
phase: 23-live-activity-tracking
verified: 2026-08-07T23:23:09Z
status: human_needed
score: 8/8 code-level must-haves verified
overrides_applied: 0
human_verification:
  - test: "The 60-second handover reads smoothly in a real GPU-backed browser"
    expected: "Whole-minute label steps down normally, then at 59s switches to a per-second countdown with no stutter or visible jump on the full ~900-line screen"
    why_human: "A widget test proves the string changes on a pumped tick; it cannot judge real-render smoothness (23-VALIDATION.md Manual-Only Verifications row 1)"
  - test: "A running break genuinely reads as rest, not as dead time"
    expected: "The live row's tone ('RIGHT NOW — RESTING' / 'Taking a break', no Complete/Skip) is judged by a human as restful rather than idle/empty"
    why_human: "Copy/tone judgment (23-VALIDATION.md Manual-Only Verifications row 2)"
  - test: "Confirm or overturn decision P-1 (the GapBeforeNext 'Up next' banner is left unchanged)"
    expected: "Dan replies 'keep' or 'remove' after looking at a live gap state on the served build"
    why_human: "P-1 was a planner decision made on Dan's behalf under a genuinely ambiguous UI-SPEC sentence; plan 23-04 Task 2 is a blocking checkpoint requiring his explicit verdict, not inferred from silence"
---

# Phase 23: Live Activity Tracking Verification Report

**Phase Goal:** The unified screen always tells the truth about what's happening right now, including breaks, with a live countdown
**Verified:** 2026-08-07T23:23:09Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

Every code-level truth behind the roadmap's three Success Criteria is independently verified in
the actual codebase (not taken from SUMMARY.md claims). The phase is **not yet fully closed**
because plan `23-04` — an explicit `autonomous: false` blocking human-verify checkpoint — has not
been run: there is no `23-04-SUMMARY.md`, and `23-VALIDATION.md` frontmatter is still
`status: draft` / `nyquist_compliant: false`. That is a deliberate, planned gate, not a defect —
see `<verification_focus>` guidance in the invocation and `23-04-PLAN.md`'s own
`checkpoint:human-verify` task. Everything gated on Dan's explicit sign-off (countdown smoothness
in a real browser, break-reads-as-rest tone judgment, and confirming/overturning decision P-1) is
listed under Human Verification below rather than scored as a gap.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A running break resolves as `Active` (not `GapBeforeNext`) and can appear as `.next` on `Active`/`Overdue`/`GapBeforeNext` | ✓ VERIFIED | `lib/screens/today/now_state.dart:130` — the `.where` predicate is `c.displayStartMinutes != null` only (no `ChunkType.work` clause); confirmed `grep -o "ChunkType.work" lib/screens/today/now_state.dart` → 0. Six new unit cases in `test/screens/today_screen_now_state_test.dart` (lines 424–525) cover break-as-Active, break-as-Active.next, break-as-GapBeforeNext.next (KEY INVARIANT still honored), break-as-Overdue, and a DayComplete regression on a work+break day. |
| 2 | The live row for a running break reads "RIGHT NOW — RESTING" / "Taking a break" (or "…long break"), keeps a progress bar, and shows **no** Complete/Skip | ✓ VERIFIED | `_liveKicker` (today_screen.dart:615-620), `_liveTitle` (604-608), and `showActions: chunk.chunkType == ChunkType.work` (710) read exactly as SUMMARY claims. Widget cases in `today_screen_now_state_test.dart` assert kicker/title text, `findsNothing` for FilledButton/OutlinedButton 'Complete'/'Skip', and a present `LinearProgressIndicator`. |
| 3 | A "Next · …" line naming a break reads "Short break"/"Long break", never "Work block" | ✓ VERIFIED | `_buildLiveRow`'s `nextLine` (695-701) calls the break-aware `_chunkTitle` (592-598), which special-cases `ChunkType.shortBreak`/`longBreak` before falling through to the goal/rationale chain. |
| 4 | "Start focus" is disabled whenever the resolved now-target is a break, unchanged otherwise | ✓ VERIFIED | `_buildAppBar` (today_screen.dart:807-816): `resolvedTarget` keeps the exhaustive switch over all five `NowState` arms, then `focusTarget` is narrowed to `resolvedTarget?.chunkType == ChunkType.work ? resolvedTarget : null`. Four widget cases in `today_screen_test.dart` (935-1020ish, WR-01 group) cover break-as-Active/GapBeforeNext/Overdue disabling the button, plus a positive case proving a work `Active` target still works. |
| 5 | Time remaining visibly counts down: whole minutes rounded up ≥60s, seconds <60s, driven by a narrowly-scoped fast timer | ✓ VERIFIED | `_liveSecondsRemaining` (today_screen.dart:635-645) and the two-branch label in `_buildLiveRow` (669-693) match the spec exactly (ceil via `(secondsRemaining + 59) ~/ 60`, no-space `s left` form). `_fastTimer`/`_syncFastTimer` (68-76, 139-148) exist only while `liveSecondsLeft < 60`, driven from a single `build()` call site (881). 8 boundary-label tests + 6 `LIVE-02 fast tick` lifecycle tests (dispose, pause/resume-doesn't-duplicate, schedule-disappears, starts/stops at the 60s crossing) all present and passing. |
| 6 | No timer leaks: cancelled on dispose, on pause, and when leaving the final minute | ✓ VERIFIED | `dispose()` (169-175) and the `paused` branch of `didChangeAppLifecycleState` (161-165) both call `_fastTimer?.cancel(); _fastTimer = null;` alongside `_nowTimer?.cancel()`. `_syncFastTimer` is idempotent and nulls the field on stop. Full suite run independently (see below) produced zero "Timer is still pending" failures. |
| 7 | Before the day's first chunk / mid-gap / day-complete each read a distinct, truthful state; gap names a break correctly; decision on the gap banner is recorded | ✓ VERIFIED | `_buildEdgeStateLine` (today_screen.dart:335-443): `PreStart` reads "Nothing until <time>" / "The day starts with <title>. Until then the time is yours." (354-362); `DayComplete` reads "That's the day." / "Everything scheduled is behind you." with no total/percentage (424-436); `GapBeforeNext` (391-423) is untouched rendering code with a doc comment above it (366-390) recording decision P-1 and its reasoning verbatim, and calls the break-aware `_chunkTitle`. Distinctness and copywriting guard tests exist in `today_screen_test.dart`. |
| 8 | CR-01 (the code-review BLOCKER): removing the debug assert does not make `DayComplete` wrong, and the regression test genuinely discriminates | ✓ VERIFIED (independently re-derived, not taken on faith) | Traced `resolveNowState`'s `DayComplete` boundary (now_state.dart:141-158): the check is `currentMinutes >= scheduled.last.displayStartMinutes! + scheduled.last.durationMinutes`, which only reads `.displayStartMinutes` and `.durationMinutes` — never `.chunkType` — so it is correct regardless of the trailing chunk's type; `scheduled` is exhaustive over every clock-positioned chunk, so once `currentMinutes` passes the last one's window end nothing else is scheduled today either way. The `while` loop's own `idx + 1 >= scheduled.length → DayComplete` branch (177) has the identical property. **I independently reproduced the review's repro**: checked out `schedule_notifier.dart` from commit `47b9f5b^` (pre-fix), ran `test/providers/schedule_notifier_add_event_test.dart`'s CR-01 test, and confirmed it fails (`Expected: ['w1'] / Actual: ['w1', 'b1']`) exactly as the fix commit message claims; restored the fixed file and confirmed it passes. `ScheduleNotifier._trimTrailingNonWork()` (schedule_notifier.dart:336-348) is called from `addEventToday` right after the stale-chunk-removal (244), covering both downstream persist branches. |

**Score:** 8/8 code-level truths verified (the 3 roadmap Success Criteria plus the CR-01 blocker resolution, plus the underlying LIVE-01/02/03 detail truths from the three plans' `must_haves`, all collapse into these 8 without gaps).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/screens/today/now_state.dart` | `resolveNowState` over ALL clock-positioned chunks | ✓ VERIFIED | `ChunkType.work` grep count 0; `allWork` renamed to `scheduled` throughout; KEY INVARIANT doc block intact; no `.second` usage (minute-granularity classifier preserved) |
| `lib/screens/today/today_screen.dart` | `_chunkTitle` break branch, `_liveTitle`, `_liveKicker`, break-excluded focusTarget, `_liveSecondsRemaining`, `_fastTimer`/`_syncFastTimer`, locked PreStart/DayComplete copy | ✓ VERIFIED | All helpers present, wired, and matching plan spec exactly (see truths 1-7 above) |
| `lib/providers/schedule_notifier.dart` | `_trimTrailingNonWork()` write-side fix for CR-01 | ✓ VERIFIED | Present at line 336, called from `addEventToday` at line 244 |
| `test/screens/today_screen_now_state_test.dart` | break-as-now unit cases, live-break widget cases, countdown boundary cases, `LIVE-02 fast tick` group, updated edge-state assertions, CR-01 cases | ✓ VERIFIED | All named test cases from all three plans' `<behavior>` sections located and present |
| `test/screens/today_screen_test.dart` | focus-target-excludes-breaks cases, edge-state/distinctness/copywriting guards, gap-targets-a-break case | ✓ VERIFIED | All present |
| `test/screens/today_timeline_model_test.dart` | live-break `isLive` case | ✓ VERIFIED | Present at line 275 |
| `test/providers/schedule_notifier_add_event_test.dart` | CR-01 regression test | ✓ VERIFIED, and **independently proven to discriminate** | Reverting the write-side fix makes this test fail; restoring it passes — confirmed by direct execution, not by SUMMARY claim |
| `lib/screens/today/widgets/live_row_card.dart` | ZERO changes (Phase 22 contract) | ✓ VERIFIED | `git diff 0e4fcf0..HEAD -- lib/` touches only `now_state.dart`, `today_screen.dart`, `schedule_notifier.dart` — the card is untouched |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `now_state.dart` | `today_screen.dart` | `resolveNowState` called exactly once in `build()` | ✓ WIRED | `today_screen.dart:878`; grep count of `resolveNowState` in the file is 1 |
| `today_screen.dart` build() | `_liveSecondsRemaining` / `_syncFastTimer` | one clock sample (`nowDt`) threaded into both `resolveNowState` and `_liveSecondsRemaining` | ✓ WIRED | `today_screen.dart:877-881` — single `_nowFn()` read, passed by closure into `resolveNowState` and directly into `_liveSecondsRemaining`, eliminating the WR-01 clock-boundary race (independently confirmed present in current code, not just claimed fixed) |
| `_TodayScreenState.dispose` / `paused` | `_fastTimer` | cancellation | ✓ WIRED | Both call sites cancel and null the field; full suite run produced no pending-timer failures |
| `schedule_notifier.dart` `addEventToday` | `_trimTrailingNonWork` | write-side invariant maintenance | ✓ WIRED | Called once, immediately after stale-chunk removal, covering both downstream persist branches (`!anchorsToday` early return and `newChunks.isEmpty` guard) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite is green | `flutter test` (run once, in full) | `459` tests, `0` failures, no pending-timer messages | ✓ PASS |
| Analyzer is clean | `flutter analyze` | "No issues found!" | ✓ PASS |
| CR-01 regression test genuinely discriminates | Reverted `schedule_notifier.dart` to pre-fix (`47b9f5b^`), ran the CR-01 test alone, then restored and re-ran | Fails pre-fix (`Expected: ['w1'] / Actual: ['w1', 'b1']`), passes post-fix | ✓ PASS |
| No debt markers left in touched files | `grep -n -E "TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER"` on the three modified `lib/` files | No matches | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| LIVE-01 | 23-01 | The screen always names what the user is doing right now, including breaks | ✓ SATISFIED | Truths 1-4 above |
| LIVE-02 | 23-02 | Time remaining in the current activity is shown and counts down while the screen is open | ✓ SATISFIED | Truths 5-6 above |
| LIVE-03 | 23-03 | The honest edge states survive the merge | ✓ SATISFIED | Truth 7 above |

All three requirement IDs declared across the phase's plan frontmatter (`LIVE-01`, `LIVE-02`,
`LIVE-03`) match REQUIREMENTS.md's Phase 23 mapping exactly. No orphaned requirements — plan
`23-04` also declares all three (it is the joint phase gate, not new scope). REQUIREMENTS.md's own
checkbox for all three is already `[x]`, which is a documentation-authoring artifact (the
requirements file was written before this verification), not evidence in itself — the code-level
verification above is what actually establishes SATISFIED status.

### Anti-Patterns Found

None. No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers, no empty stub implementations,
and no hardcoded-empty-data patterns in any of the three modified `lib/` files.

### Human Verification Required

Plan `23-04` is `autonomous: false` and its Task 2 is a `checkpoint:human-verify` gate that has
**not yet been run** — there is no `23-04-SUMMARY.md`, and `.planning/phases/23-live-activity-tracking/23-VALIDATION.md`
frontmatter is still `status: draft` / `nyquist_compliant: false`. Per the invocation's own
guidance, this is a deliberate, planned checkpoint, not a gap to report as failed. The three items
below are exactly what that checkpoint is waiting on:

### 1. The 60-second handover reads smoothly

**Test:** Open the served debug build in a real GPU-backed browser, find an activity within a
couple of minutes of ending, and watch the live row for ~90 seconds across the 60-second boundary.
**Expected:** Whole-minute label steps down one minute at a time, then at 59 seconds switches to a
per-second countdown, with no stutter or visible jump on the ~900-line screen.
**Why human:** A widget test (already passing) proves the string changes on a pumped tick; it
cannot judge whether the real render updates smoothly or stutters (23-VALIDATION.md's own
Manual-Only Verifications table, row 1).

### 2. A running break genuinely reads as rest

**Test:** Wait for or trigger a scheduled break and read the live row.
**Expected:** "RIGHT NOW — RESTING" / "Taking a break", progress bar, no Complete/Skip — judged as
restful, not as dead/idle time.
**Why human:** Copy/tone judgment (23-VALIDATION.md row 2).

### 3. Confirm or overturn decision P-1 (gap banner unchanged)

**Test:** Finish an activity early so the day drops into a gap, and look at the "Up next" banner.
**Expected:** Dan gives an explicit "keep" or "remove" verdict — the planner made this decision on
his behalf under a genuinely ambiguous UI-SPEC sentence, and plan `23-04` Task 2 is a blocking
checkpoint that must not infer a verdict from silence.

### Gaps Summary

No code-level gaps. Every artifact, key link, and observable truth behind the roadmap's three
Success Criteria is present, wired, and independently verified against the source — not merely
claimed by SUMMARY.md. The code-review BLOCKER (CR-01) is genuinely closed: I traced the
`DayComplete` boundary-check reasoning myself rather than accepting the fix report's claim, and I
reverted-then-restored the write-side fix to prove the new regression test actually discriminates
between the buggy and fixed behavior. The only remaining item before Phase 23 can be marked fully
complete is plan `23-04`'s blocking human-verify checkpoint — a planned gate, not a defect.

---

*Verified: 2026-08-07T23:23:09Z*
*Verifier: Claude (gsd-verifier)*
*Depth: standard — independent code trace of `now_state.dart`, `today_screen.dart`,
`schedule_notifier.dart`; full `flutter test` (459/459) and `flutter analyze` run directly; CR-01
regression test reverted-and-restored to prove discrimination rather than trusted from
SUMMARY/REVIEW claims.*
