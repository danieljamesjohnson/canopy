---
phase: 25-time-travel
verified: 2026-08-10T14:20:00Z
status: passed
score: 4/4 success criteria verified
overrides_applied: 0
process_deviation:
  - "No PLAN.md exists for this phase. It was scoped directly in an orchestrator prompt (Phase 24's UAT was blocked on it) and executed as a single unplanned SUMMARY (25-01-SUMMARY.md). Verified against ROADMAP success criteria and REQUIREMENTS DEV-01..03 directly, per the launch instructions. This is a real gap in the .planning/ trail — recorded here, not smoothed over, per this repo's public work-sample intent."
---

# Phase 25: Time Travel Verification Report

**Phase Goal:** A debug-only clock override lets time-gated states be inspected on demand, so UAT
of "what does the app look like at 9pm" does not require waiting until 9pm.
**Verified:** 2026-08-10
**Status:** passed
**Re-verification:** No — initial verification

## Process Note (read first)

This phase has **no PLAN.md**. `.planning/phases/25-time-travel/` contains only
`25-01-SUMMARY.md`. Per the launch instructions this was a deliberate deviation — Phase 24's final
UAT item (`DayComplete`) was blocked purely on wall-clock time, so this phase was scoped inline in
an orchestrator prompt and executed as a single plan rather than going through the normal
plan-phase step. That is a genuine hole in the planning trail (no `must_haves` frontmatter, no
`22-PATTERNS.md`-style design doc for this specific phase, no separate validation-strategy pass)
and is recorded here as such rather than glossed over. Verification below is therefore anchored to
ROADMAP.md's four success criteria and REQUIREMENTS.md's DEV-01..03, not to a plan artifact.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A debug build can be put into any simulated moment and the whole app agrees — timeline, schedule "today" key, and end-of-day card all read the same clock | VERIFIED | `main.dart:51` constructs `ScheduleNotifier(now: DevClock.now)`; `today_screen.dart:67` defaults `_nowFn` to `DevClock.now`; `hive_daily_schedule_repository.dart:33` computes `dateYmd` from `DevClock.now()` (the seam that decides which schedule loads — previously hard-coded `DateTime.now()`). `today_screen.dart` build() samples the clock exactly once (`nowDt` at line 1055) and threads it into `resolveNowState`, `_liveSecondsRemaining`, `nowMinutes`, and `_shouldShowEodCard` — so the end-of-day card can no longer disagree with the rest of the screen about the time, closing the exact defect this phase was commissioned to fix. Wiring-level test coverage exists (`test/dev/dev_clock_wiring_test.dart`): jumping the clock to a day 40 days in the past loads that day's on-disk schedule instead of the real day's (with both present, ruling out a false positive from "no schedule found"). End-to-end: Dan's own UAT (`24-UAT.md`) exercised this live in a browser via Settings → Debug → "Jump to 9pm today" and reached `DayComplete` with the correct simulated day's schedule loaded. |
| 2 | Time still *flows* while overridden — offset not frozen instant — minute ticker keeps advancing, moving marker can be watched | VERIFIED | `DevClock._offset` is a `Duration` added to `DateTime.now()` on every `now()` call (`dev_clock.dart:29`), never a captured/frozen `DateTime`. Directly tested: `dev_clock_test.dart` "time still ADVANCES while overridden" reads `now()` twice with a real 250ms delay between and asserts the difference reflects that elapsed wall-clock time (would read 0ms if frozen). `dev_clock_wiring_test.dart`'s second test confirms a simulated 23:59 rolls into the next day's schedule after a 2-minute `shift()`, proving the offset composes with real elapsed time rather than sticking. |
| 3 | The override survives a page reload and is impossible to leave on by accident — always visibly indicated | VERIFIED | Persistence: `DevClock` writes/reads `dev_clock_offset_micros` via `SharedPreferences` (`_persist()`, `init()`); `dev_clock_test.dart` "an offset set, then init() called again, restores it" simulates a fresh launch (`resetForTest()` then `init()`) and confirms the offset survives — genuine reload-persistence coverage, not just an in-memory assertion. Visibility: `today_screen.dart:_buildDevClockBanner` renders an `errorContainer`-colored "Simulated time — …" banner gated on `kDebugMode && DevClock.isActive`, wired into both the active-schedule branch (using build()'s single `nowDt` sample, preserving Phase 24's D-01 single-clock-read discipline) and the empty-state branch (reads `DevClock.now()` fresh for display only — no day-state derivation happens in that branch, so D-01 is not violated). The Settings screen additionally shows "Simulated: `<date, time>`" / "Off — showing real time" as a redundant second indicator. |
| 4 | Release builds are unaffected — override cannot be set, clock is exactly `DateTime.now()` | VERIFIED BY INSPECTION, NOT BY TEST (see Judgment Call 1) | Every mutator (`setSimulatedNow`, `shift`, `clear`) and `init()` opens with `if (!kDebugMode) return;` (`dev_clock.dart` lines 43, 60, 68, 76). All Settings UI controls that call these mutators are wrapped in `if (kDebugMode)` at the widget-tree level (`settings_screen.dart` — 10 separate `if (kDebugMode)` guards around the debug section, belt-and-braces on top of DevClock's own internal gating). The two ungated `@visibleForTesting` hooks (`resetForTest`, `setOffsetForTest`) are called ONLY from test files (`grep` across `lib/` and `test/` confirms zero production call sites) — nothing in `lib/` reaches them, so they cannot introduce a non-zero offset in a shipped build. `kDebugMode` is `true` under `flutter test`, so the release no-op branches are structurally unreachable from the automated suite — this claim rests on code inspection, not a passing release-mode test. |

**Score:** 4/4 success criteria verified (3 by test + inspection, 1 — release safety — by inspection only, explicitly not proven by an executable test; see below).

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|---|---|---|---|
| DEV-01 | Debug-only clock override puts the whole app into a simulated moment — timeline, "today" key, end-of-day card all agree | SATISFIED | See Truth #1. Wiring test + Dan's live UAT. |
| DEV-02 | Offset not frozen instant; time keeps flowing; survives page reload; always visibly indicated | SATISFIED | See Truths #2 and #3. |
| DEV-03 | Release builds unaffected — override cannot be set, clock is exactly `DateTime.now()` | SATISFIED BY INSPECTION | See Truth #4 and Judgment Call 1 below. Not proven by an executable test — this is a known, disclosed gap, not a silent one. |

No orphaned requirements — DEV-01..03 are the full set REQUIREMENTS.md maps to Phase 25, and all three appear in `25-01-SUMMARY.md`'s scope.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/dev/dev_clock.dart` | Offset-based static clock utility | VERIFIED | Exists, substantive (94 effective lines, full doc comments), all methods present and correctly gated. |
| `test/dev/dev_clock_test.dart` | Unit coverage of DevClock arithmetic | VERIFIED | 8 tests: advancing offset, persistence round-trip, shift composition, clear. All pass. |
| `test/dev/dev_clock_wiring_test.dart` | Integration coverage proving the override actually reaches consumers | VERIFIED | 2 tests: simulated day loads correct on-disk schedule (with a decoy real-day schedule present); simulated 23:59 rolls into next day after a shift. This is exactly the coverage class most likely to be skipped, and it exists. |
| `lib/main.dart` | `DevClock.init()` before notifier construction; `ScheduleNotifier(now: DevClock.now)` | VERIFIED | Line 40 (`await DevClock.init()`), line 51. |
| `lib/providers/schedule_notifier.dart` | `reloadToday()` that refreshes without re-registering the lifecycle observer | VERIFIED | `_loadToday()` private helper extracted; `init()` and `reloadToday()` both call it; `reloadToday()` does not call `addObserver`. No dedicated unit test for `reloadToday()` itself, but it is exercised transitively through the Today-screen re-arm test and Dan's live UAT. |
| `lib/screens/today/today_screen.dart` | Banner indicator + `_lastDevClockOffset` re-arm fix | VERIFIED | `_buildDevClockBanner` (line 329) correctly gated; `_lastDevClockOffset` tracking (lines 1082–1090) re-arms both centre-on-open one-shots on a DevClock offset change, closing the Phase 24/25 integration defect (commit `513552a`). Covered by `today_screen_test.dart`'s "a debug clock jump re-arms centre-on-open within the same day" test, which pins BOTH halves: a plain minute tick must NOT re-scroll (protects T-22-08), and an identical tick after a `DevClock.setOffsetForTest` jump MUST re-scroll. |
| `lib/data/repositories/hive_daily_schedule_repository.dart` | `getTodaysSchedule()` keys off `DevClock.now()` | VERIFIED | Line 33, with an inline comment noting local-time format must match `generateToday()`. This is the seam load-bearing for DEV-01 (decides which schedule loads) and it is the one directly covered by `dev_clock_wiring_test.dart`. |
| `lib/screens/settings/settings_screen.dart` | Debug UI: status tile, quick actions, absolute time picker | VERIFIED (exists, substantive, wired) — NO WIDGET TEST (disclosed gap) | All handlers present and route through `DevClock` mutators then `ScheduleNotifier.reloadToday()` + `setState`. Entirely `kDebugMode`-gated at the widget-tree level. No test file exercises this screen's debug section — acknowledged directly in the SUMMARY's addendum, not hidden. |
| `tools/serve-uat.py` | Supporting UAT infra (no-store Cache-Control) | VERIFIED | Present, used by Dan's 2026-08-10 UAT run per `24-UAT.md`; documented as CLAUDE.md trap #3. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `main.dart` | `DevClock` | `DevClock.init()` called before `ScheduleNotifier` construction | WIRED | Confirmed by read; also confirmed indirectly by SUMMARY's "headless boot check" (all 8 Hive boxes open, no JS errors). |
| `today_screen.dart` build() | `DevClock` | Single `nowDt = _nowFn()` sample threaded to 4 consumers | WIRED | No regression to Phase 24's D-01 single-clock-read rule — confirmed by direct read of the `nowDt` sampling comment block and its four use sites. |
| `settings_screen.dart` handlers | `DevClock` mutators | `_handleDevClockShift`/`JumpTo9pm`/`Reset`/`SetAbsolute` → `DevClock.*` → `_afterDevClockChange` → `ScheduleNotifier.reloadToday()` + `setState` | WIRED | Confirmed by read of all four handlers; the "no widget test" gap means this link's *automated* proof stops at the DevClock/reloadToday layer, but it is proven live by Dan's UAT (Jump to 9pm today is the literal path exercised in `24-UAT.md`). |
| `hive_daily_schedule_repository.dart` | `DevClock` | `DevClock.now()` feeds `dateYmd` computation | WIRED | Directly test-covered (`dev_clock_wiring_test.dart`), the strongest-evidence link in the phase. |
| `today_screen.dart` build() | centre-on-open one-shots | `DevClock.offset` change resets `_didCentreLiveRow`/`_didCentreMarker` | WIRED | Test-covered (`today_screen_test.dart` re-arm test) and the fix for a real defect found during this phase (commit `513552a`), confirmed present by direct read of lines 1082–1090. |

### Data-Flow Trace (Level 4)

`DevClock.now()` → `HiveDailyScheduleRepository.getTodaysSchedule()`'s `dateYmd` key → the schedule
actually loaded from Hive. This is not a static/hardcoded return: `dev_clock_wiring_test.dart` uses
two REAL on-disk `DailySchedule` records (one keyed to the real day, one to a simulated day 40 days
away) and proves the correct one is returned depending on `DevClock`'s state — this is the specific
check that rules out a hollow "override exists but the repository still reads `DateTime.now()`"
failure mode. FLOWING.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full test suite passes | `flutter test` | `515 passed, 0 failed` (via `flutter test` full run) | PASS |
| Static analysis clean | `flutter analyze` | `No issues found!` | PASS |
| DevClock wiring test exists and names the load-bearing case | enumerated in `test/dev/dev_clock_wiring_test.dart` | 2 tests present, both pass as part of the full run above | PASS |
| Re-arm regression test exists (protects both the fix and the pre-existing T-22-08 invariant) | enumerated in `test/screens/today_screen_test.dart` | test present, passes as part of the full run above | PASS |
| No production call sites reach the two ungated `@visibleForTesting` hooks | `grep -rn "resetForTest\|setOffsetForTest" lib/ test/` | 2 matches in `lib/dev/dev_clock.dart` (definitions), 7 matches across 3 test files, 0 matches elsewhere in `lib/` | PASS |
| `timeline.dart` has no `DateTime` reads outside its doc comment (Phase 24 invariant, regression check) | `grep -n "DateTime" lib/screens/today/timeline.dart` | 1 match, in the `INVARIANT 1` doc comment | PASS |

Full suite run once (per the spot-check constraint against re-running it per must-have); analyze
run once. Both commands executed directly in this verification pass, not taken from SUMMARY prose.

### Probe Execution

Not applicable — this phase is not a migration/tooling phase with a `scripts/*/tests/probe-*.sh`
convention. Skipped.

### Anti-Patterns Found

No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers found in any of the phase's modified
files (`dev_clock.dart`, `main.dart`, `schedule_notifier.dart`, `today_screen.dart`,
`hive_daily_schedule_repository.dart`, `quarterly_review_screen.dart`, `settings_screen.dart`).
No empty-implementation patterns (`return null`/`{}`/`[]`, no-op handlers) found in the new/modified
DevClock-related code paths. The two disclosed gaps (DEV-03 not test-proven, Settings UI has no
widget test) are documented directly in the SUMMARY's orchestrator addendum rather than hidden —
treated below as judgment calls, not silent anti-patterns.

## Judgment Calls

### 1. DEV-03 (release safety): proven by inspection, not by test — accepted, disclosed

`kDebugMode` is compile-time `true` under `flutter test`, so there is no way for this repo's
existing test tooling to execute the `!kDebugMode` early-return branches and observe a release
build's behavior. The SUMMARY's addendum states this plainly rather than claiming test coverage it
doesn't have. My own inspection (Judgment Call basis):

- Every mutator (`setSimulatedNow`, `shift`, `clear`) and `init()` has `if (!kDebugMode) return;`
  as its first statement — confirmed by direct read of `dev_clock.dart`.
- `now()` itself has no `kDebugMode` branch at all — it always computes `DateTime.now().add(_offset)`.
  Its release-safety is entirely a function of `_offset` never becoming non-zero, which depends
  entirely on the mutators' gating above.
- The only two methods that write `_offset` directly without a `kDebugMode` check
  (`resetForTest`, `setOffsetForTest`) are marked `@visibleForTesting` and have zero call sites
  outside `test/` (confirmed by grep across the whole `lib/` tree).
- All UI entry points to the mutators (`settings_screen.dart`) are additionally wrapped in
  `if (kDebugMode)` at the widget level, so even a hypothetical bug in DevClock's own internal gate
  would still be shielded by the caller.

This is a real, believable guarantee — but it is inspection, not proof. I am not upgrading it to
"verified by test" and neither should any future reader of this report. If a `kReleaseMode`-forcing
test harness is ever added to this repo, this is the one gap worth closing with it. Not a blocker:
the goal statement is about debug-build UAT capability, and the inspection evidence is strong.

### 2. Missing widget test for the Settings debug UI — accepted, disclosed

The Settings screen's "Time travel" section (status tile, quick actions, absolute-time picker) has
no dedicated widget test. The handlers are thin wrappers — each does `await DevClock.<mutator>()`
then `await ScheduleNotifier.reloadToday()` then `setState`— over two already-tested seams
(`DevClock`'s own arithmetic, and `HiveDailyScheduleRepository`'s DevClock-keyed lookup). The first
real exercise of this UI was Dan's own use, captured in `24-UAT.md`: "Jump to 9pm today" was the
literal control he clicked, and it worked correctly end to end in a real browser. Given (a) the
thinness of the wrapper logic, (b) the strength of the underlying test coverage, and (c) a genuine
successful live UAT run through this exact control, I accept this as a reasonable scope boundary
for a debug-only dev-tooling phase rather than a gap requiring closure. It is recorded here so a
future reader can weigh it themselves rather than have it silently absorbed into "passed."

### 3. No PLAN.md — process deviation, not a code gap

Already covered in the Process Note above. This does not affect goal achievement (the code and
tests are real and verified independently of any plan artifact), but it is a genuine hole in the
`.planning/` trail that this repo's public work-sample framing calls for surfacing rather than
smoothing over.

## Regression Checks (Phase 24 invariants)

- `lib/screens/today/timeline.dart`: still has no `DateTime` reads outside its `INVARIANT 1` doc
  comment. CONFIRMED (grep, single match, in the comment).
- `TodayScreen.build()`: still samples the clock exactly once per render (`nowDt = _nowFn()`,
  line 1055) and threads that single sample to all four downstream consumers, including the newly
  added `_buildDevClockBanner` in the active-schedule branch. CONFIRMED by direct read. The
  empty-state branch's banner reads `DevClock.now()` fresh, but that branch has no day-state
  derivation to disagree with, so this does not reintroduce the multi-read hazard D-01 guards
  against — confirmed by reading the empty-state branch and its accompanying comment.
- `flutter test`: 515/515 passing (up from Phase 24's 504 baseline: +8 `dev_clock_test.dart` +
  2 `dev_clock_wiring_test.dart` + 1 today_screen re-arm test = 515). Re-run directly in this
  verification pass, not taken on the SUMMARY's word.
- `flutter analyze`: clean. Re-run directly in this verification pass.

## Human Verification Required

None outstanding. The one item that would normally require human verification — does the debug
harness actually work end to end in a real browser — was already performed by Dan on 2026-08-10 and
is documented with a build ID and commit hash in `24-UAT.md` (3/3 tests passed, all three explicitly
attributed to "via the Phase 25 time-travel harness"). No further human verification is being
requested by this report.

## Gaps Summary

No blocking gaps. Two disclosed, accepted judgment calls (DEV-03 proven by inspection rather than
test; Settings UI untested by widget test) and one process deviation (no PLAN.md) are recorded
above rather than smoothed over, consistent with this phase's dev-tooling scope and the strength of
the end-to-end evidence from Dan's own UAT run.

---

_Verified: 2026-08-10_
_Verifier: Claude (gsd-verifier)_
