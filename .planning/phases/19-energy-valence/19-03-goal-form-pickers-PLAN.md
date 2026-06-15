---
phase: 19-energy-valence
plan: 03
type: execute
wave: 3
depends_on: ["19-02"]
files_modified:
  - lib/screens/goals/goal_form_sheet.dart
autonomous: true
requirements: [ENERGY-02, ENERGY-03]
must_haves:
  truths:
    - "Creating or editing a goal shows a gives/neutral/costs SegmentedButton; the chosen valence is saved (ENERGY-02)"
    - "A user can attach an emoji tag via a picker and clear it; it is saved on the goal (ENERGY-03)"
    - "Editing a goal pre-selects its persisted valence and shows its emoji tag"
  artifacts:
    - path: "lib/screens/goals/goal_form_sheet.dart"
      provides: "Energy section label + SegmentedButton<EnergyValence> + emoji picker affordance + _pickEmoji + emoji grid widget"
      contains: "SegmentedButton<EnergyValence>"
  key_links:
    - from: "lib/screens/goals/goal_form_sheet.dart (_save)"
      to: "Goal.energyValenceIndex / Goal.emojiTag"
      via: "cascade ..energyValenceIndex = _energyValence.index ..emojiTag = _emojiTag"
      pattern: "energyValenceIndex = _energyValence.index"
---

<objective>
Add the energy valence picker and emoji tag picker to the goal form (create + edit), and persist
both onto the Goal when the form saves (ENERGY-02, ENERGY-03).

Purpose: Let the user declare how a goal makes them feel and tag it with an emoji — the input
side of the valence feature.

Output: A goal form with an "Energy" SegmentedButton (gives/neutral/costs) and an emoji affordance,
both wired into _save(); goal_form_valence_test.dart flips from RED to GREEN.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/19-energy-valence/19-UI-SPEC.md
@.planning/phases/19-energy-valence/19-PATTERNS.md
@.planning/phases/19-energy-valence/19-RESEARCH.md

@lib/screens/goals/goal_form_sheet.dart
@lib/widgets/adaptive_form_modal.dart
</context>

<artifacts_this_plan_produces>
- `_GoalFormSheetState._energyValence` (EnergyValence, default neutral), `_emojiTag` (String?) — local form state
- "Energy" section label (labelMedium, onSurfaceVariant, **FontWeight.w400**) + `SegmentedButton<EnergyValence>` (Gives energy / Neutral / Costs energy)
- Emoji tag `OutlinedButton.icon` affordance (Add emoji / selected emoji + clear)
- `_pickEmoji()` method (inline showDialog desktop / showModalBottomSheet mobile via 720dp check)
- File-private emoji-grid picker widget(s) — 40-emoji `GridView.count(crossAxisCount: 8)`
- `_save()` cascade writes energyValenceIndex + emojiTag
</artifacts_this_plan_produces>

<tasks>

<task type="auto">
  <name>Task 1: Valence picker + state + save wiring (ENERGY-02)</name>
  <files>lib/screens/goals/goal_form_sheet.dart</files>
  <read_first>
    - 19-PATTERNS.md §"lib/screens/goals/goal_form_sheet.dart" (lines 532-637) — state fields, initState, _save cascade, valence section, exact insertion point (after name TextField + SizedBox(12), before Priority)
    - 19-PATTERNS.md §"SegmentedButton Section Label" (lines 939-955) — w400 NOT w500 label rule
    - 19-UI-SPEC.md §"Component Inventory 1. Valence Picker" (lines 132-153) + §Copywriting (lines 374-378)
    - 19-RESEARCH.md §"Goal Form Integration" (lines 358-403) — state init for edit vs add
  </read_first>
  <action>
    Add `import '../../data/models/energy_valence.dart';`. Add state `EnergyValence _energyValence =
    EnergyValence.neutral;`. In initState edit branch set `_energyValence = goal.energyValence;` (getter,
    never null); add branch leaves the neutral default. Insert the "Energy" section between the goal-name
    TextField (+ its SizedBox(height:12)) and the Priority label: a Row with a Text('Energy') styled
    labelMedium / onSurfaceVariant / **FontWeight.w400** (match the corrected Priority label — w400 NOT the
    M3-default w500, per the locked 2-weight contract), then a SegmentedButton<EnergyValence> with three
    segments — gives ("Gives energy", Icons.bolt), neutral ("Neutral", Icons.remove), costs ("Costs energy",
    Icons.hourglass_empty) — selected {_energyValence}, onSelectionChanged sets state, then SizedBox(height:8).
    In _save() append to the goal cascade `..energyValenceIndex = _energyValence.index`. Run dart format +
    flutter analyze.
  </action>
  <verify>
    <automated>grep -q 'SegmentedButton<EnergyValence>' lib/screens/goals/goal_form_sheet.dart && grep -q 'energyValenceIndex = _energyValence.index' lib/screens/goals/goal_form_sheet.dart && grep -q "Text(\s*'Energy'" lib/screens/goals/goal_form_sheet.dart && flutter test test/screens/goal_form_valence_test.dart -n "valence"</automated>
  </verify>
  <done>Energy SegmentedButton renders with w400 label; new goals default Neutral; edit pre-selects persisted valence; saving writes energyValenceIndex; valence portion of goal_form_valence_test passes.</done>
</task>

<task type="auto">
  <name>Task 2: Emoji tag picker + state + save wiring (ENERGY-03)</name>
  <files>lib/screens/goals/goal_form_sheet.dart</files>
  <read_first>
    - 19-PATTERNS.md §"goal_form_sheet.dart" emoji button + _pickEmoji (lines 639-680)
    - 19-UI-SPEC.md §"2. Emoji Tag Picker" (lines 154-174) — affordance states, grid spec, 40-emoji set (lines 166-171), "Choose an emoji" title
    - 19-RESEARCH.md §"Pitfall 4" (lines 481-488) — emoji picker opened from inside a modal must use showDialog/showModalBottomSheet directly, NOT showAdaptiveFormModal
    - 19-RESEARCH.md §"Security Domain" (lines 784-796) — emoji is from a fixed grid; no free-text; no characters package needed
    - lib/widgets/adaptive_form_modal.dart — the >=720dp breakpoint check to inline
  </read_first>
  <action>
    Add state `String? _emojiTag;`; in initState edit branch set `_emojiTag = goal.emojiTag;`. Insert the
    emoji affordance directly after the valence picker's SizedBox(height:8) and before the Priority label:
    when _emojiTag == null render `OutlinedButton.icon(icon: Icon(Icons.emoji_emotions_outlined),
    label: Text('Add emoji'), onPressed: _pickEmoji)`; when set render an OutlinedButton showing the emoji
    (titleMedium) plus a trailing IconButton(Icons.close) that clears _emojiTag; then SizedBox(height:8).
    Implement `_pickEmoji()`: inline `final isDesktop = MediaQuery.of(context).size.width >= 720;` then
    showDialog<String> (desktop) or showModalBottomSheet<String> (mobile) presenting a file-private emoji
    grid widget titled "Choose an emoji" (titleLarge, centered) using GridView.count(crossAxisCount: 8)
    over the hardcoded 40-emoji list from 19-UI-SPEC lines 166-171, each cell 44×44dp; tapping a cell pops
    with that emoji string; on non-null result setState(() => _emojiTag = picked). Do NOT use
    showAdaptiveFormModal (nested-modal pitfall). Append `..emojiTag = _emojiTag` to the _save() goal
    cascade. Keep emoji as single Dart string literals (UTF-8 source). Run dart format + flutter analyze.
  </action>
  <verify>
    <automated>grep -q '_pickEmoji' lib/screens/goals/goal_form_sheet.dart && grep -q 'emojiTag = _emojiTag' lib/screens/goals/goal_form_sheet.dart && grep -q 'GridView.count' lib/screens/goals/goal_form_sheet.dart && ! grep -q 'showAdaptiveFormModal' lib/screens/goals/goal_form_sheet.dart && flutter test test/screens/goal_form_valence_test.dart</automated>
  </verify>
  <done>Emoji affordance shows Add/selected/clear states; _pickEmoji opens a 40-emoji grid via showDialog/showModalBottomSheet (not showAdaptiveFormModal); saving writes emojiTag; full goal_form_valence_test.dart is GREEN.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user form input → persisted Goal | Valence (enum from a fixed SegmentedButton) and emojiTag (string from a fixed 40-cell grid) cross from UI into local Hive storage. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-19-04 | Tampering / Improper Input Validation (V5) | emojiTag value | accept | emojiTag is selected exclusively from a hardcoded 40-emoji grid — never free-text — so the stored value is always null or one of 40 known strings. No injection surface (local Hive only, no server/SQL), per 19-RESEARCH §Security Domain. No `characters` package or length check needed. |
| T-19-SC | Tampering | npm/pip/cargo installs | accept | No package installs in this phase (19-RESEARCH §Package Legitimacy Audit). |
</threat_model>

<verification>
- `flutter test test/screens/goal_form_valence_test.dart` — GREEN.
- `flutter analyze` clean; `dart format lib/` applied.
- Grep confirms showAdaptiveFormModal is NOT used for the in-form emoji picker.
</verification>

<success_criteria>
- ENERGY-02: valence selectable on create+edit and persisted via _save.
- ENERGY-03: emoji attachable/clearable on create+edit and persisted via _save.
- "Energy" label uses FontWeight.w400 (2-weight contract honored).
</success_criteria>

<output>
Create `.planning/phases/19-energy-valence/19-03-SUMMARY.md` when done.
</output>
