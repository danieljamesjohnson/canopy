---
phase: 18
slug: responsive-modals-and-desktop-polish
audited: 2026-06-14
baseline: 18-UI-SPEC.md (approved)
screenshots: not captured (no dev server detected; code-only audit supplemented by 18-VERIFICATION.md attestation)
---

# Phase 18 — UI Review

**Audited:** 2026-06-14
**Baseline:** 18-UI-SPEC.md (approved design contract)
**Screenshots:** Not captured — no dev server at localhost:3000/5173/8080. Code-only audit. Desktop walkthrough already attested in 18-VERIFICATION.md frontmatter (560dp dialog, 720dp body constraints, updated copy confirmed live).

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | Goal form and commitment delete copy fully upgraded; "Cancel" survives in settings_screen (out of phase scope) and commitment form lacks color picker label |
| 2. Visuals | 3/4 | Drag handle correctly hidden in dialog mode; commitment form has no visible color picker UI despite storing a color value |
| 3. Color | 3/4 | Hardcoded hex mood colors in schedule_screen and Colors.amber in empty state; all phase-18 forms use colorScheme slots correctly |
| 4. Typography | 2/4 | FontWeight.w500 in goal_form_sheet Priority label violates the w400/w600-only contract; w500 appears in two pre-existing out-of-scope files |
| 5. Spacing | 3/4 | 12dp legacy values in commitment card margin/padding; all phase-18 modal padding uses 24dp (lg) as specified |
| 6. Experience Design | 3/4 | CR-02 and WR-01 from code review are fixed; WR-02 (commitment save error handling) is fixed; WR-03 (time ordering guard) is fixed; IN-01 (day label ambiguity) is fixed; IN-02 (commitments missing maxWidth) is fixed — all code-review items resolved |

**Overall: 17/24**

---

## Top 3 Priority Fixes

1. **FontWeight.w500 on the Priority label in goal_form_sheet.dart:231** — violates the w400/w600-only typography contract from 18-UI-SPEC.md; introduces a third weight into a two-weight system, weakening emphasis hierarchy. Fix: change `fontWeight: FontWeight.w500` to `fontWeight: FontWeight.w400` (the `labelMedium` base weight, which already de-emphasizes via `onSurfaceVariant` color).

2. **Commitment form color picker is silently stored but never shown** — `_color` is initialized and written to the block (commitment_form_sheet.dart:38, 111) but no color picker widget is rendered in `build()`. Users cannot see or change a commitment's color on desktop dialog or mobile sheet. The color field appears to be a carry-forward stub. Either render a color picker row above the Discard button, or remove the `_color` field and the `block.color = _color` write until the feature is intentional.

3. **Hardcoded hex colors in schedule_screen.dart:22-26 (`_moodColors` map)** — five `Color(0xFF...)` values are defined outside the theme system. The UI-SPEC requires all color references to use `colorScheme.*` semantic slots with no raw hex values. These mood-tint colors are applied to the AppBar background on the schedule screen. They diverge from the dynamic `ColorScheme.fromSeed` mood system used in ThemeNotifier. Fix: source these from `ThemeNotifier.moodSeeds` (already used correctly in home_screen.dart) rather than a hardcoded map.

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)

**What passes:**
- Goal form add mode title: "Add Goal" — matches spec (goal_form_sheet.dart:183)
- Goal form edit mode title: "Edit Goal" — matches spec (goal_form_sheet.dart:183)
- Goal form primary CTA add: "Add Goal" — matches spec (goal_form_sheet.dart:344)
- Goal form primary CTA edit: "Save Goal" — matches spec (goal_form_sheet.dart:344)
- Goal form cancel: "Discard" — matches spec (goal_form_sheet.dart:339)
- Goal form destructive: "Archive goal" — matches spec (goal_form_sheet.dart:329)
- Commitment form titles: "New commitment" / "Edit commitment" — matches spec (commitment_form_sheet.dart:166-167)
- Commitment form CTAs: "Add commitment" / "Save changes" — matches spec (commitment_form_sheet.dart:244)
- Commitment form cancel: "Discard" — matches spec (commitment_form_sheet.dart:236)
- Commitment delete dialog: "Delete commitment?" title, "Keep commitment" / "Delete commitment" actions — matches spec (commitments_screen.dart:46-57)
- Goals empty state: "No goals yet" / "Add your first goal" — matches spec (goals_screen.dart:303-309)
- Home empty state: "No schedule yet" / "Start your morning check-in..." — matches spec (home_screen.dart:693-703)
- Goal save error snackbar: "Could not save goal. Please try again." — matches spec (goal_form_sheet.dart:105)
- Commitment save error snackbar: "Could not save commitment. Please try again." — present and correct (commitment_form_sheet.dart:118), the open spec item is addressed.

**WARNING: "Cancel" persists in settings_screen.dart:67 and :451.** These are out of scope for Phase 18 per the spec (commitments and goal forms were the only in-scope callers), but they are noted as a debt item for a future copy polish phase.

**WARNING: Commitment form color field has no UI label or affordance.** The `_color` field is set to `'#607D8B'` as a default and written to the saved block, but no label, picker, or current-color indicator appears in the form. A user editing an existing commitment with a color swatch (visible on the list card) cannot see or change it.

---

### Pillar 2: Visuals (3/4)

**What passes:**
- Drag handle correctly hidden in dialog mode via `isDialog` flag — both GoalFormSheet (goal_form_sheet.dart:168) and CommitmentFormSheet (commitment_form_sheet.dart:151) gate the handle on `!isDialog`.
- CR-02 from code review is fully resolved: CommitmentsScreen._openAddSheet (commitments_screen.dart:27-35) now explicitly passes `isDialog: isDesktop`, matching the GoalsScreen pattern.
- GoalTypePicker renders in a `Column(mainAxisSize: MainAxisSize.min)` — fits within 560dp without clipping per spec.
- Desktop icon buttons on the commitments list row use `AnimatedOpacity` with hover reveal, edit + delete icons, and tooltips — solid desktop interaction affordance (commitments_screen.dart:256-275).
- Mobile delete icon is always-visible per the spec's cross-cutting landmine note (commitments_screen.dart:249-253).
- Empty states on Goals and Commitments include icon + heading + body — clear visual hierarchy.

**BLOCKER risk averted (fixed): The nested SingleChildScrollView (CR-01) was addressed.** `_DialogForm` (`adaptive_form_modal.dart:68-96`) is a `StatefulWidget` that owns the `ScrollController` and wraps only a `ConstrainedBox` around `builder(scrollController)` — no outer `SingleChildScrollView`. The form's own `SingleChildScrollView` is the sole scroll container.

**WARNING: Commitment color swatch on list cards (a 16dp circle, commitments_screen.dart:219-225) is displayed but has no edit affordance in the form.** A user sees a colored dot on the card but the form shows no way to change it. This creates a confusing visual that implies something settable that is not.

**INFO: `Colors.amber` hardcoded on schedule empty-state icon (schedule_screen.dart:317).** The icon stands out as a warm accent against an otherwise theme-neutral empty state — the color is not sourced from the theme.

---

### Pillar 3: Color (3/4)

**What passes:**
- All phase-18 form widgets use `colorScheme.*` slots exclusively — no hardcoded hex in goal_form_sheet.dart or commitment_form_sheet.dart.
- Archive button correctly uses `colorScheme.error` (goal_form_sheet.dart:327) for the destructive action.
- Drag indicator in commitment form uses `colorScheme.outline` (commitment_form_sheet.dart:157); goal form uses `colorScheme.outlineVariant` (goal_form_sheet.dart:175) — both are neutral, not accent, per spec.
- Section headers in goals_screen use `colorScheme.primary` for type header text (goals_screen.dart:175) — correct per spec ("color, not weight" for `titleSmall` headers).
- FAB on both Goals and Commitments screens uses `FloatingActionButton.extended` with default primary fill — correct accent anchor per spec.
- Dialog surface uses Material 3 `Dialog` default (tonal surface) — no explicit override needed or added.

**WARNING: `_moodColors` map in schedule_screen.dart:22-26** defines five `Color(0xFF...)` hardcoded hex values for mood tinting the AppBar. These are outside the theme system. Per spec, no hex values are hardcoded in this phase and all references use `colorScheme.*` slots. `ThemeNotifier.moodSeeds` already provides mood-keyed colors and is used correctly in home_screen.dart:327. The schedule screen carries a pre-existing inconsistency that this phase did not address but also did not introduce.

**WARNING: `Colors.amber` for the schedule empty-state icon (schedule_screen.dart:317)** is a hardcoded color outside the theme. Pre-existing, out of phase 18 scope, but present in a file touched by this phase (ConstrainedBox was added to the schedule body).

**INFO:** `Colors.white` for `foregroundColor` on the schedule AppBar (schedule_screen.dart:49) is a common hardcoded white used for legibility against the moodColor background; this is a defensible callsite but technically violates the no-hardcoded-hex rule.

---

### Pillar 4: Typography (2/4)

**Contract:** Only w400 and w600 are permitted. No w500. `FontWeight.bold` (w700) is not mentioned as permitted.

**BLOCKER: FontWeight.w500 on Priority label** — goal_form_sheet.dart:231 applies `fontWeight: FontWeight.w500` to the "Priority" `labelMedium` text. This introduces a third weight into a two-weight system, creating an intermediate emphasis level that the spec explicitly excludes. The de-emphasis intent is already achieved by `color: colorScheme.onSurfaceVariant` — the w500 adds nothing and breaks the contract.

**WARNING: `FontWeight.bold` appears in pre-existing out-of-scope files.** Files NOT modified by phase 18 contain `FontWeight.bold` (w700): `end_of_day_card.dart:58`, `end_of_day_summary_screen.dart:77/104`, `quarterly_review/sections/data_section.dart:72/111`, `quarterly_review/sections/adjustments_section.dart:163`, `review_banner.dart:45`. These are not regressions from this phase but are violations of the typography contract if the contract is applied app-wide. Noted for a future typography cleanup pass.

**WARNING: `FontWeight.w500` also appears pre-existing in `acknowledgment_screen.dart:115` and `checkin_screen.dart:387`** — same contract violation, out of phase 18 scope.

**WARNING: `FontWeight.w300` in `focus_screen.dart:241`** — a light weight not mentioned at all in the spec.

**What passes in phase-18 files:**
- goal_form_sheet.dart: title uses `textTheme.titleLarge` (w400 base) — correct.
- commitment_form_sheet.dart: title uses `textTheme.titleLarge` — correct; "Days" label uses `textTheme.labelMedium` with `onSurfaceVariant` color only — correct.
- goals_screen.dart: section header `titleSmall` uses `colorScheme.primary` with no weight override — correct. "Your goals" heading uses w600 on `titleMedium` — correct (prominent inline heading).
- home_screen.dart: "Your day starts at…", "That's a wrap", "Up next", "Next" chunk title all use w600 on `titleMedium` — correct.

The single in-scope violation (w500 in goal_form_sheet.dart) is what drops this pillar to 2/4 — it is a deliberate contract item, not a pre-existing file, and the fix is a one-line change.

---

### Pillar 5: Spacing (3/4)

**What passes:**
- Modal padding: 24dp horizontal and vertical in both forms (`EdgeInsets.fromLTRB(24, 24, 24, 24)` in dialog mode) — matches spec `lg` token.
- Field gaps: 12dp `SizedBox` between title and type picker, between type picker and name field — these are legacy 12dp callsites; the spec explicitly tolerates them in existing code.
- Section gap before buttons: 16dp `SizedBox(height: 16)` between the last field and action row in goal form — matches `md` token.
- `SizedBox(height: 8)` between "Discard" and primary button in commitment form — matches `sm`.
- 720dp `ConstrainedBox` applied to home_screen body (home_screen.dart:356), schedule_screen Expanded list (schedule_screen.dart:94), goals_screen CustomScrollView (goals_screen.dart:92-93), commitments_screen both empty and list states (commitments_screen.dart:140-149) — all four screens constrained as required, including the IN-02 fix.
- `Align(alignment: Alignment.topCenter)` centering used on all constrained bodies — correct.

**WARNING: 12dp card margin/padding in `_CommitmentRow`** — `commitments_screen.dart:210` uses `EdgeInsets.symmetric(horizontal: 12, vertical: 4)` for card margin, and `:216` uses `EdgeInsets.symmetric(horizontal: 12, vertical: 12)` for card content padding. The spacing scale has no explicit 12dp token (it is "tolerated in existing callsites" per spec). This was pre-existing code; the phase did not introduce it. However, the phase did rewrite the surrounding screen layout, so these values now sit alongside the new `ConstrainedBox` constraint.

**INFO: `SizedBox(height: 2)` appears in multiple places** (goal_form_sheet.dart metadata gaps, commitment_form_sheet.dart time picker label gap). Not a spec violation — 2dp sub-xs inline spacing is common for tight label stacks — but it is not in the declared token table.

---

### Pillar 6: Experience Design (3/4)

**What passes (code-review items resolved):**
- CR-01 (nested scroll in dialog) — fixed. `_DialogForm` StatefulWidget owns the controller; no outer `SingleChildScrollView` wraps the builder output.
- CR-02 (missing `isDialog: isDesktop` in CommitmentsScreen) — fixed. `commitments_screen.dart:34` explicitly passes `isDialog: isDesktop`.
- WR-01 (ScrollController leak) — fixed. `_DialogFormState.dispose()` calls `_sc.dispose()` (adaptive_form_modal.dart:82-84).
- WR-02 (no error handling in CommitmentFormSheet._save) — fixed. commitment_form_sheet.dart:112-123 wraps save in `try/catch` with snackbar.
- WR-03 (no time ordering guard) — fixed. `_canSave` now includes `_endMinutes > _startMinutes` (commitment_form_sheet.dart:100).
- IN-01 (ambiguous 'T'/'S' day labels) — fixed. Day labels are now `['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']` (commitment_form_sheet.dart:131).
- IN-02 (commitments body not constrained) — fixed. Both the empty state and the `ListView.builder` are wrapped in `Align + ConstrainedBox(maxWidth: 720)` (commitments_screen.dart:139-149).
- `barrierDismissible: true` on dialog (adaptive_form_modal.dart:31) — correct.
- `autofocus: !_isEditMode` on goal name TextField remains (goal_form_sheet.dart:215) — dialog receives focus on open in add mode.
- Error handling present in GoalFormSheet._save (goal_form_sheet.dart:103-109) — snackbar on failure.

**WARNING: Commitment form color cannot be changed by the user.** `_color` initializes to `'#607D8B'` for new blocks and reads from the existing block's `.color` for edits, but no UI element lets the user see or set it. For new commitments, every block gets the same blue-grey default regardless of intent. For existing commitments, the color visible on the list card cannot be changed. This is an incomplete feature presented to users as if it were complete (the color dot on the list card implies it is meaningful).

**WARNING: No loading state on Goals or Commitments notifier load.** `goals_screen.dart:25` and `commitments_screen.dart:23` trigger `loadGoals()` / `loadBlocks()` in `addPostFrameCallback`, but neither screen shows a loading indicator while the Hive box is being read. On first launch or cold start, the screen briefly shows the empty state before data arrives. This is a pre-existing issue and not introduced by phase 18.

**INFO: ChunkDetailSheet (schedule_screen.dart:271-283) still uses direct `showModalBottomSheet` instead of the adaptive helper.** The UI-SPEC explicitly marks this as out of scope for RESP-03 ("informational, action-button only, no text input, lower friction on desktop. Migrate if time permits; not required for RESP-03."). Noted for a future phase.

---

## Files Audited

- `lib/widgets/adaptive_form_modal.dart`
- `lib/screens/goals/goal_form_sheet.dart`
- `lib/screens/goals/goals_screen.dart`
- `lib/screens/commitments/commitment_form_sheet.dart`
- `lib/screens/commitments/commitments_screen.dart`
- `lib/screens/home/home_screen.dart`
- `lib/screens/schedule/schedule_screen.dart`
- `18-UI-SPEC.md` (design contract)
- `18-REVIEW.md` (code review findings — all 7 items verified resolved)
- `18-CONTEXT.md` (phase boundary and decisions)
