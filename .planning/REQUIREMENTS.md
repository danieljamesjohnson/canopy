# Canopy — Requirements

**Milestone:** v1.3 "An Honest Day"
**Created:** 2026-06-13
**Source:** Post-v1.2 adversarial audit `.planning/seeds/SEED-003-v1.2-adversarial-gaps.md` (#1, #2, #3) + engine-honesty backlog `.planning/seeds/SEED-001-engine-product-critique.md` (#3, #6) + the 2026-06-13 dogfood session (regular-time "fills the day").

Rule-based only — no LLM. Theme: make the scheduling engine tell the truth and use the whole day. Requirements are user-observable wherever possible; the engine-internal ones (CAP, STREAK) are stated as observable schedule/display outcomes so they remain testable.

---

## Milestone v1.3 Requirements

### Time-Anchored Home (NOW)

- [x] **NOW-01**: On Home, "Now" reflects the chunk whose clock-time window contains the *current* time (not merely the first unresolved chunk), and "Next" shows the following chunk. At 6pm with nothing checked off, the 8am chunk is no longer shown as "Now." *(SEED-003 #1)*
- [x] **NOW-02**: Before the day's first chunk and after the last resolved/ended chunk, Home shows a clear pre-start / day-complete state rather than a stale "Now."

### Priority Drives Scheduling (PRIORITY) — continues PRIORITY-01

- [x] **PRIORITY-02**: Raising a *habit's* or an *outcome's* priority changes how it is allocated (more/earlier chunks), not just its sort order — priority's effect on the generated schedule is observable for all three goal types, not time-target only. *(SEED-003 #3)*
- [x] **PRIORITY-03**: Drag-reorder and the form's Low/Normal/High control write a single coherent priority model, so a goal's priority chip stays correct and visible after a drag (no goal silently losing its chip by landing at a mid-list ~0.5). *(SEED-003 #3)*

### Capacity Sharing (CAP)

- [x] **CAP-01**: When the discretionary cap is scarce (especially low mood), capacity is shared across goal types — habits cannot consume the entire cap before outcomes and time-targets are considered. *(SEED-001 #3)*

### Honest Streaks (STREAK)

- [x] **STREAK-01**: A goal's displayed streak equals the actual computed backward due-day walk — the number shown on the goal and the engine's computed streak never diverge. *(SEED-001 #6)*

### Fill the Day (FILL)

- [x] **FILL-01**: When a day has open capacity after required work and habits are placed, regular-time (time-target) goals claim the leftover slots so an otherwise-empty day is filled with what matters — not left blank.
- [x] **FILL-02**: Open-capacity fill is distributed across regular-time goals by priority and bounded by the mood cap, so no single regular-time goal swallows the whole open day.

### Goal Form Honesty (GOALFORM) — continues GOALFORM-01

- [x] **GOALFORM-02**: An automated test proves Priority and Save are reachable at the goal sheet's *true* opened modal height, for every goal type — replacing the existing test that resized the surface to 800×1200 and pumped the form outside the modal. Restructure the sheet if outcome goals overflow. *(SEED-003 #2)*

---

## Future Requirements (deferred)

- **Low-mood restorative floor (SEED-001 #2)** — let a little regular/restorative time through on low-energy days. Deferred by explicit owner decision (low days stay required + habits only); revisit if dogfooding shows low days feel empty.
- **Energy-aware valence (SEED-004)** — user-declared "gives / neutral / costs energy" at goal creation, with low/high days biasing on it. Its own follow-on milestone.

## Out of Scope

- **LLM-powered scheduling** — deferred to v2 after the rule-based engine is validated.
- **The image/text energy categorizer (SEED-004)** — the largest, most optional piece of the energy direction; not this milestone.
- **Multi-user / calendar sync** — personal, local-only tool.

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| NOW-01 | Phase 17 | Complete |
| NOW-02 | Phase 17 | Complete |
| PRIORITY-02 | Phase 15 | Complete |
| PRIORITY-03 | Phase 16 | Complete |
| CAP-01 | Phase 15 | Complete |
| STREAK-01 | Phase 15 | Complete |
| FILL-01 | Phase 15 | Complete |
| FILL-02 | Phase 15 | Complete |
| GOALFORM-02 | Phase 16 | Complete |
