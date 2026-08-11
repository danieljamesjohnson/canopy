---
phase: 26-the-day-has-a-shape
plan: 09
subsystem: ui
tags: [flutter, layout, now-line, gap-closure, regression-testing]

# Dependency graph
requires:
  - phase: 26-the-day-has-a-shape (plan 07)
    provides: G-01 fix — the now-line chip confined to kGutterWidth, closing the ordinary-ChunkCard collision
  - phase: 26-the-day-has-a-shape (plan 08)
    provides: kLiveRowReservedHeight corrected to a real-browser-measured 232.0, leaving G-03 as the only open gap
provides:
  - showChip parameter on NowLineOverlay, suppressing just the time chip (never the rule) while the line falls inside the live row's span
  - a G-03 regression test naming LiveRowCard directly, proven RED against the unfixed widget before being accepted
  - the existing G-01 test and the chip-copy test moved off a now-live clock (9:12) onto a genuinely non-live GapBeforeNext fixture, so they keep proving what they always meant to prove
  - a dated 26-UI-SPEC.md amendment recording the fix, the rejected alternatives, and the process failure that let G-03 ship as "closed" in 26-07
affects: [any future work touching lib/screens/today/widgets/now_line.dart, lib/screens/today/today_screen.dart's NowLineOverlay call site, or LiveRowCard]

tech-stack:
  added: []
  patterns:
    - "Real-browser verification via headless Chromium + localStorage-injected DevClock offset (flutter.dev_clock_offset_micros), reused unchanged from 26-08's technique, for exact simulated-time control instead of clicking coarse +1h/-1h UI buttons"
    - "RED-before-accept discipline for a regression test: temporarily force the pre-fix behavior at the call site, observe the new test fail, restore, observe it pass — both observations recorded in the SUMMARY, not just asserted"

key-files:
  created:
    - .planning/phases/26-the-day-has-a-shape/evidence-26-09/ (5 screenshots: before/after title-region crops, full-page work-live and non-live states)
  modified:
    - lib/screens/today/widgets/now_line.dart
    - lib/screens/today/today_screen.dart
    - test/screens/today_screen_test.dart
    - .planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md

key-decisions:
  - "Hide the chip specifically (not the whole overlay) while nowMinutes falls inside the live row's span; keep the rule crossing it — Dan's decision at the 26-09 planning gate, 2026-08-11. LiveRowCard already states the current time in its own copy (RIGHT NOW · <time>), so the chip is redundant there, not lost."
  - "Read the live span off TimelineGeometry.liveStartMinutes/liveEndMinutes, never recompute from resolveNowState or the chunk list — a second source of \"where is the live row\" is the exact regression class this phase has guarded against throughout."
  - "Moved the chip-copy and G-01 gutter-confinement tests off the 9:12 clock (which is now a live moment where the chip is suppressed) onto a 9:30/GapBeforeNext fixture, rather than special-casing the assertions — keeps each test proving exactly one thing."

requirements-completed: [CAL-02]

# Metrics
duration: ~25min
completed: 2026-08-11
---

# Phase 26 Plan 09: The chip yields to the live row (G-03) Summary

**Suppressed the now-line's time chip specifically while it falls inside `LiveRowCard`'s full-bleed span, closing Dan's original G-01 report (`26-UAT.md` G-03) that 26-07 had reported fixed but did not actually address — proven RED against the unfixed widget before being accepted.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-08-11
- **Tasks:** 3/3
- **Files modified:** 4 (`now_line.dart`, `today_screen.dart`, `today_screen_test.dart`, `26-UI-SPEC.md`) + 5 evidence images added

## Accomplishments

- Added a `showChip` bool parameter to `NowLineOverlay` (default `true`); the 2dp rule always renders, only the chip is conditional
- Computed `showChip` at the `today_screen.dart` call site from `TimelineGeometry.liveStartMinutes`/`liveEndMinutes` using the same half-open boundary convention already used for `liveExtraPx` (`>= liveStart && < liveEnd`) — never a second now-detector
- Wrote a dedicated `G-03` regression test that names `LiveRowCard` directly in its assertion — the exact class of assertion 26-07's `ChunkCard`-only test was missing — and **proved it RED against the unfixed widget before accepting it** (see below)
- Moved the pre-existing `chip copy` and `G-01` gutter-confinement tests off the 9:12 clock, which is now a live moment where the chip is correctly suppressed, onto a 9:30/`GapBeforeNext` fixture where no live row exists — each test still proves exactly the claim it always meant to prove
- Verified in a real browser (headless Chromium + localStorage-injected DevClock, reusing 26-08's technique) against a **WORK** live row (`Reading`, the tallest variant with the Complete/Skip action row) at simulated 8:25 AM: no chip renders over the title, the title is fully legible, and the rule still visibly crosses the card
- Verified in the same session that the chip still renders normally in a non-live (`PreStart`, simulated 7:30 AM) state, in the gutter, clear of any card
- Appended a dated (2026-08-11) amendment to `26-UI-SPEC.md`'s existing "The now-line (CAL-02)" amendment section, recording the fix, the rejected alternatives, and the process failure that let G-03 ship as closed in 26-07 — append-only, original spec text untouched
- Left the debug build served at `http://danserver:8133/` (fresh port — 8131 and 8132 already serving earlier builds of this phase)

## Task Commits

Each task was committed atomically:

1. **Task 1: Suppress the chip inside the live row's span** - `708d5de` (fix)
2. **Task 2: The regression test 26-07 should have written** - `ebb3ce0` (test)
3. **Task 3: Verify in a real browser against a WORK live row, then amend the spec** - `ec6a0ff` (docs)

_No plan-metadata commit yet — see below; STATE.md/ROADMAP.md updates follow this SUMMARY and are committed together._

## The RED/GREEN proof (the plan's most important acceptance criterion)

Per the plan's explicit instruction, the new `G-03` test was not accepted on the strength of
"I believe it would fail." It was proven:

**RED (pre-fix):** Temporarily replaced the call site's computed `showChip: ...` expression with a
hardcoded `showChip: true` (i.e., reverted Task 1's behavior while keeping the parameter itself, so
only the *value passed* regressed — the parameter's existence isn't what's under test). Ran
`flutter test test/screens/today_screen_test.dart --plain-name "G-03"`:

```
Expected: no matching candidates
  Actual: _DescendantWidgetFinder:<Found 1 widget with type "Text" descending from widget with type
"NowLineOverlay": [ Text("9:12", ... ) ]>
   Which: means one was found but none were expected
...
00:00 +0 -1: Some tests failed.
```

The test failed exactly as expected — the chip rendered over the live row, matching the reported
defect.

**GREEN (post-fix):** Restored the call site to the committed Task 1 code (`showChip:
!(geometry.liveStartMinutes != null && ...)`). Re-ran the same command:

```
00:00 +1: All tests passed!
```

Both observations are genuine — the file was diffed against the committed version after restoring
to confirm it matched exactly, and the full suite (`flutter test`) was run afterward to confirm no
other regression.

## Real-browser verification (Task 3)

Server: `http://danserver:8133/` (debug build, `flutter build web --debug --source-maps
--pwa-strategy=none`, served via `tools/serve-uat.py`, `no-store` headers, fresh port per CLAUDE.md
trap #1 — 8131 and 8132 already served earlier builds of this phase).

Technique: headless Chromium (`--use-gl=swiftshader --enable-unsafe-swiftshader`), 430×930
viewport, onboarded once into a persistent profile, then simulated time set precisely via
`localStorage.setItem('flutter.dev_clock_offset_micros', ...)` + reload — the exact technique
26-08-SUMMARY.md documented, reused unchanged.

Generated schedule for the profile used: `Reading` (deep-work tier — has Complete/Skip) 8:15–8:40
AM, then a short break 8:40–8:45 AM, then `Side project` 8:45–9:10 AM, etc.

1. **WORK live row, simulated 8:25 AM (10 min into the 25-min `Reading` chunk):** confirmed no
   chip renders over `LiveRowCard`'s title — the title `Reading` and the surrounding copy
   (`RIGHT NOW · 8:15 AM`, `15 min left · until 8:40 AM`, `Complete`/`Skip`) are all fully
   legible. The 2dp rule is visible crossing the card, directly above the title, exactly as
   intended — it still marks the truthful mid-chunk position; only the chip is gone.
   Evidence: `evidence-26-09/g03-work-live-full.png` (full page),
   `evidence-26-09/g03-work-title-after.png` (cropped title region).
2. **Before/after comparison:** `evidence-26-08/g02-work-full-after.png` (reused per the plan's
   suggestion — it incidentally captured the G-03 defect while measuring G-02) shows the `8:10`
   chip pill sitting directly on top of the `Exercise` title at that time. Cropped side-by-side:
   `evidence-26-09/g03-work-title-before.png` vs. `evidence-26-09/g03-work-title-after.png`.
3. **Non-live state, simulated 7:30 AM (`PreStart`, before the 8:15 AM first chunk):** confirmed
   the chip still renders normally — a `7:30` pill in the gutter, clear of the `Free until 8:15
   AM` copy and every card. Evidence: `evidence-26-09/g03-non-live-chip-renders.png` (full page),
   `evidence-26-09/g03-non-live-chip-crop.png` (cropped).
4. No JS console exceptions observed in either session (`page.on('pageerror', ...)` logged
   nothing in either run).

## Files Created/Modified

- `lib/screens/today/widgets/now_line.dart` - added `showChip` bool param (default `true`); the
  chip's `Align` is now wrapped in `if (showChip)`; the rule is unaffected; doc comment records the
  G-03 rationale so the parameter isn't "simplified away" later
- `lib/screens/today/today_screen.dart` - the `NowLineOverlay` call site now passes `showChip:
  !(geometry.liveStartMinutes != null && geometry.liveEndMinutes != null && nowMinutes >=
  geometry.liveStartMinutes! && nowMinutes < geometry.liveEndMinutes!)`, reading the live span off
  `TimelineGeometry` per the plan's explicit instruction (never `resolveNowState` or the chunk list)
- `test/screens/today_screen_test.dart` - added `G-03: no time chip over the live row — the
  full-bleed card leaves no gutter` (names `LiveRowCard` directly, asserts the chip is absent and
  the rule survives); moved the `chip copy` test and the `G-01` gutter test off the now-live 9:12
  clock onto a 9:30 `GapBeforeNext` fixture (`twoChunkFixture(firstResolved: true)`) so both keep
  exercising a genuinely non-live moment
- `.planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md` - appended a dated (2026-08-11) amendment
  to the existing "The now-line (CAL-02)" section recording the G-03 fix, Dan's decision and the
  rejected alternatives, and the process failure narrative from `26-UAT.md`; also annotated the
  "Suppression" table row (strikethrough + addition, not a rewrite) to record the chip's new scoped
  suppression separately from the rule's continued unconditional rendering
- `.planning/phases/26-the-day-has-a-shape/evidence-26-09/` - 5 screenshots: full-page work-live,
  full-page non-live (`PreStart`), and cropped before/after title-region comparisons

## Decisions Made

- **Chip-only suppression, not overlay suppression.** Dan's explicit choice (2026-08-11):
  `LiveRowCard` already states the current time in larger type (`RIGHT NOW · <time>`), so the chip
  is redundant inside the live row, not lost — and the rule alone still marks the exact position.
  Rejected alternatives: indenting the live row to match ordinary cards (reverses the deliberate
  full-bleed "let now break the grid" decision from Phase 22/23), and inset-the-text-only (asymmetric
  internal padding on one card type).
- **Geometry, not a second now-detector.** `showChip` is computed from `TimelineGeometry`'s own
  `liveStartMinutes`/`liveEndMinutes`, matching the exact half-open convention already used for
  `liveExtraPx`. This was an explicit plan instruction, not a discretionary choice — recomputing the
  live span from `resolveNowState` or the chunk list would reintroduce the "two sources of truth for
  where is the live row" regression class this phase has guarded against since plan 22-03.
- **Test fixture change over special-casing assertions.** Rather than teaching the existing `chip
  copy` and `G-01` tests to tolerate a suppressed chip at 9:12, both were moved to a genuinely
  non-live clock (9:30, `GapBeforeNext`). Each test now proves exactly one claim again: "the chip's
  copy is correct when it renders" and "the chip stays in the gutter when it renders," with the new
  `G-03` test owning the separate claim "the chip does not render at all over the live row."

## Deviations from Plan

None — plan executed as written. All three tasks completed exactly as scoped; no Rule 1–4 auto-fixes
were required (`flutter analyze` and the full `flutter test` run were both clean on the first attempt
after the two existing-test updates described above, which were themselves an explicit plan
instruction — task 2, action item 3 — not an unplanned fix).

## Issues Encountered

The two pre-existing tests (`chip copy`, `G-01: the now chip stays inside the time gutter...`) both
used the fixture's 9:12 clock, which — after Task 1's fix — is now a moment inside `w1`'s live span,
so the chip they were asserting against stopped rendering. This was expected and explicitly scoped
by the plan (task 2, action item 3: "strengthen the existing G-01 test... for the non-live case the
chip must clear ChunkCard"), not a surprise; both were moved to a 9:30/`GapBeforeNext` fixture as
described above.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None.

## Threat Flags

None — this plan only changes conditional rendering of a non-interactive, `IgnorePointer`-wrapped
overlay label showing a clock value already on screen. No network, auth, persistence, input
parsing, or new dependency, matching the plan's own threat model assessment.

## Server for Dan to look at

Debug build served at **`http://danserver:8133/`** (fresh port per CLAUDE.md trap #1). Server process
left running (`python3 tools/serve-uat.py 8133 --dir build/web`, background, `no-store` headers via
`tools/serve-uat.py`). To see the fix: open a fresh onboarding flow, generate a day, then use
Settings → Debug → Time travel to land inside a live WORK chunk (one with Complete/Skip buttons,
not a short break) and confirm the title is unobstructed.

## Next Phase Readiness

`26-UAT.md`'s G-03 is now closed with the exact assertion class (`LiveRowCard`-naming) that was
missing before, and with a documented RED/GREEN proof rather than an assumption. No known gaps
remain open in `26-UAT.md` after this plan. `resolveNowState` remains the single now-detector (one
definition, one call site — reverified). Zero raw `Colors.*` in `lib/screens/today/`. `flutter test`
green at 558 (above the 557 baseline), `flutter analyze` clean.

---
*Phase: 26-the-day-has-a-shape*
*Completed: 2026-08-11*

## Self-Check: PASSED

All files referenced above (source, test, spec, 5 evidence images, this SUMMARY) were verified
present on disk with `[ -f ... ]`, and all three task commit hashes (`708d5de`, `ebb3ce0`,
`ec6a0ff`) were verified present in `git log --oneline --all` after writing this SUMMARY.
