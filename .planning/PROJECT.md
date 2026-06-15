# Canopy

## What This Is

Canopy is a personal time budgeting app that generates a daily schedule built around your goals. Each day starts with a mood check-in that shapes how demanding the day's plan is. Time is organized into 25-minute focused sessions ("Chunks"), and every quarter the app reviews how your time was actually spent.

## Core Value

Generate a usable daily schedule every morning — one that reflects your real goals and how you actually feel.

## Current State

**Shipped through v1.4 "Energy-Aware" (2026-06-15).** Canopy is a working personal time-budgeting app: a daily mood check-in shapes a generated schedule of 25-min Chunks built around three goal types, with a time-anchored Home (Now/Next), an honest + energy-aware scheduling engine (fair capacity, truthful streaks, priority-driven allocation, full-day fill, restorative low days, reserved energy slot on high days), responsive modals (centered dialog on desktop / bottom sheet on phone), per-goal energy valence (gives/neutral/costs + emoji tag) visible across goal form, goals list, and schedule, an onboarding energy step, Goals-as-prioritization, and a quarterly review. ~12k LOC of app code in `lib/`, 289-test suite green, `flutter analyze` clean. Rule-based only — no LLM.

**Next:** Planning the next milestone (`/gsd-new-milestone`). Owner will dogfood v1.4 and re-review. Tracked tech debt: onboarding desktop polish (full-bleed + day-chip labels), chunk_card color-token hygiene.

<details>
<summary>Previous milestone: v1.4 "Energy-Aware" — SHIPPED 2026-06-15</summary>

3 phases (18-20), 12 plans, 13/13 requirements satisfied (browser-verified where visual), 289-test suite green. Made Canopy fit the screen and schedule around feeling: responsive adaptive modals (dialog ≥720dp / sheet below) + 720dp content constraints on primary screens (RESP-01/02/03, POLISH-01/02); per-goal energy valence (gives/neutral/costs, additive Hive migration schema 7→8, neutral-default crash-safe) + emoji tag, surfaced in goal form, goal card, and schedule chunks, with an onboarding "what gives you energy?" step (ENERGY-01/02/03/04, ONBOARD-01); and a valence-aware engine — restorative floor on low-mood days (bounded) + reserved energy/high-priority slot on high-mood days (VSCHED-01/02/03), all deterministic-unit-tested. See `.planning/milestones/v1.4-*` and `MILESTONES.md`.

</details>

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

Energy-aware + responsive (v1.4 — *browser-verified where visual*):
- ✓ Goal form and all modal callers adapt to viewport — centered dialog ≥720dp, bottom sheet below (RESP-01/02/03) — v1.4
- ✓ Primary screens (home/schedule/goals) constrain content to 720dp on desktop; high-friction desktop nits triaged (POLISH-01/02) — v1.4
- ✓ Goals carry an energy valence (gives/neutral/costs) via additive Hive migration, default neutral, crash-safe (ENERGY-01) — v1.4
- ✓ Valence set in goal form (create + edit) + optional emoji tag, persisted (ENERGY-02/03) — v1.4
- ✓ Valence + emoji visible where goals are listed and scheduled (ENERGY-04) — v1.4
- ✓ Onboarding "what gives you energy?" step seeds energy-giving goals before first schedule (ONBOARD-01) — v1.4
- ✓ Engine uses valence: bounded restorative floor on low days, reserved energy/high-priority slot on high days (VSCHED-01/02/03) — v1.4

### Active

None committed yet — next milestone TBD via `/gsd-new-milestone`. Owner will dogfood v1.4 (energy-aware schedule + responsive UI) and re-review before scoping the next set.

### Out of Scope

- LLM-powered scheduling — deferred to v2 after rule-based engine is validated
- Multi-user / team features — personal tool only
- Calendar sync (Google Calendar, etc.) — v2 consideration

## Context

- Built as a personal tool first — the primary user is the developer
- Flutter project targeting all platforms (iOS, Android, Web, Windows, macOS, Linux)
- ~12k LOC of app code in `lib/`; 289-test suite green, `flutter analyze` clean (as of v1.4)
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
| Low-mood days stay minimal (required + habits only) (v1.3) | Owner decision: protect low days from time-target load; defer SEED-001 #2 restorative floor | ✓ Resolved in v1.4 — replaced by a *bounded* restorative floor (energy-giving goals only, floor=1) so low days stay light but not empty (VSCHED-01/02) |
| Adaptive modal helper `showAdaptiveFormModal` (v1.4) | One shared dialog-vs-sheet switch at 720dp for every form caller, instead of per-screen bottom sheets | ✓ Good — RESP-01/02/03 browser-verified; goal + commitment forms both route through it |
| Energy valence as int-index Hive field, neutral=0 (v1.4) | Additive migration, no new HiveType/adapter; absent field reads neutral so old goals never crash | ✓ Good — ENERGY-01 migration-safety test green; mirrors existing GoalType/ChunkType pattern |
| Valence colors use tertiary/secondaryContainer, never error (v1.4) | "Costs energy" must not read as destructive; error slot reserved for archive/delete | ✓ Good — non-destructive tonal encoding, UI-checker approved |
| Bounded restorative floor + reserved high-day slot (v1.4) | Low days include ≥1 energy-giving goal but stay under medium-day load; high days reserve 1 energy/high-priority slot before backlog | ✓ Good — VSCHED-01/02/03 deterministic-unit-tested; double-place edge caught in review + fixed |

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
*Last updated: 2026-06-15 after shipping v1.4 "Energy-Aware" milestone*
