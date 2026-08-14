---
phase: 22-unified-today-screen
verified: 2026-08-07T22:30:00Z
status: passed
score: 11/11 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Open the served debug build on a phone-width viewport (<720dp) and a desktop-width viewport (>=720dp). Scroll to a moment mid-day where a chunk is Active."
    expected: "The current activity renders as a swelled primaryContainer card in place in the list (16dp radius, soft elevation, uppercase 'RIGHT NOW' kicker, titleLarge title, progress bar, Complete/Skip buttons, 'Next · ...' line) — matching 22-UI-SPEC.md's 'The live row' section and the reference render in 22-CONTEXT.md. Free-time rows read as quiet dotted-rule text, never blank space. Breaks show a dashed outline with no fill. Commitments show tertiaryContainer with no outline. Completed/skipped chunks are struck through and dimmed."
    why_human: "Visual treatment (colors, dashed/dotted CustomPainter rendering, opacity ramps, spacing) cannot be confirmed by grep or widget-test assertions alone — tests check for the presence of widgets/strings/colorScheme references, not that the painted result matches the sketch aesthetically."
  - test: "Open the app fresh (cold start) on a day with a schedule and a mid-day current chunk, positioned several rows down the list."
    expected: "On open, the list scrolls smoothly (250ms ease-out) to bring the live row to roughly the vertical centre of the viewport, and does not jump or re-scroll again while reading (e.g. across a 1-minute tick)."
    why_human: "The centre-on-open mechanism is unit-verified (scroll offset changes once, not twice) but the actual feel/smoothness and correctness of 'centred' at real device sizes needs a human eye — the automated test only checks the offset moved off zero, not that the row is visually centred."
  - test: "On a low-mood (1-2) day, confirm the restoratives suggestion card appears above the timeline; on mood 3+, confirm it does not. Check the mood chip text and emoji for each of the 5 mood levels."
    expected: "Chip reads '<emoji> <Low/Cloudy/Steady/Bright/Sunny> day · N chunks' and restoratives only shows for mood <= 2, per today_screen.dart's _moodLabels map."
    why_human: "Mood-to-copy mapping and emoji rendering are visual/copy correctness checks best done by a human skimming a few real mood states, not grep."
  - test: "Trigger the empty state (no schedule yet) at both phone and >=720dp widths."
    expected: "All four affordances are present and usable: the breathing-pulse 'Start your day' CTA, 'Add an event', the web check-in banner (web only), and the 'Plan your day in 30 seconds' headline — content constrained to 720dp on desktop."
    why_human: "Automated tests assert each widget exists in the tree; whether the reconciled empty state reads coherently as a single composed screen (not a visually awkward stack of two old screens' parts) needs a human look."
gaps: []
---

# Phase 22: Unified Today Screen Verification Report

**Phase Goal:** Home and Schedule merge into a single destination — users see what's happening now
and the rest of the day without switching tabs, and every existing entry point still lands
somewhere real
**Verified:** 2026-08-07T22:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Opening the app lands the user on one screen showing both what's happening now and the rest of the day's chunks — no tab switch | ✓ VERIFIED | `lib/router.dart:26` `initialLocation: '/today'` → `TodayScreen`. `today_screen.dart` build() calls `resolveNowState` once, `buildTimeline` once, and renders one `SingleChildScrollView` containing the live row (`LiveRowCard`) inline among all other rows (`today_screen.dart:731-800`). No separate "now" region exists. |
| 2 | Shell's destination list reflects the merge — Home and Schedule no longer point at two separate screens | ✓ VERIFIED | `lib/widgets/responsive_shell.dart:45-48` — `_destinations` has exactly 3 entries: Today, Goals, Settings. No "Home" or "Schedule" label anywhere in `lib/` (grep confirmed). |
| 3 | Tapping a Chunk reminder notification lands on the working unified screen, not dead/blank | ✓ VERIFIED | `lib/main.dart:86` unmodified: `router.go('/schedule')`. `lib/router.dart:41` redirects exact-match `/schedule` → `/today`, running after the onboarding gate. `test/screens/router_redirect_test.dart` reproduces this literal call and asserts resolution to `/today` (test passed in full-suite run). |
| 4 | "See full schedule" link resolves to something coherent post-merge, not a stale destination | ✓ VERIFIED | `home_screen.dart` (which held the link at line 495) is deleted. Grep for "See full schedule" in `lib/` returns zero hits — the affordance is removed, not repointed (matches 22-CONTEXT.md's explicit decision that repointing would self-link). |

### Observable Truths (Requirement-Level, UNIFY-01 / UNIFY-02)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 5 | The current activity swells in place at its own clock position — no separate now card/hero/sticky bar | ✓ VERIFIED | `_buildLiveRow`/`LiveRowCard` renders inline via the `ChunkRow(isLive: true)` case in the same row-dispatch switch as every other row type (`today_screen.dart:462-489`). Grep for "Jump to now" (sticky-pill negative gate) returns nothing. |
| 6 | Free time is named, never collapsed to blank space (>=10min gaps only) | ✓ VERIFIED | `lib/screens/today/timeline.dart` implements `kMinGapMinutes = 10` and emits `LeadingFreeRow`/`GapFreeRow`; `FreeTimeRow.until`/`.gap` render locked copy strings. Unit-tested in `today_timeline_model_test.dart` including the exact 10-min-inclusive / 9-min-suppressed boundary. |
| 7 | `resolveNowState` is the single "now" detector — no code path can disagree with it | ✓ VERIFIED | Grepped all of `lib/` for `firstOrNull`/`firstWhere` combined with unresolved-chunk scans and for stray `DateTime.now()` calls in `lib/screens/today/` — none found outside `now_state.dart`'s doc comment. `resolveNowState(` is called exactly once in `today_screen.dart:731`. The AppBar's "Start focus" affordance (`_buildAppBar`, `today_screen.dart:658-677`) — the third detector a later code review found — now derives its target from the same `nowState` via an exhaustive switch (`Active→current, Overdue→overdue, GapBeforeNext→next, PreStart→firstChunk, DayComplete→null`), confirmed present in the current file, not merely claimed in a SUMMARY. |
| 8 | Every existing entry point resolves to a real route (no dead route) | ✓ VERIFIED | Independently enumerated every `.go(`/`.push(`/route-literal in `lib/` (not copied from any plan). All resolve to a declared `GoRoute`: `/today`, `/schedule`→redirect, `/schedule/checkin`, `/onboarding`, `/review`, `/commitments`, `/restoratives`, `/summary`, `/focus`, `/goals`, `/goals/archived`, `/settings`, `/settings/past-reviews`. No orphaned literal found. |
| 9 | `/schedule/checkin` is not swallowed by the `/schedule`→`/today` redirect | ✓ VERIFIED | `lib/router.dart:41` uses exact `matchedLocation == '/schedule'`, not `startsWith`. `/schedule/checkin` is a declared child route under the same branch. `router_redirect_test.dart` has explicit cases for `/schedule/checkin` in both onboarding states, both pass. |
| 10 | Deleted surface (`home_screen.dart`, `schedule_screen.dart`, `active_chunk_card.dart`, `now_marker.dart`) is fully gone and unreferenced | ✓ VERIFIED | All four files confirmed absent on disk. `lib/screens/home/` directory confirmed absent. Grep for `HomeScreen\|ScheduleScreen\|ActiveChunkCard\|NowMarker\|'/home'` across `lib/` and `test/` returns zero hits. |
| 11 | Full test suite is green and `flutter analyze` is clean | ✓ VERIFIED | Ran independently: `flutter test` → 420/420 passed. `flutter analyze` → "No issues found!". Matches the SUMMARY's claimed count exactly. |

**Score:** 11/11 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/screens/today/now_state.dart` | NowState + resolveNowState, zero widget deps | ✓ VERIFIED | 182 lines (min 150). Sole `resolveNowState` definition in the tree. |
| `lib/screens/today/timeline.dart` | TimelineRow hierarchy + buildTimeline | ✓ VERIFIED | 92 lines (min 90). No `DateTime` reference outside comments. |
| `lib/screens/today/widgets/timeline_row_tile.dart` | 46dp gutter | ✓ VERIFIED | 57 lines (min 40). `kGutterWidth = 46`, `tabularFigures` confirmed present. |
| `lib/screens/today/widgets/free_time_row.dart` | Named free-time rows | ✓ VERIFIED | 85 lines (min 50). Locked copy strings present, no Card. |
| `lib/screens/today/widgets/live_row_card.dart` | Swelled live row | ✓ VERIFIED | 157 lines (min 120). primaryContainer, LinearProgressIndicator, showActions, clamp all present; zero raw `Colors.*`. |
| `lib/screens/today/widgets/breathing_pulse_cta.dart` | Lifted CTA, survives home_screen deletion | ✓ VERIFIED | 126 lines (min 100). Exists independently of the deleted `home_screen.dart`. |
| `lib/screens/today/today_screen.dart` | Merged destination | ✓ VERIFIED | 901 lines (min 380). Contains header, mood chip, edge-state line, day timeline, live row, empty state, AppBar actions — all confirmed present by direct read, not by grep alone. |
| `lib/screens/schedule/widgets/chunk_card.dart` | Extended row vocabulary | ✓ VERIFIED | showStartTime, lineThrough, tertiaryContainer, dashed-border painter all present; zero raw `Colors.*` outside comments. |
| `lib/router.dart` | 3 branches, `/today` canonical, `/schedule` redirect + fallback | ✓ VERIFIED | Read in full; matches plan exactly, including the belt-and-braces defensive `/schedule` builder. |
| `lib/widgets/responsive_shell.dart` | 3 destinations | ✓ VERIFIED | Read in full; `_destinations` has exactly Today/Goals/Settings; superseded-lock comment present per D-09. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `timeline.dart` | `now_state.dart` | `buildTimeline(nowState:)` | ✓ WIRED | Required named param, verified in source. |
| `today_screen.dart` | `timeline.dart` | `buildTimeline(...)` called once | ✓ WIRED | Confirmed single call site at line 732. |
| `today_screen.dart` | `now_state.dart` | `resolveNowState(...)` called once | ✓ WIRED | Confirmed single call site at line 731; also the sole call site of `resolveNowState(` in all of `lib/`. |
| `today_screen.dart` | `live_row_card.dart` | isLive row renders `LiveRowCard` | ✓ WIRED | `_buildLiveRow` returns a real `LiveRowCard` with screen-computed kicker/remainingLabel/progress/nextLine — not a stub. |
| `main.dart` | `router.dart` | `router.go('/schedule')` on notification tap | ✓ WIRED | main.dart unmodified; redirect resolves it to `/today`; regression test reproduces the literal call. |
| `lib/router.dart` | `today_screen.dart` | branch 0 builder | ✓ WIRED | `GoRoute(path: '/today', builder: ... TodayScreen())`. |
| `responsive_shell.dart` | `router.dart` | positional destination-to-branch order | ✓ WIRED | 3 destinations match 3 branches (Today=0, Goals=1, Settings=2) — confirmed by reading both files together. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| UNIFY-01 | 22-01, 22-02, 22-03 | One screen, now + rest of day, no tab switch | ✓ SATISFIED | Truths 1, 5, 6, 7 above. |
| UNIFY-02 | 22-04 | Shell reflects merge, every entry point lands somewhere real | ✓ SATISFIED | Truths 2, 3, 4, 8, 9, 10 above. |

No orphaned requirements — REQUIREMENTS.md's "Unified Today Screen" section maps only UNIFY-01/02 to Phase 22, and both appear in plan frontmatter (`22-01`/`22-02`/`22-03` declare `requirements: [UNIFY-01]`; `22-04` declares `requirements: [UNIFY-02]`).

### Anti-Patterns Found

None. Scanned all files created/modified in this phase (`lib/screens/today/**`, `lib/router.dart`, `lib/widgets/responsive_shell.dart`, `lib/screens/schedule/widgets/chunk_card.dart`, `lib/screens/schedule/widgets/swipeable_chunk_card.dart`) for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER|coming soon|not yet implemented` — zero hits. No hardcoded `Colors.*` outside comments in the row-vocabulary widgets (the standing tech-debt item from `chunk_card.dart` is confirmed closed).

### The Phase's Chartered Hazard — independently re-verified

22-PATTERNS.md section 5 flagged a competing "now" detector (`_buildActiveChunkItems` in the now-deleted `schedule_screen.dart`). I independently confirmed:
- `resolveNowState(` has exactly one call site in all of `lib/` (`today_screen.dart:731`).
- No `firstOrNull`/`firstWhere` pattern scanning for "first unresolved chunk" exists outside `now_state.dart` itself.
- A third, later-discovered detector (the AppBar's "Start focus" button, flagged as WR-01 in the code review at `22-REVIEW.md`) was fixed in commit `8bb253a` and independently re-read in the current source: it now derives its target from the same `nowState` via an exhaustive switch, not a fresh scan. I did not rely on the SUMMARY's claim alone — I read the live code at `today_screen.dart:658-677` and confirmed the switch statement matches the described fix.
- Two independent code-review iterations exist for this phase (`22-REVIEW.md` iteration 1: 2 warnings + 1 info found and fixed; `22-REVIEW.iter2.md`: re-examined the fixed code directly, including reverting to pre-fix state and confirming the new regression tests actually discriminate). This is a stronger-than-usual evidence trail and I independently re-confirmed its central claims rather than accepting them at face value.

### Test Count Delta (428 → 420)

Independently ran the full suite: 420/420 pass, matching the SUMMARY's claimed final count. The reduction from the 22-03 checkpoint (428) is explained in 22-04-SUMMARY.md as: +5 new/changed router-redirect cases, −14 deleted `active_chunk_card_test.dart` cases (re-homed per an explicit 14-row coverage map cross-checked against `grep -n 'testWidgets('` on the deleted file before deletion — the plan's own process included a STOP-and-report gate if any row was unaccounted for), −1 now-moot `NowMarker` negative-assertion case (the type no longer exists, so a stronger guarantee than a runtime check). I did not re-verify each of the 14 individually re-homed assertions line-by-line against their new locations, but the coverage-map process itself was gated and auditable, and the resulting 420-count and 0-analyze-issues state is independently confirmed.

### Human Verification Required

Four items — all genuine visual/UX checks that automated grep and widget-pump assertions cannot settle (presence-of-widget is not the same as correct-visual-rendering). Listed in the frontmatter `human_verification` block above with concrete test/expected/why-human detail. In summary: (1) live-row and row-vocabulary visual conformance to 22-UI-SPEC.md, (2) centre-on-open scroll feel at real device sizes, (3) mood chip copy/emoji correctness across the 5 mood levels, (4) empty-state visual coherence as a single composed screen.

### Gaps Summary

No gaps. All 11 derived truths (roadmap's 4 success criteria plus 7 requirement-level truths) are verified against the actual codebase — files read directly, entry points enumerated independently (not copied from the plan), the chartered now-detector hazard specifically re-checked including the later-discovered third detector, and the full test suite plus analyzer run fresh rather than trusted from the SUMMARY. Status is `human_needed` solely because this phase does real visual/interaction work that only a human eye can confirm renders as the UI-SPEC intends — not because any automatable check failed.

---

_Verified: 2026-08-07T22:30:00Z_
_Verifier: Claude (gsd-verifier)_
