---
phase: 18-responsive-modals-and-desktop-polish
plan: 02
type: execute
wave: 1
depends_on: ["18-01"]
files_modified:
  - lib/widgets/adaptive_form_modal.dart
  - lib/screens/goals/goal_form_sheet.dart
  - lib/screens/goals/goals_screen.dart
autonomous: true
requirements: [RESP-01, RESP-02]
must_haves:
  truths:
    - "Opening Add/Edit goal at >= 720dp shows a centered Material Dialog; type picker, Priority, and Save are all visible without scrolling"
    - "Opening Add/Edit goal at < 720dp still shows the familiar bottom sheet"
    - "The goal form drag handle is hidden in dialog mode and visible in sheet mode"
  artifacts:
    - path: "lib/widgets/adaptive_form_modal.dart"
      provides: "showAdaptiveFormModal dialog-vs-sheet routing helper"
      exports: ["showAdaptiveFormModal"]
      min_lines: 30
    - path: "lib/screens/goals/goal_form_sheet.dart"
      provides: "GoalFormSheet with isDialog param (handle + padding gated)"
      contains: "this.isDialog"
    - path: "lib/screens/goals/goals_screen.dart"
      provides: "_openAddSheet/_openEditSheet routed through helper"
      contains: "showAdaptiveFormModal"
  key_links:
    - from: "lib/screens/goals/goals_screen.dart"
      to: "lib/widgets/adaptive_form_modal.dart"
      via: "import + showAdaptiveFormModal call in both open methods"
      pattern: "showAdaptiveFormModal"
    - from: "lib/widgets/adaptive_form_modal.dart"
      to: "MediaQuery breakpoint"
      via: "size.width >= 720 switch"
      pattern: "size\\.width >= 720"
---

<objective>
Build the shared `showAdaptiveFormModal` helper and route the goal add/edit callers through it. On desktop width (>= 720dp) the goal form renders as a centered, width-constrained Material Dialog with the drag handle hidden and no keyboard-inset padding; on phone width the existing bottom-sheet behavior is preserved exactly. This satisfies RESP-01 (adaptive routing) and RESP-02 (full goal form visible without scroll at desktop width).

Purpose: This is the core of Phase 18 — the helper every other modal caller will reuse, and the fix for the SEED-002 goal-form-desktop-layout nit.
Output: `lib/widgets/adaptive_form_modal.dart` (new); `goal_form_sheet.dart` and `goals_screen.dart` modified.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-RESEARCH.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-PATTERNS.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-UI-SPEC.md

# Files this plan modifies / mirrors
@lib/screens/goals/goal_form_sheet.dart
@lib/screens/goals/goals_screen.dart
@lib/widgets/responsive_shell.dart
@lib/screens/commitments/commitment_form_sheet.dart
</context>

<artifacts_this_phase_produces>
- NEW file: `lib/widgets/adaptive_form_modal.dart`
- NEW function: `showAdaptiveFormModal({required BuildContext context, required Widget Function(ScrollController scrollController) builder}) → Future<void>`
- NEW param: `GoalFormSheet({..., bool isDialog = false})` (and the `final bool isDialog;` field)
- Behavior: dialog interior wrapped in `ConstrainedBox(maxWidth: 560, maxHeight: screenHeight * 0.8)`; `Dialog(clipBehavior: Clip.antiAlias)`; barrierDismissible true
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create showAdaptiveFormModal helper</name>
  <files>lib/widgets/adaptive_form_modal.dart</files>
  <behavior>
    - At MediaQuery width >= 720: routes to showDialog → Dialog(clipBehavior: antiAlias) → ConstrainedBox(maxWidth: 560, maxHeight: screenHeight*0.8) → SingleChildScrollView(fresh ScrollController) → builder(controller). barrierDismissible: true.
    - At MediaQuery width < 720: routes to showModalBottomSheet(isScrollControlled: true, useSafeArea: true) → DraggableScrollableSheet(initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 1.0, expand: false, snap: true, snapSizes: [0.6, 1.0]) → builder(controller).
    - Verified by 18-01 adaptive_form_modal_test.dart cases 1, 2, 4.
  </behavior>
  <read_first>
    - 18-PATTERNS.md §`lib/widgets/adaptive_form_modal.dart` — full desktop+mobile reference implementation, breakpoint pattern, the "read screenHeight BEFORE showDialog" caution
    - 18-UI-SPEC.md §Adaptive Modal Contract — Helper API signature, 560dp/80%, corner radius 28 (Dialog default), barrierDismissible true
    - lib/widgets/responsive_shell.dart line 66 — the locked 720dp threshold this must match
    - lib/screens/goals/goals_screen.dart `_openAddSheet` — the exact DraggableScrollableSheet config to preserve on the mobile branch
  </read_first>
  <action>
    Create `lib/widgets/adaptive_form_modal.dart` with a single top-level async function `showAdaptiveFormModal` matching the UI-SPEC signature. Import only `package:flutter/material.dart`. Read `MediaQuery.of(context).size.width` and compare against 720 (same value as responsive_shell.dart line 66 — do NOT introduce a new constant per 18-RESEARCH §Don't Hand-Roll). Capture `screenHeight = MediaQuery.of(context).size.height` BEFORE calling showDialog (Pitfall 1 — reading height inside the Dialog builder uses the dialog's constraints, not the screen's). Desktop branch and mobile branch exactly as in 18-PATTERNS.md. Construct a fresh `ScrollController()` inside each branch's builder and pass it to `builder(scrollController)`. Do not add an unsaved-changes warning (UI-SPEC: dismiss without saving, unchanged).
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy &amp;&amp; export PATH="$HOME/development/flutter/bin:$PATH" &amp;&amp; flutter analyze lib/widgets/adaptive_form_modal.dart 2>&amp;1 | tail -10</automated>
  </verify>
  <acceptance_criteria>
    `flutter analyze lib/widgets/adaptive_form_modal.dart` clean; the file exports `showAdaptiveFormModal` with the UI-SPEC signature; 720 breakpoint and 560/80% constraints present.
  </acceptance_criteria>
  <done>Helper compiles, analyzer-clean, both branches present with correct constraints and breakpoint.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add isDialog to GoalFormSheet and route goal callers through the helper</name>
  <files>lib/screens/goals/goal_form_sheet.dart, lib/screens/goals/goals_screen.dart</files>
  <behavior>
    - GoalFormSheet gains `bool isDialog = false`. When isDialog: drag-handle Container hidden; bottom padding fixed at 24 (no viewInsets.bottom); horizontal/top padding 24.
    - When !isDialog: existing behavior unchanged (handle visible, viewInsets.bottom applied).
    - goals_screen `_openAddSheet`/`_openEditSheet` call `showAdaptiveFormModal`, passing `GoalFormSheet(scrollController: sc, isDialog: <desktop>)`. The helper signals dialog mode — see action for how isDialog is supplied.
    - Verified by 18-01 cases 1, 2, 3, 4 turning GREEN, AND existing test/screens/goal_form_priority_test.dart staying GREEN (isDialog default false preserves sheet behavior).
  </behavior>
  <read_first>
    - 18-PATTERNS.md §`lib/screens/goals/goal_form_sheet.dart` — exact constructor change, `if (!widget.isDialog)` handle wrap, padding ternary, preserved Navigator.pop and error-handling block
    - 18-PATTERNS.md §`lib/screens/goals/goals_screen.dart` — before/after `_openAddSheet`/`_openEditSheet`, the import to add
    - lib/screens/goals/goal_form_sheet.dart — current drag handle (~lines 154-165), viewInsets padding (~lines 143-149), autofocus on name field
    - 18-RESEARCH.md §Pitfall 3 (viewInsets leak), §Pitfall 6 (Navigator.pop resolves correctly in showDialog)
  </read_first>
  <action>
    In `goal_form_sheet.dart`: add `this.isDialog = false` to the constructor and `final bool isDialog;` field (per RESP-01). Wrap the drag-handle `Center(Container(40x4...))` in `if (!widget.isDialog)`. Change the content padding to `EdgeInsets.fromLTRB(24, 24, 24, widget.isDialog ? 24 : 16 + MediaQuery.of(context).viewInsets.bottom)`. Do NOT read viewInsets inside any dialog-only branch; the `isDialog` flag is the gate. Leave `Navigator.pop(context)`, the save error snackbar, and `autofocus: !_isEditMode` unchanged. Do NOT change copy strings in this plan — copy is 18-05.

    In `goals_screen.dart`: add `import '../../widgets/adaptive_form_modal.dart';`. Replace `_openAddSheet` and `_openEditSheet` bodies to call `showAdaptiveFormModal(context: context, builder: (sc) => GoalFormSheet(scrollController: sc, isDialog: <isDesktop>, goal: <goal-or-null>))`. To supply `isDialog`: compute desktop status at the call site with `MediaQuery.of(context).size.width >= 720` so the form knows which container it is in (this matches what the helper routes to — both use the same 720 read on the same context). Per RESP-02, the full form (type picker, Priority, Save) must be visible without scroll inside the 560/80% dialog — GoalTypePicker is `Column(mainAxisSize.min)` and needs no change.
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy &amp;&amp; export PATH="$HOME/development/flutter/bin:$PATH" &amp;&amp; flutter test test/screens/adaptive_form_modal_test.dart test/screens/goal_form_priority_test.dart 2>&amp;1 | tail -20</automated>
  </verify>
  <acceptance_criteria>
    18-01 adaptive_form_modal_test.dart RESP-01/02 cases pass (Dialog at 720, BottomSheet at 719, handle absent in dialog, ConstrainedBox 560 present); existing goal_form_priority_test.dart remains fully GREEN (isDialog default preserves sheet path).
  </acceptance_criteria>
  <done>GoalFormSheet has isDialog; goal callers route through the helper; new RESP tests pass and prior goal-form tests stay green.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | Widget-layer container swap; no new network, auth, secret, or persistence path. Form content/validation unchanged. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-02-V | Input Validation | GoalFormSheet save path | accept | Existing `_canSave` guard and save error snackbar are preserved unchanged; container swap does not alter input handling (18-RESEARCH §Security Domain: V5 carry-forward, no new surface). |
| T-18-02-I | Information Disclosure | barrierDismissible dialog | accept | Dialog shows same data the goals screen already renders; no new exposure. ASVS V4 not applicable. |
| T-18-SC | Tampering | npm/pip/cargo installs | accept | No package installs — Flutter SDK widgets only (18-RESEARCH §Package Legitimacy Audit: N/A). |
</threat_model>

<verification>
- `flutter test test/screens/adaptive_form_modal_test.dart` RESP-01/02 cases GREEN.
- `flutter test test/screens/goal_form_priority_test.dart` GREEN (no regression).
- `flutter analyze` clean for the three modified/created files.
- Per VALIDATION.md per-task sampling: `flutter test test/screens/adaptive_form_modal_test.dart test/screens/content_width_constraint_test.dart` after each commit.
</verification>

<success_criteria>
At >= 720dp the goal form opens as a centered 560dp dialog with type picker, Priority, and Save all visible without scroll and the drag handle hidden; at < 720dp the familiar bottom sheet is unchanged. RESP-01 and RESP-02 tests GREEN; no regression in existing goal-form tests.
</success_criteria>

<output>
Create `.planning/phases/18-responsive-modals-and-desktop-polish/18-02-SUMMARY.md` when done.
</output>
