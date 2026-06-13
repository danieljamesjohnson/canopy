# Canopy

## What This Is

Canopy is a personal time budgeting app that generates a daily schedule built around your goals. Each day starts with a mood check-in that shapes how demanding the day's plan is. Time is organized into 25-minute focused sessions ("Chunks"), and every quarter the app reviews how your time was actually spent.

## Core Value

Generate a usable daily schedule every morning — one that reflects your real goals and how you actually feel.

## Previous Milestone: v1.2 "Make It Usable" — SHIPPED 2026-06-13

3 phases (12-14), 7 plans, 11/11 requirements implemented and wired, 209-test suite green. Reworked the UI foundations from the first real dogfood: Home landing + clock-timed schedule with now/next framing, labeled chunk actions, legible check-in, goal form that fits the viewport, Goals-as-prioritization, and priority that measurably drives scheduling. Human visual UAT (12 items) deferred for later `/gsd-verify-work`. See `.planning/milestones/v1.2-*` and `MILESTONES.md`.

## Current Milestone: v1.3 "An Honest Day"

**Goal:** Make the scheduling engine tell the truth and use the whole day — so the plan reflects real time, real priority, and fills open capacity with what matters. Rule-based only (no LLM).

**Why this milestone:** A post-v1.2 adversarial audit (`SEED-003`) found three v1.2 requirements landed *superficially* — Home's "Now" is a label, not time-anchored; the goal-sheet "fits viewport" claim is untested; priority's count-effect covers only 1 of 3 goal types. Continued dogfooding (2026-06-13 session) surfaced the deeper product gap: regular-time goals (e.g. family) don't claim an otherwise-empty day. Together these are an "engine honesty + fill the day" pass over `SEED-001` (#3, #6) and `SEED-003` (#1, #2, #3).

**Target features:**
- Home "Now" / "Next" reflect the chunk whose clock window contains the *actual* current time, with graceful before-start / day-over states.
- Priority changes chunk *count* for every goal type (habits & outcomes, not just time-target), and the drag-continuous vs form-discrete priority models are reconciled so the priority chip stays meaningful after a drag.
- Capacity is shared across goal types — habits no longer allocate first and consume the whole (especially low-mood) cap before outcomes/time-targets.
- Honest streaks — the displayed streak matches the actual computed walk.
- Regular-time goals fill open days — when little else is due they claim leftover slots (spread across them by priority, bounded by the mood cap), instead of leaving the day empty.
- A real viewport test proves the goal sheet's Priority + Save are reachable at the true modal height per goal type.

**Scope notes:** Low-energy days stay minimal (required + habits only); time-targets remain suppressed on mood 1–2 — explicit owner decision, so SEED-001 #2 is deferred. Energy-aware valence (`SEED-004`) deferred to a follow-on milestone. Phase numbering continues from v1.2 (starts at Phase 15); prior phase directories are preserved. Several items are partly pre-paid by the 2026-06-13 dogfood commits (start-near-now, weekday frequency, 3-hr regular-time default, removed pace prompt, humane empty-day copy).

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

v1.3 "An Honest Day" — engine honesty + fill the day. See `.planning/REQUIREMENTS.md` for the scoped, ID'd list. Themes: time-anchored Home now/next; priority changes count for all goal types + reconciled priority models; capacity shared across goal types; honest streaks; regular-time fills open days; a real goal-sheet viewport test. Deferred: SEED-001 #2 (low-mood time-target floor — owner kept low days minimal), SEED-004 (energy-aware valence).

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
*Last updated: 2026-06-13 — started milestone v1.3 "An Honest Day" (engine honesty + fill the day)*
