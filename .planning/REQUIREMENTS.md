# Requirements: Canopy — v1.4 "Energy-Aware"

**Defined:** 2026-06-14
**Core Value:** Generate a usable daily schedule every morning — one that reflects your real goals and how you actually feel.

> Milestone goal: make Canopy fit the screen it's used on (responsive modals + layout) and
> schedule around how activities make you feel (energy valence per goal, restorative low
> days) — so a fresh review can judge a more honest, more livable day. Rule-based only, no
> LLM. Hive migrations stay additive-only. Web/desktop is the primary dogfood surface.

## v1.4 Requirements

### Responsive Modals & Layout

- [x] **RESP-01**: Goal add/edit form renders as a centered, width-constrained dialog on desktop/web widths and as a bottom sheet on phone widths
- [x] **RESP-02**: On desktop width, the goal form shows the type picker, all fields, Priority, and Save/Add with nothing clipped and no scroll required
- [x] **RESP-03**: Commitment add/edit and any other modal callers use the same shared adaptive dialog-vs-sheet helper

### Energy Valence

- [ ] **ENERGY-01**: A goal carries an energy valence (gives / neutral / costs), persisted via additive Hive migration; existing goals default to neutral
- [ ] **ENERGY-02**: User can set a goal's valence in the goal form on both create and edit
- [ ] **ENERGY-03**: User can attach an emoji/image tag to a goal; it persists and renders on the goal
- [ ] **ENERGY-04**: Valence (and tag) is visible where goals are listed and scheduled, so the day reads restorative-vs-draining at a glance

### Onboarding

- [ ] **ONBOARD-01**: Onboarding includes a "what gives you energy?" step that tags a couple of energy-giving activities, seeding restorative goals before first use

### Valence-Aware Scheduling

- [ ] **VSCHED-01**: On low ("stormy") mood days, energy-giving discretionary goals are eligible for scheduling instead of required + habits only
- [ ] **VSCHED-02**: The low-day restorative inclusion is bounded (a small floor, not full time-target load) so low days stay light
- [ ] **VSCHED-03**: On high ("sunny") mood days, at least one slot is reserved for an energy-giving / high-value goal so good days aren't pure backlog throughput

### Desktop Polish

- [x] **POLISH-01**: Primary screens (home, schedule, goals, check-in) use desktop-appropriate layout at wide widths — constrained content, not phone-stretched full-bleed
- [x] **POLISH-02**: Residual UI nits from a fresh desktop walkthrough are triaged and the high-friction ones fixed

## Future Requirements

Deferred — tracked but not in the v1.4 roadmap.

### Energy Valence

- **ENERGY-F1**: Auto-categorize activity valence (no user declaration) — requires inference; out until a rules/LLM layer exists (PROJECT.md keeps LLM in v2)

### Scheduling

- **VSCHED-F1**: Per-type reservation of the mood cap / full cross-type interleave (SEED-001 #3) — revisit if dogfooding shows habits still crowd the cap after valence lands

## Out of Scope

| Feature | Reason |
|---------|--------|
| LLM-inferred valence or scheduling | PROJECT.md defers all LLM work to v2; v1.4 valence is user-declared and rule-based |
| Calendar sync | v2 consideration (PROJECT.md) |
| Multi-user / team features | Personal tool only |
| "Daily-ready" hardening / full daily-loop validation | Explicit owner call — v1.4 clears known gaps for a fresh review, not daily readiness |

## Traceability

Which phases cover which requirements. Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| RESP-01 | Phase 18 | Complete |
| RESP-02 | Phase 18 | Complete |
| RESP-03 | Phase 18 | Complete |
| ENERGY-01 | Phase 19 | Pending |
| ENERGY-02 | Phase 19 | Pending |
| ENERGY-03 | Phase 19 | Pending |
| ENERGY-04 | Phase 19 | Pending |
| ONBOARD-01 | Phase 19 | Pending |
| VSCHED-01 | Phase 20 | Pending |
| VSCHED-02 | Phase 20 | Pending |
| VSCHED-03 | Phase 20 | Pending |
| POLISH-01 | Phase 18 | Complete |
| POLISH-02 | Phase 18 | Complete |

**Coverage:**

- v1.4 requirements: 13 total
- Mapped to phases: 13 (100%)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-14*
*Last updated: 2026-06-14 after roadmap creation*
