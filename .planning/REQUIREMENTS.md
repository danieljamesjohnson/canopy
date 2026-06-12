# Canopy — Requirements

**Milestone:** v1.2 "Make It Usable"
**Created:** 2026-06-12
**Source:** First real dogfood — `.planning/seeds/SEED-002-ui-basics-rework-dogfood.md` (Dan's walkthrough, transcript + frames at `.planning/research/dogfood-2026-06-12/`) + confirmed items from `.planning/seeds/SEED-001-engine-product-critique.md`.

Rule-based only — no LLM. All requirements are user-observable capabilities that close the gap between v1.1's "complete on paper" state and a UI that is legible and usable day-to-day.

---

## Milestone v1.2 Requirements

### Navigation & Information Architecture (NAV)

- [ ] **NAV-01**: After onboarding completes — and on any normal launch with onboarding done — the app lands on **Home**, not the Goals screen.
- [ ] **NAV-02**: Home leads with the live day (current chunk + what's next) and does not merely duplicate the Schedule as a static "Up next" card; the Home↔Schedule relationship is resolved so the user always has one obvious place to see "what am I doing now."

### Schedule Legibility (SCHED)

- [ ] **SCHED-01**: Every chunk in the schedule — discretionary goals as well as commitments — displays a real clock time (start time, plus end time or duration) instead of the goal's frequency metadata ("5x/week").
- [ ] **SCHED-02**: The schedule surfaces a clear "now / next" framing: what you're doing right now, when it ends, and what's next, anchored to the current time.
- [ ] **SCHED-03**: A chunk's complete and skip actions are clear, labeled affordances discoverable without hover — not an ambiguous unlabeled circle.

### Goal Form (GOALFORM)

- [ ] **GOALFORM-01**: The add/edit goal sheet fits the viewport so every field — including Priority — and the Save/confirm action are reachable without the sheet being clipped or requiring awkward in-sheet scrolling.

### Goals Screen (GOALS)

- [ ] **GOALS-01**: The Goals screen makes its purpose explicit as a prioritization view — what your goals are and how focused you are — with an obvious reorder affordance.
- [ ] **GOALS-02**: A goal's priority (low / normal / high) has a clear, consistent visual language that reads correctly and distinctly at each level.

### Check-in (CHECKIN)

- [ ] **CHECKIN-01**: The check-in screen meets contrast/legibility standards — the mood theme background no longer makes text and controls hard to read — and interactive elements have appropriate hover/pressed states.
- [ ] **CHECKIN-02**: The lighter-day choice has a clearly readable on/off state and is presented at the right moment — after the user commits to the day ("Let's go"), framed as push-forward vs. lighter day — rather than an always-present inline toggle whose state can't be read. *(SEED-001 #1)*

### Priority Drives Scheduling (PRIORITY)

- [ ] **PRIORITY-01**: A goal's priority measurably influences schedule generation beyond a tiebreaker — higher-priority goals receive proportionally more or earlier chunks — so changing a goal's priority visibly changes the generated schedule. *(SEED-001 #4)*

---

## Future Requirements (deferred)

From SEED-001 (engine hypotheses not yet dogfooded — defer to a later "engine honesty" milestone):
- Low-mood days should not zero out time-target goals (SEED-001 #2).
- Habits should not monopolize the discretionary cap ahead of other goals (SEED-001 #3).
- Streak semantics revisited once real daily-use history exists (SEED-001 #6).

Other deferred:
- LLM-assisted scheduling and conversational re-planning (v2).
- Calendar sync; user-pinned specific days/times beyond simple frequency.

## Out of Scope (this milestone)

- Any AI/LLM API dependency.
- Backend / multi-device sync — local Hive storage only.
- Re-architecture of the stack — Hive / Provider / go_router are sound; this is UI rework + one targeted engine change (priority).
- Multi-user / team features.

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| NAV-01 | TBD | Pending |
| NAV-02 | TBD | Pending |
| SCHED-01 | TBD | Pending |
| SCHED-02 | TBD | Pending |
| SCHED-03 | TBD | Pending |
| GOALFORM-01 | TBD | Pending |
| GOALS-01 | TBD | Pending |
| GOALS-02 | TBD | Pending |
| CHECKIN-01 | TBD | Pending |
| CHECKIN-02 | TBD | Pending |
| PRIORITY-01 | TBD | Pending |

---
*Phase assignments filled in by the roadmap.*
