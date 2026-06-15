---
phase: 19-energy-valence
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - test/data/migration_schema8_test.dart
  - test/screens/goal_form_valence_test.dart
  - test/screens/goal_card_valence_test.dart
  - test/screens/chunk_card_valence_test.dart
  - test/screens/onboarding_screen4_test.dart
autonomous: true
requirements: [ENERGY-01, ENERGY-02, ENERGY-03, ENERGY-04, ONBOARD-01]
must_haves:
  truths:
    - "Every Phase 19 requirement has at least one RED test file on disk before implementation begins"
    - "The migration-safety test (old Goal record → neutral, no crash) exists and fails because EnergyValence does not yet exist"
  artifacts:
    - path: "test/data/migration_schema8_test.dart"
      provides: "ENERGY-01 schema-version + migration-safety + round-trip + ENERGY-03a emoji round-trip"
      contains: "currentSchemaVersion"
    - path: "test/screens/goal_form_valence_test.dart"
      provides: "ENERGY-02 valence picker widget test"
    - path: "test/screens/goal_card_valence_test.dart"
      provides: "ENERGY-03b + ENERGY-04a badge/emoji on GoalCard"
    - path: "test/screens/chunk_card_valence_test.dart"
      provides: "ENERGY-04b valence/emoji on ChunkCard"
    - path: "test/screens/onboarding_screen4_test.dart"
      provides: "ONBOARD-01 Screen 4 completion sets valence=gives"
  key_links:
    - from: "test/data/migration_schema8_test.dart"
      to: "lib/data/models/energy_valence.dart"
      via: "import EnergyValence (does not exist yet — RED)"
      pattern: "energy_valence"
---

<objective>
Create all five RED test stubs for Phase 19 BEFORE any implementation, per the Nyquist
validation contract (19-VALIDATION.md). Every phase requirement gets a failing test that
defines the behavior contract the implementation plans must satisfy.

Purpose: Lock the behavioral contract first. The migration-safety test (ENERGY-01a) is the
highest-risk path in the milestone — CLAUDE.md records a prior stale-Hive-data startup crash —
so its expected behavior must be pinned before the additive migration is written.

Output: Five test files that compile-fail or assertion-fail (RED) because the symbols they
reference (EnergyValence enum, Goal.energyValenceIndex/emojiTag, _ValenceBadge, _ValenceChip,
onboarding Screen 4, currentSchemaVersion==8) do not yet exist.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/19-energy-valence/19-VALIDATION.md
@.planning/phases/19-energy-valence/19-PATTERNS.md
@.planning/phases/19-energy-valence/19-RESEARCH.md

# Analog test files to copy structure from:
@test/data/migration_schema7_test.dart
@test/screens/goal_form_priority_test.dart
@test/screens/chunk_card_priority_badge_test.dart
@test/screens/goal_card_priority_chip_test.dart
@test/test_helpers/viewport.dart
@test/test_helpers/mood_pump.dart
</context>

<artifacts_this_plan_produces>
- `test/data/migration_schema8_test.dart` — NEW
- `test/screens/goal_form_valence_test.dart` — NEW
- `test/screens/goal_card_valence_test.dart` — NEW
- `test/screens/chunk_card_valence_test.dart` — NEW
- `test/screens/onboarding_screen4_test.dart` — NEW
</artifacts_this_plan_produces>

<tasks>

<task type="auto">
  <name>Task 1: Migration-safety + round-trip test (ENERGY-01a/b/c, ENERGY-03a)</name>
  <files>test/data/migration_schema8_test.dart</files>
  <read_first>
    - 19-PATTERNS.md §"test/data/migration_schema8_test.dart (NEW)" (lines 858-921) — exact structure to adapt
    - test/data/migration_schema7_test.dart (full file) — temp-dir Hive.init + old-write/reopen/new-read pattern
    - 19-VALIDATION.md §"Critical Test: Migration Safety" (lines 60-62) — the 5-step contract
    - 19-RESEARCH.md §"Hive Migration Architecture" (lines 115-178) — field-dict null mechanism
  </read_first>
  <action>
    Adapt migration_schema7_test.dart for Goal + EnergyValence. Import canopy/data/models/goal.dart,
    canopy/data/models/energy_valence.dart (does not exist yet — this drives RED), and
    canopy/data/database/migrations.dart. Register GoalAdapter (typeId 0) in setUp using the same
    Hive.init(tempDir.path) + isAdapterRegistered guard pattern as the analog. Write these test cases:
    (1) `currentSchemaVersion equals 8` — expect(currentSchemaVersion, equals(8)).
    (2) Old-record compatibility (ENERGY-01a): construct a Goal WITHOUT energyValenceIndex or emojiTag,
        put it in the box, close, reopen, read back; expect goal.energyValence == EnergyValence.neutral
        and goal.emojiTag == null and no exception thrown. (This stands in for an "old adapter" record —
        a Goal saved with the new adapter but with both new fields left null serializes/reads identically
        to a pre-migration record for the purposes of the neutral-default contract.)
    (3) Round-trip (ENERGY-01b + ENERGY-03a): construct a Goal with energyValenceIndex =
        EnergyValence.gives.index and emojiTag = a known emoji string, put/close/reopen/read; expect both
        survive equal.
    Do NOT add a separate WR-06 assert test beyond the currentSchemaVersion==8 check — the migrations.dart
    runtime assert already enforces _migrations.length == currentSchemaVersion; the version-equals-8 test
    is the executable proxy. Keep tearDown closing Hive and deleting the temp dir as in the analog.
    Because EnergyValence / the new Goal fields do not exist yet, this file MUST fail to compile (RED).
  </action>
  <verify>
    <automated>flutter test test/data/migration_schema8_test.dart 2>&1 | grep -qiE "error|fail|not found|isn't defined|Undefined name" && echo "RED-CONFIRMED"</automated>
  </verify>
  <done>test/data/migration_schema8_test.dart exists with 3 test cases (version==8, neutral-default, round-trip incl. emoji) and fails RED because EnergyValence / Goal.energyValenceIndex / Goal.emojiTag are undefined.</done>
</task>

<task type="auto">
  <name>Task 2: Widget test stubs — goal form, goal card, chunk card, onboarding (ENERGY-02/03b/04, ONBOARD-01)</name>
  <files>test/screens/goal_form_valence_test.dart, test/screens/goal_card_valence_test.dart, test/screens/chunk_card_valence_test.dart, test/screens/onboarding_screen4_test.dart</files>
  <read_first>
    - test/screens/goal_form_priority_test.dart — inline _InMemoryGoalRepository + GoalsNotifier + viewport/mood_pump helpers (analog for goal_form_valence_test)
    - test/screens/goal_card_priority_chip_test.dart — GoalCard widget pump pattern (analog for goal_card_valence_test)
    - test/screens/chunk_card_priority_badge_test.dart — ChunkCard pump + finds priority chip (analog for chunk_card_valence_test)
    - 19-UI-SPEC.md §"Component Inventory" (lines 130-316) — the exact widgets/labels/visibility rules each test asserts
    - 19-PATTERNS.md role-match rows for the four widget test files (lines 24-27)
    - test/test_helpers/viewport.dart, test/test_helpers/mood_pump.dart — reuse, do not create new helpers
  </read_first>
  <action>
    Create four RED widget test stubs. Reuse the inline _InMemoryGoalRepository + viewport/mood_pump
    helper pattern from the analogs (no new test framework, no new helpers).
    - goal_form_valence_test.dart (ENERGY-02): pump GoalFormSheet; assert an "Energy" section label and a
      SegmentedButton<EnergyValence> with "Gives energy"/"Neutral"/"Costs energy" segments render; assert
      a new goal defaults to Neutral selected; assert tapping "Gives energy" then Save yields a saved Goal
      with energyValence == EnergyValence.gives; assert editing a goal with persisted valence shows it
      pre-selected.
    - goal_card_valence_test.dart (ENERGY-03b + ENERGY-04a): pump GoalCard with a Goal that has
      emojiTag set → assert the emoji string appears in the title row; pump with energyValence == gives →
      assert "Gives" badge text + Icons.bolt present; with costs → "Costs" + Icons.hourglass_empty; with
      neutral → assert NO valence badge (no "Gives"/"Costs" text).
    - chunk_card_valence_test.dart (ENERGY-04b): pump ChunkCard with goalEmojiTag + goalValence params
      (these constructor params do not exist yet — drives RED); assert emoji appears prefixed to the goal
      name and the valence chip (Gives/Costs) renders for non-neutral, absent for neutral.
    - onboarding_screen4_test.dart (ONBOARD-01): pump the onboarding flow far enough to reach Screen 4
      (or pump Screen 4 directly via its constructor with pendingGoals); assert the "What gives you energy?"
      headline renders, mark a goal "Energizing", tap "Let's go", and assert the marked goal's saved
      energyValence == EnergyValence.gives. Skip path leaves goals neutral. If reaching Screen 4 requires
      symbols that don't exist yet, write the assertions against the intended public surface so the file
      fails RED on undefined symbols.
    All four MUST fail RED (undefined symbols: EnergyValence, Goal.emojiTag/energyValence, ChunkCard
    goalEmojiTag/goalValence params, onboarding Screen 4, _ValenceBadge/_ValenceChip visuals).
    NOTE: emoji literals in Dart string/test source are fine (UTF-8); keep each emoji as a single literal.
  </action>
  <verify>
    <automated>flutter test test/screens/goal_form_valence_test.dart test/screens/goal_card_valence_test.dart test/screens/chunk_card_valence_test.dart test/screens/onboarding_screen4_test.dart 2>&1 | grep -qiE "error|fail|isn't defined|Undefined|not found" && echo "RED-CONFIRMED"</automated>
  </verify>
  <done>All four widget test files exist, reuse existing helpers, and fail RED because the Phase 19 production symbols they reference are not implemented yet.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | Test-only plan. No runtime trust boundary is crossed; tests run in CI/dev. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-19-01 | Tampering/Denial of Service | Hive persisted Goal records (modeled here as a test) | mitigate | The migration-safety test in Task 1 pins the contract that an old/absent-field Goal reads as neutral with no exception — directly guarding the data-loss/startup-crash risk flagged in CLAUDE.md. The real mitigation lands in Plan 02; this plan makes the failure observable first. |
| T-19-SC | Tampering | npm/pip/cargo installs | accept | No package installs in this phase — 19-RESEARCH.md §"Package Legitimacy Audit" confirms zero new packages. No supply-chain surface. |
</threat_model>

<verification>
- `flutter test test/data/migration_schema8_test.dart test/screens/goal_form_valence_test.dart test/screens/goal_card_valence_test.dart test/screens/chunk_card_valence_test.dart test/screens/onboarding_screen4_test.dart` — all five files present and RED (compile or assertion failures referencing missing Phase 19 symbols).
- No production `lib/` files are modified by this plan.
</verification>

<success_criteria>
- Five test files exist at the paths in `files_modified`.
- Each fails RED for the right reason (missing Phase 19 production symbols, not test-authoring bugs).
- Existing test helpers (viewport.dart, mood_pump.dart) are reused; no new helper files created.
</success_criteria>

<output>
Create `.planning/phases/19-energy-valence/19-01-SUMMARY.md` when done.
</output>
