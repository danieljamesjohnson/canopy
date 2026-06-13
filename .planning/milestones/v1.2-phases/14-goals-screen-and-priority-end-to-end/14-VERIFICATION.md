---
phase: 14-goals-screen-and-priority-end-to-end
verified: 2026-06-13T00:00:00Z
status: human_needed
score: 7/7
overrides_applied: 0
human_verification:
  - test: "Open Goals screen with at least two goals; confirm the 'Your goals' heading and 'Drag to prioritize. Tap to edit.' subhead are readable and make the screen's purpose as a prioritization view immediately clear — not just present, but legible and purposeful."
    expected: "Heading reads naturally as an introduction to a prioritization screen. Subhead copy is visible at bodySmall, onSurfaceVariant color against the surface background."
    why_human: "Text presence is tested programmatically (heading test passes). Visual legibility, color contrast, and whether the copy actually communicates purpose to a first-time user cannot be verified by grep or widget tests."
  - test: "View a goal card for a High-priority goal (priorityWeight=0.75) and a Low-priority goal (priorityWeight=0.25). Confirm the chips are visually distinct from each other and from a Normal goal card (no chip), and read clearly at their respective sizes."
    expected: "High chip: up arrow + 'High' label on primaryContainer background. Low chip: down arrow + 'Low' label on surfaceContainerHighest background. Normal: no chip. The three states are unambiguously different at a glance."
    why_human: "Chip code, icons, and colors are verified programmatically. Whether the color contrast between the two chip backgrounds is perceptually distinct enough, and whether the 12sp labelMedium label is readable on each background, is a visual judgment."
  - test: "On a mobile device (Android or iOS), attempt to drag a goal card by pressing and holding the drag_indicator handle. Confirm the drag starts and the goal can be reordered."
    expected: "Drag begins after a short hold delay (ReorderableDelayedDragStartListener). The card lifts and the list reorders. After release, the new order is reflected immediately."
    why_human: "The ReorderableDelayedDragStartListener wrapping and Icons.drag_indicator presence are code-verified. That the drag actually initiates correctly on a real touch device requires physical interaction — widget tests cannot simulate delayed touch gestures for drag-and-drop."
  - test: "On the Goals screen, set one goal to High priority and another to Low priority, then regenerate the schedule. Navigate to the schedule and confirm: (a) both goals show their respective High/Low badge on their chunk cards; (b) the High-priority goal's chunks appear earlier in the day or in greater count than the Low-priority goal."
    expected: "Priority badge visible on chunk cards in Schedule screen and on the active chunk card in Home screen. The schedule order/count difference between High and Low goals is observable without inspecting code."
    why_human: "The engine priority logic is deterministically tested (3 passing engine tests prove the math). Badge threading is code-verified (ScheduleScreen → SwipeableChunkCard → ChunkCard, ActiveChunkCard internal lookup). The end-to-end user flow — setting priority in the goal form, regenerating the schedule, and observing the change — requires a running app."
---

# Phase 14: Goals Screen and Priority End-to-End — Verification Report

**Phase Goal:** The Goals screen reads as a prioritization view with a legible priority visual language, and changing a goal's priority produces a visibly different schedule.
**Verified:** 2026-06-13
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The Goals screen shows a "Your goals" heading + "Drag to prioritize. Tap to edit." subhead when goals exist | VERIFIED | `goals_screen.dart` lines 109–132: `SliverToBoxAdapter` with `Text('Your goals', titleMedium w600)` + `Text('Drag to prioritize. Tap to edit.', bodySmall onSurfaceVariant)` in the non-empty branch. `goals_screen_heading_test.dart` passes (confirmed by test run). |
| 2 | The reorder affordance is `Icons.drag_indicator` (six-dot grid) visible on BOTH desktop and mobile (not `Icons.drag_handle`, not hidden on mobile) | VERIFIED | `goals_screen.dart` lines 214–253: both `isMobileTouch` and desktop branches use `Icons.drag_indicator`. Mobile branch is `ReorderableDelayedDragStartListener` → always-visible `Icon(Icons.drag_indicator, size:20)`. Desktop branch: `Tooltip` → `ReorderableDelayedDragStartListener` → `SizedBox(44×44)` → `AnimatedOpacity(0.6)` → `Icon(Icons.drag_indicator)`. Updated `goal_card_drag_handle_test.dart` passes Android, iOS, and macOS cases — all `findsOneWidget`. |
| 3 | Drag-reordering a goal writes `priorityWeight` via `reorderAllWithPriority`, not just `sortOrder` | VERIFIED | `goals_screen.dart` lines 258–264: `onReorderItem` closure calls `_buildFullOrderedIds(notifier, type, reorderedGroup)` then `await notifier.reorderAllWithPriority(allOrdered)`. No call to `notifier.reorder()`. `_buildFullOrderedIds` method exists at lines 272–287, reconstructing the flat ID list in `timeTarget → outcome → habit` order. |
| 4 | A goal card shows a "High" chip (up arrow) for `priorityWeight 0.75` and a "Low" chip (down arrow) for `0.25`, and NO chip for `0.5`/null | VERIFIED | `goal_card.dart` lines 78–79: `final pw = goal.priorityWeight ?? 0.5; final showPriorityChip = pw >= 0.75 \|\| pw <= 0.25;`. `_PriorityChip` widget (lines 230–281): `>= 0.75 → Icons.arrow_upward + primaryContainer + 'High'`; `<= 0.25 → Icons.arrow_downward + surfaceContainerHighest + 'Low'`; else `SizedBox.shrink()`. All four `goal_card_priority_chip_test.dart` cases pass (confirmed by test run). |
| 5 | A high-priority habit (0.75) is scheduled before a low-priority habit (0.25) when both are due | VERIFIED | `schedule_generator.dart` lines 235–241: `habitGoals` pre-filtered and sorted descending by `priorityWeight ?? 0.5`. Engine test "Step 2: high-priority habit is scheduled before low-priority habit" passes (confirmed by test run — inputs low first, asserts `workChunks.first.goalId == highHabit.id`). |
| 6 | A high-priority time-target goal with equal remaining hours is scheduled before a low-priority one, and gets at least as many chunks under a shared cap | VERIFIED | `schedule_generator.dart` lines 316–320: composite score `remainingHours × (priorityWeight ?? 0.5)` sorts time-target goals. Two engine tests pass: "Step 4: high-priority time-target goal with equal remaining hours gets chunk before low-priority" (`greaterThan` assertion on first chunk); "Step 4: high-priority goal gets at least as many chunks as low-priority under shared cap" (`highCount greaterThan lowCount` with cap=6, demand=8). These are genuinely non-trivial tests — reversing the sort would fail both. |
| 7 | A schedule chunk card shows a "High" badge for `goalPriorityWeight 0.75` and a "Low" badge for `0.25`, and NO badge for `0.5`/null; commitment chunks (goalId == null) never show a badge | VERIFIED | `chunk_card.dart` lines 248–254: `if (goalPriorityWeight != null && goalPriorityWeight != 0.5)` guard with `_PriorityChip` (lines 333–384). `active_chunk_card.dart` lines 38–43: `_lookupGoalPriorityWeight` returns null for `chunk.goalId == null`. `schedule_screen.dart` lines 170, 207, 236–241: `_lookupGoalPriorityWeight` wired to both `SwipeableChunkCard` and skipped `ChunkCard` calls. All four `chunk_card_priority_badge_test.dart` cases pass (confirmed by test run). |

**Score:** 7/7 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/screens/goals/widgets/goal_card.dart` | `_PriorityChip` private widget + chip in secondary row | VERIFIED | `_PriorityChip` class at line 230. Chip integrated at lines 161–178 via `showPriorityChip` guard. Display-only — no tap handlers. |
| `lib/screens/goals/goals_screen.dart` | Heading sliver, `drag_indicator` handle, `_buildFullOrderedIds`, `reorderAllWithPriority` call | VERIFIED | Heading sliver at lines 109–132. Both mobile and desktop handles use `Icons.drag_indicator`. `_buildFullOrderedIds` at line 272. `reorderAllWithPriority` called at line 263. |
| `lib/services/schedule_generator.dart` | Step 2 habit priority sort + Step 4 composite score (remainingHours × priorityWeight) | VERIFIED | Step 2 sort at lines 235–241. Step 4 composite score `_remainingHours(g, ...) * (g.priorityWeight ?? 0.5)` at lines 316–317. `_demandForTimeTarget` and `_remainingHours` unchanged. |
| `lib/screens/schedule/widgets/chunk_card.dart` | `goalPriorityWeight` param + `_PriorityChip` badge | VERIFIED | `goalPriorityWeight` in both `ChunkCard` (line 17) and `_WorkChunkContent` (line 135) constructors. `_PriorityChip` at line 333. Badge inserted at lines 248–254. |
| `lib/screens/home/widgets/active_chunk_card.dart` | `_lookupGoalPriorityWeight` + priority badge | VERIFIED | `_lookupGoalPriorityWeight` method at lines 38–43. Badge at lines 143–146. File-private `_PriorityChip` at line 198. |
| `test/screens/goal_card_priority_chip_test.dart` | Chip render tests at 0.75/0.5/0.25/null | VERIFIED | 4 `testWidgets` cases present and passing. |
| `test/screens/goals_screen_heading_test.dart` | Heading text test | VERIFIED | 1 `testWidgets` case with `_InMemoryGoalRepository` pattern, passing. |
| `test/services/schedule_generator_test.dart` | Three engine behavioral tests for criteria 3 & 4 | VERIFIED | Tests at lines 925–1018: "Step 2: high-priority habit...", "Step 4: high-priority time-target...equal remaining hours...", "Step 4: high-priority goal gets at least as many chunks...shared cap". All three pass and are genuinely non-trivial (reversing priority sort would fail them). |
| `test/screens/chunk_card_priority_badge_test.dart` | Badge render tests at 0.75/0.25/0.5/null | VERIFIED | 4 `testWidgets` cases present and passing. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `goals_screen.dart` `onReorderItem` | `GoalsNotifier.reorderAllWithPriority` | `_buildFullOrderedIds` then `reorderAllWithPriority` call | VERIFIED | Line 263: `await notifier.reorderAllWithPriority(allOrdered)`. Pattern `reorderAllWithPriority` confirmed present. |
| `goal_card.dart` | `goal.priorityWeight` | `_PriorityChip(priorityWeight: goal.priorityWeight ?? 0.5)` | VERIFIED | Line 173: `_PriorityChip(priorityWeight: goal.priorityWeight ?? 0.5)`. Pattern `_PriorityChip` confirmed present. |
| `schedule_screen.dart` | `ChunkCard / SwipeableChunkCard goalPriorityWeight` | `_lookupGoalPriorityWeight(context, chunk)` passed to card | VERIFIED | Lines 170, 207: `goalPriorityWeight: _lookupGoalPriorityWeight(context, chunk)`. Method at lines 236–241. Pattern confirmed. |
| `schedule_generator.dart` | `goal.priorityWeight` | Step 2 habit sort + Step 4 composite score | VERIFIED | Line 239: `(b.priorityWeight ?? 0.5).compareTo(...)`. Line 317: `_remainingHours(g, ...) * (g.priorityWeight ?? 0.5)`. Both patterns confirmed. |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `goal_card.dart` `_PriorityChip` | `goal.priorityWeight` | `Goal` model from `GoalsNotifier.goals` (Hive-backed) | Yes — reads from persisted Hive field; `reorderAllWithPriority` writes it on drag | FLOWING |
| `chunk_card.dart` `_PriorityChip` | `goalPriorityWeight` | `ScheduleScreen._lookupGoalPriorityWeight` → `GoalsNotifier.goals` | Yes — in-memory lookup from already-loaded goals; null for commitment chunks | FLOWING |
| `active_chunk_card.dart` `_PriorityChip` | `goalPriorityWeight` | Internal `_lookupGoalPriorityWeight(context)` → `GoalsNotifier.goals` | Yes — same pattern as `_lookupGoalColor` / `_lookupGoalName`, already exercised by existing Home screen | FLOWING |
| `schedule_generator.dart` Step 2 sort | `habitGoals` sorted by `priorityWeight` | `Goal.priorityWeight` field (Hive-backed, set by goal form SegmentedButton) | Yes — sort produces different allocation order when weights differ; proven by engine tests | FLOWING |
| `schedule_generator.dart` Step 4 sort | `timeTargetGoals` sorted by composite score | `_remainingHours × priorityWeight` — both real Hive-persisted fields | Yes — composite score formula drives a different ordering than tiebreaker; proven by engine tests with non-trivial assertions | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Step 2: high-priority habit scheduled before low-priority | `flutter test test/services/schedule_generator_test.dart` — test "Step 2: high-priority habit is scheduled before low-priority habit" | +25: passed | PASS |
| Step 4: equal-hours high-priority TT goal gets first chunk | Same run — test "Step 4: high-priority time-target goal with equal remaining hours gets chunk before low-priority" | +26: passed | PASS |
| Step 4: high-priority TT goal gets more chunks under cap | Same run — test "Step 4: high-priority goal gets at least as many chunks as low-priority under shared cap" | +27: passed | PASS |
| GoalCard priority chip (High/Normal/Low/null) | `flutter test test/screens/goal_card_priority_chip_test.dart` | 4/4 passed | PASS |
| ChunkCard priority badge (High/Low/null/Normal) | `flutter test test/screens/chunk_card_priority_badge_test.dart` | 4/4 passed | PASS |
| Goals screen heading when goals exist | `flutter test test/screens/goals_screen_heading_test.dart` | 1/1 passed | PASS |
| drag_indicator visible on Android/iOS/macOS | `flutter test test/screens/goal_card_drag_handle_test.dart` | 3/3 passed | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| GOALS-01 | 14-01-PLAN | Goals screen makes purpose explicit as prioritization view with obvious reorder affordance | SATISFIED | "Your goals" heading + subhead present in code (lines 109–132 of `goals_screen.dart`); `Icons.drag_indicator` visible on all platforms (heading test + drag handle test pass) |
| GOALS-02 | 14-01-PLAN, 14-02-PLAN | Goal's priority (Low/Normal/High) has clear, consistent visual language across Goals screen and schedule cards | SATISFIED | `_PriorityChip` implemented with identical tier logic (>= 0.75 → High, <= 0.25 → Low, else nothing) in `goal_card.dart`, `chunk_card.dart`, and `active_chunk_card.dart`; all chip/badge tests pass; typography consistent (all three files use `labelMedium`) |
| PRIORITY-01 | 14-02-PLAN | Goal priority measurably influences schedule generation beyond a tiebreaker | SATISFIED | Step 2 pre-sorts habits by `priorityWeight` descending; Step 4 uses composite score `remainingHours × priorityWeight`; three deterministic engine tests prove criteria 3 (elevate → earlier/more) and 4 (lower → fewer/later) — tests are non-trivial (reversing sort causes failure) |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | — | — | — | Debt-marker scan (`TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, `PLACEHOLDER`) across all 5 modified source files returned zero results. |

**SUMMARY inaccuracy noted (informational only):** `14-02-SUMMARY.md` states `_PriorityChip` uses `textTheme.labelSmall`. The actual code in `chunk_card.dart` (line 375), `active_chunk_card.dart` (line 240), and `goal_card.dart` (line 272) all use `textTheme.labelMedium`. The code is correct and consistent with the UI-SPEC; the SUMMARY documentation is wrong. No impact on goal achievement.

---

### Human Verification Required

#### 1. Goals screen heading legibility and purpose communication

**Test:** Open the Goals screen with at least two goals and read the heading area without prior knowledge of the screen's purpose.
**Expected:** "Your goals" heading and "Drag to prioritize. Tap to edit." subhead are immediately legible and make the screen's purpose as a prioritization view clear to a first-time user — not just technically present, but communicative.
**Why human:** Text presence is proven by widget test. Whether the copy actually communicates purpose, and whether the bodySmall onSurfaceVariant text has sufficient contrast against the surface background, is a visual and UX judgment.

#### 2. Priority chip visual distinctness on goal cards

**Test:** View goal cards for a High-priority, Normal (no chip), and Low-priority goal side by side.
**Expected:** The three states are unambiguously different at a glance. High chip (primaryContainer background + up arrow) vs Low chip (surfaceContainerHighest background + down arrow) vs no chip are perceptually distinct. The 12sp labelMedium chip labels are readable.
**Why human:** Chip code, icons, and tier logic are code-verified. Whether the two chip background colors are perceptually distinct from each other and from the card surface in the app's actual color scheme is a visual judgment that depends on the rendered theme.

#### 3. Drag-to-reorder affordance on mobile

**Test:** On a physical Android or iOS device, press and hold the drag_indicator icon on a goal card and attempt to reorder it.
**Expected:** Drag begins after a short delay (ReorderableDelayedDragStartListener behavior). The card lifts and the list reorders. The handle is obviously a drag handle and its purpose is immediately apparent.
**Why human:** `ReorderableDelayedDragStartListener` wrapping and `Icons.drag_indicator` presence are code-verified and the drag handle test passes. Whether the drag gesture actually initiates and feels natural on a real touch device, and whether the handle icon reads as draggable to a user who has not been told, requires physical interaction.

#### 4. End-to-end priority → schedule change observable in the running app

**Test:** Set a goal to High priority via the goal form; set another goal of the same type to Low priority. Tap the check-in / regenerate schedule trigger. Navigate to the Schedule screen.
**Expected:** (a) Both goals show their High / Low badge on their chunk cards in the schedule. (b) The High-priority goal's chunks appear earlier in the day or in greater count than the Low-priority goal's chunks — the difference is observable without inspecting code or logs.
**Why human:** Engine priority logic is deterministically proven by 3 passing engine tests. Badge threading is code-verified end-to-end (ScheduleScreen → SwipeableChunkCard → ChunkCard; ActiveChunkCard internal lookup). The full user flow — goal form priority change, schedule regeneration, visual diff on the schedule screen — requires a running app with real data.

---

### Gaps Summary

No gaps. All 7 must-have truths are VERIFIED by direct code inspection and passing test runs. The 4 human verification items are visual/interactive judgments that automated checks cannot substitute for.

---

_Verified: 2026-06-13_
_Verifier: Claude (gsd-verifier)_
