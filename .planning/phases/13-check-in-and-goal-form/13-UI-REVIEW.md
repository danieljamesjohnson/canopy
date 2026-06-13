# Phase 13 — UI Review

**Audited:** 2026-06-13
**Baseline:** 13-UI-SPEC.md (approved design contract)
**Screenshots:** Not captured — Flutter app, no browser/Playwright available. Code-only audit.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | All contract copy present; "Priority" label style deviates (bodyMedium vs labelMedium) |
| 2. Visuals | 3/4 | Decision screen has 480dp desktop constraint; check-in emoji row does not |
| 3. Color | 3/4 | Unselected TypeCard uses null background instead of spec-required surfaceContainerHighest |
| 4. Typography | 2/4 | Priority label wrong role (bodyMedium not labelMedium); raw TextStyle used in decision subhead instead of textTheme |
| 5. Spacing | 3/4 | All spec-mandated 16→12 reductions applied; drag handle margin 16dp vs spec's implied 20dp |
| 6. Experience Design | 3/4 | No screen reader labels on emoji GestureDetectors; all state/error/disabled coverage present |

**Overall: 17/24**

---

## Top 3 Priority Fixes

1. **Priority label uses bodyMedium (14sp) instead of labelMedium (12sp w500 onSurfaceVariant)** — Users reading the label see the same visual weight as body content, undermining the label-vs-content hierarchy the spec explicitly calls out. Fix: change `goal_form_sheet.dart:208` from `theme.textTheme.bodyMedium` to `theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant)`.

2. **Unselected GoalTypePicker card background is null, not `colorScheme.surfaceContainerHighest`** — With null color, the card inherits from `CardTheme`, which under some Material 3 seeds could resolve to `surface` rather than `surfaceContainerHighest`, flattening the card-vs-background contrast the spec requires to distinguish the picker from the sheet background. Fix: change `goal_type_picker.dart:73` to `final backgroundColor = isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest`.

3. **Check-in body (emoji row + "Let's go" button) has no 480dp desktop width constraint** — The spec §Adaptive Layout requires `ConstrainedBox(maxWidth: 480)` around the entire check-in column for ≥720dp viewports to prevent the emoji row from becoming absurdly wide. `_buildDecisionBody` has this constraint (line 357–358) but `_buildCheckinBody` does not — only a 24dp horizontal padding is applied. Fix: wrap the `Column` in `_buildCheckinBody` with `ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480))` centered via `Center` (which is already the parent).

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)

WARNING — Copy words all match the contract; presentation style of the "Priority" label deviates.

**Passing:**
- AppBar title "How are you feeling?" — present (line 212)
- CTA "Let's go" — present (line 330)
- Decision heading "Ready to start?" — present (line 363)
- Decision subhead "Choose your pace for today" — present (line 372)
- Choice titles "Full day" / "Lighter day" — present (lines 382, 390)
- Choice subtitles match spec exactly — present (lines 384, 392)
- Back affordance "Go back" — present (line 399)
- Acknowledgment hint "Swipe up to begin" — present (line 464)
- Goal form titles "Add goal" / "Edit goal" — present (line 169)
- Save labels "Add goal" (add mode) / "Save" (edit mode) — present (lines 317)
- Error snackbar "Something went wrong. Please try again." — present in both `_generate()` (line 126) and `_commitAndProceed()` (line 161) and goal form save error uses slightly different wording "Could not save goal. Please try again." — acceptable variant.
- "Cancel" button label — technically a generic label but is correct as a secondary action label (UI-SPEC does not flag it).

**Failing:**
- `goal_form_sheet.dart:208`: `Text('Priority', style: theme.textTheme.bodyMedium)` — spec §Copywriting Contract states Priority label should use `labelMedium` style (12sp). The word is correct but the style token is wrong, which belongs under Typography. Noted here because it is a named element in the contract.

---

### Pillar 2: Visuals (3/4)

WARNING — Core visual hierarchy is correct; desktop adaptive gap in `_buildCheckinBody`.

**Passing:**
- Three-state AnimatedSwitcher with `ValueKey('checkin')`, `ValueKey('decision')`, `ValueKey('acknowledgment')` — fully implemented (lines 228–235).
- `_LighterDayCard` provides `AnimatedScale` (0.97, 80ms, easeOut) pressed feedback and `AnimatedContainer` border/fill hover states — implemented exactly per spec.
- Emoji targets have `MouseRegion` + `GestureDetector` onTapDown/onTapUp/onTapCancel — hover/pressed hierarchy implemented (lines 261–299).
- `_buildDecisionBody` correctly wrapped in `ConstrainedBox(maxWidth: 480)` centered for desktop (lines 357–358).
- Inline "Want a lighter day?" Switch is removed — confirmed absent.
- "Let's go" pill uses `StadiumBorder` — implemented (line 318).
- Decision cards have visible card affordance (border + fill background) distinguishing them from the mood background.

**Failing:**
- `_buildCheckinBody`: `Center > Padding(horizontal: 24) > Column(...)` — no `ConstrainedBox(maxWidth: 480)` wrapper. On a 1440dp wide desktop window the emoji row spans the full column width constrained only by `spaceEvenly`, which will distribute 5 emojis across ~1392dp — absurdly wide. Spec §Adaptive Layout explicitly requires this constraint on the check-in column at ≥720dp. (BLOCKER on desktop/web targets; WARNING on mobile-only deployment.)

**Pending human verification (8 items noted in SUMMARY):**
- Live contrast at all 5 moods, hover/pressed visibility, decision screen animated flow, card pressed scale — cannot be confirmed from code.

---

### Pillar 3: Color (3/4)

WARNING — Luminance-adaptive logic correct; unselected TypeCard background is null.

**Passing:**
- `_onBgColor` getter correctly uses `computeLuminance() > 0.35` threshold and returns `Color(0xFF1A1A1A)` or `Colors.white` (lines 66–74). Matches spec exactly.
- `_resolveEmojiBackground` uses same luminance-adaptive base for hover (alpha 26 unselected, 64 selected) and pressed (alpha 77 selected) — matches spec.
- `_LighterDayCard` border hover alpha: 77 rest → 153 hover; fill: 26 rest → 38 hover — matches spec (lines 531, 534).
- "Let's go" button `backgroundColor: _onBgColor`, `foregroundColor: _backgroundColor` — luminance-adaptive, matches spec.
- All AppBar and iconTheme colors use `_onBgColor` — matches spec.
- Goal form uses `colorScheme.error` for Archive TextButton foreground — matches spec.
- All other colors use `colorScheme.*` semantic tokens — no rogue hardcoded hex values except the two spec-mandated `Color(0xFF1A1A1A)` constants.

**Failing:**
- `goal_type_picker.dart:73`: `final backgroundColor = isSelected ? colorScheme.primaryContainer : null`. Spec §Compact GoalTypePicker visual spec states unselected card background is `colorScheme.surfaceContainerHighest`. Passing `null` to `Card(color:)` uses the inherited `CardTheme.color`, which in Material 3 defaults to `colorScheme.surfaceContainerLow` — not `surfaceContainerHighest`. This may render the unselected cards lighter than intended, reducing contrast between picker cards and the sheet background.

---

### Pillar 4: Typography (2/4)

WARNING — Two roles use wrong textTheme slots; raw TextStyle used in decision screen where textTheme roles should be used.

**Passing:**
- Goal form title: `theme.textTheme.titleLarge` — correct (line 170).
- TypeCard title: `theme.textTheme.bodyMedium?.copyWith(...)` with w600 when selected — correct (lines 95–99).
- TypeCard subtitle: `theme.textTheme.bodySmall?.copyWith(...)` — correct (lines 104–107).
- `_LighterDayCard` title: `theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)` — correct (lines 547–549).
- `_LighterDayCard` subtitle: `theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w400)` — correct (lines 555–557).
- Acknowledgment body text: `fontSize: 22, fontWeight: FontWeight.w500, height: 1.4` — matches spec (lines 455–458).
- Acknowledgment hint: `fontSize: 14, letterSpacing: 1.2` — matches spec (lines 466–467). Missing explicit `fontWeight: FontWeight.w400` but defaults correctly.

**Failing:**
- `goal_form_sheet.dart:208`: Priority label uses `theme.textTheme.bodyMedium` (14sp, w400). Spec requires `labelMedium` (12sp, w500, `onSurfaceVariant` color). The rendered label is 2sp too large and wrong weight. Missing `color: colorScheme.onSurfaceVariant`.
- `checkin_screen.dart:373–375`: Decision subhead "Choose your pace for today" uses bare `TextStyle(fontSize: 14)` with no `fontWeight` and no `color` — only `color: onBg.withAlpha(179)` is set separately. Should use `theme.textTheme.bodyMedium?.copyWith(color: ..., fontWeight: FontWeight.w400)` per spec conventions. Technically renders correctly (w400 default) but bypasses the textTheme system, meaning it won't inherit future theme overrides.
- `checkin_screen.dart:364–368`: Decision heading "Ready to start?" uses bare `TextStyle(color: onBg, fontSize: 20, fontWeight: FontWeight.w600)` — should use `theme.textTheme.titleMedium?.copyWith(...)` per spec which designates `titleMedium` for this role.
- `checkin_screen.dart:295`: Emoji text uses `TextStyle(fontSize: 36)`. Spec says emoji containers are 60dp; emoji at 36sp fills that well, but spec §Acknowledgment body emoji is `fontSize: 64dp` (3xl token). The acknowledgment emoji at line 445 uses `fontSize: 72` — the spec says 64dp (3xl token). 72 vs 64 is a deviation, but the spec also says "existing code — retain" for acknowledgment, so this is pre-existing and out of scope for Phase 13. Noted only.

---

### Pillar 5: Spacing (3/4)

WARNING — Spec-mandated reductions applied; drag handle margin slightly off; one non-scale value in decision screen.

**Passing:**
- After title spacer: `SizedBox(height: 12)` — matches spec (line 173).
- After GoalTypePicker spacer: `SizedBox(height: 12)` — matches spec (line 191).
- After name TextField spacer: `SizedBox(height: 12)` — matches spec (line 204).
- After SegmentedButton spacer: `SizedBox(height: 16)` — spec says leave at 16 (line 220). Correct.
- TypeCard contentPadding: `EdgeInsets.symmetric(horizontal: 12, vertical: 6)` — matches spec exactly (line 86).
- `minVerticalPadding: 0` on ListTile — matches spec (line 87).
- TypeCard gaps in GoalTypePicker: `SizedBox(height: 8)` between cards — matches spec (lines 29, 38).
- Decision screen: `horizontal: 32, vertical: 48` — matches spec (line 355). Subhead gap h:8, cards gap h:32, between cards h:12 — all match spec.
- Sheet horizontal padding: `EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets)` — 16dp md token, correct.
- "Let's go" button vertical padding: `EdgeInsets.symmetric(vertical: 14)` — matches spec.

**Failing:**
- `goal_form_sheet.dart:159`: Drag handle `margin: EdgeInsets.only(bottom: 16)`. Spec says drag handle adds "24dp total (handle + bottom margin)" with a 4dp tall handle, implying bottom margin of 20dp. Implemented at 16dp — 4dp short. Minor visual gap between handle and title.
- `checkin_screen.dart:394`: Between "Go back" TextButton and the card above it, `SizedBox(height: 16)` is used. This value is not in the spacing scale table and is not specified in the decision screen pseudocode (which ends after the second card). 16dp is close to md (16dp) so it is in-scale, but the spec pseudocode shows no explicit gap before the back button — it was implemented as `SizedBox(height: 16)` which is a reasonable addition but undocumented.

---

### Pillar 6: Experience Design (3/4)

WARNING — State machine complete; no screen reader labels on emoji tap targets; minor accessibility gap.

**Passing:**
- Full A→B→C→D→E state machine implemented with correct transitions (lines 228–235).
- Generation error snackbar in `_generate()` catch block — present (lines 123–130).
- `_commitAndProceed()` catch block with snackbar — present (lines 155–164).
- Goal save error snackbar — present (`goal_form_sheet.dart:98–103`).
- Archive error snackbar — present (`goal_form_sheet.dart:115–120`).
- `_canSave` gate disables Save button when name is empty or type not selected — present (line 67–68).
- `if (mounted)` guards on all async post-await setState calls — verified in `_generate()` (line 115) and `_commitAndProceed()` (line 146).
- "Go back" affordance resets `_generationDone = false` to return to State B — present (line 397).
- Non-null no-op lambda during generation prevents invisible disabled foreground on amber (line 311) — spec-endorsed approach.
- `_pressedMoods.clear()` on generation start prevents stale press highlight during transition (line 97) — good defensive code.

**Failing:**
- Emoji `GestureDetector` widgets have no `Semantics` wrapper and no `semanticsLabel`. Screen reader users cannot identify which mood each emoji represents. Spec §Accessibility Contract does not explicitly call this out but WCAG 2.1 SC 1.1.1 requires non-text content to have text alternatives. At minimum: `Semantics(label: 'Mood ${mood}: ${_moodEmojis[mood]}', button: true, child: GestureDetector(...))`.
- `_LighterDayCard` has no `Semantics` label. A screen reader will announce the icon, title, and subtitle text in sequence — this is likely adequate, but the card is not wrapped in a single semantic group marking it as a button. Add `Semantics(button: true)` to the outer `GestureDetector` in `_LighterDayCardState`.
- "Go back" TextButton: color is `onBg.withAlpha(179)` — at 70% opacity on light backgrounds (moods 4/5) this could approach the 4.5:1 WCAG threshold boundary. Not a confirmed failure (requires runtime contrast measurement) but is a risk item for human UAT.

---

## Files Audited

- `lib/screens/schedule/checkin_screen.dart` (571 lines)
- `lib/screens/goals/goal_form_sheet.dart` (327 lines)
- `lib/screens/goals/widgets/goal_type_picker.dart` (114 lines)
- `.planning/phases/13-check-in-and-goal-form/13-UI-SPEC.md`
- `.planning/phases/13-check-in-and-goal-form/13-CONTEXT.md`
- `.planning/phases/13-check-in-and-goal-form/13-01-SUMMARY.md`
- `.planning/phases/13-check-in-and-goal-form/13-02-SUMMARY.md`
