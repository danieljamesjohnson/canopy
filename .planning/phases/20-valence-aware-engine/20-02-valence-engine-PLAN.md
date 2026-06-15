---
phase: 20-valence-aware-engine
plan: 02
type: execute
wave: 2
depends_on: ["20-01"]
files_modified:
  - lib/services/schedule_generator.dart
autonomous: true
requirements: [VSCHED-01, VSCHED-02, VSCHED-03]
must_haves:
  truths:
    - "On a low (mood 1-2) day, an energy-giving discretionary goal (time-target OR outcome) appears in the schedule alongside required chunks + habits (VSCHED-01)"
    - "A low day with energy-giving goals still produces FEWER discretionary chunks than a medium (mood 3) day for identical inputs (VSCHED-02 bound)"
    - "A neutral/costs time-target gets NO restorative-floor slot on a low day (floor is gives-only)"
    - "On a high (mood >= 3) day under heavy backlog, at least one slot is reserved for an energy-giving (or high-priority fallback) goal before backlog round-robin (VSCHED-03)"
    - "All 47 pre-existing schedule_generator tests still pass — no regression to FILL-01/02, PRIORITY-02/03, habit ceiling, mood caps"
    - "generate() is deterministic: identical inputs produce identical chunk sequences (SC-4)"
  artifacts:
    - path: "lib/services/schedule_generator.dart"
      provides: "energy_valence import; hoisted placedCountPerGoal; restorativeFloor restorative sub-pass; VSCHED-03 reservation pass; VSCHED-01 outcome-gate valence condition"
      contains: "EnergyValence.gives"
  key_links:
    - from: "lib/services/schedule_generator.dart"
      to: "package:canopy/data/models/energy_valence.dart"
      via: "import + EnergyValence.gives comparisons in outcome gate, restorative floor, and reservation pass"
      pattern: "import.*energy_valence"
    - from: "restorative floor pass"
      to: "FILL-02 round-robin"
      via: "shared placedCountPerGoal map (hoisted) prevents double-placement"
      pattern: "placedCountPerGoal\\[goal.id\\]"
---

<objective>
Implement all three VSCHED behaviors in the single deterministic engine file `lib/services/schedule_generator.dart`, turning the RED tests from Plan 20-01 GREEN while keeping the 47 existing tests green.

Because the three behaviors share one mutable `placedCountPerGoal` map and must run in a strict pipeline order within Step 4, they are implemented as sequential edits in ONE plan (parallel plans would conflict on the same file/state).

Purpose: low days become livable (a bounded restorative chunk) and high days stay purposeful (a reserved energy-giving slot), rule-based and deterministic — no LLM (SC-4).
Output: 4 surgical edits to `schedule_generator.dart`.
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
@.planning/phases/20-valence-aware-engine/20-01-SUMMARY.md

# The single file this plan edits
@lib/services/schedule_generator.dart
@lib/data/models/energy_valence.dart
</context>

<artifacts_this_phase_produces>
This plan produces, in `lib/services/schedule_generator.dart`:
- New import: `import 'package:canopy/data/models/energy_valence.dart';` (NOT currently present — verified absent)
- VSCHED-01 Change A: `|| goal.energyValence == EnergyValence.gives` added to BOTH low-mood branches of the Step 3 outcome include gate (current lines ~325-332)
- Hoisted `final placedCountPerGoal = <String, int>{};` moved to BEFORE the restorative-floor pass (currently declared at line 380), so all three passes + FILL-02 share one map
- VSCHED-01/02 restorative-floor sub-pass: `const int restorativeFloor = 1;` + gives-only, isLowMood-gated single-chunk pass inserted BEFORE PRIORITY-03 (before current line 381)
- VSCHED-03 reservation pass: `!isLowMood`-gated, gives-first-then-score-sorted single reserved chunk inserted AFTER PRIORITY-03 (after line 396), BEFORE FILL-02 (before line 399)
</artifacts_this_phase_produces>

<pipeline_order priority="critical">
The final Step 4 ordering MUST be exactly (per 20-PATTERNS.md "Pipeline Order"):

1. timeTargetGoals sort (existing, ~line 363-370)
2. placedCountPerGoal declaration — HOISTED here (was line 380)
3. VSCHED-01/02 restorative floor pass — NEW (isLowMood only)
4. PRIORITY-03 surplus pass — EXISTING (lines 381-396, minus its now-hoisted declaration)
5. VSCHED-03 reservation pass — NEW (!isLowMood only)
6. FILL-02 round-robin — EXISTING (lines 399-420)

Swapping PRIORITY-03 and VSCHED-03 would let the reservation steal a slot PRIORITY-03 counts on and break existing PRIORITY-03 tests (RESEARCH Pitfall 3).
</pipeline_order>

<tasks>

<task type="auto">
  <name>Task 1: VSCHED-01 — import + outcome-gate valence eligibility (Change A)</name>
  <files>lib/services/schedule_generator.dart</files>
  <read_first>
    - 20-PATTERNS.md "VSCHED-01 Change A — Step 3 outcome include gate" → exact before/after of the gate + the required import line
    - lib/services/schedule_generator.dart imports (lines 1-7) and the outcome include gate (lines ~324-332, verified in source: if (!isLowMood) include = true; else if (lighterDay) include = deadlineToday; else include = goal.deadline != null;)
    - lib/data/models/energy_valence.dart → EnergyValence.gives is index 1; goal.energyValence getter returns the enum
  </read_first>
  <action>
    VSCHED-01 (outcome half). Add import 'package:canopy/data/models/energy_valence.dart'; to the import block (after the goal.dart import). Verified absent — EnergyValence is NOT re-exported through goal.dart for use as a bare identifier, so the direct import is required.

    In the Step 3 outcome include gate, add an OR-clause testing goal.energyValence equals EnergyValence.gives to BOTH low-mood branches:
    - lighterDay branch: include becomes deadlineToday OR gives.
    - else branch: include becomes (goal.deadline != null) OR gives.

    Leave the !isLowMood branch (include = true) untouched. This makes energy-giving outcomes eligible on low days regardless of deadline (VSCHED-01, Claude's discretion per skipped discuss). Do not touch PRIORITY-02 outcome demand below the gate.
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy && /home/dan/development/flutter/bin/flutter test test/services/schedule_generator_test.dart --name "VSCHED-01-outcome" 2>&1 | tail -8</automated>
  </verify>
  <acceptance_criteria>
    - energy_valence.dart imported in the generator
    - Both low-mood outcome-gate branches include the EnergyValence.gives OR-clause; !isLowMood branch unchanged
    - The VSCHED-01-outcome test goes GREEN
  </acceptance_criteria>
  <done>A gives-valence outcome with no deadline appears on a low day; the outcome RED test is green; file compiles.</done>
</task>

<task type="auto">
  <name>Task 2: VSCHED-01/02 — hoist placedCountPerGoal + restorative floor sub-pass</name>
  <files>lib/services/schedule_generator.dart</files>
  <read_first>
    - 20-PATTERNS.md "VSCHED-01/02 Change B — Step 4 restorative floor sub-pass" → the PRIORITY-03 analog (lines 380-397), the hoist instruction, and the new sub-pass body to copy
    - 20-RESEARCH.md Pitfall 1 (double-place) and Pitfall 2 (bound is restorativeFloor=1, day-level cap does the rest)
    - lib/services/schedule_generator.dart lines 361 (score), 363-370 (timeTargetGoals sort), 380 (placedCountPerGoal decl), 381-396 (PRIORITY-03), 399-420 (FILL-02)
  </read_first>
  <action>
    VSCHED-01 (time-target half) + VSCHED-02 (bound). Two edits:

    1. HOIST the declaration of placedCountPerGoal (an empty String→int map) from its current spot (line 380, start of PRIORITY-03) up to immediately AFTER the timeTargetGoals sort (after ~line 370) and BEFORE the new restorative-floor block. It must be visible to all three passes.

    2. Insert the restorative-floor sub-pass BETWEEN the hoisted declaration and the PRIORITY-03 loop. Copy the structure from 20-PATTERNS.md: declare const int restorativeFloor = 1; and int restorativeCount = 0;, then guard the whole pass with if (isLowMood). Loop over timeTargetGoals; inside, in order: break if discretionaryCount >= cap; break if restorativeCount >= restorativeFloor; continue if goal.energyValence is not EnergyValence.gives; compute rawDemand via _demandForTimeTarget(goal, completionLogs, date) and continue if it is <= 0; add the work ScheduledChunk (chunkTypeIndex ChunkType.work.index, durationMinutes 25, rationale via _timeTargetRationale(...)); then increment discretionaryCount, set placedCountPerGoal[goal.id] = 1 (CRITICAL — prevents FILL-02 double-place per Pitfall 1), increment restorativeCount.

    The restorativeFloor = 1 constant IS the VSCHED-02 bound (Pitfall 2): the day-level mood cap (mood1=4 vs mood3=8) plus FILL-01's per-goal demand clamp of 1 keep low < medium automatically. The floor applies to GIVES time-targets only — neutral/costs get nothing extra (covered by VSCHED-02-neutral-excluded).

    Do NOT change the PRIORITY-03 loop body other than removing its now-hoisted placedCountPerGoal declaration line.
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy && /home/dan/development/flutter/bin/flutter test test/services/schedule_generator_test.dart --name "VSCHED-01 time-target" 2>&1 | tail -6 && /home/dan/development/flutter/bin/flutter test test/services/schedule_generator_test.dart --name "VSCHED-02" 2>&1 | tail -10</automated>
  </verify>
  <acceptance_criteria>
    - placedCountPerGoal is declared once, before the restorative floor pass, and shared by restorative floor + PRIORITY-03 + FILL-02
    - restorativeFloor = 1; the floor pass is isLowMood-gated and places at most 1 chunk, only for an EnergyValence.gives time-target with demand
    - VSCHED-01 time-target, VSCHED-02 bound, and VSCHED-02-neutral-excluded tests go GREEN
    - No gives goal is double-placed (gives goal gets exactly 1 chunk on a low day)
  </acceptance_criteria>
  <done>A gives time-target appears on a low day with exactly 1 chunk; low-day discretionary count < medium-day; neutral goals get no floor slot; those RED tests are green.</done>
</task>

<task type="auto">
  <name>Task 3: VSCHED-03 — high-day reservation pass + full-suite regression gate</name>
  <files>lib/services/schedule_generator.dart</files>
  <read_first>
    - 20-PATTERNS.md "VSCHED-03 — Step 4 reservation pass before FILL-02" → the new pass body (filter, gives-first sort, single break) and exact insertion point (after PRIORITY-03 line 397, before FILL-02 line 399)
    - 20-RESEARCH.md Pitfall 3 (keep PRIORITY-03 → VSCHED-03 → FILL-02 order) and Pitfall 5 (time-targets only, not habits/outcomes)
    - score(Goal g) is already declared at line 361 and in scope; placedCountPerGoal is now hoisted (Task 2)
  </read_first>
  <action>
    VSCHED-03 (high-day reservation). Insert a new pass AFTER the PRIORITY-03 surplus loop and BEFORE the FILL-02 while-loop. Guard the whole pass with if (!isLowMood) (mood 3-5, per the generator's existing good-mood convention; mood-3 cost is one harmless reserved slot — Open Question 1 recommendation).

    Build reserveCandidates = timeTargetGoals filtered to those where goal.energyValence == EnergyValence.gives OR (goal.priorityWeight ?? 0.5) >= 0.75. Sort with a deterministic comparator: gives-valence first (map gives→0, else→1, compare), then ties broken by score(b).compareTo(score(a)) (composite score descending — score is in scope). Dart sort is stable; the existing goal ordering provides the final deterministic tiebreak.

    Iterate reserveCandidates: break if discretionaryCount >= cap; read placed = placedCountPerGoal[goal.id] ?? 0; compute rawDemand via _demandForTimeTarget(...); continue if rawDemand <= 0 OR placed >= rawDemand; otherwise place exactly 1 work ScheduledChunk (same construction as the other passes), increment discretionaryCount, set placedCountPerGoal[goal.id] = placed + 1, then break (only ONE reserved slot — the gives goal is primary, high-priority is the fallback when no gives goal has demand).

    Keep the pipeline order PRIORITY-03 → VSCHED-03 → FILL-02 (Pitfall 3). Scope to time-target goals only (Pitfall 5).

    Final step: run the FULL suite to confirm zero regression across FILL-01/02, PRIORITY-02/03, habit ceiling, and mood caps, and that determinism holds.
  </action>
  <verify>
    <automated>cd /home/dan/CodeProjects/canopy && /home/dan/development/flutter/bin/flutter test 2>&1 | tail -15</automated>
  </verify>
  <acceptance_criteria>
    - VSCHED-03 and VSCHED-03-highpri-fallback tests go GREEN (gives goal reserved under heavy backlog; high-priority goal reserved when no gives goal exists)
    - determinism test GREEN
    - All 47 pre-existing tests still pass — full `flutter test` is green with zero regressions
    - Pipeline order is PRIORITY-03 → VSCHED-03 → FILL-02; reservation places at most 1 chunk and never double-places (placedCountPerGoal honored)
  </acceptance_criteria>
  <done>Full `flutter test` suite is green: all 7 new Phase 20 tests pass and no existing test regressed. All three VSCHED requirements are satisfied deterministically.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | Pure deterministic in-memory scheduling logic. No network, auth, secrets, persistence, or external input. The Goal valence index is already range-guarded by the goal.energyValence getter (Phase 19, defaults to neutral on out-of-range). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-20-02 | Denial of Service (correctness/availability) | A logic regression in generate() produces a wrong or empty schedule | mitigate | The 47 existing deterministic unit tests + 7 new ones run in Task 3's full-suite gate; any regression fails the gate before merge. |
| T-20-03 | Tampering | Restorative pass double-places a goal that FILL-02 then re-places, exceeding the low-day bound | mitigate | placedCountPerGoal is hoisted and written in every pass; VSCHED-01 time-target test asserts exactly 1 chunk; VSCHED-02 asserts low < medium. |
| T-20-04 | Tampering | Non-deterministic ordering from the VSCHED-03 sort produces unstable schedules | mitigate | Comparator uses only stored ints/doubles + stable Dart sort; determinism test asserts identical output across two identical calls (SC-4). |
| T-20-SC | Tampering | npm/pub package installs | accept | No packages installed this phase (RESEARCH "Package Legitimacy Audit: Not applicable"). dart:math + existing imports only. |

No high-severity threats. Pure in-memory logic; honest risk surface is a correctness regression, fully covered by the deterministic test gate.
</threat_model>

<verification>
- `flutter test test/services/schedule_generator_test.dart --name "VSCHED"` → all VSCHED tests GREEN
- `flutter test test/services/schedule_generator_test.dart --name "determinism"` → GREEN
- `flutter test` → full suite GREEN (47 existing + 7 new, zero regressions)
- `flutter analyze` → no new errors in schedule_generator.dart
</verification>

<success_criteria>
- VSCHED-01: gives-valence time-target AND gives-valence outcome (no deadline) appear on low days
- VSCHED-02: low-day discretionary count < medium-day count; neutral/costs get no floor slot
- VSCHED-03: under heavy backlog on a high day, a gives (or high-priority fallback) goal is reserved
- SC-4: deterministic — identical inputs produce identical schedules
- Zero regression: full `flutter test` green
</success_criteria>

<output>
Create `.planning/phases/20-valence-aware-engine/20-02-SUMMARY.md` when done
</output>
