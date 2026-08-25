---
phase: 31-breaks-you-can-skip
plan: 02
subsystem: ui
tags: [flutter, chunk_card, semantics, accessibility, resolved-state]

# Dependency graph
requires:
  - phase: 31-breaks-you-can-skip (plan 01)
    provides: SwipeableChunkCard's isWork onTap gate and endToStart-only Dismissible direction for breaks — this plan asserts both hold, and renders the isSkipped state that plan 01's swipe gesture now writes
provides:
  - "_SubCompactRow.isSkipped (bool, default false) — Opacity(0.5) + TextDecoration.lineThrough + ', skipped' semantics on the 20dp hairline tier"
  - "chunk_card.dart compact break tier gains its first Semantics wrapper (pre-existing accessibility gap closed, not new decoration)"
  - "chunk_card.dart full/detailed break tier: Opacity(0.5) + lineThrough + trailing 'skipped' literal (verbatim reuse of _buildTrailingStatus's string)"
  - "test/screens/today_row_widgets_test.dart 'Phase 31 — what a break still is not' group — onTap/direction/markComplete prohibitions, proven non-vacuous by a temporarily-reversed gate"
affects: [31-03 (negative/no-theft drag test), 31-05 (human UAT — must judge whether 0.5 opacity is legible at sub-compact)]

# Actuals (#2632)
actuals:
  tokens: 5353
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Resolved-state vocabulary reuse across a second chunk kind: Opacity(0.5) + TextDecoration.lineThrough + a trailing 'skipped' literal, taken verbatim from _WorkChunkContent's isResolved/contentOpacity/_buildTrailingStatus and applied to _buildBreak's three density branches with no new visual language."
    - "Prohibition-test non-vacuity check: before trusting an assertion that something CANNOT happen (a break's onTap must stay null), temporarily reverse the gate that enforces it, observe the assertion go RED, then restore the gate and confirm a byte-identical diff — the project's own 'assertion that could not fail' failure class, applied to a gate rather than a finder this time."

key-files:
  created: []
  modified:
    - lib/screens/schedule/widgets/chunk_card.dart
    - test/screens/today_row_widgets_test.dart

key-decisions:
  - "Applied Opacity(opacity: chunk.isSkipped ? 0.5 : 1.0) uniformly (an always-present Opacity whose value is 1.0 when unresolved) rather than conditionally omitting the Opacity widget for the unresolved case. Behaviorally identical (Opacity(1.0) has no visible or hit-test effect) and matches the ternary style _WorkChunkContent already uses, rather than introducing a widget-presence branch the UI-SPEC didn't ask for."
  - "Composed the semantics-label suffix as a plain string ternary (', skipped' appended only when chunk.isSkipped) rather than building a list and joining, matching the file's existing '$title, $duration min' interpolation style at the sub-compact tier."

requirements-completed: [SKIPBREAK-01]

coverage:
  - id: D1
    description: "A skipped break renders at Opacity(0.5) with TextDecoration.lineThrough on its label at every density tier — full/detailed, compact, and sub-compact — reusing the exact resolved-state vocabulary a skipped work chunk already uses (D-31-04)."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#D-31-04: a skipped full-tier break is muted, struck through, and reads 'skipped'"
        status: pass
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#D-31-04: a skipped compact break is muted and struck through, and its new Semantics label carries ', skipped'"
        status: pass
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#D-31-04: a skipped sub-compact break is muted and struck through and still renders exactly two Dividers"
        status: pass
    human_judgment: false
  - id: D2
    description: "At full/detailed tier only, a skipped break's trailing duration text is replaced by the literal lowercase string 'skipped' — verbatim reuse of _buildTrailingStatus's existing string."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#D-31-04: a skipped full-tier break is muted, struck through, and reads 'skipped' (find.text('skipped') findsOneWidget, find.text('5 min') findsNothing)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The compact tier gains a Semantics wrapper it did not have before (closing a pre-existing accessibility gap), and the sub-compact tier's semanticsLabel gains ', skipped' — screen-reader coverage for a state that opacity/strikethrough alone cannot convey."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#D-31-04: a skipped compact break is muted and struck through, and its new Semantics label carries ', skipped' (find.bySemanticsLabel)"
        status: pass
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#D-31-04: a skipped sub-compact break is muted and struck through and still renders exactly two Dividers (find.bySemanticsLabel)"
        status: pass
      - kind: other
        ref: "grep acceptance: Semantics( count increases by exactly 1 relative to git show HEAD (before this plan) — confirmed 1 -> 2"
        status: pass
    human_judgment: false
  - id: D4
    description: "A break is never completable — no break at any density renders the completed treatment, and ChunkCard's break branch receives onTap == null at every density, checked rather than assumed, and proven non-vacuous by temporarily reversing the isWork gate."
    requirement: "SKIPBREAK-01"
    verification:
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#Phase 31 — what a break still is not#a break's ChunkCard receives a null onTap even when the caller supplies one (all 3 densities)"
        status: pass
      - kind: automated_ui
        ref: "test/screens/today_row_widgets_test.dart#Phase 31 — what a break still is not#a break's Dismissible offers only the skip direction / paired work-chunk horizontal case / a skipped break cannot be re-swiped / a break never reaches markComplete"
        status: pass
      - kind: other
        ref: "manual RED verification: reversed SwipeableChunkCard's isWork onTap gate to (!isWork && !resolved), observed all 3 density onTap cases fail RED, restored — git diff confirmed byte-identical restoration"
        status: pass
    human_judgment: false
  - id: D5
    description: "No break's painted height changed (SKIPBREAK-02) — box heights, Divider height:1/thickness:1 pairing, and maxLines:1/TextOverflow.ellipsis stay intact at every tier; only opacity/decoration/text-content changed."
    verification:
      - kind: other
        ref: "grep acceptance: `height: 1` count in chunk_card.dart unchanged from HEAD (3 -> 3); Phase 29's pre-existing break-densities cases pass unmodified with zero-line diff to their bodies"
        status: pass
    human_judgment: false
  - id: D6
    description: "Sub-compact tier's Opacity(0.5) legibility at colorScheme.onSurfaceVariant is a real risk that flutter test cannot settle — flagged for plan 31-05's mandatory human UAT rather than silently assumed correct."
    verification: []
    human_judgment: true
    rationale: "Widget tests can assert the opacity VALUE is 0.5 but cannot judge whether that value reads as legible text on a real screen at the smallest tier. This is explicitly deferred to plan 31-05's blocking human UAT per 31-UI-SPEC.md's own framing (T-31-05, 'mitigate' disposition)."

# Metrics
duration: ~20min
completed: 2026-08-25
status: complete
---

# Phase 31 Plan 02: Skipped-Break Rendering, Every Density Summary

**A skipped break now reads Opacity(0.5) + strikethrough + a reused `'skipped'`/`', skipped'` label at all three density tiers — including the 20dp sub-compact hairline, which had no resolved-state treatment at all before this phase — and a temporarily-reversed gate confirmed the "never tappable, never completable" prohibition tests are not vacuous.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-08-25 (immediately following plan 31-01's merge)
- **Completed:** 2026-08-25
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `_SubCompactRow.isSkipped` (`bool`, default `false`): wraps the row in `Opacity(opacity: isSkipped ? 0.5 : 1.0)`, adds `TextDecoration.lineThrough` to the label `Text`'s style, and the caller composes `', skipped'` onto the semantics label — the 20dp hairline tier's first resolved-state treatment ever.
- Compact break tier gained its first `Semantics` wrapper (previously none existed at this density), carrying `'$title, $duration min, skipped'` when resolved, plus the same `Opacity(0.5)`/`lineThrough` treatment on the dashed-border content — closing a pre-existing accessibility gap, not adding new decoration.
- Full/detailed break tier: the existing icon+title+trailing `Row` gains `Opacity(opacity: chunk.isSkipped ? 0.5 : 1.0)`, the title style gains conditional `lineThrough`, and the trailing `'${duration} min'` text swaps to the literal lowercase `'skipped'` — copied verbatim from `_buildTrailingStatus`'s existing skipped-work-chunk string, not re-authored.
- Five new widget-test cases in the `break densities` group (full/compact/sub-compact skipped, plus full/sub-compact unresolved-unchanged guards) — written first, observed RED against the unmodified widgets (3 of 5 failed, the 2 unresolved-guard cases already passed since they assert unchanged behavior), then GREEN after implementation.
- New group `Phase 31 — what a break still is not`: four cases proving a break's `ChunkCard.onTap` stays `null` at all three densities even when the caller supplies a closure, its `Dismissible` offers only `endToStart` (paired against an unresolved work chunk's `horizontal` so the break case can't pass by the widget losing the complete direction for everyone), a skipped break's direction is `none`, and a rightward drag on an unresolved break reaches neither `markComplete` nor `markSkipped`.
- Verified the onTap-prohibition test is not vacuous: temporarily reversed `SwipeableChunkCard`'s `isWork` gate to `(!isWork && !resolved) ? onTap : null`, re-ran the three density cases, observed all three fail RED (`Expected: null / Actual: <Closure>`), then restored the original gate and confirmed via `git diff` that the file returned to a byte-identical state before committing.

## Task Commits

Each task was committed atomically:

1. **Task 1: A skipped break looks skipped at all three densities** - `a6b2d21` (feat)
2. **Task 2: Prove a break stays untappable and uncompletable after the promote** - `ed54e5e` (test)

_No plan-metadata commit yet — this plan runs inside a git worktree; the orchestrator commits SUMMARY.md/STATE.md/ROADMAP.md centrally after the wave merges, per this executor's worktree-mode instructions._

## Files Created/Modified

- `lib/screens/schedule/widgets/chunk_card.dart` - `_SubCompactRow.isSkipped` param + Opacity/lineThrough/semantics; compact tier's new `Semantics` wrapper + Opacity/lineThrough; full/detailed tier's Opacity/lineThrough/trailing-`'skipped'` swap
- `test/screens/today_row_widgets_test.dart` - `_breakChunk` factory gains `skipped` param; 5 new D-31-04 rendering cases; new `Phase 31 — what a break still is not` group (4 cases, one parameterized over 3 densities)

## Decisions Made

- **Uniform `Opacity(opacity: cond ? 0.5 : 1.0)` rather than conditional widget presence.** At every tier (including `_SubCompactRow`, which previously had no `Opacity` at all), the implementation always constructs an `Opacity` widget whose value is `1.0` when unresolved, rather than branching on whether to wrap in `Opacity` at all. `Opacity(1.0)` has no visible or hit-test effect, this matches `_WorkChunkContent`'s own existing ternary style, and it keeps every branch's widget tree shape identical across resolved states — simpler than a presence/absence branch the UI-SPEC didn't ask for.
- **Semantics label suffix as a plain string ternary** (`'${chunk.isSkipped ? ", skipped" : ""}'`) rather than a list-join, matching the sub-compact tier's existing `'$title, $duration min'` interpolation convention rather than introducing a new composition style.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' `<action>` and `<acceptance_criteria>` were followed verbatim; no Rule 1-4 auto-fixes were needed.

## Issues Encountered

None. The plan-specified RED-then-implement TDD flow for Task 1, and the reverse-the-gate-then-restore verification for Task 2, both worked exactly as scripted on the first attempt.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `lib/screens/schedule/widgets/chunk_card.dart` and `test/screens/today_row_widgets_test.dart` are the only files this plan touched — confirmed via `git status --short` before each commit, matching the wave's declared `files_modified` scope (sibling plan 31-04 owns `schedule_notifier.dart` and its own test file, untouched here).
- `flutter test` (full suite, 612 tests) and `flutter analyze` are both green.
- **Observed RED, recorded per the plan's `<output>` instruction:** reversing `SwipeableChunkCard`'s `isWork` gate to `(!isWork && !resolved) ? onTap : null` made all three density cases of "a break's ChunkCard receives a null onTap even when the caller supplies one" fail with `Expected: null / Actual: <Closure: () => void>` — confirming the prohibition test is load-bearing, not vacuous. The gate was restored immediately after (verified byte-identical via `git diff`) and the reversal was never committed.
- **On the `0.5` sub-compact legibility question (plan 31-05's UAT item (b)):** widget tests confirm the `Opacity` widget carries exactly `0.5` at every tier including sub-compact, and confirm the label text and its Divider box heights are otherwise unchanged — but, as `31-UI-SPEC.md` itself flags, `flutter test` cannot judge whether `0.5` opacity on an already-`onSurfaceVariant`-toned label reads as legible on a real screen. This plan does not attempt to settle that from a desk; it stays exactly the risk plan 31-05's human UAT exists to resolve, with the documented fallback (raise opacity for that tier only, if the owner finds it unreadable).
- Plan 31-03's negative/no-theft drag test and plan 31-04's `schedule_notifier.dart` guard fix are both unaffected by this plan — no changes were made outside `chunk_card.dart`/`today_row_widgets_test.dart`.
- No blockers.

---
*Phase: 31-breaks-you-can-skip*
*Completed: 2026-08-25*

## Self-Check: PASSED

- `lib/screens/schedule/widgets/chunk_card.dart` — FOUND
- `test/screens/today_row_widgets_test.dart` — FOUND
- `.planning/phases/31-breaks-you-can-skip/31-02-SUMMARY.md` — FOUND
- Commit `a6b2d21` (Task 1: feat) — FOUND in `git log`
- Commit `ed54e5e` (Task 2: test) — FOUND in `git log`
- Commit `1da3bd8` (docs: SUMMARY) — FOUND in `git log`
