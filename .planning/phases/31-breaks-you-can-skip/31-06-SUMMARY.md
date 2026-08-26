---
phase: 31-breaks-you-can-skip
plan: 06
subsystem: ui
tags: [flutter, widget-test, dismissible, hit-testing, accessibility, gap-closure]

# Dependency graph
requires:
  - phase: 31-01
    provides: kBreakHitSlop/kMinBreakDragTarget, the Layer 1a/1b Stack split, _needsSlop, and the top-slop-band tracer test this plan's doc comment re-derives against
  - phase: 31-03
    provides: the non-vacuity RED protocol (delete the fix from the production file, run, capture the named failure verbatim, restore byte-identical) this plan reuses exactly for both RED captures
  - phase: 31-05
    provides: the human UAT verdict (Item 1 FAIL, "hard to do this with a thumb") this plan is the gap-closure response to
provides:
  - "kBreakHitSlop raised 16.0 -> 24.0 with a doc comment that derives the 68dp band, the neighbour's retained target at 16/24/26/32, and re-checks (not restates) PD-31-01's clamp-never-binds claim against schedule_generator.dart"
  - "A visible grip glyph (Icons.drag_indicator, kSubCompactGripSize=14.0) inside _SubCompactRow, present only while the break is still swipeable, at exactly zero painted-height cost"
  - "Two non-vacuity RED captures on disk (31-RED-slop24.txt, 31-RED-grip.txt), each naming its specific failure"
  - "A documented correction in today_screen_test.dart's SKIPBREAK-02 group stating what it does and does not prove after this plan"
affects: [31-07 (round-two human UAT — judges whether a real thumb can now grab the row), 31-08 (if planned — any further gap-closure work reads this plan's re-derived ceiling before touching kBreakHitSlop again)]

# Actuals (#2632)
actuals:
  tokens: 7600
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Re-derive-in-place doc comments for load-bearing constants: when a constant with a numerically-justified doc comment changes value, the comment must recompute every downstream number at the new value (band size, neighbour retention, ceiling) rather than restate the old prose with the number swapped — carried forward from this file's own kPixelsPerMinute/kSubCompactBreakMinHeight precedent."
    - "Literal-coordinate drag tests for band-size regressions: a drag origin computed symbolically from the constant under test (e.g. `paintedRect.top - kBreakHitSlop`) moves with that constant and can never distinguish an old value from a new one — the discriminating test must use a bare numeric literal chosen to fall inside the new band and outside the old one."
    - "Natural-height (unclipped, OverflowBox) measurement as the only harness that can prove a zero-extent claim about a widget rendered inside a SwipeableChunkCard-style confined ClipRect — the confined measurement is `visualHeight`-tall by construction regardless of its child, so it is structurally blind to exactly the regression class (an inflated child) this plan's grip glyph could have introduced."

key-files:
  modified:
    - lib/screens/today/timeline_geometry.dart
    - lib/screens/schedule/widgets/chunk_card.dart
    - test/screens/today_screen_test.dart
    - test/screens/today_row_widgets_test.dart
  created:
    - .planning/phases/31-breaks-you-can-skip/31-RED-slop24.txt
    - .planning/phases/31-breaks-you-can-skip/31-RED-grip.txt

key-decisions:
  - "Both halves of D-31-06 shipped together, in the same plan, as the owner's LOCKED ruling required — shipping only the slop increase would not have satisfied D-31-06."
  - "The grip glyph is Icons.drag_indicator (six-dot, direction-neutral), not a chevron or arrow — a directional icon would have asserted a swipe direction the owner never ruled on."
  - "No Semantics/semanticLabel added to the glyph itself — _SubCompactRow already wraps the whole row in Semantics(excludeSemantics: true) with the D-31-04 label; a labelled icon inside would either be swallowed or perturb an announcement the owner already passed (31-UAT.md Item 2)."
  - "dismissThresholds left untouched everywhere in lib/ — confirmed by grep before and after, per D-31-06's explicit instruction not to touch it on this evidence."
  - "The SKIPBREAK-02 'grid is unchanged' screen-level group was given a comment, not a new assertion, clarifying it cannot prove the grip's zero-extent claim — that proof lives in today_row_widgets_test.dart's widget-level, unclipped measurement instead."

requirements-completed: [SKIPBREAK-01, SKIPBREAK-02]

coverage:
  - id: D1
    description: "kBreakHitSlop raised to 24.0; a drag started 22dp above a 5-minute break's painted top edge (outside the old 16dp band, inside the new 24dp band) resolves to that break, not the preceding work chunk — proven both green (at 24.0) and RED (reverted to 16.0, failing with w1 named)."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_test.dart#Phase 31 — SKIPBREAK: breaks you can skip#D-31-06 — a bigger, findable acquisition band#D-31-06 Case A"
        status: pass
      - kind: other
        ref: ".planning/phases/31-breaks-you-can-skip/31-RED-slop24.txt (non-vacuity capture, Expected: b1 / Actual: w1)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A 25-minute work chunk with a break on both sides retains at least kMinBreakDragTarget (48dp) of its own band at the shipped 24.0 slop value — a pure-constant ceiling guard that fails loudly if the slop is ever raised past ~26dp."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: unit
        ref: "test/screens/today_screen_test.dart#Phase 31 — SKIPBREAK: breaks you can skip#D-31-06 — a bigger, findable acquisition band#D-31-06 Case B"
        status: pass
    human_judgment: false
  - id: D3
    description: "kBreakHitSlop's doc comment derives the 68dp band, the neighbour's retained target at 16/24/26/32, and re-checks PD-31-01's clamp-never-binds claim against schedule_generator.dart (binding threshold: a work chunk under 12 minutes; the generator never emits one under 25)."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: other
        ref: "lib/screens/today/timeline_geometry.dart kBreakHitSlop doc comment (read verification, quoted in this SUMMARY below)"
        status: pass
    human_judgment: false
  - id: D4
    description: "A visible grip glyph (kSubCompactGripSize=14.0, Icons.drag_indicator) renders inside an unresolved sub-compact break's row, leading the label, and is absent on a skipped one."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#... break densities#D-31-06 — the sub-compact grip glyph#Case A"
        status: pass
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#... break densities#D-31-06 — the sub-compact grip glyph#Case B"
        status: pass
    human_judgment: false
  - id: D5
    description: "The grip glyph changes the sub-compact row's natural, unclipped height by exactly zero pixels — the load-bearing SKIPBREAK-02 proof, measured outside any ClipRect, proven both green (pinned at 14.0) and RED (forced to the unpinned 24.0 default, two named unequal heights captured)."
    requirement: "SKIPBREAK-02"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#... break densities#D-31-06 — the sub-compact grip glyph#Case C"
        status: pass
      - kind: other
        ref: ".planning/phases/31-breaks-you-can-skip/31-RED-grip.txt (non-vacuity capture, Expected: <16.0> / Actual: <24.0>)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Whether a real thumb can now reliably grab the row — the actual claim the owner's UAT failed on. This is a physical-device question no widget test can settle."
    verification: []
    human_judgment: true
    rationale: "flutter test fires synthetic drags at exact coordinates and cannot model a fingertip's contact patch or the visual findability of a glyph — this is precisely the class of claim Phase 31's own precedent (31-UAT.md Item 1) already proved automation insufficient for. Requires a round-two human UAT on a real device, not part of this plan's scope."

# Metrics
duration: ~45min
completed: 2026-08-26
status: complete
---

# Phase 31 Plan 06: A Bigger, Findable Acquisition Band Summary

**Raised `kBreakHitSlop` 16.0 → 24.0 (68dp band) with re-derived doc-comment arithmetic, and added a pinned, zero-painted-cost `Icons.drag_indicator` grip glyph inside `_SubCompactRow` — both halves of D-31-06, each proven with an executed non-vacuity RED capture.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-08-26 (worktree wave 1, gap-closure replan)
- **Completed:** 2026-08-26
- **Tasks:** 3
- **Files modified:** 4 (2 production, 2 test), 2 new RED-capture artifacts

## Accomplishments

- `kBreakHitSlop` raised from `16.0` to `24.0` in `lib/screens/today/timeline_geometry.dart`. `today_screen.dart` and `swipeable_chunk_card.dart` needed zero edits — confirmed by reading `_needsSlop` (it gates on `kMinBreakDragTarget`, never reads `kBreakHitSlop` directly) and by `git diff --name-only` after the commit not listing either file.
- The constant's doc comment was rewritten to derive the arithmetic **in place at 24.0**, not restate the old prose with a new number: the break's own 68dp band (20dp painted + 24 above + 24 below), the neighbouring 25-minute work chunk's retained band at 16/24/26/32dp (68/52/48/36), and a re-checked (not assumed) verdict on PD-31-01's "clamp can never bind" claim.
- A new nested test group `D-31-06 — a bigger, findable acquisition band` in `test/screens/today_screen_test.dart`: a literal-coordinate (bare `22`, never `kBreakHitSlop`-derived) drag proving the new band discriminates from the old one, and a pure-constant ceiling guard on the neighbour's retained target.
- A visible grip glyph — `Icons.drag_indicator`, sized and boxed to a new `kSubCompactGripSize = 14.0` — added inside `_SubCompactRow`'s `Row`, between the leading `Divider` and the label, rendered only while the row is unresolved.
- A new nested test group `D-31-06 — the sub-compact grip glyph` in `test/screens/today_row_widgets_test.dart`: presence when unresolved, absence when skipped, and the load-bearing zero-extent proof measured on the natural, unclipped `ChunkCard` height.
- Two executed non-vacuity RED captures on disk (`31-RED-slop24.txt`, `31-RED-grip.txt`), each showing the exact named failure the corresponding fix protects against, with both production files confirmed restored byte-identical before their respective commits.
- A dated, comment-only correction added to `today_screen_test.dart`'s pre-existing `SKIPBREAK-02 — the grid is unchanged` group, stating plainly that it measures a confined `ClipRect` that is `visualHeight`-tall by construction and is therefore structurally incapable of proving the grip glyph's zero-extent claim — pointing a future reader at the actual proof instead.

## Task Commits

Each task was committed atomically:

1. **Task 1: Raise kBreakHitSlop to 24.0, re-derive its arithmetic, and pin the 68dp band** - `380dff9` (feat)
2. **Task 2: Add the visible grip glyph to _SubCompactRow at exactly zero painted cost** - `04368da` (feat)
3. **Task 3: Full-suite regression, RED artefact audit, and the honest coverage note** - `67e1669` (docs)

_No separate plan-metadata commit — this plan runs inside a git worktree; the orchestrator commits this SUMMARY.md and STATE.md/ROADMAP.md centrally after the wave merges._

## Files Created/Modified

- `lib/screens/today/timeline_geometry.dart` — `kBreakHitSlop` 16.0 → 24.0, doc comment fully re-derived
- `lib/screens/schedule/widgets/chunk_card.dart` — new `kSubCompactGripSize` constant and the grip glyph inside `_SubCompactRow`
- `test/screens/today_screen_test.dart` — new `D-31-06 — a bigger, findable acquisition band` group (2 cases); dated correction comment on the `SKIPBREAK-02 — the grid is unchanged` group
- `test/screens/today_row_widgets_test.dart` — new `D-31-06 — the sub-compact grip glyph` group (3 cases); `_pumpBreakCardUnbounded` gained an optional `skipped` parameter
- `.planning/phases/31-breaks-you-can-skip/31-RED-slop24.txt` — non-vacuity capture for Task 1
- `.planning/phases/31-breaks-you-can-skip/31-RED-grip.txt` — non-vacuity capture for Task 2

## Decisions Made

- **Both halves shipped in this one plan, not split.** D-31-06 is explicit that shipping only the slop increase does not satisfy the owner's ruling — both parts landed here, in separate task commits, but within the same plan.
- **`kSubCompactGripSize` named as a standalone constant (14.0), not inlined.** It is deliberately smaller than the `bodySmall` label's own line box so it can never become the row's tallest child, and it is the single number standing between this row and the exact class of miss (`Divider.height`) its own pre-existing comment already warns about.
- **Grip icon is direction-neutral (`Icons.drag_indicator`), never a chevron/arrow.** A directional glyph would assert a swipe direction the owner has not ruled on; the finding is about *findability*, not direction.
- **No new `Semantics`/`semanticLabel` on the glyph.** The row is already wrapped in `Semantics(excludeSemantics: true)` carrying the D-31-04 label; adding a labelled icon inside would either be silently swallowed or perturb an announcement already UAT-passed.
- **`dismissThresholds` confirmed untouched** — `grep -rn "dismissThresholds" lib/ test/` returns zero hits in `lib/` both before and after this plan; the only occurrence anywhere is a pre-existing test comment explaining why it is irrelevant to row height.
- **The SKIPBREAK-02 grid-unchanged group got a comment, not a new assertion.** Its `ClipRect` measurement is `visualHeight`-tall by construction and cannot see an inflated child; documenting that limitation in place (rather than leaving it to be silently misread later) was judged more valuable than adding a redundant assertion to a group whose whole point is measuring the *slot*, not the *content*.

## Deviations from Plan

None — plan executed exactly as written. Every acceptance criterion in all three tasks was checked directly (grep counts, `git diff`/`git status` scoping, RED capture contents) rather than assumed, and every check passed on the first attempt.

## The re-checked "can never bind" claim (verdict, quoted)

Per Task 1's read_first instruction, `lib/services/schedule_generator.dart` was read (not assumed) before writing this verdict. The omitted defensive clamp (`clamp(kBreakHitSlop, 0, precedingRowSlot / 2)`) would begin to bind whenever a neighbouring work chunk's own slot is under `2 * kBreakHitSlop` = 48dp — at `kPixelsPerMinute` = 4.0, **a work chunk shorter than 12 minutes**. Every work chunk the generator creates — commitment (`buildCommitmentChunks`'s `while (cursor + 25 <= block.endMinutes)` loop) and discretionary alike — is created at exactly `durationMinutes: 25`, and the file's only post-creation mutation of `durationMinutes` (the trailing tail-stretch on the last chunk of a commitment block) only ever *lengthens* a chunk to cover a sub-lattice remainder, never shortens one. **Verdict: the claim still holds** at 24.0, with a wider margin (25 min / 100dp actual vs. the 12 min / 48dp binding threshold) than PD-31-01 had reasoned about at the old value.

## RED capture naming lines (quoted, per this plan's `<output>` instruction)

**`31-RED-slop24.txt`** (reverted `kBreakHitSlop` to `16.0`, ran the new Case A):
```
Expected: 'b1'
  Actual: 'w1'
```
Case B (the pure-constant ceiling guard) stayed green throughout, confirming the failure was scoped to exactly the geometric claim Task 1's constant change protects.

**`31-RED-grip.txt`** (forced the grip `Icon` to its unpinned 24.0 default size, deleted the pinning `SizedBox`, ran the new Case C):
```
Expected: <16.0>
  Actual: <24.0>
SKIPBREAK-02: the grip-bearing (unresolved) row and the grip-free (skipped) row must measure the
identical natural height — unresolved=24.0 skipped=16.0.
```
Cases A and B (presence/absence) stayed green throughout, confirming the failure was scoped to exactly the zero-extent claim Task 2's pinning `SizedBox` protects.

## Pre/post test totals

- **Baseline (pre-plan, this plan's base SHA):** 625 passing, `flutter analyze` clean.
- **Post-plan (full suite, after Task 3):** **630 passing** (+5: 2 new cases in `today_screen_test.dart`'s `D-31-06` group, 3 new cases in `today_row_widgets_test.dart`'s `D-31-06` group), `flutter analyze` clean.
- **Existing Phase 31 drag cases needing edits:** **none.** Diffing `test/screens/today_screen_test.dart` against this plan's base SHA shows only additions (one line-count exception is the file's own diff header) — every pre-existing case in the `Phase 31 — SKIPBREAK` group tracked the new `kBreakHitSlop` value automatically because its origins are genuinely symbolic (`kBreakHitSlop`-derived), exactly as the group's own comments claim. This confirms rather than contradicts that claim — no finding to flag here.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Both halves of D-31-06 are shipped, each independently proven with an executed, non-vacuity RED capture on disk. `dismissThresholds` is untouched everywhere in `lib/`, confirmed by grep.
- `flutter test` (full suite, 630 tests) and `flutter analyze` are both green in this worktree.
- **What remains open, deliberately not this plan's scope:** whether a real thumb, on a real device, can now reliably grab the row — this is the one claim `flutter test`'s synthetic exact-coordinate drags cannot settle (coverage entry D6, `human_judgment: true`). A round-two human UAT (31-07 or wherever the orchestrator routes it) is needed before Item 1 can be re-judged PASS.
- D-31-07 (a live break's Skip-only affordance) is **not** addressed by this plan — that was scoped to a separate plan in the gap-closure replan; do not read this plan's green suite as covering it.

---
*Phase: 31-breaks-you-can-skip*
*Completed: 2026-08-26*
