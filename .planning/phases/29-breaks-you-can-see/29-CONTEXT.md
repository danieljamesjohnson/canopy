# Phase 29: Breaks You Can See - Context

**Gathered:** 2026-08-20
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Every break in the day is visible *as a break* — including a 5-minute one — without the timeline
ever lying about how long anything takes.

**In scope:** the non-live break/chunk card (`chunk_card.dart`) and the density-tier machinery it
selects through (`timeline_geometry.dart` constants). A sub-compact tier for chunks whose slot
cannot hold the compact card.

**Out of scope:** `LiveRowCard` — the live row already has its own density tiers from Phase 27.
The schedule engine (`schedule_generator.dart`) — probing confirms it emits the short breaks
correctly and on the lattice; the defect is purely downstream in render.

**Requirements:**
- SEEBREAK-01 — every break is identifiable as a break at its duration-exact height, with no
  clipped content.
- SEEBREAK-02 — the true grid is preserved: rendered height never deviates from
  `durationMinutes × kPixelsPerMinute`.

</domain>

<decisions>
## Implementation Decisions

### Pre-decided in the ROADMAP (do not relitigate)

- **Option (1), a sub-compact density tier, is the chosen approach** (owner's call, 2026-08-20).
  Below a measured threshold (~24dp), render the break as a single hairline-with-label rather than
  a card. This follows Phase 27's own precedent exactly — tiers driven by slot height — and keeps
  the grid exact.
- **Option (2) — render short breaks as the bare gap between work cards, label on tap — was
  rejected.** It loses the "you're on a break" affordance the Phase 27 spike explicitly valued when
  it rejected option (b).
- **Option (3) — raise `kPixelsPerMinute` — was rejected.** At 8.0 a break would be 40dp, but this
  doubles the day's scroll length; Phase 27 worked specifically to make the day *shorter* (it bought
  back 132dp). Do not revisit without new evidence.

### Constraints the plan must honour

- **Measure the threshold in a real browser, not in `flutter test`.** Record the raw number, the
  method, and the conditions that would invalidate it — the doc-comment house style
  `kCompactLiveMinHeight` already uses. `flutter test`'s placeholder font inflates glyph metrics
  (STATE.md carry-forward invariant), so a text-driven measurement asserted in a widget test is a
  harness bound, not a device requirement. This is the same trap Phase 27 hit with
  `kCompactLiveMinHeight` (placeholder `60.0`, measured `84.0`, re-measured `88.0`).
- **Do not buy legibility with grid accuracy.** A regression test must assert no chunk's rendered
  height deviates from `durationMinutes × kPixelsPerMinute`. Eliminating that trade is what Phase 27
  existed to do.
- **The work card's own 26dp overflow must be resolved, not left unexamined** — decide whether it is
  real on-device or a harness artifact, and either fix it or explicitly dismiss it with the evidence.
- **This phase MUST end in a `checkpoint:human-verify` task.** It cannot close on automated
  verification alone. Precedent: Phase 27 scored 16/17 automated and then failed 2 of 3 items on the
  human check. Two independent reasons automation will lie here — the placeholder-font glyph
  inflation above, and headless Chromium's `CONTEXT_LOST_WEBGL` on this project (CLAUDE.md trap #2),
  which can return a blank screenshot readable as either a pass or a false failure.

### Claude's Discretion

Everything else — the exact sub-compact layout, the constant's name, where the tier switch lives,
task decomposition — is at Claude's discretion. Use the ROADMAP phase entry, the success criteria,
and codebase conventions to guide the decisions.

</decisions>

<code_context>
## Existing Code Insights

Measured during the diagnosis that produced this phase (full trail:
`.planning/seeds/SEED-005-five-minute-breaks-clip-to-a-sliver.md`):

| chunk | slot | natural height | result |
|---|---|---|---|
| work 25min | 100dp | 126dp | clipped 26dp |
| **shortBreak 5min** | **20dp** | **52dp** | **clipped 32dp — only 38% survives** |
| longBreak 30min | 120dp | 80dp | fits |

- Slot heights are pure arithmetic (`durationMinutes × kPixelsPerMinute`, `kPixelsPerMinute = 4.0`)
  and are exact — trust that column. The natural column comes from `flutter test` and is inflated.
- A 5-minute break gets 20dp; its card needs more, so only the top edge of the dashed outline
  paints. Between two 100dp work cards that reads as a *divider*, not a break.
- today_screen's PD-10 `ClipRect` + `OverflowBox` wrapper swallows the overflow silently — remove
  the `ClipRect` and the same render throws **four** RenderFlex overflow errors, one per short
  break. That is why this never surfaced as a crash or a log line.
- `kFullBreakMinHeight = 88.0` selects `compact` for a 20dp break, and compact still needs far more
  than 20dp. **There is no tier below it** — that gap is what this phase fills.
- Phase 28 touched exactly one file (`schedule_generator.dart`); `timeline_geometry.dart` and
  `chunk_card.dart` were last touched in Phase 27. This is not a Phase 28 regression.

Further codebase context will be gathered during plan-phase research.

</code_context>

<specifics>
## Specific Ideas

- Phase 27's `.planning/spikes/001-live-row-in-a-true-grid/tools/` holds a pixel-measurement harness
  (`measure_card_fill.py`, `measure_hours.py`) to crib from for the real-browser measurement step.
- Geometric assertions (heights computed from arithmetic) stay trustworthy in the widget test and
  belong there; legibility does not.

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.

</deferred>
