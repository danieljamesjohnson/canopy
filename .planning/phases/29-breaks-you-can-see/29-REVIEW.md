---
phase: 29-breaks-you-can-see
reviewed: 2026-08-24T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/screens/today/timeline_geometry.dart
  - lib/screens/today/today_screen.dart
  - test/screens/today_row_widgets_test.dart
  - test/screens/today_screen_test.dart
  - test/screens/today_timeline_model_test.dart
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 29: Code Review Report

**Reviewed:** 2026-08-24
**Depth:** standard
**Files Reviewed:** 6

## Dispositions (added 2026-08-24, autonomous run)

| ID | Disposition |
|----|-------------|
| WR-01 | **FIXED** — `440462a`. Both doc comments corrected; the enum comment now distinguishes the live break arm from the still-dead work-chunk arm rather than flipping both. `flutter analyze` clean. |
| IN-01 | **ACCEPTED** — inherited from the pre-existing `compact` tier; a completed/skipped indicator on a 20dp hairline is a design question for the skip work in Phase 31, not a Phase 29 defect. |
| IN-02 | **ACCEPTED** — the source already documents the unreachable `[32,88)` band deliberately; leaving the band in place keeps the tier ladder total if break durations ever change. |
**Status:** issues_found

## Summary

Phase 29 ("Breaks You Can See") adds a third, lower `ChunkCardDensity.subCompact` tier so a 5-minute break renders as a legible hairline-with-label instead of clipping inside its 20dp duration-exact slot. The change is small and additive: one enum value, one file-private widget (`_SubCompactRow`), one new geometry constant (`kSubCompactBreakMinHeight`), and a three-way ternary in `today_screen.dart` that replaces the old two-way break density split.

I traced the diff against `5e1c474b28812b77e32ec49d4b7e4e480e6f9c0c^..HEAD`, re-derived the threshold arithmetic by hand, ran `flutter analyze` (clean) and the three affected test files (150/150 passing), and cross-checked `TimelineRowTile`/`OverflowBox` wrapping for any height contribution the sub-compact row's own zero-margin design didn't account for. I found no logic errors, no security issues, and no crash risk in the reviewed diff. The one real defect is a documentation-accuracy bug: two doc comments in `chunk_card.dart` still describe the sub-compact break path as unwired dead code, when the same file's own code two hundred lines below demonstrably wires it. Two lower-severity, pre-existing observations round out the report.

## Warnings

### WR-01: Stale doc comments claim the sub-compact break path is still unreachable — it is not

**File:** `lib/screens/schedule/widgets/chunk_card.dart:43-48` (also `lib/screens/schedule/widgets/chunk_card.dart:309-313`)

**Issue:** The `ChunkCardDensity.subCompact` enum value's doc comment reads:

> "No call site selects this value for a break yet either — `_buildBreak`'s density `if`-chain doesn't check it until plan `29-02` wires the branch and `today_screen.dart`'s break density ternary. Until then this value exists purely so the two density-keyed switch expressions in `_WorkChunkContent` below stay exhaustive."

This was accurate for the plan-29-01 scaffold commit (`6c2db38`), but plans 29-02 through 29-04 (commits `9a6ae15`, `1c44c67`, `354dd0c`, `8640cbe`) have since landed and are part of this HEAD. As the same file shows at line ~158, `_buildBreak` now has a live `if (density == ChunkCardDensity.subCompact) return _SubCompactRow(...)` branch, and `today_screen.dart`'s break density ternary (line ~797-802) now selects `subCompact` for every real 5-minute break the schedule generator produces (proven by 150 passing tests, including `today_screen_test.dart`'s `SEEBREAK-01`/`SEEBREAK-02` groups exercising it through the full screen). The comment was never updated after the wiring landed, so it now asserts something false about the code directly beneath it.

The nearly-identical `_SubCompactRow` class doc (line 309-313) is more hedged — "Shared by `_buildBreak`'s sub-compact branch (wired in plan `29-02`) ... Not reachable from any call site as of this plan (PD-29-01)" — but is confusing for the same reason: read at HEAD, where plan 29-02 has landed, "not reachable ... as of this plan" reads as a live claim rather than a historical marker, and a reader has to already know the phase's plan history to disambiguate.

This is a real risk, not pedantry: a future contributor doing dead-code cleanup, reading only this doc comment (which explicitly says the branch "exists purely so the switch stays exhaustive"), could reasonably conclude the `if`-branch in `_buildBreak` is vestigial and remove it — silently reintroducing the exact clipping defect (a 5-minute break's slot too short for its content) that this entire phase exists to fix.

**Fix:**
```dart
/// Phase 29 (SEEBREAK-01, `29-UI-SPEC.md`). Triggers when a row's slot
/// height falls below `kSubCompactBreakMinHeight` — **break rows only**.
/// Renders a single hairline-with-label (`_SubCompactRow`: two `Divider`s
/// flanking a centered label) instead of a card — no dashed border, no
/// duration text, non-interactive like every other break tier.
///
/// The work-chunk arm that handles this value below stays a documented
/// dead path: `today_screen.dart`'s work-chunk density ternary never
/// selects `subCompact` (it stays a 2-way `full`/`compact` split, per
/// `29-UI-SPEC.md` § "Scope boundary"). For BREAKS, this value IS live as
/// of plan 29-02: `_buildBreak`'s density `if`-chain returns
/// `_SubCompactRow` for it, and `today_screen.dart`'s break density
/// ternary selects it for every break whose slot falls below
/// [kSubCompactBreakMinHeight] — a real 5-minute break in production,
/// today. Do not "clean up" that branch as unreachable.
subCompact,
```
and update the `_SubCompactRow` class doc's second sentence similarly (drop "Not reachable from any call site as of this plan" or make explicit it is a historical note about the 29-01 scaffold commit, not the current state).

## Info

### IN-01: The sub-compact tier (like the compact tier it displaces) shows no resolved-state indicator

**File:** `lib/screens/schedule/widgets/chunk_card.dart:158-163` (compare to the `compact` branch, `chunk_card.dart:168-192`, and the `detailed`/`full` branch's `if (chunk.isCompleted) [...]`, `chunk_card.dart:235-242`)

**Issue:** `_buildBreak`'s `subCompact` branch renders only `_SubCompactRow(label: title, semanticsLabel: ...)` — there is no check for `chunk.isCompleted` or `chunk.isSkipped` anywhere in that branch, so a completed or skipped break is visually and semantically indistinguishable from an unresolved one at this density. This is not a new gap introduced by this phase — the pre-existing `compact` tier has the identical omission (no check icon, per its own doc comment: "no completed check icon") — but before this phase, a normal 5-minute break rendered `compact` (20dp slot < the old single 88dp threshold), and after this phase it renders `subCompact` instead. Net effect: the missing-resolved-indicator behavior is unchanged, but it is now guaranteed to be what every short break in production actually shows, rather than an edge case.

**Fix:** Not a required fix for this phase (scope boundary in `29-UI-SPEC.md` doesn't cover it), but worth a conscious call in a follow-up: either add a minimal resolved-state signal to `_SubCompactRow` (e.g. dim the label, small check glyph before the text) or explicitly document the decision to omit it, so it reads as a choice rather than an oversight.

### IN-02: The `compact` break density band is now fully dead code in production

**File:** `lib/screens/today/today_screen.dart:797-805`, `lib/screens/schedule/widgets/chunk_card.dart:168-192`

**Issue:** With `kSubCompactBreakMinHeight = 32.0` and `kFullBreakMinHeight = 88.0`, the `compact` branch is only selected for a break slot in `[32, 88)` px, i.e. a break duration in `[8, 22)` minutes. The schedule generator (Phase 28's lattice) only ever emits 5-minute short breaks (20px) and 30-minute long breaks (120px), so no real schedule can currently produce a break that renders `compact`. This is already explicitly documented in `kSubCompactBreakMinHeight`'s own doc comment ("the `compact` band is unreachable at today's two generated durations — kept because a future cadence change could reach it"), so it's a deliberate, acknowledged tradeoff rather than an oversight — flagging only for visibility, since dead-but-load-bearing code is easy to lose track of across future refactors.

**Fix:** None required — this is intentional per the phase's own documentation. If a future phase changes the schedule generator's break durations, re-verify this band actually becomes reachable and gets test coverage from a real (not forced) schedule fixture.

---

_Reviewed: 2026-08-24_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
