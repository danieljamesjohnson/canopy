# Phase 19: Energy Valence - Context

**Gathered:** 2026-06-14
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Users can declare how a goal makes them feel (energy valence), see that signal wherever goals appear, attach an emoji tag, and have energy-giving activities seeded during onboarding.

Requirements in scope:
- **ENERGY-01**: A goal carries an energy valence (gives / neutral / costs), persisted via additive Hive migration; existing goals default to neutral
- **ENERGY-02**: User can set a goal's valence in the goal form on both create and edit
- **ENERGY-03**: User can attach an emoji/image tag to a goal; it persists and renders on the goal
- **ENERGY-04**: Valence (and tag) is visible where goals are listed and scheduled, so the day reads restorative-vs-draining at a glance
- **ONBOARD-01**: Onboarding includes a "what gives you energy?" step that tags a couple of energy-giving activities, seeding restorative goals before first use

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting (workflow.skip_discuss=true). Use ROADMAP phase goal, success criteria, and codebase conventions.

Guidance from success criteria:
- Valence is a 3-value enum (gives / neutral / costs). Default neutral for existing goals.
- **Hive migration must be ADDITIVE and crash-safe**: new fields on the Goal adapter with new field indices; existing persisted goals load with valence=neutral and no emoji tag (no migration crash, no data loss). This is the highest-risk item — CLAUDE.md notes a prior stale-Hive-data crash; follow the existing migration/resilient_box patterns in lib/data/database/.
- Goal form (create + edit) gets a gives/neutral/costs picker and an emoji tag picker.
- Valence + emoji render on the goal card (goals list) and on schedule chunks so the day reads restorative-vs-draining at a glance.
- Onboarding gains a "what gives you energy?" step that marks a couple of goals energy-giving before first schedule generation.
- Defer engine BEHAVIOR changes to Phase 20 (this phase is the valence MODEL + visibility + onboarding seed, not the scheduling logic).

</decisions>

<code_context>
## Existing Code Insights

Codebase context gathered during plan-phase research. Known landmarks (from CLAUDE.md + Phase 18 work):
- `lib/data/models/` — Hive-adapter models + generated `*.g.dart` (Goal model + adapter lives here).
- `lib/data/database/` — Hive setup, migrations, `resilient_box` (migration safety patterns).
- `lib/data/repositories/` — goal repository (hive + in_memory impls).
- `lib/screens/goals/goal_form_sheet.dart`, `lib/screens/goals/widgets/goal_card.dart` — goal form + card (touched in Phase 18; uses adaptive modal).
- `lib/screens/schedule/` + `widgets/chunk_card.dart` — schedule chunk rendering.
- `lib/screens/onboarding/` — onboarding flow (multi-step; Phase 18 walkthrough confirmed 3 steps: outcome/regular, commitment, habit).
- `lib/providers/goals_notifier.dart` — goals state.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — discuss phase skipped. The additive Hive migration (ENERGY-01) is the critical-path, highest-risk item; verify existing-goal load defaults to neutral with no crash. Per CLAUDE.md, test against the single-bundle debug web build for desktop UAT.

</specifics>

<deferred>
## Deferred Ideas

- Valence-aware scheduling BEHAVIOR (low days restorative, high days reserve a slot) → Phase 20 (VSCHED-01/02/03). This phase is model + visibility + onboarding seed only.

</deferred>
