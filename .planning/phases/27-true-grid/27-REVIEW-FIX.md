---
phase: 27-true-grid
fixed_at: 2026-08-18T15:30:00Z
review_path: .planning/phases/27-true-grid/27-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 27: Code Review Fix Report

**Fixed at:** 2026-08-18T15:30:00Z
**Source review:** .planning/phases/27-true-grid/27-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (WR-01, WR-02, IN-01, IN-02 — all Warning and Info findings; no Critical
  findings existed)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: Hit-test regression test bypasses real hit-testing after the defect it worked around was fixed

**Files modified:** `test/screens/today_screen_test.dart`
**Commit:** `9c2ef68`
**Applied fix:** Restored the real `tester.tap(find.text('Reading'))` in place of the direct
`chunkCard.onTap!()` invocation, now that plan 27-02's fix (`Positioned(height: slot)` for the live
row) makes the geometric tap safe again. Updated the surrounding comment to record the history
(why the bypass existed, when it was fixed) instead of reasserting the now-gone defect as current.

**Verification beyond the standard 3-tier check:** ran `flutter test` with the real tap — passes.
Then, in the isolated fix worktree only, temporarily reverted `today_screen.dart`'s live-row
`height: slot` to `height: null` (reproducing the pre-27-02 unbounded live row) and re-ran the same
test — it failed with an off-target tap, confirming the restored assertion is a real regression
guard and not a no-op. The production revert was discarded (`git diff --stat` showed zero change to
`today_screen.dart`) before this commit was made; only the test file is part of the commit.

### WR-02: Stale doc comments reference concepts this phase deleted

**Files modified:** `lib/screens/today/today_screen.dart`
**Commit:** `c144f8f`
**Applied fix:** `_chunkTitle`'s doc comment no longer names the deleted `"Next · …"` line;
`_liveSecondsRemaining`'s doc comment no longer claims a progress-bar consumer. The progress bar's
removal is kept as a dated parenthetical explaining *why* it's gone (now-line already communicates
fraction-elapsed) rather than silently dropped, consistent with this codebase's habit of keeping
amendment history in comments.

### IN-01: Single-line tier's countdown suffix has no overflow guard

**Files modified:** `lib/screens/today/widgets/live_row_card.dart`
**Commit:** `e813e5d`
**Applied fix:** Added a comment above the `Text(' · $remainingLabel', ...)` recording the known,
accepted `RenderFlex` overflow risk at large accessibility text scales, citing `27-UI-SPEC.md`'s
non-truncation rule and `27-VALIDATION.md`'s explicit scoping of large text scales as out of this
phase's verification. No layout behavior changed, per the finding's own guidance.

### IN-02: Duplicated Complete/Skip `IconButton` blocks invite drift

**Files modified:** `lib/screens/today/widgets/live_row_card.dart`
**Commit:** `d378b9a`
**Applied fix:** Extracted a private `_buildActionIcon({icon, color, tooltip, onPressed})` builder
carrying the shared `constraints`/`padding`/`style` (including the touch-target-sizing rationale
comment) in one place. Both call sites still state their own icon, color, tooltip, and callback
explicitly, keeping the two buttons' distinct identities visible at each call site.

## Skipped Issues

None — all findings were fixed.

---

_Fixed: 2026-08-18T15:30:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
