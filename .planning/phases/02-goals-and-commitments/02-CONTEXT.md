# Phase 2: Goals and Commitments - Context

**Gathered:** 2026-02-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Users define the inputs the scheduling algorithm needs: goals across three types and fixed commitment blocks. All UI must avoid exposing internal taxonomic vocabulary (no "time-target", "outcome", "habit" labels). Scheduling logic, home screen, and quarterly review are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Goal list presentation
- Goals grouped by type using plain-language section headers (e.g. "Regular time" / "Working toward" / "Daily habits") — no internal enum labels ever shown
- Each goal card has a colored left border + small icon as the visual type indicator
- Card shows: name, type indicator (border + icon), color swatch; secondary line with weekly hours or streak count only if set — no stat overload
- Archived goals live on a separate screen accessed via overflow menu ("View archived") — main list stays clean

### Goal creation UX
- Type picker: vertical card stack, one card per plain-language option, tap to select and highlight — deliberate and clear
- Required fields to save: name + type only; color defaults to a generated value, all other type-specific fields (hours, deadline, frequency) are optional and can be completed later
- Add/Edit Goal opens as an expandable bottom sheet; user can pull up to full screen if the form needs more space
- Reordering within a type group: long-press reveals drag handles on each card

### Commitment block entry
- Time window: two standard time pickers (start time, end time) — clear and flexible
- Day selection: horizontal S M T W T F S chips, multi-select by tapping — standard, works well on mobile
- Commitment block card shows: name, color swatch, days + time range on one card (e.g. "9am – 5pm · Mon–Fri")
- Multiple commitment blocks supported; same list + Add button pattern as goals, no enforced limit

### Onboarding flow
- Screen 1 type picker: same vertical card stack used in the main Add Goal sheet — consistent, no extra learning curve
- Skip on Screens 2 and 3: instant, single tap, no confirmation, no modal — preserves under-90-second pace
- Visual progression: step indicator dots (1–2–3) at top, screens slide left; no back navigation during onboarding
- After completing or skipping all onboarding screens: land on the Goals list screen so the user sees their created goal immediately

### Claude's Discretion
- Exact plain-language wording for the three section headers (e.g. "Regular time" vs "Time for something")
- Color palette and icon choices for each goal type
- Empty-state illustration/copy for the goals list
- Loading/saving state handling within sheets
- Exact spacing, typography, and animation curves

</decisions>

<specifics>
## Specific Ideas

- The type picker should feel deliberate — each card should be large enough to read comfortably before tapping, not a compact chip
- Onboarding tone should be warm and direct, not instructional or corporate; the questions are conversational
- The 90-second target is a hard constraint: skip affordance on Screens 2 and 3 must be visually prominent (not a small link), and instant

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-goals-and-commitments*
*Context gathered: 2026-02-26*
