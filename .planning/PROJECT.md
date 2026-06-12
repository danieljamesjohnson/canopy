# Canopy

## What This Is

Canopy is a personal time budgeting app that generates a daily schedule built around your goals. Each day starts with a mood check-in that shapes how demanding the day's plan is. Time is organized into 25-minute focused sessions ("Chunks"), and every quarter the app reviews how your time was actually spent.

## Core Value

Generate a usable daily schedule every morning — one that reflects your real goals and how you actually feel.

## Current Milestone: v1.2 "Make It Usable"

**Goal:** Rework the UI foundations surfaced by the first real dogfood so Canopy is legible and usable day-to-day — fix the landing/information-architecture, make the schedule read as a real timed plan, redesign the goal form and check-in, clarify core affordances, and make priority actually drive scheduling. Rule-based only (no LLM).

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

(None yet — ship to validate)

### Active

- [ ] User can define fixed commitment blocks (e.g. full-time job hours) that are always scheduled regardless of mood
- [ ] User can set up goals across three types: time-target activities (relationships, wellness), outcome-focused projects, and recurring habits/routines
- [ ] App generates a daily schedule of Chunks (25-min focused sessions) each morning based on commitments, goals, and priorities
- [ ] Schedule includes automatic 5-min short breaks after each chunk and a 25-min long break after every 3 chunks (mood 1–2) or 4 chunks (mood 3–5); breaks shown explicitly in the schedule
- [ ] Morning check-in asks how the user is feeling; mood controls discretionary chunk count only — commitment blocks are always present; mood 1–2 triggers a reduced "just survive today" discretionary schedule
- [ ] User can track which Chunks they complete throughout the day
- [ ] App performs a quarterly review: data summary + guided reflection to help user adjust goals and priorities
- [ ] Schedule generation is rule-based (no AI API dependency in v1)

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
| Rule-based scheduling (not AI) | Ship and validate the core loop without API dependency | — Pending |
| 25-minute Chunks | Proven focused session length (Pomodoro research), familiar concept | — Pending |
| Three goal types | Relationships/wellness need time targets; projects need outcomes; habits need consistency | — Pending |
| Commitment blocks | Real-world obligations (job, school) always scheduled; v2 will read from calendar | — Pending |
| Break structure | 5-min after each chunk, 25-min long break every 3–4 chunks (mood-adaptive); breaks shown in schedule | — Pending |
| Local storage only | Personal tool, no server complexity in v1 | — Pending |

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
*Last updated: 2026-06-10 — started milestone v1.1 "Actually Daily" (fix the broken daily loop + make the rule-based engine real)*
