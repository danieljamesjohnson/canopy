---
phase: 19
slug: energy-valence
audited_at: 2026-06-14
baseline: 19-UI-SPEC.md (approved 2026-06-14)
screenshots: not captured (dev server not reachable on 3000/5173/8080 from audit host)
---

# Phase 19 — UI Review

**Audited:** 2026-06-14
**Baseline:** 19-UI-SPEC.md (approved)
**Screenshots:** Not captured — dev server returned HTTP 307 (redirect, not a Flutter web app response) on ports 3000 and 8080; port 5173 unreachable. Audit is code-only.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | All spec-declared strings match exactly; no generic labels |
| 2. Visuals | 3/4 | Icon size in valence badges is 12dp vs spec-declared 14dp |
| 3. Color | 3/4 | `Colors.green.shade600` and `Colors.grey.shade400` are hardcoded in chunk_card.dart (pre-existing but in scope file); valence color contract fully honored |
| 4. Typography | 3/4 | Several `TextStyle(fontSize: N)` literals bypass the Material 3 TextTheme; "Energy" label w400 correctly enforced |
| 5. Spacing | 4/4 | All spacing values are 8pt-grid multiples or spec-approved exceptions; no arbitrary pixel values |
| 6. Experience Design | 4/4 | isSaving guard on CTAs, catch blocks with snackbar, empty-state text, neutral-badge suppression all implemented |

**Overall: 21/24**

---

## Top 3 Priority Fixes

1. **Valence badge icon size is 12dp, spec declares 14dp** — At small sizes the difference is perceptible: bolt and hourglass icons in both `_ValenceBadge` (goal_card.dart:285) and `_ValenceChip` (chunk_card.dart:396, :455) render at 12dp. The UI-SPEC §Valence color encoding table calls for 14dp. Change `size: 12` to `size: 14` in both files.

2. **Hardcoded `Colors.green.shade600` for the complete-check icon** — chunk_card.dart:285 uses `Colors.green.shade600` for the `Icons.check_circle` resolved-state icon. This is a raw `dart:ui` color that ignores the Material 3 `ColorScheme` and will not adapt to dark mode or dynamic color. Replace with `colorScheme.tertiary` or `colorScheme.primary` (whichever conveys success in the app's existing convention); or `colorScheme.onPrimary` inside a colored container. This is in the audited source file even though it predates Phase 19.

3. **Hardcoded `Colors.grey.shade400` for the resolved-chunk bar color** — chunk_card.dart:159 uses `Colors.grey.shade400` as the left-bar color for completed/skipped chunks. This bypasses the ColorScheme and will not adapt to dark mode. Replace with `colorScheme.outlineVariant` or `colorScheme.surfaceContainerHighest` for a semantically correct muted signal.

---

## Detailed Findings

### Pillar 1: Copywriting (4/4)

All UI-SPEC §Copywriting Contract strings are present verbatim:

- "Energy" section label: goal_form_sheet.dart:253 — PASS
- "Gives energy" / "Neutral" / "Costs energy" segment labels: goal_form_sheet.dart:265–275 — PASS
- "Add emoji" unset button label: goal_form_sheet.dart:289 — PASS
- "Choose an emoji" picker title: goal_form_sheet.dart:496 — PASS
- "Gives" / "Costs" badge labels: goal_card.dart:267,273 — PASS
- "What gives you energy?" headline: onboarding_screen.dart:741 — PASS
- Sub-copy matches spec verbatim: onboarding_screen.dart:744–748 — PASS
- "Energizing" FilterChip label: onboarding_screen.dart:776 — PASS
- "Add something energizing" button: onboarding_screen.dart:813 — PASS
- "No goals yet — add one below." empty state: onboarding_screen.dart:755 — PASS
- "Skip" TextButton: onboarding_screen.dart:823 — PASS
- "Let's go" CTA: onboarding_screen.dart:831 — PASS
- "Add goal" tooltip on quick-add confirm: onboarding_screen.dart:804 — PASS
- "Could not save goal. Please try again." snackbar: goal_form_sheet.dart:113 — PASS

No generic labels ("Submit", "OK", "Cancel") found in Phase 19 additions. "Save Goal" / "Add Goal" / "Discard" are established carry-forward labels, not generic patterns.

### Pillar 2: Visuals (3/4)

**WARNING — Icon size mismatch:**
The UI-SPEC §Valence color encoding table specifies 14dp for all valence icons (bolt, remove, hourglass_empty). The implementation uses `size: 12` in both badge widgets:
- goal_card.dart:285 — `Icon(icon, size: 12, color: onColor)`
- chunk_card.dart:396 — `Icon(icon, size: 12, color: onColor)` (`_ValenceChip`)
- chunk_card.dart:455 — `Icon(icon, size: 12, color: onColor)` (`_PriorityChip` — pre-existing but same file)

At 12dp the bolt icon in particular may be difficult to perceive on high-density screens against the tonal container background.

**PASS — Visual hierarchy:**
- Title row of goal card correctly places type icon → optional emoji → goal name with `Expanded` + ellipsis — clear left-to-right reading order.
- Secondary row guards on `secondary != null || showPriorityChip || energyValence != neutral` so the row only appears when there is content to show (goal_card.dart:169–171).
- Onboarding Screen 4 follows the established `_ScreenLayout` wrapper (SingleChildScrollView + ConstrainedBox + IntrinsicHeight) — no structural deviation from prior screens.
- Emoji picker grid uses 44×44 `SizedBox` cells matching the touch-target spec.
- `_EmojiPickerDialog` wraps the shared `_buildEmojiGrid` in a bare `Dialog` with correct title styling (`titleLarge`, centered).

**PASS — Neutral badge suppression:**
Both `_ValenceBadge` and `_ValenceChip` return `SizedBox.shrink()` for `EnergyValence.neutral` (goal_card.dart:253, chunk_card.dart:364), matching the "neutral shows no badge" rule.

**PASS — Resolved chunk opacity:**
`_WorkChunkContent` wraps content in `Opacity(opacity: contentOpacity)` (chunk_card.dart:195) where `contentOpacity = 0.5` for resolved chunks — valence chip and emoji prefix inherit the dim automatically, no special handling needed.

### Pillar 3: Color (3/4)

**PASS — Valence color contract honored:**
- `gives`: `colorScheme.tertiaryContainer` / `colorScheme.onTertiaryContainer` — confirmed in both badge files.
- `costs`: `colorScheme.secondaryContainer` / `colorScheme.onSecondaryContainer` — confirmed in both badge files.
- `colorScheme.error` is NOT used for "costs energy" valence anywhere — the `error` slot appears only on the Archive `TextButton` (goal_form_sheet.dart:411) and the "Skip" chunk action border/foreground (chunk_card.dart:328,330), both of which are destructive/negative actions correctly using error.

**WARNING — Hardcoded non-ColorScheme colors in chunk_card.dart:**
- chunk_card.dart:159: `Colors.grey.shade400` for resolved left-bar — bypasses ColorScheme, no dark-mode adaptation.
- chunk_card.dart:285: `Colors.green.shade600` for completed-chunk check icon — raw green, will not adapt to dynamic color or dark mode.

These are in the audited file scope (chunk_card.dart is listed as a Phase 19 source) even though they predate this phase. Both are pre-existing defects that Phase 19 did not introduce but also did not remediate while modifying the file.

**PASS — No hardcoded hex values in Phase 19 additions.** All new coloring (valence badges, goal form, onboarding) uses `colorScheme.*` tokens exclusively.

**PASS — 60/30/10 discipline:**
Dominant usage is `colorScheme.surface` backgrounds (screen and dialog). Secondary usage is `surfaceContainerHighest` for unselected states. Accent (`primary`, `primaryContainer`) confined to CTAs and active step dot. No accent overuse detected.

### Pillar 4: Typography (3/4)

**PASS — Two-weight contract enforced for Phase 19 elements:**
- "Energy" label: `labelMedium.copyWith(fontWeight: FontWeight.w400)` — goal_form_sheet.dart:255. Explicitly overrides M3 default w500. PASS.
- "Priority" label: same pattern — goal_form_sheet.dart:315. Consistent. PASS.
- `_ValenceBadge` label: `labelSmall.copyWith(fontWeight: FontWeight.w600)` — goal_card.dart:289. PASS.
- `_ValenceChip` label: same pattern — chunk_card.dart:402. PASS.
- Chunk card goal-name title: `titleMedium.copyWith(fontWeight: FontWeight.w600)` — chunk_card.dart:218. PASS.

**WARNING — Raw `TextStyle(fontSize: N)` literals in audited files:**
The following bypass the Material 3 TextTheme and are not declared in the UI-SPEC typography table:
- goal_card.dart:135: `TextStyle(fontSize: 16)` for the emoji tag in the title row. The spec says "Text(goal.emojiTag!, style: TextStyle(fontSize: 16))" is acceptable for a single emoji character, but it is not mapped to a TextTheme role.
- onboarding_screen.dart:772: `TextStyle(fontSize: 20)` for the emoji `leading` widget in Screen 4 `ListTile`. Same concern — not a TextTheme role.
- goal_form_sheet.dart:513: `TextStyle(fontSize: 22)` for emoji cells in the picker grid. Not mapped to TextTheme.
- chunk_card.dart:97: `fontSize: 12` inside a raw `TextStyle` for the short-break label (pre-existing).
- chunk_card.dart:114: `TextStyle(fontSize: 24)` for the coffee emoji in a long-break card (pre-existing).

The emoji-specific cases (16, 20, 22dp) are arguable — emoji rendering is not governed by a typeface and TextTheme roles do not meaningfully apply. However they are technically out-of-contract. The non-emoji case (chunk_card.dart:97) is a clear pre-existing violation.

**PASS — No w500 detected** in any Phase 19 code.

**NOTE — `bodyLarge` usage:**
onboarding_screen.dart:908 uses `textTheme.bodyLarge` for the `_TimeTile` time display (pre-existing, Screen 2). This role is not in the Phase 19 typography table but is carried forward and was not introduced here.

### Pillar 5: Spacing (4/4)

All spacing values in Phase 19 additions conform to the 8pt grid or spec-approved exceptions:

- Goal form valence picker section: `SizedBox(height: 12)` before "Energy" label (goal_form_sheet.dart:247), consistent with existing field-gap pattern at 12dp (on-grid: 4×3). `SizedBox(height: 8)` after picker (line 283) — matches spec "8dp between the two SegmentedButton rows". `SizedBox(height: 8)` after emoji button (line 307) — on-grid.
- `_ValenceBadge` / `_ValenceChip` padding: `EdgeInsets.symmetric(horizontal: 8, vertical: 4)` — matches spec "8dp horizontal, 4dp vertical". SizedBox(width: 4) gap between icon and label — matches spec "4dp icon-to-text gap".
- Onboarding Screen 4: SizedBox(height: 8) after headline (line 742), SizedBox(height: 24) after sub-copy (line 750), SizedBox(height: 16) before quick-add (line 784) — all match the spec content-structure values (8/24/16dp).
- Emoji picker grid padding: `EdgeInsets.all(8)` (line 505) — on-grid.
- No arbitrary pixel values (`[Npx]` or `[Nrem]`) detected.

Minor note: `SizedBox(height: 2)` appears in chunk_card.dart for tight inline spacing within the text column (pre-existing, lines 223, 238, 253, 905). This is 2dp (half-grid), but it predates Phase 19 and was not introduced here.

### Pillar 6: Experience Design (4/4)

**PASS — Save guard:** `_isSaving` flag prevents double-tap on onboarding completion (onboarding_screen.dart:91–92). Both "Skip" and "Let's go" CTAs on Screen 4 are disabled during save (`isSaving ? null : ...` — lines 824, 830).

**PASS — Error handling:** `_save()` and `_archive()` both have `catch (e)` blocks that show a snackbar with the spec-declared error copy (goal_form_sheet.dart:109–116, 126–133).

**PASS — Empty state:** Screen 4 shows "No goals yet — add one below." when `allGoals.isEmpty` (onboarding_screen.dart:753–760), using `bodyMedium`, `onSurfaceVariant`, `textAlign: center` — matches spec.

**PASS — Disabled state:** The Save/Add Goal `ElevatedButton` is gated on `_canSave` (goal_form_sheet.dart:427). Screen 4 CTAs gated on `isSaving`.

**PASS — Valence badge suppression for neutral:** No badge rendered when `goal.energyValence == EnergyValence.neutral` — prevents visual noise for the majority of goals.

**PASS — In-flight quick-add auto-commit:** `_onComplete()` calls `_confirmQuickAdd()` when `_showQuickAdd && text.isNotEmpty` before firing `widget.onComplete` (onboarding_screen.dart:720–726) — prevents silently discarding a goal the user typed but hadn't confirmed.

**PASS — No missing loading state for emoji picker:** The picker dismisses synchronously on tap, with no async operation, so no loading state is needed.

---

## Registry Safety

Not applicable — Flutter project. No component registry used (confirmed by absence of `components.json`).

---

## Files Audited

- `lib/screens/goals/goal_form_sheet.dart` (542 lines)
- `lib/screens/goals/widgets/goal_card.dart` (357 lines)
- `lib/screens/schedule/widgets/chunk_card.dart` (469 lines)
- `lib/screens/onboarding/onboarding_screen.dart` (916 lines)
- `.planning/phases/19-energy-valence/19-UI-SPEC.md` (audit baseline)
- `.planning/phases/19-energy-valence/19-01-SUMMARY.md` (context)
