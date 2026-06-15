# Canopy — Roadmap

**Created:** 2026-02-24
**Last updated:** 2026-06-14 (v1.4 roadmap added)

## Milestones

- ✅ **v1.0 — Core Product Loop** — Phases 1-6 (shipped)
- ✅ **v1.1 — Actually Daily** — Phases 7-11 (shipped)
- ✅ **v1.2 — Make It Usable** — Phases 12-14 (shipped 2026-06-13)
- ✅ **v1.3 — An Honest Day** — Phases 15-17 (shipped 2026-06-14)
- 🚧 **v1.4 — Energy-Aware** — Phases 18-20 (in progress)

Full per-milestone detail (phase goals, success criteria, coverage maps) is archived in
`.planning/milestones/`: `v1.2-ROADMAP.md` carries the complete cumulative roadmap through v1.2;
`v1.3-ROADMAP.md`, `v1.3-REQUIREMENTS.md`, and `v1.3-MILESTONE-AUDIT.md` carry the v1.3
phase detail, requirements, and audit.

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

</details>

<details>
<summary>✅ v1.3 An Honest Day (Phases 15-17) — SHIPPED 2026-06-14</summary>

**Milestone Goal:** Make the scheduling engine tell the truth and use the whole day — real time, real priority, filled capacity, honest streaks. Rule-based only (no LLM).

- [x] Phase 15: Engine Honesty (2/2 plans) — CAP-01, STREAK-01, PRIORITY-02, FILL-01, FILL-02
- [x] Phase 16: Priority Model Reconciliation (1/1 plan) — PRIORITY-03, GOALFORM-02
- [x] Phase 17: Time-Anchored Home (1/1 plan) — NOW-01, NOW-02

Full detail archived in `.planning/milestones/v1.3-ROADMAP.md`. 9/9 requirements satisfied,
browser-verified; 247/247 tests green. See `v1.3-MILESTONE-AUDIT.md`.

</details>

### 🚧 v1.4 Energy-Aware (In Progress)

**Milestone Goal:** Make Canopy fit the screen it's used on and schedule around how activities make you feel — so a fresh review can judge a more honest, more livable day.

- [x] **Phase 18: Responsive Modals and Desktop Polish** - Goal form and other modals adapt to viewport (dialog vs sheet); primary screens fit desktop width (completed 2026-06-15)
- [ ] **Phase 19: Energy Valence** - Goals carry a user-declared valence (gives / neutral / costs) with an optional emoji tag; valence is visible in goal form, goal list, and schedule; onboarding seeds restorative activities
- [ ] **Phase 20: Valence-Aware Engine** - Scheduler uses valence to make low days restorative and high days purposeful

## Phase Details

### Phase 18: Responsive Modals and Desktop Polish

**Goal**: Users on desktop/web see modals and primary screens that fit the viewport — no cramped phone-style sheets, no content clipped off-screen
**Depends on**: Phase 17 (v1.3 shipped)
**Requirements**: RESP-01, RESP-02, RESP-03, POLISH-01, POLISH-02
**Success Criteria** (what must be TRUE):

  1. Opening Add/Edit goal on a desktop-width browser shows a centered dialog where type picker, Priority, and Save are all visible without scrolling
  2. Opening Add/Edit goal on a phone-width browser still shows the familiar bottom sheet
  3. Commitment add/edit and any other modal callers use the same adaptive helper — no modal renders as a cramped phone sheet on desktop
  4. Primary screens (home, schedule, goals, check-in) have constrained content width on desktop — not phone-stretched full-bleed
  5. High-friction desktop UI nits from a walkthrough are identified and fixed

**Plans**: 5 plans

- [x] 18-01-PLAN.md — Wave 0 test stubs (adaptive modal, content width, copy) — RED scaffolds
- [x] 18-02-PLAN.md — showAdaptiveFormModal helper + goal form routing (RESP-01, RESP-02)
- [x] 18-03-PLAN.md — commitment caller routed through helper (RESP-03)
- [x] 18-04-PLAN.md — primary screen content-width constraints (POLISH-01)
- [x] 18-05-PLAN.md — copy polish + desktop walkthrough (POLISH-02)

**UI hint**: yes

### Phase 19: Energy Valence

**Goal**: Users can declare how a goal makes them feel, see that signal wherever goals appear, and have restorative activities seeded during onboarding
**Depends on**: Phase 18
**Requirements**: ENERGY-01, ENERGY-02, ENERGY-03, ENERGY-04, ONBOARD-01
**Success Criteria** (what must be TRUE):

  1. Creating or editing a goal shows a gives / neutral / costs picker; the chosen valence persists across app restarts
  2. Existing goals (from before this phase) load with valence defaulting to neutral — no data loss, no migration crash
  3. User can attach an emoji tag to a goal; it persists and appears on the goal card in the goals list
  4. The schedule view shows valence and/or emoji tags on chunks so the day reads restorative-vs-draining at a glance
  5. Onboarding includes a "what gives you energy?" step that marks a couple of goals as energy-giving before first schedule generation

**Plans**: 5 plans

- [ ] 19-01-PLAN.md — Wave 0 RED test stubs (migration safety, goal form, goal card, chunk card, onboarding)
- [ ] 19-02-PLAN.md — Data model: EnergyValence enum + Goal fields 12/13 + schema bump 7→8 + no-op _migration7to8 (ENERGY-01)
- [ ] 19-03-PLAN.md — Goal form valence picker + emoji tag picker (ENERGY-02, ENERGY-03)
- [ ] 19-04-PLAN.md — Valence badge + emoji on goal card and schedule chunk card (ENERGY-03, ENERGY-04)
- [ ] 19-05-PLAN.md — Onboarding Screen 4 "What gives you energy?" energy step (ONBOARD-01)

**UI hint**: yes

### Phase 20: Valence-Aware Engine

**Goal**: The scheduling engine uses valence to shape low and high mood days — low days include restorative activities, high days reserve a slot for what matters
**Depends on**: Phase 19
**Requirements**: VSCHED-01, VSCHED-02, VSCHED-03
**Success Criteria** (what must be TRUE):

  1. On a low ("stormy") mood day, at least one energy-giving discretionary goal appears in the generated schedule alongside required chunks and habits
  2. The restorative inclusion on low days is bounded — a low day with energy-giving goals still has fewer discretionary chunks than a medium mood day
  3. On a high ("sunny") mood day, at least one slot is reserved for an energy-giving or high-priority goal even when backlog pressure is high
  4. Engine behavior is covered by deterministic unit tests that pass under `flutter test`

**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-6 (Core Product Loop) | v1.0 | — | Complete | 2026-02 |
| 7-11 (Actually Daily) | v1.1 | — | Complete | — |
| 12-14 (Make It Usable) | v1.2 | 7/7 | Complete | 2026-06-13 |
| 15. Engine Honesty | v1.3 | 2/2 | Complete | 2026-06-13 |
| 16. Priority Model Reconciliation | v1.3 | 1/1 | Complete | 2026-06-13 |
| 17. Time-Anchored Home | v1.3 | 1/1 | Complete | 2026-06-14 |
| 18. Responsive Modals and Desktop Polish | v1.4 | 5/5 | Complete   | 2026-06-15 |
| 19. Energy Valence | v1.4 | 0/5 | Planned | - |
| 20. Valence-Aware Engine | v1.4 | 0/? | Not started | - |
