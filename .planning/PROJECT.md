# Canopy

## What This Is

Canopy is a personal time budgeting app that generates a daily schedule built around your goals. Each day starts with a mood check-in that shapes how demanding the day's plan is. Time is organized into 25-minute focused sessions ("Chunks"), and every quarter the app reviews how your time was actually spent.

## Core Value

Generate a usable daily schedule every morning — one that reflects your real goals and how you actually feel.

## Current State

**Shipped through v1.3 "An Honest Day" (2026-06-14).** Canopy is a working personal time-budgeting app: a daily mood check-in shapes a generated schedule of 25-min Chunks built around three goal types, with a time-anchored Home (Now/Next), an honest scheduling engine (fair capacity, truthful streaks, priority-driven allocation for all goal types, full-day fill), Goals-as-prioritization, and a quarterly review. ~11.4k LOC of app code in `lib/`, 247-test suite green, `flutter analyze` clean. Rule-based only — no LLM.

**Next:** v1.4 "Energy-Aware" — make Canopy fit the screen it's used on (responsive modals, F-03) and schedule around how activities make you feel (energy valence per goal, restorative low days). Not aiming for daily-ready; clearing known gaps for a fresh review.

## Current Milestone: v1.4 Energy-Aware

**Goal:** Make Canopy fit the screen it's used on and schedule around how activities make you feel — so a fresh review can judge a more honest, more livable day.

**Target features:**
- **Responsive modals (F-03)** — goal form and other modals adapt to viewport: centered dialog on desktop/web width, bottom sheet on phone; Priority + Save visible without scrolling.
- **Energy valence per goal (SEED-004)** — a gives / neutral / costs pick plus an emoji/image tag at goal creation; new Hive field + additive migration; surfaced in the goal form.
- **Onboarding energy prompt** — a "what gives you energy?" step so a couple restorative activities exist from day one.
- **Valence-aware engine** — low ("stormy") days let energy-giving discretionary goals through instead of required+habits only (the SEED-001 #2 restorative floor); high days reserve a slot for an energy-giving / high-value goal.
- **Residual UI-basics polish (SEED-002)** — sweep leftover first-dogfood UI nits not already consumed by v1.2/v1.3.

**Key context:** Not aiming for "daily-ready" — owner will dogfood and re-review after. Rule-based only, no LLM. Hive migration stays additive-only. Web/desktop is the primary dogfood surface.

<details>
<summary>Previous milestone: v1.3 "An Honest Day" — SHIPPED 2026-06-14</summary>

3 phases (15-17), 4 plans, 9/9 requirements satisfied and browser-verified, 247-test suite green. Made the scheduling engine tell the truth and use the whole day: time-anchored Home Now/Next with pre-start/day-complete states (NOW-01/02); priority drives chunk count for all three goal types with reconciled drag/form priority models (PRIORITY-02/03); capacity shared across goal types so habits don't monopolize the low-mood cap (CAP-01); generation-time honest streaks (STREAK-01); regular-time goals fill open days, priority-spread and mood-capped (FILL-01/02); and a true-modal-height goal-sheet reachability test (GOALFORM-02). See `.planning/milestones/v1.3-*` and `MILESTONES.md`.

</details>

<details>
<summary>Previous milestone: v1.2 "Make It Usable" — SHIPPED 2026-06-13</summary>

3 phases (12-14), 7 plans, 11/11 requirements implemented and wired, 209-test suite green. Reworked the UI foundations from the first real dogfood: Home landing + clock-timed schedule with now/next framing, labeled chunk actions, legible check-in, goal form that fits the viewport, Goals-as-prioritization, and priority that measurably drives scheduling. See `.planning/milestones/v1.2-*`.

</details>

## Requirements

### Validated

Core product loop (v1.0) and daily-loop hardening (v1.1):
- ✓ Fixed commitment blocks always scheduled regardless of mood — v1.0
- ✓ Three goal types (time-target, outcome, habit) — v1.0
- ✓ Daily schedule of 25-min Chunks generated each morning — v1.0
- ✓ Mood-adaptive breaks (5-min short, 25-min long every 3–4 chunks) — v1.0
- ✓ Morning mood check-in controls discretionary chunk count — v1.0
- ✓ Chunk completion tracking — v1.0
- ✓ Quarterly review (data summary + guided reflection) — v1.0
- ✓ Rule-based scheduling (no AI dependency) — v1.0

Usability rework (v1.2):
- ✓ Home is the landing; schedule reads as a real timed plan with now/next framing (NAV-01/02, SCHED-01/02) — v1.2
- ✓ Chunk complete/skip are labeled, hover-free affordances (SCHED-03) — v1.2
- ✓ Check-in legible at all moods + hover/pressed; lighter-day choice is a readable post-commit decision (CHECKIN-01/02) — v1.2
- ✓ Goal form fits the viewport — Priority + Save reachable (GOALFORM-01) — v1.2
- ✓ Goals screen reads as a prioritization view with a clear priority visual language (GOALS-01/02) — v1.2
- ✓ Priority measurably changes the generated schedule, not just a tiebreaker (PRIORITY-01) — v1.2

Engine honesty + fill the day (v1.3 — *browser-verified*):
- ✓ Home Now/Next reflect the chunk whose clock window contains the current time, with pre-start / day-complete states (NOW-01/02) — v1.3
- ✓ Priority changes chunk count for all three goal types; drag and form write one coherent priority model (PRIORITY-02/03) — v1.3
- ✓ Capacity shared across goal types — habits can't monopolize the low-mood cap (CAP-01) — v1.3
- ✓ Displayed streak equals the computed backward due-day walk (STREAK-01) — v1.3
- ✓ Regular-time goals fill open days, priority-spread and mood-capped (FILL-01/02) — v1.3
- ✓ Goal sheet's Priority + Save proven reachable at true modal height for every goal type (GOALFORM-02) — v1.3

### Active

Committed to v1.4 "Energy-Aware" (scoped requirements in `.planning/REQUIREMENTS.md`):
- **F-03 responsive modals** — goal form and other modals adapt to viewport (dialog on desktop, sheet on phone).
- **Energy valence per goal (SEED-004)** — gives / neutral / costs pick + emoji/image tag; new Hive field + additive migration; goal-form UI.
- **Onboarding energy prompt** — seed restorative activities up front.
- **Valence-aware engine** — restorative low days (SEED-001 #2) + reserved energy slot on high days.
- **Residual UI-basics polish (SEED-002)** — leftover first-dogfood nits.

### Out of Scope

- LLM-powered scheduling — deferred to v2 after rule-based engine is validated
- Multi-user / team features — personal tool only
- Calendar sync (Google Calendar, etc.) — v2 consideration

## Context

- Built as a personal tool first — the primary user is the developer
- Flutter project targeting all platforms (iOS, Android, Web, Windows, macOS, Linux)
- ~11.4k LOC of app code in `lib/`; 247-test suite green, `flutter analyze` clean (as of v1.3)
- Dogfooded via a hosted **debug** web build (single dart2js bundle, no service worker) over tailscale — see CLAUDE.md "Local hosting for UAT"
- The "Chunk" concept is like a Pomodoro (25 min) but framed around budgeting time toward goals rather than pure focus sessions
- Every chunk is followed by a 5-min short break; after 3–4 chunks a 25-min long break is inserted (mood-adaptive cadence)
- Commitment blocks (job, school, appointments) are chunked up automatically within their time window and always appear in the schedule
- Three discretionary goal types require different scheduling logic:
  - **Time-target** (e.g. family time, friends): allocate hours per week, spread across days
  - **Outcome-focused projects** (e.g. side project, learning): schedule based on outcome priority and deadline
  - **Habits/routines** (e.g. meditation, brushing teeth, cleaning): daily or periodic, lower cognitive load

## Constraints

- **Tech stack**: Flutter/Dart — no external state management library initially, `StatefulWidget` + `setState()`
- **AI**: No LLM API calls in v1 — rule-based scheduling only
- **Platforms**: Must work on all Flutter targets (mobile-first UX, all platforms supported)
- **Data**: Local storage only for v1 — no backend/sync

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Rule-based scheduling (not AI) | Ship and validate the core loop without API dependency | ✓ Good — engine is deterministic and testable through v1.2 |
| 25-minute Chunks | Proven focused session length (Pomodoro research), familiar concept | ✓ Good |
| Three goal types | Relationships/wellness need time targets; projects need outcomes; habits need consistency | ✓ Good |
| Commitment blocks | Real-world obligations (job, school) always scheduled; v2 will read from calendar | ✓ Good |
| Break structure | 5-min after each chunk, 25-min long break every 3–4 chunks (mood-adaptive); breaks shown in schedule | ✓ Good |
| Local storage only | Personal tool, no server complexity in v1 | ✓ Good |
| Priority drives scheduling (v1.2) | Make priority observable: habit sort + time-target composite score, not a tiebreaker | ✓ Good — proven by deterministic engine tests (PRIORITY-01) |
| Provider + ChangeNotifier (from Phase 2) | Cross-screen state without a heavier framework | ✓ Good — held up through v1.3 |
| Habit ceiling `ceil(cap/2)` for capacity sharing (v1.3) | Stop habits monopolizing the discretionary cap on low-mood days so outcomes/time-targets get a share | ✓ Good — CAP-01 browser-verified (2/4 habits on a low-mood day) |
| Generation-time streak write-back (v1.3) | Displayed streak can't diverge from the computed walk if it's written at generation | ✓ Good — STREAK-01 |
| Always-run round-robin fill, mood-capped (v1.3) | Fill open days with time-target goals by priority without one goal swallowing the day | ⚠️ Revisit — FILL-02 high-priority monopoly edge documented-accepted (3+ goals at weight ≥0.75 can starve lower-priority time-targets) |
| Time-anchor Home via `resolveNowState` + 1-min timer (v1.3) | Now/Next must track the real clock window, not the first unresolved chunk; honest pre-start/day-complete states | ✓ Good — NOW-01/02 browser-verified |
| Low-mood days stay minimal (required + habits only) (v1.3) | Owner decision: protect low days from time-target load; defer SEED-001 #2 restorative floor | — Pending — revisit if low days feel empty in dogfooding |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-14 after starting v1.4 "Energy-Aware" milestone*
