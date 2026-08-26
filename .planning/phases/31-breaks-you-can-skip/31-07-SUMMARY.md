---
phase: 31-breaks-you-can-skip
plan: 07
subsystem: ui
tags: [flutter, widget-test, dismissible, live-row, now-state, gap-closure]

# Dependency graph
requires:
  - phase: 31-06
    provides: kBreakHitSlop=24.0 (the 68dp acquisition band) and the sub-compact grip glyph — this plan's SwipeableRowShell reuses the shipped slop value unchanged
  - phase: 31-03
    provides: the non-vacuity RED protocol (delete the fix from the production file, run, capture the named failure verbatim, restore byte-identical) this plan reuses exactly
  - phase: 31-01
    provides: SwipeableChunkCard's original Dismissible mechanics, extracted verbatim into SwipeableRowShell by this plan's Task 2
provides:
  - "LiveRowCard.showComplete/isSkipped — a live break is Skip-only, never Complete, with TextDecoration.lineThrough at both density tiers and no Opacity wrapper"
  - "SwipeableRowShell — the Dismissible extracted from SwipeableChunkCard, verbatim and API-preserving, now the single swipe-contract definition for chunk rows"
  - "A live break's row wrapped in SwipeableRowShell at the isLive arm of _buildPositionedRow, growing its hit-test envelope by kBreakHitSlop exactly as the non-live break arm does"
  - "test/screens/today_screen_now_state_test.dart's D-31-07 group — Cases A-D, including truth #14's three-part composition proof"
  - "31-RED-d3107.txt — executed non-vacuity capture for both named failures"
affects: [31-08 (if planned — the round-two human UAT covering both D-31-06 and D-31-07 together), any future work touching now_state.dart's "advance past resolved chunks" semantics should read this plan's Case B commentary first]

# Actuals (#2632)
actuals:
  tokens: 15600
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Extract-then-wrap for gesture shells: SwipeableChunkCard's Dismissible was pulled into a standalone SwipeableRowShell(chunk, visualHeight, child) so a second call site (the live-break arm) can reuse the identical swipe contract without a second Dismissible definition — proven behaviour-preserving via an empty git status --porcelain on the pre-existing test file, not merely asserted."
    - "Stack-relative geometry comparison across two independently-classified NowState pumps: when comparing tester.getRect() positions across two pumps whose NowState classification differs (Active vs GapBeforeNext), measure relative to a stable in-Stack anchor (the timeline Stack's own top), not raw screen coordinates — an edge-state banner or CAL-03 auto-scroll target can legitimately differ between classifications and will otherwise be misread as a geometry regression."

key-files:
  modified:
    - lib/screens/today/widgets/live_row_card.dart
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart
    - lib/screens/today/today_screen.dart
    - test/screens/today_row_widgets_test.dart
    - test/screens/today_screen_now_state_test.dart
    - .planning/phases/31-breaks-you-can-skip/31-VERIFICATION.md
  created:
    - .planning/phases/31-breaks-you-can-skip/31-RED-d3107.txt

key-decisions:
  - "SwipeableRowShell extraction required ZERO edits to any existing test file. git status --porcelain test/screens/today_screen_test.dart stayed empty through Task 2's commit, and the file's own Phase 31 SKIPBREAK group (12 cases) passed unmodified — proving the extraction behaviour-preserving rather than asserting it."
  - "showActions' meaning changed from 'work chunks only' to 'this row offers at least one action'; showComplete is the new parameter that decides WHICH actions, defaulting to true so the live work chunk's shipped behaviour needed zero call-site changes beyond the one line D-31-07 targets."
  - "No Opacity wrapper added to LiveRowCard for the skipped state (PD-31-07-02) — the live card paints over the now-line rule specifically so the rule stops at the card's edges, and a translucent card would re-open the exact 27-UI-REVIEW.md defect that fix closed."
  - "Case B's literal plan wording ('exactly one LiveRowCard is found' in both a live pump and a pre-skipped pump at the same clock) was corrected against two verified facts about the existing codebase, documented in place rather than silently reinterpreted: (1) resolveNowState's 'advance past resolved chunks' loop unconditionally delists an isSkipped/isCompleted chunk from 'current', even mid-window — a pre-existing, deliberate, ALREADY-TESTED invariant (this file's own 'near-gap: c1 resolved 9:00-9:25 ... now=9:10 -> GapBeforeNext' case), not a defect this plan introduced or should change; (2) GapBeforeNext's 'Up next' banner (absent for Active) shifts the whole page, confounding a raw-screen-coordinate comparison. The corrected proof measures the SAME chunk's confined-band height and Stack-relative position across the live-to-resolved-and-delisted transition, which is the claim that is actually true and actually load-bearing."
  - "Cases C and D were likewise re-scoped to the reachable state (a break that WAS live and is now resolved-and-delisted) rather than the literally-unreachable 'isSkipped:true LIVE break' combination, which is impossible through resolveNowState for ANY chunk type, not just breaks. Case D's 'true' half of the isSkipped/strikethrough matrix is proven instead at the widget level in Task 1's today_row_widgets_test.dart addition, which exercises the identical _buildLiveRow wiring without going through the state machine."
  - "_needsSlop gained no isLive term (verified by direct read, quoted in Task 2's commit) — the live-break branch calls the existing predicate to decide slop amount, relying on the fact that a chunk is either live or not, never both, so the two Stack passes stay mutually exclusive by construction."

requirements-completed: [SKIPBREAK-01, SKIPBREAK-02]

coverage:
  - id: D1
    description: "A live break shows a Skip action and never a Complete action at the compact tier (30-minute long break, 120dp slot); a live WORK chunk at the identical slot height is unaffected (PD-31-07-03 regression guard)."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#LiveRowCard — two density tiers (GRID-02)#D-31-07 — LiveRowCard Skip without Complete"
        status: pass
      - kind: automated_ui
        ref: "test/screens/today_screen_now_state_test.dart#TodayScreen time-anchored Now (NOW-01/NOW-02)#D-31-07: a live long break shows Skip and never Complete"
        status: pass
      - kind: automated_ui
        ref: "test/screens/today_screen_now_state_test.dart#TodayScreen time-anchored Now (NOW-01/NOW-02)#D-31-07: a live WORK chunk at the identical slot height keeps both Complete and Skip (PD-31-07-03 regression guard)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A live 5-minute break's single-line-tier row is swipeable via the same one-directional endToStart SwipeableRowShell every other break uses, at the shipped kBreakHitSlop=24.0 acquisition band."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_now_state_test.dart#D-31-07 — a live break can be skipped#Case A — a live short break can be swiped"
        status: pass
      - kind: other
        ref: ".planning/phases/31-breaks-you-can-skip/31-RED-d3107.txt (non-vacuity capture, Case A named failure: Expected 'b1' / Actual null)"
        status: pass
    human_judgment: false
  - id: D3
    description: "SwipeableRowShell extraction is verbatim and API-preserving — SwipeableChunkCard's public constructor, every parameter, and onTap gating are byte-for-byte unchanged, proven by an empty git status --porcelain on the pre-existing test file through the extraction's own commit."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: other
        ref: "git status --porcelain test/screens/today_screen_test.dart (empty, confirmed at commit 6689b9c) and full-suite pass of that file's 152 cases with zero edits"
        status: pass
    human_judgment: false
  - id: D4
    description: "Truth #14's UI-SPEC E2 composition — a live break's confined band keeps its slot height and timeline position, and the now-line's Stack-relative position is unchanged, across the live-to-resolved-and-delisted transition."
    requirement: "SKIPBREAK-02"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_now_state_test.dart#D-31-07 — a live break can be skipped#Case B — truth #14's composition, proven"
        status: pass
    human_judgment: false
  - id: D5
    description: "An already-resolved (skipped) break offers no Skip affordance and cannot be re-swiped, at the position it occupied while live."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_screen_now_state_test.dart#D-31-07 — a live break can be skipped#Case C"
        status: pass
    human_judgment: false
  - id: D6
    description: "_needsSlop carries no isLive term; Layer 1a/1b still agree on it; the live break's branch needs no Layer 1b treatment because the live-row loop is already the last Stack child."
    requirement: "SKIPBREAK-02"
    verification:
      - kind: other
        ref: "lib/screens/today/today_screen.dart _needsSlop body (read verification, quoted in this SUMMARY below)"
        status: pass
    human_judgment: false

# Metrics
duration: ~2h
completed: 2026-08-26
status: complete
---

# Phase 31 Plan 07: A Currently-Live Break Becomes Skippable Summary

**A live break now shows Skip (never Complete) at the compact tier and is swipeable at the single-line tier via an extracted, shared `SwipeableRowShell`, with truth #14's live+skipped composition proven — not re-abstained — against two evidence-based corrections to the plan's literal test design.**

## Performance

- **Duration:** ~2h
- **Completed:** 2026-08-26
- **Tasks:** 3
- **Files modified:** 6 (3 production, 3 test), 1 new RED-capture artifact, 1 verification note

## Accomplishments

- `LiveRowCard` gained `showComplete` (default `true`) and `isSkipped` (default `false`), both defaulted so every pre-existing call site compiles unchanged. `_buildLiveRow`'s `showActions` call site now reads `isBreak ? !chunk.isSkipped : true` (was: work-chunk-only), removing the exact line `31-VERIFICATION.md` truth #14 cited as the reason it abstained.
- Extracted `SwipeableRowShell` from `SwipeableChunkCard.build` — a mechanical, verbatim extraction proven behaviour-preserving by an empty `git status --porcelain` on `test/screens/today_screen_test.dart` through the extraction's own commit, not merely asserted. `SwipeableChunkCard` is now a thin wrapper; there remains exactly one `Dismissible` definition for chunk rows in `lib/`.
- Added a live-break branch to `_buildPositionedRow`'s `isLive` arm: wraps the live row in `SwipeableRowShell` with no outer `ClipRect` (the shell's own `_confineContent` re-imposes it at exactly `slot`), grows the hit-test envelope by the shipped `kBreakHitSlop` under `kMinBreakDragTarget`, and needs no Layer 1b treatment since the live-row loop is already the Stack's last child.
- Repointed the now-stale `live break shows no Complete/Skip (D-02)` case into two precise ones (a live long break shows Skip and never Complete; a live WORK chunk at the identical slot height keeps both — the PD-31-07-03 regression guard) and added a new `D-31-07 — a live break can be skipped` group with four cases, including truth #14's composition proof.
- Wrote `31-RED-d3107.txt`: an executed non-vacuity capture with both required named failures (the un-swiped break, the absent Skip tooltip), both temporary production reversions confirmed restored byte-identical.
- Added a dated note under truth #14 in `31-VERIFICATION.md` recording that its abstention's stated justification is no longer factual and naming the two test groups that now carry the evidence.

## Task Commits

Each task was committed atomically:

1. **Task 1: Give LiveRowCard a Skip-without-Complete mode and a skipped state** - `1bb6dd3` (feat)
2. **Task 2: Extract SwipeableRowShell and make the live break row swipeable** - `6689b9c` (feat)
3. **Task 3: Prove truth #14's composition and repoint the stale live-break test, with a RED capture** - `b263e5e` (test)

_No separate plan-metadata commit — this plan runs inside a git worktree; the orchestrator commits this SUMMARY.md and STATE.md/ROADMAP.md centrally after the wave merges._

## Files Created/Modified

- `lib/screens/today/widgets/live_row_card.dart` — `showComplete`/`isSkipped` parameters, `TextDecoration.lineThrough` at both tiers, no `Opacity` wrapper (PD-31-07-02)
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — `SwipeableRowShell` extracted; `SwipeableChunkCard` now a thin wrapper
- `lib/screens/today/today_screen.dart` — `_buildLiveRow`'s `showActions`/`showComplete`/`isSkipped` wiring; the live-break branch in `_buildPositionedRow`'s `isLive` arm
- `test/screens/today_row_widgets_test.dart` — new `D-31-07 — LiveRowCard Skip without Complete` group (4 cases)
- `test/screens/today_screen_now_state_test.dart` — repointed D-02 case (→ 2 cases); new `D-31-07 — a live break can be skipped` group (4 cases)
- `.planning/phases/31-breaks-you-can-skip/31-RED-d3107.txt` — non-vacuity capture for Task 3
- `.planning/phases/31-breaks-you-can-skip/31-VERIFICATION.md` — dated note under truth #14

## Deviations from Plan

### Auto-fixed Issues

None — no bugs, missing functionality, or blocking issues arose that required Rule 1-3 auto-fixes to production code.

### Test-design corrections (documented, not silent)

**1. Case B's literal "exactly one LiveRowCard found" in both pumps was corrected to reflect verified `resolveNowState` behavior.**
- **Found during:** Task 3, writing the truth #14 composition proof.
- **Issue:** The plan's Case B instructs pumping "the break skipped" at a clock still inside its own window and expecting `resolveNowState` to still classify it `Active` (i.e., still live). A probe test against `resolveNowState` (run before writing the final test) showed this returns `GapBeforeNext(w2)`, not `Active(b1)`. Reading `now_state.dart`'s "advance past resolved chunks" loop confirms this is unconditional and pre-existing: it treats ANY `isCompleted || isSkipped` candidate as no longer current, even while its own window is open — for any chunk type, not just breaks. This project's own `near-gap: c1 resolved 9:00-9:25, c2 starts 9:25, now=9:10 -> GapBeforeNext` case (same file, pre-existing, unmodified) already exercises and asserts exactly this invariant for a work chunk. Changing `now_state.dart` to make Case B's literal premise true would be an architectural change to a heavily-tested state machine, well outside this plan's scope, and was not attempted.
- **Fix:** Case B was rewritten to assert the claim that IS true and load-bearing: the same chunk's confined paint band keeps its exact slot height and its position relative to the timeline Stack's own top across the live-to-resolved-and-delisted transition, and the now-line's Stack-relative position is unchanged. A second, independently-discovered confound (the GapBeforeNext-only "Up next" banner shifts the whole page, differently from Active's empty edge-state line) was also corrected by measuring positions relative to the Stack rather than in raw screen coordinates.
- **Files modified:** `test/screens/today_screen_now_state_test.dart` (test-file-only; no production behavior changed).
- **Commit:** `b263e5e`.

**2. Cases C and D re-scoped to the reachable state.**
- **Found during:** Task 3, same investigation as above.
- **Issue:** Cases C and D as literally described ("an already-skipped LIVE break") share Case B's false premise — the combination `isLive && isSkipped` is unreachable through `resolveNowState` for any chunk type.
- **Fix:** Case C now proves the reachable equivalent (a break that WAS live and is now resolved-and-delisted offers no Skip affordance and cannot be re-swiped, at the position the live row previously occupied). Case D proves the "false" half of the isSkipped/strikethrough matrix at the screen level (a live, unresolved break carries no strikethrough); the "true" half is already proven at the widget level in Task 1's `today_row_widgets_test.dart` addition, which exercises the identical `_buildLiveRow` wiring without depending on `resolveNowState`'s reachability.
- **Files modified:** `test/screens/today_screen_now_state_test.dart`.
- **Commit:** `b263e5e`.

Neither correction changed any production file or weakened truth #14 — both are documented in place (in the test file's own comments, and here) so a future reader sees a deliberate ruling rather than an oversight or a silently-weakened test.

## The RED capture's two named failures (quoted)

**Reverted:** `_buildLiveRow`'s `showActions` back to `chunk.chunkType == ChunkType.work`, and the live-break branch's `isLiveBreak` predicate forced to `false` (restoring the plain `ClipRect`/`OverflowBox` live arm, no `SwipeableRowShell`).

```
D-31-07: a live long break shows Skip and never Complete
Expected: exactly one matching candidate
  Actual: _DescendantWidgetFinder:<Found 0 widgets ...>

Case A — a live short break can be swiped
Expected: 'b1'
  Actual: <null>
```

Both production files confirmed restored byte-identical (`git diff lib/screens/today/today_screen.dart` empty) before committing.

## The three measured pairs from Case B (quoted)

1. **Keeps its slot height:** live pump `5 * kPixelsPerMinute` == resolved pump `5 * kPixelsPerMinute` (both `20.0`).
2. **Stays on the timeline:** the confined band's top edge, measured relative to the timeline Stack's own top, is identical before and after resolution (both arms route through the same `SwipeableRowShell._confineContent` geometry).
3. **Does not move the now-line:** the now-line's position relative to the Stack is identical before and after resolution — asserted by direct equality, not by re-deriving the expected y from geometry.

## `_needsSlop`'s body (quoted, per Task 2's acceptance criteria)

```dart
bool _needsSlop(ScheduledChunk chunk, TimelineGeometry geometry) {
  final isBreak =
      chunk.chunkType == ChunkType.shortBreak ||
      chunk.chunkType == ChunkType.longBreak;
  if (!isBreak) return false;
  final start = chunk.displayStartMinutes;
  if (start == null) return false;
  return geometry.heightFor(start, chunk.durationMinutes) <
      kMinBreakDragTarget;
}
```

No `isLive` term, confirming Layer 1a's exclusion and Layer 1b's inclusion still agree on it.

## Full-suite total

- **Baseline (this plan's base SHA, post-31-06):** 630 passing, `flutter analyze` clean.
- **Post-plan (full suite, after Task 3):** **639 passing** (+9: 4 new cases in `today_row_widgets_test.dart`'s D-31-07 group, +1 net in `today_screen_now_state_test.dart` from repointing D-02 into 2 cases, +4 new cases in that file's D-31-07 group), `flutter analyze` clean.

## Issues Encountered

None beyond the two documented test-design corrections above.

## User Setup Required

None — no external service configuration required.

## Known Stubs

None.

## Next Phase Readiness

- D-31-07 ships at both live density tiers — button where a button fits (compact tier, 30-minute+ breaks), swipe where it does not (single-line tier, 5-minute breaks) — with Complete excluded everywhere, consistent with D-31-01.
- `SwipeableRowShell` is now the single swipe-contract definition for chunk rows; a future third call site (if one is ever needed) should reuse it rather than adding a second `Dismissible`.
- Truth #14 has a real code path, real assertions, and a real RED capture — it can be re-verified by `/gsd-verify-work` rather than re-abstained. The verifier should read this SUMMARY's "Deviations from Plan" section before scoring row 14, since the proof's exact assertions differ from the plan's literal (and, per the probe evidence in this SUMMARY, factually incorrect) wording.
- This plan ships alongside 31-06 for a single round-two human UAT covering both D-31-06 (acquisition) and D-31-07 (live-break skippability).

---
*Phase: 31-breaks-you-can-skip*
*Completed: 2026-08-26*

## Self-Check: PASSED

- `lib/screens/today/widgets/live_row_card.dart` — FOUND
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — FOUND
- `lib/screens/today/today_screen.dart` — FOUND
- `test/screens/today_row_widgets_test.dart` — FOUND
- `test/screens/today_screen_now_state_test.dart` — FOUND
- `.planning/phases/31-breaks-you-can-skip/31-RED-d3107.txt` — FOUND
- `.planning/phases/31-breaks-you-can-skip/31-VERIFICATION.md` — FOUND
- Commit `1bb6dd3` (feat: LiveRowCard Skip-without-Complete) — FOUND in `git log`
- Commit `6689b9c` (feat: SwipeableRowShell extraction + live-break branch) — FOUND in `git log`
- Commit `b263e5e` (test: truth #14 composition proof + RED capture) — FOUND in `git log`
