---
status: complete
phase: 13-check-in-and-goal-form
source: [13-VERIFICATION.md]
started: 2026-06-13
updated: 2026-06-14T19:50:21Z
---

## Current Test

number: 8
name: Goal form Priority + Save reachability
expected: |
  On a phone-class viewport with the keyboard up, opening the Add goal sheet (time-target/habit
  type) shows the Priority Low/Normal/High control AND the "Add goal" button without in-sheet
  scrolling. Selected type card shows both a colored border and a bold title. Edit mode keeps
  Archive/Cancel/Save reachable.
awaiting: none — all 8 scenarios run (2 pass, 3 issues, 3 obsolete). See Gaps.

## Tests

### 1. Mood 5 amber contrast
expected: Mood 5 (amber #E8C547) renders dark text/controls, clearly readable — no white-on-amber wash.
result: pass (verified 2026-06-14)

### 2. Mood 4 sage contrast + moods 1-3
expected: Mood 4 (sage #7AAF6A) renders dark text and is legible; moods 1-3 render white text on the darker blues/teal.
result: pass (verified 2026-06-14)

### 3. Emoji hover highlight (desktop/web)
expected: Moving the pointer over an unselected emoji circle shows a subtle highlight; moving off clears it.
result: issue — no perceptible hover on desktop. Highlight is white@alpha26 (~10%); before any mood is selected `luminance` defaults to 0.0 so base is forced white → invisible on the light pre-selection background. (verified 2026-06-14) → see G1.

### 4. Emoji pressed state
expected: Press-and-hold an emoji shows a stronger pressed fill (alpha increase) before release.
result: issue — no pressed fill. The unselected branch of _resolveEmojiBackground ignores isPressed (`base.withAlpha(isHovered ? 26 : 0)`), and selection only fires on onTap (release), so the press-and-hold window is always unselected → no feedback. (verified 2026-06-14) → see G1.

### 5. Lighter-day decision screen flow
expected: No inline "Want a lighter day?" toggle exists pre-commit. After tapping a mood then "Let's go", a decision screen slides in with heading "Ready to start?", two cards (Full day / Lighter day), and a "Go back" link.
result: obsolete — decision screen REMOVED in v1.3 (commit 70a9f8b "feat(checkin): drop pace prompt"). Flow now goes mood → "Let's go" → full-plan generation directly (lighterDay hardcoded false). Scenario superseded, not testable. (2026-06-14)

### 6. Go back resets to mood selection
expected: Tapping "Go back" on the decision screen returns to the mood + "Let's go" state; re-running and tapping "Lighter day" regenerates the schedule and shows the acknowledgment ("Swipe up to begin").
result: obsolete — depends on the removed decision screen (see #5). Superseded by v1.3 pace-prompt removal. (2026-06-14)

### 7. Decision card press scale
expected: Pressing a decision card briefly scales it down (~0.97) on press.
result: obsolete — decision cards no longer exist (see #5). (2026-06-14)

### 8. Goal form Priority + Save reachability
expected: On a phone-class viewport with the keyboard up, opening the Add goal sheet (time-target/habit type) shows the Priority Low/Normal/High control AND the "Add goal" button without in-sheet scrolling. Selected type card shows both a colored border and a bold title. Edit mode keeps Archive/Cancel/Save reachable.
result: issue — the goal form is a phone bottom sheet (showModalBottomSheet + DraggableScrollableSheet at 0.6) shown UNCONDITIONALLY, with no desktop/wide-viewport layout. On desktop/web it renders the same cramped sheet (identical with device emulation on or off); the 3rd type card ("daily habit") clips at the bottom and Priority + Add goal fall below the fold → require scrolling, contrary to GOALFORM-01 intent. User: "trying to be a mobile screen not a PC screen." (verified 2026-06-14) → see G3.

## Summary

total: 8
passed: 2
issues: 3
pending: 0
skipped: 3
blocked: 0

## Gaps

### G1 — Check-in emoji hover + pressed feedback not visible (CHECKIN-01, scenarios 3 & 4)
Both states are wired but invisible in practice, same method `_resolveEmojiBackground`
(lib/screens/schedule/checkin_screen.dart ~L79):
- Hover: unselected highlight is `base.withAlpha(26)` (~10%). Worse, when no mood is
  selected yet `luminance` defaults to `0.0` → `base` forced to white → white@10% on the
  light pre-selection background = invisible. Fix: compute luminance from the actual
  current screen background even pre-selection, and/or raise the hover alpha so it's
  perceptible on a light background.
- Pressed: the unselected branch `base.withAlpha(isHovered ? 26 : 0)` ignores `isPressed`,
  and selection fires on `onTap` (release) — so the press-and-hold window is always on an
  unselected emoji and shows no pressed fill. Fix: honor `isPressed` in the unselected
  branch too.
Captured: .planning/todos/pending/2026-06-14-checkin-emoji-hover-pressed.md

### G2 — Scenarios 5-7 obsolete (lighter-day decision screen removed in v1.3)
The post-commit lighter-day decision screen (built in 8d7865e) was removed in
70a9f8b "feat(checkin): drop pace prompt". The check-in now goes mood → "Let's go"
→ full-plan generation, with `lighterDay: false` hardcoded in `_generate`
(checkin_screen.dart ~L110). Scenarios 5/6/7 test that removed UI and are no longer
applicable. No action — intended product change. (If the v1.2 UAT is ever revived,
delete these three scenarios.)

### G3 — Goal form is a phone bottom sheet, no desktop layout (GOALFORM-01, scenario 8)
`_openAddSheet` / `_openEditSheet` (goals_screen.dart:28-62) call
`showModalBottomSheet` + `DraggableScrollableSheet(initialChildSize: 0.6)`
unconditionally — no MediaQuery width branch. On desktop/web (the primary dogfood
surface) it renders the same cramped 60%-height draggable sheet a phone gets;
identical with device emulation on or off. At 0.6 the GoalTypePicker's 3rd card
clips at the bottom and Priority + the Add/Save button fall below the fold,
requiring scroll. Recommendation: branch on viewport — centered `Dialog` with a
constrained max width (~480-560px) and natural height on wide screens; keep the
bottom sheet only on narrow/phone widths. Likely applies to other modals too
(audit commitment/edit sheets). Captured:
.planning/todos/pending/2026-06-14-goal-form-desktop-layout.md
