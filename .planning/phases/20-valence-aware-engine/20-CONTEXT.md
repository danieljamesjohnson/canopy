# Phase 20: Valence-Aware Engine - Context

**Gathered:** 2026-06-14
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

The scheduling engine uses goal energy valence (added in Phase 19) to shape low and high mood days — low days include a bounded set of restorative (energy-giving) activities; high days reserve a slot for an energy-giving / high-value goal.

Requirements in scope:
- **VSCHED-01**: On low ("stormy") mood days, energy-giving discretionary goals are eligible for scheduling instead of required + habits only
- **VSCHED-02**: The low-day restorative inclusion is bounded (a small floor, not full time-target load) so low days stay light
- **VSCHED-03**: On high ("sunny") mood days, at least one slot is reserved for an energy-giving / high-value goal so good days aren't pure backlog throughput

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting (workflow.skip_discuss=true). Use ROADMAP phase goal, success criteria, and the engine constraints carried in STATE.md.

Guidance from success criteria + STATE engine constraints:
- This is a RULE-BASED, deterministic engine change in `lib/services/schedule_generator.dart` — no LLM.
- **Low ("stormy") days** currently allow required + habits only. VSCHED-01/02 relax this with a BOUNDED restorative floor: include at least one energy-giving discretionary goal, but keep the day light — a low day with energy-giving goals must still have FEWER discretionary chunks than a medium-mood day (SC-2 is the bound).
- **High ("sunny") days** currently raise the cap and fill backlog. VSCHED-03 RESERVES at least one slot for an energy-giving / high-priority goal even under high backlog pressure, so good days aren't pure backlog throughput.
- Builds on the Phase 19 `EnergyValence` (gives/neutral/costs) on Goal. "Energy-giving" = `EnergyValence.gives`.
- Determinism is a hard requirement (SC-4): behavior covered by deterministic unit tests passing under `flutter test`. Use the existing schedule_generator test patterns (fixed testDate, seeded inputs).

</decisions>

<code_context>
## Existing Code Insights

Codebase context gathered during plan-phase research. Known landmarks (from STATE.md engine constraints + prior phases):
- `lib/services/schedule_generator.dart` — the deterministic rule-based generator (the file this phase changes). Covered by unit tests in test/.
- Existing engine rules (carry-forward): habit ceiling `ceil(cap/2)`; low-mood = required + habits only (relaxed here); high-mood = raise cap + fill backlog; FILL-01/02 round-robin Step 4 with `isLowMood ? 1 : demand` per-goal cap; priority composite score (remainingHours × priorityWeight) for time-targets; PRIORITY-02 flat +1 chunk for high-priority on good-mood days.
- Mood model: low ("stormy") / medium / high ("sunny") — find how mood is represented and threaded into generation.
- `EnergyValence` enum (Phase 19) on Goal: `goal.energyValence` getter (gives/neutral/costs), `goal.energyValenceIndex`.
- Goal types: timeTarget (regular time / discretionary), outcome, habit.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — discuss phase skipped. The bound (SC-2: low day with energy-giving goals still < medium day discretionary count) and the high-day reservation (SC-3: ≥1 energy-giving/high-priority slot under backlog pressure) are the two precise behaviors to encode and unit-test. Keep changes deterministic and minimally invasive to the existing rule pipeline.

</specifics>

<deferred>
## Deferred Ideas

None — this is the final v1.4 phase; valence model + visibility shipped in Phase 19.

</deferred>
