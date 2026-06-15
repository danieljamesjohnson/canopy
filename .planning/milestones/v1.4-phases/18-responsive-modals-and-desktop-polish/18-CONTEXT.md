# Phase 18: Responsive Modals and Desktop Polish - Context

**Gathered:** 2026-06-14
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Users on desktop/web see modals and primary screens that fit the viewport — no cramped phone-style sheets, no content clipped off-screen.

Requirements in scope:
- **RESP-01**: Goal add/edit form renders as a centered, width-constrained dialog on desktop/web widths and as a bottom sheet on phone widths
- **RESP-02**: On desktop width, the goal form shows the type picker, all fields, Priority, and Save/Add with nothing clipped and no scroll required
- **RESP-03**: Commitment add/edit and any other modal callers use the same shared adaptive dialog-vs-sheet helper
- **POLISH-01**: Primary screens (home, schedule, goals, check-in) use desktop-appropriate layout at wide widths — constrained content, not phone-stretched full-bleed
- **POLISH-02**: Residual UI nits from a fresh desktop walkthrough are triaged and the high-friction ones fixed

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting (workflow.skip_discuss=true). Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Guidance from success criteria:
- A shared adaptive helper should switch between a centered, width-constrained Material dialog (desktop/wide) and the existing bottom sheet (phone/narrow), based on a breakpoint.
- All modal callers (goal add/edit, commitment add/edit, any others) must route through this single helper.
- Primary screens should constrain content width on desktop rather than stretching full-bleed.
- A fresh desktop walkthrough should surface high-friction nits; fix the high-friction ones.

</decisions>

<code_context>
## Existing Code Insights

Codebase context will be gathered during plan-phase research. Known landmarks (from CLAUDE.md):
- `lib/widgets/responsive_shell` — responsive scaffolding already present.
- `lib/screens/goals/`, `lib/screens/commitments/` — modal callers for goal/commitment add/edit.
- `lib/screens/home/`, `lib/screens/schedule/`, `lib/screens/end_of_day/` (check-in) — primary screens.
- Material 3 theme via `ColorScheme.fromSeed(Colors.deepOrangeAccent)`.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — discuss phase skipped. Refer to ROADMAP phase description and success criteria. UAT hosting note (CLAUDE.md): test against the single-bundle debug web build to verify desktop-width behavior.

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.

</deferred>
