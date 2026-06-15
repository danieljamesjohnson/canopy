---
phase: 18-responsive-modals-and-desktop-polish
plan: 01
type: execute
wave: 0
depends_on: []
files_modified:
  - test/screens/adaptive_form_modal_test.dart
  - test/screens/content_width_constraint_test.dart
  - test/screens/goal_form_copy_test.dart
autonomous: true
requirements: [RESP-01, RESP-02, RESP-03, POLISH-01, POLISH-02]
must_haves:
  truths:
    - "Three new test files exist and are discovered by `flutter test`"
    - "Each test references the symbols the implementation waves will create (showAdaptiveFormModal, isDialog, 560/720 ConstrainedBox, new copy)"
    - "Tests fail (RED) for the right reason — missing symbols/behavior, not import or compile typos"
  artifacts:
    - path: "test/screens/adaptive_form_modal_test.dart"
      provides: "RESP-01/02/03 dialog-vs-sheet behavior tests"
      contains: "showAdaptiveFormModal"
    - path: "test/screens/content_width_constraint_test.dart"
      provides: "POLISH-01 content-width constraint tests"
      contains: "maxWidth == 720"
    - path: "test/screens/goal_form_copy_test.dart"
      provides: "POLISH-02 copy-label tests"
      contains: "Add Goal"
  key_links:
    - from: "test/screens/adaptive_form_modal_test.dart"
      to: "lib/widgets/adaptive_form_modal.dart"
      via: "import + showAdaptiveFormModal call"
      pattern: "showAdaptiveFormModal"
---

<objective>
Create the Wave 0 test scaffolds (RED) that the Phase 18 implementation plans must turn GREEN. Per 18-VALIDATION.md, every implementation task verifies against these three files. They must exist and fail for the right reason before any implementation begins.

Purpose: Nyquist compliance — no implementation task ships without an automated proxy already in place. This is the failing-first half of the loop.
Output: `test/screens/adaptive_form_modal_test.dart`, `test/screens/content_width_constraint_test.dart`, `test/screens/goal_form_copy_test.dart`.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-VALIDATION.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-PATTERNS.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-UI-SPEC.md

# Test analog files (read for exact patterns — pump helpers, in-memory repos, Scrollable.first)
@test/screens/goal_form_priority_test.dart
@test/screens/responsive_layout_test.dart
@test/test_helpers/viewport.dart
@test/test_helpers/mood_pump.dart
</context>

<artifacts_this_phase_produces>
This plan does NOT produce production symbols — it consumes the symbols later plans create, so the references below MUST match the contracts in 18-02/03/04/05 exactly:

- `showAdaptiveFormModal({required BuildContext context, required Widget Function(ScrollController) builder})` → `lib/widgets/adaptive_form_modal.dart` (created in 18-02)
- `GoalFormSheet(..., bool isDialog = false)` → `lib/screens/goals/goal_form_sheet.dart` (param added in 18-02)
- `CommitmentFormSheet(..., bool isDialog = false)` → `lib/screens/commitments/commitment_form_sheet.dart` (param added in 18-03)
- Dialog interior `ConstrainedBox(maxWidth: 560)` (18-02)
- Primary screen body `ConstrainedBox(maxWidth: 720)` on home + goals + schedule (18-04)
- Copy labels "Add Goal" / "Save Goal" / "Discard" / "Archive goal" (goal form, 18-05), "Delete commitment" / "Keep commitment" (commitment delete dialog, 18-05)
</artifacts_this_phase_produces>

<tasks>

<task type="auto">
  <name>Task 1: Create adaptive_form_modal_test.dart (RESP-01/02/03 RED stubs)</name>
  <files>test/screens/adaptive_form_modal_test.dart</files>
  <read_first>
    - test/screens/goal_form_priority_test.dart — copy `_pumpModal` structure, the in-memory GoalRepository stub, and the `find.byType(Scrollable).first` comment/pattern verbatim
    - test/test_helpers/viewport.dart — use `setViewport(tester, size)`, never `tester.view.physicalSize` directly (auto-teardown)
    - test/test_helpers/mood_pump.dart — use `pumpWithMood(tester, child, extraProviders: [...])`
    - 18-PATTERNS.md §`test/screens/adaptive_form_modal_test.dart` — `_pumpAdaptiveModal` helper, Dialog/BottomSheet assertions, ConstrainedBox(560) assertion
  </read_first>
  <action>
    Create the test file importing `package:canopy/widgets/adaptive_form_modal.dart` (does not exist yet — RED), `GoalFormSheet`, `CommitmentFormSheet`, the notifiers, and the test helpers. Build a `_pumpAdaptiveModal(tester, viewport, builder)` helper modeled on `_pumpModal` in goal_form_priority_test.dart: pump a Builder via `pumpWithMood` to capture a BuildContext, call `showAdaptiveFormModal` WITHOUT awaiting (the Future only resolves on dismiss), then `pumpAndSettle`. Stub an in-memory GoalRepository and CommitmentsNotifier as needed.

    Write these test cases (RESP-01/02/03):
    1. RESP-01: at `setViewport(tester, const Size(720, 900))`, opening goal form via helper → `find.byType(Dialog)` findsOneWidget AND `find.byType(BottomSheet)` findsNothing.
    2. RESP-01: at `setViewport(tester, const Size(719, 900))` (just under breakpoint) → `find.byType(BottomSheet)` findsOneWidget AND `find.byType(Dialog)` findsNothing.
    3. RESP-02: at 720dp, the dialog goal form shows the type picker, the Priority control, and the Save/Add button without requiring scroll; assert the drag-handle Container (40x4) is absent inside the Dialog. Use `find.byType(Scrollable).first` if any scroll is needed.
    4. RESP-02: the Dialog contains a `ConstrainedBox` with `constraints.maxWidth == 560.0` (use `find.descendant(of: find.byType(Dialog), matching: find.byType(ConstrainedBox))`).
    5. RESP-03: at 720dp, opening the commitment form via the helper → `find.byType(Dialog)` findsOneWidget (commitment caller routes through the same helper).

    Cite RESP-01/RESP-02/RESP-03 in test group descriptions. Do NOT inline any production implementation. Tests are expected to FAIL on the missing `adaptive_form_modal.dart` import — that is correct RED state.
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy &amp;&amp; export PATH="$HOME/development/flutter/bin:$PATH" &amp;&amp; flutter test test/screens/adaptive_form_modal_test.dart 2>&amp;1 | tail -20; test -f test/screens/adaptive_form_modal_test.dart</automated>
  </verify>
  <acceptance_criteria>
    File exists; `flutter test` discovers it and reports failures referencing the missing `adaptive_form_modal.dart`/`showAdaptiveFormModal` (RED for the right reason), not a malformed-test/analyzer error in the test scaffolding itself.
  </acceptance_criteria>
  <done>adaptive_form_modal_test.dart exists with 5 RESP-tagged cases; fails because showAdaptiveFormModal does not exist yet.</done>
</task>

<task type="auto">
  <name>Task 2: Create content_width_constraint_test.dart and goal_form_copy_test.dart (POLISH-01/02 RED stubs)</name>
  <files>test/screens/content_width_constraint_test.dart, test/screens/goal_form_copy_test.dart</files>
  <read_first>
    - test/screens/responsive_layout_test.dart — `_pumpShellAt` pattern, breakpoint-assertion structure, minimal router/provider stubs
    - test/screens/goal_form_priority_test.dart — `_pumpForm`/`_pumpModal` and in-memory repo stub for pumping the goal form directly
    - 18-PATTERNS.md §`test/screens/content_width_constraint_test.dart` — `boxes.any((b) => b.constraints.maxWidth == 720.0)` assertion idiom
    - 18-UI-SPEC.md §Copywriting Contract — exact FIX strings ("Add Goal", "Save Goal", "Discard", "Archive goal", "Delete commitment", "Keep commitment")
  </read_first>
  <action>
    content_width_constraint_test.dart (POLISH-01): set a desktop viewport (`setViewport(tester, const Size(1024, 768))`), pump each screen under test with minimal provider stubs, and assert a `ConstrainedBox(maxWidth: 720)` is present in the body. Cases:
    1. Goals screen body contains a ConstrainedBox whose `constraints.maxWidth == 720.0`.
    2. Home screen body contains a ConstrainedBox whose `constraints.maxWidth == 720.0`.
    3. Schedule screen: the ListView region is wrapped in a ConstrainedBox(maxWidth: 720) while the ScheduleProgressBar stays full-width (assert at least one ConstrainedBox(720) under the body; if a clean stub for schedule state is impractical, mark this single case `skip:` with a TODO citing 18-04, but keep goals+home asserting). Use `widgetList<ConstrainedBox>(...).any(...)`.

    goal_form_copy_test.dart (POLISH-02): pump GoalFormSheet directly (add mode and edit mode) and assert the FIX copy from UI-SPEC:
    1. Add mode: title "Add Goal" and primary CTA "Add Goal" present.
    2. Edit mode: title "Edit Goal" and primary CTA "Save Goal" present; "Discard" TextButton present; "Archive goal" present.
    3. Commitment delete confirm copy: assert "Delete commitment" and "Keep commitment" labels (pump commitments_screen delete dialog, or assert on the strings via the confirm AlertDialog). If pumping the full delete flow is heavy, target the dialog directly.

    Cite POLISH-01 / POLISH-02 in group descriptions. These fail (RED) because the constraints and copy changes do not exist yet.
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy &amp;&amp; export PATH="$HOME/development/flutter/bin:$PATH" &amp;&amp; flutter test test/screens/content_width_constraint_test.dart test/screens/goal_form_copy_test.dart 2>&amp;1 | tail -20; test -f test/screens/content_width_constraint_test.dart &amp;&amp; test -f test/screens/goal_form_copy_test.dart</automated>
  </verify>
  <acceptance_criteria>
    Both files exist and are discovered by `flutter test`; failures are assertion failures on missing constraints/copy (RED for the right reason), not analyzer/compile errors in the test scaffolding.
  </acceptance_criteria>
  <done>Both POLISH test files exist with the cases above; fail because 720dp constraints and FIX copy are not yet implemented.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | This plan adds test files only — no runtime trust boundary is crossed |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-01 | Tampering | Test code at rest | accept | Test-only files; no production code path, no input, no persistence. ASVS V5 not applicable per 18-RESEARCH.md Security Domain. |
| T-18-SC | Tampering | npm/pip/cargo installs | accept | No package installs in this phase — pure Flutter SDK widgets/tests (18-RESEARCH §Package Legitimacy Audit: N/A). No install task exists. |
</threat_model>

<verification>
- `flutter test` discovers all three new files.
- The three files fail (RED) for missing-symbol / missing-behavior reasons, not scaffolding errors.
- `flutter analyze` reports no errors in the new test files beyond the expected missing-import (which resolves once 18-02 lands).
</verification>

<success_criteria>
Three test files exist, are discovered, and are RED for the right reason — ready for 18-02/03/04/05 to turn GREEN.
</success_criteria>

<output>
Create `.planning/phases/18-responsive-modals-and-desktop-polish/18-01-SUMMARY.md` when done.
</output>
