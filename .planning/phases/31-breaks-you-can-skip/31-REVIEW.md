---
phase: 31-breaks-you-can-skip
reviewed: 2026-08-25T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/screens/today/timeline_geometry.dart
  - lib/screens/schedule/widgets/swipeable_chunk_card.dart
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/screens/today/today_screen.dart
  - lib/providers/schedule_notifier.dart
  - test/screens/today_screen_test.dart
  - test/screens/today_row_widgets_test.dart
  - test/providers/schedule_notifier_break_extension_test.dart
findings:
  critical: 0
  warning: 1
  info: 1
  total: 2
status: issues_found
---

# Phase 31: Code Review Report

**Reviewed:** 2026-08-25
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found (both findings are minor, no blockers)

## Summary

Reviewed the full diff for Phase 31 (SKIPBREAK-01/02) against `31-UI-SPEC.md`, `31-RESEARCH.md`,
and each plan's own SUMMARY claims, with particular attention to the five risk surfaces called out
in the review brief.

**The grown hit-test envelope arithmetic is correct.** `_buildPositionedRow`'s break arm sets
`top: geometry.yFor(start) - slop`, `height: slot + 2*slop`. Worked the algebra: the resulting box's
vertical center is `yFor(start) + slot/2` regardless of `slop`'s value, which is exactly the center
`Align(center)` inside `SwipeableChunkCard._confineContent`/`_confineReveal` needs in order to
reproduce `[yFor(start), yFor(start)+slot]` for the painted content. Confirmed with the actual
running test suite (`SKIPBREAK-02 — the grid is unchanged` group, all passing) rather than static
reading alone.

**The Layer 1b Stack pass is correctly mutually exclusive with Layer 1a.** `_needsSlop` gates both
loops identically (`!_needsSlop(...)` in 1a, `_needsSlop(...)` in 1b), so no chunk is ever emitted
twice and no `ValueKey` collision is possible. The live row and the now-line overlay are unaffected —
Layer 1b sits strictly between the non-live/non-slop loop and the now-line overlay, matching the
documented ordering. Independently verified the underlying claim ("last-added Stack child wins
hit-testing") against `RenderStack.hitTestChildren`/`defaultHitTestChildren` in the Flutter SDK
directly, not just by trusting the code comments.

**Guard 9 in `_absorbReclaimedTimeIntoNextBreak` is correctly placed.** It sits after Guard 6
(anchored/movable check) and before Guard 7 (window-open check), so a skipped break is rejected
regardless of whether its window has opened yet — closing exactly the gap the window-open guard
alone would have left. Guards 1–8 are otherwise untouched (confirmed via the diff: only one line
inserted, no renumbering, no reordering).

**`SwipeableChunkCard`'s promote is sound.** Verified against the Flutter SDK's own
`Dismissible.build()` (`background`/`secondaryBackground` substitution logic) that a one-directional
break with `secondaryBackground: null` correctly uses `background` for its only enabled direction
(`endToStart`) — this is not just trusted from the code comment, it was checked against
`dismissible.dart:613-619` directly. For every existing work-chunk call site, `visualHeight` stays
`null`, so `_confineReveal`/`_confineContent` are identity transforms and the work-chunk swipe
(`horizontal` direction, both reveals, `onTap` gate) is byte-for-byte unchanged — confirmed by
reading the diff line-by-line, not just running the (green) test suite.

**No product-position violations.** No LLM/AI surface, no new secrets, no `eval`/dangerous-function
usage, no debug artifacts (`print`, `TODO`, `FIXME`) introduced anywhere in the diff.

**`flutter analyze --no-pub`**: clean. **`flutter test --no-pub`** on the three most relevant files:
160/160 passing.

Both findings below are documentation-accuracy issues in test comments, not functional defects —
every test whose comment is now stale still asserts something true and non-vacuous.

## Warnings

### WR-01: Two pre-existing test titles/comments describe a code path this phase deleted

**File:** `test/screens/today_row_widgets_test.dart:962-1017`
**Issue:** Two tests — `"SwipeableChunkCard forwards density on the break early-return path..."`
(line 962) and `"SEEBREAK-01: SwipeableChunkCard forwards subCompact on the break early-return
path"` (line 983, with an inline comment claiming "two forwarding sites (the break early-return at
~line 79-81, and the Dismissible's `child: ChunkCard(...)` at ~line 123-132)") — both predate this
phase and were not touched by this phase's diff (confirmed: they fall outside every insertion hunk
in `git diff e82189e..HEAD`). But `swipeable_chunk_card.dart`'s `chunk.chunkType != ChunkType.work`
early return is exactly what plan 31-01's `promote` decision deleted (confirmed: `grep -n
"chunkType != ChunkType.work" lib/screens/schedule/widgets/swipeable_chunk_card.dart` returns
nothing; there is now exactly one `density:` forwarding site, line 216). These two test names/
comments now describe a branch and a "two forwarding sites" structure that no longer exist —
directly contradicting this phase's own D3 coverage claim ("SwipeableChunkCard collapses to exactly
one Dismissible construction site"). The tests themselves still pass and still assert something real
(compact/sub-compact density forwarding for a break), so this is not a functional bug — but a future
maintainer trusting the comment's claimed line numbers/structure while touching this widget again
will be misled.
**Fix:** Reword both test titles/comments to describe the current, single-construction-site
structure, e.g. "SwipeableChunkCard forwards density for a break (compact)" and drop the "early-
return path" / "two forwarding sites" language, or delete the now-inaccurate inline comment at
lines 987-994 entirely since the claim it documents no longer holds.

## Info

### IN-01: Stale guard count in a comment added by this same phase

**File:** `test/providers/schedule_notifier_break_extension_test.dart:396-397`
**Issue:** The D-31-05 regression test's own new comment reads "Deliberately inside w1's own window,
so every one of the eight existing guards passes" — but this same plan (31-04) added the ninth guard
in the same commit sequence. The comment was accurate before Guard 9 landed and was not updated
afterward.
**Fix:** Update to "every one of the eight pre-existing guards" or "every one of the nine guards"
(whichever reading was intended) so the count doesn't contradict `schedule_notifier.dart`'s own
guard list.

---

_Reviewed: 2026-08-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
