# Canopy — Roadmap

**Created:** 2026-02-24
**Last updated:** 2026-06-13 (v1.3 roadmap added)

## Milestones

- ✅ **v1.0 — Core Product Loop** — Phases 1-6 (shipped)
- ✅ **v1.1 — Actually Daily** — Phases 7-11 (shipped)
- ✅ **v1.2 — Make It Usable** — Phases 12-14 (shipped 2026-06-13)
- 🚧 **v1.3 — An Honest Day** — Phases 15-17 (in progress)

Full per-milestone detail (phase goals, success criteria, coverage maps) is archived in
`.planning/milestones/` (`v1.2-ROADMAP.md` carries the complete cumulative roadmap through v1.2;
`v1.2-REQUIREMENTS.md` and `v1.2-MILESTONE-AUDIT.md` carry the requirements and audit).

## Phases

<details>
<summary>✅ v1.0 Core Product Loop (Phases 1-6) — SHIPPED</summary>

- [x] Phase 1: Foundation
- [x] Phase 2: Goals and Commitments
- [x] Phase 3: Schedule Generation and Morning Check-in
- [x] Phase 4: Chunk Tracking and Notifications
- [x] Phase 5: Quarterly Review
- [x] Phase 6: Desktop and Web Polish

</details>

<details>
<summary>✅ v1.1 Actually Daily (Phases 7-11) — SHIPPED</summary>

- [x] Phase 7: Unbreak the Morning
- [x] Phase 8: A Schedule You Can Read
- [x] Phase 9: An Engine That Budgets
- [x] Phase 10: Close the Day
- [x] Phase 11: Honest Long Loop

</details>

<details>
<summary>✅ v1.2 Make It Usable (Phases 12-14) — SHIPPED 2026-06-13</summary>

- [x] Phase 12: Home as Landing, Schedule as Plan (3/3 plans) — NAV-01/02, SCHED-01/02/03
- [x] Phase 13: Check-in and Goal Form (2/2 plans) — CHECKIN-01/02, GOALFORM-01
- [x] Phase 14: Goals Screen and Priority End-to-End (2/2 plans) — GOALS-01/02, PRIORITY-01

Deferred: human visual UAT for phases 12/13/14 (tracked in each phase's `*-UAT.md`;
run `/gsd-verify-work {12,13,14}` to confirm). All requirements implemented, wired, and
covered by a green 209-test suite — see `milestones/v1.2-MILESTONE-AUDIT.md`.

</details>

### 🚧 v1.3 An Honest Day (In Progress)

**Milestone Goal:** Make the scheduling engine tell the truth and use the whole day — real time, real priority, filled capacity, honest streaks.

- [x] **Phase 15: Engine Honesty** - Cap sharing, honest streaks, priority drives all goal types, regular-time fills open days (completed 2026-06-13)
- [ ] **Phase 16: Priority Model Reconciliation** - Drag and form write one coherent priority; goal sheet viewport test proves Priority+Save always reachable
- [ ] **Phase 17: Time-Anchored Home** - Now/Next reflect the chunk whose clock window contains the actual current time; pre-start and day-complete states

## Phase Details

### Phase 15: Engine Honesty

**Goal**: The scheduling engine allocates capacity fairly, counts streaks truthfully, and uses the full day — so the generated schedule reflects reality rather than an artifact of processing order.
**Depends on**: Phase 14 (v1.2 shipped)
**Requirements**: CAP-01, STREAK-01, PRIORITY-02, FILL-01, FILL-02
**Success Criteria** (what must be TRUE):

  1. On a low-mood day, outcome and time-target goals receive chunks even when habits are also scheduled — no single goal type monopolizes the discretionary cap.
  2. A goal's streak shown in the UI matches what a manual backward walk over due-days would compute — no divergence possible.
  3. Raising a habit's priority increases the number of chunks it receives relative to a lower-priority habit; raising an outcome's priority increases its chunk allocation relative to a lower-priority outcome.
  4. On a day with open capacity after required work and habits, regular-time (time-target) goals appear in the schedule rather than leaving the day empty.
  5. When multiple regular-time goals compete for open slots, higher-priority goals receive more chunks and no single goal claims the entire open day.

**Plans**: 2 plans

  - [x] 15-01-PLAN.md — Engine allocation fixes: habit ceiling + multi-chunk priority demand + always-run round-robin time-target fill (CAP-01, PRIORITY-02, FILL-01, FILL-02)
  - [x] 15-02-PLAN.md — Generation-time streak write-back so displayed streak matches computeStreak() (STREAK-01)

### Phase 16: Priority Model Reconciliation

**Goal**: The drag-reorder and the form's Low/Normal/High selector write the same priority model, so a goal's priority chip stays correct after any interaction — and an automated test proves the goal sheet's Priority and Save controls are reachable at the true modal height for every goal type.
**Depends on**: Phase 15
**Requirements**: PRIORITY-03, GOALFORM-02
**Success Criteria** (what must be TRUE):

  1. After dragging a goal to a new position in the list, its priority chip displays the correct Low/Normal/High label — no goal silently loses its chip or shows a stale value.
  2. After opening a goal's form and changing the priority selector, the goal's chip in the list reflects the new value without requiring a restart or re-open.
  3. A widget test run at the goal sheet's actual opened modal height (not an oversized test surface) passes for time-target, outcome, and habit goals — confirming Priority and Save are not clipped.

**Plans**: TBD
**UI hint**: yes

### Phase 17: Time-Anchored Home

**Goal**: Home's Now and Next always reflect the chunk whose clock window contains the current time — not the first unresolved chunk — with clear pre-start and day-complete states when no chunk is active.
**Depends on**: Phase 16
**Requirements**: NOW-01, NOW-02
**Success Criteria** (what must be TRUE):

  1. At 6pm with no chunks checked off, the 8am chunk is not shown as "Now" — the chunk matching the current clock time (or a day-complete state) is shown instead.
  2. Before the first chunk of the day begins, Home shows a pre-start state (not a stale or incorrect "Now").
  3. After the last chunk's time window has passed, Home shows a day-complete state rather than the last chunk stuck as "Now."

**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-6 (Core Product Loop) | v1.0 | — | Complete | 2026-02 |
| 7-11 (Actually Daily) | v1.1 | — | Complete | — |
| 12. Home as Landing, Schedule as Plan | v1.2 | 3/3 | Complete | 2026-06-12 |
| 13. Check-in and Goal Form | v1.2 | 2/2 | Complete | 2026-06-13 |
| 14. Goals Screen and Priority End-to-End | v1.2 | 2/2 | Complete | 2026-06-13 |
| 15. Engine Honesty | v1.3 | 2/2 | Complete   | 2026-06-13 |
| 16. Priority Model Reconciliation | v1.3 | 0/? | Not started | - |
| 17. Time-Anchored Home | v1.3 | 0/? | Not started | - |
