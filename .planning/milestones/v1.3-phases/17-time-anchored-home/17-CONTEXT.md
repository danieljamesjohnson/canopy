# Phase 17: Time-Anchored Home - Context

**Gathered:** 2026-06-13
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Home's Now and Next always reflect the chunk whose clock window contains the current time — not the first unresolved chunk — with clear pre-start and day-complete states when no chunk is active.

**Requirements:** NOW-01, NOW-02

**Success Criteria (what must be TRUE):**
1. At 6pm with no chunks checked off, the 8am chunk is not shown as "Now" — the chunk matching the current clock time (or a day-complete state) is shown instead.
2. Before the first chunk of the day begins, Home shows a pre-start state (not a stale or incorrect "Now").
3. After the last chunk's time window has passed, Home shows a day-complete state rather than the last chunk stuck as "Now."

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Known guidance from REQUIREMENTS.md:
- **NOW-01**: "Now" reflects the chunk whose clock-time window contains the *current* time (not merely the first unresolved chunk); "Next" shows the following chunk. At 6pm with nothing checked off, the 8am chunk is no longer shown as "Now." (SEED-003 #1)
- **NOW-02**: Before the day's first chunk and after the last resolved/ended chunk, Home shows a clear pre-start / day-complete state rather than a stale "Now."

</decisions>

<code_context>
## Existing Code Insights

Codebase context will be gathered during plan-phase research. Relevant areas: the Home screen's Now/Next cards, how the current chunk is selected (currently "first unresolved" — must become "clock-window contains now"), the chunk clock-time window data (start/end minutes), and the existing Home empty/landing states from v1.2 Phase 12 (Home as Landing).

</code_context>

<specifics>
## Specific Ideas

The selection logic must switch from "first unresolved chunk" to "the chunk whose [start, end) clock window contains the current wall-clock time," with explicit pre-start (before first chunk) and day-complete (after last chunk window) states. Now/Next must update with the passage of time, not only on user actions.

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.

</deferred>
