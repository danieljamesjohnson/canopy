---
phase: 18-responsive-modals-and-desktop-polish
plan: 03
type: execute
wave: 2
depends_on: ["18-02"]
files_modified:
  - lib/screens/commitments/commitment_form_sheet.dart
  - lib/screens/commitments/commitments_screen.dart
autonomous: true
requirements: [RESP-03]
must_haves:
  truths:
    - "Commitment add/edit opens as a centered dialog at >= 720dp and as a bottom sheet at < 720dp"
    - "No user-facing form caller invokes showModalBottomSheet directly — all route through showAdaptiveFormModal"
    - "Commitment form drag handle hidden in dialog mode; padding has no keyboard inset in dialog mode"
  artifacts:
    - path: "lib/screens/commitments/commitment_form_sheet.dart"
      provides: "CommitmentFormSheet with isDialog param (handle + padding gated)"
      contains: "this.isDialog"
    - path: "lib/screens/commitments/commitments_screen.dart"
      provides: "_openAddSheet routed through showAdaptiveFormModal"
      contains: "showAdaptiveFormModal"
  key_links:
    - from: "lib/screens/commitments/commitments_screen.dart"
      to: "lib/widgets/adaptive_form_modal.dart"
      via: "import + showAdaptiveFormModal in _openAddSheet"
      pattern: "showAdaptiveFormModal"
---

<objective>
Route the commitment add/edit caller through the shared `showAdaptiveFormModal` helper built in 18-02, and add the `isDialog` parameter to `CommitmentFormSheet` so it renders correctly in both dialog and sheet containers. This satisfies RESP-03: commitment forms (and every user-facing form) use the same adaptive helper — no caller renders a cramped phone sheet on desktop.

Purpose: Complete the modal-routing migration. `ChunkDetailSheet` and the delete `AlertDialog` are explicitly out of scope (18-RESEARCH / UI-SPEC).
Output: `commitment_form_sheet.dart` and `commitments_screen.dart` modified.
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

# The helper this plan consumes (from 18-02) and the goal-form mirror
@lib/widgets/adaptive_form_modal.dart
@lib/screens/goals/goal_form_sheet.dart
@lib/screens/commitments/commitment_form_sheet.dart
@lib/screens/commitments/commitments_screen.dart
</context>

<artifacts_this_phase_produces>
- NEW param: `CommitmentFormSheet({..., bool isDialog = false})` (and the `final bool isDialog;` field)
- Behavior: commitments `_openAddSheet` calls `showAdaptiveFormModal` (handles both add and edit via the optional `block` param)
- NOTE: this plan does NOT add the "Discard" button or change delete-dialog copy — those are POLISH-02 copy fixes in 18-05. Keep the existing save-only button here.
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add isDialog to CommitmentFormSheet and route the commitment caller through the helper</name>
  <files>lib/screens/commitments/commitment_form_sheet.dart, lib/screens/commitments/commitments_screen.dart</files>
  <behavior>
    - CommitmentFormSheet gains `bool isDialog = false`. When isDialog: drag-handle Container hidden; padding uses fixed values (no `viewInsetsOf(context).bottom`); top/bottom 24.
    - When !isDialog: existing behavior unchanged (handle visible, viewInsets applied, top 8 / bottom 32).
    - commitments_screen `_openAddSheet([CommitmentBlock? block])` calls `showAdaptiveFormModal`, passing `CommitmentFormSheet(scrollController: sc, block: block, isDialog: <desktop>)`.
    - Verified by 18-01 adaptive_form_modal_test.dart RESP-03 case (Dialog at 720dp via commitment caller) turning GREEN; existing commitment-related tests stay GREEN.
  </behavior>
  <read_first>
    - 18-PATTERNS.md §`lib/screens/commitments/commitment_form_sheet.dart` — exact constructor change, `if (!widget.isDialog)` handle wrap, the padding ternary (`widget.isDialog ? 24 : 8` top, `widget.isDialog ? 24 : 32 + MediaQuery.viewInsetsOf(context).bottom`), preserved `Navigator.of(context).pop()`
    - 18-PATTERNS.md §`lib/screens/commitments/commitments_screen.dart` — before/after `_openAddSheet`, the import to add
    - lib/widgets/adaptive_form_modal.dart — the helper signature created in 18-02
    - lib/screens/goals/goal_form_sheet.dart — the isDialog pattern already applied in 18-02 (mirror it)
  </read_first>
  <action>
    In `commitment_form_sheet.dart`: add `this.isDialog = false` to the constructor and `final bool isDialog;` field (per RESP-03). Wrap the drag-indicator `Center(Container(40x4...))` in `if (!widget.isDialog)`. Change the content padding ternary exactly as in 18-PATTERNS.md so dialog mode uses fixed padding with no `MediaQuery.viewInsetsOf(context).bottom`. Preserve the `if (mounted) Navigator.of(context).pop()` on save (resolves correctly inside showDialog per 18-RESEARCH §Pitfall 6). Do NOT add a Discard button and do NOT change any copy here — that is 18-05.

    In `commitments_screen.dart`: add `import '../../widgets/adaptive_form_modal.dart';`. Replace `_openAddSheet([CommitmentBlock? block])` to call `showAdaptiveFormModal(context: context, builder: (sc) => CommitmentFormSheet(scrollController: sc, block: block, isDialog: MediaQuery.of(context).size.width >= 720))`. Compute `isDialog` from the same 720 read on the caller context (consistent with the helper's routing and with 18-02's goal-form approach). Do NOT touch `_confirmDelete` / its AlertDialog in this plan.
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy &amp;&amp; export PATH="$HOME/development/flutter/bin:$PATH" &amp;&amp; flutter test test/screens/adaptive_form_modal_test.dart 2>&amp;1 | tail -20 &amp;&amp; flutter analyze lib/screens/commitments/commitment_form_sheet.dart lib/screens/commitments/commitments_screen.dart 2>&amp;1 | tail -8</automated>
  </verify>
  <acceptance_criteria>
    18-01 RESP-03 case (commitment form → Dialog at 720dp) GREEN; analyzer clean for both modified files; no `showModalBottomSheet` call remains in commitments_screen for the form caller (the helper owns that now); delete AlertDialog untouched.
  </acceptance_criteria>
  <done>CommitmentFormSheet has isDialog; commitment caller routes through the helper; RESP-03 test GREEN; delete dialog and copy untouched.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | Container swap for an existing form; no new network/auth/secret/persistence path. Existing `_canSave` validation preserved. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-03-V | Input Validation | CommitmentFormSheet save path | accept | Existing `_canSave` guard preserved; container swap does not change input handling (18-RESEARCH §Security Domain: V5 carry-forward). |
| T-18-SC | Tampering | npm/pip/cargo installs | accept | No package installs — Flutter SDK widgets only (18-RESEARCH §Package Legitimacy Audit: N/A). |
</threat_model>

<verification>
- `flutter test test/screens/adaptive_form_modal_test.dart` RESP-03 case GREEN.
- `flutter analyze` clean for both modified files.
- Existing commitment tests (if any touch the form) stay GREEN; run `flutter test` at wave merge.
</verification>

<success_criteria>
Commitment add/edit opens as a centered dialog at >= 720dp and the familiar sheet at < 720dp; every user-facing form now routes through showAdaptiveFormModal. RESP-03 satisfied.
</success_criteria>

<output>
Create `.planning/phases/18-responsive-modals-and-desktop-polish/18-03-SUMMARY.md` when done.
</output>
