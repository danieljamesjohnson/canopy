---
phase: 06-desktop-and-web-polish
fixed_at: 2026-05-14T00:00:00Z
review_path: .planning/phases/06-desktop-and-web-polish/06-REVIEW.md
iteration: 1
findings_in_scope: 11
fixed: 10
skipped: 1
status: partial
---

# Phase 6: Code Review Fix Report

**Fixed at:** 2026-05-14T00:00:00Z
**Source review:** `.planning/phases/06-desktop-and-web-polish/06-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 11 (2 Critical + 9 Warning; Info skipped per `--fix` default scope)
- Fixed: 10
- Skipped: 1
- Test baseline before: 89 passing / `flutter analyze` clean
- Test baseline after: **90 passing** / `flutter analyze` clean (one new regression test added for WR-09)

## Fixed Issues

### CR-01: Mid-foreground midnight rollover does not reset mood seed (D-10 broken)

**Files modified:** `lib/providers/theme_notifier.dart`
**Commit:** `4939db9`
**Applied fix:** Added `_resetIfDayChanged()` call inside the 20-minute `Timer.periodic` callback in `_startTicker`, before `notifyListeners()`. A foregrounded app now clears the in-memory mood seed at the local midnight crossing on the very next tick (worst case ~20 minutes post-midnight) without requiring a pause/resume cycle. Existing daily-rollover tests in `theme_notifier_test.dart` still pass; the fix is additive (only adds a no-op when the day has not flipped).

---

### CR-02: AdjustmentsSection._finish is non-atomic with no rollback, leaves data partial on retry

**Files modified:** `lib/screens/quarterly_review/sections/adjustments_section.dart`
**Commit:** `5503928`
**Applied fix:** Three coordinated changes:
1. Added a `_pendingSnapshot` field (cached `QuarterlySnapshot?`) that is constructed once via `??=` and reused across retries. Because `HiveQuarterlySnapshotRepository.append` is implemented as `_box.put(snapshot.id, snapshot)`, retries with the same snapshot id now *overwrite* the prior row rather than minting a duplicate quarterly history entry.
2. The mutable fields (`goalChunkTotals`, `reflectionAnswers`, `goalPrioritySnapshot`, `archivedGoalIds`) are re-stamped on every attempt so the snapshot always reflects the latest in-memory archive/reorder state.
3. Replaced `catch (_)` with `catch (e, st)` + `debugPrint('AdjustmentsSection._finish failed: $e\n$st')` so silent failures are no longer opaque to support.

**Status:** `fixed: requires human verification` — this fix changes retry semantics. The behavior is verified by Tier 1 (re-read), Tier 2 (analyze + 16 existing quarterly_review tests pass), and Tier 3 fallback, but no test exists that actually exercises a failing `archiveGoal`/`reorderAll`/`append` and asserts retry reuses the same `QuarterlySnapshot.id`. A developer should add a unit test that injects a failing `HiveQuarterlySnapshotRepository` mock and asserts retry reuses the cached id before the phase advances to verification. Suggested test path: `test/screens/quarterly_review_retry_test.dart`.

**Wider scope concern (cross-phase):** The truly atomic fix would also address mid-loop failure of `archiveGoal` (some goals archived, others not) and `reorderAll` (sort order partially applied). Both would require changes to `GoalsNotifier` and the Hive write-batch semantics established in Phase 5, plus an `unarchiveGoal` rollback path that does not exist today. The surgical fix in this commit neutralizes the specific *duplicate-snapshot* defect (the most user-visible corruption) without crossing the Phase 6 boundary. Follow-up issue suggested: "GoalsNotifier: make archiveGoal + reorderAll transactional" — likely Phase 7 or a Phase 5 hotfix.

---

### WR-01: BreathingPulseCta does not react to mid-session accessibility toggle

**Files modified:** `lib/screens/home/home_screen.dart`
**Commit:** `69dc7ba`
**Applied fix:** Mixed `WidgetsBindingObserver` into `_BreathingPulseCtaState`, registered/unregistered in `initState`/`dispose`, and overrode `didChangeAccessibilityFeatures` to call a new `_applyAnimationState()` helper. The same helper now handles initial state, `didUpdateWidget`, and the OS-toggle path — so a mid-session "Reduce motion" toggle stops the controller and pins blur at midpoint in lockstep with the platform without waiting for a parent rebuild. Existing BreathingPulseCta tests still pass.

---

### WR-02: Resolved chunks reveal hover icons at full opacity with disabled taps

**Files modified:** `lib/screens/schedule/widgets/chunk_card.dart`
**Commit:** `c7c7079`
**Applied fix:** Gated the entire `Positioned(AnimatedOpacity(...))` overlay on `!isResolved`. When a chunk is completed or skipped, the mark-complete / mark-skipped IconButtons no longer paint at all — eliminating the "looks tappable but does nothing on click" UX cliff. The three existing `chunk_card_hover_test.dart` tests still pass (they all use the default unresolved work chunk).

---

### WR-03: Hover icons in GoalCard overlap the goal-color swatch and secondary text

**Files modified:** `lib/screens/goals/widgets/goal_card.dart`
**Commit:** `d7e8777`
**Applied fix:** Conditioned the 16dp goal-color `Container` swatch on `showHoverIcons && _hovered`, swapping it for a `SizedBox(width: 16, height: 16)` of identical dimensions when the hover overlay would otherwise paint on top of it. Layout stays stable (no jank from a vanishing widget); the swatch simply fades to invisible as the action icons fade in. All `goal_card_hover_test.dart` and `goal_card_drag_handle_test.dart` tests still pass.

---

### WR-05: main.dart does not guard setupDesktopWindow() against transient failures

**Files modified:** `lib/main.dart`
**Commit:** `e3ad129`
**Applied fix:** Wrapped `await setupDesktopWindow();` in `try/catch (e, st)` with a `debugPrint` log of the exception, so a window_manager plugin failure no longer hard-bricks startup. `debugPrint` is re-exported via `package:flutter/material.dart`, so no new import was needed.

---

### WR-06: ThemeNotifier.init() does not guard against repository failure

**Files modified:** `lib/providers/theme_notifier.dart`
**Commit:** `5a17415`
**Applied fix:** Wrapped `_repo.getSettings()` and the subsequent state assignment in `try/catch` inside `init()`. On a repository failure (e.g., corrupted Hive, partial migration), `_moodSeed` and `_lastMoodSetYmd` are reset to defaults (`null` for both — the curious pre-checkin state), the failure is logged via `debugPrint`, and the lifecycle observer + ticker still register normally so the rest of the boot sequence runs. Combined with WR-05, a single piece of bad persisted state can no longer hard-brick the app on launch.

---

### WR-07: resetToCurious does not clear _lastMoodSetYmd or persist it

**Files modified:** `lib/providers/theme_notifier.dart`
**Commit:** `d051c9c`
**Applied fix:** `resetToCurious()` now also sets `_lastMoodSetYmd = null` (in-memory) and `s.lastMoodSetYmdInt = null` (Hive) so the persisted "last mood event" timestamp no longer lags behind the actual mood state after a reset. Existing ThemeNotifier tests still pass.

---

### WR-08: Migration runner does not validate currentSchemaVersion bounds

**Files modified:** `lib/data/database/migrations.dart`
**Commit:** `a7727a4`
**Applied fix:** Added an `assert(storedVersion <= currentSchemaVersion, ...)` to surface a rolled-back-app condition loudly in debug, plus an `if (storedVersion > currentSchemaVersion) return;` early-return so release builds *skip* the `prefs.setInt('schemaVersion', currentSchemaVersion)` downgrade-write that would otherwise corrupt the schema cursor. A future re-upgrade now sees the correct (newer) stored version and runs the right forward migrations.

---

### WR-09: ResponsiveShell._goBranch active-tab pop semantics are untested

**Files modified:** `test/screens/responsive_layout_test.dart`
**Commit:** `e3d84b8`
**Applied fix:** Added a sub-route `/a/sub` under the existing test router's branch A, then added a new test that pushes `/a/sub` via `router.go(...)`, taps the active "Home" `NavigationBar` destination, and asserts the tree rendered "Branch A" (root, not "Branch A sub-route"). This is the WR-09 regression guard. The test suite now has 90 passing tests (up from 89 baseline).

## Skipped Issues

### WR-04: Touch-Windows / touch-ChromeOS users lose delete + edit affordance

**File:** `lib/screens/commitments/commitments_screen.dart:198-200` (and `lib/screens/goals/widgets/goal_card.dart`, `lib/screens/schedule/widgets/chunk_card.dart`)
**Reason:** skipped: suggested fix is incorrect for the stated scope and breaks an existing test.

**Detail:**
The REVIEW.md suggested patch reads:

```dart
opacity: _hovered ? 1.0 : (isMobileTouch ? 1.0 : 0.0),
```

Two problems with applying this mechanically:

1. **Does not actually fix the reported scope.** The reported issue is that *touch-Windows* and *touch-ChromeOS* users have no affordance — those platforms report `TargetPlatform.windows` / `TargetPlatform.linux`, so `isMobileTouch` is *false* and the suggested fix still leaves opacity at 0. The fix only changes behavior on `android` / `iOS`, where opacity 0 was already correct (the design relies on `Dismissible` swipe gestures as the touch affordance on Android/iOS, per the `_HoverableChunkContent` doc comment and Phase 4 Pitfall 5).
2. **Breaks the existing chunk_card test.** `test/screens/chunk_card_hover_test.dart` asserts that on a touch drag, hover icons remain at opacity 0 ("touch drag does NOT reveal hover icons (RESEARCH.md Pitfall 5)"). The default `defaultTargetPlatform` under test is `android` → `isMobileTouch = true` → the patched opacity would be 1.0, failing this test.

**Original issue:** Touch-Windows and touch-ChromeOS users have no way to delete a commitment, archive a goal, or skip a chunk because the action icons are gated on hover events that touch-only pointer streams never fire.

**Recommended follow-up (out of scope for surgical fix iteration):**
- Detect *input modality* (touch vs pointer) rather than platform. Possible signals: `PointerDeviceKind` from a wrapping `Listener`, `MediaQuery.of(context).gestureSettings`, or a top-level `InputModalityNotifier` provider that flips on first touch/mouse event.
- Alternatively, expose a long-press secondary menu for action icons that works regardless of pointer kind.
- Update `RESEARCH.md` Pitfall 5 to acknowledge the touch-Windows / touch-ChromeOS edge case so a future patch is not blocked by the test in its current shape.

This is a design-level fix that warrants its own RESEARCH/PATTERNS update and is too large for the `--fix` iteration to apply correctly without making the situation worse.

---

## Verification Run

After all fixes applied, the following commands were run from the worktree:

```
flutter test         → 90 passed (one new test added; 89 baseline preserved)
flutter analyze      → No issues found
```

Per-fix verification (Tier 1 re-read + Tier 2 analyze + Tier 2 targeted test runs) is documented in each "Applied fix" block.

---

_Fixed: 2026-05-14T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
