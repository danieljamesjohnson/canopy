---
phase: 29-breaks-you-can-see
plan: 01
subsystem: ui
tags: [flutter, widget-tests, chunk-card, timeline-geometry, density-tier, tdd-red]

# Dependency graph
requires:
  - phase: 27-true-grid
    provides: "ChunkCardDensity's full/compact tiers and the kFullTierMinHeight/kFullBreakMinHeight/kCompactLiveMinHeight threshold-constant house style this plan extends"
  - phase: 28-the-day-is-a-lattice
    provides: "the engine lattice that emits the two break durations (5min, 30min) this plan's tests are ground-truthed against"
provides:
  - "ChunkCardDensity.subCompact enum value (inert, unreachable from any call site)"
  - "kSubCompactBreakMinHeight = 24.0, an explicitly UNMEASURED PLACEHOLDER constant"
  - "_SubCompactRow, the shared hairline-with-label widget both the break tier (29-02) and the work-chunk dead-path fallback will render"
  - "Eight new tests (5 proven RED, 3 GUARD green) pinning the sub-compact tier's exact behaviour before any wiring exists"
  - "29-RED-subcompact.txt — committed raw evidence that the 5 behavioural tests fail against the unwired code for the right reason"
affects: [29-02 (wires _buildBreak's branch and today_screen.dart's ternary — turns this plan's RED tests GREEN by touching lib/ only), 29-03 (measures and replaces kSubCompactBreakMinHeight), 29-04 (real-browser pixel proof + human UAT checkpoint)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Wave-1-tests-wave-2-wiring split (Phase 28 precedent) applied to a UI change: an inert scaffold lands first so density-typed tests can compile, then all behavioural tests are written and proven RED against that inert scaffold, then wave 2 (29-02) touches only lib/ to turn them GREEN"
    - "Relative height comparison instead of an absolute flutter-test height assertion (PD-29-06) — sub-compact vs compact measured in the same placeholder-font harness so the harness bias cancels, avoiding an assertion that would pass in flutter test while clipping on a real device"
    - "Ground-truth-literal test discipline (this repo's GRID-01 precedent) extended to SEEBREAK-02: heightFor(540, 5) == 20.0 and heightFor(600, 30) == 120.0 as bare double literals, never re-deriving kPixelsPerMinute"

key-files:
  created:
    - .planning/phases/29-breaks-you-can-see/29-RED-subcompact.txt
  modified:
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/today/timeline_geometry.dart
    - test/screens/today_row_widgets_test.dart
    - test/screens/today_screen_test.dart
    - test/screens/today_timeline_model_test.dart

key-decisions:
  - "Corrected the plan's cited three-strikes history for kCompactLiveMinHeight from '60→84→88' (unverifiable — no '60' value exists anywhere in git history) to the actual, git-verified sequence '88.0 (its own UNMEASURED PLACEHOLDER) → 84.0 (first real-browser measurement) → 88.0 (re-measured after a touch-target UAT finding)' in kSubCompactBreakMinHeight's new doc comment, rather than propagate an apparently-erroneous citation"
  - "_SubCompactRow's two Dividers are written as two separate inline widget literals, not factored into one shared `divider` variable referenced twice — needed so the plan's own acceptance-criteria grep (height: 1 / thickness: 1 must appear at least twice each in executable code) is satisfiable, and it also matches 29-UI-SPEC.md's widget tree exactly rather than a 'simplified' refactor"
  - "Renamed the local test-fixture closure from _breakBoundaryFixture to breakBoundaryFixture — flutter analyze's no_leading_underscores_for_local_identifiers lint flagged the underscore-prefixed local function; local identifiers carry no privacy semantics in Dart so the prefix was purely cosmetic and wrong per this repo's clean-analyze bar"

patterns-established:
  - "Documented, unreachable defensive fallback: an enum arm and switch case exist purely to satisfy Dart's compile-time exhaustiveness check, are labelled as such in a code comment naming the plan that could someday make them reachable, and carry no bespoke measured constant of their own (per 29-UI-SPEC.md 'Scope boundary')"

requirements-completed: [SEEBREAK-01, SEEBREAK-02]

# Metrics
duration: ~20min
completed: 2026-08-20
---

# Phase 29 Plan 01: Every test that defines "a break you can see" Summary

**Landed an inert `ChunkCardDensity.subCompact` scaffold (enum value, `kSubCompactBreakMinHeight` UNMEASURED PLACEHOLDER, shared `_SubCompactRow` widget, both `_WorkChunkContent` switch arms) that changes no rendered output, then wrote eight new tests and proved five of them RED against that unwired scaffold with raw `flutter test` output committed as evidence.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-08-20
- **Tasks:** 3/3
- **Files modified:** 5 (2 lib/, 3 test/), 1 file created (RED evidence)

## Accomplishments

- Added `ChunkCardDensity.subCompact` to `chunk_card.dart`, doc-commented in the existing house style, citing `29-UI-SPEC.md`, its trigger (`slot < kSubCompactBreakMinHeight`), its break-only scope, and naming plan `29-02` as the one that wires it.
- Added `kSubCompactBreakMinHeight = 24.0` to `timeline_geometry.dart`, headed **UNMEASURED PLACEHOLDER**, positioned between `kFullBreakMinHeight` and `kCompactLiveMinHeight` per the file's "one file owns every Today-timeline density threshold" convention.
- Added the file-private `_SubCompactRow` widget (two hairline `Divider(height: 1, thickness: 1)`s flanking a centered, ellipsized `bodySmall` label, `Semantics(excludeSemantics: true)` restating the duration, zero margin/padding on all four sides) — wired into `_WorkChunkContent`'s two density switches as a documented, unreachable defensive fallback, but **not** into `_buildBreak`'s branch chain (that stays 29-02's job per PD-29-01).
- Proved the wave-1 scaffold is inert: after Task 1, the full suite is still **579 green** and `flutter analyze` reports **no issues**; `git diff --stat lib/screens/today/today_screen.dart` is empty for the whole plan.
- Added five ChunkCard-level tests (Task 2) plus a `_pumpBreakCardUnbounded` harness helper that mirrors `today_screen.dart`'s production `ClipRect`/`OverflowBox` wrapper (unlike `pumpWithMood` alone, which hands the card a bounded `Scaffold` height and makes any cross-density height comparison meaningless).
- Added the screen-level tier-boundary test and two SEEBREAK-02 ground-truth GUARDs (Task 3), all boundary values derived from `kSubCompactBreakMinHeight`/`kPixelsPerMinute` so they survive 29-03's measurement instead of being invalidated by it.
- Captured `.planning/phases/29-breaks-you-can-see/29-RED-subcompact.txt`: all three test files run together with `--concurrency=1 --reporter expanded` — **exactly 5** `[E]`-marked failures (Tests 1, 2, 3, 5, 6), **0** on any of the 3 GUARDs (Tests 4, 7, 8). Every failure is a behavioural assertion mismatch (`Expected: .../Actual: ...`), never a compile error or missing symbol.

## Task Commits

Each task was committed atomically:

1. **Task 1: Land the inert subCompact scaffold** - `6c2db38` (feat)
2. **Task 2: The ChunkCard-level tests** - `fe4f409` (test)
3. **Task 3: The screen-level tier-boundary test, SEEBREAK-02 ground truth, RED evidence** - `1176929` (test)

_This is a `type: execute` plan with `tdd`-flavored gates at the task level (RED proven in Tasks 2-3 against Task 1's inert scaffold), not a `type: tdd` plan — no separate feat/test/refactor cycle per task was required by the plan's own frontmatter._

## Files Created/Modified

- `lib/screens/schedule/widgets/chunk_card.dart` — `ChunkCardDensity.subCompact`, `_SubCompactRow`, both `_WorkChunkContent` switch arms, and documentation-only comments on the two unprotected `if`-based density sites (see "Two unprotected if-based density sites" below)
- `lib/screens/today/timeline_geometry.dart` — `kSubCompactBreakMinHeight` UNMEASURED PLACEHOLDER constant
- `test/screens/today_row_widgets_test.dart` — `_pumpBreakCardUnbounded` helper + 5 new `testWidgets` (Tests 1-5)
- `test/screens/today_screen_test.dart` — `group('Phase 29 — SEEBREAK: breaks you can see')` with the tier-boundary test (Test 6) and the SEEBREAK-02 rendered-slot GUARD (Test 7)
- `test/screens/today_timeline_model_test.dart` — the SEEBREAK-02 ground-truth GUARD (Test 8)
- `.planning/phases/29-breaks-you-can-see/29-RED-subcompact.txt` — created (RED evidence, all 3 test files, `--concurrency=1 --reporter expanded`)

## Decisions Made

- **Two unprotected `if`-based density sites, and whether `subCompact` can reach each** (recorded for 29-02, per the plan's `<output>` spec):
  1. `_buildBreak`'s `if (density == ChunkCardDensity.compact)` (~line 153, `chunk_card.dart`) — **reachable**: `_buildBreak` runs for every break density including `subCompact`, but no branch here checks for it yet, so a break card built at `subCompact` today falls through to the detailed/full treatment (the same code path `full` uses — this is exactly what Test 3's measured `52.0` height for the unwired `subCompact` case comes from, and what SEED-005's own "52dp natural height" figure independently corroborates). Plan 29-02 adds the missing branch, checked before `compact`.
  2. `final isFull = density == ChunkCardDensity.full;` inside `_buildContentShell` (~line 655, `chunk_card.dart`) — **not reachable**: `_WorkChunkContent`'s content-builder switch (this plan's Task 1) routes `ChunkCardDensity.subCompact` to `_SubCompactRow` instead of `_buildContentShell`, so this line is never reached at that density. No change needed here in 29-02.
- Corrected an apparent citation error in the plan text (see `key-decisions` in frontmatter) — the plan asked for a "60→84→88" three-strikes history for `kCompactLiveMinHeight`; git history (`aed0949`, `1ca4204`, `419aa7b`) shows no `60.0` value ever existed for that constant. Used the verified sequence instead.
- Kept the `_SubCompactRow` widget's two `Divider`s as separate inline literals (not a shared variable) so the plan's own acceptance-criteria grep for `height: 1`/`thickness: 1` (expected ≥2 each in executable code) is satisfiable, and so the code matches `29-UI-SPEC.md`'s widget tree verbatim.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a missing closing brace when moving the SwipeableChunkCard forwarding test out of the nested `break densities` group**
- **Found during:** Task 2, first `flutter test` run against the edited file
- **Issue:** Moving Test 5 to "immediately after the existing forwarding test, at the same nesting level" (per the plan's own instruction) accidentally dropped the outer `group('ChunkCardDensity ...')`'s closing `});`, producing three cascading parser errors ("Can't find ')' to match '('", "Can't find '}' to match '{'", "Expected ';' after this") — a compile error, which the plan is explicit is NOT valid RED.
- **Fix:** Restored the missing `});` before `group('LiveRowCard — two density tiers (GRID-02)', ...)`.
- **Files modified:** `test/screens/today_row_widgets_test.dart`
- **Verification:** `flutter test test/screens/today_row_widgets_test.dart` compiled and ran; the RED failures that followed were then genuinely behavioural (see `29-RED-subcompact.txt`).
- **Committed in:** `fe4f409` (part of Task 2 commit — fixed before commit, not a separate commit)

**2. [Rule 1 - Bug] Fixed a `no_leading_underscores_for_local_identifiers` analyzer warning**
- **Found during:** Task 3, `flutter analyze` after adding the `Phase 29 — SEEBREAK` test group
- **Issue:** The local fixture-building closure was named `_breakBoundaryFixture`; Dart local identifiers carry no privacy semantics, so the leading underscore is flagged by this repo's lint set and would have broken the plan's "flutter analyze clean" bar.
- **Fix:** Renamed to `breakBoundaryFixture` (no functional change).
- **Files modified:** `test/screens/today_screen_test.dart`
- **Verification:** `flutter analyze` — No issues found.
- **Committed in:** `1176929` (part of Task 3 commit — fixed before commit, not a separate commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1, both fixed before their task's commit so no separate commit exists for either).
**Impact on plan:** Both were mechanical corrections required to meet the plan's own stated gates (valid RED, clean analyze). No scope creep — nothing in `lib/` beyond what Task 1 specified was touched, and no test assertion was weakened.

## Plan-Authoring Inconsistency (documented, not "fixed")

The plan's acceptance criterion `grep -A6 "switch (density)" lib/screens/schedule/widgets/chunk_card.dart | grep -c "subCompact"` (expected `2`) actually returns `0` on the finished file. This is a property of the plan's own verification command, not a defect in the code: the `contentPadding` switch's `subCompact` arm is placed after the `detailed` arm (matching the enum's declaration order, matching every other arm's position), which puts it roughly 18 lines below the `switch (density) {` line — past `grep -A6`'s 6-line window. Verified correctness directly instead:

```
awk '/final contentPadding = switch \(density\) \{/,/^    \};/' chunk_card.dart | grep -c "ChunkCardDensity.subCompact"  # => 1
awk '/child: switch \(density\) \{/,/^                    \},/' chunk_card.dart | grep -c "ChunkCardDensity.subCompact"  # => 1
```

Both switches carry exactly one `subCompact` arm each, and `grep -c "switch (density)"` (no `-A`) returns exactly `2` as the plan's other criterion requires. Precedent for documenting rather than distorting code to satisfy an imprecise plan-authored grep: `28-02-SUMMARY.md`'s "Task 2's render test uses `testWidgets()`... structurally unsatisfiable while remaining correct."

## Issues Encountered

None beyond the two auto-fixed items above.

## Test Evidence (quoted, one failure per RED-PROOF test)

All five, verbatim from `29-RED-subcompact.txt`:

1. **`sub-compact short break renders two Dividers and the label, no dashed border, no duration text`**
   `Expected: no matching candidates / Actual: _TextWidgetFinder:<Found 1 widget with text "5 min": [...]>` — the unwired `subCompact` density still falls through to the detailed/full treatment, which renders the duration text this tier must drop.

2. **`sub-compact short break restates the duration in its semantics label`**
   `Expected: exactly one matching candidate / Actual: _ElementPredicateWidgetFinder:<Found 0 widgets with a semantics label named "Short break, 5 min": []>` — no `Semantics(label: ...)` restating the duration exists yet at this density.

3. **`sub-compact renders shorter than compact for the same break`**
   `Expected: a value less than <24.0> / Actual: <52.0>` (harness bounds: compact=24.0, subCompact=52.0) — the unwired `subCompact` card is currently *taller* than `compact`, not shorter, because it falls through to the full/detailed treatment. `52.0` independently corroborates SEED-005's own "~52dp natural height" figure for the unfixed compact-tier defect.

4. **`SwipeableChunkCard forwards subCompact on the break early-return path`**
   `Expected: no matching candidates / Actual: _TextWidgetFinder:<Found 1 widget with text "5 min": [...]>` — same underlying cause as #1, observed through the `SwipeableChunkCard` forwarding wrapper.

5. **`SEEBREAK-01 tier boundary: a break slot below kSubCompactBreakMinHeight renders sub-compact; at the threshold it renders compact`**
   `Expected: exactly 2 matching candidates / Actual: _TypeWidgetFinder:<Found 0 widgets with type "Divider": []>` — `today_screen.dart`'s density-selection ternary is still the old 2-way `full`/`compact` split (untouched, per PD-29-01), so no `Divider` renders anywhere in the pumped screen yet.

**Two GUARD results, confirming the finders are not vacuous:**

- `SEEBREAK-01 non-vacuity: compact short break still renders the dashed painter and no Divider` — green, unchanged.
- `SEEBREAK-02: a 5-minute break occupies exactly 20.0dp of slot at sub-compact density` — green (rendered-slot height is purely geometry-derived, unaffected by which density tier's content is drawn inside it).
- `SEEBREAK-02: heightFor returns the ground-truth pixel height for every break duration the lattice emits` — green (pure arithmetic, `heightFor(540,5)==20.0`, `heightFor(600,30)==120.0`).

## RESEARCH Assumption A2 (swipeable_chunk_card.dart, full-file grep)

```
grep -n "ChunkCardDensity\|density" lib/screens/schedule/widgets/swipeable_chunk_card.dart
27:    this.density = ChunkCardDensity.detailed,
61:  /// break must not render at [ChunkCardDensity.detailed] inside a tiny
63:  final ChunkCardDensity density;
80:        density: density,
132:        density: density,
```

**Confirmed: no.** Neither forwarding site (line 80, the break early-return; line 132, the `Dismissible` child) branches on a specific `ChunkCardDensity` value — both simply forward the `density:` parameter through unmodified. No source change needed in this file for `subCompact` to reach a break card via `SwipeableChunkCard`; Test 5's failure is entirely `ChunkCard`-side (confirmed by the identical failure signature to Test 1).

## Verification Summary

- `flutter analyze` — No issues found (checked after every task).
- After Task 1 only: `flutter test --concurrency=1` — **579 passed**, 0 failed (byte-identical to pre-plan baseline).
- After Task 3 (full repo): `flutter test --concurrency=1` — **582 passed, 5 failed** (587 total = 579 baseline + 8 new tests; the 5 failures are exactly the 5 RED-PROOF tests named above — this is the plan's own explicitly intended intermediate state).
- `git diff --stat lib/` — empty for Tasks 2 and 3 (verified individually before each commit).
- `git diff --stat lib/screens/today/today_screen.dart` — empty for the whole plan.
- `git diff --exit-code pubspec.yaml pubspec.lock` — empty (exit 0), no package installed (T-29-01 satisfied).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Wave 2 (plan `29-02`) can now touch `lib/` only: add `_buildBreak`'s `subCompact` branch (checked before `compact`) and `today_screen.dart`'s three-band break density ternary. Doing so should flip exactly the 5 named RED-PROOF tests to GREEN without touching any test file — git will prove that directly (`git diff --stat test/` empty for 29-02), closing the RED→GREEN causal chain this plan exists to set up. The two GUARD-only findings above (which `if`-site is reachable, which isn't) are handed off so 29-02 doesn't have to rediscover them. `kSubCompactBreakMinHeight`'s UNMEASURED PLACEHOLDER (`24.0`) is intentionally left for plan `29-03` to replace via real-browser measurement — do not treat it as final in the meantime.

---
*Phase: 29-breaks-you-can-see*
*Completed: 2026-08-20*

## Self-Check: PASSED

- FOUND: `.planning/phases/29-breaks-you-can-see/29-01-SUMMARY.md`
- FOUND: `.planning/phases/29-breaks-you-can-see/29-RED-subcompact.txt`
- FOUND commit: `6c2db38` (Task 1)
- FOUND commit: `fe4f409` (Task 2)
- FOUND commit: `1176929` (Task 3)
