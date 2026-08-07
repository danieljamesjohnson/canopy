# Phase 21: Mood-Scaled Breaks & Honest Rationale - Context

**Gathered:** 2026-08-07
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

The schedule's break cadence adapts to the morning mood, and a time-target goal's rationale never frames the user as behind.

**Requirements:** BREAK-01, BREAK-02, TONE-01

- **BREAK-01**: Chunks-before-a-long-break scales with the morning mood — roughly 2 on a low day, 5 on a sunny one — deterministically and unit-tested
- **BREAK-02**: The 25-min chunk / 5-min short break interleave and the 25-min long break are preserved through the change
- **TONE-01**: No "behind this week" framing anywhere; a time-target goal's rationale reads as what the schedule is doing for the user, not as a deficit report

**Success criteria (what must be TRUE):**

1. On a low-mood day, the generated schedule inserts a long break after roughly every 2 chunks; on a sunny-mood day, after roughly every 5 chunks — deterministic and unit-tested
2. Every chunk is still followed by its 5-min short break, and every long break is still 25 minutes — only the cadence count changed, not the break structure
3. No schedule or rationale text anywhere reads "behind this week"; a time-target goal's rationale reads as what the schedule is doing for the user, not as a deficit report

**Out of this phase:** the Home/Schedule merge (Phase 22) and live activity tracking (Phase 23). This phase is engine + copy only — parallel-safe with Phase 22, no shared surface.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

### Standing project constraints that bound those choices
- Rule-based engine only — **no LLM, no "smart" suggestions** (permanent product position, see PROJECT.md "Out of Scope")
- Hive migrations are additive-only (new fields with defaults; never remove or rename)
- The generator is deterministic and unit-tested — any cadence change must stay both

</decisions>

<code_context>
## Existing Code Insights

Carried from REQUIREMENTS.md "Implementation Notes" and STATE.md engine constraints so planning doesn't re-derive them:

- Long-break cadence is a single constant: `final int longBreakEvery = isLowMood ? 3 : 4;` (`lib/services/schedule_generator.dart:220`) — BREAK-01 replaces this with a mood-scaled value (~2 low, ~5 sunny)
- Three existing tests in `test/services/schedule_generator_test.dart` (~lines 492–543) assert the every-4 cadence and must change with it
- The "behind" string lives at `lib/services/schedule_generator.dart:190`; its sibling branch already reads "On track this week" — use that framing as the model
- Schedule generator lives in `lib/services/schedule_generator.dart` — deterministic, covered by unit tests

Full codebase context will be gathered during plan-phase research.

</code_context>

<specifics>
## Specific Ideas

No user-supplied specifics — discuss phase skipped. Refer to the ROADMAP phase description and success criteria above.

Note the deliberate hedge in the criteria: "roughly every 2" / "roughly every 5". The mood scale has more than two points, so planning should decide and justify the full mood→cadence mapping (not just the low/sunny endpoints) and lock it in tests.

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.

</deferred>
