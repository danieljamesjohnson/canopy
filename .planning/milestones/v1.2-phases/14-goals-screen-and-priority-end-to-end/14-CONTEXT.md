# Phase 14: Goals Screen and Priority End-to-End - Context

**Gathered:** 2026-06-13
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

The Goals screen reads as a prioritization view with a legible priority visual language, and changing a goal's priority produces a visibly different schedule.

**Requirements:** GOALS-01, GOALS-02, PRIORITY-01

**Success Criteria** (what must be TRUE):

1. The Goals screen's purpose is explicit — a heading or framing copy makes clear this is where the user decides what to focus on — and the reorder affordance is obvious (not an ambiguous "two slashes").
2. Low, normal, and high priority are visually distinct and consistently applied across the Goals screen and schedule cards — changing a goal's priority produces a visible, unambiguous difference in how it is displayed.
3. Elevating a goal from low to high priority and regenerating the schedule produces measurably more or earlier chunks for that goal — the change is observable by the user without inspecting code.
4. Lowering a goal from high to low priority and regenerating produces fewer or later chunks — the effect is symmetric and consistent.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

**Continuity with Phase 13:** Phase 13 established the priority visual language on the goal form (SegmentedButton Low/Normal/High mapping to weights 0.25/0.5/0.75) and compact GoalTypePicker cards. This phase must keep the priority visual language consistent across the Goals screen list and the schedule cards.

</decisions>

<code_context>
## Existing Code Insights

Codebase context will be gathered during plan-phase research. Relevant existing code: the Goals screen/list, goal cards, the priority weight model (0.25/0.5/0.75), the schedule generation engine (ScheduleNotifier.generateToday and the underlying scheduling/prioritization logic), and the schedule chunk cards that already render on Home.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — discuss phase skipped. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.

</deferred>
