---
phase: 18-responsive-modals-and-desktop-polish
plan: 05
type: execute
wave: 3
depends_on: ["18-02", "18-03", "18-04"]
files_modified:
  - lib/screens/goals/goal_form_sheet.dart
  - lib/screens/commitments/commitment_form_sheet.dart
  - lib/screens/commitments/commitments_screen.dart
autonomous: false
requirements: [POLISH-02]
must_haves:
  truths:
    - "Goal form shows context-specific copy: 'Add Goal'/'Edit Goal' titles, 'Add Goal'/'Save Goal' CTA, 'Discard', 'Archive goal'"
    - "Commitment form has a 'Discard' TextButton above the save button"
    - "Commitment delete confirm uses 'Delete commitment' / 'Keep commitment'"
    - "A fresh desktop walkthrough is performed at >= 720dp and high-friction nits are triaged (fixed or logged)"
  artifacts:
    - path: "lib/screens/goals/goal_form_sheet.dart"
      provides: "POLISH-02 goal form copy fixes"
      contains: "Save Goal"
    - path: "lib/screens/commitments/commitment_form_sheet.dart"
      provides: "Discard TextButton + copy"
      contains: "Discard"
    - path: "lib/screens/commitments/commitments_screen.dart"
      provides: "delete-confirm copy fixes"
      contains: "Keep commitment"
  key_links:
    - from: "lib/screens/goals/goal_form_sheet.dart"
      to: "18-01 goal_form_copy_test.dart"
      via: "string literals matching test expectations"
      pattern: "Save Goal"
---

<objective>
Apply the POLISH-02 copy fixes from the approved UI-SPEC Copywriting Contract, add the missing "Discard" button to the commitment form, and perform the fresh desktop walkthrough that triages high-friction UI nits at >= 720dp. This is the polish wave — sequenced last because it touches files owned by 18-02 (goal_form_sheet) and 18-03 (commitment files), and because the walkthrough should evaluate the fully-assembled responsive behavior.

Purpose: Close POLISH-02 — context-specific copy plus a real desktop pass surfacing and fixing high-friction nits, per CLAUDE.md's debug-web-build UAT protocol.
Output: copy edits in three files + the walkthrough triage log captured in the SUMMARY (and any high-friction fixes applied).
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-UI-SPEC.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-PATTERNS.md
@.planning/phases/18-responsive-modals-and-desktop-polish/18-RESEARCH.md

# Files this plan modifies
@lib/screens/goals/goal_form_sheet.dart
@lib/screens/commitments/commitment_form_sheet.dart
@lib/screens/commitments/commitments_screen.dart

# Project UAT protocol (debug web build, fresh port, real GPU browser)
@CLAUDE.md
</context>

<artifacts_this_phase_produces>
- Copy: goal form titles "Add Goal"/"Edit Goal"; CTA "Add Goal" (add) / "Save Goal" (edit); cancel → "Discard"; archive → "Archive goal" (TextButton, error color)
- Copy: commitment form cancel → new "Discard" TextButton above the save FilledButton (both add and edit paths)
- Copy: commitment delete confirm → "Delete commitment" (confirm) / "Keep commitment" (cancel)
- Artifact: desktop walkthrough triage table (screen / element / problem / fix / friction-rating) captured in 18-05-SUMMARY.md
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Apply POLISH-02 copy fixes and add commitment Discard button</name>
  <files>lib/screens/goals/goal_form_sheet.dart, lib/screens/commitments/commitment_form_sheet.dart, lib/screens/commitments/commitments_screen.dart</files>
  <behavior>
    - goal_form_sheet: title `_isEditMode ? 'Edit Goal' : 'Add Goal'`; primary CTA `_isEditMode ? 'Save Goal' : 'Add Goal'`; cancel label 'Discard'; archive label 'Archive goal'.
    - commitment_form_sheet: a 'Discard' TextButton added above the existing FilledButton (both add and edit modes); existing CTA labels 'Add commitment' / 'Save changes' unchanged (locked).
    - commitments_screen delete AlertDialog: cancel 'Keep commitment', confirm 'Delete commitment'.
    - Verified by 18-01 goal_form_copy_test.dart turning GREEN.
  </behavior>
  <read_first>
    - 18-UI-SPEC.md §Copywriting Contract — the authoritative FIX vs locked table (do NOT change rows marked locked; only apply FIX rows)
    - 18-PATTERNS.md §goal_form_sheet (title/button copy), §commitment_form_sheet (Discard button structure), §commitments_screen (delete dialog before/after)
    - 18-RESEARCH.md §Open Questions #1 — add Discard to commitment form in both paths (3-line addition)
    - lib/screens/goals/goal_form_sheet.dart — current title (~line 168), CTA/Cancel/Archive buttons near bottom of build()
    - lib/screens/commitments/commitment_form_sheet.dart — current save-only FilledButton block
    - lib/screens/commitments/commitments_screen.dart — `_confirmDelete` AlertDialog (~lines 48-62)
  </read_first>
  <action>
    Apply the UI-SPEC FIX copy exactly (per POLISH-02). goal_form_sheet.dart: change the title Text to `_isEditMode ? 'Edit Goal' : 'Add Goal'`; the primary CTA label to `_isEditMode ? 'Save Goal' : 'Add Goal'`; the Cancel TextButton label to 'Discard'; the Archive TextButton label to 'Archive goal' (keep its error color). commitment_form_sheet.dart: add a `TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Discard'))` with an `SizedBox(height: 8)` above the existing save FilledButton, in both add and edit modes; leave the FilledButton labels ('Add commitment' / 'Save changes') unchanged (locked). commitments_screen.dart: in the delete confirm AlertDialog, change the cancel TextButton to 'Keep commitment' and the confirm to 'Delete commitment'. Do NOT change any row the UI-SPEC marks locked. Run `dart format lib/` after edits (CLAUDE.md).
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy &amp;&amp; export PATH="$HOME/development/flutter/bin:$PATH" &amp;&amp; flutter test test/screens/goal_form_copy_test.dart 2>&amp;1 | tail -20</automated>
  </verify>
  <acceptance_criteria>
    goal_form_copy_test.dart GREEN (all FIX copy + commitment delete copy assertions pass); commitment form has a Discard button; locked labels unchanged; `flutter analyze` clean for all three files.
  </acceptance_criteria>
  <done>All POLISH-02 copy fixes applied per UI-SPEC; commitment Discard button added; copy test GREEN.</done>
</task>

<task type="auto">
  <name>Task 2: Full suite green + build debug web bundle and capture walkthrough triage</name>
  <files>(no source edits unless a high-friction fix is found — then list them in the SUMMARY)</files>
  <read_first>
    - CLAUDE.md "Local hosting for UAT" — `flutter build web --debug --source-maps --pwa-strategy=none`, serve via `python3 -m http.server <port> --bind 0.0.0.0` on a FRESH port never used for a release build; verify in a real GPU-backed browser (the two blank-page traps)
    - 18-UI-SPEC.md §POLISH-02 Audit Scope — the 4-step walkthrough protocol and the known pre-identified nit (goal-form-desktop-layout, resolved by 18-02)
    - 18-VALIDATION.md §Manual-Only Verifications — desktop walkthrough is the one manual verification
  </read_first>
  <action>
    First run the full suite green: `flutter test` and `flutter analyze`. Then build the debug single-bundle web build per CLAUDE.md (`flutter build web --debug --source-maps --pwa-strategy=none`) and serve it on a fresh, never-release port via `python3 -m http.server <port> --bind 0.0.0.0`. At >= 720dp, walk Home → Schedule → Goals → Check-in plus the goal and commitment modal forms (dialog mode). Log each friction point as (screen, element, observed problem, proposed fix, friction rating). Confirm the known nit (goal form was a cramped desktop sheet) is resolved. Apply fixes ONLY for items rated high-friction (blocks a task or visible layout breakage); defer low-friction nits to a later phase with a note. Record the full triage table and any fixes in the SUMMARY. Use a real GPU-backed browser, not headless Chromium (CONTEXT_LOST_WEBGL false alarm).
  </action>
  <verify>
    <human-check>
      Build served at http://danserver:&lt;port&gt;/ in a real browser at desktop width. Confirm: (1) goal Add/Edit opens as a centered dialog with type picker + Priority + Save visible without scroll; (2) commitment Add/Edit opens as a centered dialog; (3) Home/Schedule/Goals content is a centered ~720dp column, not full-bleed; (4) walkthrough triage table is captured in the SUMMARY with high-friction items fixed. Reply "approved" or list issues.
    </human-check>
  </verify>
  <acceptance_criteria>
    `flutter test` and `flutter analyze` fully green; debug web build serves and renders at desktop width in a real browser; triage table recorded; high-friction nits fixed (or none found, stated explicitly); user approves.
  </acceptance_criteria>
  <done>Full suite green, debug web build verified at desktop width, walkthrough triaged, high-friction nits fixed, user sign-off captured.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | String-literal copy changes + a manual walkthrough; no data, network, auth, or persistence change. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-05-I | Information Disclosure | UAT debug web build | accept | Debug build with source maps is served only on the tailnet/LAN (no public exposure per danserver operating guide), fresh port, for UAT — not a production artifact. |
| T-18-SC | Tampering | npm/pip/cargo installs | accept | No package installs — copy edits + `flutter build web` only (18-RESEARCH §Package Legitimacy Audit: N/A). |
</threat_model>

<verification>
- `flutter test test/screens/goal_form_copy_test.dart` GREEN.
- `flutter test` full suite + `flutter analyze` clean (phase gate).
- Manual: debug web build walkthrough at >= 720dp in a real browser; triage table in SUMMARY.
</verification>

<success_criteria>
Context-specific copy applied per UI-SPEC; commitment Discard button present; delete confirm uses Keep/Delete commitment; full suite green; a real desktop walkthrough is done with high-friction nits triaged and fixed. POLISH-02 satisfied.
</success_criteria>

<output>
Create `.planning/phases/18-responsive-modals-and-desktop-polish/18-05-SUMMARY.md` when done — include the desktop walkthrough triage table.
</output>
