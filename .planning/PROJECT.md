# Canopy

## What This Is

Canopy is a personal time budgeting app that generates a daily schedule built around your goals. Each day starts with a mood check-in that shapes how demanding the day's plan is. Time is organized into 25-minute focused sessions ("Chunks"), and every quarter the app reviews how your time was actually spent.

## Core Value

Generate a usable daily schedule every morning — one that reflects your real goals and how you actually feel.

## Current State: v1.2 "Make It Usable" — SHIPPED 2026-06-13

**Shipped:** 3 phases (12-14), 7 plans, 11/11 requirements implemented and wired, 209-test suite green. Home now lands the day with clock-timed schedule cards and now/next framing; the check-in is legible with a post-commit lighter-day decision screen; the goal form fits the viewport; the Goals screen reads as a prioritization view; and priority measurably changes the generated schedule. Human visual UAT (12 items across phases 12-14) deferred for later confirmation via `/gsd-verify-work`. See `.planning/milestones/v1.2-*` and `MILESTONES.md`.

**Next:** start the next milestone with `/gsd-new-milestone`.

**v1.2 goal (delivered):** Rework the UI foundations surfaced by the first real dogfood so Canopy is legible and usable day-to-day — fix the landing/information-architecture, make the schedule read as a real timed plan, redesign the goal form and check-in, clarify core affordances, and make priority actually drive scheduling. Rule-based only (no LLM).

**Why this milestone:** v1.1 shipped 21/21 requirements "complete on paper and in code," but the first end-to-end walkthrough (Dan, 2026-06-12) returned a blunt verdict: *"the basics just aren't here yet… quite a bit of rework on just the basics of the UI."* The dogfood is captured in `.planning/seeds/SEED-002-ui-basics-rework-dogfood.md` with transcript + annotated frames at `.planning/research/dogfood-2026-06-12/`. It also confirmed two engine concerns from `.planning/seeds/SEED-001-engine-product-critique.md` (#1 lighter-day default + unreadable toggle, #5 chunks show "5x/week" instead of times).

**Target outcomes:**
- Home is the landing, and the schedule reads as a real plan — every chunk shows a clock time, with a clear "now / next" framing (not "5x/week").
- The goal form fits the screen — Priority and Save are always reachable.
- The Goals screen reads as a prioritization view with a legible priority visual language.
- The check-in is legible (contrast/hover), and the lighter-day choice has a readable state shown at the right moment (after "Let's go"), not an always-on ambiguous toggle.
- Core chunk affordances (complete / skip) are obvious, not an unlabeled circle.
- Priority measurably changes the generated schedule (SEED-001 #4), not just a tiebreaker.

**Scope notes:** Driven by SEED-002 (A–F) + SEED-001 #1/#5/#4. Deferred to a later "engine honesty" milestone: SEED-001 #2 (low-mood zeros time-targets), #3 (habits monopolize the cap), #6 (streak semantics). Phase numbering continues from v1.1 (starts at Phase 12); v1.1 phase directories are preserved.

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

Usability rework (v1.2 — *code-validated; visual UAT deferred*):
- ✓ Home is the landing; schedule reads as a real timed plan with now/next framing (NAV-01/02, SCHED-01/02) — v1.2
- ✓ Chunk complete/skip are labeled, hover-free affordances (SCHED-03) — v1.2
- ✓ Check-in legible at all moods + hover/pressed; lighter-day choice is a readable post-commit decision (CHECKIN-01/02) — v1.2
- ✓ Goal form fits the viewport — Priority + Save reachable (GOALFORM-01) — v1.2
- ✓ Goals screen reads as a prioritization view with a clear priority visual language (GOALS-01/02) — v1.2
- ✓ Priority measurably changes the generated schedule, not just a tiebreaker (PRIORITY-01) — v1.2

### Active

(None — define the next milestone's requirements via `/gsd-new-milestone`. Candidate backlog: SEED-001 engine-honesty items #2 low-mood zeros time-targets, #3 habits monopolize the cap, #6 streak semantics.)

### Out of Scope

- LLM-powered scheduling — deferred to v2 after rule-based engine is validated
- Multi-user / team features — personal tool only
- Calendar sync (Google Calendar, etc.) — v2 consideration

## Context

- Built as a personal tool first — the primary user is the developer
- Flutter project targeting all platforms (iOS, Android, Web, Windows, macOS, Linux)
- Currently at Flutter starter template; all app code goes in `lib/`
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
| Provider + ChangeNotifier (from Phase 2) | Cross-screen state without a heavier framework | ✓ Good — held up through v1.2 |

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
*Last updated: 2026-06-13 after v1.2 "Make It Usable" milestone (UI foundations rework + priority drives scheduling; visual UAT deferred)*
