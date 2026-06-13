# Phase 16: Priority Model Reconciliation - Context

**Gathered:** 2026-06-13
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

The drag-reorder and the form's Low/Normal/High selector write the same priority model, so a goal's priority chip stays correct after any interaction — and an automated test proves the goal sheet's Priority and Save controls are reachable at the true modal height for every goal type.

**Requirements:** PRIORITY-03, GOALFORM-02

**Success Criteria (what must be TRUE):**
1. After dragging a goal to a new position in the list, its priority chip displays the correct Low/Normal/High label — no goal silently loses its chip or shows a stale value.
2. After opening a goal's form and changing the priority selector, the goal's chip in the list reflects the new value without requiring a restart or re-open.
3. A widget test run at the goal sheet's actual opened modal height (not an oversized test surface) passes for time-target, outcome, and habit goals — confirming Priority and Save are not clipped.

</domain>

<decisions>
## Implementation Decisions

### D-01 (LOCKED — user decision 2026-06-13): Position IS the priority model
Drag-reorder's continuous positional `priorityWeight` is the single coherent priority model. Dragging a goal to a mid-list position **correctly** makes it Normal (no chip) — this is intended behavior, not a bug. PRIORITY-03 is satisfied by a widget test proving the priority chip reflects the goal's *current* `priorityWeight` after a drag (no stale value, correct Low/Normal/High label) — **NOT** by changing production code to make the Low/Normal/High selector override drag. Do not add code that prevents drag from changing a goal's band. The selector and drag write the same continuous model; the chip is a pure function of `priorityWeight`.

### Claude's Discretion
All other implementation choices are at Claude's discretion — discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Known guidance from REQUIREMENTS.md:
- **PRIORITY-03**: Drag-reorder and the Low/Normal/High control must write a single coherent priority model — no goal silently losing its chip by landing at a mid-list ~0.5. (SEED-003 #3)
- **GOALFORM-02**: Replace the existing test that resized the surface to 800×1200 and pumped the form outside the modal with one that proves Priority and Save are reachable at the goal sheet's *true* opened modal height, for every goal type. Restructure the sheet if outcome goals overflow. (SEED-003 #2)

</decisions>

<code_context>
## Existing Code Insights

Codebase context will be gathered during plan-phase research. Relevant areas: goal list with drag-reorder, the goal form/sheet with the Low/Normal/High priority selector, the priority chip widget, and the priorityWeight model field shared with the Phase 15 scheduling engine.

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond the success criteria — discuss phase skipped. The priority model must be coherent between drag-reorder (which assigns a positional weight) and the discrete Low/Normal/High selector (which the engine reads as priorityWeight bands).

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.

</deferred>
