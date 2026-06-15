---
phase: 19
slug: energy-valence
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-14
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 19-RESEARCH.md "## Validation Architecture". Planner fills the Per-Task Verification Map with real task IDs.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (Flutter SDK) |
| **Config file** | none — Flutter SDK built-in |
| **Quick run command** | `flutter test test/data/migration_schema8_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30–60 seconds (full suite) |

Pattern reference for the migration test: `test/data/migration_schema7_test.dart` (temp-dir `Hive.init`, old-adapter write → reopen → new-adapter read). Widget helpers: `test/test_helpers/viewport.dart`, `test/test_helpers/mood_pump.dart`.

---

## Sampling Rate

- **After every task commit:** `flutter test test/data/migration_schema8_test.dart` (migration safety — the highest-risk path)
- **After every plan wave:** `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

> Planner populates with real task IDs. Derived from research Validation Architecture:

| Req | Behavior to verify | Test Type | Automated Command | File Exists | Status |
|-----|--------------------|-----------|-------------------|-------------|--------|
| ENERGY-01a | Old Goal (no field 12/13) loads as EnergyValence.neutral, no crash | persistence | `flutter test test/data/migration_schema8_test.dart` | ❌ W0 | ⬜ pending |
| ENERGY-01b | New Goal with energyValenceIndex persists across box close/reopen | persistence | `flutter test test/data/migration_schema8_test.dart` | ❌ W0 | ⬜ pending |
| ENERGY-01c | currentSchemaVersion == 8 AND _migrations.length == 8 (WR-06 assert) | unit | `flutter test test/data/migration_schema8_test.dart` | ❌ W0 | ⬜ pending |
| ENERGY-02 | Valence picker renders in goal form; saves correctly | widget | `flutter test test/screens/goal_form_valence_test.dart` | ❌ W0 | ⬜ pending |
| ENERGY-03a | Emoji tag round-trips through save/reload | persistence | `flutter test test/data/migration_schema8_test.dart` | ❌ W0 | ⬜ pending |
| ENERGY-03b | Emoji renders on GoalCard title row when set | widget | `flutter test test/screens/goal_card_valence_test.dart` | ❌ W0 | ⬜ pending |
| ENERGY-04a | Valence badge renders on GoalCard for gives/costs; absent for neutral | widget | `flutter test test/screens/goal_card_valence_test.dart` | ❌ W0 | ⬜ pending |
| ENERGY-04b | Valence chip + emoji visible on ChunkCard when goal has valence/emoji | widget | `flutter test test/screens/chunk_card_valence_test.dart` | ❌ W0 | ⬜ pending |
| ONBOARD-01 | Marking a goal on onboarding Screen 4 + completing sets energyValence=gives | widget | `flutter test test/screens/onboarding_screen4_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Critical Test: Migration Safety (ENERGY-01a) — highest priority

Must: (1) write a `Goal` via the OLD adapter shape (no HiveField 12/13); (2) close box; (3) reopen with the NEW adapter; (4) assert loaded Goal has `energyValence == EnergyValence.neutral` and `emojiTag == null`; (5) assert no exception. Follow `migration_schema7_test.dart`'s temp-dir + `Hive.init(tempDir.path)` pattern.

---

## Wave 0 Requirements

- [ ] `test/data/migration_schema8_test.dart` — ENERGY-01 migration safety + round-trip (incl. WR-06 schema-version assert) + ENERGY-03a emoji round-trip
- [ ] `test/screens/goal_form_valence_test.dart` — ENERGY-02 valence picker widget test
- [ ] `test/screens/goal_card_valence_test.dart` — ENERGY-03b, ENERGY-04a badge/emoji on GoalCard
- [ ] `test/screens/chunk_card_valence_test.dart` — ENERGY-04b valence/emoji on ChunkCard
- [ ] `test/screens/onboarding_screen4_test.dart` — ONBOARD-01 energy step
- [ ] Reuse existing `viewport.dart` / `mood_pump.dart` helpers (no new framework)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual legibility of valence/emoji "restorative-vs-draining at a glance" on the real schedule | ENERGY-04 | Subjective glance-readability; automated tests assert presence not legibility | Single-bundle debug web build per CLAUDE.md, desktop width, scan a generated day's chunks |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
