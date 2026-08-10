---
phase: 24-where-am-i
verified: 2026-08-08T23:30:00Z
status: passed
score: 6/7 must-haves verified (1 perceptual truth partially confirmed — see below)
overrides_applied: 0
human_verification:
  - test: "Open http://danserver:8123/ (Dan's real schedule data, debug build) at a time of day when the day's schedule is entirely in the past (i.e. after the last chunk's end time — the DayComplete state). If it's not currently that time of day, use the browser devtools or simply revisit after the day's last chunk ends."
    expected: "The page opens already scrolled near the BOTTOM of the list, with a 'Now' marker row (a horizontal rule + the word 'Now' + a fading rule, in the theme's primary color) visible without any manual scrolling. You should NOT need to scroll up from the top to find it."
    why_human: "This is the exact defect Dan reported in 24-03 ('now were done and it's hard to tell') and the exact fix 24-04 shipped (auto-scroll-to-marker fallback when no live row exists). The automated widget test (today_screen_test.dart, 'DayComplete overflow, 24-04') proves the underlying Scrollable.ensureVisible mechanics work against a synthetic fixture, but only Dan's own eyes in a real browser against his real data can confirm the *perceptual* claim — 'is now findable at a glance' — which is precisely the class of claim this phase exists to satisfy after the first widget-tests-green-but-Dan-still-confused round (24-03)."
  - test: "While on the same page, also check the PreStart and GapBeforeNext moments if convenient (e.g. before the day's first chunk starts, or during a gap between chunks) — confirm the marker is visible without scrolling in those cases too, since 24-04 applied the identical fallback to all three no-live-row states, not just DayComplete."
    expected: "Same as above: the marker is visible on open, no manual scroll required."
    why_human: "24-04's fix and its regression tests exercise DayComplete explicitly; PreStart/GapBeforeNext share the identical code path (same `hasMarkerRow` guard) but were not separately UAT'd by Dan. Lower priority than the DayComplete check above since Dan didn't report a problem in those states, but worth a quick look since they share the exact fix."
---

# Phase 24: Where Am I — Verification Report

**Phase Goal:** "The timeline itself shows where 'now' falls, so the user can locate themselves in the day even when no activity is currently running"
**Verified:** 2026-08-08T23:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification (no prior `24-VERIFICATION.md` existed)

## Why human_needed, not passed

Every automatable truth below is VERIFIED against the codebase as it stands at `HEAD` (`fa885c6`),
not merely claimed by a SUMMARY. `flutter analyze` is clean and `flutter test` is 504/504 (both
re-run independently by this verifier, not taken from a SUMMARY's self-check). But the phase's own
success criterion 1 is a **perceptual** claim ("so the user can locate themselves... by looking at
the timeline"), and this phase's own history is that an implementation which passed every automated
test still left Dan unable to answer "where am I" (24-03's UAT). Dan's real-browser re-verification
of the fix that plan 24-04 shipped for the `DayComplete` case has **not yet happened** — he confirmed
only the mid-day/`GapBeforeNext` case in 24-03, before 24-04 existed. Marking this phase `passed` on
the strength of widget tests alone would repeat exactly the mistake that produced 24-03's UAT report
in the first place. Per this task's explicit instruction, `human_needed` is the honest verdict here,
not `passed`.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `timeline.dart` never reads the clock (INVARIANT 1) | ✓ VERIFIED | Full file read; the only `DateTime` tokens in the file are inside doc comments (lines 16, 50-58). `nowMinutes`/`nowState` arrive as parameters. |
| 2 | `buildTimeline` preserves chunk order, never re-sorts (INVARIANT 2) | ✓ VERIFIED | Single `for (final chunk in chunks)` loop, rows appended in iteration order; no `.sort(` call anywhere in the file. |
| 3 | `buildTimeline` emits exactly one `NowMarkerRow` for `PreStart`/`GapBeforeNext`/`Overdue`/`DayComplete`, zero for `Active` | ✓ VERIFIED | `showMarker = nowMinutes != null && nowState is! Active` (timeline.dart:84); insertion + fallback-at-end logic (lines 119-131); model tests at `today_timeline_model_test.dart:277-371` (`'buildTimeline — now-marker (NOW-01)'` group) exercise all four states plus the Active-suppression case; `flutter test` green. |
| 4 | Leading `Free until <time>` row suppressed once its window has closed (NOW-02), still renders while open | ✓ VERIFIED | `timeline.dart:103`: `if (start > 0 && (nowMinutes == null \|\| nowMinutes < start))`; tests at `today_timeline_model_test.dart:92-127` cover before/after/omitted-nowMinutes cases. |
| 5 | A visible `Now` row appears in the rendered `TodayScreen` for `PreStart`/`GapBeforeNext`/`DayComplete`, none for `Active` | ✓ VERIFIED | `today_screen.dart:596-626`, the fourth exhaustive-switch arm; renders `NowMarker` inside `TimelineRowTile`; screen-level tests assert `find.byType(NowMarker)`. |
| 6 | D-01: `build()` samples the clock exactly once (`nowDt = _nowFn()`) and every render-path consumer derives from it — no second clock read anywhere in the render path | ✓ VERIFIED | `today_screen.dart:1008-1010` single `_nowFn()` call threaded to `resolveNowState`, `_liveSecondsRemaining`, `nowMinutes`, and `_shouldShowEodCard`. Two pre-existing violations found and fixed during this phase's own gates, confirmed via `git blame`/commit inspection: `a8966b4` (EOD card read its own `DateTime.now`, caught by the orchestrator's post-merge gate, not the executor) and `159e45e`/WR-02 (`_buildHeader` read `_nowFn()` independently — code-review finding, now threaded through `nowDt` parameter). Both commits confirmed present on `HEAD` via `git log`. |
| 7 | D-02: centre-on-open is one-shot per day, not a listener; the new marker-fallback (24-04) is a genuinely separate flag that doesn't suppress the live-row centring | ✓ VERIFIED | `_didCentreLiveRow`/`_didCentreMarker` are separate booleans, both flipped synchronously before the post-frame callback (today_screen.dart:1030-1077), both reset together on day-boundary change (line 229-230). The load-bearing "two-flag regression" test (`today_screen_test.dart:834-880`) was independently re-run by this verifier and passes — it specifically fails under a single-shared-flag design. |
| 8 | D-03: no sticky bar, floating pill, or jump button was added | ✓ VERIFIED | `grep -iE "sticky\|floating.*pill\|jump.*button\|jumpTo"` across `today_screen.dart` returns only doc-comment references describing the *rejected* approach — no such widget exists in the tree. |
| 9 | Exhaustive `TimelineRow`/`NowState` switches carry no `default:` arm | ✓ VERIFIED | `grep -n "default:"` across `today_screen.dart`, `timeline.dart`, `now_state.dart` returns nothing. |
| 10 | Screen-reader users get one clean announcement for the marker row, not two (WR-01 fix) | ✓ VERIFIED | `Semantics(excludeSemantics: true, ...)` now wraps the whole `TimelineRowTile` (today_screen.dart:618-625), not just `NowMarker`, per the code review's fix. Regression test at `today_screen_test.dart:578-610` (`ensureSemantics()` + `find.bySemanticsLabel`) independently re-run by this verifier, passes. |
| 11 | **Perceptual: "where am I" is answerable by looking at the timeline, in a real browser, for every `NowState`, not just the mid-day case** | ? UNCERTAIN (human_needed) | Mid-day/`GapBeforeNext` case **confirmed by Dan** in 24-03 ("it did look a lot better when i saw it"). `DayComplete` case **failed** in that same UAT round and was routed to 24-04. **24-04's fix has not yet been re-verified by Dan in the running app** — see below. |

**Score:** 10/11 truths verified programmatically; 1 perceptual truth (the phase's actual reason for
existing) partially confirmed and awaiting Dan's re-check.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/screens/today/timeline.dart` | `NowMarkerRow` subtype, `nowMinutes` param, NOW-02 guard | ✓ VERIFIED | Class present (line 42-45), guard present (line 103), wired into `_buildTimelineRow`. |
| `lib/screens/today/widgets/now_marker.dart` | Quiet `Now` row widget | ✓ VERIFIED | 44 lines, exports `NowMarker`, matches 24-UI-SPEC.md description (rule + label + fading rule). |
| `lib/utils/time_format.dart` | Shared `minutesOfDay` | ✓ VERIFIED (not directly re-read, but referenced/used consistently across `now_state.dart` and `today_screen.dart`, `nowMinutes = minutesOfDay(nowDt)` at `today_screen.dart:1009`) | |
| `lib/screens/today/today_screen.dart` | `nowMinutes` threaded, fourth switch case, `_nowMarkerKey`/`_didCentreMarker` fallback | ✓ VERIFIED | All present and wired (see truths 5-8 above). |
| `test/screens/today_timeline_model_test.dart`, `today_row_widgets_test.dart`, `today_screen_test.dart` | NOW-01/NOW-02 coverage, DayComplete overflow + two-flag regression tests | ✓ VERIFIED | All present; independently re-run, pass. |
| `.planning/phases/24-where-am-i/24-VALIDATION.md` | Manual-Only Verifications row closed | ✓ VERIFIED (as PARTIAL PASS, not clean pass) | Row explicitly records the `DayComplete` failure and routes it to 24-04; does not claim a clean pass. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `today_screen.dart build()` | `buildTimeline` | `nowMinutes: nowMinutes` | ✓ WIRED | `today_screen.dart:1019-1023` |
| `today_screen.dart _buildTimelineRow` | `now_marker.dart` | fourth switch case | ✓ WIRED | `today_screen.dart:596-626` |
| `today_screen.dart _buildTimelineRow` | screen readers | `Semantics` label at call site, enclosing the full tile | ✓ WIRED (fixed post-review) | `today_screen.dart:618-625`; WR-01 fix confirmed by regression test |
| `today_screen.dart build()` | `Scrollable.ensureVisible(_nowMarkerKey...)` | `!hasLiveRow && !_didCentreMarker && hasMarkerRow` | ✓ WIRED | `today_screen.dart:1063-1077`; DayComplete-overflow test independently re-run, passes |
| `now_state.dart` | `time_format.dart` | `minutesOfDay(nowDt)` | ✓ WIRED | consistent usage found at call sites |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `flutter analyze` clean | `flutter analyze` | "No issues found!" | ✓ PASS |
| Full suite green | `flutter test` | 504/504 passing | ✓ PASS |
| DayComplete scroll-to-marker fix works against synthetic fixture | `flutter test test/screens/today_screen_test.dart --plain-name "DayComplete overflow"` | 1/1 passed | ✓ PASS |
| Two-flag design doesn't suppress live-row centring | `flutter test ... --plain-name "two-flag regression"` | 1/1 passed | ✓ PASS |
| Semantics single-announcement fix (WR-01) | inspected `today_screen_test.dart:578-610`, re-run via full suite | passed | ✓ PASS |
| Debug build reachable, no stale service worker | `curl -sI http://danserver:8123/`, `curl -sI .../flutter_service_worker.js` | 200, 404 | ✓ PASS |
| Debug build content matches the 24-04 fix | `build/web/main.dart.js` mtime (18:08) vs commit `a8966b4` (18:07:03, the EOD-card D-01 fix folded into the same build) | build postdates `a8966b4` | ✓ CONFIRMED — see caveat below |

**Caveat on the served build's freshness:** `build/web/` was built at 18:07-18:08 local, which is
*after* `a8966b4` (18:07:03 — the D-01 end-of-day-card fix, part of 24-04's gate) but *before*
`159e45e` (18:21:19 — the WR-01/WR-02 code-review fixes). `git diff a8966b4..HEAD -- lib/` shows
only `today_screen.dart` changed by `159e45e`, and that change is screen-reader semantics wiring
plus a header-date clock-read consolidation — neither is visually observable in a sighted UAT pass.
**The DayComplete scroll-to-marker fix Dan needs to re-check is present in what's currently being
served at `http://danserver:8123/`.** The served build is not byte-identical to `HEAD`, but nothing
in the delta affects the pending visual check.

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| NOW-01 | 24-01, 24-02, 24-03, 24-04 | Visible now-marker at the current clock position, position-only (never a second detector) | ✓ SATISFIED (code) / ? PENDING (perceptual, DayComplete) | Marked `[x]` complete in REQUIREMENTS.md; code-level truths 1, 3, 5-10 above all verified; perceptual truth 11 partially confirmed |
| NOW-02 | 24-01, 24-02 | Leading "Free until" row never describes a closed window | ✓ SATISFIED | Marked `[x]` complete in REQUIREMENTS.md; truth 4 above verified in code and tests, and directly visible in Dan's 24-03 UAT (he did not re-report this specific defect after 24-02) |

No orphaned requirements: `REQUIREMENTS.md` maps only NOW-01 and NOW-02 to Phase 24 (`grep "Phase 24"`
confirms), and both appear in every plan's `requirements:` frontmatter that touches them. `CAL-01`,
`CAL-02`, `CAL-03` were added to REQUIREMENTS.md *from* Phase 24's UAT but are explicitly scoped to
the new Phase 25 ("Not started") — correctly out of this phase's responsibility, not a gap here.

### Anti-Patterns Found

None. No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers in any file this phase touched
(`timeline.dart`, `today_screen.dart`, `now_marker.dart`, `now_state.dart`, `time_format.dart`).
`git status --short` is clean — no uncommitted work. All commits referenced in the SUMMARYs
(`2d942a9`, `06c4c17`, `2e5a78b`, `8fd639e`, `dc1cb59`, `a8966b4`, `159e45e`, and the `docs(24-*)`
metadata commits) exist on the current branch via `git log`.

### Human Verification Required

See YAML frontmatter `human_verification` above for the two concrete, executable checks. Summary:

1. **Primary check (blocking):** Open `http://danserver:8123/` after the scheduled day is complete
   (`DayComplete` state) and confirm the `Now` marker is visible on open without manual scrolling —
   this is the literal re-test of Dan's 24-03 complaint against the 24-04 fix.
2. **Secondary check (non-blocking, lower priority):** Spot-check the same "visible on open, no
   scroll needed" behavior for `PreStart`/`GapBeforeNext` if convenient, since they share the
   identical fix but weren't individually UAT'd.

### Gaps Summary

No code-level gaps. The single open item is procedural, not a defect: Dan's real-browser
confirmation of the `DayComplete` fix (plan 24-04) has not yet happened. Everything that can be
verified by reading and running the code — the two invariants, the four locked decisions (D-01
through D-03 plus the single-detector rule), both requirement IDs, the two post-hoc gate fixes
(`a8966b4`, `159e45e`), and the full automated suite — holds. This phase should move to `passed`
as soon as Dan confirms the `DayComplete` case at `http://danserver:8123/`; if he reports the same
"hard to tell" defect again, that is a real regression against 24-04's own test suite and would
need fresh investigation (the widget test that encodes the fix is passing, so a repeat failure
would mean the test's fixture doesn't match some aspect of his real data/viewport).

---

_Verified: 2026-08-08T23:30:00Z_
_Verifier: Claude (gsd-verifier)_


---

## UAT closed — status human_needed → passed (2026-08-10)

All three human_verification items were executed by Dan in a real browser and passed. See
`24-UAT.md` for per-test results.

The blocking item — `DayComplete` opening with the now-marker on screen without a manual scroll —
is confirmed. That closes the loop on his 24-03 report (*"now were 'done' and it's hard to tell"*)
against the fix shipped in 24-04, in the only instrument that could settle it.

Reaching the state required building the Phase 25 time-travel harness first, since `DayComplete`
only exists after the day's last chunk ends and the running app had no clock seam the router used.
Two client-side false alarms (a heuristically-cached bundle, and a likely service worker on the
`:8123` origin) delayed that by two round trips; both are now diagnosable in one glance via the
`BUILD_ID` shown in Settings → Debug.

**Honest weighting of the evidence:** test 1 is load-bearing. Test 3 (no regression to the
already-approved Active case) is meaningful because 24-04 changed the scroll behaviour underneath
it. Test 2 (PreStart) is corroborating only — the marker is the second row there, so it is visible
whether or not the auto-scroll fires, and it cannot distinguish a working fallback from a no-op.
Phase 24's goal does not rest on it.
