---
phase: 13-check-in-and-goal-form
plan: "01"
subsystem: checkin-screen
tags: [contrast, accessibility, hover, pressed, state-machine, lighter-day, wcag]
dependency_graph:
  requires: []
  provides: [checkin-contrast-fix, lighter-day-decision-screen]
  affects: [lib/screens/schedule/checkin_screen.dart]
tech_stack:
  added: []
  patterns:
    - luminance-adaptive foreground via Color.computeLuminance()
    - MouseRegion + AnimatedContainer for hover/pressed states
    - AnimatedSwitcher three-state machine with ValueKey
    - AnimatedScale 0.97 pressed feedback on choice cards
    - _LighterDayCard private StatefulWidget
key_files:
  created:
    - test/screens/checkin_screen_test.dart
    - test/screens/checkin_screen_widget_test.dart
  modified:
    - lib/screens/schedule/checkin_screen.dart
decisions:
  - _onBgColor uses 0.35 luminance threshold; mood 4 (#7AAF6A, luminance=0.3584) measured above threshold so both moods 4 and 5 get dark foreground
  - Inline 'Want a lighter day?' Switch removed entirely; replaced by post-commit decision screen
  - _generate() uses lighterDay:false as provisional; decision screen drives _commitAndProceed for final value
  - StadiumBorder replaces BorderRadius.circular(30) on Let's go button for spinner-swap compatibility
  - onPressed non-null during generation (no-op lambda) avoids invisible disabled foreground on amber background
  - _buildDecisionBody uses ConstrainedBox(maxWidth:480) centered for >=720dp desktop case
metrics:
  duration: "4 minutes"
  completed: "2026-06-13"
  tasks_completed: 3
  files_modified: 3
---

# Phase 13 Plan 01: Check-in Contrast and Lighter-Day Decision Flow Summary

Reworked `checkin_screen.dart` to fix WCAG contrast failures at all five mood levels (CHECKIN-01) and replaced the ambiguous inline lighter-day Switch with a post-commit two-card decision screen (CHECKIN-02). All automated tests pass; flutter analyze is clean.

## What Was Built

**CHECKIN-01: Luminance-adaptive contrast + emoji hover/pressed states**

Added `_onBgColor` getter that computes `_backgroundColor.computeLuminance()` and returns `Color(0xFF1A1A1A)` (near-black) when luminance > 0.35, else `Colors.white`. This replaces all hardcoded `Colors.white` foreground references in the AppBar title, AppBar iconTheme, and `_buildCheckinBody`. Mood 5 (#E8C547 amber, luminance ≈ 0.55) and mood 4 (#7AAF6A sage, luminance ≈ 0.36) both exceed 0.35 and now receive dark foreground — eliminating the amber ~1.9:1 WCAG AA failure.

Added `_resolveEmojiBackground(int mood, bool isSelected)` helper that uses the same luminance-adaptive base to compute hover (alpha 26 unselected, 64 selected) and pressed (alpha 77 selected) overlay colors. Wrapped each emoji `GestureDetector` in `MouseRegion` with `onEnter`/`onExit`, added `onTapDown`/`onTapUp`/`onTapCancel` for pressed visual feedback, and changed `AnimatedContainer` duration to 120ms (hover) per UI-SPEC.

Updated "Let's go" `ElevatedButton` to use `backgroundColor: _onBgColor`, `foregroundColor: _backgroundColor`, `StadiumBorder()`, and a non-null no-op `onPressed` during generation (avoiding the invisible disabled foreground on amber backgrounds — Pitfall 6).

**CHECKIN-02: Lighter-day post-commit decision screen**

Removed `bool _lighterDay = true` field and the inline "Want a lighter day?" `Row` + `Switch` block from `_buildCheckinBody`. Added three state fields: `bool _generationDone`, `Map<int, bool> _hoveredMoods`, `Map<int, bool> _pressedMoods`.

Restructured `_generate()` to use `lighterDay: false` (provisional) and set `_generationDone = true` on success (instead of `_scheduleGenerated = true`). Added error snackbar ("Something went wrong. Please try again.") in catch block, guarded by `if (mounted)`.

Added `_commitAndProceed({required bool lighterDay})`: regenerates with `lighterDay: true` only on the lighter-day path; always advances to acknowledgment via `_scheduleGenerated = true`.

Updated `AnimatedSwitcher` to three-state ternary: `_scheduleGenerated ? acknowledgment : _generationDone ? decision : checkin`. Each body method uses its unique `ValueKey` (`'checkin'`, `'decision'`, `'acknowledgment'`).

Added `_buildDecisionBody(BuildContext context)` with heading "Ready to start?", subhead "Choose your pace for today", two `_LighterDayCard` instances ("Full day" and "Lighter day"), and a "Go back" `TextButton` that resets `_generationDone = false`. Desktop adaptive: wrapped in `ConstrainedBox(maxWidth: 480)` centered.

Added `_LighterDayCard` private `StatefulWidget` with `MouseRegion` hover, `GestureDetector` tap (setState first, then onTap per Pitfall 5), `AnimatedScale` 0.97 pressed feedback, and `AnimatedContainer` border/fill hover states.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: CHECKIN-01 contrast + hover | d4e1fc8 | lib/screens/schedule/checkin_screen.dart, test/screens/checkin_screen_test.dart |
| Task 2: CHECKIN-02 widget tests | 8d7865e | test/screens/checkin_screen_widget_test.dart |
| Task 3: Checkpoint deferred | (auto-approved, no commit) | — |

## Test Results

- `flutter test test/screens/checkin_screen_test.dart` — 5/5 pass (unit luminance assertions)
- `flutter test test/screens/checkin_screen_widget_test.dart` — 4/4 pass (state machine)
- `flutter test` (full suite) — 194/194 pass (no regressions)
- `flutter analyze` — 0 issues on all modified/created files

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Mood 4 luminance measured above threshold (opposite of RESEARCH estimate)**
- **Found during:** Task 1 unit test (RED phase)
- **Issue:** RESEARCH.md estimated mood 4 (#7AAF6A) luminance as "≈ 0.22 — falls below 0.35". Actual Flutter SDK `computeLuminance()` returned 0.3584 — above the threshold. The plan directive was to "assert whichever side of 0.35 it actually falls on."
- **Fix:** Updated unit test assertion to `greaterThan(0.35)` with documentation that both moods 4 and 5 receive dark foreground. The `_onBgColor` implementation (`luminance > 0.35 → Color(0xFF1A1A1A)`) was already correct; only the test expected value needed updating.
- **Files modified:** test/screens/checkin_screen_test.dart
- **Commit:** d4e1fc8

**2. [Rule 1 - Bug] Unused import in checkin_screen_test.dart**
- **Found during:** Task 1 flutter analyze
- **Issue:** `import 'package:flutter/material.dart'` was unused (Color values accessed via ThemeNotifier, which re-exports them).
- **Fix:** Removed unused import.
- **Files modified:** test/screens/checkin_screen_test.dart
- **Commit:** d4e1fc8

### Task 3: Human Visual Verification — Deferred

Per checkpoint handling instructions, Task 3 (manual visual verification) is auto-approved with the following items outstanding for human validation at the phase-level gate:

1. **Mood 5 contrast (amber):** Confirm AppBar title, "Let's go" label, and body text are dark and clearly readable against the amber (#E8C547) background — no white wash.
2. **Mood 4 contrast (sage):** Confirm legibility at dark foreground on sage (#7AAF6A).
3. **Moods 1-3 contrast:** Confirm white text on dark blue/teal backgrounds.
4. **Emoji hover highlight:** On desktop, verify each emoji target shows a subtle highlight on mouse enter.
5. **Emoji pressed state:** Verify pressed alpha increase (51 → 77) on tap-down.
6. **"Let's go" pill shape:** Verify `StadiumBorder` renders as a proper pill.
7. **Decision screen flow:** Tap mood → "Let's go" → verify no inline toggle before this point → decision screen slides in with "Ready to start?", "Full day", "Lighter day", "Go back".
8. **"Go back" reset:** Returns to mood + "Let's go" state.
9. **"Lighter day" flow:** Regenerates and shows acknowledgment.
10. **Card pressed scale:** Decision cards scale to 0.97 on press-down.

These checks require a running app on a desktop target (`flutter run -d linux` or equivalent).

## Known Stubs

None. All decision screen elements are fully wired. The `_commitAndProceed` method correctly routes to `generateToday(lighterDay: true)` or reuses the existing schedule.

## Threat Flags

No new threat surface introduced. All threat mitigations from the plan's `<threat_model>` are applied:
- T-13-01: `if (_selectedMood == null || _isGenerating) return` guard in `_generate()` — present
- T-13-02: All post-`await` setState calls guarded by `if (mounted)` in `_generate()` and `_commitAndProceed()` — present

## Self-Check: PASSED

Files created/modified exist:
- lib/screens/schedule/checkin_screen.dart — present
- test/screens/checkin_screen_test.dart — present
- test/screens/checkin_screen_widget_test.dart — present

Commits exist:
- d4e1fc8 — confirmed in git log
- 8d7865e — confirmed in git log
