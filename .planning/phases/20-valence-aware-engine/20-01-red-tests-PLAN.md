---
phase: 20-valence-aware-engine
plan: 01
type: tdd
wave: 1
depends_on: []
files_modified:
  - test/services/schedule_generator_test.dart
autonomous: true
requirements: [VSCHED-01, VSCHED-02, VSCHED-03]
must_haves:
  truths:
    - "The 47 existing schedule_generator tests still pass after helper signatures change (default valence keeps them green)"
    - "New VSCHED-01/02/03 + determinism test blocks exist and FAIL (RED) against the unchanged engine"
    - "makeTimeTarget and makeOutcome accept a valence param defaulting to EnergyValence.neutral"
  artifacts:
    - path: "test/services/schedule_generator_test.dart"
      provides: "RED VSCHED-01/02/03 + determinism test blocks; valence param on makeTimeTarget/makeOutcome; energy_valence import"
      contains: "EnergyValence.gives"
  key_links:
    - from: "test/services/schedule_generator_test.dart"
      to: "package:canopy/data/models/energy_valence.dart"
      via: "import + EnergyValence.gives/neutral in helpers and tests"
      pattern: "import.*energy_valence"
---

<objective>
Wave 0 (RED): Add deterministic failing tests for all three Phase 20 engine behaviors and extend the existing test helpers with an `EnergyValence` valence parameter — WITHOUT touching the engine. The new tests must FAIL against the current `schedule_generator.dart` (proving they exercise real new behavior); the 47 existing tests must stay GREEN (proving the helper change is backward-compatible).

Purpose: Establish the executable contract for VSCHED-01/02/03 before the engine change (Plan 20-02) implements them. This is the RED half of RED→GREEN.
Output: Extended test helpers + 7 new failing `test()` blocks appended to `test/services/schedule_generator_test.dart`.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/phases/20-valence-aware-engine/20-RESEARCH.md
@.planning/phases/20-valence-aware-engine/20-PATTERNS.md
@.planning/phases/20-valence-aware-engine/20-VALIDATION.md

# Files this plan reads/edits
@test/services/schedule_generator_test.dart
@lib/data/models/energy_valence.dart
</context>

<artifacts_this_phase_produces>
This plan (Wave 0) produces, in `test/services/schedule_generator_test.dart`:
- A new import: `import 'package:canopy/data/models/energy_valence.dart';`
- `valence` param (default `EnergyValence.neutral`) added to `makeTimeTarget(...)`, wired to `energyValenceIndex: valence.index`
- `valence` param (default `EnergyValence.neutral`) added to `makeOutcome(...)`, wired to `energyValenceIndex: valence.index`
- 7 new RED `test()` blocks (see task), each with a `VSCHED-01` / `VSCHED-02` / `VSCHED-03` / `determinism` name substring matchable by `--name`

(Plan 20-02 produces the engine-side symbols: the energy_valence import in the generator, hoisted `placedCountPerGoal`, the `restorativeFloor` restorative sub-pass, and the VSCHED-03 reservation pass.)
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Extend test helpers with a valence param (backward-compatible)</name>
  <files>test/services/schedule_generator_test.dart</files>
  <read_first>
    - 20-PATTERNS.md "Test file — new test() blocks" → helper pattern (test file lines 24–62) and the EXTENDED helper bodies to copy verbatim
    - Existing helpers `makeHabit`/`makeOutcome`/`makeTimeTarget` at test/services/schedule_generator_test.dart lines 24–62 (read in current file)
    - lib/data/models/energy_valence.dart → confirm enum order `neutral=0, gives=1, costs=2` and the constructor field name `energyValenceIndex` on Goal
  </read_first>
  <action>
    Add `import 'package:canopy/data/models/energy_valence.dart';` to the test file's import block (alongside the existing `goal.dart` import).

    Add a named param `EnergyValence valence = EnergyValence.neutral` to BOTH `makeTimeTarget(...)` and `makeOutcome(...)`, and pass `energyValenceIndex: valence.index` into the `Goal(...)` constructor inside each. Do NOT add it to `makeHabit` (VSCHED behaviors do not touch habits — keep helper surface minimal per RESEARCH Pitfall 5).

    The default `EnergyValence.neutral` (index 0) preserves the unset-field behavior, so the 47 existing tests compile and pass unchanged. Do NOT modify any existing `test()` block in this task.
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy && /home/dan/development/flutter/bin/flutter test test/services/schedule_generator_test.dart</automated>
  </verify>
  <acceptance_criteria>
    - `energy_valence.dart` is imported in the test file
    - `makeTimeTarget` and `makeOutcome` accept `valence` (default `EnergyValence.neutral`) and forward `energyValenceIndex: valence.index`
    - `makeHabit` is unchanged
    - All 47 pre-existing tests still pass GREEN (helper change is backward-compatible)
  </acceptance_criteria>
  <done>The test file compiles, helpers accept valence, and the full existing suite in this file is green with zero regressions.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Append 7 RED test blocks for VSCHED-01/02/03 + determinism</name>
  <files>test/services/schedule_generator_test.dart</files>
  <read_first>
    - 20-VALIDATION.md "Per-Task Verification Map" → the 7 behaviors and their `--name` substrings
    - 20-RESEARCH.md "Exact Assertions (for Planner Reference)" lines 584–660 → the precise deterministic assertion bodies to transcribe (VSCHED-01 time-target, VSCHED-01 outcome, VSCHED-02 bound, VSCHED-03 reservation, determinism)
    - 20-PATTERNS.md "test() body pattern" + `workChunksOf` helper (test line 75–76) + `monday` fixture (test line 11–17) — all already in scope
  </read_first>
  <action>
    Append 7 new `test()` blocks (append at end of the existing top-level `group`/`main` body; do NOT edit existing tests). Use the exact assertion bodies from 20-RESEARCH.md "Exact Assertions". Each test name MUST contain the matchable substring shown so `--name` filtering works:

    1. `'VSCHED-01 time-target: low/stormy day → gives-valence time-target appears'` — mood=1, lighterDay=true, a gives-valence `makeTimeTarget` + a `makeHabit`; assert the gives goal has ≥1 work chunk.
    2. `'VSCHED-01-outcome: low day → gives-valence outcome with no deadline appears'` — mood=1, lighterDay=true, a gives-valence `makeOutcome(deadline: null)`; assert ≥1 work chunk for it.
    3. `'VSCHED-02: low day discretionary count < medium day count'` — same two goals (one gives, one neutral, large weeklyHourBudget), mood=1 vs mood=3, both lighterDay=true; assert `workChunksOf(low) < workChunksOf(medium)`.
    4. `'VSCHED-02-neutral-excluded: neutral/costs time-target gets no restorative floor on low day'` — mood=1, lighterDay=true, a SINGLE neutral time-target only (no gives goal); assert it does NOT receive a restorative-floor slot beyond what FILL-01 already grants. Encode this as: with only a neutral goal on a low day, the restorative floor must add nothing — assert the neutral goal's work-chunk count equals the baseline FILL-01 cap of 1 (NOT 2). (This proves the floor is gives-only.)
    5. `'VSCHED-03: high day under heavy backlog reserves a gives-valence slot'` — mood=4, lighterDay=true, one gives `makeTimeTarget` + 5 neutral backlog `makeTimeTarget`s (all large budget); assert the gives goal has ≥1 work chunk.
    6. `'VSCHED-03-highpri-fallback: high day, no gives goal → high-priority goal reserved'` — mood=4, lighterDay=true, no gives goals; one high-priority (priorityWeight 0.9) neutral time-target among several low-priority neutral backlog goals; assert the high-priority goal has ≥1 work chunk. (Distinguish "reserved" from incidental round-robin placement is hard to prove directly; the minimum honest assertion is presence ≥1 — keep it.)
    7. `'determinism: same inputs produce same schedule'` — two identical `generate(...)` calls (mood=3, a gives time-target); assert `r1.map((c)=>c.goalId).toList()` equals `r2.map((c)=>c.goalId).toList()`.

    Transcribe assertion bodies from 20-RESEARCH.md verbatim where provided. Use `EnergyValence.gives` / `EnergyValence.neutral` via the extended helpers. Reuse the in-scope `monday` and `workChunksOf`.

    These tests are EXPECTED TO FAIL now (engine unchanged). That is the RED state — do NOT modify the engine in this plan.
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy && /home/dan/development/flutter/bin/flutter test test/services/schedule_generator_test.dart --name "VSCHED" 2>&1 | tail -20; echo "EXPECT: VSCHED tests FAIL (RED) against unchanged engine — determinism may pass"</automated>
  </verify>
  <acceptance_criteria>
    - 7 new `test()` blocks exist with the `VSCHED-01`/`VSCHED-02`/`VSCHED-03`/`determinism` name substrings
    - File compiles (no analyzer errors): `flutter analyze` clean for this file
    - Running `--name "VSCHED"` shows the new VSCHED tests FAILING (RED) — confirming they bind to behavior not yet implemented
    - No existing test was edited
  </acceptance_criteria>
  <done>The 7 RED tests compile and fail (VSCHED ones) against the current engine; the determinism test may already pass. The contract for Plan 20-02 is now executable.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | Test-only change. No network, auth, secrets, persistence, or external input. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-20-01 | Tampering | RED tests assert too weakly and pass vacuously, masking missing behavior | mitigate | Each VSCHED test must FAIL now (verified RED in Task 2); Plan 20-02 flips them GREEN. A test green in both states is invalid. |
| T-20-SC | Tampering | npm/pub package installs | accept | No packages installed this phase (RESEARCH "Package Legitimacy Audit: Not applicable"). dart:math + flutter_test only. |

No high-severity threats. This is a deterministic, in-memory, test-only change.
</threat_model>

<verification>
- `flutter test test/services/schedule_generator_test.dart` → 47 existing tests GREEN (helper backward-compat)
- `flutter test test/services/schedule_generator_test.dart --name "VSCHED"` → new VSCHED tests RED
- `flutter analyze` → no new errors in the test file
</verification>

<success_criteria>
- Helpers accept `valence` (default neutral); existing 47 tests unaffected
- 7 new deterministic test blocks added, VSCHED ones failing RED, determinism passing
- No engine file touched
</success_criteria>

<output>
Create `.planning/phases/20-valence-aware-engine/20-01-SUMMARY.md` when done
</output>
