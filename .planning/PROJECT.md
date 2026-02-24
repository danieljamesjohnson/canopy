# Canopy

## What This Is

Canopy is a personal time budgeting app that generates a daily schedule built around your goals. Each day starts with a mood check-in that shapes how demanding the day's plan is. Time is organized into 25-minute focused sessions ("Chunks"), and every quarter the app reviews how your time was actually spent.

## Core Value

Generate a usable daily schedule every morning — one that reflects your real goals and how you actually feel.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] User can set up goals across three types: time-target activities (relationships, wellness), outcome-focused projects, and recurring habits/routines
- [ ] App generates a daily schedule of Chunks (25-min focused sessions) each morning based on goals and priorities
- [ ] Morning check-in asks how the user is feeling; harder days get fewer Chunks and easier tasks, good days get fuller schedules
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
- Three goal types require different scheduling logic:
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
| Local storage only | Personal tool, no server complexity in v1 | — Pending |

---
*Last updated: 2026-02-24 after initialization*
