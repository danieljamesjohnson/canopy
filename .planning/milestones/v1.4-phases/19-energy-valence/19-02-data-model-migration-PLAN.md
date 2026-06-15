---
phase: 19-energy-valence
plan: 02
type: execute
wave: 2
depends_on: ["19-01"]
files_modified:
  - lib/data/models/energy_valence.dart
  - lib/data/models/goal.dart
  - lib/data/models/goal.g.dart
  - lib/data/database/migrations.dart
autonomous: true
requirements: [ENERGY-01]
must_haves:
  truths:
    - "Existing goals persisted before this phase load with energyValence == EnergyValence.neutral and no migration crash (ENERGY-01)"
    - "A new goal's energy valence and emoji tag persist across an app restart"
    - "currentSchemaVersion is 8 and the migrations list has exactly 8 entries so the WR-06 startup assert passes"
  artifacts:
    - path: "lib/data/models/energy_valence.dart"
      provides: "EnergyValence enum (neutral, gives, costs) — neutral at index 0"
      contains: "enum EnergyValence"
    - path: "lib/data/models/goal.dart"
      provides: "energyValenceIndex (HiveField 12), emojiTag (HiveField 13), energyValence getter"
      contains: "energyValenceIndex"
    - path: "lib/data/models/goal.g.dart"
      provides: "Regenerated adapter serializing 14 fields"
      contains: "writeByte(14)"
    - path: "lib/data/database/migrations.dart"
      provides: "currentSchemaVersion=8 + _migration7to8 no-op"
      contains: "_migration7to8"
  key_links:
    - from: "lib/data/models/goal.dart"
      to: "lib/data/models/energy_valence.dart"
      via: "import + getter EnergyValence.values[energyValenceIndex ?? 0]"
      pattern: "EnergyValence.values"
    - from: "lib/data/database/migrations.dart"
      to: "_migrations list length"
      via: "WR-06 assert _migrations.length == currentSchemaVersion"
      pattern: "_migration7to8"
---

<objective>
Add the energy-valence data model: the EnergyValence enum, two additive Hive fields on Goal
(HiveField 12 energyValenceIndex, HiveField 13 emojiTag), the regenerated adapter, and the
schema bump to 8 with a no-op _migration7to8. This is the critical-path, highest-risk task in
the milestone (ENERGY-01).

Purpose: Persist valence + emoji without breaking existing users' data. CLAUDE.md records a
prior stale-Hive-data startup crash; this migration must be strictly additive so existing
goals (missing fields 12/13) read back as neutral / no-tag with no exception.

Output: A green migration_schema8 test (flipped from RED in Plan 01) proving old-record
compatibility and round-trip persistence, plus the schema version assert satisfied at startup.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/19-energy-valence/19-RESEARCH.md
@.planning/phases/19-energy-valence/19-PATTERNS.md
@.planning/phases/19-energy-valence/19-VALIDATION.md

# Files to modify / their analogs:
@lib/data/models/goal.dart
@lib/data/models/goal.g.dart
@lib/data/database/migrations.dart
</context>

<artifacts_this_plan_produces>
- `lib/data/models/energy_valence.dart` — NEW: `enum EnergyValence { neutral, gives, costs }`
- `Goal.energyValenceIndex` (HiveField 12, int?), `Goal.emojiTag` (HiveField 13, String?), `Goal.energyValence` getter — added to goal.dart + Goal constructor params
- `lib/data/models/goal.g.dart` — REGENERATED (writeByte(14), reads fields[12]/fields[13])
- `currentSchemaVersion = 8`, `_migration7to8()` no-op — migrations.dart
</artifacts_this_plan_produces>

<note_on_repositories>
This codebase has NO in-memory goal repository file. `lib/data/repositories/goal_repository.dart`
is the interface; `lib/data/repositories/hive_goal_repository.dart` stores the whole Goal object
via `_box.put(goal.id, goal)` (verified). Adding HiveField 12/13 to the model therefore requires
ZERO repository changes — the adapter handles serialization and the repo passes the object through
intact. (The planning-context note about "both hive and in_memory goal repositories" does not match
this codebase; the per-test inline _InMemoryGoalRepository in widget tests already passes Goal
objects through unchanged.) Do not invent repository edits.
</note_on_repositories>

<tasks>

<task type="auto">
  <name>Task 1: EnergyValence enum + Goal fields 12/13 + getter + constructor params</name>
  <files>lib/data/models/energy_valence.dart, lib/data/models/goal.dart</files>
  <read_first>
    - 19-PATTERNS.md §"lib/data/models/energy_valence.dart" (lines 33-57) — exact enum + comment convention
    - 19-PATTERNS.md §"lib/data/models/goal.dart (MODIFIED)" (lines 60-126) — field append point, getter, constructor params, import
    - 19-RESEARCH.md §"HiveField Index Registry" (lines 136-157) + §"Pitfall 2" (lines 461-469) — neutral MUST be index 0
    - lib/data/models/goal.dart (full) — existing GoalType int-index pattern + constructor
  </read_first>
  <action>
    Create lib/data/models/energy_valence.dart containing exactly the plain enum
    `enum EnergyValence { neutral, gives, costs }` with the "ORDER IS FIXED / neutral = 0 so missing
    HiveField reads correctly / never reorder / no @HiveType" comment block (per 19-PATTERNS.md lines
    49-56). It is a plain Dart enum — NO @HiveType annotation, NO adapter, NO new typeId.
    In goal.dart: add `import 'energy_valence.dart';`. Append after the existing @HiveField(11) streakCount:
    `@HiveField(12) int? energyValenceIndex;` and `@HiveField(13) String? emojiTag;`, plus the getter
    `EnergyValence get energyValence => EnergyValence.values[energyValenceIndex ?? 0];`. Add
    `this.energyValenceIndex,` and `this.emojiTag,` as optional named params to the Goal constructor
    (matching the existing nullable-param style). Do NOT touch any existing HiveField index.
  </action>
  <verify>
    <automated>grep -q 'enum EnergyValence { neutral, gives, costs }' lib/data/models/energy_valence.dart && grep -q 'HiveField(12)' lib/data/models/goal.dart && grep -q 'HiveField(13)' lib/data/models/goal.dart && grep -q 'EnergyValence.values\[energyValenceIndex ?? 0\]' lib/data/models/goal.dart && echo OK</automated>
  </verify>
  <done>EnergyValence enum exists with neutral first; Goal has fields 12/13 + getter + constructor params; no existing HiveField index changed; no @HiveType on the enum.</done>
</task>

<task type="auto">
  <name>Task 2: Regenerate adapter + bump schema to 8 + add _migration7to8 (no-op)</name>
  <files>lib/data/models/goal.g.dart, lib/data/database/migrations.dart</files>
  <read_first>
    - 19-RESEARCH.md §"Pitfall 1" (lines 451-459) — must run build_runner; verify writeByte(14)
    - 19-RESEARCH.md §"Pitfall 6" (lines 497-505) — bump constant AND append migration in same commit
    - 19-PATTERNS.md §"lib/data/database/migrations.dart" (lines 162-209) — exact two edits + no-op body
    - lib/data/database/migrations.dart (full) — WR-06 assert + existing _migration6to7 no-op body style
    - CLAUDE.md §Commands — regen command + analyze/format requirement
  </read_first>
  <action>
    Run `dart run build_runner build --delete-conflicting-outputs` from the project root (set up the
    nvm/flutter PATH first: `export NVM_DIR=$HOME/.nvm; . $NVM_DIR/nvm.sh` and ensure
    /home/dan/development/flutter/bin is on PATH). Confirm goal.g.dart now contains `..writeByte(14)`
    in write() and reads `fields[12]` / `fields[13]` in read() with null-safe casts. Do NOT hand-edit
    goal.g.dart.
    In migrations.dart make exactly two edits in this same task: (a) change
    `const int currentSchemaVersion = 7;` to `= 8;`; (b) append `_migration7to8,` to the `_migrations`
    list and add the async no-op `_migration7to8()` body with a comment matching the existing
    _migration6to7 style (Goal gains energyValenceIndex HiveField 12 int? + emojiTag HiveField 13 String?,
    additive nullable, Hive CE returns null for missing fields, null → EnergyValence.neutral, no data
    transformation). The WR-06 assert (_migrations.length == currentSchemaVersion) must now hold (8 == 8).
    Run `dart format lib/` and `flutter analyze` and resolve any new issues before finishing.
  </action>
  <verify>
    <automated>grep -q 'writeByte(14)' lib/data/models/goal.g.dart && grep -q 'const int currentSchemaVersion = 8;' lib/data/database/migrations.dart && grep -q '_migration7to8' lib/data/database/migrations.dart && flutter test test/data/migration_schema8_test.dart</automated>
  </verify>
  <done>goal.g.dart regenerated to 14 fields; currentSchemaVersion==8 with matching _migration7to8 entry; migration_schema8_test.dart is GREEN (version==8, old-record→neutral, valence+emoji round-trip); flutter analyze clean.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| persisted Hive 'goals' box → app at startup | Existing on-disk Goal records (untrusted shape from older app versions) are deserialized by the new GoalAdapter during normal launch. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-19-02 | Tampering / Denial of Service (data loss + startup availability) | GoalAdapter.read() over pre-migration Goal records | mitigate | Strictly additive HiveField 12/13 (nullable); neutral at enum index 0 so missing field reads as neutral; no-op _migration7to8 performs no data transformation; WR-06 assert guards version/list sync; migration_schema8_test pins the old-record→neutral + no-exception contract. This is the exact data-loss/crash risk from the prior stale-Hive incident in CLAUDE.md. |
| T-19-03 | Tampering | goal.g.dart serialization header (writeByte count) | mitigate | build_runner regen + explicit writeByte(14) verification prevents the "new saves silently drop fields 12/13" failure (19-RESEARCH Pitfall 1). |
| T-19-SC | Tampering | npm/pip/cargo installs | accept | No package installs — 19-RESEARCH §Package Legitimacy Audit confirms zero new packages; build_runner/hive_ce_generator already in pubspec from prior phases. |
</threat_model>

<verification>
- `flutter test test/data/migration_schema8_test.dart` — GREEN.
- `flutter analyze` — no new errors.
- Manual grep confirms no existing HiveField index (0-11) was altered.
- Full suite regression deferred to the Wave 2 merge: `flutter test`.
</verification>

<success_criteria>
- ENERGY-01 satisfied: existing goals load as neutral/no-tag with no crash; new valence+emoji persist across restart.
- Schema version 8 with matching migration entry (WR-06 assert passes).
- No repository file changes (correctly — whole-object storage).
</success_criteria>

<output>
Create `.planning/phases/19-energy-valence/19-02-SUMMARY.md` when done.
</output>
