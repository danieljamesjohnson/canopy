# Phase 15: Engine Honesty - Context

**Gathered:** 2026-06-13
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

The scheduling engine allocates capacity fairly, counts streaks truthfully, and uses the full day — so the generated schedule reflects reality rather than an artifact of processing order.

**Requirements:** CAP-01, STREAK-01, PRIORITY-02, FILL-01, FILL-02

**Success Criteria (what must be TRUE):**
1. On a low-mood day, outcome and time-target goals receive chunks even when habits are also scheduled — no single goal type monopolizes the discretionary cap.
2. A goal's streak shown in the UI matches what a manual backward walk over due-days would compute — no divergence possible.
3. Raising a habit's priority increases the number of chunks it receives relative to a lower-priority habit; raising an outcome's priority increases its chunk allocation relative to a lower-priority outcome.
4. On a day with open capacity after required work and habits, regular-time (time-target) goals appear in the schedule rather than leaving the day empty.
5. When multiple regular-time goals compete for open slots, higher-priority goals receive more chunks and no single goal claims the entire open day.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

</decisions>

<code_context>
## Existing Code Insights

Codebase context will be gathered during plan-phase research.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — discuss phase skipped. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.

</deferred>
